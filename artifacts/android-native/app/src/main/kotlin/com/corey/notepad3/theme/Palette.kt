package com.corey.notepad3.theme

data class Palette(
    val background: String,
    val foreground: String,
    val card: String,
    val primary: String,
    val primaryForeground: String,
    val secondary: String,
    val muted: String,
    val mutedForeground: String,
    val accent: String,
    val border: String,
    val editorBackground: String,
    val editorGutter: String,
    val destructive: String,
    val success: String,
    val titleGradientStart: String,
    val titleGradientEnd: String,
    val chromeGradientStart: String,
    val chromeGradientEnd: String,
    val radius: Int,
) {
    companion object {
        val classic = Palette(
            background = "#dbe5f1",
            foreground = "#1a2334",
            card = "#dde7f3",
            primary = "#3a78c4",
            primaryForeground = "#ffffff",
            secondary = "#c4d5ec",
            muted = "#eef3fa",
            mutedForeground = "#4a5e7a",
            accent = "#2c5d9b",
            border = "#7a96bd",
            editorBackground = "#ffffff",
            editorGutter = "#eef3fa",
            destructive = "#a83232",
            success = "#1f6f3f",
            titleGradientStart = "#5a8fcf",
            titleGradientEnd = "#2c5d9b",
            chromeGradientStart = "#eef3fa",
            chromeGradientEnd = "#cad9ed",
            radius = 4,
        )

        val light = Palette(
            background = "#f5f5f7",
            foreground = "#1a1a1a",
            card = "#ffffff",
            primary = "#0a64a4",
            primaryForeground = "#ffffff",
            secondary = "#e6e6e6",
            muted = "#f0f0f0",
            mutedForeground = "#5a5a5a",
            accent = "#0a64a4",
            border = "#cfcfcf",
            editorBackground = "#ffffff",
            editorGutter = "#f4f4f4",
            destructive = "#a83232",
            success = "#1f6f3f",
            titleGradientStart = "#ffffff",
            titleGradientEnd = "#f0f0f0",
            chromeGradientStart = "#fafafa",
            chromeGradientEnd = "#ececec",
            radius = 6,
        )

        val dark = Palette(
            background = "#1e1e1e",
            foreground = "#e6e6e6",
            card = "#2a2a2a",
            primary = "#4ea3dc",
            primaryForeground = "#0a0a0a",
            secondary = "#3a3a3a",
            muted = "#262626",
            mutedForeground = "#a8a8a8",
            accent = "#4ea3dc",
            border = "#3f3f46",
            editorBackground = "#1e1e1e",
            editorGutter = "#262626",
            destructive = "#e07070",
            success = "#7fbf7f",
            titleGradientStart = "#3a3a3a",
            titleGradientEnd = "#1a1a1a",
            chromeGradientStart = "#2e2e2e",
            chromeGradientEnd = "#1f1f1f",
            radius = 6,
        )

        val retro = Palette(
            background = "#c0c0c0",
            foreground = "#000000",
            card = "#c0c0c0",
            primary = "#000080",
            primaryForeground = "#ffffff",
            secondary = "#a8a8a8",
            muted = "#d4d0c8",
            mutedForeground = "#404040",
            accent = "#000080",
            border = "#808080",
            editorBackground = "#ffffff",
            editorGutter = "#dcdcdc",
            destructive = "#800000",
            success = "#005900",
            titleGradientStart = "#000080",
            titleGradientEnd = "#000080",
            chromeGradientStart = "#c0c0c0",
            chromeGradientEnd = "#c0c0c0",
            radius = 0,
        )

        val modern = Palette(
            background = "#f8fafc",
            foreground = "#0f172a",
            card = "#ffffff",
            primary = "#6366f1",
            primaryForeground = "#ffffff",
            secondary = "#eef2ff",
            muted = "#f1f5f9",
            mutedForeground = "#64748b",
            accent = "#8b5cf6",
            border = "#e2e8f0",
            editorBackground = "#ffffff",
            editorGutter = "#f8fafc",
            destructive = "#ef4444",
            success = "#10b981",
            titleGradientStart = "#ffffff",
            titleGradientEnd = "#f8fafc",
            chromeGradientStart = "#ffffff",
            chromeGradientEnd = "#f1f5f9",
            radius = 12,
        )

        val sunset = Palette(
            background = "#fff6fa",
            foreground = "#3a1a3a",
            card = "#ffffff",
            primary = "#ff3d8a",
            primaryForeground = "#ffffff",
            secondary = "#ffd6e6",
            muted = "#eaf3fb",
            mutedForeground = "#6e3a5e",
            accent = "#ff7a3d",
            border = "#ffb3d1",
            editorBackground = "#fffafd",
            editorGutter = "#ffe8f1",
            destructive = "#c0264e",
            success = "#8fd9b8",
            titleGradientStart = "#ff7a3d",
            titleGradientEnd = "#ff3d8a",
            chromeGradientStart = "#d8f1e4",
            chromeGradientEnd = "#d6ecff",
            radius = 8,
        )

        val cyberpunk = Palette(
            background = "#0b0820",
            foreground = "#f0f6ff",
            card = "#150f33",
            primary = "#ff2bd1",
            primaryForeground = "#0b0820",
            secondary = "#1f1850",
            muted = "#161139",
            mutedForeground = "#9af7ff",
            accent = "#00f0ff",
            border = "#ff2bd1",
            editorBackground = "#070518",
            editorGutter = "#0e0a26",
            destructive = "#ff5577",
            success = "#76ff7a",
            titleGradientStart = "#ff2bd1",
            titleGradientEnd = "#7b00ff",
            chromeGradientStart = "#1a1340",
            chromeGradientEnd = "#0e0a26",
            radius = 2,
        )

        fun forName(name: ThemeName): Palette =
            when (name) {
                ThemeName.CLASSIC -> classic
                ThemeName.LIGHT -> light
                ThemeName.DARK -> dark
                ThemeName.RETRO -> retro
                ThemeName.MODERN -> modern
                ThemeName.CYBERPUNK -> cyberpunk
                ThemeName.SUNSET -> sunset
                ThemeName.CUSTOM -> light
            }

        fun byOverlaying(overrides: Map<String, String>, base: Palette): Palette =
            base.copy(
                background = overrides.validHex("background") ?: base.background,
                foreground = overrides.validHex("foreground") ?: base.foreground,
                card = overrides.validHex("card") ?: base.card,
                primary = overrides.validHex("primary") ?: base.primary,
                primaryForeground = overrides.validHex("primaryForeground") ?: base.primaryForeground,
                secondary = overrides.validHex("secondary") ?: base.secondary,
                muted = overrides.validHex("muted") ?: base.muted,
                mutedForeground = overrides.validHex("mutedForeground") ?: base.mutedForeground,
                accent = overrides.validHex("accent") ?: base.accent,
                border = overrides.validHex("border") ?: base.border,
                editorBackground = overrides.validHex("editorBackground") ?: base.editorBackground,
                editorGutter = overrides.validHex("editorGutter") ?: base.editorGutter,
                destructive = overrides.validHex("destructive") ?: base.destructive,
                success = overrides.validHex("success") ?: base.success,
                titleGradientStart = overrides.validHex("titleGradientStart") ?: base.titleGradientStart,
                titleGradientEnd = overrides.validHex("titleGradientEnd") ?: base.titleGradientEnd,
                chromeGradientStart = overrides.validHex("chromeGradientStart") ?: base.chromeGradientStart,
                chromeGradientEnd = overrides.validHex("chromeGradientEnd") ?: base.chromeGradientEnd,
            )

        private fun Map<String, String>.validHex(key: String): String? {
            val value = get(key)?.trim()?.lowercase() ?: return null
            return value.takeIf { Regex("^#[0-9a-f]{6}$").matches(it) }
        }
    }
}
