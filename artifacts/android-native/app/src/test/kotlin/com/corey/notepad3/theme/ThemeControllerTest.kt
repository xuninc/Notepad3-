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
        assertEquals("#6366f1", paletteFor(ThemeName.MODERN).primary)
        assertEquals("#0b0820", paletteFor(ThemeName.CYBERPUNK).background)
        assertEquals("#ff3d8a", paletteFor(ThemeName.SUNSET).primary)
    }

    private fun paletteFor(name: ThemeName): Palette {
        val controller = ThemeController(InMemoryThemePreferences(ThemePreference.Named(name)))
        return controller.palette.value
    }
}
