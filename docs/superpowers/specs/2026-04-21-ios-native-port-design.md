# Notepad 3++ — Native iOS Swift Port Design

**Status:** spec for review
**Date:** 2026-04-21
**Author:** Claude (Opus 4.7) with Corey
**Scope:** 1-for-1 feature port of the React Native Notepad 3++ app to native Swift/UIKit for iOS 16+

> **2026-04-26 update — RN archived.** The React Native / Expo app was removed from this repo on 2026-04-26 and preserved on the `archive/rn-garbage` branch. The Swift port at `artifacts/ios-native/` is now the *only* iOS path, not a parallel one to a live RN app. Anywhere this doc says "RN is the oracle" or "match the RN behavior" should be read as historical / aspirational at the moment of the port, not as ongoing parity work. Any salvage (assets, behavior references) comes from the archive branch. A native Android port is planned as a sibling (separate spec).

---

## 1. Context

`artifacts/mobile/` is a React Native 0.81.5 / Expo 54 app that hit walls the RN layer couldn't cleanly solve: classic-mode rendering crashes, no native undo, no native syntax coloring, bloated third-party libs for things iOS gives for free. After multiple iterations we decided to rebuild it in Swift/UIKit under `artifacts/ios-native/`, keeping the RN app intact as the authoritative spec. When this Swift port reaches parity + stability, it can be extracted into its own repo with `git filter-repo --subdirectory-filter artifacts/ios-native`.

**The RN app is the oracle.** Every design question answered by: "what does the RN app do?" We match behavior, not implementation detail. We do not re-design.

## 2. Goals & Non-goals

**Goals:**
- Visual + behavioral 1-for-1 parity with the RN app (themes, menus, tabs, editing, find/replace, compare, settings, starter content, classic vs mobile layout)
- Use native iOS primitives where RN was compromising (UITextView undoManager, NSTextStorage syntax coloring, UIInputViewController keyboard accessory, UIDocumentPickerViewController, UIMenu, haptic generators)
- Autosave parity: everything persists immediately to local disk, exactly like the RN app
- Build green on macOS CI every PR (Corey cannot build Swift locally on WSL)

**Non-goals (deferred):**
- iPad-specific UI
- Mac Catalyst / visionOS
- iCloud / CloudKit sync
- Any multi-device collaboration
- Any feature the RN app does not already have
- Extracting into a separate repo (comes later; stays in-tree for now)

## 3. Design philosophy

**RN-first diffing:** For every Swift file we write, we maintain a pointer to its RN source-of-truth. Drift gets caught in code review.

**UIKit over SwiftUI for the editor:** SwiftUI's `TextEditor` hides too much of `UITextView`. We need direct access to `textStorage`, `selectedRange`, `inputAccessoryView`, `undoManager`. Settings + chrome *can* be SwiftUI, but we start everything in UIKit for simplicity and one mental model.

**Native idioms over RN idioms:** iOS has undoManager — we use it, not a hand-rolled ring buffer. iOS has UIMenu — we use it, not a custom dropdown. iOS has haptic generators — we use them directly. We don't reproduce RN's Context pattern; we use singletons + KVO-like observer tokens, which the current `NotesStore` already does.

**Isolated modules:** Each unit has one purpose, one file (or a small group), well-defined inputs and outputs. An editor module should be explainable in a paragraph. A theme palette should be changeable without touching the editor. A syntax highlighter should be swappable.

---

## 4. Phase 0 — CI build verification (blocker for everything else)

**Problem:** Corey's dev host is WSL Ubuntu. There is no `swiftc` or Xcode on Linux. Every "this compiles" claim is unverifiable locally. Without CI, every PR is a faith act until he next has a Mac in front of him.

**Solution:** Add `.github/workflows/ios-native-build.yml`:
- Trigger: push + PR touching `artifacts/ios-native/**` or the workflow itself
- Runs on: `macos-latest`
- Steps: install xcodegen (`brew install xcodegen`), `xcodegen generate`, `xcodebuild -scheme Notepad3 -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO`
- Optional second step (stretch): boot a simulator and run UI smoke tests

**Gate:** No feature PR lands until this workflow is green on `main`. Everything after Phase 0 is built PR-by-PR, each of which must keep the workflow green.

**Verification of Phase 0 itself:** A trivial "hello" change lands and the workflow succeeds.

---

## 5. Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    SceneDelegate                            │
│   chooses root VC based on ThemePreferences.layoutMode     │
└──────────────┬─────────────────────────────────┬───────────┘
               │ mobile                          │ classic (deferred)
               ▼                                 ▼
    ┌─────────────────────┐          ┌──────────────────────┐
    │  MobileRootVC        │         │  ClassicRootVC       │
    │  - title bar         │         │  - Aero title bar    │
    │  - tab strip         │         │  - menu bar          │
    │  - EditorVC (child)  │         │  - sidebar list      │
    │  - bottom action bar │         │  - EditorVC (child)  │
    └──────────┬──────────┘          └──────────┬──────────┘
               │                                 │
               └─────────────┬───────────────────┘
                             ▼
                  ┌──────────────────────┐
                  │   EditorViewController│
                  │   - UITextView        │
                  │   - NSTextStorage     │◄──── SyntaxHighlighter
                  │   - inputAccessoryView│◄──── KeyboardToolbar
                  │   - findBar (optional)│◄──── FindReplaceController
                  └─────────┬────────────┘
                            │ observes
                            ▼
                  ┌──────────────────────┐          ┌─────────────────┐
                  │   NotesStore         │◄────────►│ ThemePreferences│
                  │   (singleton)        │          │ (singleton)     │
                  │   Documents/notes.json│         │ UserDefaults    │
                  └──────────────────────┘          └─────────────────┘
```

**Four singletons:** `NotesStore.shared` (already built), `ThemePreferences.shared` (new), `AppEnvironment.shared` (crash recovery flag + current palette resolver). Haptics, pasteboard are accessed via framework singletons.

**Observer pattern (already in NotesStore):** UUID tokens, closure-keyed — ported to `ThemePreferences` too. No Combine / no RxSwift; just closure observers.

**Crash recovery parity:** RN uses `LAYOUT_PENDING_KEY` set on classic-mode boot, cleared after 1.5s. Swift port does the same: on `didFinishLaunching` we check a UserDefaults flag, downgrade to mobile if it was left set, set it if we're booting classic, clear it on `viewDidAppear + 1.5s`.

---

## 6. RN → Swift cross-reference table

Every RN artifact maps to a Swift destination. This table is the audit checklist for "is it 1-for-1?"

| RN source (file :: symbol) | Swift destination (file :: type :: method) | Status |
|---|---|---|
| `context/NotesContext.tsx :: NoteDocument` | `Models/Note.swift :: Note` | ✅ done |
| `context/NotesContext.tsx :: starterNote` | `Models/Note.swift :: Note.welcome` | ✅ done |
| `context/NotesContext.tsx :: detectLanguageFromFileName` | `Models/NoteLanguage.swift :: NoteLanguage.detect(fromFileName:)` | ✅ done |
| `context/NotesContext.tsx :: NotesProvider` | `Persistence/NotesStore.swift :: NotesStore` | ✅ done (CRUD complete) |
| `context/NotesContext.tsx :: undo/redo history ring` | `Editor/EditorViewController.swift :: uses UITextView.undoManager` | ❌ (drop RN's ring; use native) |
| `context/ThemeContext.tsx :: ThemeProvider` | `Persistence/ThemePreferences.swift :: ThemePreferences` | ❌ to build |
| `context/ThemeContext.tsx :: resetLayoutModeToMobile` | `Persistence/ThemePreferences.swift :: resetLayoutModeToMobile()` | ❌ to build |
| `constants/colors.ts :: themes` | `Models/Theme.swift :: Palette.{classic,light,dark,retro,modern,cyberpunk,sunset,custom}` | ⚠️ 3/8 done (classic, light, dark) |
| `constants/colors.ts :: buildCustomPalette` | `Models/Theme.swift :: Palette.build(custom:)` | ❌ to build |
| `app/_layout.tsx :: providers` | `App.swift :: SceneDelegate.scene(_:willConnectTo:options:)` | ⚠️ stub exists (hardwired root = EditorViewController); needs ThemePreferences boot + crash-recovery flag check + MobileRootVC wrapper, classic root chooser deferred with M14 |
| `app/index.tsx :: editor TextInput (uncontrolled)` | `Editor/EditorViewController.swift :: textView` | ⚠️ stub exists, needs undo, syntax, accessory |
| `app/index.tsx :: handleUndo / handleRedo` | `Editor/EditorViewController.swift :: textView.undoManager.undo/redo` | ❌ to wire |
| `app/index.tsx :: tokenizeLine + SyntaxLine + SyntaxPreview` | `Editor/SyntaxHighlighter.swift :: SyntaxHighlighter : NSObject, NSTextStorageDelegate` | ❌ to build |
| `app/index.tsx :: menuBar + DropdownItem + openMenu` | `UI/MenuBarView.swift :: UIMenu-backed buttons` (classic only) | ❌ to build, deferred |
| `app/index.tsx :: DocumentTab + tabsLayout` | `UI/TabStripView.swift :: UICollectionView horizontal` | ❌ to build |
| `app/index.tsx :: tabMenuId action sheet` | `UI/TabActionSheet.swift :: UIAlertController + UIMenu` | ❌ to build |
| `app/index.tsx :: toolbar + TbItem rendering` | `UI/MobileActionBar.swift :: UIStackView of UIButton` | ❌ to build |
| `app/index.tsx :: accessory KbBtn + KbHoldBtn + KbSep` | `UI/KeyboardToolbar.swift :: UIInputView subclass` | ❌ to build |
| `app/index.tsx :: MouseOverlay (virtual trackpad)` | `UI/VirtualTrackpadView.swift :: UIView + UIPanGestureRecognizer` | ❌ to build |
| `app/index.tsx :: find + replace bar` | `UI/FindReplaceBar.swift :: UIView + 2×UITextField + next/prev/replace/replaceAll` | ❌ to build |
| `app/index.tsx :: compareDocuments + ComparePane` | `UI/CompareViewController.swift :: UISplitViewController (horizontal split on iPhone)` | ❌ to build |
| `app/index.tsx :: sortLines/trimTrailingSpaces/duplicateCurrentLine/deleteCurrentLine/insertTextAtSelection/selectLine/selectParagraph/selectAll/moveCursorBy/moveCursorVertical` | `Editor/EditorActions.swift :: extension EditorViewController` | ❌ to build |
| `app/index.tsx :: importFromFiles (DocumentPicker)` | `UI/DocumentPicker.swift :: DocumentPickerController : UIDocumentPickerViewController` | ❌ to build |
| `app/index.tsx :: Settings sheet (Tools > Preferences)` | `UI/SettingsViewController.swift :: UITableViewController` | ❌ to build |
| `components/ErrorBoundary.tsx :: componentDidCatch + recordCrash` | `App.swift :: NSSetUncaughtExceptionHandler + crash flag in UserDefaults` | ❌ to build |
| `lib/crashLog.ts :: recordCrash/readLastCrash` | `Persistence/CrashLog.swift :: CrashLog` | ❌ to build |

---

## 7. Module breakdown + verification criteria

Each module has a **purpose**, a **done-when** criterion that is verifiable from the CI build + simulator screenshots. "Will verify" not "will work."

### M0 — CI build workflow (Phase 0)
- **Purpose:** Block every later PR on macOS build
- **Done when:** `.github/workflows/ios-native-build.yml` runs on every push to `artifacts/ios-native/**`, succeeds on main, comments on PR with result
- **Risk:** need to confirm Corey's macOS runner budget / chosen action versions — reuse the same actions already present in his YTAfterglow IPA workflow

### M1 — Models + Persistence
- **Purpose:** Single source of truth, JSON autosave
- **Status:** ✅ already built
- **Done when:** `NotesStore` unit tests pass (smoke: create → update → load → survive restart). Manual verify: tap, type, force-quit, relaunch, content is there.

### M2 — Theme palettes + ThemePreferences
- **Purpose:** 8 palettes + persistence for every non-note setting the RN app persists
- **Done when:** Every RN AsyncStorage key has a Swift UserDefaults counterpart with matching types and key names (`notepad3pp.themePreference`, `notepad3pp.tabsLayout.v2`, `notepad3pp.toolbarLabels`, `notepad3pp.toolbarRows`, `notepad3pp.customPalette`, `notepad3pp.layoutMode`, `notepad3pp.layoutMode.pendingClassic`, `notepad3pp.accessoryRows`, `notepad3pp.starterContent`). `Palette` struct has parity with RN's `Palette` type (note: RN has `titleGradient: [string, string]` — Swift uses `[UIColor]` of length 2, helper on CAGradientLayer). Manual verify: Settings > Theme, pick each of the 8, editor background + chrome gradient recolor live.
- **Note:** AsyncStorage and UserDefaults are independent stores — Swift first-launch sees fresh defaults, not migrated state. We accept that. Fresh launch starter content will be the welcome note unless user has set blank in the Swift app's own settings.
- **Parallelizable:** yes (independent of editor core)

### M3 — EditorViewController (core)
- **Purpose:** The text-editing surface. UITextView bound to active note body with autosave on every change, selection preserved across note switches.
- **Done when:**
  - Type a char → NotesStore persists it within one run loop
  - Switch note → new body loads, selection resets to 0 (matches RN's `key={activeNote.id}` remount)
  - Typing preserves undo stack; shake-to-undo works; Cmd-Z from external keyboard works
  - Programmatic body mutations (paste, sort lines, insert text, etc. from M4) register undo entries
  - Palette colors apply + respond to `ThemePreferences` observer
- **Blocker for:** M5, M7, M9, M10, M11
- **Serial (do first)**

### M4 — EditorActions (line tools, cursor moves, select variants, paste)
- **Purpose:** All the Edit-menu and toolbar actions except undo/redo/find
- **Done when:** 10 actions (sort / trim / dedupe / replace / insertText / dupLine / deleteLine / selectLine / selectParagraph / selectAll) work + moveCursorBy/Vertical work + cut/copy/paste via UIPasteboard. Each has a RN test-case: take the same input in RN and Swift, selection, press button, assert matching post-state.
- **Depends on:** M3

### M5 — SyntaxHighlighter (NSTextStorage coloring)
- **Purpose:** On-the-fly coloring via NSTextStorageDelegate. Per-language keyword/register/comment/string/number maps — drop-in logic port of `tokenizeLine` + `tokenColor`.
- **Done when:** Switching language in the Settings updates all visible coloring within 1 frame; typing a keyword in JS/Python bolds it; semicolon-prefix lines in assembly grey out; string/number highlighting matches RN.
- **Depends on:** M3 (has textStorage access)
- **Risk:** 10k-line file performance. Test: open a 10k-line .asm file, measure typing lag. Target < 16ms per keystroke. If we regret: switch to incremental invalidation of only the edited paragraph range.

### M6 — DocumentPicker (Open any file)
- **Purpose:** File > Open lets the user open any file from Files.app, reads it, creates a new note with detected language
- **Done when:** Open a .swift file from iCloud Drive → note opens with `language == .javaScript` (or .plain if unsupported extension) + body populated; repeat with .asm, .md, .py, .json
- **Parallelizable:** yes (isolated, uses only UIDocumentPickerViewController + NotesStore.importNote)

### M7 — KeyboardToolbar (inputAccessoryView)
- **Purpose:** Exact parity with RN's accessory row — copy/cut/paste/undo/redo/arrows/hold-to-accelerate/sep/close-keyboard, single or double row based on preference
- **Done when:** Focus editor → accessory appears; tap copy, tap paste into another app, content matches; arrow buttons move cursor; hold arrow for 600ms → acceleration kicks in; swap to double-row in Settings → 2 rows appear
- **Depends on:** M3 (accessoryView attached to textView), M4 (action wiring)

### M8 — TabStrip + TabActionSheet
- **Purpose:** Horizontal tab strip across top; long-press tab → action sheet (rename/close/closeOthers/duplicate/delete); tapping tab switches
- **Done when:** Multiple notes visible; tap switches instantly; long-press opens UIAlertController with matching items; every action persists through NotesStore
- **Depends on:** M3 (not the editor per se, but the root chrome composition)

### M9 — MobileActionBar
- **Purpose:** Bottom bar with the primary actions for mobile mode (when keyboard is hidden; accessory takes over when keyboard is up)
- **Done when:** With keyboard down, bar shows at bottom; with keyboard up, bar auto-hides in favor of keyboard accessory; bar shows proper icons (Open, New, Save-indicator, Settings, Find, Compare)
- **Depends on:** M3, M6, M10

### M10 — SettingsViewController
- **Purpose:** Tools > Preferences equivalent — theme picker, layout mode toggle, accessory rows, starter content, font options
- **Done when:** Every preference in M2 has a corresponding row; changing it persists + triggers live update in editor
- **Parallelizable:** yes after M2 is done

### M11 — FindReplaceBar + match nav
- **Purpose:** Find + replace inline bar, next/prev nav, highlight matches, case-sensitive toggle
- **Done when:** Type "the" in find → matches highlighted + count shown; next/prev navigate; replace does exactly-one; replaceAll replaces all and count matches
- **Depends on:** M3 (needs textStorage for range-based attribute runs)

### M12 — CompareViewController
- **Purpose:** View > Compare top/bottom diff against another open note
- **Done when:** With 2+ notes open, View > Compare shows top/bottom panes; modified/added/removed rows colored per RN; scrolling one pane syncs the other (match RN's `syncScroll`)
- **Depends on:** M3, M5 (line coloring under diff)

### M13 — VirtualTrackpadView (on-screen trackpad)
- **Purpose:** Dedicated pad area in keyboard toolbar for smooth cursor movement with swipe gesture, acceleration, single-tap = move cursor home
- **Done when:** Pan on pad moves cursor by `SENS * dx, SENS * dy`; acceleration matches RN (SENS = 1.8); works with external keyboard absent
- **Parallelizable:** yes after M7 is in (it's a subview of the keyboard toolbar)

### M14 — Classic mode chrome (deferred, stretch)
- **Purpose:** Aero-style title bar gradient + menu bar + sidebar list — faithful to the RN classic layout
- **Done when:** Classic mode renders without crash on iPhone 17 Pro; all menu items produce the same action as their mobile counterparts; crash-recovery flag path verified (boot classic, kill app mid-render, next launch downgrades to mobile)
- **Deferred:** only ship when everything else is solid; needs its own design revision

### M15 — Crash recovery (AppEnvironment + CrashLog)
- **Purpose:** Port `ErrorBoundary` + `crashLog` + `LAYOUT_PENDING_KEY`. On crash, we record; on next boot, we surface the last crash and degrade gracefully.
- **Done when:** Force an NSException in classic layout startup; next launch opens in mobile layout + shows the recorded crash in Settings > About
- **Depends on:** M2 (uses ThemePreferences for the pending flag)

---

## 8. Parallelism map

Per advisor's correction: not everything is parallelizable. The interlocking pieces are in serial lanes; only truly independent work fans out.

```
Phase 0 (serial, blocks all):
  M0 — CI workflow

Phase 1 (partly parallel; M3 gates most of Phase 2):
  M1 ✅ (done already)
  M2 [stream A] — theme palettes + ThemePreferences
  M3 [main lane] — editor core
  M15 [stream A] — crash recovery (low-risk, plugs into ThemePreferences)

Phase 2 (mostly parallel after M3 lands):
  M4 [main lane] — editor actions
  M5 [main lane] — syntax highlighter (serial with M4 to avoid file collisions in EditorViewController.swift)
  M6 [stream B] — document picker
  M10 [stream A] — settings screen (needs M2 done)

Phase 3 (UI composition, needs M3+M4+M5):
  M7 [main lane] — keyboard toolbar (plus M4 actions to call)
  M8 [main lane] — tabs
  M9 [stream B] — bottom action bar
  M11 [main lane] — find/replace (needs M5's text storage attribute work)
  M13 [stream B] — virtual trackpad (lives inside M7 but is its own file)

Phase 4 (late):
  M12 — compare view
  M14 — classic chrome (if we pursue it)
```

**Up to 3 concurrent agents** during Phase 2 and Phase 3 (main lane + stream A + stream B). We do NOT try for 4+ concurrent because:
- Editor core + actions + syntax all live in the same file tree and would fight for merges
- Tabs + action bar + settings all touch root VC composition
- Classic chrome is deferred and would be a 4th lane anyway

**Rollup on every phase:** single agent reconciles, runs CI, confirms green before next phase starts.

---

## 9. Testing + verification plan

**Per module:**
- Unit tests where they make sense (NotesStore CRUD, tokenizer output for sample lines, cursor-move math)
- Manual test cases documented in `artifacts/ios-native/docs/verification/<module>.md` — what to tap, what to observe, screenshot expected

**Per PR:**
- CI green (M0)
- At least one manual verification case documented in PR body
- If behavior diverges from RN, PR body must justify why (e.g., "RN hid the bottom bar when keyboard appeared; we use native inputAccessoryView which iOS auto-positions above keyboard — same user-visible behavior via different primitives")

**Parity gate (before considering "done"):**
- Screenshot-by-screenshot walk of the RN app vs the Swift app with both on the same iPhone simulator (17 Pro, iOS 26.5)
- Manual test of every Edit-menu action in both
- Autosave survival test: type, force-quit, relaunch — data present

---

## 10. Risks + mitigations

| Risk | Mitigation |
|---|---|
| Swift compile fails that we can't catch locally | Phase 0 CI is the blocker; keep PRs small |
| Syntax highlighting too slow on long files | Incremental NSTextStorage invalidation (only the edited paragraph) |
| Memory from observer-token closures | `[weak self]` in every observer block; already pattern in EditorViewController |
| Classic mode crashes recur | Crash recovery flag + automatic degrade to mobile; M15 verifies |
| SwiftUI-vs-UIKit regret for Settings | Settings is isolated; can be swapped if UIKit cost is too high |
| Scope creep ("while we're at it let's add X") | Every feature must map to a row in the cross-reference table. No row → no feature. |
| Corey's signing cert rotation | Out of scope for this spec; follows existing YTAfterglow pattern |

---

## 11. What success looks like

- `xcodebuild` green on every PR
- On-device: feature checklist from RN matches Swift 1-for-1
- Classic-mode crash parity (crashes recover; flag clears after 1.5s stability)
- No third-party Swift Package dependencies (unless we add one for something truly unbuildable, and then only after discussion)
- Swift file tree reflects the module breakdown above — a reader can open any file and know what it does in < 30s

---

## 12. Open questions

- Do we want iPad support eventually? If yes, it shapes root VC composition (UISplitViewController vs single column). For this spec: iPhone-only.
- Starter-content preference ("welcome" vs "blank"): keeping parity means both are options. Settings > Preferences > First-run content.
- Do we ship TestFlight / Sideloadly / self-signed? Same pattern as YTAfterglow IPA workflow — decide at shipping time, not design time.

---

## 13. Next step

Write the implementation plan via `superpowers:writing-plans`, then execute it via `superpowers:executing-plans`, using `superpowers:dispatching-parallel-agents` for the 3-stream phases above. Phase 0 is serial and lands first; every subsequent phase lands its work on top of a known-green CI build.
