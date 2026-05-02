package com.corey.notepad3.app

import com.corey.notepad3.models.TextDocument
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CompareTargetsTest {
    @Test
    fun keepsPreviousTargetWhenItIsStillComparable() {
        val active = document("active", "active.txt")
        val first = document("first", "first.txt")
        val second = document("second", "second.txt")

        val target = chooseCompareTarget(
            activeId = active.id,
            documents = listOf(active, first, second),
            previousTargetId = second.id,
        )

        assertEquals(second.id, target?.id)
    }

    @Test
    fun fallsBackToTheFirstOtherDocumentWhenPreviousTargetIsActive() {
        val active = document("active", "active.txt")
        val first = document("first", "first.txt")
        val second = document("second", "second.txt")

        val target = chooseCompareTarget(
            activeId = active.id,
            documents = listOf(active, first, second),
            previousTargetId = active.id,
        )

        assertEquals(first.id, target?.id)
    }

    @Test
    fun fallsBackWhenPreviousTargetHasBeenClosed() {
        val active = document("active", "active.txt")
        val first = document("first", "first.txt")

        val target = chooseCompareTarget(
            activeId = active.id,
            documents = listOf(active, first),
            previousTargetId = "closed",
        )

        assertEquals(first.id, target?.id)
    }

    @Test
    fun returnsNullWhenNoOtherDocumentCanBeCompared() {
        val active = document("active", "active.txt")

        val target = chooseCompareTarget(
            activeId = active.id,
            documents = listOf(active),
            previousTargetId = null,
        )

        assertNull(target)
    }

    private fun document(id: String, title: String): TextDocument =
        TextDocument(id = id, title = title)
}
