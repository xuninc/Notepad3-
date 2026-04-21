# Notepad 3++ — iOS Native (Swift)

Native iOS rewrite of the React Native version in `../mobile/`. Same feature set, native-feeling editor (UITextView + NSAttributedString), word-aware undo, gesture-based undo/redo, syntax coloring without overlay tricks, ~1-3MB binary instead of 10-30MB.

The RN version remains in `../mobile/` as a working backstop. When this catches up to mobile-mode parity, we can extract this directory into its own repo with `git filter-repo --subdirectory-filter artifacts/ios-native/`.

## Build

You need Xcode 15+ on macOS and Homebrew.

```bash
brew install xcodegen
cd artifacts/ios-native
xcodegen generate         # produces Notepad3.xcodeproj
open Notepad3.xcodeproj
# In Xcode: select Notepad3 scheme, your iPhone, Cmd+R
```

The `.xcodeproj` is generated from `Project.yml` and is **gitignored**, so adding new source files just requires re-running `xcodegen generate` — no merge conflicts on `.pbxproj`.

## Layout

```
artifacts/ios-native/
├── Project.yml                    xcodegen spec (single source of truth)
├── README.md                      this file
├── .gitignore
└── Sources/
    └── Notepad3/
        ├── App.swift              @main, scene/window, root view controller
        ├── Info.plist             bundle config
        ├── Models/
        │   ├── Note.swift         NoteDocument equivalent
        │   ├── NoteLanguage.swift detection + keyword sets
        │   └── Theme.swift        palette, ThemeName, dynamic colors
        ├── Persistence/
        │   └── NotesStore.swift   JSON-file backing + observer pattern
        ├── Editor/
        │   ├── EditorViewController.swift    main edit screen
        │   ├── EditorTextView.swift          UITextView subclass with input accessory
        │   └── SyntaxHighlighter.swift       NSAttributedString tokenizer
        ├── Tabs/
        │   └── TabBarView.swift   open-doc tab strip
        ├── Sheets/
        │   ├── ActionSheet.swift  the More menu (mobile)
        │   └── PreferencesViewController.swift
        └── Trackpad/
            └── TrackpadOverlay.swift  on-screen pad + UIPointerInteraction
```

## Status

See the task list / commits on this branch for current state. First commit is project skeleton + models + persistence; editor and UI come in subsequent commits.

## Why not SwiftUI

SwiftUI's `TextEditor` wraps `UITextView` but hides most of the API we need: per-character `NSAttributedString` styling, custom `inputAccessoryView`, programmatic selection, full undoManager access. UIKit gives all of that directly. SwiftUI is fine for the chrome (settings, modals, theme picker) — we can mix it in via `UIViewRepresentable` if it ends up cleaner, but the editor itself stays UIKit.

## Why uncontrolled by default

Our React Native version had to fight controlled `value` + `onChangeText` to get even basic undo working. Native `UITextView` owns its own text storage and undoManager — we just observe via `UITextViewDelegate.textViewDidChange(_:)` and persist. No state churn, no defeated undo stacks.
