package com.corey.notepad3.editor

class EditorHistory(initialBody: String = "") {
    private val undoStack = ArrayDeque<String>()
    private val redoStack = ArrayDeque<String>()
    private var current = initialBody
    private var openGroup: EditGroup? = null

    val canUndo: Boolean
        get() = undoStack.isNotEmpty()

    val canRedo: Boolean
        get() = redoStack.isNotEmpty()

    fun record(nextBody: String) {
        openGroup = null
        if (nextBody == current) return
        undoStack.addLast(current)
        current = nextBody
        redoStack.clear()
    }

    fun recordUserEdit(nextBody: String) {
        val delta = TextDelta.between(current, nextBody) ?: return
        val group = openGroup
        if (group != null && group.canMerge(delta)) {
            openGroup = group.merged(delta)
            current = nextBody
            redoStack.clear()
            return
        }

        undoStack.addLast(current)
        current = nextBody
        redoStack.clear()
        openGroup = EditGroup.from(delta)
    }

    fun sync(body: String) {
        openGroup = null
        current = body
    }

    fun undo(): String? {
        if (undoStack.isEmpty()) return null
        openGroup = null
        redoStack.addLast(current)
        current = undoStack.removeLast()
        return current
    }

    fun redo(): String? {
        if (redoStack.isEmpty()) return null
        openGroup = null
        undoStack.addLast(current)
        current = redoStack.removeLast()
        return current
    }

    private enum class EditKind {
        Insert,
        Delete,
        Replace,
    }

    private data class TextDelta(
        val kind: EditKind,
        val start: Int,
        val removedLength: Int,
        val insertedLength: Int,
    ) {
        companion object {
            fun between(previous: String, next: String): TextDelta? {
                if (previous == next) return null

                var start = 0
                val sharedPrefixLength = minOf(previous.length, next.length)
                while (start < sharedPrefixLength && previous[start] == next[start]) {
                    start += 1
                }

                var previousEnd = previous.length
                var nextEnd = next.length
                while (
                    previousEnd > start &&
                    nextEnd > start &&
                    previous[previousEnd - 1] == next[nextEnd - 1]
                ) {
                    previousEnd -= 1
                    nextEnd -= 1
                }

                val removedLength = previousEnd - start
                val insertedLength = nextEnd - start
                val kind = when {
                    removedLength == 0 -> EditKind.Insert
                    insertedLength == 0 -> EditKind.Delete
                    else -> EditKind.Replace
                }
                return TextDelta(kind, start, removedLength, insertedLength)
            }
        }
    }

    private data class EditGroup(
        val kind: EditKind,
        val start: Int,
        val length: Int,
    ) {
        fun canMerge(delta: TextDelta): Boolean =
            when (kind) {
                EditKind.Insert ->
                    delta.kind == EditKind.Insert && (delta.start == start + length || delta.start == start)
                EditKind.Delete ->
                    delta.kind == EditKind.Delete &&
                        (delta.start + delta.removedLength == start || delta.start == start)
                EditKind.Replace ->
                    false
            }

        fun merged(delta: TextDelta): EditGroup =
            when (kind) {
                EditKind.Insert -> copy(length = length + delta.insertedLength)
                EditKind.Delete -> copy(
                    start = minOf(start, delta.start),
                    length = length + delta.removedLength,
                )
                EditKind.Replace -> this
            }

        companion object {
            fun from(delta: TextDelta): EditGroup? =
                when (delta.kind) {
                    EditKind.Insert -> EditGroup(EditKind.Insert, delta.start, delta.insertedLength)
                    EditKind.Delete -> EditGroup(EditKind.Delete, delta.start, delta.removedLength)
                    EditKind.Replace -> null
                }
        }
    }
}
