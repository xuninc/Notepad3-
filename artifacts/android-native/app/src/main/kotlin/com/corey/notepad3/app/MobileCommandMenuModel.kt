package com.corey.notepad3.app

internal enum class MobileMenuSurface {
    TOP_QUICK,
    MENU_BAR,
}

internal data class MobileMenuSection(
    val title: String,
    val rows: List<MobileMenuRow>,
)

internal data class MobileMenuRow(
    val title: String,
)

internal data class ClassicSubmenuSpec(
    val title: String,
    val rows: List<MobileMenuRow>,
    val expandable: Boolean = rows.isNotEmpty(),
)

internal enum class PreferencesDestination(
    val title: String,
) {
    GENERAL("Preferences"),
    APPEARANCE("Appearance"),
    TOOLBAR("Toolbar"),
    EDITOR("Editor"),
}

internal data class KeyboardAccessoryToggleState(
    val label: String,
    val active: Boolean,
    val enabled: Boolean,
)

internal enum class AccessoryDeckPage(
    val title: String,
) {
    EDIT("Edit"),
    NAVIGATION("Nav"),
    NUMERIC("123"),
}

internal enum class AccessoryDeckActionId {
    OPEN_DOCUMENTS,
    ESCAPE,
    SHIFT,
    CTRL,
    ALT,
    ENTER,
    COPY,
    CUT,
    PASTE,
    PAGE_DOTS,
    BACKSPACE,
    UNDO,
    REDO,
    FIND,
    SELECT_WORD,
    SELECT_LINE,
    SELECT_ALL,
    INSERT_DATE,
    READ_MODE,
    COMPARE,
    MORE,
    HIDE_KEYBOARD,
    PRINT_SCREEN,
    SCROLL_LOCK,
    BREAK,
    HOME,
    INSERT,
    END,
    PAGE_UP,
    PAGE_DOWN,
    MOVE_LEFT,
    MOVE_UP,
    MOVE_DOWN,
    MOVE_RIGHT,
    SWITCH_DECK,
    TAB,
    INSERT_TEXT,
}

internal data class AccessoryDeckKeySpec(
    val id: AccessoryDeckActionId,
    val label: String,
    val insertText: String? = null,
    val repeatOnHold: Boolean = false,
    val columnSpan: Int = 1,
)

internal data class RepeatPressSpec(
    val initialDelayMillis: Long = 360L,
    val firstRepeatDelayMillis: Long = 170L,
    val minimumDelayMillis: Long = 32L,
    val accelerationNumerator: Long = 5L,
    val accelerationDenominator: Long = 6L,
)

internal val accessoryRepeatPressSpec = RepeatPressSpec()

internal fun keyboardAccessoryMoreSurface(): MobileMenuSurface =
    MobileMenuSurface.MENU_BAR

internal fun accessoryStaticButtonRepeats(label: String): Boolean =
    label in setOf("Up", "Down", "Left", "Right", "Delete", "Backspace", "Home", "End", "Pg Up", "Pg Dn")

internal fun accessoryDeckPages(): List<AccessoryDeckPage> =
    AccessoryDeckPage.entries

internal fun nextAccessoryDeckPage(page: AccessoryDeckPage): AccessoryDeckPage {
    val pages = accessoryDeckPages()
    val nextIndex = (pages.indexOf(page) + 1).floorMod(pages.size)
    return pages[nextIndex]
}

internal fun previousAccessoryDeckPage(page: AccessoryDeckPage): AccessoryDeckPage {
    val pages = accessoryDeckPages()
    val previousIndex = (pages.indexOf(page) - 1).floorMod(pages.size)
    return pages[previousIndex]
}

internal fun accessoryDeckColumnCount(page: AccessoryDeckPage): Int =
    if (page == AccessoryDeckPage.NUMERIC) 4 else 3

internal fun accessoryDeckRowCount(page: AccessoryDeckPage): Int =
    when (page) {
        AccessoryDeckPage.EDIT -> 4
        AccessoryDeckPage.NAVIGATION -> 4
        AccessoryDeckPage.NUMERIC -> 4
    }

internal fun accessoryDeckModifierStrip(): List<AccessoryDeckKeySpec> =
    listOf(
        AccessoryDeckKeySpec(AccessoryDeckActionId.OPEN_DOCUMENTS, "Windows"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.ESCAPE, "esc"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.SHIFT, "shift"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.CTRL, "ctrl"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.ALT, "alt"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.SWITCH_DECK, "Switch"),
    )

internal fun accessoryDeckLeftRail(): List<AccessoryDeckKeySpec> =
    listOf(
        AccessoryDeckKeySpec(AccessoryDeckActionId.COPY, "Copy"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.CUT, "Cut"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.PASTE, "Paste"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.PAGE_DOTS, "•••"),
    )

internal fun accessoryDeckRightRail(): List<AccessoryDeckKeySpec> =
    listOf(
        AccessoryDeckKeySpec(AccessoryDeckActionId.BACKSPACE, "Backspace", repeatOnHold = true),
        AccessoryDeckKeySpec(AccessoryDeckActionId.ENTER, "Enter", insertText = "\n"),
    )

internal fun accessoryDeckKeys(page: AccessoryDeckPage): List<AccessoryDeckKeySpec> =
    when (page) {
        AccessoryDeckPage.EDIT -> listOf(
            AccessoryDeckKeySpec(AccessoryDeckActionId.UNDO, "Undo"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.REDO, "Redo"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.FIND, "Find"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.SELECT_WORD, "Word"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.SELECT_LINE, "Line"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.SELECT_ALL, "All"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_DATE, "Date"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.OPEN_DOCUMENTS, "Open"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.READ_MODE, "Read"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.COMPARE, "Compare"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.MORE, "More"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.HIDE_KEYBOARD, "Hide"),
        )
        AccessoryDeckPage.NAVIGATION -> listOf(
            AccessoryDeckKeySpec(AccessoryDeckActionId.PRINT_SCREEN, "prt scn"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.SCROLL_LOCK, "scr lk"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.BREAK, "break"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.HOME, "Home", repeatOnHold = true),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT, "Insert"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.PAGE_UP, "Pg Up", repeatOnHold = true),
            AccessoryDeckKeySpec(AccessoryDeckActionId.END, "End", repeatOnHold = true),
            AccessoryDeckKeySpec(AccessoryDeckActionId.MOVE_UP, "Up", repeatOnHold = true),
            AccessoryDeckKeySpec(AccessoryDeckActionId.PAGE_DOWN, "Pg Dn", repeatOnHold = true),
            AccessoryDeckKeySpec(AccessoryDeckActionId.MOVE_LEFT, "Left", repeatOnHold = true),
            AccessoryDeckKeySpec(AccessoryDeckActionId.MOVE_DOWN, "Down", repeatOnHold = true),
            AccessoryDeckKeySpec(AccessoryDeckActionId.MOVE_RIGHT, "Right", repeatOnHold = true),
        )
        AccessoryDeckPage.NUMERIC -> listOf(
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "/", insertText = "/"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "7", insertText = "7"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "8", insertText = "8"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "9", insertText = "9"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "*", insertText = "*"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "4", insertText = "4"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "5", insertText = "5"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "6", insertText = "6"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "-", insertText = "-"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "1", insertText = "1"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "2", insertText = "2"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "3", insertText = "3"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "+", insertText = "+"),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, "0", insertText = "0", columnSpan = 2),
            AccessoryDeckKeySpec(AccessoryDeckActionId.INSERT_TEXT, ".", insertText = "."),
        )
    }

private fun Int.floorMod(divisor: Int): Int =
    ((this % divisor) + divisor) % divisor

internal fun repeatDelayForIteration(
    iteration: Int,
    spec: RepeatPressSpec = accessoryRepeatPressSpec,
): Long {
    var delay = spec.firstRepeatDelayMillis
    repeat(iteration.coerceAtLeast(0)) {
        delay = maxOf(
            spec.minimumDelayMillis,
            delay * spec.accelerationNumerator / spec.accelerationDenominator,
        )
    }
    return delay
}

internal fun keyboardAccessoryToggleState(
    keyboardSuppressed: Boolean,
    readOnly: Boolean,
): KeyboardAccessoryToggleState =
    KeyboardAccessoryToggleState(
        label = "Hide",
        active = keyboardSuppressed,
        enabled = !readOnly,
    )

internal fun shouldShowPersistentDocumentStrip(layoutMode: EditorLayoutMode): Boolean =
    layoutMode == EditorLayoutMode.CLASSIC

private const val DOCUMENT_TAB_MAX_TITLE_CHARS = 26
private const val DOCUMENT_TAB_MIN_WIDTH_DP = 86
private const val DOCUMENT_TAB_MAX_WIDTH_DP = 184

internal fun documentTabDisplayTitle(title: String): String {
    val cleaned = title.trim().ifBlank { "untitled.txt" }
    return if (cleaned.length <= DOCUMENT_TAB_MAX_TITLE_CHARS) {
        cleaned
    } else {
        cleaned.take(DOCUMENT_TAB_MAX_TITLE_CHARS - 3) + "..."
    }
}

internal fun documentTabWidthDp(title: String): Int {
    val visibleChars = minOf(documentTabDisplayTitle(title).length, DOCUMENT_TAB_MAX_TITLE_CHARS)
    return (23 + visibleChars * 7).coerceIn(DOCUMENT_TAB_MIN_WIDTH_DP, DOCUMENT_TAB_MAX_WIDTH_DP)
}

internal fun shouldShowSoftKeyboardOnEditorFocus(
    readOnly: Boolean,
    keyboardSuppressed: Boolean,
): Boolean =
    !readOnly && !keyboardSuppressed

internal fun mobileMenuSections(surface: MobileMenuSurface): List<MobileMenuSection> =
    when (surface) {
        MobileMenuSurface.TOP_QUICK -> topQuickMenuSections()
        MobileMenuSurface.MENU_BAR -> menuBarSections()
    }

internal fun classicSettingsSubmenus(): List<ClassicSubmenuSpec> =
    listOf(
        ClassicSubmenuSpec(
            title = "Appearance",
            rows = listOf(
                "Toolbar preferences...",
                "Themes",
            ).map(::MobileMenuRow),
        ),
    )

internal fun preferencesHomeRows(): List<MobileMenuRow> =
    listOf(
        MobileMenuRow("Appearance"),
        MobileMenuRow("Toolbar"),
        MobileMenuRow("Editor"),
    )

private fun topQuickMenuSections(): List<MobileMenuSection> =
    listOf(
        MobileMenuSection(
            title = "Quick actions",
            rows = listOf(
                "Preferences",
                "Compare documents",
                "Change language",
                "Go to line",
                "Virtual trackpad",
                "Preview markdown",
                "Read mode",
                "Zen mode",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "Line tools",
            rows = listOf(
                "Sort lines",
                "Trim trailing spaces",
                "Duplicate current line",
                "Delete current line",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "Document",
            rows = listOf(
                "Insert date/time",
                "Duplicate current doc",
                "Rename current doc",
                "Close current doc",
            ).map(::MobileMenuRow),
        ),
    )

private fun menuBarSections(): List<MobileMenuSection> =
    listOf(
        MobileMenuSection(
            title = "File",
            rows = listOf(
                "New blank",
                "Open documents",
                "Open from Files",
                "Save",
                "Duplicate current",
                "Rename current",
                "Close current",
                "Close others",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "Edit",
            rows = listOf(
                "Undo",
                "Redo",
                "Cut",
                "Copy",
                "Paste",
                "Select all",
                "Select word",
                "Select line",
                "Select paragraph",
                "Insert date/time",
                "Uppercase selection",
                "Lowercase selection",
                "Indent",
                "Unindent",
                "Toggle comment",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "Search",
            rows = listOf(
                "Find/Replace",
                "Go to line",
                "Compare documents",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "View",
            rows = listOf(
                "Read mode",
                "Zen mode",
                "Preview markdown",
                "Virtual trackpad",
                "Switch to classic layout",
                "Word wrap",
                "Line numbers",
                "Keyboard toolbar",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "Language",
            rows = listOf(
                "Plain text",
                "Markdown",
                "JSON",
                "HTML",
                "CSS",
                "JavaScript",
                "Kotlin",
                "Swift",
                "Python",
                "C++",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "Settings",
            rows = listOf(
                "Preferences",
                "Appearance preferences",
                "Toolbar preferences",
                "Cycle theme",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "Tools",
            rows = listOf(
                "Duplicate current line",
                "Delete current line",
                "Move line up",
                "Move line down",
                "Sort lines",
                "Trim trailing spaces",
                "Trim leading spaces",
                "Join selected lines",
                "Reverse lines",
                "Unique lines",
            ).map(::MobileMenuRow),
        ),
        MobileMenuSection(
            title = "Help",
            rows = listOf("About Notepad 3++").map(::MobileMenuRow),
        ),
    )
