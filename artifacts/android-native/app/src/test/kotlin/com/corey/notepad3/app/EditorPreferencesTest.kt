package com.corey.notepad3.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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

        assertEquals(EditorLayoutMode.CLASSIC, preferences.displayOptions.value.layoutMode)
        assertEquals(EditorLayoutMode.CLASSIC, controller.displayOptions.value.layoutMode)
    }

    @Test
    fun controllerTogglesLayoutMode() {
        val controller = EditorPreferenceController(InMemoryEditorPreferences())

        controller.toggleLayoutMode()
        assertEquals(EditorLayoutMode.CLASSIC, controller.displayOptions.value.layoutMode)

        controller.toggleLayoutMode()
        assertEquals(EditorLayoutMode.MOBILE, controller.displayOptions.value.layoutMode)
    }

    @Test
    fun controllerAdjustsEditorDisplayOptionsWithinUsableBounds() {
        val controller = EditorPreferenceController(InMemoryEditorPreferences())

        assertEquals(EditorFontFamily.MONOSPACE, controller.displayOptions.value.editorFontFamily)
        controller.adjustFontSize(40)
        controller.toggleWordWrap()
        controller.toggleLineNumbers()
        controller.toggleAccessoryBar()
        controller.setEditorFontFamily(EditorFontFamily.SANS)

        assertEquals(24, controller.displayOptions.value.fontSizeSp)
        assertEquals(false, controller.displayOptions.value.wordWrap)
        assertEquals(false, controller.displayOptions.value.lineNumbers)
        assertEquals(false, controller.displayOptions.value.accessoryBar)
        assertEquals(EditorFontFamily.SANS, controller.displayOptions.value.editorFontFamily)

        controller.adjustFontSize(-40)

        assertEquals(11, controller.displayOptions.value.fontSizeSp)
    }

    @Test
    fun editorFontFamiliesRoundTripThroughStorageNames() {
        assertEquals(EditorFontFamily.MONOSPACE, EditorFontFamily.fromStorageName("monospace"))
        assertEquals(EditorFontFamily.SANS, EditorFontFamily.fromStorageName("sans"))
        assertEquals(EditorFontFamily.SERIF, EditorFontFamily.fromStorageName("serif"))
        assertEquals(EditorFontFamily.DEFAULT, EditorFontFamily.fromStorageName("default"))
        assertEquals(null, EditorFontFamily.fromStorageName("missing"))
    }

    @Test
    fun controllerCustomizesAccessoryToolbarLayoutWithinUsableBounds() {
        val controller = EditorPreferenceController(InMemoryEditorPreferences())

        controller.adjustToolbarRows(10)
        controller.setToolbarButtonSize(AccessoryToolbarButtonSize.LARGE)
        controller.setToolbarContentMode(AccessoryToolbarContentMode.ICON_ONLY)

        assertEquals(3, controller.displayOptions.value.accessoryToolbarRows)
        assertEquals(AccessoryToolbarButtonSize.LARGE, controller.displayOptions.value.accessoryToolbarButtonSize)
        assertEquals(AccessoryToolbarContentMode.ICON_ONLY, controller.displayOptions.value.accessoryToolbarContentMode)

        controller.adjustToolbarRows(-10)

        assertEquals(1, controller.displayOptions.value.accessoryToolbarRows)
    }

    @Test
    fun controllerCustomizesPinnedAndHiddenAccessoryButtons() {
        val controller = EditorPreferenceController(InMemoryEditorPreferences())

        assertTrue(controller.displayOptions.value.staticAccessoryButtons.contains(AccessoryToolbarButton.SHIFT))
        assertTrue(controller.displayOptions.value.staticAccessoryButtons.contains(AccessoryToolbarButton.MOVE_LEFT))
        assertTrue(controller.displayOptions.value.staticAccessoryButtons.any { it.storageName == "undo" })
        assertTrue(controller.displayOptions.value.staticAccessoryButtons.any { it.storageName == "redo" })
        assertFalse(controller.displayOptions.value.staticAccessoryButtons.any { it.storageName == "undo_redo" })
        assertFalse(controller.displayOptions.value.staticAccessoryButtons.contains(AccessoryToolbarButton.CUT))

        controller.toggleStaticAccessoryButton(AccessoryToolbarButton.CUT)
        controller.toggleHiddenAccessoryButton(AccessoryToolbarButton.PASTE)

        assertTrue(controller.displayOptions.value.staticAccessoryButtons.contains(AccessoryToolbarButton.CUT))
        assertTrue(controller.displayOptions.value.hiddenAccessoryButtons.contains(AccessoryToolbarButton.PASTE))

        controller.toggleStaticAccessoryButton(AccessoryToolbarButton.CUT)
        controller.toggleHiddenAccessoryButton(AccessoryToolbarButton.PASTE)

        assertFalse(controller.displayOptions.value.staticAccessoryButtons.contains(AccessoryToolbarButton.CUT))
        assertFalse(controller.displayOptions.value.hiddenAccessoryButtons.contains(AccessoryToolbarButton.PASTE))
    }

    @Test
    fun accessoryToolbarPinnedAndHiddenChoicesStayMutuallyExclusive() {
        val controller = EditorPreferenceController(InMemoryEditorPreferences())

        controller.toggleStaticAccessoryButton(AccessoryToolbarButton.CUT)
        controller.toggleHiddenAccessoryButton(AccessoryToolbarButton.CUT)

        assertFalse(controller.displayOptions.value.staticAccessoryButtons.contains(AccessoryToolbarButton.CUT))
        assertTrue(controller.displayOptions.value.hiddenAccessoryButtons.contains(AccessoryToolbarButton.CUT))

        controller.toggleStaticAccessoryButton(AccessoryToolbarButton.CUT)

        assertTrue(controller.displayOptions.value.staticAccessoryButtons.contains(AccessoryToolbarButton.CUT))
        assertFalse(controller.displayOptions.value.hiddenAccessoryButtons.contains(AccessoryToolbarButton.CUT))
    }

    @Test
    fun accessoryToolbarDoesNotExposeDuplicateReplaceButton() {
        val displayTitles = AccessoryToolbarButton.entries.map { it.displayTitle }

        assertTrue(displayTitles.contains("Find"))
        assertTrue(displayTitles.contains("Hide"))
        assertTrue(displayTitles.contains("Undo"))
        assertTrue(displayTitles.contains("Redo"))
        assertFalse(displayTitles.contains("Undo/Redo"))
        assertTrue(AccessoryToolbarButton.entries.map { it.storageName }.contains("undo"))
        assertTrue(AccessoryToolbarButton.entries.map { it.storageName }.contains("redo"))
        assertFalse(AccessoryToolbarButton.entries.map { it.storageName }.contains("undo_redo"))
        assertFalse(displayTitles.contains("Replace"))
        assertFalse(AccessoryToolbarButton.entries.any { it.storageName == "replace" })
    }

    @Test
    fun legacyCombinedUndoRedoStorageNameExpandsToSeparateToolbarButtons() {
        val decoded = AccessoryToolbarButton.fromStorageNames("undo_redo")

        assertEquals(setOf(AccessoryToolbarButton.UNDO, AccessoryToolbarButton.REDO), decoded)
    }

    @Test
    fun undoAndRedoStayPinnedOutsideTheArrowClusterByDefault() {
        assertTrue(EditorDisplayOptions.DEFAULT_STATIC_ACCESSORY_BUTTONS.contains(AccessoryToolbarButton.UNDO))
        assertTrue(EditorDisplayOptions.DEFAULT_STATIC_ACCESSORY_BUTTONS.contains(AccessoryToolbarButton.REDO))
        assertFalse(AccessoryToolbarButton.navigationClusterButtons.contains(AccessoryToolbarButton.UNDO))
        assertFalse(AccessoryToolbarButton.navigationClusterButtons.contains(AccessoryToolbarButton.REDO))
        assertEquals(
            setOf(
                AccessoryToolbarButton.SHIFT,
                AccessoryToolbarButton.MOVE_UP,
                AccessoryToolbarButton.DELETE_BACKWARD,
                AccessoryToolbarButton.MOVE_LEFT,
                AccessoryToolbarButton.MOVE_DOWN,
                AccessoryToolbarButton.MOVE_RIGHT,
            ),
            AccessoryToolbarButton.navigationClusterButtons,
        )
    }
}
