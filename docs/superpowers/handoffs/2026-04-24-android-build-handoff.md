# Android Build Handoff — 2026-04-24

## Status

Green on first try. Workflow `Build Android` on `main` produces a sideload-able debug APK.

> Runtime install/launch on a device is **not** verified in this handoff — only structural verification (manifest, ABIs, autolinked components, debug signing). Sideload to a real Android device or attach an emulator-launch CI step to close the runtime gap. Debug APKs from AGP have effectively zero install-time failure rate when structural checks pass, so the gap is theoretical, but documenting the boundary.

- **First successful run:** [24921462661](https://github.com/xuninc/Notepad3-/actions/runs/24921462661) (2026-04-25T03:24Z → 03:42Z, ~18 min total)
- **Wiring commit:** `b0332de` — adds `app.json` android.package, `prebuild:android` script, `scripts/prebuild-android.sh`, `.github/workflows/build-android.yml`
- **Plan:** `docs/superpowers/plans/2026-04-24-android-build.md`

## Verified APK

Downloaded from artifact `notepad3pp-debug-apk` of run 24921462661:

- Size: 186 MB (debug; full ABI set, no R8/proguard, no hermes-only)
- Package: `com.corey.android.np3plusplus`
- ABIs: `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`
- Files: 1264 entries (21 dex, expected expo-modules-core / reanimated / worklets / play-services native libs)
- Components present: `MainActivity`, `MainApplication`, `ClipboardFileProvider`, `FileSystemFileProvider`, `ImagePickerFileProvider`, plus the cropper FileProvider — i.e. the full Expo/RN module surface autolinked correctly.
- New Architecture (`newArchEnabled: true`) is on; the build proves the dep set works on Android with new arch.

## How to build

### CI (default)

```bash
gh workflow run build-android.yml --ref main
gh run watch --exit-status
gh run download <run-id> -n notepad3pp-debug-apk
```

Or push a tag matching `android-v*` (e.g. `android-v1.0.0`).

The job runs on `ubuntu-latest`, takes ~15–20 min cold, ~5–10 min warm thanks to the pnpm-store cache and the gradle setup-action.

### Local (Linux/WSL or macOS, requires Android SDK + JDK 17 on host)

```bash
cd artifacts/mobile
pnpm run prebuild:android        # runs expo prebuild --platform android --clean
(cd android && ./gradlew assembleDebug)
# → artifacts/mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

Corey's WSL doesn't have the Android SDK installed yet — CI is the path of least resistance for now. If you ever want local builds, the lightest setup is:

```bash
sudo apt-get install -y openjdk-17-jdk
# then download command-line tools, accept licenses, install platforms;android-34 + build-tools;34.0.0
```

## Knobs

| What | Where | Default |
| --- | --- | --- |
| applicationId | `artifacts/mobile/app.json` → `expo.android.package` | `com.corey.android.np3plusplus` |
| versionCode | `expo.android.versionCode` | `1` (auto, bump on releases) |
| version name | `expo.version` | `1.0.0` (shared with iOS) |
| New Arch | `expo.newArchEnabled` | `true` |
| Workflow runner | `.github/workflows/build-android.yml` → `runs-on` | `ubuntu-latest` |
| Java | `actions/setup-java@v4` | Temurin 17 |

## Known fixes applied

None. First commit (`b0332de`) was clean — gradle assembleDebug succeeded on the first run. The advisor pre-flagged three risk areas (worklets/new-arch codegen, gradle OOM on the 7GB runner, iOS-only modules breaking autolinking) — none materialized.

## Open follow-ups (out of scope here)

- Release-signed APK (production keystore + `assembleRelease` + signing config) — needed for Play Store or for sharing builds outside trusted devices
- Play Store AAB (`bundleRelease`) — dual-step from release flow
- ABI splits / per-abi APK uploads — would shrink the 186 MB debug build dramatically (target: ~30–60 MB per ABI for release)
- Hermes engine confirmation on Android (likely on by default in SDK 54; verify if perf matters)
- Replit "artifacts" surface integration so the Android artifact is reachable the same way iOS is
- Symmetric `feat/android-native-port` workstream (Kotlin/Compose mirror of `artifacts/ios-native/`) — distinct from the Expo build covered here

## Why this lives on `main`, not a branch

Workflow + minimal config additions are additive to existing infra (mirrors how the iOS build's `main.yml` lives on main while `feat/ios-native-port` is the separate native-port workstream). Adding Android wiring directly to `main` keeps the iOS port branch focused and lets `main` produce both platform builds.
