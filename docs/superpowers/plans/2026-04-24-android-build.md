# Android Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a working, sideload-able debug APK of the Notepad 3++ Expo app from CI. End state: a green `Build Android` workflow run that uploads `notepad3pp-debug-apk` artifact, plus a handoff doc.

**Architecture:** Mirror the existing iOS CI pipeline. Use Expo's prebuild to generate a native Android project at `artifacts/mobile/android/`, then build with Gradle's `assembleDebug` on `ubuntu-latest`. Debug-keystore signing is auto-applied by AGP — no signing infra required for sideload-friendly APKs. Handle the discovered failure modes empirically: re-trigger after each fix, watch logs, iterate.

**Tech Stack:** Expo SDK 54 (~54.0.27), React Native 0.81.5 with new architecture, Java 17 (Temurin), Android Gradle Plugin 8.x, Gradle 8.x, pnpm 9 workspaces, Node 20.

**Files:**
- Modify: `artifacts/mobile/app.json` — Android `package` (already added: `com.corey.android.np3plusplus`)
- Modify: `artifacts/mobile/package.json` — `prebuild:android` script (already added)
- Create: `artifacts/mobile/scripts/prebuild-android.sh` — local prebuild helper (already added)
- Create: `.github/workflows/build-android.yml` — Ubuntu CI workflow (already added)
- Create on completion: `docs/superpowers/handoffs/2026-04-24-android-build-handoff.md`

The first cut of all four files was committed in `b0332de` and has progressed through Expo prebuild + Gradle setup successfully on the first run; the open question is whether `gradlew assembleDebug` itself completes. This plan drives the remaining triage to closure.

---

### Task 1: Observe the in-flight build's outcome

**Files:** none

- [ ] **Step 1: Block on the run until terminal**

```bash
gh run watch 24921462661 --exit-status
```

Exits 0 on success, non-zero on failure. Cleaner than poll loops.

- [ ] **Step 2: If success, jump to Task 6 (verify artifact)**

- [ ] **Step 3: If failure, capture the failed step's log**

```bash
gh run view 24921462661 --log-failed > /tmp/android-build-fail.log
tail -200 /tmp/android-build-fail.log
```

Identify which step failed. The plan branches by failure step:
- "Install workspace dependencies" → Task 2
- "Expo prebuild (Android)" → Task 3
- "Build debug APK" → Task 4 or Task 5 (sub-cases by error type)
- "Upload debug APK" → Task 6 (file path mismatch)

- [ ] **Step 4: Commit nothing for this task; this is observation only**

---

### Task 2: Fix workspace dependency install (only if Task 1 routed here)

**Files:**
- Modify (possibly): `.github/workflows/build-android.yml`
- Modify (possibly): `pnpm-workspace.yaml`

- [ ] **Step 1: Look at the precise failure**

`pnpm install --no-frozen-lockfile` typically fails on:
- Missing native build tooling for a transitive dep — uncommon on Ubuntu, but `node-gyp` deps may need `python3` (already available)
- Network flakes — re-run is usually enough
- `catalog:` resolution — workspace catalog mismatch

- [ ] **Step 2: If network flake, re-trigger with `gh workflow run build-android.yml --ref main`**

- [ ] **Step 3: If catalog or lockfile drift, regenerate the lockfile locally**

```bash
cd /home/corey/repos/xuninc/Notepad3-
pnpm install --no-frozen-lockfile
git diff pnpm-lock.yaml | head -40
git add pnpm-lock.yaml
git commit -m "chore: refresh lockfile for android prebuild"
git push origin main
```

- [ ] **Step 4: Re-trigger the workflow and return to Task 1**

---

### Task 3: Fix Expo prebuild Android failure

**Files:**
- Modify (possibly): `artifacts/mobile/app.json`
- Modify (possibly): `artifacts/mobile/package.json`

- [ ] **Step 1: Read the failed step output for the autolinking / config-plugin error**

```bash
gh run view <run-id> --log-failed | grep -E "(error|Error|failed|FAILURE)" | head -40
```

Common failure shapes:
- `Cannot find module 'expo-glass-effect/plugin'` — config plugin not registered or iOS-only without Android shim
- `expo-symbols` autolinking — iOS-only; should not break Android prebuild but may warn
- `babel-preset-expo` resolution — pnpm hoisting issue
- Missing `package` in app.json (already provided — `com.corey.android.np3plusplus`)

- [ ] **Step 2: For an iOS-only module breaking Android, scope it to ios in app.json plugins**

If `expo-glass-effect` or another iOS-only plugin needs scoping, change:

```json
"plugins": [
  ["expo-router", { "origin": "https://replit.com/" }],
  "expo-font",
  "expo-web-browser"
]
```

Note: those three are cross-platform — fine. iOS-only modules listed in `dependencies` (not `plugins`) auto-skip on Android via Expo autolinking. If a specific module errors, add a `react-native.config.js` override:

```js
module.exports = {
  dependencies: {
    "expo-glass-effect": { platforms: { android: null } },
  },
};
```

- [ ] **Step 3: Commit + push**

```bash
git add artifacts/mobile/app.json artifacts/mobile/react-native.config.js 2>/dev/null
git commit -m "fix(android): scope iOS-only modules out of android prebuild"
git push origin main
```

- [ ] **Step 4: Re-trigger workflow, return to Task 1**

---

### Task 4: Fix Gradle compile / autolinking failure

**Files:**
- Modify (possibly): `artifacts/mobile/app.json`
- Modify (possibly): `.github/workflows/build-android.yml`

- [ ] **Step 1: Diagnose by reading the gradle error**

```bash
gh run view <run-id> --log-failed | sed -n '/Build debug APK/,$p' | head -300
```

Common failure shapes (in order of likelihood for Expo SDK 54 + RN 0.81.5 + new-arch):

A) **`react-native-worklets` / `react-native-reanimated` codegen mismatch** — RN 0.81 changed codegen output; if reanimated/worklets versions are pinned to the workspace catalog and don't match, the C++ codegen step fails.

B) **`react-native-keyboard-controller` Android module not found** — sometimes pnpm hoisting + autolinking miss it.

C) **`compileSdk` / `targetSdk` Java compatibility** — Java 17 + AGP 8.x + targetSdk 34 should be fine; if compileSdk is set higher (35) than what `android-sdk` provides, install via `sdkmanager`.

D) **Out-of-memory in gradle daemon** — Ubuntu runner has 7GB; new-arch + worklets is heavy. Set `org.gradle.jvmargs=-Xmx5g`.

- [ ] **Step 2A: For codegen / new-arch issues, try toggling new-arch off as a probe**

Edit `artifacts/mobile/app.json`:

```json
"newArchEnabled": false
```

Commit + push + re-run. If it passes with `false`, restore to `true` and pin reanimated/worklets to versions known-good with RN 0.81. If it fails the same way with `false`, the issue isn't new-arch — proceed.

- [ ] **Step 2B: For OOM, set jvm args via gradle.properties**

Add to `artifacts/mobile/scripts/prebuild-android.sh` after the prebuild call:

```bash
cat >> android/gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx5g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
EOF
```

And add the same step in CI right before `Build debug APK`:

```yaml
      - name: Tune Gradle memory
        working-directory: artifacts/mobile/android
        run: |
          echo "org.gradle.jvmargs=-Xmx5g -XX:MaxMetaspaceSize=1g -Dfile.encoding=UTF-8" >> gradle.properties
```

- [ ] **Step 2C: For missing SDK, add android-actions/setup-android@v3 step**

Insert before "Setup Gradle" in the workflow:

```yaml
      - name: Setup Android SDK
        uses: android-actions/setup-android@v3
        with:
          packages: "platforms;android-34 build-tools;34.0.0"
```

- [ ] **Step 3: Commit the targeted fix, push, re-trigger, return to Task 1**

---

### Task 5: Fix per-module-specific Android failure (catch-all)

**Files:**
- Create (possibly): `artifacts/mobile/react-native.config.js`
- Modify (possibly): `artifacts/mobile/package.json`

- [ ] **Step 1: Identify the offending module from the gradle log**

Look for the last `> Task :<module>:<task> FAILED` line. Module name (e.g. `:expo-glass-effect`) is your target.

- [ ] **Step 2: Decide: drop the module from Android, or fix it**

For an iOS-only module that no-ops on Android, write `react-native.config.js`:

```js
module.exports = {
  dependencies: {
    "expo-glass-effect": { platforms: { android: null } },
    "expo-symbols": { platforms: { android: null } },
  },
};
```

- [ ] **Step 3: For a version-mismatched module, use `expo install` (not raw `pnpm add`)**

Expo CLI picks the SDK-54-compatible version automatically:

```bash
cd artifacts/mobile
pnpm exec expo install <pkg>
git add package.json ../../pnpm-lock.yaml
git commit -m "fix(android): pin <pkg> to Expo SDK 54 compatible"
```

Bypassing the matrix with raw `pnpm add` can resolve at install but crash at runtime — don't do it.

- [ ] **Step 4: Commit + push + re-trigger + return to Task 1**

---

### Task 6: Verify the APK artifact

**Files:** none

- [ ] **Step 1: Confirm successful run**

```bash
gh run list --workflow=build-android.yml --limit 1 --json conclusion,databaseId
```

Expected: `"conclusion": "success"`.

- [ ] **Step 2: Download the artifact**

```bash
mkdir -p /tmp/np3pp-android && cd /tmp/np3pp-android
gh run download <run-id> -n notepad3pp-debug-apk
ls -lah
```

Expected: one or more `*.apk` files (likely `app-debug.apk`, ~30–60 MB).

- [ ] **Step 3: Sanity-check the APK (works without aapt2 on WSL)**

```bash
# unzip listing — confirms it's a real APK
unzip -l app-debug.apk | head -20
# applicationId / label inside the binary manifest
unzip -p app-debug.apk AndroidManifest.xml | strings -a | grep -iE "com\\.corey|notepad" | head
# signing cert (debug keystore)
unzip -p app-debug.apk META-INF/CERT.RSA 2>/dev/null \
  | openssl pkcs7 -inform DER -print_certs 2>/dev/null | head -10
```

Expected: package contains `com.corey.android.np3plusplus`, label visible as `Notepad 3++`, debug-keystore cert (CN=Android Debug).

- [ ] **Step 4: Commit nothing; this task is verification only**

---

### Task 7: Write the handoff doc

**Files:**
- Create: `docs/superpowers/handoffs/2026-04-24-android-build-handoff.md`

- [ ] **Step 1: Write the handoff with concrete state**

```markdown
# Android Build Handoff — 2026-04-24

## Status

Green. `Build Android` workflow on `main` produces a sideload-able debug APK.

## How to build

- **CI:** trigger via `gh workflow run build-android.yml --ref main` or push a tag `android-v*`. Artifact `notepad3pp-debug-apk` contains the APK.
- **Local (requires Android SDK + JDK 17 on host):**

  ```bash
  cd artifacts/mobile
  pnpm run prebuild:android
  (cd android && ./gradlew assembleDebug)
  # → android/app/build/outputs/apk/debug/app-debug.apk
  ```

## Knobs

- `app.json` → `expo.android.package` controls applicationId
- `app.json` → `expo.android.versionCode` (default 1) — bump on releases
- `newArchEnabled: true` is on; the build proves it works on Android with current pinned deps

## Known fixes applied along the way

[List the actual fixes applied — e.g. "added react-native.config.js to scope expo-glass-effect to iOS only", "tuned gradle JVM heap to 5g", etc. Skip this section if the first build was clean.]

## Open follow-ups

- Release-signed APK (production keystore) — not in scope
- Play Store AAB (`assembleRelease` + `bundleRelease`) — not in scope
- Wiring into Replit "artifacts" surface — not in scope
```

- [ ] **Step 2: Commit + push**

```bash
git add docs/superpowers/handoffs/2026-04-24-android-build-handoff.md
git commit -m "docs(android): build handoff after first green CI run"
git push origin main
```

---

### Task 8: Final advisor checkpoint

**Files:** none

- [ ] **Step 1: Call advisor with the full execution transcript**

The advisor should confirm:
- The APK is real (not a 0-byte upload)
- The applicationId / label match expectations
- No silent shortcuts taken (e.g. didn't disable a critical module)
- Plan items are all checked off or explicitly deferred

- [ ] **Step 2: Address any feedback before declaring done**
