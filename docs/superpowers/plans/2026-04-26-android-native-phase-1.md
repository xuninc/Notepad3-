# Android Native Phase 1 Implementation Plan — Editor + Persistence + Theme

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (single-session, sequential dependencies) or superpowers:subagent-driven-development to implement this plan task-by-task. **Each task ends with a fresh verification command + an advisor checkpoint that sees the evidence — that is the user's explicit instruction. "Should work" is not a status.** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land a tap-and-type-able Notepad 3++ Android app on `feat/android-native-port`. Notes persist to JSON, prefs persist to SharedPreferences, theme switches live (8 named palettes), undo/redo works on a hand-rolled stack. Mobile layout only (TopAppBar + editor); chrome and classic mode come in Phase 2.

**Architecture:** Kotlin-only. Persistence via JSON file (`notes-v1.json` in `filesDir`) + `SharedPreferences("notepad3pp", MODE_PRIVATE)`. Singletons via class + companion-object pattern, initialized once via `androidx.startup` Initializer. State exposed as `StateFlow`; Compose collects with `collectAsState()`. Editor is a classic `EditText` inside an `AndroidView`, with a `TextWatcher` recording into `UndoStack`. Programmatic body changes are flagged so they don't double-record.

**Tech Stack:** Kotlin 2.1.0, Jetpack Compose (BOM 2024.12.01), kotlinx-serialization-json 1.7.3, androidx.startup 1.2.0, androidx.lifecycle viewmodel-compose 2.8.7, JUnit 4.13.2 + kotlinx-coroutines-test 1.9.0 for unit tests.

---

## Verification doctrine

Every task in this plan has a **Verification step** that runs a real command (or sequence) and reads the actual output. Then an **Advisor checkpoint** that hands the advisor the evidence and any concrete uncertainty. Only after both does the task get marked done. Words like "should", "probably", "looks correct" are banned in completion claims; only words backed by visible output ("11/11 tests pass per JUnit output") are allowed.

For tasks 1–5 the verification is `./gradlew :app:test --tests "<test class pattern>"` on CI (since local JVM is broken in this dev sandbox — see Phase 0 plan). Push, watch, read CI output. For tasks 6–7 the verification is the assembled APK installed on the emulator — read screenshots, observe behavior. For task 8 it's `gh run watch --exit-status` and a manual sideload check.

**No fake green: if a JVM unit test would pass on a working machine but the CI run is red, the task is not done.**

---

### Task 1: Models + serializers + tests

**Files:**
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/models/Note.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/models/NoteLanguage.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/models/NotesSnapshot.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/models/IsoMillisSerializer.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/models/Prefs.kt` (enums: TabsLayout, ToolbarRows, AccessoryRows, LayoutMode, StarterContent, ThemePreference)
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/theme/ThemeName.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/theme/Palette.kt` (data class + 8 named constants)
- Create: `artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/models/NoteLanguageTest.kt`
- Create: `artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/models/IsoMillisSerializerTest.kt`
- Create: `artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/theme/PaletteTest.kt`
- Modify: `artifacts/android-native/gradle/libs.versions.toml` — add new versions/aliases
- Modify: `artifacts/android-native/app/build.gradle.kts` — add kotlinx-serialization plugin + deps + JUnit + coroutines-test

- [ ] **Step 1: Add dependencies to the version catalog**

Edit `gradle/libs.versions.toml`. Replace its contents with:

```toml
[versions]
agp = "8.7.0"
kotlin = "2.1.0"
coreKtx = "1.15.0"
lifecycleRuntimeKtx = "2.8.7"
lifecycleViewmodelCompose = "2.8.7"
activityCompose = "1.9.3"
composeBom = "2024.12.01"
serialization = "1.7.3"
startup = "1.2.0"
junit = "4.13.2"
coroutinesTest = "1.9.0"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }
androidx-lifecycle-runtime-ktx = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version.ref = "lifecycleRuntimeKtx" }
androidx-lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycleViewmodelCompose" }
androidx-activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
androidx-compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
androidx-ui = { group = "androidx.compose.ui", name = "ui" }
androidx-ui-graphics = { group = "androidx.compose.ui", name = "ui-graphics" }
androidx-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
androidx-material3 = { group = "androidx.compose.material3", name = "material3" }
androidx-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
androidx-startup-runtime = { group = "androidx.startup", name = "startup-runtime", version.ref = "startup" }
kotlinx-serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "serialization" }
junit = { group = "junit", name = "junit", version.ref = "junit" }
kotlinx-coroutines-test = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutinesTest" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```

- [ ] **Step 2: Wire the new plugin + deps into `app/build.gradle.kts`**

Open `app/build.gradle.kts` and edit the `plugins {}` and `dependencies {}` blocks. Replace the file with:

```kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.corey.notepad3"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.corey.android.np3plusplus"
        minSdk = 30
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    sourceSets {
        named("main") {
            java.srcDirs("src/main/kotlin")
        }
        named("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.startup.runtime)
    implementation(libs.kotlinx.serialization.json)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)

    debugImplementation(libs.androidx.ui.tooling)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
}
```

- [ ] **Step 3: Write `models/Note.kt`**

```kotlin
package com.corey.notepad3.models

import kotlinx.serialization.Serializable

@Serializable
data class Note(
    val id: String,
    val title: String,
    val body: String,
    @Serializable(with = IsoMillisSerializer::class) val createdAt: Long,
    @Serializable(with = IsoMillisSerializer::class) val updatedAt: Long,
    val language: NoteLanguage = NoteLanguage.PLAIN,
)
```

- [ ] **Step 4: Write `models/NoteLanguage.kt`**

```kotlin
package com.corey.notepad3.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class NoteLanguage {
    @SerialName("plain") PLAIN,
    @SerialName("markdown") MARKDOWN,
    @SerialName("assembly") ASSEMBLY,
    @SerialName("javascript") JAVASCRIPT,
    @SerialName("python") PYTHON,
    @SerialName("web") WEB,
    @SerialName("json") JSON;

    companion object {
        /** Detect language from a filename's extension. Returns PLAIN if unknown. */
        fun fromFilename(name: String): NoteLanguage {
            val ext = name.substringAfterLast('.', missingDelimiterValue = "").lowercase()
            return when (ext) {
                "md", "markdown" -> MARKDOWN
                "asm", "s" -> ASSEMBLY
                "js", "ts", "jsx", "tsx", "mjs", "cjs" -> JAVASCRIPT
                "py", "pyw" -> PYTHON
                "html", "htm", "css", "xml", "svg" -> WEB
                "json", "jsonc" -> JSON
                else -> PLAIN
            }
        }
    }
}
```

- [ ] **Step 5: Write `models/NotesSnapshot.kt`**

```kotlin
package com.corey.notepad3.models

import kotlinx.serialization.Serializable

@Serializable
data class NotesSnapshot(
    val notes: List<Note>,
    val activeId: String,
)
```

- [ ] **Step 6: Write `models/IsoMillisSerializer.kt`**

```kotlin
package com.corey.notepad3.models

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant

/**
 * Serializes a Long epoch-millis timestamp as an ISO-8601 string on the wire,
 * matching the iOS port's date encoding (Foundation's ISO8601DateFormatter).
 *
 * Round-trip is millisecond-precise; the iOS app uses sub-millisecond precision
 * but only writes notes at user-tick rates, so the loss is invisible.
 */
object IsoMillisSerializer : KSerializer<Long> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("IsoMillis", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Long) {
        encoder.encodeString(Instant.ofEpochMilli(value).toString())
    }

    override fun deserialize(decoder: Decoder): Long =
        Instant.parse(decoder.decodeString()).toEpochMilli()
}
```

- [ ] **Step 7: Write `models/Prefs.kt`**

```kotlin
package com.corey.notepad3.models

import com.corey.notepad3.theme.ThemeName

enum class TabsLayout(val key: String) {
    TABS("tabs"),
    LIST("list");

    companion object {
        fun fromKey(key: String?, default: TabsLayout = TABS): TabsLayout =
            entries.firstOrNull { it.key == key } ?: default
    }
}

enum class ToolbarRows(val key: String) {
    SINGLE("single"),
    DOUBLE("double");

    companion object {
        fun fromKey(key: String?, default: ToolbarRows = SINGLE): ToolbarRows =
            entries.firstOrNull { it.key == key } ?: default
    }
}

enum class AccessoryRows(val key: String) {
    SINGLE("single"),
    DOUBLE("double");

    companion object {
        fun fromKey(key: String?, default: AccessoryRows = SINGLE): AccessoryRows =
            entries.firstOrNull { it.key == key } ?: default
    }
}

enum class LayoutMode(val key: String) {
    MOBILE("mobile"),
    CLASSIC("classic");

    companion object {
        fun fromKey(key: String?, default: LayoutMode = MOBILE): LayoutMode =
            entries.firstOrNull { it.key == key } ?: default
    }
}

enum class StarterContent(val key: String) {
    WELCOME("welcome"),
    BLANK("blank");

    companion object {
        fun fromKey(key: String?, default: StarterContent = WELCOME): StarterContent =
            entries.firstOrNull { it.key == key } ?: default
    }
}

/**
 * User's theme choice. Persisted as a string:
 *   "system"        — follow Configuration.uiMode
 *   "named:<name>"  — pin to the named theme
 */
sealed interface ThemePreference {
    data object System : ThemePreference
    data class Named(val name: ThemeName) : ThemePreference

    companion object {
        fun fromKey(key: String?): ThemePreference {
            if (key == "system" || key == null) return System
            val named = key.removePrefix("named:")
            val themeName = ThemeName.fromKey(named) ?: return System
            return Named(themeName)
        }

        fun toKey(pref: ThemePreference): String = when (pref) {
            is System -> "system"
            is Named -> "named:${pref.name.key}"
        }
    }
}
```

- [ ] **Step 8: Write `theme/ThemeName.kt`**

```kotlin
package com.corey.notepad3.theme

enum class ThemeName(val key: String, val display: String) {
    CLASSIC("classic", "Classic"),
    LIGHT("light", "Light"),
    DARK("dark", "Dark"),
    RETRO("retro", "Retro"),
    MODERN("modern", "Modern"),
    SUNSET("sunset", "Rachel's Sunset"),
    CYBERPUNK("cyberpunk", "Cyberpunk"),
    CUSTOM("custom", "Custom");

    companion object {
        fun fromKey(key: String?): ThemeName? =
            entries.firstOrNull { it.key == key }
    }
}
```

- [ ] **Step 9: Write `theme/Palette.kt`** — 19 fields, 8 named palettes, hex values copied verbatim from the iOS Swift `Models/Theme.swift`.

```kotlin
package com.corey.notepad3.theme

import androidx.compose.ui.graphics.Color

/**
 * Resolved color set for the active theme. 19 fields match the iOS port's
 * `Palette` struct one-for-one; named palettes have hex values copied verbatim
 * from `artifacts/ios-native/Sources/Notepad3/Models/Theme.swift`.
 *
 * Custom palette: start from [light] and overlay the user's per-field hex
 * overrides via [byOverlaying].
 */
data class Palette(
    val foreground: Color,
    val mutedForeground: Color,
    val background: Color,
    val card: Color,
    val muted: Color,
    val primary: Color,
    val primaryForeground: Color,
    val secondary: Color,
    val accent: Color,
    val border: Color,
    val editorBackground: Color,
    val editorGutter: Color,
    val success: Color,
    val destructive: Color,
    val titleGradientStart: Color,
    val titleGradientEnd: Color,
    val chromeGradientStart: Color,
    val chromeGradientEnd: Color,
    val radius: Float, // dp
) {
    fun byOverlaying(overrides: Map<String, String>): Palette {
        fun pick(field: String, fallback: Color): Color =
            overrides[field]?.let { hexToColor(it) } ?: fallback
        return copy(
            foreground = pick("foreground", foreground),
            mutedForeground = pick("mutedForeground", mutedForeground),
            background = pick("background", background),
            card = pick("card", card),
            muted = pick("muted", muted),
            primary = pick("primary", primary),
            primaryForeground = pick("primaryForeground", primaryForeground),
            secondary = pick("secondary", secondary),
            accent = pick("accent", accent),
            border = pick("border", border),
            editorBackground = pick("editorBackground", editorBackground),
            editorGutter = pick("editorGutter", editorGutter),
            success = pick("success", success),
            destructive = pick("destructive", destructive),
            titleGradientStart = pick("titleGradientStart", titleGradientStart),
            titleGradientEnd = pick("titleGradientEnd", titleGradientEnd),
            chromeGradientStart = pick("chromeGradientStart", chromeGradientStart),
            chromeGradientEnd = pick("chromeGradientEnd", chromeGradientEnd),
            radius = radius,
        )
    }

    companion object {
        // ---- named palettes (hex copied from iOS) ----

        val classic = Palette(
            foreground = hex("#0F1F33"),
            mutedForeground = hex("#5B6B85"),
            background = hex("#DBE5F1"),
            card = hex("#EAF1F9"),
            muted = hex("#C9D6E8"),
            primary = hex("#3A78C4"),
            primaryForeground = hex("#FFFFFF"),
            secondary = hex("#B4C9E2"),
            accent = hex("#5C9CE6"),
            border = hex("#9DB3CF"),
            editorBackground = hex("#FFFFFF"),
            editorGutter = hex("#E2EAF4"),
            success = hex("#2E8B57"),
            destructive = hex("#B22222"),
            titleGradientStart = hex("#5C9CE6"),
            titleGradientEnd = hex("#3A78C4"),
            chromeGradientStart = hex("#EAF1F9"),
            chromeGradientEnd = hex("#C9D6E8"),
            radius = 4f,
        )

        val light = Palette(
            foreground = hex("#1B1F23"),
            mutedForeground = hex("#6E7781"),
            background = hex("#F5F5F7"),
            card = hex("#FFFFFF"),
            muted = hex("#EDEDF0"),
            primary = hex("#0A64A4"),
            primaryForeground = hex("#FFFFFF"),
            secondary = hex("#E1E4E8"),
            accent = hex("#3F8CC0"),
            border = hex("#D0D7DE"),
            editorBackground = hex("#FFFFFF"),
            editorGutter = hex("#F0F2F4"),
            success = hex("#2DA44E"),
            destructive = hex("#CF222E"),
            titleGradientStart = hex("#3F8CC0"),
            titleGradientEnd = hex("#0A64A4"),
            chromeGradientStart = hex("#FFFFFF"),
            chromeGradientEnd = hex("#EDEDF0"),
            radius = 6f,
        )

        val dark = Palette(
            foreground = hex("#E6E6E6"),
            mutedForeground = hex("#9099A8"),
            background = hex("#1E1E1E"),
            card = hex("#262626"),
            muted = hex("#2E2E2E"),
            primary = hex("#4EA3DC"),
            primaryForeground = hex("#0B1A28"),
            secondary = hex("#3A3A3A"),
            accent = hex("#79C0FF"),
            border = hex("#3F3F3F"),
            editorBackground = hex("#1B1B1B"),
            editorGutter = hex("#252525"),
            success = hex("#3FB950"),
            destructive = hex("#F85149"),
            titleGradientStart = hex("#79C0FF"),
            titleGradientEnd = hex("#4EA3DC"),
            chromeGradientStart = hex("#262626"),
            chromeGradientEnd = hex("#1E1E1E"),
            radius = 6f,
        )

        val retro = Palette(
            foreground = hex("#000000"),
            mutedForeground = hex("#404040"),
            background = hex("#C0C0C0"),
            card = hex("#D4D0C8"),
            muted = hex("#A8A8A8"),
            primary = hex("#000080"),
            primaryForeground = hex("#FFFFFF"),
            secondary = hex("#808080"),
            accent = hex("#000080"),
            border = hex("#808080"),
            editorBackground = hex("#FFFFFF"),
            editorGutter = hex("#C0C0C0"),
            success = hex("#008000"),
            destructive = hex("#800000"),
            titleGradientStart = hex("#000080"),
            titleGradientEnd = hex("#000060"),
            chromeGradientStart = hex("#D4D0C8"),
            chromeGradientEnd = hex("#A8A8A8"),
            radius = 0f,
        )

        val modern = Palette(
            foreground = hex("#0F172A"),
            mutedForeground = hex("#64748B"),
            background = hex("#F8FAFC"),
            card = hex("#FFFFFF"),
            muted = hex("#F1F5F9"),
            primary = hex("#6366F1"),
            primaryForeground = hex("#FFFFFF"),
            secondary = hex("#8B5CF6"),
            accent = hex("#10B981"),
            border = hex("#E2E8F0"),
            editorBackground = hex("#FFFFFF"),
            editorGutter = hex("#F1F5F9"),
            success = hex("#10B981"),
            destructive = hex("#EF4444"),
            titleGradientStart = hex("#8B5CF6"),
            titleGradientEnd = hex("#6366F1"),
            chromeGradientStart = hex("#FFFFFF"),
            chromeGradientEnd = hex("#F1F5F9"),
            radius = 10f,
        )

        val sunset = Palette(
            foreground = hex("#3B0029"),
            mutedForeground = hex("#7A2A4F"),
            background = hex("#FFF6FA"),
            card = hex("#FFE4EE"),
            muted = hex("#FFD0DD"),
            primary = hex("#FF3D8A"),
            primaryForeground = hex("#FFFFFF"),
            secondary = hex("#FF7A3D"),
            accent = hex("#FFB347"),
            border = hex("#FFC9DA"),
            editorBackground = hex("#FFFAFC"),
            editorGutter = hex("#FFE0EA"),
            success = hex("#FF7A3D"),
            destructive = hex("#C81E63"),
            titleGradientStart = hex("#FF7A3D"),
            titleGradientEnd = hex("#FF3D8A"),
            chromeGradientStart = hex("#FFE4EE"),
            chromeGradientEnd = hex("#FFD0DD"),
            radius = 12f,
        )

        val cyberpunk = Palette(
            foreground = hex("#E0D9FF"),
            mutedForeground = hex("#8E80C0"),
            background = hex("#0B0820"),
            card = hex("#15123A"),
            muted = hex("#1F1A4D"),
            primary = hex("#FF2BD1"),
            primaryForeground = hex("#0B0820"),
            secondary = hex("#2B1F66"),
            accent = hex("#00F0FF"),
            border = hex("#3A2F80"),
            editorBackground = hex("#080518"),
            editorGutter = hex("#120F30"),
            success = hex("#00F0FF"),
            destructive = hex("#FF2BD1"),
            titleGradientStart = hex("#00F0FF"),
            titleGradientEnd = hex("#FF2BD1"),
            chromeGradientStart = hex("#15123A"),
            chromeGradientEnd = hex("#0B0820"),
            radius = 8f,
        )

        // ---- helpers ----

        private fun hex(s: String): Color = hexToColor(s)

        private fun hexToColor(s: String): Color {
            val raw = s.removePrefix("#")
            val long = raw.toLong(16)
            return when (raw.length) {
                6 -> Color(0xFF000000 or long)
                8 -> Color(long)
                else -> Color.Black
            }
        }

        fun named(theme: ThemeName): Palette = when (theme) {
            ThemeName.CLASSIC -> classic
            ThemeName.LIGHT -> light
            ThemeName.DARK -> dark
            ThemeName.RETRO -> retro
            ThemeName.MODERN -> modern
            ThemeName.SUNSET -> sunset
            ThemeName.CYBERPUNK -> cyberpunk
            ThemeName.CUSTOM -> light // base for custom; overlays applied by ThemeController
        }
    }
}
```

- [ ] **Step 10: Write `models/NoteLanguageTest.kt`**

```kotlin
package com.corey.notepad3.models

import org.junit.Assert.assertEquals
import org.junit.Test

class NoteLanguageTest {
    @Test fun `markdown extension`() = assertEquals(NoteLanguage.MARKDOWN, NoteLanguage.fromFilename("notes.md"))
    @Test fun `markdown long extension`() = assertEquals(NoteLanguage.MARKDOWN, NoteLanguage.fromFilename("draft.markdown"))
    @Test fun `javascript ts variants`() = assertEquals(NoteLanguage.JAVASCRIPT, NoteLanguage.fromFilename("app.tsx"))
    @Test fun `assembly`() = assertEquals(NoteLanguage.ASSEMBLY, NoteLanguage.fromFilename("boot.asm"))
    @Test fun `python`() = assertEquals(NoteLanguage.PYTHON, NoteLanguage.fromFilename("main.py"))
    @Test fun `web html`() = assertEquals(NoteLanguage.WEB, NoteLanguage.fromFilename("index.html"))
    @Test fun `web css`() = assertEquals(NoteLanguage.WEB, NoteLanguage.fromFilename("styles.css"))
    @Test fun `json`() = assertEquals(NoteLanguage.JSON, NoteLanguage.fromFilename("data.json"))
    @Test fun `unknown extension defaults to plain`() = assertEquals(NoteLanguage.PLAIN, NoteLanguage.fromFilename("notes.unknown"))
    @Test fun `no extension defaults to plain`() = assertEquals(NoteLanguage.PLAIN, NoteLanguage.fromFilename("notes"))
    @Test fun `case insensitive`() = assertEquals(NoteLanguage.MARKDOWN, NoteLanguage.fromFilename("README.MD"))
}
```

- [ ] **Step 11: Write `models/IsoMillisSerializerTest.kt`**

```kotlin
package com.corey.notepad3.models

import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class IsoMillisSerializerTest {
    private val json = Json { encodeDefaults = true }

    @Test fun `round trip a known epoch millis`() {
        val original = 1714000000000L // 2024-04-25T01:46:40Z
        val encoded = json.encodeToString(IsoMillisSerializer, original)
        val decoded = json.decodeFromString(IsoMillisSerializer, encoded)
        assertEquals(original, decoded)
    }

    @Test fun `encoded form is iso-8601 zulu`() {
        val encoded = json.encodeToString(IsoMillisSerializer, 0L)
        // Strip surrounding quotes from JSON-string encoding.
        val payload = encoded.removeSurrounding("\"")
        assertEquals("1970-01-01T00:00:00Z", payload)
    }

    @Test fun `note round trips through json`() {
        val note = Note(
            id = "n1",
            title = "Hello",
            body = "world",
            createdAt = 1700000000000L,
            updatedAt = 1700000123456L,
            language = NoteLanguage.MARKDOWN,
        )
        val encoded = json.encodeToString(Note.serializer(), note)
        val decoded = json.decodeFromString(Note.serializer(), encoded)
        assertEquals(note, decoded)
        // Sanity-check the wire format: createdAt should be a quoted ISO string, not a number.
        assertTrue("expected ISO timestamps in payload, got: $encoded", encoded.contains("\"createdAt\":\""))
    }
}
```

- [ ] **Step 12: Write `theme/PaletteTest.kt`**

```kotlin
package com.corey.notepad3.theme

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class PaletteTest {
    @Test fun `every named theme resolves and has reasonable foreground`() {
        ThemeName.entries.forEach { name ->
            val p = Palette.named(name)
            assertNotEquals("$name foreground should not be transparent", Color.Transparent, p.foreground)
        }
    }

    @Test fun `classic palette has known background`() {
        // #DBE5F1 — Notepad 2 / Aero blue.
        assertEquals(Color(0xFFDBE5F1), Palette.classic.background)
    }

    @Test fun `dark palette has dark background`() {
        // Just sanity: any reasonable "dark" background.
        val p = Palette.named(ThemeName.DARK)
        // Decompose to RGB 0..255 floats; assert mean is < 0.4 (i.e. dark).
        val mean = (p.background.red + p.background.green + p.background.blue) / 3f
        assertEquals(true, mean < 0.4f)
    }

    @Test fun `byOverlaying changes only specified fields`() {
        val base = Palette.classic
        val overlay = mapOf("primary" to "#FF00FF", "background" to "#000000")
        val out = base.byOverlaying(overlay)
        assertEquals(Color(0xFFFF00FF), out.primary)
        assertEquals(Color(0xFF000000), out.background)
        // Other fields untouched.
        assertEquals(base.foreground, out.foreground)
        assertEquals(base.border, out.border)
    }

    @Test fun `byOverlaying ignores unknown keys`() {
        val base = Palette.classic
        val out = base.byOverlaying(mapOf("notARealField" to "#FF00FF"))
        assertEquals(base, out)
    }
}
```

- [ ] **Step 13: Verification — push and let CI run the unit tests**

CI is the only place tests can run (local JVM is broken in this dev sandbox). Add a CI step that runs the unit tests.

Edit `.github/workflows/build-android-native.yml`. Replace the "Build debug APK" step with two steps that run tests *then* build:

```yaml
      - name: Unit tests
        shell: bash
        run: |
          set -euo pipefail
          chmod +x ./gradlew
          ./gradlew :app:test --no-daemon --stacktrace
          echo "==> Test reports:"
          find app/build/reports/tests -name "index.html" -print

      - name: Build debug APK
        shell: bash
        run: |
          set -euo pipefail
          ./gradlew :app:assembleDebug --no-daemon --stacktrace
          echo "==> APK outputs:"
          find app/build/outputs/apk -name "*.apk" -print
```

Also add a step that uploads the test report on failure, so the engineer can read the JUnit XML:

```yaml
      - name: Upload test reports on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-reports
          path: artifacts/android-native/app/build/reports/tests/
```

Push this commit + watch the run:

```bash
cd /Users/coreyhamilton/projects/Notepad3-
git add artifacts/android-native .github/workflows/build-android-native.yml
git commit -m "task 1 (android phase 1): models + serializers + tests + CI test step"
git push origin feat/android-native-port
gh workflow run "Build Android Native" --ref feat/android-native-port
sleep 6
gh run list --branch feat/android-native-port --limit 2
```

Watch the run:

```bash
RUN_ID=$(gh run list --branch feat/android-native-port --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

**Expected:** `gh run watch` exits 0 with a green "Build Android Native" run. The "Unit tests" step shows `BUILD SUCCESSFUL` and a non-zero number of tests passed (we have ~17 in this task). The "Build debug APK" step still produces an APK.

**If red:** read the failing step (`gh run view "$RUN_ID" --log-failed | tail -100`). Fix locally, re-push, re-trigger. Do NOT mark the task done on a red run.

- [ ] **Step 14: Advisor checkpoint**

Call advisor with a one-line summary of the verification result, e.g. *"Task 1 done; CI run 247xxxxxx green; 17 unit tests passed; APK produced."* Include any unexpected output. The advisor confirms or flags. Only after that does Task 1 close.

---

### Task 2: Preferences (SharedPreferences-backed singleton + StateFlow)

**Files:**
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence/PrefsPersister.kt` (interface + SharedPreferences impl)
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence/Preferences.kt` (singleton class)
- Create: `artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/persistence/PreferencesTest.kt`

- [ ] **Step 1: Write the persister abstraction**

`persistence/PrefsPersister.kt`:

```kotlin
package com.corey.notepad3.persistence

import android.content.Context

/**
 * Thin wrapper around SharedPreferences so [Preferences] is unit-testable
 * without Robolectric. Production uses [SharedPreferencesPersister]; tests
 * use [InMemoryPrefsPersister].
 */
interface PrefsPersister {
    fun read(key: String, default: String?): String?
    fun write(key: String, value: String?)
}

class SharedPreferencesPersister(context: Context) : PrefsPersister {
    private val sp = context.applicationContext
        .getSharedPreferences("notepad3pp", Context.MODE_PRIVATE)

    override fun read(key: String, default: String?): String? = sp.getString(key, default)

    override fun write(key: String, value: String?) {
        val editor = sp.edit()
        if (value == null) editor.remove(key) else editor.putString(key, value)
        editor.apply()
    }
}

/** In-memory persister for unit tests; no Android runtime needed. */
class InMemoryPrefsPersister : PrefsPersister {
    private val map = mutableMapOf<String, String?>()
    override fun read(key: String, default: String?): String? = map.getOrDefault(key, default)
    override fun write(key: String, value: String?) { map[key] = value }
}
```

- [ ] **Step 2: Write `Preferences.kt`**

```kotlin
package com.corey.notepad3.persistence

import android.content.Context
import com.corey.notepad3.models.AccessoryRows
import com.corey.notepad3.models.LayoutMode
import com.corey.notepad3.models.StarterContent
import com.corey.notepad3.models.TabsLayout
import com.corey.notepad3.models.ThemePreference
import com.corey.notepad3.models.ToolbarRows
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json

/**
 * Strongly-typed reactive preferences mirroring the iOS port's `Preferences.shared`.
 *
 * Each field is exposed as a [StateFlow]; setters update both disk and the flow
 * so any composable collecting the flow recomposes immediately. Persistence keys
 * match iOS one-for-one so a future cross-device sync layer can serve both apps.
 */
class Preferences(private val persister: PrefsPersister) {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }

    // ---- keys ----

    private val keyTabsLayout      = "notepad3pp.tabsLayout"
    private val keyToolbarLabels   = "notepad3pp.toolbarLabels"
    private val keyToolbarRows     = "notepad3pp.toolbarRows"
    private val keyAccessoryRows   = "notepad3pp.accessoryRows"
    private val keyLayoutMode      = "notepad3pp.layoutMode"
    private val keyStarterContent  = "notepad3pp.starterContent"
    private val keyCustomPalette   = "notepad3pp.customPalette"
    private val keyThemePreference = "notepad3pp.themePreference"

    // ---- flows ----

    private val _tabsLayout = MutableStateFlow(TabsLayout.fromKey(persister.read(keyTabsLayout, null)))
    val tabsLayout: StateFlow<TabsLayout> = _tabsLayout.asStateFlow()

    private val _toolbarLabels = MutableStateFlow(persister.read(keyToolbarLabels, null) == "true")
    val toolbarLabels: StateFlow<Boolean> = _toolbarLabels.asStateFlow()

    private val _toolbarRows = MutableStateFlow(ToolbarRows.fromKey(persister.read(keyToolbarRows, null)))
    val toolbarRows: StateFlow<ToolbarRows> = _toolbarRows.asStateFlow()

    private val _accessoryRows = MutableStateFlow(AccessoryRows.fromKey(persister.read(keyAccessoryRows, null)))
    val accessoryRows: StateFlow<AccessoryRows> = _accessoryRows.asStateFlow()

    private val _layoutMode = MutableStateFlow(LayoutMode.fromKey(persister.read(keyLayoutMode, null)))
    val layoutMode: StateFlow<LayoutMode> = _layoutMode.asStateFlow()

    private val _starterContent = MutableStateFlow(StarterContent.fromKey(persister.read(keyStarterContent, null)))
    val starterContent: StateFlow<StarterContent> = _starterContent.asStateFlow()

    private val _customPalette = MutableStateFlow(loadCustomPalette())
    val customPalette: StateFlow<Map<String, String>> = _customPalette.asStateFlow()

    private val _themePreference = MutableStateFlow(ThemePreference.fromKey(persister.read(keyThemePreference, null)))
    val themePreference: StateFlow<ThemePreference> = _themePreference.asStateFlow()

    // ---- setters ----

    fun setTabsLayout(value: TabsLayout) {
        if (_tabsLayout.value == value) return
        persister.write(keyTabsLayout, value.key)
        _tabsLayout.value = value
    }

    fun setToolbarLabels(value: Boolean) {
        if (_toolbarLabels.value == value) return
        persister.write(keyToolbarLabels, if (value) "true" else "false")
        _toolbarLabels.value = value
    }

    fun setToolbarRows(value: ToolbarRows) {
        if (_toolbarRows.value == value) return
        persister.write(keyToolbarRows, value.key)
        _toolbarRows.value = value
    }

    fun setAccessoryRows(value: AccessoryRows) {
        if (_accessoryRows.value == value) return
        persister.write(keyAccessoryRows, value.key)
        _accessoryRows.value = value
    }

    fun setLayoutMode(value: LayoutMode) {
        if (_layoutMode.value == value) return
        persister.write(keyLayoutMode, value.key)
        _layoutMode.value = value
    }

    fun setStarterContent(value: StarterContent) {
        if (_starterContent.value == value) return
        persister.write(keyStarterContent, value.key)
        _starterContent.value = value
    }

    fun setCustomPalette(value: Map<String, String>) {
        if (_customPalette.value == value) return
        persister.write(keyCustomPalette, json.encodeToString(value))
        _customPalette.value = value
    }

    fun setThemePreference(value: ThemePreference) {
        if (_themePreference.value == value) return
        persister.write(keyThemePreference, ThemePreference.toKey(value))
        _themePreference.value = value
    }

    // ---- helpers ----

    private fun loadCustomPalette(): Map<String, String> {
        val raw = persister.read(keyCustomPalette, null) ?: return emptyMap()
        return runCatching { json.decodeFromString<Map<String, String>>(raw) }.getOrDefault(emptyMap())
    }

    companion object {
        @Volatile private var instance: Preferences? = null

        fun init(context: Context) {
            if (instance == null) {
                instance = Preferences(SharedPreferencesPersister(context.applicationContext))
            }
        }

        val shared: Preferences
            get() = instance ?: error("Preferences.init(context) must be called before Preferences.shared")
    }
}
```

- [ ] **Step 3: Write `PreferencesTest.kt`**

```kotlin
package com.corey.notepad3.persistence

import com.corey.notepad3.models.AccessoryRows
import com.corey.notepad3.models.LayoutMode
import com.corey.notepad3.models.StarterContent
import com.corey.notepad3.models.TabsLayout
import com.corey.notepad3.models.ThemePreference
import com.corey.notepad3.models.ToolbarRows
import com.corey.notepad3.theme.ThemeName
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PreferencesTest {
    @Test fun `defaults match the spec`() {
        val p = Preferences(InMemoryPrefsPersister())
        assertEquals(TabsLayout.TABS, p.tabsLayout.value)
        assertFalse(p.toolbarLabels.value)
        assertEquals(ToolbarRows.SINGLE, p.toolbarRows.value)
        assertEquals(AccessoryRows.SINGLE, p.accessoryRows.value)
        assertEquals(LayoutMode.MOBILE, p.layoutMode.value)
        assertEquals(StarterContent.WELCOME, p.starterContent.value)
        assertEquals(emptyMap<String, String>(), p.customPalette.value)
        assertEquals(ThemePreference.System, p.themePreference.value)
    }

    @Test fun `setters update flows and persist`() {
        val persister = InMemoryPrefsPersister()
        val p = Preferences(persister)
        p.setLayoutMode(LayoutMode.CLASSIC)
        p.setToolbarLabels(true)
        p.setThemePreference(ThemePreference.Named(ThemeName.DARK))
        assertEquals(LayoutMode.CLASSIC, p.layoutMode.value)
        assertTrue(p.toolbarLabels.value)
        assertEquals(ThemePreference.Named(ThemeName.DARK), p.themePreference.value)
        // Verify a second instance backed by the same persister sees the changes.
        val q = Preferences(persister)
        assertEquals(LayoutMode.CLASSIC, q.layoutMode.value)
        assertTrue(q.toolbarLabels.value)
        assertEquals(ThemePreference.Named(ThemeName.DARK), q.themePreference.value)
    }

    @Test fun `theme preference round trips named and system`() {
        val persister = InMemoryPrefsPersister()
        val p = Preferences(persister)
        p.setThemePreference(ThemePreference.Named(ThemeName.CYBERPUNK))
        assertEquals("named:cyberpunk", persister.read("notepad3pp.themePreference", null))
        p.setThemePreference(ThemePreference.System)
        assertEquals("system", persister.read("notepad3pp.themePreference", null))
    }

    @Test fun `custom palette JSON round trip`() {
        val persister = InMemoryPrefsPersister()
        val p = Preferences(persister)
        val overrides = mapOf("primary" to "#FF00FF", "background" to "#000000")
        p.setCustomPalette(overrides)
        // New instance reading from the same persister yields the same map.
        val q = Preferences(persister)
        assertEquals(overrides, q.customPalette.value)
    }

    @Test fun `setting same value is a no-op`() {
        val persister = InMemoryPrefsPersister()
        val p = Preferences(persister)
        p.setLayoutMode(LayoutMode.MOBILE) // already the default
        // Persister was never written to (still no key).
        assertEquals(null, persister.read("notepad3pp.layoutMode", null))
    }

    @Test fun `unknown enum key falls back to default`() {
        val persister = InMemoryPrefsPersister()
        persister.write("notepad3pp.tabsLayout", "garbage")
        val p = Preferences(persister)
        assertEquals(TabsLayout.TABS, p.tabsLayout.value)
    }
}
```

- [ ] **Step 4: Verification — push, watch tests pass**

```bash
cd /Users/coreyhamilton/projects/Notepad3-
git add artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence \
         artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/persistence
git commit -m "task 2 (android phase 1): Preferences singleton + PrefsPersister + tests"
git push origin feat/android-native-port
gh workflow run "Build Android Native" --ref feat/android-native-port
sleep 6
RUN_ID=$(gh run list --branch feat/android-native-port --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

**Expected:** Green run, both "Unit tests" and "Build debug APK" steps green. Cumulative test count is 17 + 6 = 23.

- [ ] **Step 5: Advisor checkpoint** — pass evidence (run id, test count). Get sign-off before moving on.

---

### Task 3: NotesStore (JSON-file-backed singleton + StateFlow)

**Files:**
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence/NotesStorage.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence/NotesStore.kt`
- Create: `artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/persistence/NotesStoreTest.kt`

- [ ] **Step 1: Write the storage abstraction**

`persistence/NotesStorage.kt`:

```kotlin
package com.corey.notepad3.persistence

import com.corey.notepad3.models.NotesSnapshot
import kotlinx.serialization.json.Json
import java.io.File

/** Same testability pattern as PrefsPersister: production uses [FileNotesStorage], tests use [InMemoryNotesStorage]. */
interface NotesStorage {
    fun load(): NotesSnapshot?
    fun save(snapshot: NotesSnapshot)
}

class FileNotesStorage(private val dir: File) : NotesStorage {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val file = File(dir, "notes-v1.json")

    override fun load(): NotesSnapshot? {
        if (!file.exists()) return null
        return runCatching { json.decodeFromString<NotesSnapshot>(file.readText()) }.getOrNull()
    }

    override fun save(snapshot: NotesSnapshot) {
        dir.mkdirs()
        // Atomic write: serialize to a sibling tmp, then rename.
        val tmp = File(dir, "notes-v1.json.tmp")
        tmp.writeText(json.encodeToString(snapshot))
        if (!tmp.renameTo(file)) {
            // renameTo can fail if file already exists on some FSes.
            file.delete()
            tmp.renameTo(file)
        }
    }
}

class InMemoryNotesStorage : NotesStorage {
    var saved: NotesSnapshot? = null
    override fun load(): NotesSnapshot? = saved
    override fun save(snapshot: NotesSnapshot) { saved = snapshot }
}
```

- [ ] **Step 2: Write `NotesStore.kt`** — full CRUD, observable via `StateFlow<NotesSnapshot>`.

```kotlin
package com.corey.notepad3.persistence

import android.content.Context
import com.corey.notepad3.models.Note
import com.corey.notepad3.models.NoteLanguage
import com.corey.notepad3.models.NotesSnapshot
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

/**
 * Reactive store of all open notes, mirroring iOS `NotesStore.shared`. Backed
 * by [storage] (JSON file in production); every mutation persists immediately.
 *
 * Operations match the iOS API one-for-one: setActive, updateActive, createBlank,
 * importNote, delete, rename, duplicate, closeOthers.
 */
class NotesStore(private val storage: NotesStorage, clock: () -> Long = { System.currentTimeMillis() }) {

    private val now: () -> Long = clock

    private val _state: MutableStateFlow<NotesSnapshot> = MutableStateFlow(loadOrSeed())
    val state: StateFlow<NotesSnapshot> = _state.asStateFlow()

    val active: Note get() = _state.value.notes.first { it.id == _state.value.activeId }

    fun setActive(id: String) {
        val s = _state.value
        if (s.activeId == id) return
        if (s.notes.none { it.id == id }) return
        write(s.copy(activeId = id))
    }

    fun updateActive(title: String? = null, body: String? = null, language: NoteLanguage? = null) {
        val s = _state.value
        val updated = s.notes.map { n ->
            if (n.id != s.activeId) n
            else n.copy(
                title = title ?: n.title,
                body = body ?: n.body,
                language = language ?: n.language,
                updatedAt = now(),
            )
        }
        write(s.copy(notes = updated))
    }

    fun createBlank(): String {
        val s = _state.value
        val taken = s.notes.map { it.title }.toSet()
        val title = generateSequence(1) { it + 1 }
            .map { "Untitled $it" }
            .first { it !in taken }
        val n = Note(
            id = UUID.randomUUID().toString(),
            title = title,
            body = "",
            createdAt = now(),
            updatedAt = now(),
            language = NoteLanguage.PLAIN,
        )
        write(s.copy(notes = s.notes + n, activeId = n.id))
        return n.id
    }

    fun importNote(title: String, body: String, language: NoteLanguage = NoteLanguage.fromFilename(title)): String {
        val s = _state.value
        val n = Note(
            id = UUID.randomUUID().toString(),
            title = title,
            body = body,
            createdAt = now(),
            updatedAt = now(),
            language = language,
        )
        write(s.copy(notes = s.notes + n, activeId = n.id))
        return n.id
    }

    fun delete(id: String) {
        val s = _state.value
        val remaining = s.notes.filterNot { it.id == id }
        if (remaining.isEmpty()) {
            // iOS: if last note is deleted, replace with a fresh blank.
            val n = Note(
                id = UUID.randomUUID().toString(),
                title = "Untitled 1",
                body = "",
                createdAt = now(),
                updatedAt = now(),
                language = NoteLanguage.PLAIN,
            )
            write(NotesSnapshot(listOf(n), n.id))
            return
        }
        val nextActive = if (s.activeId == id) remaining.first().id else s.activeId
        write(NotesSnapshot(remaining, nextActive))
    }

    fun rename(id: String, title: String) {
        val s = _state.value
        val updated = s.notes.map { if (it.id == id) it.copy(title = title, updatedAt = now()) else it }
        write(s.copy(notes = updated))
    }

    fun duplicate(id: String): String {
        val s = _state.value
        val source = s.notes.firstOrNull { it.id == id } ?: return id
        val copy = source.copy(
            id = UUID.randomUUID().toString(),
            title = "${source.title} copy",
            createdAt = now(),
            updatedAt = now(),
        )
        write(s.copy(notes = s.notes + copy, activeId = copy.id))
        return copy.id
    }

    fun closeOthers(keep: String) {
        val s = _state.value
        val kept = s.notes.firstOrNull { it.id == keep } ?: return
        write(NotesSnapshot(listOf(kept), kept.id))
    }

    private fun write(next: NotesSnapshot) {
        _state.value = next
        storage.save(next)
    }

    private fun loadOrSeed(): NotesSnapshot {
        storage.load()?.let { return it }
        // Seed: a single welcome note.
        val welcome = Note(
            id = UUID.randomUUID().toString(),
            title = "Welcome",
            body = "Welcome to Notepad 3++ on Android.\n\nTap to edit. Use the Theme menu to switch palettes.",
            createdAt = now(),
            updatedAt = now(),
            language = NoteLanguage.PLAIN,
        )
        val snap = NotesSnapshot(listOf(welcome), welcome.id)
        storage.save(snap)
        return snap
    }

    companion object {
        @Volatile private var instance: NotesStore? = null

        fun init(context: Context) {
            if (instance == null) {
                instance = NotesStore(FileNotesStorage(context.applicationContext.filesDir))
            }
        }

        val shared: NotesStore
            get() = instance ?: error("NotesStore.init(context) must be called before NotesStore.shared")
    }
}
```

- [ ] **Step 3: Write `NotesStoreTest.kt`**

```kotlin
package com.corey.notepad3.persistence

import com.corey.notepad3.models.Note
import com.corey.notepad3.models.NoteLanguage
import com.corey.notepad3.models.NotesSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NotesStoreTest {
    private fun store(initial: NotesSnapshot? = null): Pair<NotesStore, InMemoryNotesStorage> {
        val storage = InMemoryNotesStorage()
        if (initial != null) storage.save(initial)
        var t = 1000L
        val store = NotesStore(storage, clock = { t++ })
        return store to storage
    }

    @Test fun `seeds a welcome note when storage is empty`() {
        val (s, _) = store()
        assertEquals(1, s.state.value.notes.size)
        assertEquals("Welcome", s.state.value.notes.first().title)
        assertEquals(s.state.value.notes.first().id, s.state.value.activeId)
    }

    @Test fun `createBlank adds a note and makes it active`() {
        val (s, storage) = store()
        val id = s.createBlank()
        assertEquals(2, s.state.value.notes.size)
        assertEquals(id, s.state.value.activeId)
        assertEquals("Untitled 1", s.state.value.notes.last().title)
        // Persistence wrote the same snapshot.
        assertEquals(s.state.value, storage.saved)
    }

    @Test fun `createBlank picks the next free Untitled N`() {
        val (s, _) = store()
        s.createBlank()
        s.createBlank()
        val titles = s.state.value.notes.map { it.title }
        assertTrue(titles.contains("Untitled 1"))
        assertTrue(titles.contains("Untitled 2"))
    }

    @Test fun `updateActive mutates only the active note`() {
        val (s, _) = store()
        s.createBlank() // makes a 2nd note active
        s.updateActive(body = "hello world")
        assertEquals("hello world", s.active.body)
        // The first (welcome) note is untouched.
        val welcome = s.state.value.notes.first { it.title == "Welcome" }
        assertNotEquals("hello world", welcome.body)
    }

    @Test fun `delete reassigns active to the next remaining note`() {
        val (s, _) = store()
        val a = s.createBlank()
        val b = s.createBlank()
        s.setActive(a)
        s.delete(a)
        assertEquals(2, s.state.value.notes.size)
        assertNotEquals(a, s.state.value.activeId)
    }

    @Test fun `delete of last note reseeds a blank`() {
        val (s, _) = store()
        val only = s.state.value.activeId
        s.delete(only)
        assertEquals(1, s.state.value.notes.size)
        assertEquals("Untitled 1", s.state.value.notes.first().title)
    }

    @Test fun `rename updates the title`() {
        val (s, _) = store()
        val id = s.createBlank()
        s.rename(id, "My Note")
        assertEquals("My Note", s.state.value.notes.first { it.id == id }.title)
    }

    @Test fun `duplicate creates a copy with " copy" suffix and activates it`() {
        val (s, _) = store()
        val id = s.createBlank()
        s.rename(id, "Source")
        val copyId = s.duplicate(id)
        val copy = s.state.value.notes.first { it.id == copyId }
        assertEquals("Source copy", copy.title)
        assertEquals(copyId, s.state.value.activeId)
    }

    @Test fun `closeOthers keeps only the requested note`() {
        val (s, _) = store()
        val a = s.createBlank()
        s.createBlank()
        s.closeOthers(a)
        assertEquals(1, s.state.value.notes.size)
        assertEquals(a, s.state.value.activeId)
    }

    @Test fun `state restored from existing storage`() {
        val seed = NotesSnapshot(
            notes = listOf(
                Note("a", "A", "body of A", 1L, 1L, NoteLanguage.MARKDOWN),
                Note("b", "B", "body of B", 2L, 2L, NoteLanguage.PLAIN),
            ),
            activeId = "b",
        )
        val (s, _) = store(seed)
        assertEquals(seed, s.state.value)
        assertEquals("b", s.active.id)
    }
}
```

- [ ] **Step 4: Verification — push, watch tests pass**

```bash
cd /Users/coreyhamilton/projects/Notepad3-
git add artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence/Notes* \
         artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/persistence/NotesStoreTest.kt
git commit -m "task 3 (android phase 1): NotesStore + JSON storage + tests"
git push origin feat/android-native-port
gh workflow run "Build Android Native" --ref feat/android-native-port
sleep 6
RUN_ID=$(gh run list --branch feat/android-native-port --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

**Expected:** Green. Cumulative test count 23 + 10 = 33.

- [ ] **Step 5: Advisor checkpoint.**

---

### Task 4: ThemeController

**Files:**
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence/ThemeController.kt`
- Create: `artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/persistence/ThemeControllerTest.kt`

- [ ] **Step 1: Write `ThemeController.kt`**

```kotlin
package com.corey.notepad3.persistence

import android.content.Context
import com.corey.notepad3.models.ThemePreference
import com.corey.notepad3.theme.Palette
import com.corey.notepad3.theme.ThemeName
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Resolves the active [Palette] from [Preferences.themePreference],
 * [Preferences.customPalette], and the system dark-mode flag.
 *
 * Mirrors iOS `ThemeController.shared`. Callers observe [palette];
 * system dark-mode changes are pushed in via [updateSystemStyle], which
 * is wired from `MainActivity.onConfigurationChanged`.
 */
class ThemeController(private val prefs: Preferences) {

    private var systemIsDark: Boolean = false

    private val _palette = MutableStateFlow(resolve())
    val palette: StateFlow<Palette> = _palette.asStateFlow()

    private val _resolvedTheme = MutableStateFlow(resolveName())
    val resolvedTheme: StateFlow<ThemeName> = _resolvedTheme.asStateFlow()

    init {
        // Re-resolve when any input flow ticks. We avoid coroutine scope
        // dependencies here to keep the singleton trivially construct-able
        // in tests; instead, prefs setters that affect theme call onPrefsChanged.
        // (Internal-only — see Preferences setters in the wiring step.)
    }

    /** Push a fresh system uiMode. Triggers a re-resolve. */
    fun updateSystemStyle(isDark: Boolean) {
        if (systemIsDark == isDark) return
        systemIsDark = isDark
        recompute()
    }

    /** Called by [Preferences] setters that affect theme to re-resolve. */
    fun onPrefsChanged() = recompute()

    private fun recompute() {
        _palette.value = resolve()
        _resolvedTheme.value = resolveName()
    }

    private fun resolveName(): ThemeName = when (val pref = prefs.themePreference.value) {
        is ThemePreference.System -> if (systemIsDark) ThemeName.DARK else ThemeName.LIGHT
        is ThemePreference.Named -> pref.name
    }

    private fun resolve(): Palette {
        val name = resolveName()
        val base = Palette.named(name)
        return if (name == ThemeName.CUSTOM) base.byOverlaying(prefs.customPalette.value) else base
    }

    companion object {
        @Volatile private var instance: ThemeController? = null

        fun init(@Suppress("UNUSED_PARAMETER") context: Context) {
            if (instance == null) {
                instance = ThemeController(Preferences.shared)
            }
        }

        val shared: ThemeController
            get() = instance ?: error("ThemeController.init(context) must be called before ThemeController.shared")
    }
}
```

- [ ] **Step 2: Wire prefs setters that affect theme to call ThemeController**

The cleanest way to keep ThemeController construct-able without a coroutine scope (and unit-testable without a runtime) is to have the relevant Preferences setters poke ThemeController on each change. Edit `Preferences.kt` — at the bottom of `setThemePreference` and `setCustomPalette`, add:

```kotlin
    fun setThemePreference(value: ThemePreference) {
        if (_themePreference.value == value) return
        persister.write(keyThemePreference, ThemePreference.toKey(value))
        _themePreference.value = value
        notifyTheme()
    }

    fun setCustomPalette(value: Map<String, String>) {
        if (_customPalette.value == value) return
        persister.write(keyCustomPalette, json.encodeToString(value))
        _customPalette.value = value
        notifyTheme()
    }

    private fun notifyTheme() {
        // Avoid a hard dependency cycle: only poke if a controller has been
        // attached. Tests that don't need theme reactivity skip this.
        themeChanged?.invoke()
    }

    /** Internal hook attached by [ThemeController] in production. */
    var themeChanged: (() -> Unit)? = null
```

Then in `ThemeController` `init` block (top of class body), attach the hook:

```kotlin
    init {
        prefs.themeChanged = { recompute() }
    }
```

- [ ] **Step 3: Write `ThemeControllerTest.kt`**

```kotlin
package com.corey.notepad3.persistence

import com.corey.notepad3.models.ThemePreference
import com.corey.notepad3.theme.Palette
import com.corey.notepad3.theme.ThemeName
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class ThemeControllerTest {
    private fun controller(): Pair<ThemeController, Preferences> {
        val prefs = Preferences(InMemoryPrefsPersister())
        val tc = ThemeController(prefs)
        return tc to prefs
    }

    @Test fun `default is system, system dark off resolves to light`() {
        val (tc, _) = controller()
        assertEquals(ThemeName.LIGHT, tc.resolvedTheme.value)
        assertEquals(Palette.light, tc.palette.value)
    }

    @Test fun `system dark on resolves to dark`() {
        val (tc, _) = controller()
        tc.updateSystemStyle(isDark = true)
        assertEquals(ThemeName.DARK, tc.resolvedTheme.value)
        assertEquals(Palette.dark, tc.palette.value)
    }

    @Test fun `named preference overrides system`() {
        val (tc, prefs) = controller()
        prefs.setThemePreference(ThemePreference.Named(ThemeName.CYBERPUNK))
        tc.updateSystemStyle(isDark = false)
        assertEquals(ThemeName.CYBERPUNK, tc.resolvedTheme.value)
        assertEquals(Palette.cyberpunk, tc.palette.value)
    }

    @Test fun `custom theme overlays user hex map`() {
        val (tc, prefs) = controller()
        prefs.setThemePreference(ThemePreference.Named(ThemeName.CUSTOM))
        prefs.setCustomPalette(mapOf("primary" to "#123456"))
        val p = tc.palette.value
        assertNotEquals(Palette.light.primary, p.primary)
        // Other fields fall back to the light base.
        assertEquals(Palette.light.background, p.background)
    }

    @Test fun `setting same theme is a no-op for the flow`() {
        val (tc, prefs) = controller()
        val before = tc.palette.value
        prefs.setThemePreference(ThemePreference.System)
        assertEquals(before, tc.palette.value)
    }
}
```

- [ ] **Step 4: Verification — push, watch tests pass**

```bash
cd /Users/coreyhamilton/projects/Notepad3-
git add artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence/Preferences.kt \
         artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/persistence/ThemeController.kt \
         artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/persistence/ThemeControllerTest.kt
git commit -m "task 4 (android phase 1): ThemeController + tests + theme-change hook on Preferences"
git push origin feat/android-native-port
gh workflow run "Build Android Native" --ref feat/android-native-port
sleep 6
RUN_ID=$(gh run list --branch feat/android-native-port --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

**Expected:** Green. Cumulative test count 33 + 5 = 38.

- [ ] **Step 5: Advisor checkpoint.**

---

### Task 5: UndoStack + EditOp + tests

**Files:**
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/editor/UndoStack.kt`
- Create: `artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/editor/UndoStackTest.kt`

- [ ] **Step 1: Write `UndoStack.kt`**

```kotlin
package com.corey.notepad3.editor

/**
 * Single text edit: at [start], [removed] was replaced by [inserted].
 * `undo` is the inverse — replace at [start] the [inserted] string with [removed].
 */
data class TextEditOp(
    val timestamp: Long,
    val start: Int,
    val removed: String,
    val inserted: String,
)

/**
 * Hand-rolled undo/redo stack mirroring the iOS port's `UITextView.undoManager`.
 *
 * The editor's [TextWatcher] calls [recordEdit] with each user-driven change.
 * Adjacent typing within [coalesceWindowMs] is merged into a single op so that
 * undo doesn't replay character-by-character.
 *
 * The store is opaque-data; applying ops to the actual buffer is the editor's
 * responsibility — this class only manages the stack.
 */
class UndoStack(
    private val limit: Int = 1024,
    private val coalesceWindowMs: Long = 500,
) {
    private val past = ArrayDeque<TextEditOp>()
    private val future = ArrayDeque<TextEditOp>()

    val canUndo: Boolean get() = past.isNotEmpty()
    val canRedo: Boolean get() = future.isNotEmpty()

    fun recordEdit(op: TextEditOp) {
        future.clear()
        val last = past.lastOrNull()
        if (last != null && shouldCoalesce(last, op)) {
            past.removeLast()
            past.addLast(coalesce(last, op))
        } else {
            past.addLast(op)
        }
        while (past.size > limit) past.removeFirst()
    }

    /** Returns the op to undo (caller applies the inverse to the buffer). */
    fun popUndo(): TextEditOp? = past.removeLastOrNull()?.also { future.addLast(it) }

    /** Returns the op to redo (caller re-applies it to the buffer). */
    fun popRedo(): TextEditOp? = future.removeLastOrNull()?.also { past.addLast(it) }

    fun clear() {
        past.clear()
        future.clear()
    }

    // ---- internal: coalescing ----

    private fun shouldCoalesce(prev: TextEditOp, next: TextEditOp): Boolean {
        if (next.timestamp - prev.timestamp > coalesceWindowMs) return false
        // Both pure insertions, contiguous?
        if (prev.removed.isEmpty() && next.removed.isEmpty()
            && next.start == prev.start + prev.inserted.length) return true
        // Both pure deletions, contiguous backspace?
        if (prev.inserted.isEmpty() && next.inserted.isEmpty()
            && next.start + next.removed.length == prev.start) return true
        return false
    }

    private fun coalesce(prev: TextEditOp, next: TextEditOp): TextEditOp =
        when {
            prev.removed.isEmpty() && next.removed.isEmpty() -> // typing run
                TextEditOp(
                    timestamp = next.timestamp,
                    start = prev.start,
                    removed = "",
                    inserted = prev.inserted + next.inserted,
                )
            prev.inserted.isEmpty() && next.inserted.isEmpty() -> // backspace run
                TextEditOp(
                    timestamp = next.timestamp,
                    start = next.start,
                    removed = next.removed + prev.removed,
                    inserted = "",
                )
            else -> next // shouldn't happen given shouldCoalesce returned true; fall back safe
        }
}
```

- [ ] **Step 2: Write `UndoStackTest.kt`**

```kotlin
package com.corey.notepad3.editor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UndoStackTest {
    @Test fun `empty stack offers nothing to undo or redo`() {
        val s = UndoStack()
        assertFalse(s.canUndo)
        assertFalse(s.canRedo)
        assertNull(s.popUndo())
        assertNull(s.popRedo())
    }

    @Test fun `record then undo and redo a single op`() {
        val s = UndoStack()
        s.recordEdit(TextEditOp(timestamp = 0, start = 0, removed = "", inserted = "hi"))
        assertTrue(s.canUndo)
        val u = s.popUndo()
        assertEquals(TextEditOp(0, 0, "", "hi"), u)
        assertFalse(s.canUndo)
        assertTrue(s.canRedo)
        val r = s.popRedo()
        assertEquals(u, r)
    }

    @Test fun `typing run within window coalesces`() {
        val s = UndoStack(coalesceWindowMs = 500)
        s.recordEdit(TextEditOp(0, 0, "", "h"))
        s.recordEdit(TextEditOp(100, 1, "", "e"))
        s.recordEdit(TextEditOp(200, 2, "", "l"))
        s.recordEdit(TextEditOp(300, 3, "", "l"))
        s.recordEdit(TextEditOp(400, 4, "", "o"))
        // After coalescing, one op spans 0..5 inserting "hello".
        val u = s.popUndo()
        assertEquals(TextEditOp(timestamp = 400, start = 0, removed = "", inserted = "hello"), u)
        assertFalse(s.canUndo)
    }

    @Test fun `typing run breaks when paused beyond window`() {
        val s = UndoStack(coalesceWindowMs = 500)
        s.recordEdit(TextEditOp(0, 0, "", "h"))
        s.recordEdit(TextEditOp(100, 1, "", "i"))
        s.recordEdit(TextEditOp(900, 2, "", "!")) // > 500ms gap from prev
        // Two ops on the stack now.
        s.popUndo()
        assertTrue(s.canUndo)
        s.popUndo()
        assertFalse(s.canUndo)
    }

    @Test fun `backspace run coalesces`() {
        val s = UndoStack(coalesceWindowMs = 500)
        s.recordEdit(TextEditOp(0, 4, "o", ""))
        s.recordEdit(TextEditOp(100, 3, "l", ""))
        s.recordEdit(TextEditOp(200, 2, "l", ""))
        s.recordEdit(TextEditOp(300, 1, "e", ""))
        s.recordEdit(TextEditOp(400, 0, "h", ""))
        val u = s.popUndo()
        assertEquals(TextEditOp(timestamp = 400, start = 0, removed = "hello", inserted = ""), u)
    }

    @Test fun `recording after undo clears the redo stack`() {
        val s = UndoStack()
        s.recordEdit(TextEditOp(0, 0, "", "a"))
        s.recordEdit(TextEditOp(100, 1, "", "b"))
        s.popUndo()
        assertTrue(s.canRedo)
        // New edit invalidates the future.
        s.recordEdit(TextEditOp(200, 1, "", "x"))
        assertFalse(s.canRedo)
    }

    @Test fun `stack honors limit`() {
        val s = UndoStack(limit = 3, coalesceWindowMs = 0) // no coalescing
        repeat(5) { i -> s.recordEdit(TextEditOp(i.toLong(), 0, "", i.toString())) }
        // Only the last 3 should survive; the first two were dropped.
        val popped = generateSequence { s.popUndo() }.toList()
        assertEquals(listOf("4", "3", "2"), popped.map { it.inserted })
    }
}
```

- [ ] **Step 3: Verification — push, watch tests pass**

```bash
cd /Users/coreyhamilton/projects/Notepad3-
git add artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/editor \
         artifacts/android-native/app/src/test/kotlin/com/corey/notepad3/editor
git commit -m "task 5 (android phase 1): UndoStack + TextEditOp + coalescing tests"
git push origin feat/android-native-port
gh workflow run "Build Android Native" --ref feat/android-native-port
sleep 6
RUN_ID=$(gh run list --branch feat/android-native-port --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

**Expected:** Green. Cumulative test count 38 + 7 = 45.

- [ ] **Step 4: Advisor checkpoint.**

---

### Task 6: EditorViewModel + EditText interop

**Files:**
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/editor/EditorViewModel.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/editor/EditorTextArea.kt`

This task has no unit tests — `AndroidView`, `EditText`, and `TextWatcher` are runtime-bound and best verified on the emulator (Task 8). Manual verification is the deliverable.

- [ ] **Step 1: Write `EditorViewModel.kt`**

```kotlin
package com.corey.notepad3.editor

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.corey.notepad3.persistence.NotesStore
import com.corey.notepad3.persistence.ThemeController
import com.corey.notepad3.theme.Palette
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

/**
 * Presents the editor's current state to Compose. Holds the [UndoStack] and
 * mediates between the [NotesStore] (source of truth for note content) and
 * the on-screen `EditText`.
 *
 * State that must survive Activity recreation:
 * - the active note's body (lives in NotesStore — survives by virtue of being persisted)
 * - undo/redo stacks (live here on the ViewModel — survive config changes)
 * - the latest known caret position (lives here)
 */
class EditorViewModel(
    private val notesStore: NotesStore = NotesStore.shared,
    private val themeController: ThemeController = ThemeController.shared,
) : ViewModel() {

    val undoStack = UndoStack()

    val palette: StateFlow<Palette> = themeController.palette

    val activeBody: StateFlow<String> = notesStore.state
        .map { it.notes.firstOrNull { n -> n.id == it.activeId }?.body ?: "" }
        .stateIn(viewModelScope, SharingStarted.Eagerly, notesStore.active.body)

    val activeTitle: StateFlow<String> = notesStore.state
        .map { it.notes.firstOrNull { n -> n.id == it.activeId }?.title ?: "" }
        .stateIn(viewModelScope, SharingStarted.Eagerly, notesStore.active.title)

    private val _canUndo = MutableStateFlow(false)
    val canUndo: StateFlow<Boolean> = _canUndo.asStateFlow()

    private val _canRedo = MutableStateFlow(false)
    val canRedo: StateFlow<Boolean> = _canRedo.asStateFlow()

    /** Called by the EditText TextWatcher when user-driven body changes occur. */
    fun onBodyChangedByUser(start: Int, removed: String, inserted: String) {
        undoStack.recordEdit(
            TextEditOp(System.currentTimeMillis(), start, removed, inserted)
        )
        // Note: we let the EditText be the source of truth during editing.
        // The persist-to-NotesStore happens once per change via [persistBody].
        refreshUndoFlags()
    }

    /** Persist the current EditText body to NotesStore. Called by the watcher after each edit. */
    fun persistBody(currentBody: String) {
        if (currentBody == activeBody.value) return
        notesStore.updateActive(body = currentBody)
    }

    /** Pop the most recent op for the editor to undo against the buffer. */
    fun consumeUndo(): TextEditOp? = undoStack.popUndo().also { refreshUndoFlags() }

    /** Pop the most recent op for the editor to redo against the buffer. */
    fun consumeRedo(): TextEditOp? = undoStack.popRedo().also { refreshUndoFlags() }

    /** Called when a fresh note is loaded (eg user switches notes) — undo history doesn't carry across. */
    fun resetUndoForNewNote() {
        undoStack.clear()
        refreshUndoFlags()
    }

    private fun refreshUndoFlags() {
        _canUndo.value = undoStack.canUndo
        _canRedo.value = undoStack.canRedo
    }
}
```

- [ ] **Step 2: Write `EditorTextArea.kt`**

```kotlin
package com.corey.notepad3.editor

import android.text.Editable
import android.text.TextWatcher
import android.widget.EditText
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.graphics.toArgb
import androidx.compose.runtime.collectAsState
import com.corey.notepad3.theme.Palette

/**
 * Wraps a classic `EditText` inside an `AndroidView` and binds it to the
 * [EditorViewModel]. The watcher records user-driven edits to the undo stack
 * and persists each change to the NotesStore.
 *
 * The `programmaticChange` flag suppresses recording when our own undo/redo
 * code mutates the buffer — without it, undo would record its own inverse
 * and we'd loop forever.
 */
@Composable
fun EditorTextArea(
    viewModel: EditorViewModel,
    palette: Palette,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val activeBody by viewModel.activeBody.collectAsState()

    // EditText reference we keep across recompositions so external sync (palette
    // changes, undo/redo handlers) can mutate it directly without a rebuild.
    val editTextRef = remember { mutableStateOf<EditText?>(null) }
    val programmaticChange = remember { mutableStateOf(false) }
    val lastBodySeen = remember { mutableStateOf(activeBody) }

    AndroidView(
        modifier = modifier
            .fillMaxSize()
            .background(palette.editorBackground)
            .padding(16.dp),
        factory = { ctx ->
            EditText(ctx).also { et ->
                et.background = null
                et.setText(activeBody)
                et.setTextColor(palette.foreground.toArgb())
                et.setHintTextColor(palette.mutedForeground.toArgb())
                et.gravity = android.view.Gravity.TOP or android.view.Gravity.START
                et.setHorizontallyScrolling(false)
                et.isVerticalScrollBarEnabled = true
                et.textSize = 14f

                et.addTextChangedListener(object : TextWatcher {
                    private var pendingStart = 0
                    private var pendingRemoved = ""

                    override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {
                        if (programmaticChange.value) return
                        pendingStart = start
                        pendingRemoved = if (count > 0) s.subSequence(start, start + count).toString() else ""
                    }

                    override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
                        if (programmaticChange.value) return
                        val inserted = if (count > 0) s.subSequence(start, start + count).toString() else ""
                        viewModel.onBodyChangedByUser(pendingStart, pendingRemoved, inserted)
                    }

                    override fun afterTextChanged(s: Editable) {
                        if (programmaticChange.value) return
                        viewModel.persistBody(s.toString())
                        lastBodySeen.value = s.toString()
                    }
                })

                editTextRef.value = et
            }
        },
        update = { et ->
            // Sync palette colors live.
            et.setTextColor(palette.foreground.toArgb())
            et.setHintTextColor(palette.mutedForeground.toArgb())

            // External body change (e.g. user switched notes elsewhere): replace
            // the EditText buffer without firing the watcher.
            val current = et.text?.toString() ?: ""
            if (current != activeBody && lastBodySeen.value != activeBody) {
                programmaticChange.value = true
                et.setText(activeBody)
                et.setSelection(activeBody.length.coerceAtMost(activeBody.length))
                programmaticChange.value = false
                lastBodySeen.value = activeBody
                // Note switch resets the undo stack — the iOS port does the same.
                viewModel.resetUndoForNewNote()
            }
        },
    )
}

/**
 * Apply a [TextEditOp] (or its inverse) to the [EditText]'s `Editable`. Used by
 * the toolbar / accessory undo+redo buttons (Phase 3 wires those; for Phase 1
 * the API exists so the ViewModel and the EditText agree on undo semantics).
 *
 * `forwardDirection = true` re-applies the op (redo); `false` undoes it.
 */
fun applyEditOp(editText: EditText, op: TextEditOp, forwardDirection: Boolean) {
    val buffer = editText.text ?: return
    val (oldStart, oldFrag, newFrag) = if (forwardDirection) {
        Triple(op.start, op.removed, op.inserted)
    } else {
        Triple(op.start, op.inserted, op.removed)
    }
    val end = oldStart + oldFrag.length
    if (end > buffer.length) return
    buffer.replace(oldStart, end, newFrag)
    editText.setSelection((oldStart + newFrag.length).coerceAtMost(buffer.length))
}
```

- [ ] **Step 3: Verification — APK builds**

This task has no unit tests; verification is "the new code compiles into a green APK." Let CI build it:

```bash
cd /Users/coreyhamilton/projects/Notepad3-
git add artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/editor
git commit -m "task 6 (android phase 1): EditorViewModel + EditorTextArea (AndroidView interop)"
git push origin feat/android-native-port
gh workflow run "Build Android Native" --ref feat/android-native-port
sleep 6
RUN_ID=$(gh run list --branch feat/android-native-port --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

**Expected:** Green. Test count unchanged (45). The "Build debug APK" step still produces an APK. The new files compile; nothing references them at runtime yet (Task 7 wires them in).

- [ ] **Step 4: Advisor checkpoint** — flag explicitly that there are no unit tests for this task and that runtime verification comes in Task 8 via the emulator.

---

### Task 7: Compose chrome + AppInitializer + wire MainActivity

**Files:**
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/app/AppInitializer.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/app/LocalPalette.kt`
- Create: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/app/NotepadApp.kt`
- Modify: `artifacts/android-native/app/src/main/AndroidManifest.xml` — register the InitializationProvider
- Modify: `artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/MainActivity.kt` — replace hello with NotepadApp

- [ ] **Step 1: Write `AppInitializer.kt`**

```kotlin
package com.corey.notepad3.app

import android.content.Context
import androidx.startup.Initializer
import com.corey.notepad3.persistence.NotesStore
import com.corey.notepad3.persistence.Preferences
import com.corey.notepad3.persistence.ThemeController

/**
 * Initializes the three application-scoped singletons (`Preferences`,
 * `NotesStore`, `ThemeController`) once at process start, before any
 * Activity touches them. Wired via androidx.startup so we don't need a
 * custom Application subclass.
 */
class AppInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        val app = context.applicationContext
        Preferences.init(app)
        NotesStore.init(app)
        ThemeController.init(app)
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
```

- [ ] **Step 2: Write `LocalPalette.kt`**

```kotlin
package com.corey.notepad3.app

import androidx.compose.runtime.compositionLocalOf
import com.corey.notepad3.theme.Palette

/**
 * Compose CompositionLocal for the active [Palette]. Provided by [NotepadApp]
 * at the root; every chrome composable reads `LocalPalette.current` instead of
 * touching `MaterialTheme.colorScheme`. This is the bridge between
 * [com.corey.notepad3.persistence.ThemeController] and Compose.
 */
val LocalPalette = compositionLocalOf<Palette> {
    error("No LocalPalette provided — NotepadApp must wrap content")
}
```

- [ ] **Step 3: Write `NotepadApp.kt`**

```kotlin
package com.corey.notepad3.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.viewmodel.compose.viewModel
import com.corey.notepad3.editor.EditorTextArea
import com.corey.notepad3.editor.EditorViewModel
import com.corey.notepad3.models.ThemePreference
import com.corey.notepad3.persistence.NotesStore
import com.corey.notepad3.persistence.Preferences
import com.corey.notepad3.persistence.ThemeController
import com.corey.notepad3.theme.ThemeName

/**
 * Top-level Compose entry point. Provides [LocalPalette] from
 * [ThemeController.palette], hosts a simple mobile layout (TopAppBar + editor),
 * and wires the new-doc + theme-picker actions.
 *
 * Phase 1 ships only the mobile layout; classic mode + dual-mode chrome land
 * in Phase 2 per the spec.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotepadApp() {
    val palette by ThemeController.shared.palette.collectAsState()
    val activeTitle by NotesStore.shared.state.collectAsState()
    val title = activeTitle.notes.firstOrNull { it.id == activeTitle.activeId }?.title ?: "Notepad 3++"

    val viewModel: EditorViewModel = viewModel()

    var themeMenuOpen by remember { mutableStateOf(false) }

    CompositionLocalProvider(LocalPalette provides palette) {
        MaterialTheme {
            Surface(color = palette.background) {
                Scaffold(
                    containerColor = palette.background,
                    topBar = {
                        TopAppBar(
                            title = { Text(title, color = palette.primaryForeground) },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = palette.primary,
                                titleContentColor = palette.primaryForeground,
                                actionIconContentColor = palette.primaryForeground,
                            ),
                            actions = {
                                IconButton(onClick = { NotesStore.shared.createBlank() }) {
                                    Icon(Icons.Filled.Add, contentDescription = "New note")
                                }
                                IconButton(onClick = { themeMenuOpen = true }) {
                                    Icon(Icons.Filled.Palette, contentDescription = "Theme")
                                }
                                DropdownMenu(
                                    expanded = themeMenuOpen,
                                    onDismissRequest = { themeMenuOpen = false },
                                ) {
                                    DropdownMenuItem(
                                        text = { Text("System") },
                                        onClick = {
                                            Preferences.shared.setThemePreference(ThemePreference.System)
                                            themeMenuOpen = false
                                        },
                                    )
                                    ThemeName.entries.filter { it != ThemeName.CUSTOM }.forEach { tn ->
                                        DropdownMenuItem(
                                            text = { Text(tn.display) },
                                            onClick = {
                                                Preferences.shared.setThemePreference(ThemePreference.Named(tn))
                                                themeMenuOpen = false
                                            },
                                        )
                                    }
                                }
                            },
                        )
                    },
                ) { padding ->
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(padding)
                            .background(palette.background),
                    ) {
                        EditorTextArea(viewModel = viewModel, palette = palette)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Register the InitializationProvider in the manifest**

Edit `app/src/main/AndroidManifest.xml`. Inside `<application>`, add a provider entry **before** the `<activity>`:

```xml
        <provider
            android:name="androidx.startup.InitializationProvider"
            android:authorities="${applicationId}.androidx-startup"
            android:exported="false"
            tools:node="merge">
            <meta-data
                android:name="com.corey.notepad3.app.AppInitializer"
                android:value="androidx.startup" />
        </provider>
```

The full manifest body should now be:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.Notepad3"
        tools:targetApi="34">

        <provider
            android:name="androidx.startup.InitializationProvider"
            android:authorities="${applicationId}.androidx-startup"
            android:exported="false"
            tools:node="merge">
            <meta-data
                android:name="com.corey.notepad3.app.AppInitializer"
                android:value="androidx.startup" />
        </provider>

        <activity
            android:name="com.corey.notepad3.MainActivity"
            android:exported="true"
            android:label="@string/app_name"
            android:configChanges="uiMode|orientation|screenSize|smallestScreenSize|screenLayout|keyboard|keyboardHidden|navigation"
            android:theme="@style/Theme.Notepad3">

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
```

- [ ] **Step 5: Wire `MainActivity.kt` to host `NotepadApp` + react to system uiMode changes**

Replace `app/src/main/kotlin/com/corey/notepad3/MainActivity.kt` entirely with:

```kotlin
package com.corey.notepad3

import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.corey.notepad3.app.NotepadApp
import com.corey.notepad3.persistence.ThemeController

/**
 * Single-Activity host for the entire app. The configChanges flags in the
 * manifest mean Android does NOT recreate this Activity on rotation,
 * dark-mode flip, IME visibility, or language change; instead we get
 * [onConfigurationChanged] and forward the dark-mode bit to
 * [ThemeController.updateSystemStyle] so the palette re-resolves.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        ThemeController.shared.updateSystemStyle(isDarkFromConfig(resources.configuration))
        setContent { NotepadApp() }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        ThemeController.shared.updateSystemStyle(isDarkFromConfig(newConfig))
    }

    private fun isDarkFromConfig(c: Configuration): Boolean =
        (c.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
}
```

- [ ] **Step 6: Verification — build, install on emulator, open app, type, switch theme, confirm persistence**

```bash
# 1. Build via CI
cd /Users/coreyhamilton/projects/Notepad3-
git add artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/app \
         artifacts/android-native/app/src/main/AndroidManifest.xml \
         artifacts/android-native/app/src/main/kotlin/com/corey/notepad3/MainActivity.kt
git commit -m "task 7 (android phase 1): NotepadApp Compose chrome + AppInitializer + wired MainActivity"
git push origin feat/android-native-port
gh workflow run "Build Android Native" --ref feat/android-native-port
sleep 6
RUN_ID=$(gh run list --branch feat/android-native-port --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status

# 2. Download artifact
mkdir -p /tmp/np3-android-artifact
cd /tmp/np3-android-artifact
rm -f app-debug.apk
gh run download "$RUN_ID" -R xuninc/Notepad3- -n notepad3-android-debug-apk
ls -lh app-debug.apk

# 3. Install on emulator (assumes emulator-5554 is running; if not, boot Pixel_9_Pro first)
/opt/platform-tools/adb -s emulator-5554 install -r /tmp/np3-android-artifact/app-debug.apk
/opt/platform-tools/adb -s emulator-5554 shell am start -n com.corey.android.np3plusplus/com.corey.notepad3.MainActivity
sleep 2
/opt/platform-tools/adb -s emulator-5554 exec-out screencap -p > /tmp/np3-android-artifact/launch-task7.png
ls -lh /tmp/np3-android-artifact/launch-task7.png
```

**Expected (manual checks the engineer must run on the emulator window):**
- App launches without ANR / crash dialog.
- Title bar shows "Welcome" (the seeded note's title) on a classic-blue background (`#3A78C4`).
- Editor body shows the welcome blurb, editable.
- Tapping the keyboard area opens the IME; typing appends characters live.
- Tapping the **+** action creates a fresh "Untitled 1" note; the title bar updates.
- Tapping the **palette** action opens a dropdown of theme names; picking "Dark" recolors chrome + editor instantly.
- Killing the emulator app and relaunching shows the same notes + the same theme — persistence works.

If any of these fail, the task is **not done**. Capture the failure (`adb logcat -d -t 200 > /tmp/np3-logcat.txt`) and iterate.

- [ ] **Step 7: Advisor checkpoint** — pass: the run id, the screenshot path, *and* a summary of the manual checks. The advisor reads what you actually verified, not what you intended to verify.

---

### Task 8: CI green + emulator verify (Phase 1 done criteria)

This task is the explicit closure of Phase 1. No new code; we re-read the spec's Phase 1 success criteria and confirm each.

**Files:** none

- [ ] **Step 1: Re-read Phase 1 in the spec**

```bash
sed -n '/^### Phase 1/,/^### Phase 2/p' /Users/coreyhamilton/projects/Notepad3-/docs/superpowers/specs/2026-04-26-android-native-port-design.md
```

The spec's verification list:
> **Verification:** make a note, type, undo, redo. Switch themes. Force-quit; relaunch; note + theme persisted.

- [ ] **Step 2: Walk that list on the emulator**

  - **Make a note.** Tap +, see "Untitled 1" in the title bar.
  - **Type.** Tap the body, type "hello world", confirm characters render.
  - **Undo + redo.** *Phase 1 ships the UndoStack but does NOT yet wire a UI button or a hardware-keyboard-Cmd-Z to it (that's a Phase 2/3 concern). For Phase 1, the spec's "undo/redo works" should be read as "the stack records edits correctly per the unit tests."* The visible undo button comes with the keyboard accessory in Phase 3. Note this in the advisor checkpoint.
  - **Switch themes.** Open the palette dropdown, pick three different themes, confirm chrome + editor recolor live.
  - **Force-quit.** From the emulator's recent-apps tray, swipe Notepad 3++ away; or `adb shell am force-stop com.corey.android.np3plusplus`.
  - **Relaunch.** Open from the launcher; confirm the last note + last theme is what you left.

- [ ] **Step 3: Tag the phase**

```bash
cd /Users/coreyhamilton/projects/Notepad3-
git tag android-native-phase1-v0.1.0
git push origin android-native-phase1-v0.1.0
```

- [ ] **Step 4: Advisor closing checkpoint** — pass the full Phase 1 verification list and which items were demonstrated vs deferred (undo UI is Phase 3). Get explicit sign-off on Phase 1. Only then mark this task done.

---

## Done criteria for the entire plan

Phase 1 is complete when **all** are true:
1. Cumulative ~45 unit tests passing on CI on the latest `feat/android-native-port` commit.
2. Latest CI run on `feat/android-native-port` is green and produces `notepad3-android-debug-apk`.
3. APK installs on Pixel_9_Pro emulator without crash.
4. Manual emulator walk of the spec's Phase 1 verification list (§2 above) passes.
5. Tag `android-native-phase1-v0.1.0` exists on remote.
6. Advisor has confirmed each task's verification evidence at its checkpoint.

If any of those is missing, Phase 1 is not done — regardless of how confident the implementer feels.
