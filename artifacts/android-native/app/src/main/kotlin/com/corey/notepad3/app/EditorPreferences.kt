package com.corey.notepad3.app

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class AccessoryToolbarButton(val storageName: String, val displayTitle: String) {
    HIDE_KEYBOARD("hide_keyboard", "Hide"),
    CUT("cut", "Cut"),
    COPY("copy", "Copy"),
    PASTE("paste", "Paste"),
    SELECT_WORD("select_word", "Word"),
    SELECT_LINE("select_line", "Line"),
    SELECT_ALL("select_all", "All"),
    UNDO("undo", "Undo"),
    REDO("redo", "Redo"),
    READ_MODE("read_mode", "Read"),
    FIND("find", "Find"),
    INSERT_DATE("insert_date", "Date"),
    OPEN_DOCUMENTS("open_documents", "Open"),
    COMPARE("compare", "Compare"),
    MORE("more", "More"),
    SHIFT("shift", "Shift"),
    MOVE_UP("move_up", "Up"),
    DELETE_BACKWARD("delete_backward", "Delete"),
    MOVE_LEFT("move_left", "Left"),
    MOVE_DOWN("move_down", "Down"),
    MOVE_RIGHT("move_right", "Right"),
    ;

    companion object {
        val navigationClusterButtons: Set<AccessoryToolbarButton> = setOf(
            SHIFT,
            MOVE_UP,
            DELETE_BACKWARD,
            MOVE_LEFT,
            MOVE_DOWN,
            MOVE_RIGHT,
        )

        fun fromStorageName(value: String): AccessoryToolbarButton? =
            entries.firstOrNull { it.storageName == value }

        fun fromStorageNames(value: String): Set<AccessoryToolbarButton> =
            when (value) {
                "undo_redo" -> setOf(UNDO, REDO)
                else -> fromStorageName(value)?.let(::setOf) ?: emptySet()
            }
    }
}

enum class AccessoryToolbarButtonSize(val storageName: String, val displayTitle: String) {
    SMALL("small", "Small"),
    MEDIUM("medium", "Medium"),
    LARGE("large", "Large"),
    ;

    companion object {
        fun fromStorageName(value: String): AccessoryToolbarButtonSize? =
            entries.firstOrNull { it.storageName == value }
    }
}

enum class AccessoryToolbarContentMode(val storageName: String, val displayTitle: String) {
    ICON_AND_TEXT("icon_and_text", "Text + icon"),
    ICON_ONLY("icon_only", "Icon only"),
    TEXT_ONLY("text_only", "Text only"),
    ;

    companion object {
        fun fromStorageName(value: String): AccessoryToolbarContentMode? =
            entries.firstOrNull { it.storageName == value }
    }
}

enum class EditorFontFamily(val storageName: String, val displayTitle: String) {
    MONOSPACE("monospace", "Monospace"),
    SANS("sans", "Sans"),
    SERIF("serif", "Serif"),
    DEFAULT("default", "System"),
    ;

    companion object {
        fun fromStorageName(value: String): EditorFontFamily? =
            entries.firstOrNull { it.storageName == value }
    }
}

data class EditorDisplayOptions(
    val layoutMode: EditorLayoutMode = EditorLayoutMode.MOBILE,
    val fontSizeSp: Int = DEFAULT_FONT_SIZE_SP,
    val editorFontFamily: EditorFontFamily = EditorFontFamily.MONOSPACE,
    val wordWrap: Boolean = true,
    val lineNumbers: Boolean = true,
    val accessoryBar: Boolean = true,
    val accessoryToolbarRows: Int = DEFAULT_ACCESSORY_TOOLBAR_ROWS,
    val accessoryToolbarButtonSize: AccessoryToolbarButtonSize = AccessoryToolbarButtonSize.MEDIUM,
    val accessoryToolbarContentMode: AccessoryToolbarContentMode = AccessoryToolbarContentMode.ICON_AND_TEXT,
    val staticAccessoryButtons: Set<AccessoryToolbarButton> = DEFAULT_STATIC_ACCESSORY_BUTTONS,
    val hiddenAccessoryButtons: Set<AccessoryToolbarButton> = emptySet(),
) {
    fun withFontDelta(delta: Int): EditorDisplayOptions =
        copy(fontSizeSp = (fontSizeSp + delta).coerceIn(MIN_FONT_SIZE_SP, MAX_FONT_SIZE_SP))

    fun withAccessoryToolbarRowDelta(delta: Int): EditorDisplayOptions =
        withAccessoryToolbarRows(accessoryToolbarRows + delta)

    fun withAccessoryToolbarRows(rows: Int): EditorDisplayOptions =
        copy(accessoryToolbarRows = rows.coerceIn(MIN_ACCESSORY_TOOLBAR_ROWS, MAX_ACCESSORY_TOOLBAR_ROWS))

    fun toggledStaticAccessoryButton(button: AccessoryToolbarButton): EditorDisplayOptions =
        if (button in staticAccessoryButtons) {
            copy(staticAccessoryButtons = staticAccessoryButtons - button)
        } else {
            copy(
                staticAccessoryButtons = staticAccessoryButtons + button,
                hiddenAccessoryButtons = hiddenAccessoryButtons - button,
            )
        }

    fun toggledHiddenAccessoryButton(button: AccessoryToolbarButton): EditorDisplayOptions =
        if (button in hiddenAccessoryButtons) {
            copy(hiddenAccessoryButtons = hiddenAccessoryButtons - button)
        } else {
            copy(
                hiddenAccessoryButtons = hiddenAccessoryButtons + button,
                staticAccessoryButtons = staticAccessoryButtons - button,
            )
        }

    companion object {
        const val MIN_FONT_SIZE_SP = 11
        const val DEFAULT_FONT_SIZE_SP = 15
        const val MAX_FONT_SIZE_SP = 24
        const val MIN_ACCESSORY_TOOLBAR_ROWS = 1
        const val DEFAULT_ACCESSORY_TOOLBAR_ROWS = 2
        const val MAX_ACCESSORY_TOOLBAR_ROWS = 3
        val DEFAULT_STATIC_ACCESSORY_BUTTONS: Set<AccessoryToolbarButton> = setOf(
            AccessoryToolbarButton.SHIFT,
            AccessoryToolbarButton.MOVE_UP,
            AccessoryToolbarButton.DELETE_BACKWARD,
            AccessoryToolbarButton.UNDO,
            AccessoryToolbarButton.MOVE_LEFT,
            AccessoryToolbarButton.MOVE_DOWN,
            AccessoryToolbarButton.MOVE_RIGHT,
            AccessoryToolbarButton.REDO,
        )
        val LEGACY_DEFAULT_STATIC_ACCESSORY_BUTTONS: Set<AccessoryToolbarButton> = setOf(
            AccessoryToolbarButton.SHIFT,
            AccessoryToolbarButton.MOVE_UP,
            AccessoryToolbarButton.DELETE_BACKWARD,
            AccessoryToolbarButton.MOVE_LEFT,
            AccessoryToolbarButton.MOVE_DOWN,
            AccessoryToolbarButton.MOVE_RIGHT,
        )
    }
}

interface EditorPreferences {
    val displayOptions: StateFlow<EditorDisplayOptions>
    val layoutMode: StateFlow<EditorLayoutMode>
    fun setDisplayOptions(options: EditorDisplayOptions)
    fun setLayoutMode(mode: EditorLayoutMode)
}

class EditorPreferenceController(private val preferences: EditorPreferences) {
    val displayOptions: StateFlow<EditorDisplayOptions> = preferences.displayOptions
    val layoutMode: StateFlow<EditorLayoutMode> = preferences.layoutMode

    fun setDisplayOptions(options: EditorDisplayOptions) {
        preferences.setDisplayOptions(options)
    }

    fun setLayoutMode(mode: EditorLayoutMode) {
        preferences.setLayoutMode(mode)
    }

    fun toggleLayoutMode() {
        setLayoutMode(layoutMode.value.toggled())
    }

    fun adjustFontSize(delta: Int) {
        setDisplayOptions(displayOptions.value.withFontDelta(delta))
    }

    fun setEditorFontFamily(fontFamily: EditorFontFamily) {
        setDisplayOptions(displayOptions.value.copy(editorFontFamily = fontFamily))
    }

    fun toggleWordWrap() {
        setDisplayOptions(displayOptions.value.copy(wordWrap = !displayOptions.value.wordWrap))
    }

    fun toggleLineNumbers() {
        setDisplayOptions(displayOptions.value.copy(lineNumbers = !displayOptions.value.lineNumbers))
    }

    fun toggleAccessoryBar() {
        setDisplayOptions(displayOptions.value.copy(accessoryBar = !displayOptions.value.accessoryBar))
    }

    fun adjustToolbarRows(delta: Int) {
        setDisplayOptions(displayOptions.value.withAccessoryToolbarRowDelta(delta))
    }

    fun setToolbarButtonSize(size: AccessoryToolbarButtonSize) {
        setDisplayOptions(displayOptions.value.copy(accessoryToolbarButtonSize = size))
    }

    fun setToolbarContentMode(mode: AccessoryToolbarContentMode) {
        setDisplayOptions(displayOptions.value.copy(accessoryToolbarContentMode = mode))
    }

    fun toggleStaticAccessoryButton(button: AccessoryToolbarButton) {
        setDisplayOptions(displayOptions.value.toggledStaticAccessoryButton(button))
    }

    fun toggleHiddenAccessoryButton(button: AccessoryToolbarButton) {
        setDisplayOptions(displayOptions.value.toggledHiddenAccessoryButton(button))
    }
}

class InMemoryEditorPreferences(
    layoutMode: EditorLayoutMode = EditorLayoutMode.MOBILE,
) : EditorPreferences {
    private val _displayOptions = MutableStateFlow(EditorDisplayOptions(layoutMode = layoutMode))
    override val displayOptions: StateFlow<EditorDisplayOptions> = _displayOptions.asStateFlow()

    private val _layoutMode = MutableStateFlow(layoutMode)
    override val layoutMode: StateFlow<EditorLayoutMode> = _layoutMode.asStateFlow()

    override fun setDisplayOptions(options: EditorDisplayOptions) {
        _displayOptions.value = options
        _layoutMode.value = options.layoutMode
    }

    override fun setLayoutMode(mode: EditorLayoutMode) {
        setDisplayOptions(displayOptions.value.copy(layoutMode = mode))
    }
}

class AndroidEditorPreferences(context: Context) : EditorPreferences {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val legacyPrefs: SharedPreferences =
        context.getSharedPreferences(LEGACY_PREFS_NAME, Context.MODE_PRIVATE)

    private val _displayOptions = MutableStateFlow(decodeDisplayOptions())
    override val displayOptions: StateFlow<EditorDisplayOptions> = _displayOptions.asStateFlow()

    private val _layoutMode = MutableStateFlow(_displayOptions.value.layoutMode)
    override val layoutMode: StateFlow<EditorLayoutMode> = _layoutMode.asStateFlow()

    override fun setDisplayOptions(options: EditorDisplayOptions) {
        prefs.edit()
            .putString(KEY_LAYOUT_MODE, options.layoutMode.storageName)
            .putInt(KEY_FONT_SIZE_SP, options.fontSizeSp)
            .putString(KEY_EDITOR_FONT_FAMILY, options.editorFontFamily.storageName)
            .putBoolean(KEY_WORD_WRAP, options.wordWrap)
            .putBoolean(KEY_LINE_NUMBERS, options.lineNumbers)
            .putBoolean(KEY_ACCESSORY_BAR, options.accessoryBar)
            .putInt(KEY_ACCESSORY_TOOLBAR_ROWS, options.accessoryToolbarRows)
            .putString(KEY_ACCESSORY_TOOLBAR_BUTTON_SIZE, options.accessoryToolbarButtonSize.storageName)
            .putString(KEY_ACCESSORY_TOOLBAR_CONTENT_MODE, options.accessoryToolbarContentMode.storageName)
            .putString(KEY_STATIC_ACCESSORY_BUTTONS, encodeAccessoryButtons(options.staticAccessoryButtons))
            .putString(KEY_HIDDEN_ACCESSORY_BUTTONS, encodeAccessoryButtons(options.hiddenAccessoryButtons))
            .apply()
        _displayOptions.value = options
        _layoutMode.value = options.layoutMode
    }

    override fun setLayoutMode(mode: EditorLayoutMode) {
        setDisplayOptions(displayOptions.value.copy(layoutMode = mode))
    }

    private fun decodeDisplayOptions(): EditorDisplayOptions =
        EditorDisplayOptions(
            layoutMode = decodeLayoutMode(),
            fontSizeSp = intPreference(KEY_FONT_SIZE_SP, EditorDisplayOptions.DEFAULT_FONT_SIZE_SP)
                .coerceIn(EditorDisplayOptions.MIN_FONT_SIZE_SP, EditorDisplayOptions.MAX_FONT_SIZE_SP),
            editorFontFamily = stringPreference(KEY_EDITOR_FONT_FAMILY)
                ?.let(EditorFontFamily::fromStorageName)
                ?: EditorFontFamily.MONOSPACE,
            wordWrap = booleanPreference(KEY_WORD_WRAP, true),
            lineNumbers = booleanPreference(KEY_LINE_NUMBERS, true),
            accessoryBar = booleanPreference(KEY_ACCESSORY_BAR, true),
            accessoryToolbarRows = intPreference(
                KEY_ACCESSORY_TOOLBAR_ROWS,
                EditorDisplayOptions.DEFAULT_ACCESSORY_TOOLBAR_ROWS,
            ).coerceIn(
                EditorDisplayOptions.MIN_ACCESSORY_TOOLBAR_ROWS,
                EditorDisplayOptions.MAX_ACCESSORY_TOOLBAR_ROWS,
            ),
            accessoryToolbarButtonSize = stringPreference(KEY_ACCESSORY_TOOLBAR_BUTTON_SIZE)
                ?.let(AccessoryToolbarButtonSize::fromStorageName)
                ?: AccessoryToolbarButtonSize.MEDIUM,
            accessoryToolbarContentMode = stringPreference(KEY_ACCESSORY_TOOLBAR_CONTENT_MODE)
                ?.let(AccessoryToolbarContentMode::fromStorageName)
                ?: AccessoryToolbarContentMode.ICON_AND_TEXT,
            staticAccessoryButtons = decodeStaticAccessoryButtons(),
            hiddenAccessoryButtons = decodeAccessoryButtons(
                key = KEY_HIDDEN_ACCESSORY_BUTTONS,
                fallback = emptySet(),
            ),
        )

    private fun decodeLayoutMode(): EditorLayoutMode =
        stringPreference(KEY_LAYOUT_MODE)
            ?.let(EditorLayoutMode::fromStorageName)
            ?: EditorLayoutMode.MOBILE

    private fun decodeAccessoryButtons(
        key: String,
        fallback: Set<AccessoryToolbarButton>,
    ): Set<AccessoryToolbarButton> =
        stringPreference(key)
            ?.let(::decodeAccessoryButtonSet)
            ?: fallback

    private fun decodeStaticAccessoryButtons(): Set<AccessoryToolbarButton> {
        val decoded = decodeAccessoryButtons(
            key = KEY_STATIC_ACCESSORY_BUTTONS,
            fallback = EditorDisplayOptions.DEFAULT_STATIC_ACCESSORY_BUTTONS,
        )
        return if (decoded == EditorDisplayOptions.LEGACY_DEFAULT_STATIC_ACCESSORY_BUTTONS) {
            EditorDisplayOptions.DEFAULT_STATIC_ACCESSORY_BUTTONS
        } else {
            decoded
        }
    }

    private fun decodeAccessoryButtonSet(raw: String): Set<AccessoryToolbarButton> {
        if (raw.isBlank()) return emptySet()
        return raw.split(",")
            .flatMap { AccessoryToolbarButton.fromStorageNames(it.trim()) }
            .toSet()
    }

    private fun encodeAccessoryButtons(buttons: Set<AccessoryToolbarButton>): String =
        buttons.joinToString(",") { it.storageName }

    private fun stringPreference(key: String): String? =
        prefs.getString(key, null) ?: legacyPrefs.getString(legacyKey(key), null)

    private fun booleanPreference(key: String, defaultValue: Boolean): Boolean =
        if (prefs.contains(key)) prefs.getBoolean(key, defaultValue)
        else legacyPrefs.getBoolean(legacyKey(key), defaultValue)

    private fun intPreference(key: String, defaultValue: Int): Int =
        if (prefs.contains(key)) prefs.getInt(key, defaultValue)
        else legacyPrefs.getInt(legacyKey(key), defaultValue)

    private fun legacyKey(key: String): String =
        key.replaceFirst(PREFS_NAME, LEGACY_PREFS_NAME)

    companion object {
        private const val PREFS_NAME = "notepad3"
        private const val LEGACY_PREFS_NAME = "notepad3" + "pp"
        private const val KEY_LAYOUT_MODE = "notepad3.layoutMode"
        private const val KEY_FONT_SIZE_SP = "notepad3.fontSizeSp"
        private const val KEY_EDITOR_FONT_FAMILY = "notepad3.editorFontFamily"
        private const val KEY_WORD_WRAP = "notepad3.wordWrap"
        private const val KEY_LINE_NUMBERS = "notepad3.lineNumbers"
        private const val KEY_ACCESSORY_BAR = "notepad3.accessoryBar"
        private const val KEY_ACCESSORY_TOOLBAR_ROWS = "notepad3.accessoryToolbarRows"
        private const val KEY_ACCESSORY_TOOLBAR_BUTTON_SIZE = "notepad3.accessoryToolbarButtonSize"
        private const val KEY_ACCESSORY_TOOLBAR_CONTENT_MODE = "notepad3.accessoryToolbarContentMode"
        private const val KEY_STATIC_ACCESSORY_BUTTONS = "notepad3.staticAccessoryButtons"
        private const val KEY_HIDDEN_ACCESSORY_BUTTONS = "notepad3.hiddenAccessoryButtons"
    }
}
