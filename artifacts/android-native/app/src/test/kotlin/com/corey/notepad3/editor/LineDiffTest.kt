package com.corey.notepad3.editor

import org.junit.Assert.assertEquals
import org.junit.Test

class LineDiffTest {
    @Test
    fun reportsIdenticalDocumentsAsFullySimilar() {
        val diff = LineDiff.compute(top = "one\ntwo", bottom = "one\ntwo")

        assertEquals(2, diff.summary.unchanged)
        assertEquals(0, diff.summary.added)
        assertEquals(0, diff.summary.removed)
        assertEquals(0, diff.summary.changed)
        assertEquals(100, diff.summary.percentSimilar)
        assertEquals(listOf(LineDiff.Status.Unchanged, LineDiff.Status.Unchanged), diff.topStatuses)
        assertEquals(listOf(LineDiff.Status.Unchanged, LineDiff.Status.Unchanged), diff.bottomStatuses)
    }

    @Test
    fun reportsAddedLinesAgainstTheBottomDocument() {
        val diff = LineDiff.compute(top = "one\ntwo", bottom = "one\ntwo\nthree")

        assertEquals(2, diff.summary.unchanged)
        assertEquals(1, diff.summary.added)
        assertEquals(0, diff.summary.removed)
        assertEquals(0, diff.summary.changed)
        assertEquals(66, diff.summary.percentSimilar)
        assertEquals(
            listOf(LineDiff.Status.Unchanged, LineDiff.Status.Unchanged, LineDiff.Status.Added),
            diff.bottomStatuses,
        )
        assertEquals(
            listOf(
                LineDiff.Row("one", LineDiff.Status.Unchanged, "one", LineDiff.Status.Unchanged),
                LineDiff.Row("two", LineDiff.Status.Unchanged, "two", LineDiff.Status.Unchanged),
                LineDiff.Row(null, null, "three", LineDiff.Status.Added),
            ),
            diff.rows,
        )
    }

    @Test
    fun pairsSimilarRemoveAndAddRunsAsChangedLinesLikeIos() {
        val diff = LineDiff.compute(
            top = "alpha\ncount = 1\nomega",
            bottom = "alpha\ncount = 2\nomega",
        )

        assertEquals(2, diff.summary.unchanged)
        assertEquals(0, diff.summary.added)
        assertEquals(0, diff.summary.removed)
        assertEquals(1, diff.summary.changed)
        assertEquals(66, diff.summary.percentSimilar)
        assertEquals(LineDiff.Status.Changed, diff.topStatuses[1])
        assertEquals(LineDiff.Status.Changed, diff.bottomStatuses[1])
        assertEquals(
            LineDiff.Row("count = 1", LineDiff.Status.Changed, "count = 2", LineDiff.Status.Changed),
            diff.rows[1],
        )
    }

    @Test
    fun keepsDissimilarLinesAsRemoveAndAdd() {
        val diff = LineDiff.compute(
            top = "alpha\nshort\nomega",
            bottom = "alpha\ncompletely different\nomega",
        )

        assertEquals(2, diff.summary.unchanged)
        assertEquals(1, diff.summary.added)
        assertEquals(1, diff.summary.removed)
        assertEquals(0, diff.summary.changed)
        assertEquals(LineDiff.Status.Removed, diff.topStatuses[1])
        assertEquals(LineDiff.Status.Added, diff.bottomStatuses[1])
        assertEquals(
            listOf(
                LineDiff.Row("alpha", LineDiff.Status.Unchanged, "alpha", LineDiff.Status.Unchanged),
                LineDiff.Row("short", LineDiff.Status.Removed, null, null),
                LineDiff.Row(null, null, "completely different", LineDiff.Status.Added),
                LineDiff.Row("omega", LineDiff.Status.Unchanged, "omega", LineDiff.Status.Unchanged),
            ),
            diff.rows,
        )
    }
}
