package com.corey.notepad3.editor

import kotlin.math.ceil

object EditorGutter {
    fun visibleLineCount(body: String): Int =
        body.count { it == '\n' } + 1

    fun digitCountForLineCount(lineCount: Int): Int =
        lineCount.coerceAtLeast(1).toString().length

    fun gutterWidthPx(
        lineCount: Int,
        digitWidthPx: Float,
        sidePaddingPx: Int,
    ): Int =
        ceil(digitCountForLineCount(lineCount) * digitWidthPx).toInt() + (sidePaddingPx * 2)

    fun totalLeftPaddingPx(
        lineCount: Int,
        digitWidthPx: Float,
        sidePaddingPx: Int,
        textPaddingPx: Int,
    ): Int =
        gutterWidthPx(lineCount, digitWidthPx, sidePaddingPx) + textPaddingPx

    fun logicalLineNumberAtOffset(body: String, offset: Int): Int {
        val clamped = offset.coerceIn(0, body.length)
        var line = 1
        for (index in 0 until clamped) {
            if (body[index] == '\n') line += 1
        }
        return line
    }
}
