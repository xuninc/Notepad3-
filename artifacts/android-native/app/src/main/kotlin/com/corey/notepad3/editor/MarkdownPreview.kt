package com.corey.notepad3.editor

sealed class MarkdownBlock {
    data class Heading(val level: Int, val text: String) : MarkdownBlock()
    data class Paragraph(val text: String) : MarkdownBlock()
    data class Bullet(val text: String) : MarkdownBlock()
    data class Code(val text: String) : MarkdownBlock()
}

object MarkdownPreview {
    fun parse(body: String): List<MarkdownBlock> {
        val blocks = mutableListOf<MarkdownBlock>()
        val paragraph = mutableListOf<String>()
        val code = mutableListOf<String>()
        var inCodeFence = false

        fun flushParagraph() {
            if (paragraph.isNotEmpty()) {
                blocks += MarkdownBlock.Paragraph(paragraph.joinToString("\n"))
                paragraph.clear()
            }
        }

        fun flushCode() {
            blocks += MarkdownBlock.Code(code.joinToString("\n"))
            code.clear()
        }

        body.lines().forEach { line ->
            val trimmed = line.trim()
            if (trimmed.startsWith("```")) {
                if (inCodeFence) {
                    flushCode()
                    inCodeFence = false
                } else {
                    flushParagraph()
                    inCodeFence = true
                }
                return@forEach
            }

            if (inCodeFence) {
                code += line
                return@forEach
            }

            if (trimmed.isEmpty()) {
                flushParagraph()
                return@forEach
            }

            val headingLevel = headingLevel(trimmed)
            if (headingLevel != null) {
                flushParagraph()
                blocks += MarkdownBlock.Heading(
                    level = headingLevel,
                    text = trimmed.drop(headingLevel).trim(),
                )
                return@forEach
            }

            val bulletText = bulletText(trimmed)
            if (bulletText != null) {
                flushParagraph()
                blocks += MarkdownBlock.Bullet(bulletText)
                return@forEach
            }

            paragraph += line
        }

        if (inCodeFence) {
            flushCode()
        } else {
            flushParagraph()
        }

        return blocks
    }

    private fun headingLevel(trimmed: String): Int? {
        val count = trimmed.takeWhile { it == '#' }.length
        return count.takeIf {
            it in 1..6 && trimmed.length > it && trimmed[it].isWhitespace()
        }
    }

    private fun bulletText(trimmed: String): String? =
        when {
            trimmed.startsWith("- ") -> trimmed.drop(2).trim()
            trimmed.startsWith("* ") -> trimmed.drop(2).trim()
            else -> null
        }
}
