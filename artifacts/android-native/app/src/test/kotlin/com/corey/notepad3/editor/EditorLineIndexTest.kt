package com.corey.notepad3.editor

import org.junit.Assert.assertEquals
import org.junit.Test

class EditorLineIndexTest {
    @Test
    fun mapsOffsetsToLogicalLineNumbersWithoutRescanningFromTheStart() {
        val index = EditorLineIndex.from("alpha\nbravo\ncharlie")

        assertEquals(3, index.lineCount)
        assertEquals(1, index.lineNumberAtOffset(0))
        assertEquals(2, index.lineNumberAtOffset(6))
        assertEquals(3, index.lineNumberAtOffset(12))
        assertEquals(listOf(1, 2, 3), index.lineNumbersAtSortedOffsets(listOf(0, 6, 12)))
    }

    @Test
    fun treatsTrailingNewlineAsAnEmptyFinalLine() {
        val index = EditorLineIndex.from("one\n")

        assertEquals(2, index.lineCount)
        assertEquals(2, index.lineNumberAtOffset(4))
    }

    @Test
    fun clampsOutOfRangeOffsets() {
        val index = EditorLineIndex.from("one\ntwo")

        assertEquals(1, index.lineNumberAtOffset(-10))
        assertEquals(2, index.lineNumberAtOffset(100))
        assertEquals(listOf(1, 2), index.lineNumbersAtSortedOffsets(listOf(-10, 100)))
    }
}
