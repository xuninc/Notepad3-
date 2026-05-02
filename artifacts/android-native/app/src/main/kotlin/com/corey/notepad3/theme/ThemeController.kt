package com.corey.notepad3.theme

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

enum class ThemeName(val storageName: String) {
    CLASSIC("classic"),
    LIGHT("light"),
    DARK("dark"),
    RETRO("retro"),
    MODERN("modern"),
    CYBERPUNK("cyberpunk"),
    SUNSET("sunset"),
    CUSTOM("custom");

    companion object {
        fun fromStorageName(value: String): ThemeName? =
            entries.firstOrNull { it.storageName == value }
    }
}

sealed interface ThemePreference {
    data class Named(val name: ThemeName) : ThemePreference
    data object System : ThemePreference
}

interface ThemePreferences {
    val themePreference: StateFlow<ThemePreference>
    val customPalette: StateFlow<Map<String, String>>
    fun setThemePreference(preference: ThemePreference)
    fun setCustomPalette(overrides: Map<String, String>)
}

class ThemeController(private val preferences: ThemePreferences) {
    private val _resolvedTheme = MutableStateFlow(resolveTheme(preferences.themePreference.value))
    val resolvedTheme: StateFlow<ThemeName> = _resolvedTheme.asStateFlow()

    private val _palette = MutableStateFlow(resolvePalette())
    val palette: StateFlow<Palette> = _palette.asStateFlow()

    fun setThemePreference(preference: ThemePreference) {
        preferences.setThemePreference(preference)
        refresh()
    }

    fun cycleEarlyThemes() {
        val namedThemes = listOf(
            ThemeName.CLASSIC,
            ThemeName.LIGHT,
            ThemeName.DARK,
            ThemeName.RETRO,
            ThemeName.MODERN,
            ThemeName.SUNSET,
            ThemeName.CYBERPUNK,
        )
        val current = namedThemes.indexOf(_resolvedTheme.value).takeIf { it >= 0 } ?: 0
        val next = namedThemes[(current + 1) % namedThemes.size]
        setThemePreference(ThemePreference.Named(next))
    }

    private fun refresh() {
        _resolvedTheme.value = resolveTheme(preferences.themePreference.value)
        _palette.value = resolvePalette()
    }

    private fun resolvePalette(): Palette {
        val name = resolveTheme(preferences.themePreference.value)
        return if (name == ThemeName.CUSTOM) {
            Palette.byOverlaying(preferences.customPalette.value, Palette.light)
        } else {
            Palette.forName(name)
        }
    }

    private fun resolveTheme(preference: ThemePreference): ThemeName =
        when (preference) {
            is ThemePreference.Named -> preference.name
            ThemePreference.System -> ThemeName.LIGHT
        }
}

class InMemoryThemePreferences(
    themePreference: ThemePreference = ThemePreference.Named(ThemeName.CLASSIC),
    customPalette: Map<String, String> = emptyMap(),
) : ThemePreferences {
    private val _themePreference = MutableStateFlow(themePreference)
    override val themePreference: StateFlow<ThemePreference> = _themePreference.asStateFlow()

    private val _customPalette = MutableStateFlow(customPalette)
    override val customPalette: StateFlow<Map<String, String>> = _customPalette.asStateFlow()

    override fun setThemePreference(preference: ThemePreference) {
        _themePreference.value = preference
    }

    override fun setCustomPalette(overrides: Map<String, String>) {
        _customPalette.value = overrides
    }
}

class AndroidThemePreferences(context: Context) : ThemePreferences {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("notepad3pp", Context.MODE_PRIVATE)
    private val json = Json

    private val _themePreference = MutableStateFlow(decodeThemePreference())
    override val themePreference: StateFlow<ThemePreference> = _themePreference.asStateFlow()

    private val _customPalette = MutableStateFlow(decodeCustomPalette())
    override val customPalette: StateFlow<Map<String, String>> = _customPalette.asStateFlow()

    override fun setThemePreference(preference: ThemePreference) {
        prefs.edit().putString(KEY_THEME_PREFERENCE, encodeThemePreference(preference)).apply()
        _themePreference.value = preference
    }

    override fun setCustomPalette(overrides: Map<String, String>) {
        val editor = prefs.edit()
        if (overrides.isEmpty()) {
            editor.remove(KEY_CUSTOM_PALETTE)
        } else {
            editor.putString(KEY_CUSTOM_PALETTE, json.encodeToString(overrides))
        }
        editor.apply()
        _customPalette.value = overrides
    }

    private fun decodeThemePreference(): ThemePreference {
        val raw = prefs.getString(KEY_THEME_PREFERENCE, null) ?: "named:classic"
        if (raw == "system") return ThemePreference.System
        if (raw.startsWith("named:")) {
            val name = ThemeName.fromStorageName(raw.removePrefix("named:"))
            if (name != null) return ThemePreference.Named(name)
        }
        return ThemePreference.Named(ThemeName.CLASSIC)
    }

    private fun encodeThemePreference(preference: ThemePreference): String =
        when (preference) {
            is ThemePreference.Named -> "named:${preference.name.storageName}"
            ThemePreference.System -> "system"
        }

    private fun decodeCustomPalette(): Map<String, String> =
        prefs.getString(KEY_CUSTOM_PALETTE, null)?.let { raw ->
            runCatching { json.decodeFromString<Map<String, String>>(raw) }.getOrNull()
        } ?: emptyMap()

    companion object {
        private const val KEY_THEME_PREFERENCE = "notepad3pp.themePreference"
        private const val KEY_CUSTOM_PALETTE = "notepad3pp.customPalette"
    }
}
