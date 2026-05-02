package com.corey.notepad3.app

import org.junit.Assert.assertEquals
import org.junit.Test

class EditorPreferencesTest {
    @Test
    fun controllerStartsWithTheStoredLayoutMode() {
        val preferences = InMemoryEditorPreferences(layoutMode = EditorLayoutMode.CLASSIC)
        val controller = EditorPreferenceController(preferences)

        assertEquals(EditorLayoutMode.CLASSIC, controller.layoutMode.value)
    }

    @Test
    fun controllerPersistsLayoutModeChanges() {
        val preferences = InMemoryEditorPreferences()
        val controller = EditorPreferenceController(preferences)

        controller.setLayoutMode(EditorLayoutMode.CLASSIC)

        assertEquals(EditorLayoutMode.CLASSIC, preferences.layoutMode.value)
        assertEquals(EditorLayoutMode.CLASSIC, controller.layoutMode.value)
    }

    @Test
    fun controllerTogglesLayoutMode() {
        val controller = EditorPreferenceController(InMemoryEditorPreferences())

        controller.toggleLayoutMode()
        assertEquals(EditorLayoutMode.CLASSIC, controller.layoutMode.value)

        controller.toggleLayoutMode()
        assertEquals(EditorLayoutMode.MOBILE, controller.layoutMode.value)
    }
}
