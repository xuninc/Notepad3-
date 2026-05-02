package com.corey.notepad3.editor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EditorCommandsTest {
    @Test
    fun trimsTrailingSpacesOnEveryLine() {
        val result = EditorCommands.trimTrailingSpaces(
            body = "alpha  \nbeta\t \n gamma ",
            selection = TextSelection(7),
        )

        assertEquals("alpha\nbeta\n gamma", result.body)
        assertEquals(TextSelection(7), result.selection)
    }

    @Test
    fun sortsAllLinesCaseInsensitivelyLikeIos() {
        val result = EditorCommands.sortLines("banana\nApple\n\ncarrot")

        assertEquals("\nApple\nbanana\ncarrot", result.body)
        assertEquals(TextSelection(0), result.selection)
    }

    @Test
    fun duplicatesTheCurrentLineAtTheCaret() {
        val result = EditorCommands.duplicateCurrentLine("one\ntwo\nthree", caret = 5)

        assertEquals("one\ntwo\ntwo\nthree", result.body)
        assertEquals(TextSelection(9), result.selection)
    }

    @Test
    fun deletesTheCurrentLineAtTheCaret() {
        val result = EditorCommands.deleteCurrentLine("one\ntwo\nthree", caret = 5)

        assertEquals("one\nthree", result.body)
        assertEquals(TextSelection(4), result.selection)
    }

    @Test
    fun insertsTextOverTheCurrentSelection() {
        val result = EditorCommands.insertText(
            body = "abc",
            selection = TextSelection(1, 2),
            value = "XYZ",
        )

        assertEquals("aXYZc", result.body)
        assertEquals(TextSelection(4), result.selection)
    }

    @Test
    fun uppercasesOnlyTheCurrentSelection() {
        val result = EditorCommands.uppercaseSelection("alpha beta", TextSelection(6, 10))

        assertEquals("alpha BETA", result.body)
        assertEquals(TextSelection(6, 10), result.selection)
    }

    @Test
    fun lowercasesOnlyTheCurrentSelection() {
        val result = EditorCommands.lowercaseSelection("ALPHA BETA", TextSelection(0, 5))

        assertEquals("alpha BETA", result.body)
        assertEquals(TextSelection(0, 5), result.selection)
    }

    @Test
    fun indentsEveryLineTouchedByTheSelection() {
        val result = EditorCommands.indentSelection("one\ntwo\nthree", TextSelection(2, 6))

        assertEquals("    one\n    two\nthree", result.body)
        assertEquals(TextSelection(6, 14), result.selection)
    }

    @Test
    fun unindentsEveryLineTouchedByTheSelectionWithoutCrossingText() {
        val result = EditorCommands.unindentSelection("    one\n  two\nthree", TextSelection(5, 12))

        assertEquals("one\ntwo\nthree", result.body)
        assertEquals(TextSelection(1, 6), result.selection)
    }

    @Test
    fun goesToTheStartOfTheRequestedOneBasedLine() {
        val selection = EditorCommands.gotoLine("one\ntwo\nthree", lineNumber = 3)

        assertEquals(TextSelection(8), selection)
    }

    @Test
    fun clampsGotoLineToTheAvailableTextRange() {
        val body = "one\ntwo\nthree"

        assertEquals(TextSelection(0), EditorCommands.gotoLine(body, lineNumber = 0))
        assertEquals(TextSelection(8), EditorCommands.gotoLine(body, lineNumber = 99))
        assertEquals(TextSelection(0), EditorCommands.gotoLine("", lineNumber = 3))
    }

    @Test
    fun selectsAllText() {
        assertEquals(TextSelection(0, 11), EditorCommands.selectAll("hello\nworld"))
    }

    @Test
    fun selectsTheCurrentLineWithoutTheLineBreak() {
        assertEquals(
            TextSelection(6, 11),
            EditorCommands.selectLine("alpha\nbravo\ncharlie", caret = 8),
        )
    }

    @Test
    fun selectsTheParagraphAroundTheCaretUntilBlankLines() {
        val body = "intro\n\none\ntwo\n\noutro"

        assertEquals(TextSelection(7, 15), EditorCommands.selectParagraph(body, caret = 10))
    }

    @Test
    fun selectsWholeDocumentParagraphWhenThereAreNoBlankLines() {
        val body = "one\ntwo"

        assertEquals(TextSelection(0, body.length), EditorCommands.selectParagraph(body, caret = 2))
    }

    @Test
    fun findsNextAndPreviousLiteralMatchesCaseInsensitively() {
        val body = "alpha Beta beta"

        assertEquals(TextSelection(6, 10), EditorCommands.findNext(body, "beta", TextSelection(0)))
        assertEquals(TextSelection(11, 15), EditorCommands.findNext(body, "beta", TextSelection(6, 10)))
        assertEquals(TextSelection(6, 10), EditorCommands.findNext(body, "beta", TextSelection(11, 15)))
        assertEquals(TextSelection(11, 15), EditorCommands.findPrevious(body, "beta", TextSelection(6, 10)))
        assertNull(EditorCommands.findNext(body, "", TextSelection(0)))
    }

    @Test
    fun replacesAllLiteralMatchesCaseInsensitively() {
        val result = EditorCommands.replaceAll(
            body = "one ONE tone",
            query = "one",
            replacement = "two",
        )

        assertEquals("two two ttwo", result.body)
        assertEquals(TextSelection(0), result.selection)
    }

    @Test
    fun replaceCurrentSelectsTheNextMatchWhenNothingIsSelected() {
        val result = EditorCommands.replaceCurrent(
            body = "alpha beta beta",
            query = "beta",
            replacement = "two",
            selection = TextSelection(0),
        )

        assertEquals("alpha beta beta", result.body)
        assertEquals(TextSelection(6, 10), result.selection)
    }

    @Test
    fun replaceCurrentReplacesSelectionAndSelectsTheNextMatch() {
        val result = EditorCommands.replaceCurrent(
            body = "beta beta",
            query = "beta",
            replacement = "two",
            selection = TextSelection(0, 4),
        )

        assertEquals("two beta", result.body)
        assertEquals(TextSelection(4, 8), result.selection)
    }

    @Test
    fun replaceCurrentLeavesCaretAfterReplacementWhenThereIsNoNextMatch() {
        val result = EditorCommands.replaceCurrent(
            body = "alpha beta",
            query = "beta",
            replacement = "two",
            selection = TextSelection(6, 10),
        )

        assertEquals("alpha two", result.body)
        assertEquals(TextSelection(9), result.selection)
    }

    @Test
    fun recordsUndoAndRedoForUserAndCommandEdits() {
        val history = EditorHistory("a")

        history.record("ab")
        history.record("abc")

        assertTrue(history.canUndo)
        assertFalse(history.canRedo)
        assertEquals("ab", history.undo())
        assertEquals("a", history.undo())
        assertNull(history.undo())
        assertTrue(history.canRedo)
        assertEquals("ab", history.redo())
    }

    @Test
    fun coalescesAdjacentTypedCharactersIntoOneUndoStep() {
        val history = EditorHistory("Welcome to Notepad 3++")

        history.recordUserEdit("WelcomeA to Notepad 3++")
        history.recordUserEdit("WelcomeAD to Notepad 3++")
        history.recordUserEdit("WelcomeADB to Notepad 3++")

        assertEquals("Welcome to Notepad 3++", history.undo())
        assertNull(history.undo())
        assertEquals("WelcomeADB to Notepad 3++", history.redo())
    }

    @Test
    fun coalescesRepeatedPrefixInsertionIntoOneUndoStep() {
        val history = EditorHistory("")

        history.recordUserEdit("A")
        history.recordUserEdit("BA")
        history.recordUserEdit("CBA")

        assertEquals("", history.undo())
        assertNull(history.undo())
        assertEquals("CBA", history.redo())
    }
}
