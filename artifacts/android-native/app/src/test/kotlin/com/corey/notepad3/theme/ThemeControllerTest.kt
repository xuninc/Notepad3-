package com.corey.notepad3.theme

import org.junit.Assert.assertEquals
import org.junit.Test

class ThemeControllerTest {
    @Test
    fun defaultsToClassicTheme() {
        val prefs = InMemoryThemePreferences()
        val controller = ThemeController(prefs)

        assertEquals(ThemeName.CLASSIC, controller.resolvedTheme.value)
        assertEquals("#dbe5f1", controller.palette.value.background)
        assertEquals("#2f5f9e", controller.palette.value.primary)
    }

    @Test
    fun windows7ThemeUsesNeutralClassicChromeWithoutReplacingClassicTheme() {
        val palette = paletteFor(ThemeName.WINDOWS7)

        assertEquals("#d4d0c8", palette.background)
        assertEquals("#f0f0f0", palette.card)
        assertEquals("#e9e9e9", palette.muted)
        assertEquals("#808080", palette.border)
        assertEquals("#0a246a", palette.titleGradientStart)
        assertEquals("#0a246a", palette.titleGradientEnd)
        assertEquals("#f7f7f7", palette.chromeGradientStart)
        assertEquals("#e3e3e3", palette.chromeGradientEnd)
        assertEquals(1, palette.radius)
    }

    @Test
    fun customThemeOverlaysOnlyProvidedFields() {
        val prefs = InMemoryThemePreferences(
            themePreference = ThemePreference.Named(ThemeName.CUSTOM),
            customPalette = mapOf("background" to "#101010", "primary" to "#ff00ff"),
        )
        val controller = ThemeController(prefs)

        assertEquals("#101010", controller.palette.value.background)
        assertEquals("#ff00ff", controller.palette.value.primary)
        assertEquals(Palette.light.foreground, controller.palette.value.foreground)
    }

    @Test
    fun resolvesEveryNamedPaletteInsteadOfFallingBackToLightOrDark() {
        assertEquals("#c0c0c0", paletteFor(ThemeName.RETRO).background)
        assertEquals("#d4d0c8", paletteFor(ThemeName.WINDOWS7).background)
        assertEquals("#6366f1", paletteFor(ThemeName.MODERN).primary)
        assertEquals("#0b0820", paletteFor(ThemeName.CYBERPUNK).background)
        assertEquals("#ff3d8a", paletteFor(ThemeName.SUNSET).primary)
    }

    private fun paletteFor(name: ThemeName): Palette {
        val controller = ThemeController(InMemoryThemePreferences(ThemePreference.Named(name)))
        return controller.palette.value
    }
}
