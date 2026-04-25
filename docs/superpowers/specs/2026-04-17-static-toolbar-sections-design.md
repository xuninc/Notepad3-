# Notepad 3++ — Static Toolbar Sections Design

**Status:** spec for review
**Date:** 2026-04-17
**Author:** Claude (Opus 4.7) with Corey
**Scope:** Add user-pinned static (non-scrolling) sections to the classic toolbar, on both the iOS-native Swift port (`artifacts/ios-native/`) and the React Native cross-platform app (`artifacts/mobile/`, which ships to iOS + Android tablets/desktop).

---

## 1. Context

The classic toolbar today is a single horizontally-scrolling strip (or two such strips, in 2-row mode) of icon buttons. As the toolbar's button list has grown, the most-used buttons (Save, Undo, Find) frequently scroll off-screen, especially on narrower windows where labels are visible.

Users want to **pin their most-used buttons to the edges** so those buttons remain visible no matter how far the rest of the toolbar is scrolled. Pinned buttons live in **static zones at the start and/or end of each row**; the buttons between them remain a horizontal scroll.

Two runtimes ship the classic toolbar:

- **iOS native** — `artifacts/ios-native/Sources/Notepad3/UI/Classic/ClassicToolbar.swift`. UIKit. `UIScrollView` per row, `UIStackView` of buttons inside.
- **RN/Expo** — `artifacts/mobile/app/index.tsx` around line 1000. `<ScrollView horizontal>` per row, with the toolbar gated by `!isMobile` (so this feature ships on tablets/desktop, not phone chrome).

Both must implement the feature. The data model is shared in spirit; persistence keys are namespaced identically across both runtimes.

## 2. Goals & Non-goals

**Goals:**
- Users can pin any toolbar button to the **start** or **end** of any row via two paths: (a) a **settings panel** with a 3-state choice per button (none / pin to start / pin to end) — plus row selector when 2-row mode is on — and (b) **drag-and-drop** in an explicit edit mode.
- Pinned buttons stay visible while the middle (scrolling) region scrolls.
- Pin state persists across launches.
- Feature parity between the iOS-native Swift toolbar and the RN toolbar.
- 1-row ↔ 2-row mode transitions handle pinned buttons without losing user intent (see §6).

**Non-goals (deferred):**
- **Mobile/phone chrome** (`MobileBottomBar`, `MobileFAB`, `MobileActionSheet`). The classic toolbar is the only target.
- **Cross-device sync.** Pin state is per-device, same as `toolbarLabels` and `toolbarRows` today.
- **Reordering buttons within the scrolling region.** Drag is for pinning to/unpinning from edges only. The scrolling region's order remains the canonical `items()` order.
- **Per-document pin state.** Pins are user-global, not per-document.
- **Custom button creation.** Users can pin only existing toolbar buttons.

## 3. Design philosophy

**One model, two renderers.** Both runtimes consume the same logical pin spec (`{buttonId → {side, row}}`) and render it the same way. Drift gets caught when the visual behavior diverges.

**Existing prefs pattern.** Persistence piggybacks on the existing `Preferences` (Swift `UserDefaults`) and `ThemeContext` (RN AsyncStorage) using the same `notepad3pp.*` namespacing.

**No new dependencies.** RN already has `react-native-gesture-handler ~2.28.0` and `react-native-reanimated ~4.1.1` in `artifacts/mobile/package.json` — those cover drag. iOS native uses built-in `UIDragInteraction` / `UIDropInteraction`.

**Don't break what works.** Long-press on a toolbar button still surfaces the accessibility-announcer label/tooltip. Read mode, Zen mode, Trackpad toggles still re-tint correctly. The 1-row default toolbar with no pins looks visually identical to today.

---

## 4. Data model

### 4.1 Pin spec

A user's pin state is a map keyed by stable button ID:

```
ToolbarPins = {
  [buttonId: string]: {
    side: "start" | "end",
    row: 1 | 2     // ignored when toolbarRows == "single"; always 1 in that mode
  }
}
```

Stable IDs already exist in both runtimes (`tb-new`, `tb-open`, `tb-save`, …, `tb-edit` (new), …). The `items()` array in the Swift toolbar and the `items` array in the RN render block are the canonical ID source.

### 4.2 Render rule

Per row, in this left-to-right order:

1. **Start zone:** all pinned buttons whose `(side, row)` is `(start, thisRow)`, in **pin order** (see §4.3).
2. **Vertical separator** (if start zone is non-empty *and* the scrolling region has any buttons).
3. **Scrolling region:** every other button for this row (in canonical `items()` order, with separators), inside the existing horizontal scroll view.
4. **Vertical separator** (if end zone is non-empty *and* the scrolling region has any buttons).
5. **End zone:** all pinned buttons whose `(side, row)` is `(end, thisRow)`, in **pin order**.

Separators between groups inside the canonical `items()` are preserved in the scrolling region; pinned buttons drop their adjacent separators.

### 4.3 Pin order

Pin order within a zone is **the order in which buttons were pinned**, oldest first (i.e. closest to the outer edge), newest closest to the scrolling region.

Rationale: predictable to the user, and matches how badges accumulate in macOS Customize-Toolbar mode. Settings panel and drag both append to the end of the zone.

Reorder within a zone is **out of scope** for v1 — users who want a different order can unpin and re-pin in the desired sequence.

### 4.4 Capacity rule

No hard cap on pinned button count. Instead: **the scrolling region must retain a minimum visible width of 80 pt.** This applies per row.

- A drag-and-drop drop that would push the scrolling region below 80 pt is **refused** with a brief error haptic (Swift: `Haptics.error()` from `UI/Haptics.swift`; RN: `Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error)` from `expo-haptics`).
- A settings-panel toggle that would do the same is also refused, with an inline error row in the panel ("Not enough room — unpin one first").
- The 80 pt threshold is computed against the row's available width minus the start zone, end zone, and the two separators. Re-evaluated on rotation / resize.

## 5. UX

### 5.1 Settings panel

Add a new section to the existing Preferences modal: **"Pinned buttons"**, beneath the existing "Two-row toolbar" / "Show text under icons" controls.

- Lists every toolbar button by label and SF-Symbol icon.
- Each row: 3-state segmented control — **None** / **Pin to start** / **Pin to end**.
- When `toolbarRows == "double"`, each row also shows a row selector (Row 1 / Row 2) that activates only if pin state is non-None.
- Refused changes (capacity rule) show an inline note next to the offending row.

The list scrolls; the panel itself is the existing modal.

### 5.2 Edit mode (drag-and-drop)

Drag is gated behind an explicit "Edit toolbar" mode to avoid conflict with the existing tap and long-press behaviors.

- A new toolbar button **`tb-edit`** (SF Symbol `slider.horizontal.3`, RN icon `sliders` or equivalent Feather icon) is added to the canonical `items()` list, near the "Preferences" button.
- Tapping `tb-edit` enters edit mode:
  - All toolbar buttons begin a subtle wiggle (Springboard-like).
  - The start and end zones of each visible row get a faint background highlight using `palette.border` at low alpha.
  - The `tb-edit` icon swaps to a checkmark (`checkmark`) — its label/tooltip reads **"Done"**.
  - Tapping the button (now Done) exits edit mode.
- While in edit mode:
  - Tapping a button does **not** fire its action; instead it briefly pulses to indicate it's draggable.
  - Dragging a button onto a start or end zone (any row) pins it there. Dragging an already-pinned button onto the scrolling region unpins it. Dragging a pinned button to a different zone moves it.
  - Drop animations use `Haptics.selectionChanged()` (Swift) / `Haptics.selectionAsync()` (RN) on success; error haptic on refusal (capacity rule).
- **Tap outside the toolbar does NOT exit edit mode.** Exit only via the Done button. Rationale: pinned buttons live at the toolbar's edges, where tap-outside is most likely to be an accidental drop or stray touch — mistakenly exiting would erase the user's mental flow.
- The toolbar's `onMore` overflow menu and other buttons are inert in edit mode.

### 5.3 Long-press behavior unchanged

Long-press on any toolbar button still triggers the accessibility-announcer label / iOS 16+ tooltip exactly as today. No mode collision.

## 6. Two-row mode migrations

Toolbar row count is a user preference (`toolbarRows: single | double`). Migrating a non-empty pin map between modes:

### 6.1 `double → single`

For each pinned button currently on row 2, **collapse it to the same side of row 1**, appended after row 1's existing pins on that side.

If collapsing would violate the capacity rule (§4.4) for row 1, the surplus row-2 pins are **demoted to None** (i.e. unpinned, falling back into the scrolling region in canonical order). A one-shot info banner in the Preferences modal tells the user: "*N pinned buttons couldn't fit when switching to one row and were unpinned.*"

### 6.2 `single → double`

All pins remain on row 1. Row 2 starts empty. The user can re-pin to row 2 via the settings panel or by entering edit mode and dragging.

Rationale: this matches user intent ("I had them pinned where they were"); making the system *spread* pins across rows would surprise the user and require a heuristic the user didn't ask for.

## 7. Visual treatment

- **Single thin vertical separator** (1px / `1 / UIScreen.main.scale` on iOS) between each non-empty static zone and the scrolling region. Color: `palette.border` (same color as the existing inter-group separators).
- **No background tint** on the static zones in normal mode. They look like the rest of the toolbar.
- In edit mode only: the static zones get a faint background highlight (`palette.border` at ~20% alpha) so users know where to drop. This highlight disappears when edit mode exits.

## 8. Persistence

### 8.1 Swift (iOS native)

Add to `Preferences.swift`:

```swift
private let keyToolbarPins = "notepad3pp.toolbarPins"

var toolbarPins: ToolbarPins {
    get {
        guard let data = defaults.data(forKey: keyToolbarPins),
              let decoded = try? JSONDecoder().decode(ToolbarPins.self, from: data)
        else { return ToolbarPins() }
        return decoded
    }
    set {
        guard let data = try? JSONEncoder().encode(newValue) else { return }
        defaults.set(data, forKey: keyToolbarPins)
        notify()
    }
}
```

`ToolbarPins` is a `Codable` `[String: ToolbarPinSpec]` where `ToolbarPinSpec` has `side: Side` (enum) and `row: Int`.

Pattern matches the existing `customPalette` JSON-encoded preference.

### 8.2 RN

Add to `context/ThemeContext.tsx`:

```ts
const PINS_KEY = "notepad3pp.toolbarPins";
toolbarPins: ToolbarPins;
setToolbarPins: (next: ToolbarPins) => void;
```

`ToolbarPins` shape mirrors §4.1. JSON-encoded into AsyncStorage (`@react-native-async-storage/async-storage`, the store already used for `LABELS_KEY`/`ROWS_KEY`/`CUSTOM_KEY`).

### 8.3 Migration safety

If the persisted JSON references a button ID that no longer exists in `items()`, **silently drop it on read.** No errors, no banners.

## 9. Implementation phases

### Phase 0 — Shared groundwork

- Add `ToolbarPins` types in both runtimes (`Models/ToolbarPins.swift` for Swift; `lib/toolbarPins.ts` shared type for RN if a shared lib exists, otherwise inline in `ThemeContext.tsx`).
- Add the persistence prefs as in §8.
- Add the `tb-edit` button to the canonical `items()` lists in both renderers — initial action is a no-op so the visual alignment is in place.

**Verification:** prefs round-trip a fixed pin map across an app relaunch in both runtimes.

### Phase 1 — Render the static zones (settings-driven)

- Modify the Swift `ClassicToolbar.rebuild()` to split `items()` per row into `(start zone, scrolling region, end zone)` based on `Preferences.shared.toolbarPins`.
- Mirror the same split in the RN render block around line 1000 of `app/index.tsx`. Each row becomes three `<View>`s: start zone, scrolling `<ScrollView horizontal>`, end zone.
- Add the inter-zone vertical separators per §7.
- Add the **settings panel** UI in §5.1 (no drag yet). User can pin/unpin via the panel and watch the toolbar update live.
- Implement the capacity rule (§4.4) for settings-driven changes.
- Implement the 1↔2-row migration (§6).

**Verification:** in both runtimes, a user can pin/unpin via settings and pinned buttons stay visible while the scrolling region scrolls. Capacity refusals show the inline note. Switching `toolbarRows` preserves intent per §6.

### Phase 2 — Edit mode + drag-and-drop

- Wire `tb-edit` to a published "isEditingToolbar" flag (held on the toolbar view in Swift; via React state in RN).
- Implement the wiggle animation, the zone highlight, and the Done-button swap.
- iOS native: use `UIDragInteraction` / `UIDropInteraction` on each button and on the start/end-zone container views. The zone container computes the drop side and row from its identity. Reject drops that violate the capacity rule with `UINotificationFeedbackGenerator(.error)`.
- RN: use `react-native-gesture-handler` `LongPressGestureHandler` + `PanGestureHandler` (or a single `GestureDetector` in v2 API) plus `react-native-reanimated` shared values. Drop targets are absolute-positioned overlay views above each start/end zone, hit-tested by `runOnJS` on gesture end. Same capacity rule and error haptic.

**Verification:** drag-and-drop in edit mode achieves identical pin state to the settings panel. Capacity refusals haptic + bounce-back. Long-press tooltips remain unchanged outside edit mode.

### Phase 3 — Polish

- A11y: VoiceOver labels for the static zones ("Pinned to start", "Pinned to end"). The `tb-edit` Done state announces "Done editing toolbar."
- Keyboard support (iOS native only, given external keyboard use case): in edit mode, arrow keys move the focused button between zones; space pins/unpins.
- Settings-panel "Reset pins" button to clear `toolbarPins` to `{}` after a confirmation.

**Verification:** VoiceOver walk-through reads the toolbar in three groups (start / scrolling / end) and announces edit mode entry/exit.

## 10. Risks & open questions

- **RN drag UX on Android.** `react-native-gesture-handler` works on Android but pixel-perfect feel parity with iOS is not guaranteed. Acceptable for v1; if Android drag feels rough, settings-panel path still works as fallback.
- **Two-row collapse data loss.** When `double → single` causes capacity surplus (§6.1), unpinned buttons fall back to the scrolling region. Users who frequently toggle row count *might* be confused. Mitigation: the one-shot info banner. If that's not enough, future v2 could remember the demoted pins and restore them on `single → double`.
- **`tb-edit` button uses one of the visible toolbar slots.** If a user pins it, edit mode becomes always-easy to enter. If they don't, it lives in the scrolling region. Either way it's reachable. We accept the small additional clutter.

## 11. Test plan

- **Unit (both runtimes):** pin spec encode/decode round-trip; render-rule splits `items()` correctly for an empty pin map, all-start, all-end, mixed, and 2-row variants; capacity refusal logic.
- **Integration (Swift):** UI smoke test in CI that toggles a pin via the settings API and asserts the button's superview is the start-zone container, not the scroll view.
- **Manual (both):** drag a button, drop in start, scroll the middle, confirm pinned button stays visible. Drag to refuse-capacity zone, confirm haptic + bounce-back. Switch 2→1 row mode with row-2 pins, confirm collapse + banner.

---

## 12. Out of scope (explicit non-goals reiterated)

- Mobile phone chrome (deferred).
- Per-document pin state.
- Cross-device sync.
- User-defined / custom toolbar buttons.
- Reordering inside the scrolling region.
- Reordering inside a zone (v1 uses pin order — oldest closest to the outer edge).
