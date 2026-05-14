package com.corey.notepad3.editor

import com.corey.notepad3.models.DocumentLanguage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SyntaxHighlighterTest {
    @Test
    fun plansKeywordStringNumberAndCommentRangesWithoutHighlightingStringContents() {
        val text = """
            fun main() {
                val answer = 42
                println("if // not a comment")
            } // return later
        """.trimIndent()

        val ranges = SyntaxHighlighter.plan(text, DocumentLanguage.KOTLIN)

        assertHas(text, ranges, "fun", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "val", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "42", HighlightCategory.NUMBER)
        assertHas(text, ranges, "\"if // not a comment\"", HighlightCategory.STRING)
        assertHas(text, ranges, "// return later", HighlightCategory.COMMENT)
        assertFalse(ranges.containsText(text, "if", HighlightCategory.KEYWORD))
    }

    @Test
    fun supportsHashCommentsAndHexNumbersForPython() {
        val text = "def build():\n    return 0x2A # answer"

        val ranges = SyntaxHighlighter.plan(text, DocumentLanguage.PYTHON)

        assertHas(text, ranges, "def", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "return", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "0x2A", HighlightCategory.NUMBER)
        assertHas(text, ranges, "# answer", HighlightCategory.COMMENT)
    }

    @Test
    fun treatsSqlKeywordsAndCommentsCaseInsensitively() {
        val text = "SELECT * FROM notes WHERE id = 7 -- filter"

        val ranges = SyntaxHighlighter.plan(text, DocumentLanguage.SQL)

        assertHas(text, ranges, "SELECT", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "FROM", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "WHERE", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "7", HighlightCategory.NUMBER)
        assertHas(text, ranges, "-- filter", HighlightCategory.COMMENT)
    }

    @Test
    fun blockCommentsClaimTheirContentsBeforeKeywordPasses() {
        val text = "const ok = true\n/* if false */\nlet done = 1"

        val ranges = SyntaxHighlighter.plan(text, DocumentLanguage.JAVA_SCRIPT)

        assertHas(text, ranges, "const", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "true", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "/* if false */", HighlightCategory.COMMENT)
        assertHas(text, ranges, "let", HighlightCategory.KEYWORD)
        assertHas(text, ranges, "1", HighlightCategory.NUMBER)
        assertFalse(ranges.containsText(text, "if", HighlightCategory.KEYWORD))
        assertFalse(ranges.containsText(text, "false", HighlightCategory.KEYWORD))
    }

    @Test
    fun skipsPlainAndMarkdownDocuments() {
        assertFalse(SyntaxHighlighter.supports(DocumentLanguage.PLAIN))
        assertFalse(SyntaxHighlighter.supports(DocumentLanguage.MARKDOWN))
        assertTrue(SyntaxHighlighter.supports(DocumentLanguage.KOTLIN))
        assertEquals(emptyList<HighlightRange>(), SyntaxHighlighter.plan("return 1", DocumentLanguage.PLAIN))
        assertEquals(emptyList<HighlightRange>(), SyntaxHighlighter.plan("# return 1", DocumentLanguage.MARKDOWN))
    }

    @Test
    fun refusesLargeInputsPastTheConfiguredGuard() {
        val text = "val answer = 42"

        assertEquals(emptyList<HighlightRange>(), SyntaxHighlighter.plan(text, DocumentLanguage.KOTLIN, maxTextLength = 4))
    }

    private fun assertHas(
        text: String,
        ranges: List<HighlightRange>,
        snippet: String,
        category: HighlightCategory,
    ) {
        assertTrue(
            "Expected $category range for '$snippet' in $ranges",
            ranges.containsText(text, snippet, category),
        )
    }

    private fun List<HighlightRange>.containsText(
        source: String,
        snippet: String,
        category: HighlightCategory,
    ): Boolean =
        any { it.category == category && source.substring(it.start, it.end) == snippet }
}
