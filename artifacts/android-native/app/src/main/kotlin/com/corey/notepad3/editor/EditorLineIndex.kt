package com.corey.notepad3.editor

class EditorLineIndex private constructor(
    private val lineStarts: IntArray,
    private val bodyLength: Int,
) {
    val lineCount: Int
        get() = lineStarts.size

    fun lineNumberAtOffset(rawOffset: Int): Int {
        val offset = rawOffset.coerceIn(0, bodyLength)
        var low = 0
        var high = lineStarts.lastIndex
        var best = 0

        while (low <= high) {
            val mid = (low + high).ushr(1)
            if (lineStarts[mid] <= offset) {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return best + 1
    }

    fun lineNumbersAtSortedOffsets(offsets: List<Int>): List<Int> =
        offsets.map(::lineNumberAtOffset)

    companion object {
        val EMPTY: EditorLineIndex = from("")

        fun from(body: String): EditorLineIndex {
            val starts = ArrayList<Int>()
            starts += 0
            body.forEachIndexed { index, char ->
                if (char == '\n') {
                    starts += index + 1
                }
            }
            return EditorLineIndex(starts.toIntArray(), body.length)
        }
    }
}
