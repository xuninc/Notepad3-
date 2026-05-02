package com.corey.notepad3.editor

import org.junit.Assert.assertEquals
import org.junit.Test

class MarkdownPreviewTest {
    @Test
    fun parsesCommonMarkdownBlocksInDocumentOrder() {
        val blocks = MarkdownPreview.parse(
            """
                # Title

                Body line
                still body

                - first
                - second

                ```kotlin
                val x = 1
                ```

                ### Tail
            """.trimIndent(),
        )

        assertEquals(
            listOf(
                MarkdownBlock.Heading(level = 1, text = "Title"),
                MarkdownBlock.Paragraph("Body line\nstill body"),
                MarkdownBlock.Bullet("first"),
                MarkdownBlock.Bullet("second"),
                MarkdownBlock.Code("val x = 1"),
                MarkdownBlock.Heading(level = 3, text = "Tail"),
            ),
            blocks,
        )
    }

    @Test
    fun keepsUnclosedFenceAsCodeThroughTheEndOfTheDocument() {
        val blocks = MarkdownPreview.parse(
            """
                Intro

                ```
                line one
                line two
            """.trimIndent(),
        )

        assertEquals(
            listOf(
                MarkdownBlock.Paragraph("Intro"),
                MarkdownBlock.Code("line one\nline two"),
            ),
            blocks,
        )
    }
}
