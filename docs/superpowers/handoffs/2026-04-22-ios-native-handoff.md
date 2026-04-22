# Notepad 3++ iOS Native Port — Handoff Brief

**Date:** 2026-04-22
**For:** the next Claude (or human) picking up this work
**From:** Claude Opus 4.7 (1M context) at the end of an audit pass
**Owner:** Corey (xuninc on GitHub, xuninc@gmail.com)

This brief is self-contained. You don't need any prior conversation history.

**You're on macOS with Xcode and you can `xcodebuild` and run a simulator locally — use it as your primary verification loop.** Corey's host is WSL Ubuntu where Swift can't compile; he relies on you to be his Mac.

---

## 0. Read these first (15 minutes)

Before doing anything, get oriented from primary sources:

1. `git log --oneline origin/main..feat/ios-native-port` — every commit on the active branch with messages that describe what was built
2. `artifacts/ios-native/README.md` — original Why-this-exists doc (note: layout section is stale — see §4)
3. `docs/superpowers/specs/2026-04-21-ios-native-port-design.md` — design spec from a prior brainstorming pass (note: most of it was already implemented before the spec was written; treat as conceptual reference)
4. `artifacts/ios-native/Sources/Notepad3/App.swift` — entry point, just 27 LOC
5. `artifacts/ios-native/Sources/Notepad3/Editor/EditorViewController.swift` — the heart of the app, 1245 LOC
6. `artifacts/mobile/app/index.tsx` — the RN app that the Swift port is mirroring (1847 LOC; this is the *spec*)
7. `artifacts/ios-native/Project.yml` — xcodegen manifest

The recipient already has a clean local build of `feat/ios-native-port` as of 2026-04-22 — compilation is not in question. Your starting line is reading the code, not bringing up the build.

---

## 1. What this project is

**Repo:** `xuninc/Notepad3-` on GitHub. Local checkout: `/home/corey/repos/xuninc/Notepad3-/` (WSL Ubuntu 24.04 on Windows host NIBIRU-DARKLIGHT).

**Two apps live in the same monorepo under `artifacts/`:**

- `artifacts/mobile/` — the original React Native 0.81.5 / Expo 54 / pnpm-workspace app (`@workspace/mobile`). Still works. Acts as the **authoritative spec** for behavior.
- `artifacts/ios-native/` — a native Swift/UIKit rewrite that we are now actively building. Targets iOS 16+, iPhone-only. Bundle id `com.corey.ios.np3plusplus.native`.

**Goal:** 1-for-1 feature parity with the RN app, but using native iOS primitives where RN was painful (UITextView undoManager, NSTextStorage syntax coloring, UIInputViewController, UIDocumentPickerViewController, UIMenu, haptics). The RN app stays in the repo as a working backstop.

**Long-term plan:** Once the Swift port reaches stability, extract `artifacts/ios-native/` to its own repo with `git filter-repo --subdirectory-filter artifacts/ios-native/`. Don't worry about that now.

---

## 2. Where things live

| Thing | Path |
|---|---|
| RN app (the spec) | `artifacts/mobile/` |
| Swift port (active work) | `artifacts/ios-native/` |
| Swift port README | `artifacts/ios-native/README.md` (NOTE: layout section is out of date — see §4 for current truth) |
| xcodegen manifest | `artifacts/ios-native/Project.yml` |
| Design spec doc | `docs/superpowers/specs/2026-04-21-ios-native-port-design.md` (NOTE: written before discovering most of it was already built — treat as conceptual reference, not gospel) |
| This handoff | `docs/superpowers/handoffs/2026-04-22-ios-native-handoff.md` |
| Active branch | `feat/ios-native-port` (don't push directly to `main`; PRs only) |
| Default branch | `main` |
| CI workflow (RN only — does NOT build Swift!) | `.github/workflows/main.yml` |

---

## 3. Build / dev environment

**Two hosts, two roles:**

- **Corey:** WSL Ubuntu 24.04 on Windows. No `swiftc`, no Xcode. He authors RN parity code and reviews; he cannot verify Swift builds.
- **You:** macOS with Xcode. You are the build verifier. Every PR you land should be one you actually compiled and ran (or at least built) on your Mac.

**The macOS local loop:**
```bash
brew install xcodegen           # one-time
cd artifacts/ios-native
xcodegen generate                # regenerates Notepad3.xcodeproj from Project.yml
open Notepad3.xcodeproj          # then Cmd+R, or:
xcodebuild -scheme Notepad3 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The `.xcodeproj` is **gitignored**. Adding a source file = drop a `.swift` into `Sources/Notepad3/…`, re-run `xcodegen generate`. No `.pbxproj` merge conflicts ever.

**CI is still worth adding** even though you can build locally — every PR should be reproducibly buildable from a clean checkout. See §6.

---

## 4. Current state of the Swift port (verified 2026-04-22)

**30 Swift files, 7,855 LOC.** Vast majority of features already implemented. Recent commits show it was built day-by-day with parallel agents.

### Source tree (actual, not what README claims)

```
artifacts/ios-native/Sources/Notepad3/
├── App.swift                              (27 LOC — basic SceneDelegate, no crash recovery wired yet)
├── Info.plist
├── Models/
│   ├── Note.swift                         (54)
│   ├── NoteLanguage.swift                 (71)
│   └── Theme.swift                        (258 — all 8 palettes including custom overlay)
├── Persistence/
│   ├── NotesStore.swift                   (169 — JSON file in Documents/, observer pattern)
│   ├── Preferences.swift                  (127 — UserDefaults backing every RN preference key)
│   └── ThemeController.swift              (104 — resolves named/system to palette)
├── Editor/
│   ├── EditorViewController.swift         (1245 — hosts both layouts; observer-driven)
│   └── SyntaxHighlighter.swift            (196 — NSTextStorageDelegate)
└── UI/
    ├── CompareViewController.swift        (628 — top/bottom diff)
    ├── CustomPaletteBuilderViewController  (261 — color picker for custom theme)
    ├── DocsListViewController.swift       (359 — doc list modal w/ context menus)
    ├── FindReplaceBar.swift               (214 — case/whole-word/regex toggles)
    ├── GotoLine.swift                     (36)
    ├── Haptics.swift                      (19 — wrapper around UIFeedbackGenerator)
    ├── KeyboardAccessoryView.swift        (490 — copy/cut/paste/undo/redo/arrows etc.)
    ├── LanguagePickerViewController.swift (101)
    ├── MarkdownPreviewView.swift          (371 — NSAttributedString markdown rendering)
    ├── SettingsViewController.swift       (443 — UITableView preferences)
    ├── TabStripView.swift                 (369 — tabs OR list mode)
    ├── Classic/
    │   ├── AeroMenuBar.swift              (278)
    │   ├── ClassicTitleBar.swift          (62)
    │   ├── ClassicToolbar.swift           (446)
    │   ├── LineGutter.swift               (164)
    │   └── StatusBar.swift                (263)
    ├── Mobile/
    │   ├── MobileActionSheet.swift        (255)
    │   ├── MobileBottomBar.swift          (147)
    │   └── MobileFAB.swift                (101)
    └── Trackpad/
        ├── PointerOverlay.swift           (141 — fake-pointer dot + click ripple)
        └── VirtualTrackpad.swift          (456)
```

### What's known to work (per commit messages — verify on a sim before trusting)

- **Day 2 (`ef61777`):** Tabs, new/open menu, file import via UIDocumentPickerViewController
- **Day 3 (`b02336c`):** Themes, dark/light toggle, settings screen, syntax coloring
- **Day 4a (`1e9c5ca`):** Find/replace bar, line tools (sort/trim/dup/delete), real palettes
- **Day 4+5 (`4bfeb41`):** Full chrome integration, classic mode rendering
- **Notepad2 chrome (`fbedaa6`):** Classic title bar + Aero menu bar + classic toolbar + status bar + compare diff engine
- **Tab list mode + markdown preview + richer highlighter + haptics (`5abff52`)** — built in parallel by sub-agents
- **Custom palette overlay (`c43d403`):** Pick custom colors → live repaint
- **Programmatic mutations register undo (`da468d6`):** Sort/Trim/DupLine/DeleteLine/Replace/Cut/Insert all reversible via shake or 3-finger swipe; action names show in Edit > Undo (e.g., "Undo Sort Lines")
- **Real DocsListViewController (`320003c`):** Replaces a UIAlertController hack — sheet presentation with grabber, medium/large detents, per-row context menus
- **Find options (`a685771`):** Case-sensitive, whole-word (`\b…\b`), regex (with template-escaped literal mode)
- **Trackpad ripple (`38431d3`):** PointerOverlay.animateClickRipple matches RN's clickRipple
- **Bottom bar layout fix (`b18745b`):** Fixed bar ballooning to fill space + collapsing textView to 0pt; default theme now `named:classic` (Aero blue)

### What's NOT done / unverified (verified by reading the code, 2026-04-22)

- **CI build workflow for Swift.** The only workflow today is the RN/Expo IPA build (`.github/workflows/main.yml` runs `expo prebuild` against `artifacts/mobile`). Nothing has actually compiled the Swift code in CI. **Highest priority** — see §6.
- **Crash recovery missing.** Confirmed by reading `Persistence/Preferences.swift`: there is no `pendingClassic` key, no `LAYOUT_PENDING_KEY` equivalent. RN's `ThemeContext.tsx` sets a flag on classic boot and clears it after 1.5s of stable rendering; if next launch sees the flag still set, it downgrades to mobile. Swift port has no equivalent — a classic-mode launch crash will re-crash on next launch.
- **App.swift is 27 LOC.** `SceneDelegate.scene(_:willConnectTo:options:)` directly creates `EditorViewController(store: NotesStore.shared)`, wraps in `UINavigationController`, and shows it. No Preferences read, no crash-flag check.
- **Outdated README.** `artifacts/ios-native/README.md` describes a layout that no longer matches reality (mentions `Editor/EditorTextView.swift`, `Tabs/TabBarView.swift`, `Sheets/ActionSheet.swift`, `Sheets/PreferencesViewController.swift`, `Trackpad/TrackpadOverlay.swift` — none of these exist).
- **No tests.** Zero unit or UI tests in the Swift target.
- **No Asset catalog visible in the source tree.** `Project.yml` references `LaunchBackground` and `AccentColor` color names. Either the asset catalog exists outside the source tree, or Xcode is tolerating the missing references with warnings. Recipient confirms clean build, so probably tolerated — but should still create the catalog before relying on it.
- **Custom palette overlay is incomplete.** `Models/Theme.swift :: Palette.byOverlaying(overrides:onto:)` only honors 12 of the Palette's 18 fields: `background, foreground, card, primary, primaryForeground, secondary, muted, mutedForeground, accent, border, editorBackground, editorGutter`. The user CANNOT customize: `destructive, success, titleGradientStart, titleGradientEnd, chromeGradientStart, chromeGradientEnd, radius`. RN's `CUSTOM_PALETTE_KEYS` includes `destructive, highlight, titleGradientStart, titleGradientEnd, chromeGradientStart, chromeGradientEnd` — so the Swift port's custom palette is strictly less capable than RN's.
- **Preferences storage key for tabsLayout disagrees with RN.** Swift writes to `notepad3pp.tabsLayout`; RN writes to `notepad3pp.tabsLayout.v2`. Doesn't matter today (apps don't share defaults), but if you ever introduce a migration, watch out.
- **`onSave` callbacks in classic chrome are no-ops.** `aeroMenuBar.onSave` and `classicToolbar.onSave` are wired to empty closures with the comment "notes auto-save to disk; no explicit action". The menu items still appear though — could confuse users who expect a save indicator. RN behavior is the same (autosave only) but the Swift port might benefit from a "saved <relative time>" status bar field — verify the StatusBar already shows `savedAt` (it does, per `EditorViewController.refreshStatusBar()`).
- **Two different "Open" code paths.** The mobile bottom bar's Open button calls `presentOpenMenu()` which builds a `UIAlertController` action sheet listing New blank / Open from Files / each open note. The keyboard accessory's Open and the classic toolbar's Docs both call `presentDocsList()` which is the proper `DocsListViewController` modal (the one commit `320003c` introduced). The action sheet is leftover and inconsistent.

---

## 5. Coding rules (non-negotiable, learned from Corey)

These come from Corey's MEMORY.md and prior session feedback. Following them avoids friction.

1. **The RN app is the oracle.** Every behavior question: "what does `artifacts/mobile/` do?" Don't redesign. If you find yourself adding a feature that's not in the RN app, stop and ask.
2. **No third-party Swift Package dependencies** unless explicitly cleared with Corey first. UIKit + Foundation are enough for everything we need.
3. **UIKit, not SwiftUI** for the editor (SwiftUI's `TextEditor` hides UITextView API we need: textStorage attributes, inputAccessoryView, undoManager). SwiftUI for chrome is OK but currently nothing uses it; one mental model is fine.
4. **Native idioms over RN ports.** Use `UITextView.undoManager` (not a hand-rolled ring), `UIMenu` (not custom dropdowns), `UIFeedbackGenerator` for haptics. The Swift code already follows this.
5. **Don't preemptively hedge.** "Probably won't work" is unhelpful. Try it, see what happens. Corey will course-correct.
6. **Defend reasoning when challenged.** If Corey questions a choice, explain it before reverting. He pushes back to learn, not to dictate.
7. **Minimal chatter.** Short, terse, no permission-dance, no repeated menus. End-of-turn summary is one or two sentences.
8. **Don't cancel running CI builds.** Ever, without asking.
9. **Questions are not instructions.** If Corey asks "could we do X?", answer first. Don't start doing X.
10. **Default to no comments in code.** Only add a comment if it explains a non-obvious *why*. Never narrate what the code does.
11. **Single-color emoji avoidance.** No emojis in code or commit messages unless asked.
12. **Commit messages.** Use the existing pattern: `feat(ios-native): …`, `fix(ios-native): …`, `docs(ios-native): …`. Always include the trailer:
    ```
    Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
    ```
13. **Don't push to main.** Branch protection blocks it anyway. PRs only.
14. **Don't bundle / consolidate.** If a feature is independent, keep it independent. (This rule comes from Corey's other repo (YTAfterglow) but the principle holds.)

---

## 6. First priority

**Add a Swift xcodebuild CI workflow.** Build is clean on your Mac, but it's not reproducible from a clean checkout in CI. Until CI is green, every "I added X" claim is unverifiable for anyone who isn't you, and a future contributor with a slightly different Xcode version may be unable to build at all.

### Spec for the workflow

File: `.github/workflows/ios-native-build.yml`

Triggers:
- `push` on `main`, `feat/ios-native-port`, and any branch matching `feat/ios-native-*` or `fix/ios-native-*`
- `pull_request` touching `artifacts/ios-native/**` or the workflow itself
- `workflow_dispatch` (so Corey can trigger manually)

Job:
- Runs on `macos-15` (matches the existing `main.yml`)
- Checkout
- `brew install xcodegen` (or use an action if cached version is faster)
- `cd artifacts/ios-native && xcodegen generate`
- `xcodebuild -scheme Notepad3 -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO`
- Cache xcodegen, Swift Package Manager build outputs (under `~/Library/Developer/Xcode/DerivedData`)

Stretch (optional second step in same workflow):
- Boot a simulator (`xcrun simctl boot`), install the .app, take a screenshot of the main view via `xcrun simctl io … screenshot`, upload it as an artifact. This catches "compiles but crashes on launch" without writing test code.

After the workflow exists:
1. Push the workflow on a branch
2. Open a PR — confirm the workflow runs
3. Whatever fails, fix. Likely candidates: missing `LaunchBackground`/`AccentColor` asset catalog (add a minimal `.xcassets`), Info.plist references, scheme not generated by xcodegen (configure under `targets.Notepad3.scheme` in `Project.yml`).
4. Land the workflow on `main`. From now on, every PR includes a green CI run as evidence.

---

## 7. The next tasks in order

After CI is green, these are the actual gaps verified by reading the code. Do them in order; later items depend on earlier ones being verified.

### Task 1: Crash-recovery flag (App.swift + Preferences.swift)
- **Why:** Confirmed missing. RN's classic mode used to crash on launch and lock the app out. RN solves this with `LAYOUT_PENDING_KEY`: set on classic boot, cleared after 1.5s of stable rendering, checked at next launch.
- **What:**
  1. Add to `Preferences.swift`: a new key `notepad3pp.layoutMode.pendingClassic` and accessor `var pendingClassic: Bool { get / set }` — same pattern as the other typed accessors.
  2. In `SceneDelegate.scene(_:willConnectTo:options:)`: before constructing the editor, read `Preferences.shared.layoutMode` and `Preferences.shared.pendingClassic`. If both indicate "we tried classic and didn't make it", set `Preferences.shared.layoutMode = .mobile` and clear the pending flag.
  3. If we ARE launching classic, set `pendingClassic = true` before showing the window.
  4. In `EditorViewController.viewDidAppear`, schedule a 1.5s timer that clears the flag (only when `prefs.layoutMode == .classic`).
- **RN reference:** `artifacts/mobile/context/ThemeContext.tsx` lines ~50–115.
- **Verify:** Add a DEBUG-only menu item or just temporarily insert `fatalError()` into a classic-mode subview's `layoutSubviews`. Force-quit, relaunch, app should boot mobile.

### Task 2: Fill the custom-palette gap
- **Why:** Confirmed: `Palette.byOverlaying` only honors 12 of 18 fields. Users who pick "Custom" theme and tweak a destructive color or title gradient will see no effect.
- **What:** In `Models/Theme.swift :: Palette.byOverlaying(overrides:onto:)`, add the missing fields: `destructive, success, titleGradientStart, titleGradientEnd, chromeGradientStart, chromeGradientEnd`. (Skip `radius` — it's a CGFloat, not a UIColor; if needed, parse from a numeric override key.)
- Also: confirm that `CustomPaletteBuilderViewController` exposes UI for the new fields. If not, add rows for them (it currently only knows about a subset).
- **Verify:** Settings → pick Custom → set destructive to red → trigger a destructive confirm dialog → button color matches.

### Task 3: README freshen
- **Why:** Current README's "Layout" section is wrong. Mentions files (`EditorTextView.swift`, `Tabs/TabBarView.swift`, `Sheets/`, `Trackpad/TrackpadOverlay.swift`) that don't exist.
- **What:** Update `artifacts/ios-native/README.md` to reflect the actual `Sources/Notepad3/` tree from §4. Add a "Status" subsection linking to this handoff. Keep the "Why not SwiftUI" and "Why uncontrolled by default" sections — those are still accurate.

### Task 4: Asset catalog
- **Why:** `Project.yml` references `LaunchBackground` and `AccentColor`. Recipient's clean build suggests Xcode tolerates the missing catalog, but CI will be stricter.
- **What:** Create `artifacts/ios-native/Sources/Notepad3/Assets.xcassets/` with:
  - `AccentColor.colorset/Contents.json` — `palette.classic.primary` (#3a78c4)
  - `LaunchBackground.colorset/Contents.json` — `palette.classic.background` (#dbe5f1)
  - `AppIcon.appiconset/Contents.json` — at minimum a 1024×1024 placeholder
- **Verify:** Workflow from §6 still green; no missing-asset warnings.

### Task 5: Unify the two Open paths
- **Why:** Confirmed inconsistency. The mobile bottom bar's Open button calls `presentOpenMenu()` (a UIAlertController action sheet listing each open note); everywhere else uses `presentDocsList()` (the proper `DocsListViewController` modal). User flows feel different depending on entry point.
- **What:** Replace `presentOpenMenu()` with `presentDocsList()` in the mobile bottom bar handler (line 191 of `EditorViewController.swift`). Delete the now-unused `presentOpenMenu()` method (lines 1100–1113). Verify the mobile bottom bar Open button → DocsListViewController appears.

### Task 6: Verification screenshots / golden path test
- **Why:** Catches regressions in chrome layout like the b18745b bottom bar bug.
- **What:** Add a small UI test target (or `xcrun simctl` script) that boots a simulator with cleared defaults, launches the app, takes screenshots of: launch / mobile editor / mobile bottom bar / classic title bar+menu+toolbar / find bar open / find bar with replace / tab strip in tabs mode / tab strip in list mode / preferences modal / docs list modal. Compare against committed reference screenshots on PR.

### Task 7: RN feature parity audit
- **Why:** The Swift port is ~95% done by file count but no one has line-by-line walked it against RN.
- **What:** Sit with `artifacts/mobile/app/index.tsx` (1847 LOC) and `artifacts/ios-native/Sources/Notepad3/Editor/EditorViewController.swift` (1246 LOC). For each RN menu item, toolbar button, action sheet row: confirm the Swift equivalent exists. Anything in RN but not in Swift: file an issue or fix it. Anything in Swift but not in RN: ask Corey if it's intentional (Markdown preview, language picker modal, custom palette builder are all candidates).
- Output: a checklist in `docs/superpowers/specs/2026-04-22-rn-vs-swift-parity-audit.md`.

---

## 8. RN → Swift cross-reference (quick lookup)

When you need to know "what does the RN app do here", grep these files first:

| Concept | RN source | Swift source |
|---|---|---|
| Note model | `mobile/context/NotesContext.tsx :: NoteDocument` | `ios-native/.../Models/Note.swift` |
| Persistence + observer pattern | `mobile/context/NotesContext.tsx :: NotesProvider` | `ios-native/.../Persistence/NotesStore.swift` |
| Preferences | `mobile/context/ThemeContext.tsx` (storage keys: `notepad3pp.*`) | `ios-native/.../Persistence/Preferences.swift` |
| Theme palettes | `mobile/constants/colors.ts :: themes` | `ios-native/.../Models/Theme.swift` |
| Theme resolution (named/system) | `mobile/context/ThemeContext.tsx :: themeName` | `ios-native/.../Persistence/ThemeController.swift` |
| Custom palette overlay | `mobile/constants/colors.ts :: buildCustomPalette` | `ios-native/.../Models/Theme.swift :: Palette.byOverlaying(_:onto:)` |
| Editor screen | `mobile/app/index.tsx :: NotepadScreen` | `ios-native/.../Editor/EditorViewController.swift` |
| Syntax tokenizer | `mobile/app/index.tsx :: tokenizeLine` + `tokenColor` | `ios-native/.../Editor/SyntaxHighlighter.swift` |
| Tab strip | `mobile/app/index.tsx :: DocumentTab` | `ios-native/.../UI/TabStripView.swift` |
| Find/replace | `mobile/app/index.tsx :: findNext/replaceAll/replaceNext` | `ios-native/.../UI/FindReplaceBar.swift` |
| Compare view | `mobile/app/index.tsx :: ComparePane + compareDocuments` | `ios-native/.../UI/CompareViewController.swift` |
| Keyboard accessory | `mobile/app/index.tsx :: KbBtn + KbHoldBtn + KbSep` | `ios-native/.../UI/KeyboardAccessoryView.swift` |
| Virtual trackpad | `mobile/app/index.tsx :: MouseOverlay` | `ios-native/.../UI/Trackpad/VirtualTrackpad.swift + PointerOverlay.swift` |
| Settings screen | `mobile/app/index.tsx :: settingsSheet` | `ios-native/.../UI/SettingsViewController.swift` |
| Document picker | `mobile/app/index.tsx :: importFromFiles` | `ios-native/.../UI/DocsListViewController.swift` (open buttons) |
| Mobile bottom bar | `mobile/app/index.tsx :: bottom toolbar` | `ios-native/.../UI/Mobile/MobileBottomBar.swift` |
| Classic title bar | `mobile/app/index.tsx :: classic chrome` | `ios-native/.../UI/Classic/ClassicTitleBar.swift + AeroMenuBar.swift + ClassicToolbar.swift + StatusBar.swift + LineGutter.swift` |
| Crash recovery | `mobile/context/ThemeContext.tsx :: LAYOUT_PENDING_KEY + resetLayoutModeToMobile` | NOT YET PORTED (Task 1 above) |
| Error boundary | `mobile/components/ErrorBoundary.tsx` | NOT YET PORTED |
| Notes file on disk | RN: AsyncStorage key `pocketpad-notes-v1` | Swift: `<Documents>/notes-v1.json` (`NotesStore.url`) |
| Open-from-Files action | `mobile/app/index.tsx :: importFromFiles` | `EditorViewController :: presentFileOpen + UIDocumentPickerDelegate` (lines 1220–1245) |
| Mobile More sheet | `mobile/app/index.tsx :: settings sheet` | `EditorViewController :: presentMobileMore` (lines 1115–1167) |

---

## 9. Verification methodology

You have Xcode and a Mac, so:
- **Every PR you open should be one you've already built locally.** State the build status in the PR description: "Built clean on Xcode 16.x against iOS 17 Simulator."
- **For visible changes, screenshot from a running simulator.** Drop the screenshot into the PR description so Corey can see without running it himself.
- **For interactive flows (find/replace, tab actions, classic chrome menus), run them in the simulator.** Note any latency or layout glitches in the PR.

For Corey's side:
- He runs the IPA on his iPhone 17 Pro / iOS 26.5 beta when you have a sideload-able build.
- He'll report back with screenshots and bug descriptions.

Once CI is in (§6), it backstops you — but your local Mac build is the primary truth source.

---

## 10. Tools you have

You're a Claude Code instance on macOS with Xcode. That gives you:

- **The actual build loop.** `xcodebuild`, the iOS Simulator, Instruments, the LLDB debugger. Use them as your primary feedback loop. Static analysis is no substitute.
- Full filesystem read/write under your local checkout
- `git`, `gh` (GitHub CLI — make sure you're authenticated as xuninc or a collaborator who can push to the repo)
- `Bash`, `Edit`, `Read`, `Write`, `Glob`, `Grep`
- The `Agent` tool for spawning subagents. Corey has prior parallel-build commits in this repo (`5abff52` was "Parallel-built"), so this works. **Caveat:** subagent prompts must embed context — the subagent sees no prior conversation, so quote relevant memory and code excerpts inline.
- `superpowers` skill set: `brainstorming`, `writing-plans`, `executing-plans`, `dispatching-parallel-agents`, `debugging`, `using-superpowers`. The `using-superpowers` skill auto-loads at session start.
- An `advisor` tool that consults a stronger reviewer with your full conversation context — call it before committing to an approach on anything > 3 steps, and before declaring done.

**Use the simulator, not just the build output.** Compile success ≠ feature success. Run the app, exercise the feature you changed, and screenshot the result.

---

## 11. Open questions for Corey

If you're picking this up cold, get answers before doing anything beyond Task §6:

1. **iPad support eventually?** Currently iPhone-only. Affects root VC composition.
2. **TestFlight or self-sign?** Same pattern as YTAfterglow IPA workflow, decide at shipping time.
3. **Are the Swift port's bonus features (markdown preview, language picker modal, custom palette builder) intentional or scope creep?** They exist in Swift but are not 1-for-1 with RN.
4. **App icon — placeholder OK or should we design one?**

---

## 12. Don't forget

- **`/effort max` and auto mode are how Corey runs sessions.** Don't be precious.
- **Use TodoWrite/TaskCreate** to track multi-step work.
- **Use the `advisor` tool** before committing to an approach on anything > 3 steps.
- **Save state with `remember:remember`** between major milestones in long sessions.
- **The brainstorming skill has a HARD-GATE:** if Corey asks for a design, no implementation until he approves the spec. (You can skip this if the work is a continuation of an existing approved spec, like all of Tasks 1–5 above.)

---

**End of brief. Branch: `feat/ios-native-port`. Spec doc: `docs/superpowers/specs/2026-04-21-ios-native-port-design.md`. Go.**
