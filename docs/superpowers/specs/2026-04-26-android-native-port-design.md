# Notepad 3++ — Native Android Port Design

**Status:** spec for review
**Date:** 2026-04-26
**Author:** Claude (Opus 4.7) with Corey
**Scope:** 1-for-1 feature port of the native Swift Notepad 3++ iOS app (`artifacts/ios-native/`) to a native Android app written in Kotlin, living at `artifacts/android-native/`.

> **Honest scope:** this is a multi-phase port. Estimate: 4–8 weeks of focused work to reach feature parity. Each phase ships a green CI run + a sideloadable debug APK. Treat the phases as the product roadmap, not the implementation schedule — a single agent session won't finish all of them.

---

## 1. Context

The repo previously had a React Native / Expo cross-platform app at `artifacts/mobile/` that targeted both iOS and Android. That app has been retired and preserved on the `archive/rn-garbage` branch. The native Swift iOS port at `artifacts/ios-native/` is now the authoritative implementation of the Notepad 3++ feature surface.

This spec covers building a native Android sibling at `artifacts/android-native/`. The Swift iOS app is the **oracle**: every behavior, every visual choice, every preference key is matched, with platform-appropriate substitutions where iOS APIs have no Android equivalent. We do not redesign the app for Android; we re-implement it.

**The two native apps are siblings, not a shared codebase.** No common runtime, no shared business logic. They share only:
- The product name, brand, and visual identity (colors, layouts, behaviors)
- The persisted-data shape (notes JSON, prefs keys — so a future cloud sync layer could feed both)
- The git repo

## 2. Goals & Non-goals

**Goals:**

- Native Kotlin Android app at `artifacts/android-native/` reaching feature parity with the iOS Swift port as of commit `36d34b4`.
- All 8 themes (Classic / Light / Dark / Retro / Modern / Sunset / Cyberpunk / Custom) with the same hex values and the same field semantics as iOS.
- Two layout modes (mobile and classic) with the same chrome composition: mobile bottom bar + FAB; classic title bar + menu bar with Aero-style flat dropdowns + scrolling toolbar + tab strip + status bar.
- Editor with hand-rolled undo/redo, programmatic-mutation tracking, syntax highlighting for the same 7 languages, find/replace with regex/case/word options, line tools (sort, trim, duplicate, delete, goto), markdown preview.
- Keyboard accessory bar above the IME with the static 3×2 virtual D-pad cluster (Shift / ↑ / Delete on top, ← / ↓ / → on bottom) and a horizontally-scrolling supporting bar.
- Always-visible layout-switcher button in both modes.
- Read mode (editor read-only with a visible lock affordance).
- Zen mode that actually expands the editor (constraint-set swap, not just hidden chrome).
- Compare modal — side-by-side or top-bottom diff view between two open notes, with synchronized scrolling and per-line status (added/modified/removed).
- Custom palette builder with per-field hex overrides persisted across launches.
- CI workflow producing a green debug APK on every push.

**Non-goals (deferred):**

- **Tablet-specific layouts.** The iOS port is iPhone-only (`TARGETED_DEVICE_FAMILY: 1`); the Android port is phone-only too. Tablet/foldable adaptation comes later.
- **Wear OS, Android Auto, Android TV, ChromeOS.** Phone form factor only.
- **Material You dynamic color.** Android 12+'s Monet system would clash with our 8 named themes. We override.
- **Cloud sync, multi-device, accounts, login.** Local-only.
- **Play Store distribution.** Sideloadable debug APK from CI is the deliverable. Release signing / AAB / Play Console comes after parity.
- **Virtual trackpad.** The iOS feature simulates a trackpad for keyboard-only iPads. Android phones rarely use this pattern; deferred.
- **Track-pad-style pointer overlay.** Same reason as above.
- **NDK / native code.** Kotlin only. No JNI.
- **Hermes-style JIT.** N/A — that's RN.

## 3. Design philosophy

**iOS is the oracle.** Whenever a design question comes up — what color, what spacing, what gesture, what label — the answer is "what does the iOS app do?" We match the behavior, not the implementation detail. Where iOS has no Android-side analog (e.g. `UIInputViewController`, `NSTextStorage` delegate), we pick the closest native Android equivalent and document the substitution.

**Native idioms over RN/cross-platform idioms.** This is not a port of the dead RN code; it is a port of the *iOS Swift code*. Don't reach for KMP, don't reach for Flutter, don't reach for Electron. Kotlin + Jetpack + Android SDK.

**Compose for chrome, classic Views/EditText for the editor.** Decision rationale in §5.1.

**ViewModel + StateFlow for surviving config changes.** Android destroys Activities on rotation, dark-mode flip, IME visibility, language change. The iOS architecture (singletons + observer tokens) doesn't think this way. We keep state in ViewModels and observe it as `StateFlow`; Views are dumb projections.

**Hand-rolled undo from day 1.** EditText's built-in undo is a toy. The iOS app gets undo for free via `UITextView.undoManager`; on Android we build it ourselves. Phase 1 ships with it. Retrofitting undo into a half-built editor is famously painful — we don't.

**Phased delivery; every phase ships a green APK.** No phase merges to `main` without a CI green run *and* a sideloaded device check.

**Manual DI, no Hilt.** Mirrors the iOS singleton pattern (`NotesStore.shared` → `object NotesStore`). Hilt's annotation-processor cost outweighs its benefit at this scope.

---

## 4. Tech stack — locked decisions

| Decision | Value | Rationale |
|---|---|---|
| Language | Kotlin 2.x | Java is dead for new Android dev. |
| UI framework | Jetpack Compose (chrome) + classic `EditText` via `AndroidView` interop (editor) | Compose's `BasicTextField` re-runs `VisualTransformation` per recomposition, dying on 5k+ line documents with custom highlighting. `SpannableStringBuilder` on a classic `EditText` parallels iOS's mutable `NSTextStorage` directly. |
| Min SDK | **API 30 (Android 11)** | `WindowInsetsCompat.Type.ime()` is the only sane way to anchor the keyboard accessory bar to the IME top; stable on API 30+, fragile on 28–29. Trades ~6% of devices for not having to rebuild that feature twice. |
| Target SDK | API 34 (Android 14) | Latest stable; no behaviour-change surprises in 35 yet for non-Play apps. |
| Build system | Gradle 8.x with **Kotlin DSL (KTS)** + `libs.versions.toml` version catalog | Standard for new projects in 2026. No Groovy. |
| DI | Manual `object` singletons | Mirrors iOS `*.shared` pattern. |
| Persistence | JSON file (`notes-v1.json`) + `SharedPreferences` for prefs | Mirrors iOS exactly so a future sync layer can serve both. No Room. |
| Async | Kotlin coroutines + `StateFlow` | Idiomatic; survives config changes when held in `ViewModel`. |
| Markdown rendering | [Markwon](https://github.com/noties/Markwon) | Mature, no WebView, supports CommonMark + extensions. |
| Bundle ID | `com.corey.android.np3plusplus` | Matches the dead RN Android build's package; future-friendly for users who installed both. |
| Java toolchain | Temurin JDK 17 | Standard AGP 8.x requirement. |
| Min Gradle | 8.7+ | Pairs with AGP 8.5+. |

## 5. Architecture

### 5.1 Editor: classic `EditText` inside `AndroidView`

The single most consequential UI decision. Compose's `BasicTextField` looks attractive but has known issues:
- `VisualTransformation` re-runs on every recomposition; with token-based syntax highlighting this becomes O(N) per keystroke, where N is the document length.
- Selection-management bugs on multi-line input with custom decorations through Compose 1.7.x.
- Custom span types (background colors, click handlers) are awkward.

`EditText` with a `SpannableStringBuilder` underneath, mutated via a custom `TextWatcher` that runs the syntax highlighter, parallels iOS's `NSTextStorage` + `NSTextStorageDelegate` model directly. The `EditText` is wrapped in an `AndroidView` and embedded in the Compose tree at the editor position.

### 5.2 Chrome: Jetpack Compose

Title bar, menu bar (with Aero-style dropdowns), toolbar, tab strip, status bar, mobile bottom bar, FAB, settings, find/replace bar, modals — all Compose. Reasoning:
- Compose's `Modifier.composed`-driven theming makes the 8-theme switching trivial.
- Aero/Win98 styling means heavy override of Material defaults; Compose's full styling control is easier than fighting `MaterialTheme` from XML.
- Keyboard accessory uses `WindowInsetsCompat.Type.ime()` to anchor itself; trivial in Compose with `imePadding()`.
- Animations (theme switch, find-bar slide, layout-mode switch, zen-mode collapse) are first-class via `animateContentSize`, `AnimatedVisibility`, `Crossfade`.

### 5.3 State

| Layer | Holder | Lives across | Notes |
|---|---|---|---|
| Notes (CRUD, active id) | `NotesStore` (`object` singleton) | App lifetime | Backed by `notes-v1.json` in `filesDir`. |
| Prefs | `Preferences` (`object` singleton) | App lifetime | Backed by `SharedPreferences("notepad3pp", MODE_PRIVATE)`. Same key names as iOS. |
| Theme | `ThemeController` (`object` singleton) | App lifetime | Resolves the active `Palette` from preference + system dark mode. |
| Per-screen UI state | `ViewModel` per screen | Config changes | E.g. `EditorViewModel` holds the editor's read-mode flag, find-bar visibility, current selection. |
| Editor text | `EditText` instance | Activity lifetime | Re-bound to `NotesStore.activeNote.body` on rebuild. |

`StateFlow` is the canonical observation primitive; the singletons expose them, ViewModels collect them.

### 5.4 Activity / Fragment / Compose hierarchy

Single Activity (`MainActivity`) hosting a Compose root. No `Fragment`s — Compose handles the navigation for our two-mode app trivially via state-driven `if`/`when`.

```
MainActivity
└── NotepadApp (top-level @Composable)
    ├── findBarVisible — Compose state
    ├── layoutMode — collected from Preferences
    └── when (layoutMode) {
            mobile -> MobileLayout(notesStore, themeController, prefs)
            classic -> ClassicLayout(notesStore, themeController, prefs)
        }
```

### 5.5 Project layout (final)

```
artifacts/android-native/
├── app/
│   ├── build.gradle.kts
│   ├── src/main/
│   │   ├── AndroidManifest.xml
│   │   ├── kotlin/com/corey/notepad3/
│   │   │   ├── MainActivity.kt
│   │   │   ├── app/                      # top-level composables, theme bridge
│   │   │   ├── editor/                   # EditText interop, undo, syntax highlighter
│   │   │   ├── chrome/
│   │   │   │   ├── classic/              # title bar, aero menu bar, toolbar, status bar, etc.
│   │   │   │   └── mobile/               # bottom bar, FAB, action sheet
│   │   │   ├── ime/                      # keyboard accessory bar + D-pad cluster
│   │   │   ├── persistence/              # NotesStore, Preferences, ThemeController
│   │   │   ├── models/                   # Note, NoteLanguage, Palette, ToolbarRows, etc.
│   │   │   ├── theme/                    # 8 named palettes, custom palette resolver
│   │   │   ├── findreplace/              # Find/replace UI + regex engine
│   │   │   ├── syntax/                   # SyntaxHighlighter + per-language token sets
│   │   │   ├── markdown/                 # Markwon adapter
│   │   │   └── settings/                 # Settings screen + custom palette builder
│   │   └── res/                          # icons, strings, themes (Material3 base)
├── build.gradle.kts                      # root build
├── settings.gradle.kts
├── gradle.properties
├── gradle/wrapper/                       # Gradle wrapper jar/properties
├── libs.versions.toml                    # version catalog
└── README.md
```

Source root is `kotlin/` (not `java/`) — modern AGP convention.

### 5.6 Modules

**Single app module for v1.** Multi-module is overkill until the codebase exceeds ~30k lines. We keep the option open by following a clean package structure (above).

---

## 6. Persistence model

### 6.1 Notes

`NotesStore.shared` (in iOS) → `object NotesStore` in Kotlin. Backed by `<filesDir>/notes-v1.json` written atomically (write-to-tempfile-then-rename).

```kotlin
@Serializable
data class Note(
    val id: String,                    // UUID
    val title: String,
    val body: String,
    val createdAt: Long,               // epoch millis (iOS uses ISO8601 — we serialize compatibly)
    val updatedAt: Long,
    val language: NoteLanguage = NoteLanguage.PLAIN,
)

@Serializable
data class NotesSnapshot(
    val notes: List<Note>,
    val activeId: String,
)
```

Date format note: iOS encodes as ISO 8601. We serialize epoch millis but encode as ISO 8601 strings for cross-platform compatibility — JSON's `kotlinx.serialization.modules` allow custom serializers for `Long` ↔ ISO 8601.

CRUD methods match iOS 1-for-1: `setActive(id)`, `updateActive(title=, body=, language=)`, `createBlank()`, `importNote(title, body, language)`, `delete(id)`, `rename(id, title)`, `duplicate(id)`, `closeOthers(keep)`.

Observer pattern: expose `state: StateFlow<NotesSnapshot>`. Callers `collect`.

### 6.2 Prefs

`Preferences.shared` → `object Preferences`. Backed by `SharedPreferences("notepad3pp", MODE_PRIVATE)`. Keys match iOS exactly:

| iOS key | Android key | Type |
|---|---|---|
| `notepad3pp.tabsLayout` | same | enum string |
| `notepad3pp.toolbarLabels` | same | bool |
| `notepad3pp.toolbarRows` | same | enum string |
| `notepad3pp.accessoryRows` | same | enum string |
| `notepad3pp.layoutMode` | same | enum string |
| `notepad3pp.starterContent` | same | enum string |
| `notepad3pp.customPalette` | same | JSON string of `Map<String,String>` |
| `notepad3pp.themePreference` | same | string `"system"` or `"named:<name>"` |

Each is exposed as a `StateFlow<T>`; mutations go through `Preferences.setX(value)` which updates the disk-backed prefs and emits.

### 6.3 Crash recovery

Mirrors iOS `StartupGuard`:
- On boot, read `notepad3pp.layoutMode.pendingClassic` flag.
- If set and older than 1.5 s, force `layoutMode = mobile` to break a classic-mode render loop.
- On a successful classic render (after 1.5 s of stable layout), clear the flag.

Implementation: `MainActivity.onCreate` reads the flag and the timestamp; a `LaunchedEffect(Unit)` with a 1.5 s `delay` clears it once the classic chrome has settled.

## 7. Theming

### 7.1 8 named palettes

`Palette` is a `data class` with the 19 fields the iOS port has (foreground, mutedForeground, background, card, muted, primary, primaryForeground, secondary, accent, border, editorBackground, editorGutter, success, destructive, titleGradientStart, titleGradientEnd, chromeGradientStart, chromeGradientEnd, radius). Each named palette is a `companion object` constant on `Palette`, hex values copied from the iOS Swift source verbatim.

### 7.2 Theme resolution

`ThemeController` exposes `palette: StateFlow<Palette>`. Resolution:
- If `themePreference == "system"`: pick `light` or `dark` based on `Configuration.uiMode & Configuration.UI_MODE_NIGHT_MASK`.
- If `"named:custom"`: start from `light`, overlay user's hex overrides from `Preferences.customPalette`.
- Else: the named palette.

System dark-mode changes: `MainActivity` overrides `onConfigurationChanged` (with `android:configChanges="uiMode"` on the manifest) to forward the new mode to `ThemeController.updateSystemStyle(isDark = ...)`. The flow re-emits, the chrome re-paints. No restart.

### 7.3 Compose bridging

A `LocalPalette` `CompositionLocal` is provided at the root, fed from `ThemeController.palette.collectAsState()`. Every chrome composable reads `LocalPalette.current` rather than `MaterialTheme.colorScheme`. We ship a `MaterialTheme` configured with neutral colors only because some Compose components (e.g. `TextField`) leak through; our actual theming is via `LocalPalette`.

### 7.4 Aero on Material 3 — the override list

The default Material 3 theme on Android will fight us:
- **Rounded corners everywhere** → set `Shape.None` family-wide; use rectangular `RoundedCornerShape(palette.radius.dp)` only where the palette demands it.
- **Soft drop shadows on cards** → `Modifier.shadow(0.dp)` on every card; use 1px `Modifier.border(BorderStroke(Dp.Hairline, palette.border))` instead.
- **Material You dynamic color** → opt out via `dynamicColor = false` (or never call `dynamicLightColorScheme`).
- **Ripples** → keep, but recolor to `palette.primary.copy(alpha = 0.2f)`.
- **TextField underlines / outline** → `TextFieldDefaults.colors(...)` with all line/border colors set to `Color.Transparent`; we draw our own borders.

Document this approach in code (one comment block) so future readers understand why we don't "just use Material defaults."

## 8. Editor

### 8.1 EditText interop

```kotlin
@Composable
fun EditorTextArea(
    body: String,
    onBodyChange: (String) -> Unit,
    selection: IntRange,
    onSelectionChange: (IntRange) -> Unit,
    palette: Palette,
    syntaxHighlighter: SyntaxHighlighter,
) {
    AndroidView(
        factory = { ctx ->
            EditText(ctx).apply {
                background = null
                setText(body, BufferType.SPANNABLE)
                addTextChangedListener(SyntaxHighlightingWatcher(syntaxHighlighter))
                addTextChangedListener(UndoTrackingWatcher(undoStack))
            }
        },
        update = { editText ->
            // Apply theme: text color, cursor color, gutter color
            // Sync selection from Compose state (only when externally set)
            // Re-bind body if it changed externally (e.g. switched note)
        }
    )
}
```

Key behaviors:
- `SpannableStringBuilder` is the underlying buffer. Syntax highlighting attaches `ForegroundColorSpan`, `BackgroundColorSpan`, `StyleSpan` instances.
- Re-tokenization triggered by `TextWatcher.afterTextChanged`. Phase 1 does full retokenization; Phase 5 adds incremental.
- Selection state is the source of truth in Compose; the `EditText` is a projection. Two-way binding via `setSelection` in `update`, `OnSelectionChangedListener` (custom subclass) emitting upward.

### 8.2 Undo / redo

Hand-rolled stack:

```kotlin
sealed interface EditOp {
    val timestamp: Long
    fun apply(buffer: Editable)
    fun undo(buffer: Editable)
}

data class TextEditOp(
    override val timestamp: Long,
    val start: Int,
    val removed: CharSequence,
    val inserted: CharSequence,
) : EditOp { ... }

class UndoStack(private val limit: Int = 1024) {
    private val past = ArrayDeque<EditOp>()
    private val future = ArrayDeque<EditOp>()
    fun record(op: EditOp) { past.addLast(op); future.clear(); if (past.size > limit) past.removeFirst() }
    fun undo(buffer: Editable) { past.removeLastOrNull()?.also { it.undo(buffer); future.addLast(it) } }
    fun redo(buffer: Editable) { future.removeLastOrNull()?.also { it.apply(buffer); past.addLast(it) } }
    val canUndo get() = past.isNotEmpty()
    val canRedo get() = future.isNotEmpty()
}
```

Coalescing: typing-runs collapse into a single op (gap of >500 ms ends the run). Programmatic mutations (sort lines, trim, paste, etc.) each emit one op explicitly via a `Mutator` helper.

### 8.3 Selection helpers

Direct ports of iOS `EditorViewController` methods, operating on `Editable`:
- `selectWord()`, `selectLine()`, `selectParagraph()`, `selectAll()`
- `duplicateCurrentLine()`, `deleteCurrentLine()`
- `sortLines()` (sorts current selection or whole document)
- `trimTrailingSpaces()`
- `insertText(s)` — used for date insert + paste
- `deleteBackwardFromCaret()` — used by the D-pad's Delete key
- `gotoLine(n)` — set selection to start of line n

### 8.4 Arrow keys and Shift toggle

Same model as iOS:
- `shiftAnchor: Int?` lives in `EditorViewModel`. When non-null, arrow taps extend selection from anchor.
- A `programmaticSelectionChange` flag prevents user-driven taps from clearing the anchor when we're the one moving the caret.
- Shift toggle on the keyboard accessory's D-pad flips `shiftAnchor` between `null` and `currentCaret`.
- Any tap-to-position, drag-select, or explicit selection command (Word, Line, All, Paste, Cut) clears the anchor.

### 8.5 Find / replace

`findreplace/FindReplaceBar.kt` — Compose composable that slides in from the top with `AnimatedVisibility`. Three toggle chips (Aa / W / .* for case / whole-word / regex). Uses `Pattern.compile` with appropriate flags.

Highlighting: `BackgroundColorSpan(palette.success)` on each match in the editor's `SpannableStringBuilder`. Current match: stronger highlight. Spans are removed on bar dismiss.

## 9. Keyboard accessory bar — THE hard part

### 9.1 Goal

Match the iOS `KeyboardAccessoryView`: a 88pt-tall bar above the IME with:
- Static 3×2 D-pad cluster pinned to leading edge: `[Shift][↑][Delete] / [←][↓][→]`
- Horizontally-scrolling supporting bar to the right with the rest of the accessory items (Hide, Cut/Copy/Paste, selectors, Undo/Redo, Read, Find/Replace, Date, Open, Compare, More)
- 1-row or 2-row mode for the scrolling supporting bar (`Preferences.accessoryRows`)

### 9.2 Implementation plan

`AccessoryBar` is a `@Composable` rendered above the IME using `Modifier.imePadding()` plus `WindowInsetsCompat.Type.ime()` to detect IME visibility. The bar itself sits in a `Box` at the bottom of the screen with `Modifier.windowInsetsPadding(WindowInsets.ime)`.

When the IME is hidden, the accessory bar hides too. When the IME slides up, the bar lifts with it.

### 9.3 Why this is hard

| Challenge | Mitigation |
|---|---|
| IME heights vary by keyboard app (Gboard, Samsung, SwiftKey, FleksyKB) by 30+pt. | `WindowInsetsCompat.Type.ime()` reports actual height. Test on all four major IMEs in CI smoke test (Phase 3). |
| API <30 IME inset reporting is unreliable. | Min SDK 30 — locked. |
| Some IMEs show their own row of suggestions above their keys; ours sits on top, but visually awkward. | Accept; user can dismiss IME suggestions per-keyboard. |
| Auto-repeat for held arrow keys (220 → 120 → 60 ms). | `Modifier.pointerInput` + `awaitPointerEventScope` + a coroutine-driven repeating job that cancels on `PointerEventType.Release`. |
| Rotation: IME heights change. | Recompute on `onConfigurationChanged`. |

### 9.4 Phase scope

Phase 3 of the implementation plan is dedicated to this. No other features in Phase 3 — it's hard enough to deserve its own milestone. Proof-of-acceptance: sideload on a Pixel + a Samsung running stock keyboard + Gboard + SwiftKey, confirm bar anchors above each keyboard without overlap or floating gap.

## 10. Layout modes

### 10.1 Mobile layout

Top: standard Android `TopAppBar` (Compose) showing the active note title + nav-bar buttons (New / Find / Theme toggle / More).
Body: editor.
Bottom: `MobileBottomBar` (5 equal cells: File, Find, Compare, Classic [layout switcher], More). FAB in the bottom-right (anchored above the bottom bar).

### 10.2 Classic layout

Top to bottom:
- `ClassicTitleBar` — gradient bar showing active note title.
- `AeroMenuBar` — File · Edit · View · Tools · Help, each a button that opens a `ClassicMenuPopover`. Trailing edge: layout-switcher button (glyph: `mobile` / phone icon).
- `ClassicToolbar` — horizontally-scrolling icon button bar with the same set of buttons as iOS. 1- or 2-row per `toolbarRows`. Optional text labels per `toolbarLabels`.
- `TabStripView` — `tabs` mode shows horizontally-scrolling tab cells; `list` mode shows a compact bar with active title + chevron-to-list.
- Editor (with `LineGutter` to the left).
- `StatusBar` — bottom strip with line/column / language / theme.

### 10.3 Layout switcher

Always-visible button in both modes:
- Mobile: 5th button on the bottom bar, glyph `desktop_windows`, label "Classic", taps switch `Preferences.layoutMode` to `classic`.
- Classic: trailing-edge button on `AeroMenuBar`, glyph `phone_iphone`, taps switch to `mobile`.

Each glyph depicts the destination, mirroring iOS.

### 10.4 Aero menu popover

`ClassicMenuPopover` is a Compose `Popup` styled flat (`Surface(shape = RectangleShape, shadowElevation = 0.dp, border = BorderStroke(Hairline, palette.border))`). Items render as `Row { Icon, Spacer, Text, Spacer, OptionalCheckmark }` with hover/press background `palette.primary`. Submenus open as a second `Popup` aligned to the row's trailing edge.

## 11. Syntax highlighting

`SyntaxHighlighter` is a regex-based tokenizer matching iOS's exact rules:

1. Block comments (`/* ... */`) — C-style languages only
2. Line comments (`//`, `#`, `;`)
3. Template strings (backtick, with escape support)
4. Regular strings (single/double-quoted, same-line)
5. Numbers (decimal, float, hex)
6. Identifiers (keywords, registers, function-call detection)
7. Decorators (`@identifier`, JS only)
8. Operators

7 languages: Plain, Markdown, Assembly, JavaScript, Python, Web (HTML/CSS), JSON. Keyword/register sets ported verbatim from `Editor/SyntaxHighlighter.swift`.

Phase 1 ships full re-tokenization on every keystroke. Phase 5 adds:
- Off-thread tokenization on the IO dispatcher
- Incremental retokenization (only the changed line range)
- Profiling with Android Studio CPU profiler — target <8 ms per keystroke on a 10k-line file (matches iOS Pixel 4 baseline)

## 12. Markdown preview

`Markwon` library, rendered into a `TextView` inside an `AndroidView`, swapped in for the editor when `previewMode` is on and `note.language == .markdown`. Live re-render on body change (debounced 200 ms).

## 13. Settings

Compose-based screen with the same sections as iOS:
- **Theme** — match system + 8 named themes
- **Appearance** — tabs layout, toolbar labels, toolbar rows, accessory rows
- **Layout Mode** — mobile vs classic
- **Starter Content** — welcome vs blank
- **Custom Palette** — entry point to `CustomPaletteBuilder`

`CustomPaletteBuilder` is a screen with a list of 19 palette fields; tapping a field opens a Material color picker (or a hex input). Changes write to `Preferences.customPalette` immediately (no Save button — autosaved like iOS).

## 14. Build system & CI

### 14.1 Local build

```
cd artifacts/android-native
./gradlew assembleDebug
# → app/build/outputs/apk/debug/app-debug.apk
```

Requires JDK 17 on `JAVA_HOME` and `Android SDK` (cmdline-tools is enough; full Studio not required).

### 14.2 CI workflow

`.github/workflows/build-android-native.yml` (planned in Phase 0). Mirrors the structure of the now-deleted RN Android workflow (which we can reference from `archive/rn-garbage`):
- `runs-on: ubuntu-latest`
- `actions/setup-java@v4` with Temurin 17
- `gradle/actions/setup-gradle@v4` (cache wrapper + dep cache)
- `./gradlew assembleDebug --no-daemon --stacktrace`
- Upload artifact `notepad3-android-debug-apk`

Trigger: `workflow_dispatch` + push of `android-native-v*` tags.

Expected first build time: 8–12 minutes cold; 4–6 warm.

### 14.3 Sideloading

User downloads the APK artifact from CI, transfers to an Android device with `adb install` or a file-share method, taps to install (developer install permission required from device settings).

## 15. Risks

1. **Keyboard accessory anchoring.** Hard. Mitigated by min SDK 30 + dedicated phase.
2. **Aero on Material 3.** Long override list; documented in §7.4.
3. **Syntax highlighting performance on 10k+ line files.** Initial implementation re-tokenizes everything on each keystroke. Acceptable for v1; Phase 5 optimizes.
4. **Undo/redo coalescing edge cases.** Built day 1; first hands-on test confirms behavior.
5. **Configuration changes destroying Activities.** Architected for it (state in ViewModel/Flow). Easy to forget; lint rules in CI will catch leaks.
6. **Different IMEs reporting different heights.** Tested against four major Android keyboards as part of Phase 3 acceptance.
7. **Material color theming leaking through Compose components.** Mitigated by aggressive override list and a custom `LocalPalette`.
8. **Custom palette builder UI.** Material color picker doesn't exist out-of-box; will need to write or pull a small lib (`com.github.skydoves:colorpickerview`). Decide in Phase 6.
9. **No Hilt → manual singletons.** Tested at the iOS scale; should be fine, but be vigilant about thread-safety on `NotesStore` since multiple ViewModels read/write.
10. **`EditText` long-press menu can collide with our keyboard accessory.** Native Android shows Cut/Copy/Paste in a contextual menu on long-press; ours offers similar via the accessory. We accept the redundancy — the system menu is accessibility-driven.

## 16. Phased delivery — implementation roadmap

Each phase ships a green CI run + a sideloaded debug APK that demonstrates new functionality without regressing prior phases.

### Phase 0 — Skeleton + CI + first APK builds green

- Empty `MainActivity` with "Hello, Notepad 3++" Compose text.
- `app/build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`, `libs.versions.toml`, gradle wrapper.
- `.github/workflows/build-android-native.yml` produces `notepad3-android-debug-apk`.
- **Verification:** workflow green; APK installs and shows the hello text.

### Phase 1 — Editor + persistence + theme

- `NotesStore` with notes-v1.json, `Preferences`, `ThemeController`.
- `EditText` interop, hand-rolled `UndoStack`, basic `EditorViewModel`.
- 8 named palettes, `LocalPalette` Compose bridge.
- Mobile layout only (no classic yet): top bar with title + new-doc, editor, no chrome below.
- Tap-and-type works; undo/redo works; theme switch live-applies.
- **Verification:** make a note, type, undo, redo. Switch themes. Force-quit; relaunch; note + theme persisted.

### Phase 2 — Tabs + dual-mode chrome

- `TabStripView` (tabs + list modes).
- Mobile bottom bar (5 cells incl. layout switcher) + FAB.
- Classic layout: title bar, Aero menu bar with flat dropdowns, classic toolbar (1/2 row, optional labels), tab strip, status bar, line gutter.
- `Preferences.layoutMode` toggles between modes; layout switcher button works in both.
- **Zen mode** wired in this phase since it's a chrome operation (hide everything except the editor). Implementation mirrors iOS's constraint-set-swap pattern: a separate `ZenLayout` composable that renders only the editor pinned to safe area; entering zen swaps the root from the active mode's layout to `ZenLayout`. Find-bar visibility is restored on exit. Exit affordance is reachable from the keyboard accessory's More sheet (added in Phase 3).
- Aero override list applied; classic theme looks like iOS classic theme.
- **Verification:** sideload, tap layout switcher, mode toggles. Each menu in classic opens a flat dropdown. Zen toggles in/out and the editor actually grows. Toolbar buttons fire callbacks (no-op stubs OK for some).

### Phase 3 — Keyboard accessory bar + D-pad cluster

- `AccessoryBar` anchored above the IME via `imePadding()` / `WindowInsetsCompat.Type.ime()`.
- Static 3×2 D-pad cluster on the leading edge.
- Scrolling supporting bar with the same buttons as iOS.
- Shift toggle + arrow-extension behavior.
- Auto-repeat (220 → 120 → 60 ms ramp) on held D-pad arrows + Delete.
- **Verification:** sideload. Open note. Keyboard appears. D-pad above IME. Press-and-hold arrow auto-repeats. Tap Shift, then arrow → selection extends. Switch to Gboard, Samsung Keyboard, SwiftKey — bar anchors correctly each time.

### Phase 4 — Find/replace + selection helpers + line tools + Read mode + Compare

- Find/replace bar with regex/case/word toggles; navigate matches; replace one / replace all.
- Word/Line/All/Paragraph selection.
- Sort lines, trim spaces, duplicate line, delete line, goto line.
- Insert date.
- **Read mode** — `editText.isEnabled = !readMode` plus a visual lock affordance (lock icon in the title-bar trailing area on classic, in the top-app-bar on mobile). Toggle via the toolbar's Read button + the keyboard-accessory Read button.
- **Compare modal** — `CompareScreen` Compose composable presented as a full-screen modal. Two synchronized `LazyColumn`s rendering each note's lines, each line annotated with a per-line status (added / modified / removed / unchanged) computed by a basic LCS-based line-diff. Side-by-side on landscape, top-bottom on portrait. Picker chips at the top to select left and right notes from the open set.
- **Verification:** open a multi-line note; find a token; replace; sort; goto line. Toggle Read mode → editor refuses input + lock icon appears. Open Compare → pick two notes → diff renders → scroll one side → other follows.

### Phase 5 — Syntax highlighting + markdown preview

- `SyntaxHighlighter` for 7 languages with the same regex pipeline as iOS.
- Off-thread tokenization for files > 1k lines.
- Incremental retokenization (line-range only).
- Markdown preview via Markwon, debounced 200 ms.
- **Verification:** load a 5k-line JS note; type at the bottom; no jank. Markdown note → toggle preview → renders correctly with live updates.

### Phase 6 — Settings + custom palette builder

- Settings screen (Compose).
- Theme picker, prefs toggles, layout-mode picker.
- Custom palette builder — list of 19 fields, tap to open color picker, hex input fallback, persists immediately.
- **Verification:** change every preference; force-quit; relaunch; everything restored. Build a custom palette; it shows up as the 9th theme option.

### Phase 7 — Polish

- Haptics on every primary interaction (note switch, palette pick, undo, paste, etc.) using `VibrationEffect.createPredefined(EFFECT_TICK)` etc.
- A11y: TalkBack labels for all chrome buttons; `AccessibilityNodeInfo` overrides where Compose's defaults are wrong.
- Animations: theme switch crossfade, find-bar slide, layout-mode crossfade, zen-mode collapse.
- Edge cases: empty state, very long titles, invalid JSON on load (fall back to `welcome`), out-of-disk-space on save.
- Verified running on Android 11 (min SDK), Android 14 (target), Pixel + Samsung phones.
- **Verification:** sideload final APK; comprehensive manual test plan; release candidate.

---

## 17. iOS ↔ Android term mapping (glossary)

| iOS / Swift | Android / Kotlin |
|---|---|
| `UIViewController` | `Activity` (top-level) or `@Composable` function (sub-screens) |
| `UIView` | `View`, or `@Composable` function |
| `UITextView` | `EditText` |
| `NSTextStorage` | `Editable` / `SpannableStringBuilder` |
| `NSAttributedString` | `Spanned` / `SpannableString` |
| `NSTextStorageDelegate` | `TextWatcher` |
| `UITextViewDelegate` | (No direct equivalent; use `TextWatcher` + `OnSelectionChanged` listener subclass) |
| `undoManager` | hand-rolled `UndoStack` |
| `UIInputViewController` / `inputAccessoryView` | Compose `AccessoryBar` anchored via `imePadding()` |
| `UIDragInteraction` | `View.startDragAndDrop` (when needed) |
| `UIPasteboard` | `ClipboardManager` |
| `UIMenu` | Compose `Popup` (we use a custom flat one — `ClassicMenuPopover`) |
| `UIScrollView` | `LazyRow` / `Modifier.horizontalScroll` |
| `UICollectionView` | `LazyRow` / `LazyColumn` |
| `UITableView` | `LazyColumn` with section headers |
| `CAGradientLayer` | `Brush.verticalGradient` / `Brush.horizontalGradient` |
| `UIDocumentPickerViewController` | `Intent.ACTION_OPEN_DOCUMENT` via `ActivityResultContracts.OpenDocument` |
| `UITraitCollection` (dark mode) | `Configuration.uiMode` |
| `UIImpactFeedbackGenerator` | `VibrationEffect.createPredefined(EFFECT_TICK)` |
| `UISelectionFeedbackGenerator` | `VibrationEffect.createPredefined(EFFECT_CLICK)` |
| `NSRegularExpression` | `java.util.regex.Pattern` |
| `UserDefaults` | `SharedPreferences` |
| `safeAreaLayoutGuide` | `WindowInsets.systemBars` / `Modifier.systemBarsPadding` |
| `inputAccessoryView` | `Modifier.imePadding()` + `WindowInsets.ime` |

## 18. Out of scope — explicit non-goals reiterated

- Tablet / foldable / Wear OS / Auto / TV / ChromeOS layouts
- Material You dynamic color
- Cloud sync, accounts, multi-device
- Play Store distribution / release signing / AAB
- Virtual trackpad, pointer overlay
- NDK / native code
- Sharing a runtime or business logic with the iOS app

---

## 19. Success criteria

The Android port is "done" when:

1. CI green for ≥ 7 consecutive runs.
2. Sideloaded APK runs on a real Android 11+ device without crashes during a 30-minute manual test session covering: create / edit / save / open / theme switch / layout switch / find-replace / undo / D-pad navigation / shift-extend / settings / custom palette / multi-tab.
3. All 8 themes render legibly.
4. Both layout modes work and the always-visible switcher button appears in both.
5. Keyboard accessory bar anchors correctly above Gboard, Samsung Keyboard, and one third-party IME (SwiftKey or Fleksy).
6. Undo/redo handles a typing session of ≥ 1k characters without dropping operations.
7. Files of 10k+ lines remain editable without > 200 ms keystroke latency (Phase 5 optimization may be required).
8. The user (Corey) signs off after one or more rounds of sideloaded testing.

This spec is the contract for that work.
