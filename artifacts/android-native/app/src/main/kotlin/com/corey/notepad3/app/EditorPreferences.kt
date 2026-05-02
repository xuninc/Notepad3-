package com.corey.notepad3.app

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

interface EditorPreferences {
    val layoutMode: StateFlow<EditorLayoutMode>
    fun setLayoutMode(mode: EditorLayoutMode)
}

class EditorPreferenceController(private val preferences: EditorPreferences) {
    val layoutMode: StateFlow<EditorLayoutMode> = preferences.layoutMode

    fun setLayoutMode(mode: EditorLayoutMode) {
        preferences.setLayoutMode(mode)
    }

    fun toggleLayoutMode() {
        setLayoutMode(layoutMode.value.toggled())
    }
}

class InMemoryEditorPreferences(
    layoutMode: EditorLayoutMode = EditorLayoutMode.MOBILE,
) : EditorPreferences {
    private val _layoutMode = MutableStateFlow(layoutMode)
    override val layoutMode: StateFlow<EditorLayoutMode> = _layoutMode.asStateFlow()

    override fun setLayoutMode(mode: EditorLayoutMode) {
        _layoutMode.value = mode
    }
}

class AndroidEditorPreferences(context: Context) : EditorPreferences {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("notepad3pp", Context.MODE_PRIVATE)

    private val _layoutMode = MutableStateFlow(decodeLayoutMode())
    override val layoutMode: StateFlow<EditorLayoutMode> = _layoutMode.asStateFlow()

    override fun setLayoutMode(mode: EditorLayoutMode) {
        prefs.edit().putString(KEY_LAYOUT_MODE, mode.storageName).apply()
        _layoutMode.value = mode
    }

    private fun decodeLayoutMode(): EditorLayoutMode =
        prefs.getString(KEY_LAYOUT_MODE, null)
            ?.let(EditorLayoutMode::fromStorageName)
            ?: EditorLayoutMode.MOBILE

    companion object {
        private const val KEY_LAYOUT_MODE = "notepad3pp.layoutMode"
    }
}
