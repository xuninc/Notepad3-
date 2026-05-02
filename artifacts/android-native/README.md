# Notepad 3++ — Native Android Port

Kotlin / Jetpack Compose implementation of Notepad 3++ for Android. Sibling to the iOS Swift port at `../ios-native/`. The Android app tracks iOS parity where it makes sense, while still taking Android-specific wins when the platform can do more.

See `docs/superpowers/specs/2026-04-26-android-native-port-design.md` for the full design and `docs/superpowers/plans/2026-04-26-android-native-phase-0.md` for the phase-0 plan.

## Status

**Native editor slice** — The current APK launches into a usable text editor:

- native `EditText` body editor hosted inside Compose
- local JSON persistence at `filesDir/documents-v1.json`
- editable document title
- New document action
- open-document switching, duplicate, close, and close-others actions
- Android file picker import wired through the document store
- all named iOS palettes ported, with a Theme button cycling them
- find/replace controls with literal case-insensitive navigation, replace-current, and replace-all
- editor commands for undo/redo, date/time insert, go-to-line, select all/current line/current paragraph, uppercase/lowercase selection, indent/unindent selection, trailing-space trim, line sort, line duplicate, and line delete
- iOS-style compare summary and two-pane diff preview powered by the same LCS line-diff shape: percent similar plus added/removed/changed counts, with selectable compare targets
- syntax/language picker using the same language set as the iOS port
- Markdown preview mode for Markdown documents, with rendered headings, paragraphs, bullets, and fenced code blocks
- read mode and Zen mode, including Android Back exit from Zen
- persistent mobile/classic layout preference, with classic mode moving primary commands into desktop-style top chrome
- functional classic-mode title-bar close button wired to finish and remove the Android task
- status readout for language, read-only state, lines, characters, caret line/column, and selection length
- JVM tests for language detection, persistence, theme resolution, editor preferences, editor commands, editor status, undo grouping, Markdown preview parsing, and line diffing

The next useful slice is deeper editor parity: keyboard accessory tools, full compare panes with scroll sync, line-number gutter work, richer document metadata, and more Notepad++-style editing commands.

## Local build

Requires:
- macOS or Linux
- JDK 17 (`brew install --cask temurin@17` on macOS)
- Android SDK with build-tools 34+ and platform-tools (Android Studio installs these by default; cmdline-tools alone also works)
- Set `ANDROID_SDK_ROOT` (or `ANDROID_HOME`) to your SDK location

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 17)   # macOS
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk" # macOS
./gradlew :app:assembleDebug
# → app/build/outputs/apk/debug/app-debug.apk
```

## CI build

Push a tag matching `android-native-v*` (e.g. `android-native-v0.1.0`) or run the workflow manually:

```bash
gh workflow run "Build Android Native" --ref <branch>
gh run watch --exit-status
gh run download <run-id> -n notepad3-android-debug-apk
```

Artifact: `notepad3-android-debug-apk` containing `app-debug.apk`.

## Sideloading

1. Enable Developer Options on your Android device (Settings → About phone → tap Build number 7 times).
2. Enable USB Debugging.
3. Connect via USB, then `adb install path/to/app-debug.apk`.

Or, transfer the APK to the device (cloud, AirDrop-equivalent, etc.) and tap to install. Android will prompt to allow installs from this source.

## Project layout

```
app/                                    # the application module
├── build.gradle.kts                    # module build script
├── src/main/
│   ├── AndroidManifest.xml
│   ├── kotlin/com/corey/notepad3/
│   │   └── MainActivity.kt             # Android editor entry point
│   └── res/                            # icons, strings, themes
build.gradle.kts                        # root build
settings.gradle.kts                     # module wiring
gradle.properties                       # JVM flags + AGP feature flags
gradle/
├── libs.versions.toml                  # version catalog
└── wrapper/                            # gradle wrapper jar/properties
gradlew, gradlew.bat                    # wrapper scripts
```
