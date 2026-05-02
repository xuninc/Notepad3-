package com.corey.notepad3.app

enum class EditorLayoutMode(val storageName: String) {
    MOBILE("mobile"),
    CLASSIC("classic"),
    ;

    val showMobileBottomBar: Boolean
        get() = this == MOBILE

    val showClassicCloseButton: Boolean
        get() = this == CLASSIC

    val toggleLabel: String
        get() = when (this) {
            MOBILE -> "Classic UI"
            CLASSIC -> "Mobile UI"
        }

    fun toggled(): EditorLayoutMode =
        when (this) {
            MOBILE -> CLASSIC
            CLASSIC -> MOBILE
        }

    companion object {
        fun fromStorageName(value: String): EditorLayoutMode? =
            entries.firstOrNull { it.storageName == value }
    }
}
