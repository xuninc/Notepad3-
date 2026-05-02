package com.corey.notepad3.editor

object EditorStatus {
    fun summary(
        languageName: String,
        body: String,
        selection: TextSelection,
        readOnly: Boolean,
    ): String {
        val lineColumn = body.lineColumn(selection.min)
        val modeSummary = if (readOnly) " | Read Only" else ""
        val selectionLength = selection.max - selection.min
        val selectionSummary = if (selectionLength > 0) " | Sel $selectionLength chars" else ""
        return "$languageName$modeSummary | ${body.lines().size} lines | ${body.length} chars | " +
            "Ln ${lineColumn.first}, Col ${lineColumn.second}$selectionSummary"
    }
}

private fun String.lineColumn(caret: Int): Pair<Int, Int> {
    val clamped = caret.coerceIn(0, length)
    var line = 1
    var column = 1

    for (index in 0 until clamped) {
        if (this[index] == '\n') {
            line += 1
            column = 1
        } else {
            column += 1
        }
    }

    return line to column
}
