package com.corey.notepad3.editor

import org.junit.Assert.assertEquals
import org.junit.Test

class EditorStatusTest {
    @Test
    fun summarizesLineColumnAndSelectionLength() {
        val status = EditorStatus.summary(
            languageName = "Plain Text",
            body = "one\ntwo",
            selection = TextSelection(4, 7),
            readOnly = false,
        )

        assertEquals("Plain Text | 2 lines | 7 chars | Ln 2, Col 1 | Sel 3 chars", status)
    }

    @Test
    fun includesReadOnlyModeWhenEnabled() {
        val status = EditorStatus.summary(
            languageName = "Markdown",
            body = "alpha",
            selection = TextSelection(2),
            readOnly = true,
        )

        assertEquals("Markdown | Read Only | 1 lines | 5 chars | Ln 1, Col 3", status)
    }
}
