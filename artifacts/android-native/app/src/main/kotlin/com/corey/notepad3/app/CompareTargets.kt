package com.corey.notepad3.app

import com.corey.notepad3.models.TextDocument

fun chooseCompareTarget(
    activeId: String,
    documents: List<TextDocument>,
    previousTargetId: String?,
): TextDocument? {
    val comparable = documents.filter { it.id != activeId }
    return comparable.firstOrNull { it.id == previousTargetId } ?: comparable.firstOrNull()
}
