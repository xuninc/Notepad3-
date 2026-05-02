package com.corey.notepad3.editor

object LineDiff {
    enum class Status {
        Unchanged,
        Added,
        Removed,
        Changed,
    }

    data class Summary(
        val unchanged: Int,
        val added: Int,
        val removed: Int,
        val changed: Int,
        val percentSimilar: Int,
    )

    data class Result(
        val topLines: List<String>,
        val bottomLines: List<String>,
        val topStatuses: List<Status>,
        val bottomStatuses: List<Status>,
        val rows: List<Row>,
        val summary: Summary,
    )

    data class Row(
        val topLine: String?,
        val topStatus: Status?,
        val bottomLine: String?,
        val bottomStatus: Status?,
    )

    fun compute(top: String, bottom: String): Result {
        val topLines = top.split("\n")
        val bottomLines = bottom.split("\n")
        val reconciled = reconcileChanges(lcsOps(topLines, bottomLines), topLines, bottomLines)

        val topStatuses = mutableListOf<Status>()
        val bottomStatuses = mutableListOf<Status>()
        val rows = mutableListOf<Row>()
        var topIndex = 0
        var bottomIndex = 0
        var unchanged = 0
        var added = 0
        var removed = 0
        var changed = 0

        reconciled.forEach { op ->
            when (op) {
                Op.Equal -> {
                    topStatuses += Status.Unchanged
                    bottomStatuses += Status.Unchanged
                    rows += Row(
                        topLine = topLines[topIndex],
                        topStatus = Status.Unchanged,
                        bottomLine = bottomLines[bottomIndex],
                        bottomStatus = Status.Unchanged,
                    )
                    topIndex += 1
                    bottomIndex += 1
                    unchanged += 1
                }
                Op.Add -> {
                    bottomStatuses += Status.Added
                    rows += Row(
                        topLine = null,
                        topStatus = null,
                        bottomLine = bottomLines[bottomIndex],
                        bottomStatus = Status.Added,
                    )
                    bottomIndex += 1
                    added += 1
                }
                Op.Remove -> {
                    topStatuses += Status.Removed
                    rows += Row(
                        topLine = topLines[topIndex],
                        topStatus = Status.Removed,
                        bottomLine = null,
                        bottomStatus = null,
                    )
                    topIndex += 1
                    removed += 1
                }
                Op.ChangePair -> {
                    topStatuses += Status.Changed
                    bottomStatuses += Status.Changed
                    rows += Row(
                        topLine = topLines[topIndex],
                        topStatus = Status.Changed,
                        bottomLine = bottomLines[bottomIndex],
                        bottomStatus = Status.Changed,
                    )
                    topIndex += 1
                    bottomIndex += 1
                    changed += 1
                }
            }
        }

        while (topStatuses.size < topLines.size) topStatuses += Status.Unchanged
        while (bottomStatuses.size < bottomLines.size) bottomStatuses += Status.Unchanged

        val denominator = maxOf(topLines.size, bottomLines.size)
        val percentSimilar = if (denominator == 0) {
            100
        } else {
            ((unchanged.toDouble() / denominator.toDouble()) * 100.0).toInt()
        }

        return Result(
            topLines = topLines,
            bottomLines = bottomLines,
            topStatuses = topStatuses,
            bottomStatuses = bottomStatuses,
            rows = rows,
            summary = Summary(
                unchanged = unchanged,
                added = added,
                removed = removed,
                changed = changed,
                percentSimilar = percentSimilar,
            ),
        )
    }

    fun similarity(first: String, second: String): Double {
        if (first == second) return 1.0
        if (first.isEmpty() && second.isEmpty()) return 1.0
        if (first.isEmpty() || second.isEmpty()) return 0.0

        val distance = levenshtein(first.toList(), second.toList())
        val longest = maxOf(first.length, second.length)
        return 1.0 - distance.toDouble() / longest.toDouble()
    }

    private enum class Op {
        Equal,
        Add,
        Remove,
        ChangePair,
    }

    private fun lcsOps(a: List<String>, b: List<String>): List<Op> {
        val n = a.size
        val m = b.size
        if (n == 0) return List(m) { Op.Add }
        if (m == 0) return List(n) { Op.Remove }

        val back = ByteArray((n + 1) * (m + 1))
        var previous = IntArray(m + 1)
        var current = IntArray(m + 1)

        fun index(i: Int, j: Int): Int = i * (m + 1) + j

        for (i in 1..n) {
            for (j in 1..m) {
                if (a[i - 1] == b[j - 1]) {
                    current[j] = previous[j - 1] + 1
                    back[index(i, j)] = 0
                } else if (previous[j] >= current[j - 1]) {
                    current[j] = previous[j]
                    back[index(i, j)] = 1
                } else {
                    current[j] = current[j - 1]
                    back[index(i, j)] = 2
                }
            }
            val temp = previous
            previous = current
            current = temp
            current.fill(0)
        }

        val ops = mutableListOf<Op>()
        var i = n
        var j = m
        while (i > 0 && j > 0) {
            when (back[index(i, j)].toInt()) {
                0 -> {
                    ops += Op.Equal
                    i -= 1
                    j -= 1
                }
                1 -> {
                    ops += Op.Remove
                    i -= 1
                }
                else -> {
                    ops += Op.Add
                    j -= 1
                }
            }
        }
        while (i > 0) {
            ops += Op.Remove
            i -= 1
        }
        while (j > 0) {
            ops += Op.Add
            j -= 1
        }
        return ops.asReversed()
    }

    private fun reconcileChanges(ops: List<Op>, a: List<String>, b: List<String>): List<Op> {
        val out = mutableListOf<Op>()
        var ai = 0
        var bi = 0
        var k = 0

        while (k < ops.size) {
            when (ops[k]) {
                Op.Equal -> {
                    out += Op.Equal
                    ai += 1
                    bi += 1
                    k += 1
                }
                Op.Remove, Op.Add -> {
                    val runStart = k
                    while (k < ops.size && (ops[k] == Op.Remove || ops[k] == Op.Add)) {
                        k += 1
                    }
                    val runEnd = k
                    val removeLines = mutableListOf<String>()
                    val addLines = mutableListOf<String>()
                    for (idx in runStart until runEnd) {
                        if (ops[idx] == Op.Remove) {
                            removeLines += a[ai]
                            ai += 1
                        } else {
                            addLines += b[bi]
                            bi += 1
                        }
                    }

                    val pairCount = minOf(removeLines.size, addLines.size)
                    val paired = BooleanArray(pairCount)
                    for (pairIndex in 0 until pairCount) {
                        paired[pairIndex] = similarity(removeLines[pairIndex], addLines[pairIndex]) >= 0.5
                    }

                    for (pairIndex in 0 until pairCount) {
                        if (paired[pairIndex]) {
                            out += Op.ChangePair
                        } else {
                            out += Op.Remove
                            out += Op.Add
                        }
                    }
                    repeat(removeLines.size - pairCount) { out += Op.Remove }
                    repeat(addLines.size - pairCount) { out += Op.Add }
                }
                Op.ChangePair -> {
                    out += Op.ChangePair
                    ai += 1
                    bi += 1
                    k += 1
                }
            }
        }

        return out
    }

    private fun levenshtein(first: List<Char>, second: List<Char>): Int {
        val short = if (first.size <= second.size) first else second
        val long = if (first.size <= second.size) second else first
        var previous = IntArray(short.size + 1) { it }
        var current = IntArray(short.size + 1)

        for (i in 1..long.size) {
            current[0] = i
            for (j in 1..short.size) {
                val cost = if (long[i - 1] == short[j - 1]) 0 else 1
                current[j] = minOf(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost,
                )
            }
            val temp = previous
            previous = current
            current = temp
        }
        return previous[short.size]
    }
}
