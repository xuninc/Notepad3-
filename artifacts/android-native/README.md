# Notepad 3++ — Native Android Port

Kotlin / Jetpack Compose implementation of Notepad 3++ for Android. Sibling to the iOS Swift port at `../ios-native/`. The iOS app is the *behavioral oracle* — every design decision here matches iOS unless platform constraints force a substitution.

See `docs/superpowers/specs/2026-04-26-android-native-port-design.md` for the full design and `docs/superpowers/plans/2026-04-26-android-native-phase-0.md` for the phase-0 plan.

## Status

**Phase 0** — Skeleton + CI. The current APK launches and shows a Compose hello screen. Real features land in subsequent phases per the spec.

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
│   │   └── MainActivity.kt             # Phase 0 entry point
│   └── res/                            # icons, strings, themes
build.gradle.kts                        # root build
settings.gradle.kts                     # module wiring
gradle.properties                       # JVM flags + AGP feature flags
gradle/
├── libs.versions.toml                  # version catalog
└── wrapper/                            # gradle wrapper jar/properties
gradlew, gradlew.bat                    # wrapper scripts
```
