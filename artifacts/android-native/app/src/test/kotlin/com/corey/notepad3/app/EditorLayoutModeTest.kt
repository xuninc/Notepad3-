package com.corey.notepad3.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EditorLayoutModeTest {
    @Test
    fun classicModeUsesDesktopChromeAndShowsCloseButton() {
        assertFalse(EditorLayoutMode.CLASSIC.showMobileBottomBar)
        assertTrue(EditorLayoutMode.CLASSIC.showClassicCloseButton)
        assertEquals("Mobile UI", EditorLayoutMode.CLASSIC.toggleLabel)
    }

    @Test
    fun mobileModeKeepsBottomBarAndCanSwitchToClassic() {
        assertTrue(EditorLayoutMode.MOBILE.showMobileBottomBar)
        assertFalse(EditorLayoutMode.MOBILE.showClassicCloseButton)
        assertEquals("Classic UI", EditorLayoutMode.MOBILE.toggleLabel)
        assertEquals(EditorLayoutMode.CLASSIC, EditorLayoutMode.MOBILE.toggled())
    }

    @Test
    fun storageNamesRoundTripForPreferences() {
        assertEquals("mobile", EditorLayoutMode.MOBILE.storageName)
        assertEquals("classic", EditorLayoutMode.CLASSIC.storageName)
        assertEquals(EditorLayoutMode.MOBILE, EditorLayoutMode.fromStorageName("mobile"))
        assertEquals(EditorLayoutMode.CLASSIC, EditorLayoutMode.fromStorageName("classic"))
        assertEquals(null, EditorLayoutMode.fromStorageName("desk"))
    }
}
