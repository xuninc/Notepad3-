package com.corey.notepad3.editor

import java.util.Locale

data class TextSelection(
    val start: Int,
    val end: Int = start,
) {
    val min: Int = kotlin.math.min(start, end)
    val max: Int = kotlin.math.max(start, end)

    fun clamped(length: Int): TextSelection {
        val safeStart = start.coerceIn(0, length)
        val safeEnd = end.coerceIn(0, length)
        return TextSelection(safeStart, safeEnd)
    }
}

data class EditResult(
    val body: String,
    val selection: TextSelection,
)

object EditorCommands {
    fun trimTrailingSpaces(body: String, selection: TextSelection): EditResult {
        val trimmed = body.split("\n", ignoreCase = false, limit = 0)
            .joinToString("\n") { it.replace(Regex("[ \\t]+$"), "") }
        return EditResult(trimmed, selection.clamped(trimmed.length))
    }

    fun sortLines(body: String): EditResult {
        val sorted = body.split("\n")
            .sortedWith(String.CASE_INSENSITIVE_ORDER)
            .joinToString("\n")
        return EditResult(sorted, TextSelection(0))
    }

    fun duplicateCurrentLine(body: String, caret: Int): EditResult {
        val (lineStart, lineEnd) = lineRange(body, caret)
        val line = body.substring(lineStart, lineEnd)
        val inserted = "\n$line"
        val next = body.replaceRange(lineEnd, lineEnd, inserted)
        return EditResult(next, TextSelection((caret + inserted.length).coerceIn(0, next.length)))
    }

    fun deleteCurrentLine(body: String, caret: Int): EditResult {
        val (lineStart, lineEnd) = lineRange(body, caret)
        val removeEnd = if (lineEnd < body.length && body[lineEnd] == '\n') lineEnd + 1 else lineEnd
        val next = body.removeRange(lineStart, removeEnd)
        return EditResult(next, TextSelection(lineStart.coerceIn(0, next.length)))
    }

    fun insertText(body: String, selection: TextSelection, value: String): EditResult {
        val safeSelection = selection.clamped(body.length)
        val next = body.replaceRange(safeSelection.min, safeSelection.max, value)
        return EditResult(next, TextSelection(safeSelection.min + value.length))
    }

    fun uppercaseSelection(body: String, selection: TextSelection): EditResult =
        transformSelection(body, selection) { it.uppercase(Locale.ROOT) }

    fun lowercaseSelection(body: String, selection: TextSelection): EditResult =
        transformSelection(body, selection) { it.lowercase(Locale.ROOT) }

    fun indentSelection(body: String, selection: TextSelection): EditResult {
        val safeSelection = selection.clamped(body.length)
        val starts = selectedLineStarts(body, safeSelection)
        val next = insertAtLineStarts(body, starts, "    ")
        val selectionShift = starts.count { it <= safeSelection.start } * 4
        val endShift = starts.count { it <= safeSelection.end } * 4
        return EditResult(
            body = next,
            selection = TextSelection(safeSelection.start + selectionShift, safeSelection.end + endShift),
        )
    }

    fun unindentSelection(body: String, selection: TextSelection): EditResult {
        val safeSelection = selection.clamped(body.length)
        val starts = selectedLineStarts(body, safeSelection)
        val removals = starts.map { lineStart ->
            lineStart to indentationRemovalLength(body, lineStart)
        }.filter { (_, removalLength) -> removalLength > 0 }

        val next = removals.asReversed().fold(body) { current, (lineStart, removalLength) ->
            current.removeRange(lineStart, lineStart + removalLength)
        }
        val startShift = removals.sumOf { (lineStart, removalLength) ->
            if (lineStart < safeSelection.start) removalLength else 0
        }
        val endShift = removals.sumOf { (lineStart, removalLength) ->
            if (lineStart < safeSelection.end) removalLength else 0
        }
        return EditResult(
            body = next,
            selection = TextSelection(
                (safeSelection.start - startShift).coerceIn(0, next.length),
                (safeSelection.end - endShift).coerceIn(0, next.length),
            ),
        )
    }

    fun gotoLine(body: String, lineNumber: Int): TextSelection {
        val targetLine = lineNumber.coerceAtLeast(1)
        var currentLine = 1
        var index = 0
        var lastLineStart = 0

        while (index < body.length && currentLine < targetLine) {
            if (body[index] == '\n') {
                currentLine += 1
                lastLineStart = index + 1
            }
            index += 1
        }

        return TextSelection(lastLineStart.coerceIn(0, body.length))
    }

    fun selectAll(body: String): TextSelection = TextSelection(0, body.length)

    fun selectLine(body: String, caret: Int): TextSelection {
        val (lineStart, lineEnd) = lineRange(body, caret)
        return TextSelection(lineStart, lineEnd)
    }

    fun selectParagraph(body: String, caret: Int): TextSelection {
        val ranges = lineRanges(body)
        val lineIndex = lineIndexForCaret(ranges, body, caret)
        if (lineIsBlank(body, ranges[lineIndex])) {
            return TextSelection(ranges[lineIndex].first, ranges[lineIndex].second)
        }

        var firstLine = lineIndex
        while (firstLine > 0 && !lineIsBlank(body, ranges[firstLine - 1])) {
            firstLine -= 1
        }

        var lastLine = lineIndex
        while (lastLine < ranges.lastIndex && !lineIsBlank(body, ranges[lastLine + 1])) {
            lastLine += 1
        }

        val start = ranges[firstLine].first
        val endBeforeLineBreak = ranges[lastLine].second
        val end = if (endBeforeLineBreak < body.length) endBeforeLineBreak + 1 else endBeforeLineBreak
        return TextSelection(start, end)
    }

    fun findNext(body: String, query: String, selection: TextSelection): TextSelection? {
        if (query.isBlank()) return null
        val startAt = selection.clamped(body.length).max
        val found = body.indexOf(query, startIndex = startAt, ignoreCase = true)
            .takeIf { it >= 0 }
            ?: body.indexOf(query, startIndex = 0, ignoreCase = true).takeIf { it >= 0 }
        return found?.let { TextSelection(it, it + query.length) }
    }

    fun findPrevious(body: String, query: String, selection: TextSelection): TextSelection? {
        if (query.isBlank()) return null
        val before = selection.clamped(body.length).min
        val matches = findMatches(body, query)
        return matches.lastOrNull { it.start < before } ?: matches.lastOrNull()
    }

    fun replaceAll(body: String, query: String, replacement: String): EditResult {
        if (query.isBlank()) return EditResult(body, TextSelection(0))
        val next = findMatches(body, query)
            .asReversed()
            .fold(body) { current, match ->
                current.replaceRange(match.start, match.end, replacement)
            }
        return EditResult(next, TextSelection(0))
    }

    fun replaceCurrent(
        body: String,
        query: String,
        replacement: String,
        selection: TextSelection,
    ): EditResult {
        val safeSelection = selection.clamped(body.length)
        if (safeSelection.min == safeSelection.max) {
            return EditResult(body, findNext(body, query, safeSelection) ?: safeSelection)
        }

        val next = body.replaceRange(safeSelection.min, safeSelection.max, replacement)
        val caret = TextSelection(safeSelection.min + replacement.length)
        return EditResult(next, findNext(next, query, caret) ?: caret)
    }

    fun findMatches(body: String, query: String): List<TextSelection> {
        if (query.isBlank()) return emptyList()
        val matches = mutableListOf<TextSelection>()
        var index = body.indexOf(query, startIndex = 0, ignoreCase = true)
        while (index >= 0) {
            matches += TextSelection(index, index + query.length)
            index = body.indexOf(query, startIndex = index + query.length, ignoreCase = true)
        }
        return matches
    }

    private fun lineRange(body: String, caret: Int): Pair<Int, Int> {
        val clamped = caret.coerceIn(0, body.length)
        var start = clamped
        while (start > 0 && body[start - 1] != '\n') start -= 1
        var end = clamped
        while (end < body.length && body[end] != '\n') end += 1
        return start to end
    }

    private fun lineRanges(body: String): List<Pair<Int, Int>> {
        val ranges = mutableListOf<Pair<Int, Int>>()
        var start = 0
        for (index in body.indices) {
            if (body[index] == '\n') {
                ranges += start to index
                start = index + 1
            }
        }
        ranges += start to body.length
        return ranges
    }

    private fun lineIndexForCaret(ranges: List<Pair<Int, Int>>, body: String, caret: Int): Int {
        val clamped = caret.coerceIn(0, body.length)
        return ranges.indexOfFirst { (_, end) -> clamped <= end }.takeIf { it >= 0 } ?: ranges.lastIndex
    }

    private fun lineIsBlank(body: String, range: Pair<Int, Int>): Boolean =
        body.substring(range.first, range.second).isBlank()

    private fun transformSelection(
        body: String,
        selection: TextSelection,
        transform: (String) -> String,
    ): EditResult {
        val safeSelection = selection.clamped(body.length)
        if (safeSelection.min == safeSelection.max) return EditResult(body, safeSelection)
        val replacement = transform(body.substring(safeSelection.min, safeSelection.max))
        val next = body.replaceRange(safeSelection.min, safeSelection.max, replacement)
        return EditResult(next, TextSelection(safeSelection.min, safeSelection.min + replacement.length))
    }

    private fun selectedLineStarts(body: String, selection: TextSelection): List<Int> {
        val ranges = lineRanges(body)
        val lookupEnd = if (selection.min == selection.max) {
            selection.max
        } else {
            (selection.max - 1).coerceAtLeast(selection.min)
        }
        val firstLine = lineIndexForCaret(ranges, body, selection.min)
        val lastLine = lineIndexForCaret(ranges, body, lookupEnd)
        return (firstLine..lastLine).map { ranges[it].first }
    }

    private fun insertAtLineStarts(body: String, lineStarts: List<Int>, value: String): String {
        var next = body
        var offset = 0
        lineStarts.forEach { lineStart ->
            val insertionPoint = lineStart + offset
            next = next.replaceRange(insertionPoint, insertionPoint, value)
            offset += value.length
        }
        return next
    }

    private fun indentationRemovalLength(body: String, lineStart: Int): Int {
        if (lineStart >= body.length) return 0
        if (body[lineStart] == '\t') return 1
        var count = 0
        while (lineStart + count < body.length && count < 4 && body[lineStart + count] == ' ') {
            count += 1
        }
        return count
    }
}
