package com.corey.notepad3.editor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EditorGutterTest {
    @Test
    fun countsAtLeastOneVisibleLineForEmptyDocuments() {
        assertEquals(1, EditorGutter.visibleLineCount(""))
        assertEquals(1, EditorGutter.visibleLineCount("single line"))
    }

    @Test
    fun countsTrailingBlankLinesLikeTheEditor() {
        assertEquals(2, EditorGutter.visibleLineCount("alpha\n"))
        assertEquals(3, EditorGutter.visibleLineCount("alpha\nbeta\n"))
    }

    @Test
    fun digitCountGrowsAtLineNumberBoundaries() {
        assertEquals(1, EditorGutter.digitCountForLineCount(9))
        assertEquals(2, EditorGutter.digitCountForLineCount(10))
        assertEquals(3, EditorGutter.digitCountForLineCount(100))
    }

    @Test
    fun gutterWidthReservesRoomForNumbersAndTextPadding() {
        val oneDigit = EditorGutter.gutterWidthPx(lineCount = 9, digitWidthPx = 8f, sidePaddingPx = 10)
        val threeDigits = EditorGutter.gutterWidthPx(lineCount = 100, digitWidthPx = 8f, sidePaddingPx = 10)

        assertEquals(28, oneDigit)
        assertEquals(44, threeDigits)
        assertTrue(threeDigits > oneDigit)
    }

    @Test
    fun totalLeftPaddingKeepsBodyTextOutOfTheLineNumberColumn() {
        val padding = EditorGutter.totalLeftPaddingPx(
            lineCount = 42,
            digitWidthPx = 9f,
            sidePaddingPx = 12,
            textPaddingPx = 18,
        )

        assertEquals(60, padding)
    }

    @Test
    fun mapsCharacterOffsetsToLogicalLineNumbers() {
        val body = "alpha\nbeta\ngamma"

        assertEquals(1, EditorGutter.logicalLineNumberAtOffset(body, 0))
        assertEquals(1, EditorGutter.logicalLineNumberAtOffset(body, 5))
        assertEquals(2, EditorGutter.logicalLineNumberAtOffset(body, 6))
        assertEquals(3, EditorGutter.logicalLineNumberAtOffset(body, body.length))
    }
}
