package com.corey.notepad3.app

import android.app.Activity
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.os.Build
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.text.method.KeyListener
import android.util.TypedValue
import android.view.Gravity
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.filled.*
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.corey.notepad3.editor.EditResult
import com.corey.notepad3.editor.EditorCommands
import com.corey.notepad3.editor.EditorGutter
import com.corey.notepad3.editor.EditorHistory
import com.corey.notepad3.editor.EditorStatus
import com.corey.notepad3.editor.LineDiff
import com.corey.notepad3.editor.MarkdownBlock
import com.corey.notepad3.editor.MarkdownPreview
import com.corey.notepad3.editor.SearchOptions
import com.corey.notepad3.editor.TextSelection
import com.corey.notepad3.models.DocumentLanguage
import com.corey.notepad3.models.TextDocument
import com.corey.notepad3.persistence.DocumentStore
import com.corey.notepad3.theme.Palette
import com.corey.notepad3.theme.ThemeController
import com.corey.notepad3.theme.ThemeName
import com.corey.notepad3.theme.ThemePreference
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

@Composable
fun NotepadApp(
    store: DocumentStore,
    themeController: ThemeController,
    editorPreferenceController: EditorPreferenceController,
    modifier: Modifier = Modifier,
    onOpenFile: () -> Unit = {},
    onSaveFile: (TextDocument) -> Unit = {},
    onCloseApp: () -> Unit = {},
) {
    val snapshot by store.state.collectAsState()
    val palette by themeController.palette.collectAsState()
    val resolvedTheme by themeController.resolvedTheme.collectAsState()
    val layoutMode by editorPreferenceController.layoutMode.collectAsState()
    val displayOptions by editorPreferenceController.displayOptions.collectAsState()
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current
    val active = snapshot.documents.firstOrNull { it.id == snapshot.activeId } ?: snapshot.documents.first()
    val histories = remember { mutableStateMapOf<String, EditorHistory>() }
    val selections = remember { mutableStateMapOf<String, TextSelection>() }
    val history = histories.getOrPut(active.id) { EditorHistory(active.body) }
    val activeSelection = selections[active.id]?.clamped(active.body.length) ?: TextSelection(0)
    var historyVersion by remember { mutableStateOf(0) }
    var showDocuments by rememberSaveable { mutableStateOf(false) }
    var showFind by rememberSaveable { mutableStateOf(false) }
    var findQuery by rememberSaveable { mutableStateOf("") }
    var replacement by rememberSaveable { mutableStateOf("") }
    var findCaseSensitive by rememberSaveable { mutableStateOf(false) }
    var findWholeWord by rememberSaveable { mutableStateOf(false) }
    var findRegex by rememberSaveable { mutableStateOf(false) }
    var showGoto by rememberSaveable { mutableStateOf(false) }
    var gotoValue by rememberSaveable { mutableStateOf("") }
    var showLanguage by rememberSaveable { mutableStateOf(false) }
    var showRename by rememberSaveable { mutableStateOf(false) }
    var renameValue by rememberSaveable { mutableStateOf("") }
    var showAbout by rememberSaveable { mutableStateOf(false) }
    var previewMode by rememberSaveable { mutableStateOf(false) }
    var showCompare by rememberSaveable { mutableStateOf(false) }
    var compareTargetId by rememberSaveable { mutableStateOf<String?>(null) }
    var showMore by rememberSaveable { mutableStateOf(false) }
    var showPreferences by rememberSaveable { mutableStateOf(false) }
    var preferencesDestination by rememberSaveable { mutableStateOf(PreferencesDestination.GENERAL) }
    var showTrackpad by rememberSaveable { mutableStateOf(false) }
    var shiftAnchor by rememberSaveable { mutableStateOf<Int?>(null) }
    var readMode by rememberSaveable { mutableStateOf(false) }
    var zenMode by rememberSaveable { mutableStateOf(false) }
    var editorFocused by rememberSaveable { mutableStateOf(false) }
    var keyboardSuppressed by rememberSaveable { mutableStateOf(false) }
    var editorView by remember { mutableStateOf<EditorEditText?>(null) }
    val showingMarkdownPreview = previewMode && active.language == DocumentLanguage.MARKDOWN
    val searchOptions = SearchOptions(
        caseSensitive = findCaseSensitive,
        wholeWord = findWholeWord,
        regex = findRegex,
    )
    val canUndo = historyVersion.let { history.canUndo }
    val canRedo = historyVersion.let { history.canRedo }

    fun rememberSelection(selection: TextSelection) {
        selections[active.id] = selection
    }

    fun commitEdit(result: EditResult) {
        val safeSelection = result.selection.clamped(result.body.length)
        history.record(result.body)
        historyVersion += 1
        selections[active.id] = safeSelection
        shiftAnchor = null
        store.updateActive(body = result.body)
    }

    fun replaceBodyFromHistory(nextBody: String?) {
        if (nextBody == null) return
        historyVersion += 1
        val safeSelection = activeSelection.clamped(nextBody.length)
        selections[active.id] = safeSelection
        shiftAnchor = null
        store.updateActive(body = nextBody)
    }

    fun applyEditorSelectionImmediately(selection: TextSelection) {
        val editText = editorView ?: return
        val safeSelection = selection.clamped(editText.text?.length ?: active.body.length)
        if (keyboardSuppressed) {
            editText.focusWithoutSoftKeyboard()
        } else if (!editText.isFocused) {
            editText.requestFocus()
        }
        editText.post {
            val length = editText.text?.length ?: return@post
            val safeStart = safeSelection.start.coerceIn(0, length)
            val safeEnd = safeSelection.end.coerceIn(0, length)
            if (editText.selectionStart != safeStart || editText.selectionEnd != safeEnd) {
                editText.setSelection(safeStart, safeEnd)
            }
        }
    }

    fun insertDateTime() {
        val formatted = LocalDateTime.now().format(
            DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT).withLocale(Locale.getDefault()),
        )
        commitEdit(EditorCommands.insertText(active.body, activeSelection, formatted))
    }

    fun applySelection(selection: TextSelection) {
        val safeSelection = selection.clamped(active.body.length)
        selections[active.id] = safeSelection
        applyEditorSelectionImmediately(safeSelection)
        shiftAnchor = null
        showMore = false
    }

    fun toggleZenMode() {
        zenMode = !zenMode
        showMore = false
        if (zenMode) {
            showDocuments = false
            showFind = false
            showGoto = false
            showLanguage = false
            showCompare = false
        }
    }

    fun toggleDocumentsPanel() {
        showDocuments = !showDocuments
    }

    fun toggleFindPanel() {
        showFind = !showFind
    }

    fun toggleComparePanel() {
        showCompare = !showCompare
    }

    fun toggleMorePanel() {
        showMore = !showMore
    }

    fun openPreferencesPanel(destination: PreferencesDestination = PreferencesDestination.GENERAL) {
        preferencesDestination = destination
        showPreferences = true
        showMore = false
    }

    fun toggleLayoutMode() {
        editorPreferenceController.toggleLayoutMode()
        showMore = false
    }

    fun cycleTheme() {
        themeController.cycleEarlyThemes()
        showMore = false
    }

    fun undoEdit() {
        replaceBodyFromHistory(history.undo())
    }

    fun redoEdit() {
        replaceBodyFromHistory(history.redo())
    }

    fun startGotoLine() {
        gotoValue = activeSelection.lineNumberIn(active.body).toString()
        showGoto = true
        showMore = false
    }

    fun startRenameDocument() {
        renameValue = active.title
        showRename = true
        showMore = false
    }

    fun selectAllText() {
        applySelection(EditorCommands.selectAll(active.body))
    }

    fun duplicateLine() {
        if (!readMode) commitEdit(EditorCommands.duplicateCurrentLine(active.body, activeSelection.min))
    }

    fun deleteLine() {
        if (!readMode) commitEdit(EditorCommands.deleteCurrentLine(active.body, activeSelection.min))
    }

    fun deleteBackward() {
        if (!readMode) commitEdit(EditorCommands.deleteBackward(active.body, activeSelection))
    }

    fun trimSelection() {
        if (!readMode) commitEdit(EditorCommands.trimTrailingSpaces(active.body, activeSelection))
    }

    fun sortDocument() {
        if (!readMode) commitEdit(EditorCommands.sortLines(active.body))
    }

    fun selectWord() {
        applySelection(EditorCommands.selectWord(active.body, activeSelection.min))
    }

    fun selectLine() {
        applySelection(EditorCommands.selectLine(active.body, activeSelection.min))
    }

    fun selectParagraph() {
        applySelection(EditorCommands.selectParagraph(active.body, activeSelection.min))
    }

    fun copySelection() {
        val safeSelection = activeSelection.clamped(active.body.length)
        if (safeSelection.min == safeSelection.max) return
        clipboard.setText(AnnotatedString(active.body.substring(safeSelection.min, safeSelection.max)))
        showMore = false
    }

    fun cutSelection() {
        val safeSelection = activeSelection.clamped(active.body.length)
        if (readMode || safeSelection.min == safeSelection.max) return
        clipboard.setText(AnnotatedString(active.body.substring(safeSelection.min, safeSelection.max)))
        commitEdit(EditorCommands.insertText(active.body, safeSelection, ""))
        showMore = false
    }

    fun pasteFromClipboard() {
        if (readMode) return
        val text = clipboard.getText()?.text.orEmpty()
        if (text.isNotEmpty()) {
            commitEdit(EditorCommands.insertText(active.body, activeSelection, text))
        }
        showMore = false
    }

    fun toggleShiftSelection() {
        shiftAnchor = if (shiftAnchor == null) activeSelection.min else null
    }

    fun movingCursor(): Int =
        if (shiftAnchor != null) activeSelection.end.coerceIn(0, active.body.length) else activeSelection.min

    fun updateCursorSelection(nextCaret: Int) {
        val next = nextCaret.coerceIn(0, active.body.length)
        val anchor = shiftAnchor
        val nextSelection = if (anchor == null) TextSelection(next) else TextSelection(anchor, next)
        selections[active.id] = nextSelection
        applyEditorSelectionImmediately(nextSelection)
    }

    fun moveCursorBy(delta: Int) {
        updateCursorSelection(movingCursor() + delta)
    }

    fun moveCursorVertical(direction: Int) {
        val body = active.body
        val caret = movingCursor().coerceIn(0, body.length)
        val lineStart = body.lastIndexOf('\n', (caret - 1).coerceAtLeast(0)) + 1
        val column = caret - lineStart
        if (direction < 0) {
            if (lineStart == 0) {
                updateCursorSelection(0)
                return
            }
            val previousLineEnd = lineStart - 1
            val previousLineStart = body.lastIndexOf('\n', (previousLineEnd - 1).coerceAtLeast(0)) + 1
            updateCursorSelection((previousLineStart + column).coerceAtMost(previousLineEnd))
        } else {
            val lineEnd = body.indexOf('\n', caret)
            if (lineEnd < 0) {
                updateCursorSelection(body.length)
                return
            }
            val nextLineStart = lineEnd + 1
            val nextLineEnd = body.indexOf('\n', nextLineStart).takeIf { it >= 0 } ?: body.length
            updateCursorSelection((nextLineStart + column).coerceAtMost(nextLineEnd))
        }
    }

    fun moveCursorHome() {
        val body = active.body
        val caret = movingCursor().coerceIn(0, body.length)
        updateCursorSelection(body.lastIndexOf('\n', (caret - 1).coerceAtLeast(0)) + 1)
    }

    fun moveCursorEnd() {
        val body = active.body
        val caret = movingCursor().coerceIn(0, body.length)
        updateCursorSelection(body.indexOf('\n', caret).takeIf { it >= 0 } ?: body.length)
    }

    fun moveCursorPage(direction: Int) {
        moveCursorBy(direction * 80)
    }

    fun insertAccessoryText(text: String) {
        if (!readMode) {
            commitEdit(EditorCommands.insertText(active.body, activeSelection, text))
        }
    }

    fun toggleReadMode() {
        val nextReadMode = !readMode
        readMode = nextReadMode
        if (nextReadMode) {
            keyboardSuppressed = true
            context.hideSoftKeyboard()
        }
        showMore = false
    }

    fun togglePreviewMode() {
        if (active.language == DocumentLanguage.MARKDOWN) {
            previewMode = !previewMode
        }
        showMore = false
    }

    fun toggleTrackpad() {
        showTrackpad = !showTrackpad
        showMore = false
    }

    fun setTheme(name: ThemeName) {
        themeController.setThemePreference(ThemePreference.Named(name))
        showMore = false
    }

    fun switchToClassic() {
        editorPreferenceController.setLayoutMode(EditorLayoutMode.CLASSIC)
        showMore = false
    }

    fun switchToMobile() {
        editorPreferenceController.setLayoutMode(EditorLayoutMode.MOBILE)
        showMore = false
    }

    fun toggleKeyboardSuppression() {
        if (readMode) return
        if (keyboardSuppressed) {
            keyboardSuppressed = false
            editorView?.showSoftKeyboard(force = true)
        } else {
            keyboardSuppressed = true
            editorView?.focusWithoutSoftKeyboard()
            context.hideSoftKeyboard()
        }
        showMore = false
    }

    fun showAboutPanel() {
        showAbout = true
        showMore = false
    }

    fun setDocumentLanguage(language: DocumentLanguage) {
        store.updateActive(language = language)
        showLanguage = false
        showMore = false
        if (language != DocumentLanguage.MARKDOWN) {
            previewMode = false
        }
    }

    if (zenMode) {
        BackHandler {
            zenMode = false
        }
    }

    MaterialTheme {
        Surface(
            modifier = modifier
                .fillMaxSize()
                .background(palette.background.toColor()),
            color = palette.background.toColor(),
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize(),
                ) {
                if (!zenMode) {
                    WindowBar(
                        document = active,
                        palette = palette,
                        layoutMode = layoutMode,
                        activeTheme = resolvedTheme,
                        activeLanguage = active.language,
                        displayOptions = displayOptions,
                        compareEnabled = snapshot.documents.size > 1,
                        compareActive = showCompare,
                        canUndo = canUndo,
                        canRedo = canRedo,
                        readOnly = readMode,
                        zenMode = zenMode,
                        previewEnabled = active.language == DocumentLanguage.MARKDOWN,
                        previewActive = showingMarkdownPreview,
                        trackpadActive = showTrackpad,
                        commentEnabled = active.language.lineCommentPrefix != null,
                        onCycleTheme = ::cycleTheme,
                        onThemeSelect = ::setTheme,
                        onOpenDocuments = ::toggleDocumentsPanel,
                        onOpenFile = onOpenFile,
                        onSave = { onSaveFile(active) },
                        onFind = ::toggleFindPanel,
                        onCompare = ::toggleComparePanel,
                        onMore = ::toggleMorePanel,
                        onPreferences = { openPreferencesPanel() },
                        onAppearancePreferences = { openPreferencesPanel(PreferencesDestination.APPEARANCE) },
                        onToolbarPreferences = { openPreferencesPanel(PreferencesDestination.TOOLBAR) },
                        onShowAbout = ::showAboutPanel,
                        onToggleWordWrap = editorPreferenceController::toggleWordWrap,
                        onToggleLineNumbers = editorPreferenceController::toggleLineNumbers,
                        onToggleAccessoryBar = editorPreferenceController::toggleAccessoryBar,
                        onNew = store::createBlank,
                        onDuplicateDocument = store::duplicateActive,
                        onCloseDocument = { store.close(active.id) },
                        onCloseOthers = { store.closeOthers(active.id) },
                        onUndo = ::undoEdit,
                        onRedo = ::redoEdit,
                        onCut = ::cutSelection,
                        onCopy = ::copySelection,
                        onPaste = ::pasteFromClipboard,
                        onGotoLine = ::startGotoLine,
                        onChangeLanguage = {
                            showLanguage = true
                            showMore = false
                        },
                        onLanguageSelect = ::setDocumentLanguage,
                        onSelectAll = ::selectAllText,
                        onSelectWord = ::selectWord,
                        onSelectLine = ::selectLine,
                        onSelectParagraph = ::selectParagraph,
                        onInsertDateTime = ::insertDateTime,
                        onDuplicateLine = ::duplicateLine,
                        onDeleteLine = ::deleteLine,
                        onTrim = ::trimSelection,
                        onSort = ::sortDocument,
                        onRenameDocument = ::startRenameDocument,
                        onUppercase = {
                            commitEdit(EditorCommands.uppercaseSelection(active.body, activeSelection))
                        },
                        onLowercase = {
                            commitEdit(EditorCommands.lowercaseSelection(active.body, activeSelection))
                        },
                        onIndent = {
                            commitEdit(EditorCommands.indentSelection(active.body, activeSelection))
                        },
                        onUnindent = {
                            commitEdit(EditorCommands.unindentSelection(active.body, activeSelection))
                        },
                        onToggleComment = {
                            active.language.lineCommentPrefix?.let { prefix ->
                                commitEdit(EditorCommands.toggleLineComment(active.body, activeSelection, prefix))
                            }
                        },
                        onMoveLineUp = {
                            commitEdit(EditorCommands.moveCurrentLineUp(active.body, activeSelection.min))
                        },
                        onMoveLineDown = {
                            commitEdit(EditorCommands.moveCurrentLineDown(active.body, activeSelection.min))
                        },
                        onTrimLeading = {
                            commitEdit(EditorCommands.trimLeadingSpaces(active.body, activeSelection))
                        },
                        onJoinLines = {
                            commitEdit(EditorCommands.joinSelectedLines(active.body, activeSelection))
                        },
                        onReverseLines = {
                            commitEdit(EditorCommands.reverseLines(active.body))
                        },
                        onRemoveDuplicateLines = {
                            commitEdit(EditorCommands.removeDuplicateLines(active.body))
                        },
                        onTogglePreview = ::togglePreviewMode,
                        onToggleTrackpad = ::toggleTrackpad,
                        onToggleReadMode = ::toggleReadMode,
                        onToggleZenMode = ::toggleZenMode,
                        onSwitchToClassic = ::switchToClassic,
                        onSwitchToMobile = ::switchToMobile,
                        onCloseApp = onCloseApp,
                    )
                    if (shouldShowPersistentDocumentStrip(layoutMode)) {
                        Spacer(Modifier.height(if (layoutMode == EditorLayoutMode.CLASSIC) 0.dp else 4.dp))
                        DocumentStrip(
                            documents = snapshot.documents,
                            activeId = snapshot.activeId,
                            palette = palette,
                            onSelect = store::setActive,
                            onClose = store::close,
                        )
                    }
                    if (showDocuments) {
                        Spacer(Modifier.height(8.dp))
                        OpenDocumentsPanel(
                            documents = snapshot.documents,
                            activeId = snapshot.activeId,
                            palette = palette,
                            onSelect = {
                                store.setActive(it)
                                showDocuments = false
                            },
                            onNew = store::createBlank,
                            onOpenFile = onOpenFile,
                            onClose = store::close,
                        )
                    }
                    if (showFind) {
                        Spacer(Modifier.height(8.dp))
                        FindPanel(
                            document = active,
                            query = findQuery,
                            replacement = replacement,
                            options = searchOptions,
                            palette = palette,
                            replaceEnabled = !readMode,
                            onQueryChange = { findQuery = it },
                            onReplacementChange = { replacement = it },
                            onToggleCaseSensitive = { findCaseSensitive = !findCaseSensitive },
                            onToggleWholeWord = { findWholeWord = !findWholeWord },
                            onToggleRegex = { findRegex = !findRegex },
                            onNext = {
                                EditorCommands.findNext(active.body, findQuery, activeSelection, searchOptions)
                                    ?.let { selections[active.id] = it }
                            },
                            onPrevious = {
                                EditorCommands.findPrevious(active.body, findQuery, activeSelection, searchOptions)
                                    ?.let { selections[active.id] = it }
                            },
                            onReplaceCurrent = {
                                if (!readMode) {
                                    commitEdit(
                                        EditorCommands.replaceCurrent(
                                            body = active.body,
                                            query = findQuery,
                                            replacement = replacement,
                                            selection = activeSelection,
                                            options = searchOptions,
                                        ),
                                    )
                                }
                            },
                            onReplaceAll = {
                                if (!readMode) {
                                    commitEdit(EditorCommands.replaceAll(active.body, findQuery, replacement, searchOptions))
                                }
                            },
                        )
                    }
                    if (showGoto) {
                        Spacer(Modifier.height(8.dp))
                        GotoPanel(
                            document = active,
                            value = gotoValue,
                            palette = palette,
                            onValueChange = { gotoValue = it.filter(Char::isDigit) },
                            onGo = {
                                gotoValue.toIntOrNull()?.let {
                                    selections[active.id] = EditorCommands.gotoLine(active.body, it)
                                    showGoto = false
                                }
                            },
                            onCancel = { showGoto = false },
                        )
                    }
                    if (showLanguage) {
                        Spacer(Modifier.height(8.dp))
                        LanguagePanel(
                            current = active.language,
                            palette = palette,
                            onSelect = {
                                setDocumentLanguage(it)
                            },
                            onCancel = { showLanguage = false },
                        )
                    }
                    if (showRename) {
                        Spacer(Modifier.height(8.dp))
                        RenamePanel(
                            value = renameValue,
                            palette = palette,
                            onValueChange = { renameValue = it },
                            onSave = {
                                val next = renameValue.trim()
                                if (next.isNotEmpty()) {
                                    store.rename(active.id, next)
                                    showRename = false
                                }
                            },
                            onCancel = { showRename = false },
                        )
                    }
                    if (showAbout) {
                        Spacer(Modifier.height(8.dp))
                        AboutPanel(
                            palette = palette,
                            onDismiss = { showAbout = false },
                        )
                    }
                    if (showCompare) {
                        Spacer(Modifier.height(8.dp))
                        val compareTarget = chooseCompareTarget(
                            activeId = snapshot.activeId,
                            documents = snapshot.documents,
                            previousTargetId = compareTargetId,
                        )
                        ComparePanel(
                            active = active,
                            documents = snapshot.documents,
                            target = compareTarget,
                            palette = palette,
                            onTargetSelect = { compareTargetId = it },
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                }
                if (showingMarkdownPreview) {
                    MarkdownPreviewPane(document = active, palette = palette, modifier = Modifier.weight(1f))
                } else {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                    ) {
                        EditorTextArea(
                            document = active,
                            palette = palette,
                            selection = activeSelection,
                            readOnly = readMode,
                            fontSizeSp = displayOptions.fontSizeSp,
                            wordWrap = displayOptions.wordWrap,
                            showLineNumbers = layoutMode == EditorLayoutMode.CLASSIC && displayOptions.lineNumbers,
                            keyboardSuppressed = keyboardSuppressed,
                            onSelectionChange = ::rememberSelection,
                            onFocusChange = {
                                editorFocused = it
                            },
                            onEditorReady = { editorView = it },
                            onBodyChange = { next, nextSelection ->
                                if (!readMode) {
                                    selections[active.id] = nextSelection
                                    history.recordUserEdit(next)
                                    historyVersion += 1
                                    store.updateActive(body = next)
                                }
                            },
                            modifier = Modifier.fillMaxSize(),
                        )
                        if (layoutMode == EditorLayoutMode.MOBILE && !zenMode && !editorFocused) {
                            FloatingActionButton(
                                onClick = store::createBlank,
                                containerColor = palette.primary.toColor(),
                                contentColor = palette.primaryForeground.toColor(),
                                modifier = Modifier
                                    .align(Alignment.BottomEnd)
                                    .padding(18.dp),
                            ) {
                                Icon(Icons.Filled.Add, contentDescription = "New document")
                            }
                        }
                        if (layoutMode == EditorLayoutMode.MOBILE && showTrackpad) {
                            TrackpadPanel(
                                palette = palette,
                                onMoveLeft = { moveCursorBy(-1) },
                                onMoveUp = { moveCursorVertical(-1) },
                                onMoveDown = { moveCursorVertical(1) },
                                onMoveRight = { moveCursorBy(1) },
                                onHide = { showTrackpad = false },
                                modifier = Modifier
                                    .align(Alignment.BottomEnd)
                                    .padding(16.dp),
                            )
                        }
                    }
                }
                if (!zenMode) {
                    Spacer(Modifier.height(if (layoutMode == EditorLayoutMode.CLASSIC) 0.dp else 4.dp))
                    StatusBar(document = active, selection = activeSelection, readOnly = readMode, palette = palette)
                    Spacer(Modifier.height(if (layoutMode == EditorLayoutMode.CLASSIC) 0.dp else 4.dp))
                    if (displayOptions.accessoryBar) {
                        MobileKeyboardAccessory(
                            palette = palette,
                            displayOptions = displayOptions,
                            canUndo = canUndo,
                            canRedo = canRedo,
                            canCut = activeSelection.min != activeSelection.max && !readMode,
                            canPaste = !readMode,
                            readOnly = readMode,
                            shiftActive = shiftAnchor != null,
                            keyboardSuppressed = keyboardSuppressed,
                            findActive = showFind,
                            compareEnabled = snapshot.documents.size > 1,
                            compareActive = showCompare,
                            onToggleKeyboardSuppression = ::toggleKeyboardSuppression,
                            onReadToggle = ::toggleReadMode,
                            onUndo = ::undoEdit,
                            onRedo = ::redoEdit,
                            onCut = ::cutSelection,
                            onCopy = ::copySelection,
                            onPaste = ::pasteFromClipboard,
                            onShiftToggle = ::toggleShiftSelection,
                            onDeleteBackward = ::deleteBackward,
                            onMoveLeft = { moveCursorBy(-1) },
                            onMoveUp = { moveCursorVertical(-1) },
                            onMoveDown = { moveCursorVertical(1) },
                            onMoveRight = { moveCursorBy(1) },
                            onMoveHome = ::moveCursorHome,
                            onMoveEnd = ::moveCursorEnd,
                            onPageUp = { moveCursorPage(-1) },
                            onPageDown = { moveCursorPage(1) },
                            onFind = ::toggleFindPanel,
                            onInsertDateTime = ::insertDateTime,
                            onInsertText = ::insertAccessoryText,
                            onOpenDocuments = ::toggleDocumentsPanel,
                            onSelectAll = ::selectAllText,
                            onSelectWord = ::selectWord,
                            onSelectLine = ::selectLine,
                            onCompare = ::toggleComparePanel,
                            onMore = ::toggleMorePanel,
                        )
                        Spacer(Modifier.height(2.dp))
                    }
                    if (layoutMode == EditorLayoutMode.MOBILE && !editorFocused && !keyboardSuppressed) {
                        MobileBottomBar(
                            palette = palette,
                            compareEnabled = snapshot.documents.size > 1,
                            compareActive = showCompare,
                            findActive = showFind,
                            onOpen = ::toggleDocumentsPanel,
                            onFind = ::toggleFindPanel,
                            onCompare = ::toggleComparePanel,
                            onSwitchToClassic = ::switchToClassic,
                            onMore = ::toggleMorePanel,
                        )
                    }
                }
                }
                if (showMore) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = 0.16f))
                            .clickable { showMore = false },
                    )
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.BottomCenter,
                    ) {
                        MorePanel(
                            palette = palette,
                            canUndo = historyVersion.let { history.canUndo },
                            canRedo = historyVersion.let { history.canRedo },
                            readMode = readMode,
                            zenMode = zenMode,
                            layoutMode = layoutMode,
                            activeLanguage = active.language,
                            displayOptions = displayOptions,
                            trackpadActive = showTrackpad,
                            onDismiss = { showMore = false },
                            onNew = {
                                store.createBlank()
                                showMore = false
                            },
                            onOpenDocuments = {
                                showDocuments = true
                                showMore = false
                            },
                            onOpenFile = {
                                onOpenFile()
                                showMore = false
                            },
                            onSave = {
                                onSaveFile(active)
                                showMore = false
                            },
                            onDuplicateDocument = {
                                store.duplicateActive()
                                showMore = false
                            },
                            onRenameDocument = ::startRenameDocument,
                            onCloseDocument = {
                                store.close(active.id)
                                showMore = false
                            },
                            onCloseOthers = {
                                store.closeOthers(active.id)
                                showMore = false
                            },
                            onUndo = ::undoEdit,
                            onRedo = ::redoEdit,
                            onCut = ::cutSelection,
                            onCopy = ::copySelection,
                            onPaste = ::pasteFromClipboard,
                            onFind = ::toggleFindPanel,
                            onInsertDateTime = ::insertDateTime,
                            onGotoLine = ::startGotoLine,
                            onCompare = ::toggleComparePanel,
                            onSelectAll = ::selectAllText,
                            onSelectWord = ::selectWord,
                            onSelectLine = ::selectLine,
                            onSelectParagraph = ::selectParagraph,
                            onUppercase = {
                                commitEdit(EditorCommands.uppercaseSelection(active.body, activeSelection))
                            },
                            onLowercase = {
                                commitEdit(EditorCommands.lowercaseSelection(active.body, activeSelection))
                            },
                            onIndent = {
                                commitEdit(EditorCommands.indentSelection(active.body, activeSelection))
                            },
                            onUnindent = {
                                commitEdit(EditorCommands.unindentSelection(active.body, activeSelection))
                            },
                            onToggleComment = {
                                active.language.lineCommentPrefix?.let { prefix ->
                                    commitEdit(EditorCommands.toggleLineComment(active.body, activeSelection, prefix))
                                }
                            },
                            onMoveLineUp = {
                                commitEdit(EditorCommands.moveCurrentLineUp(active.body, activeSelection.min))
                            },
                            onMoveLineDown = {
                                commitEdit(EditorCommands.moveCurrentLineDown(active.body, activeSelection.min))
                            },
                            onTrim = ::trimSelection,
                            onTrimLeading = {
                                commitEdit(EditorCommands.trimLeadingSpaces(active.body, activeSelection))
                            },
                            onJoinLines = {
                                commitEdit(EditorCommands.joinSelectedLines(active.body, activeSelection))
                            },
                            onReverseLines = {
                                commitEdit(EditorCommands.reverseLines(active.body))
                            },
                            onRemoveDuplicateLines = {
                                commitEdit(EditorCommands.removeDuplicateLines(active.body))
                            },
                            onSort = ::sortDocument,
                            onDuplicateLine = ::duplicateLine,
                            onDeleteLine = ::deleteLine,
                            onLanguageSelect = ::setDocumentLanguage,
                            commentEnabled = active.language.lineCommentPrefix != null,
                            previewEnabled = active.language == DocumentLanguage.MARKDOWN,
                            previewActive = showingMarkdownPreview,
                            onTogglePreview = ::togglePreviewMode,
                            onToggleReadMode = ::toggleReadMode,
                            onToggleZenMode = ::toggleZenMode,
                            onToggleLayoutMode = ::toggleLayoutMode,
                            onToggleTrackpad = ::toggleTrackpad,
                            onFontSizeDown = { editorPreferenceController.adjustFontSize(-1) },
                            onFontSizeUp = { editorPreferenceController.adjustFontSize(1) },
                            onToggleWordWrap = {
                                editorPreferenceController.toggleWordWrap()
                                showMore = false
                            },
                            onToggleLineNumbers = {
                                editorPreferenceController.toggleLineNumbers()
                                showMore = false
                            },
                            onToggleAccessoryBar = {
                                editorPreferenceController.toggleAccessoryBar()
                                showMore = false
                            },
                            onCycleTheme = ::cycleTheme,
                            onPreferences = { openPreferencesPanel() },
                            onAppearancePreferences = { openPreferencesPanel(PreferencesDestination.APPEARANCE) },
                            onToolbarPreferences = { openPreferencesPanel(PreferencesDestination.TOOLBAR) },
                            onShowAbout = ::showAboutPanel,
                            modifier = Modifier.padding(8.dp),
                        )
                    }
                }
                if (showPreferences) {
                    PreferencesPage(
                        palette = palette,
                        destination = preferencesDestination,
                        activeTheme = resolvedTheme,
                        layoutMode = layoutMode,
                        displayOptions = displayOptions,
                        onDismiss = { showPreferences = false },
                        onNavigate = { preferencesDestination = it },
                        onThemeSelect = ::setTheme,
                        onSetLayoutMode = editorPreferenceController::setLayoutMode,
                        onToggleWordWrap = editorPreferenceController::toggleWordWrap,
                        onToggleLineNumbers = editorPreferenceController::toggleLineNumbers,
                        onToggleAccessoryBar = editorPreferenceController::toggleAccessoryBar,
                        onToolbarRowsDown = { editorPreferenceController.adjustToolbarRows(-1) },
                        onToolbarRowsUp = { editorPreferenceController.adjustToolbarRows(1) },
                        onToolbarButtonSizeSelect = editorPreferenceController::setToolbarButtonSize,
                        onToolbarContentModeSelect = editorPreferenceController::setToolbarContentMode,
                        onToggleStaticAccessoryButton = editorPreferenceController::toggleStaticAccessoryButton,
                        onToggleHiddenAccessoryButton = editorPreferenceController::toggleHiddenAccessoryButton,
                        onFontSizeDown = { editorPreferenceController.adjustFontSize(-1) },
                        onFontSizeUp = { editorPreferenceController.adjustFontSize(1) },
                    )
                }
            }
        }
    }
}
@Composable
private fun WindowBar(
    document: TextDocument,
    palette: Palette,
    layoutMode: EditorLayoutMode,
    activeTheme: ThemeName,
    activeLanguage: DocumentLanguage,
    displayOptions: EditorDisplayOptions,
    compareEnabled: Boolean,
    compareActive: Boolean,
    canUndo: Boolean,
    canRedo: Boolean,
    readOnly: Boolean,
    zenMode: Boolean,
    previewEnabled: Boolean,
    previewActive: Boolean,
    trackpadActive: Boolean,
    commentEnabled: Boolean,
    onCycleTheme: () -> Unit,
    onThemeSelect: (ThemeName) -> Unit,
    onOpenDocuments: () -> Unit,
    onOpenFile: () -> Unit,
    onSave: () -> Unit,
    onFind: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
    onPreferences: () -> Unit,
    onAppearancePreferences: () -> Unit,
    onToolbarPreferences: () -> Unit,
    onShowAbout: () -> Unit,
    onToggleWordWrap: () -> Unit,
    onToggleLineNumbers: () -> Unit,
    onToggleAccessoryBar: () -> Unit,
    onNew: () -> Unit,
    onDuplicateDocument: () -> Unit,
    onCloseDocument: () -> Unit,
    onCloseOthers: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onCut: () -> Unit,
    onCopy: () -> Unit,
    onPaste: () -> Unit,
    onGotoLine: () -> Unit,
    onChangeLanguage: () -> Unit,
    onLanguageSelect: (DocumentLanguage) -> Unit,
    onSelectAll: () -> Unit,
    onSelectWord: () -> Unit,
    onSelectLine: () -> Unit,
    onSelectParagraph: () -> Unit,
    onInsertDateTime: () -> Unit,
    onDuplicateLine: () -> Unit,
    onDeleteLine: () -> Unit,
    onTrim: () -> Unit,
    onSort: () -> Unit,
    onRenameDocument: () -> Unit,
    onUppercase: () -> Unit,
    onLowercase: () -> Unit,
    onIndent: () -> Unit,
    onUnindent: () -> Unit,
    onToggleComment: () -> Unit,
    onMoveLineUp: () -> Unit,
    onMoveLineDown: () -> Unit,
    onTrimLeading: () -> Unit,
    onJoinLines: () -> Unit,
    onReverseLines: () -> Unit,
    onRemoveDuplicateLines: () -> Unit,
    onTogglePreview: () -> Unit,
    onToggleTrackpad: () -> Unit,
    onToggleReadMode: () -> Unit,
    onToggleZenMode: () -> Unit,
    onSwitchToClassic: () -> Unit,
    onSwitchToMobile: () -> Unit,
    onCloseApp: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(if (layoutMode == EditorLayoutMode.CLASSIC) 0.dp else 4.dp)) {
        if (layoutMode == EditorLayoutMode.CLASSIC) {
            ClassicCaptionBar(document = document, palette = palette, onCloseApp = onCloseApp)
            ClassicMenuBar(
                palette = palette,
                activeTheme = activeTheme,
                activeLanguage = activeLanguage,
                displayOptions = displayOptions,
                compareEnabled = compareEnabled,
                compareActive = compareActive,
                canUndo = canUndo,
                canRedo = canRedo,
                readOnly = readOnly,
                zenMode = zenMode,
                previewEnabled = previewEnabled,
                previewActive = previewActive,
                trackpadActive = trackpadActive,
                commentEnabled = commentEnabled,
                onNew = onNew,
                onOpenFile = onOpenFile,
                onSave = onSave,
                onOpenDocuments = onOpenDocuments,
                onDuplicateDocument = onDuplicateDocument,
                onRenameDocument = onRenameDocument,
                onCloseDocument = onCloseDocument,
                onCloseOthers = onCloseOthers,
                onUndo = onUndo,
                onRedo = onRedo,
                onCut = onCut,
                onCopy = onCopy,
                onPaste = onPaste,
                onSelectAll = onSelectAll,
                onSelectWord = onSelectWord,
                onSelectLine = onSelectLine,
                onSelectParagraph = onSelectParagraph,
                onFind = onFind,
                onGotoLine = onGotoLine,
                onInsertDateTime = onInsertDateTime,
                onDuplicateLine = onDuplicateLine,
                onDeleteLine = onDeleteLine,
                onTrim = onTrim,
                onSort = onSort,
                onUppercase = onUppercase,
                onLowercase = onLowercase,
                onIndent = onIndent,
                onUnindent = onUnindent,
                onToggleComment = onToggleComment,
                onMoveLineUp = onMoveLineUp,
                onMoveLineDown = onMoveLineDown,
                onTrimLeading = onTrimLeading,
                onJoinLines = onJoinLines,
                onReverseLines = onReverseLines,
                onRemoveDuplicateLines = onRemoveDuplicateLines,
                onCompare = onCompare,
                onPreferences = onPreferences,
                onAppearancePreferences = onAppearancePreferences,
                onToolbarPreferences = onToolbarPreferences,
                onShowAbout = onShowAbout,
                onThemeSelect = onThemeSelect,
                onCycleTheme = onCycleTheme,
                onLanguageSelect = onLanguageSelect,
                onTogglePreview = onTogglePreview,
                onToggleTrackpad = onToggleTrackpad,
                onToggleWordWrap = onToggleWordWrap,
                onToggleLineNumbers = onToggleLineNumbers,
                onToggleAccessoryBar = onToggleAccessoryBar,
                onToggleReadMode = onToggleReadMode,
                onToggleZenMode = onToggleZenMode,
                onSwitchToMobile = onSwitchToMobile,
            )
            ClassicToolRack(
                palette = palette,
                compareEnabled = compareEnabled,
                compareActive = compareActive,
                canUndo = canUndo,
                canRedo = canRedo,
                readOnly = readOnly,
                onNew = onNew,
                onOpen = onOpenDocuments,
                onOpenFile = onOpenFile,
                onSave = onSave,
                onDuplicateDocument = onDuplicateDocument,
                onCut = onCut,
                onCopy = onCopy,
                onPaste = onPaste,
                onFind = onFind,
                onCompare = onCompare,
                onMore = onMore,
                onPreferences = onPreferences,
                onCycleTheme = onCycleTheme,
                onUndo = onUndo,
                onRedo = onRedo,
                onGotoLine = onGotoLine,
                onSelectAll = onSelectAll,
                onSelectLine = onSelectLine,
                onSelectParagraph = onSelectParagraph,
                onInsertDateTime = onInsertDateTime,
                onDuplicateLine = onDuplicateLine,
                onDeleteLine = onDeleteLine,
                onTrim = onTrim,
                onSort = onSort,
                onToggleReadMode = onToggleReadMode,
                onToggleZenMode = onToggleZenMode,
            )
        } else {
            MobileTitleBar(
                document = document,
                palette = palette,
                onNew = onNew,
                onOpenDocuments = onOpenDocuments,
                onFind = onFind,
                onCycleTheme = onCycleTheme,
                onMore = onMore,
                onPreferences = onPreferences,
                compareEnabled = compareEnabled,
                readOnly = readOnly,
                zenMode = zenMode,
                previewEnabled = previewEnabled,
                previewActive = previewActive,
                trackpadActive = trackpadActive,
                onCompare = onCompare,
                onChangeLanguage = onChangeLanguage,
                onGotoLine = onGotoLine,
                onToggleTrackpad = onToggleTrackpad,
                onTogglePreview = onTogglePreview,
                onToggleReadMode = onToggleReadMode,
                onToggleZenMode = onToggleZenMode,
                onSwitchToClassic = onSwitchToClassic,
                onSort = onSort,
                onTrim = onTrim,
                onDuplicateLine = onDuplicateLine,
                onDeleteLine = onDeleteLine,
                onInsertDateTime = onInsertDateTime,
                onDuplicateDocument = onDuplicateDocument,
                onRenameDocument = onRenameDocument,
                onCloseDocument = onCloseDocument,
            )
        }
    }
}

@Composable
private fun MobileTitleBar(
    document: TextDocument,
    palette: Palette,
    onNew: () -> Unit,
    onOpenDocuments: () -> Unit,
    onFind: () -> Unit,
    onCycleTheme: () -> Unit,
    onMore: () -> Unit,
    onPreferences: () -> Unit,
    compareEnabled: Boolean,
    readOnly: Boolean,
    zenMode: Boolean,
    previewEnabled: Boolean,
    previewActive: Boolean,
    trackpadActive: Boolean,
    onCompare: () -> Unit,
    onChangeLanguage: () -> Unit,
    onGotoLine: () -> Unit,
    onToggleTrackpad: () -> Unit,
    onTogglePreview: () -> Unit,
    onToggleReadMode: () -> Unit,
    onToggleZenMode: () -> Unit,
    onSwitchToClassic: () -> Unit,
    onSort: () -> Unit,
    onTrim: () -> Unit,
    onDuplicateLine: () -> Unit,
    onDeleteLine: () -> Unit,
    onInsertDateTime: () -> Unit,
    onDuplicateDocument: () -> Unit,
    onRenameDocument: () -> Unit,
    onCloseDocument: () -> Unit,
) {
    var quickOpen by remember { mutableStateOf(false) }

    fun runQuick(action: () -> Unit) {
        quickOpen = false
        action()
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(palette.background.toColor())
            .padding(horizontal = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = document.title,
            color = palette.foreground.toColor(),
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            overflow = TextOverflow.Ellipsis,
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        RoundIconButton(icon = Icons.AutoMirrored.Filled.List, label = "Tabs", palette = palette, onClick = onOpenDocuments)
        RoundIconButton(icon = Icons.AutoMirrored.Filled.NoteAdd, label = "New document", palette = palette, onClick = onNew)
        RoundIconButton(icon = Icons.Filled.Search, label = "Find", palette = palette, onClick = onFind)
        RoundIconButton(icon = Icons.Filled.Brightness6, label = "Theme", palette = palette, onClick = onCycleTheme)
        MobileModeButton(
            icon = Icons.Filled.DesktopWindows,
            label = "Classic",
            palette = palette,
            onClick = onSwitchToClassic,
        )
        Box {
            RoundIconButton(icon = Icons.Filled.MoreHoriz, label = "More", palette = palette, onClick = { quickOpen = true })
            DropdownMenu(
                expanded = quickOpen,
                onDismissRequest = { quickOpen = false },
                modifier = Modifier
                    .background(palette.card.toColor())
                    .border(1.dp, palette.border.toColor()),
            ) {
                ClassicDropdownMenuHeader("Quick actions", palette)
                ClassicDropdownMenuItem("Preferences...", Icons.Filled.Settings, palette) { runQuick(onPreferences) }
                ClassicDropdownMenuItem("Compare documents", Icons.Filled.ViewColumn, palette, enabled = compareEnabled) { runQuick(onCompare) }
                ClassicDropdownMenuItem("Change language", Icons.Filled.Code, palette) { runQuick(onChangeLanguage) }
                ClassicDropdownMenuItem("Go to line...", Icons.AutoMirrored.Filled.KeyboardTab, palette) { runQuick(onGotoLine) }
                ClassicDropdownMenuItem("Virtual trackpad", Icons.Filled.TouchApp, palette, checked = trackpadActive) { runQuick(onToggleTrackpad) }
                ClassicDropdownMenuItem(
                    if (previewActive) "Edit markdown" else "Preview markdown",
                    if (previewActive) Icons.Filled.Edit else Icons.Filled.Visibility,
                    palette,
                    enabled = previewEnabled,
                    checked = previewActive,
                ) { runQuick(onTogglePreview) }
                ClassicDropdownMenuItem("Read mode", if (readOnly) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, palette, checked = readOnly) { runQuick(onToggleReadMode) }
                ClassicDropdownMenuItem("Zen mode", if (zenMode) Icons.Filled.FullscreenExit else Icons.Filled.Fullscreen, palette, checked = zenMode) { runQuick(onToggleZenMode) }
                ClassicDropdownSeparator(palette)
                ClassicDropdownMenuHeader("Line tools", palette)
                ClassicDropdownMenuItem("Sort lines", Icons.Filled.SortByAlpha, palette, enabled = !readOnly) { runQuick(onSort) }
                ClassicDropdownMenuItem("Trim trailing spaces", Icons.AutoMirrored.Filled.FormatAlignLeft, palette, enabled = !readOnly) { runQuick(onTrim) }
                ClassicDropdownMenuItem("Duplicate current line", Icons.Filled.AddBox, palette, enabled = !readOnly) { runQuick(onDuplicateLine) }
                ClassicDropdownMenuItem("Delete current line", Icons.Filled.IndeterminateCheckBox, palette, enabled = !readOnly, destructive = true) { runQuick(onDeleteLine) }
                ClassicDropdownSeparator(palette)
                ClassicDropdownMenuHeader("Document", palette)
                ClassicDropdownMenuItem("Insert date/time", Icons.Filled.AccessTime, palette, enabled = !readOnly) { runQuick(onInsertDateTime) }
                ClassicDropdownMenuItem("Duplicate current doc", Icons.Filled.ContentCopy, palette) { runQuick(onDuplicateDocument) }
                ClassicDropdownMenuItem("Rename current doc", Icons.Filled.Edit, palette) { runQuick(onRenameDocument) }
                ClassicDropdownMenuItem("Close current doc", Icons.Filled.Close, palette, destructive = true) { runQuick(onCloseDocument) }
            }
        }
    }
}

@Composable
private fun MobileModeButton(
    icon: ImageVector,
    label: String,
    palette: Palette,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .height(34.dp)
            .defaultMinSize(minWidth = 82.dp)
            .border(1.dp, palette.border.toColor(), RoundedCornerShape(4.dp))
            .background(palette.card.toColor(), RoundedCornerShape(4.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            icon,
            contentDescription = label,
            tint = palette.primary.toColor(),
            modifier = Modifier.size(18.dp),
        )
        Text(
            text = label,
            color = palette.foreground.toColor(),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Clip,
        )
    }
}

@Composable
private fun RoundIconButton(
    icon: ImageVector,
    label: String,
    palette: Palette,
    onClick: () -> Unit,
) {
    IconButton(
        onClick = onClick,
        modifier = Modifier.size(42.dp),
    ) {
        Icon(
            icon,
            contentDescription = label,
            tint = palette.primary.toColor(),
            modifier = Modifier.size(27.dp),
        )
    }
}

@Composable
private fun ClassicCaptionBar(
    document: TextDocument,
    palette: Palette,
    onCloseApp: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(24.dp)
            .background(
                Brush.verticalGradient(
                    listOf(palette.titleGradientStart.toColor(), palette.titleGradientEnd.toColor()),
                ),
                RoundedCornerShape(topStart = palette.radius.dp, topEnd = palette.radius.dp),
            )
            .border(
                1.dp,
                palette.border.toColor(),
                RoundedCornerShape(topStart = palette.radius.dp, topEnd = palette.radius.dp),
            )
            .padding(start = 8.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = "${document.title} - Notepad 3++",
            color = palette.primaryForeground.toColor(),
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold, fontSize = 12.sp),
            overflow = TextOverflow.Ellipsis,
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        CommandButton(
            text = "X",
            palette = palette,
            modifier = Modifier.size(width = 32.dp, height = 20.dp),
            onClick = onCloseApp,
        )
    }
}

@Composable
private fun ClassicMiniIconButton(
    icon: ImageVector,
    label: String,
    palette: Palette,
    onClick: () -> Unit,
) {
    IconButton(
        onClick = onClick,
        modifier = Modifier.size(width = 32.dp, height = 23.dp),
    ) {
        Icon(icon, contentDescription = label, tint = palette.foreground.toColor(), modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun ClassicMenuBar(
    palette: Palette,
    activeTheme: ThemeName,
    activeLanguage: DocumentLanguage,
    displayOptions: EditorDisplayOptions,
    compareEnabled: Boolean,
    compareActive: Boolean,
    canUndo: Boolean,
    canRedo: Boolean,
    readOnly: Boolean,
    zenMode: Boolean,
    previewEnabled: Boolean,
    previewActive: Boolean,
    trackpadActive: Boolean,
    commentEnabled: Boolean,
    onNew: () -> Unit,
    onOpenFile: () -> Unit,
    onSave: () -> Unit,
    onOpenDocuments: () -> Unit,
    onDuplicateDocument: () -> Unit,
    onRenameDocument: () -> Unit,
    onCloseDocument: () -> Unit,
    onCloseOthers: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onCut: () -> Unit,
    onCopy: () -> Unit,
    onPaste: () -> Unit,
    onSelectAll: () -> Unit,
    onSelectWord: () -> Unit,
    onSelectLine: () -> Unit,
    onSelectParagraph: () -> Unit,
    onFind: () -> Unit,
    onGotoLine: () -> Unit,
    onInsertDateTime: () -> Unit,
    onDuplicateLine: () -> Unit,
    onDeleteLine: () -> Unit,
    onTrim: () -> Unit,
    onSort: () -> Unit,
    onUppercase: () -> Unit,
    onLowercase: () -> Unit,
    onIndent: () -> Unit,
    onUnindent: () -> Unit,
    onToggleComment: () -> Unit,
    onMoveLineUp: () -> Unit,
    onMoveLineDown: () -> Unit,
    onTrimLeading: () -> Unit,
    onJoinLines: () -> Unit,
    onReverseLines: () -> Unit,
    onRemoveDuplicateLines: () -> Unit,
    onCompare: () -> Unit,
    onPreferences: () -> Unit,
    onAppearancePreferences: () -> Unit,
    onToolbarPreferences: () -> Unit,
    onShowAbout: () -> Unit,
    onThemeSelect: (ThemeName) -> Unit,
    onCycleTheme: () -> Unit,
    onLanguageSelect: (DocumentLanguage) -> Unit,
    onTogglePreview: () -> Unit,
    onToggleTrackpad: () -> Unit,
    onToggleWordWrap: () -> Unit,
    onToggleLineNumbers: () -> Unit,
    onToggleAccessoryBar: () -> Unit,
    onToggleReadMode: () -> Unit,
    onToggleZenMode: () -> Unit,
    onSwitchToMobile: () -> Unit,
) {
    var openMenu by remember { mutableStateOf<ClassicMenu?>(null) }

    fun runMenuAction(action: () -> Unit) {
        openMenu = null
        action()
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(25.dp)
            .background(
                Brush.verticalGradient(
                    listOf(palette.chromeGradientStart.toColor(), palette.chromeGradientEnd.toColor()),
                ),
            )
            .border(1.dp, palette.border.toColor())
            .padding(horizontal = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(0.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ClassicMenuButton(
            text = "File",
            menu = ClassicMenu.FILE,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem(
                "New",
                Icons.AutoMirrored.Filled.NoteAdd,
                palette,
            ) { runMenuAction(onNew) }
            ClassicDropdownMenuItem(
                "Open...",
                Icons.Filled.FolderOpen,
                palette,
            ) { runMenuAction(onOpenFile) }
            ClassicDropdownMenuItem(
                "Open documents...",
                Icons.AutoMirrored.Filled.List,
                palette,
            ) { runMenuAction(onOpenDocuments) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuItem(
                "Save",
                Icons.Filled.Save,
                palette,
            ) { runMenuAction(onSave) }
            ClassicDropdownMenuItem(
                "Duplicate",
                Icons.Filled.ContentCopy,
                palette,
            ) { runMenuAction(onDuplicateDocument) }
            ClassicDropdownMenuItem(
                "Rename...",
                Icons.Filled.Edit,
                palette,
            ) { runMenuAction(onRenameDocument) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuItem(
                "Close",
                Icons.Filled.Close,
                palette,
            ) { runMenuAction(onCloseDocument) }
            ClassicDropdownMenuItem(
                "Close others",
                Icons.Filled.DisabledByDefault,
                palette,
            ) { runMenuAction(onCloseOthers) }
        }
        ClassicMenuButton(
            text = "Edit",
            menu = ClassicMenu.EDIT,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem(
                "Undo",
                Icons.AutoMirrored.Filled.Undo,
                palette,
                enabled = canUndo,
            ) { runMenuAction(onUndo) }
            ClassicDropdownMenuItem(
                "Redo",
                Icons.AutoMirrored.Filled.Redo,
                palette,
                enabled = canRedo,
            ) { runMenuAction(onRedo) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuItem(
                "Cut",
                Icons.Filled.ContentCut,
                palette,
                enabled = !readOnly,
            ) { runMenuAction(onCut) }
            ClassicDropdownMenuItem(
                "Copy",
                Icons.Filled.ContentCopy,
                palette,
            ) { runMenuAction(onCopy) }
            ClassicDropdownMenuItem(
                "Paste",
                Icons.Filled.ContentPaste,
                palette,
                enabled = !readOnly,
            ) { runMenuAction(onPaste) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuItem(
                "Select all",
                Icons.Filled.SelectAll,
                palette,
            ) { runMenuAction(onSelectAll) }
            ClassicDropdownMenuItem("Select word", Icons.AutoMirrored.Filled.ShortText, palette) { runMenuAction(onSelectWord) }
            ClassicDropdownMenuItem("Select line", Icons.AutoMirrored.Filled.Subject, palette) { runMenuAction(onSelectLine) }
            ClassicDropdownMenuItem("Select paragraph", Icons.Filled.FormatAlignJustify, palette) { runMenuAction(onSelectParagraph) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuHeader("Text transform", palette)
            ClassicDropdownMenuItem("Uppercase selection", Icons.Filled.FormatSize, palette, enabled = !readOnly) { runMenuAction(onUppercase) }
            ClassicDropdownMenuItem("Lowercase selection", Icons.Filled.TextFields, palette, enabled = !readOnly) { runMenuAction(onLowercase) }
            ClassicDropdownMenuItem("Indent", Icons.AutoMirrored.Filled.FormatIndentIncrease, palette, enabled = !readOnly) { runMenuAction(onIndent) }
            ClassicDropdownMenuItem("Unindent", Icons.AutoMirrored.Filled.FormatIndentDecrease, palette, enabled = !readOnly) { runMenuAction(onUnindent) }
            ClassicDropdownMenuItem("Toggle comment", Icons.Filled.Code, palette, enabled = !readOnly && commentEnabled) { runMenuAction(onToggleComment) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuItem("Insert date/time", Icons.Filled.AccessTime, palette, enabled = !readOnly) { runMenuAction(onInsertDateTime) }
        }
        ClassicMenuButton(
            text = "Search",
            menu = ClassicMenu.SEARCH,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem("Find/Replace...", Icons.Filled.Search, palette) { runMenuAction(onFind) }
            ClassicDropdownMenuItem("Goto line...", Icons.AutoMirrored.Filled.KeyboardTab, palette) { runMenuAction(onGotoLine) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuItem("Compare documents", Icons.Filled.ViewColumn, palette, enabled = compareEnabled, checked = compareActive) { runMenuAction(onCompare) }
        }
        ClassicMenuButton(
            text = "View",
            menu = ClassicMenu.VIEW,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem("Switch to mobile layout", Icons.Filled.PhoneAndroid, palette) { runMenuAction(onSwitchToMobile) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuHeader("Document view", palette)
            ClassicDropdownMenuItem("Read mode", if (readOnly) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, palette, checked = readOnly) { runMenuAction(onToggleReadMode) }
            ClassicDropdownMenuItem("Zen mode", if (zenMode) Icons.Filled.FullscreenExit else Icons.Filled.Fullscreen, palette, checked = zenMode) { runMenuAction(onToggleZenMode) }
            ClassicDropdownMenuItem("Markdown preview", Icons.Filled.Visibility, palette, enabled = previewEnabled, checked = previewActive) { runMenuAction(onTogglePreview) }
            ClassicDropdownMenuItem("Virtual trackpad", Icons.Filled.TouchApp, palette, checked = trackpadActive) { runMenuAction(onToggleTrackpad) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuHeader("Editor chrome", palette)
            ClassicDropdownMenuItem("Word wrap", Icons.AutoMirrored.Filled.WrapText, palette, checked = displayOptions.wordWrap) { runMenuAction(onToggleWordWrap) }
            ClassicDropdownMenuItem("Line numbers", Icons.Filled.FormatListNumbered, palette, checked = displayOptions.lineNumbers) { runMenuAction(onToggleLineNumbers) }
            ClassicDropdownMenuItem("Accessory toolbar", Icons.Filled.Keyboard, palette, checked = displayOptions.accessoryBar) { runMenuAction(onToggleAccessoryBar) }
        }
        ClassicMenuButton(
            text = "Syntax",
            menu = ClassicMenu.LANGUAGE,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            DocumentLanguage.selectableLanguages.forEach { language ->
                ClassicDropdownMenuItem(
                    text = language.displayName,
                    icon = Icons.Filled.Code,
                    palette = palette,
                    checked = language == activeLanguage,
                ) {
                    runMenuAction { onLanguageSelect(language) }
                }
            }
        }
        ClassicMenuButton(
            text = "Settings",
            menu = ClassicMenu.SETTINGS,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem("Preferences...", Icons.Filled.Settings, palette) { runMenuAction(onPreferences) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownSubmenuItem("Appearance", Icons.Filled.Palette, palette) {
                ClassicDropdownMenuItem("Appearance preferences...", Icons.Filled.Settings, palette) { runMenuAction(onAppearancePreferences) }
                ClassicDropdownMenuItem("Toolbar preferences...", Icons.Filled.Keyboard, palette) { runMenuAction(onToolbarPreferences) }
                ClassicDropdownSubmenuItem("Themes", Icons.Filled.Palette, palette) {
                    ClassicDropdownMenuItem("Next theme", Icons.Filled.Palette, palette) { runMenuAction(onCycleTheme) }
                    ClassicDropdownSeparator(palette)
                    ThemeName.entries.filterNot { it == ThemeName.CUSTOM }.forEach { theme ->
                        ClassicDropdownMenuItem(
                            text = theme.displayTitle,
                            icon = Icons.Filled.Palette,
                            palette = palette,
                            checked = theme == activeTheme,
                        ) {
                            runMenuAction { onThemeSelect(theme) }
                        }
                    }
                }
            }
        }
        ClassicMenuButton(
            text = "Tools",
            menu = ClassicMenu.TOOLS,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuHeader("Line operations", palette)
            ClassicDropdownMenuItem("Duplicate current line", Icons.Filled.AddBox, palette, enabled = !readOnly) { runMenuAction(onDuplicateLine) }
            ClassicDropdownMenuItem("Delete current line", Icons.Filled.IndeterminateCheckBox, palette, enabled = !readOnly, destructive = true) { runMenuAction(onDeleteLine) }
            ClassicDropdownMenuItem("Move line up", Icons.Filled.KeyboardArrowUp, palette, enabled = !readOnly) { runMenuAction(onMoveLineUp) }
            ClassicDropdownMenuItem("Move line down", Icons.Filled.KeyboardArrowDown, palette, enabled = !readOnly) { runMenuAction(onMoveLineDown) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuItem("Sort lines", Icons.Filled.SortByAlpha, palette, enabled = !readOnly) { runMenuAction(onSort) }
            ClassicDropdownMenuItem("Trim trailing spaces", Icons.AutoMirrored.Filled.FormatAlignLeft, palette, enabled = !readOnly) { runMenuAction(onTrim) }
            ClassicDropdownMenuItem("Trim leading spaces", Icons.Filled.ContentCut, palette, enabled = !readOnly) { runMenuAction(onTrimLeading) }
            ClassicDropdownMenuItem("Join selected lines", Icons.AutoMirrored.Filled.FormatAlignLeft, palette, enabled = !readOnly) { runMenuAction(onJoinLines) }
            ClassicDropdownMenuItem("Reverse lines", Icons.Filled.SwapVert, palette, enabled = !readOnly) { runMenuAction(onReverseLines) }
            ClassicDropdownMenuItem("Unique lines", Icons.Filled.FilterList, palette, enabled = !readOnly) { runMenuAction(onRemoveDuplicateLines) }
        }
        ClassicMenuButton(
            text = "?",
            menu = ClassicMenu.HELP,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem("About Notepad 3++", Icons.Filled.Info, palette) { runMenuAction(onShowAbout) }
        }
        Spacer(Modifier.weight(1f))
        ClassicMiniIconButton(icon = Icons.Filled.PhoneAndroid, label = "Mobile layout", palette = palette, onClick = onSwitchToMobile)
    }
}

@Composable
private fun ClassicMenuButton(
    text: String,
    menu: ClassicMenu,
    openMenu: ClassicMenu?,
    palette: Palette,
    onOpen: (ClassicMenu?) -> Unit,
    content: @Composable () -> Unit,
) {
    val selected = openMenu == menu
    Box {
        Text(
            text = text,
            color = if (selected) palette.primaryForeground.toColor() else palette.foreground.toColor(),
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Normal, fontSize = 12.sp),
            modifier = Modifier
                .height(23.dp)
                .background(if (selected) palette.primary.toColor() else Color.Transparent)
                .clickable { onOpen(if (selected) null else menu) }
                .padding(horizontal = 5.dp, vertical = 3.dp),
        )
        DropdownMenu(
            expanded = selected,
            onDismissRequest = { onOpen(null) },
            modifier = Modifier
                .background(palette.card.toColor())
                .border(1.dp, palette.border.toColor()),
        ) {
            content()
        }
    }
}

@Composable
private fun ClassicDropdownMenuItem(
    text: String,
    icon: ImageVector,
    palette: Palette,
    enabled: Boolean = true,
    checked: Boolean = false,
    destructive: Boolean = false,
    onClick: () -> Unit,
) {
    val color = when {
        !enabled -> palette.mutedForeground.toColor().copy(alpha = 0.55f)
        destructive -> palette.destructive.toColor()
        else -> palette.foreground.toColor()
    }
    Row(
        modifier = Modifier
            .widthIn(min = 210.dp)
            .height(28.dp)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(start = 8.dp, end = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(17.dp))
        Text(
            text = text,
            color = color,
            style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        if (checked) {
            Icon(Icons.Filled.Check, contentDescription = null, tint = palette.primary.toColor(), modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun ClassicDropdownSubmenuItem(
    text: String,
    icon: ImageVector,
    palette: Palette,
    enabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    var revealRequest by remember { mutableStateOf(0) }
    LaunchedEffect(revealRequest) {
        if (revealRequest > 0) {
            delay(120)
            expanded = true
        }
    }
    val color = when {
        !enabled -> palette.mutedForeground.toColor().copy(alpha = 0.55f)
        expanded -> palette.primaryForeground.toColor()
        else -> palette.foreground.toColor()
    }
    Box {
        Row(
            modifier = Modifier
                .widthIn(min = 210.dp)
                .height(28.dp)
                .background(if (expanded) palette.primary.toColor() else Color.Transparent)
                .clickable(enabled = enabled) {
                    if (expanded) {
                        expanded = false
                    } else {
                        revealRequest += 1
                    }
                }
                .padding(start = 8.dp, end = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(17.dp))
            Text(
                text = text,
                color = color,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
                maxLines = 1,
                modifier = Modifier.weight(1f),
            )
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = "Open $text submenu",
                tint = color,
                modifier = Modifier.size(17.dp),
            )
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            offset = DpOffset(x = 210.dp, y = (-28).dp),
            modifier = Modifier
                .background(palette.card.toColor())
                .border(1.dp, palette.border.toColor()),
        ) {
            content()
        }
    }
}

@Composable
private fun ClassicDropdownSeparator(palette: Palette) {
    Spacer(
        Modifier
            .padding(vertical = 3.dp)
            .height(1.dp)
            .widthIn(min = 210.dp)
            .background(palette.border.toColor().copy(alpha = 0.55f)),
    )
}

@Composable
private fun ClassicDropdownMenuHeader(text: String, palette: Palette) {
    Text(
        text = text.uppercase(Locale.ROOT),
        color = palette.mutedForeground.toColor(),
        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold),
        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun ClassicToolRack(
    palette: Palette,
    compareEnabled: Boolean,
    compareActive: Boolean,
    canUndo: Boolean,
    canRedo: Boolean,
    readOnly: Boolean,
    onNew: () -> Unit,
    onOpen: () -> Unit,
    onOpenFile: () -> Unit,
    onSave: () -> Unit,
    onDuplicateDocument: () -> Unit,
    onCut: () -> Unit,
    onCopy: () -> Unit,
    onPaste: () -> Unit,
    onFind: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
    onPreferences: () -> Unit,
    onCycleTheme: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onGotoLine: () -> Unit,
    onSelectAll: () -> Unit,
    onSelectLine: () -> Unit,
    onSelectParagraph: () -> Unit,
    onInsertDateTime: () -> Unit,
    onDuplicateLine: () -> Unit,
    onDeleteLine: () -> Unit,
    onTrim: () -> Unit,
    onSort: () -> Unit,
    onToggleReadMode: () -> Unit,
    onToggleZenMode: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    listOf(palette.chromeGradientStart.toColor(), palette.chromeGradientEnd.toColor()),
                ),
            )
            .border(1.dp, palette.border.toColor()),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 4.dp, vertical = 3.dp),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ClassicToolbarButton(
                icon = Icons.AutoMirrored.Filled.NoteAdd,
                label = "New",
                palette = palette,
                onClick = onNew,
            )
            ClassicToolbarButton(
                icon = Icons.Filled.FolderOpen,
                label = "Open",
                palette = palette,
                onClick = onOpenFile,
            )
            ClassicToolbarButton(
                icon = Icons.AutoMirrored.Filled.List,
                label = "Docs",
                palette = palette,
                onClick = onOpen,
            )
            ClassicToolbarButton(
                icon = Icons.Filled.Save,
                label = "Save",
                palette = palette,
                onClick = onSave,
            )
            ClassicToolbarButton(
                icon = Icons.Filled.ContentCopy,
                label = "Duplicate",
                palette = palette,
                onClick = onDuplicateDocument,
            )
            ToolbarDivider(palette)
            ClassicToolbarButton(
                icon = Icons.Filled.ContentCut,
                label = "Cut",
                palette = palette,
                enabled = !readOnly,
                onClick = onCut,
            )
            ClassicToolbarButton(
                icon = Icons.Filled.ContentCopy,
                label = "Copy",
                palette = palette,
                onClick = onCopy,
            )
            ClassicToolbarButton(
                icon = Icons.Filled.ContentPaste,
                label = "Paste",
                palette = palette,
                enabled = !readOnly,
                onClick = onPaste,
            )
            ToolbarDivider(palette)
            ClassicToolbarButton(
                icon = Icons.AutoMirrored.Filled.Undo,
                label = "Undo",
                palette = palette,
                enabled = canUndo,
                onClick = onUndo,
            )
            ClassicToolbarButton(
                icon = Icons.AutoMirrored.Filled.Redo,
                label = "Redo",
                palette = palette,
                enabled = canRedo,
                onClick = onRedo,
            )
            ToolbarDivider(palette)
            ClassicToolbarButton(
                icon = Icons.Filled.Search,
                label = "Find",
                palette = palette,
                onClick = onFind,
            )
            ClassicToolbarButton(icon = Icons.Filled.AccessTime, label = "Date", palette = palette, enabled = !readOnly, onClick = onInsertDateTime)
            ToolbarDivider(palette)
            ClassicToolbarButton(
                icon = Icons.Filled.SelectAll,
                label = "Select all",
                palette = palette,
                onClick = onSelectAll,
            )
            ClassicToolbarButton(icon = Icons.AutoMirrored.Filled.Subject, label = "Line", palette = palette, onClick = onSelectLine)
            ClassicToolbarButton(icon = Icons.Filled.FormatAlignJustify, label = "Paragraph", palette = palette, onClick = onSelectParagraph)
            ToolbarDivider(palette)
            ClassicToolbarButton(icon = Icons.Filled.AddBox, label = "Duplicate line", palette = palette, enabled = !readOnly, onClick = onDuplicateLine)
            ClassicToolbarButton(icon = Icons.Filled.IndeterminateCheckBox, label = "Delete line", palette = palette, enabled = !readOnly, destructive = true, onClick = onDeleteLine)
            ClassicToolbarButton(icon = Icons.AutoMirrored.Filled.KeyboardTab, label = "Goto line", palette = palette, onClick = onGotoLine)
            ClassicToolbarButton(icon = Icons.AutoMirrored.Filled.FormatAlignLeft, label = "Trim", palette = palette, enabled = !readOnly, onClick = onTrim)
            ClassicToolbarButton(icon = Icons.Filled.SortByAlpha, label = "Sort", palette = palette, enabled = !readOnly, onClick = onSort)
            ToolbarDivider(palette)
            ClassicToolbarButton(
                icon = Icons.Filled.ViewColumn,
                label = "Compare",
                palette = palette,
                enabled = compareEnabled,
                active = compareActive,
                onClick = onCompare,
            )
            ClassicToolbarButton(icon = Icons.Filled.VisibilityOff, label = "Read mode", palette = palette, active = readOnly, onClick = onToggleReadMode)
            ClassicToolbarButton(icon = Icons.Filled.Fullscreen, label = "Zen mode", palette = palette, onClick = onToggleZenMode)
            ClassicToolbarButton(icon = Icons.Filled.Palette, label = "Theme", palette = palette, onClick = onCycleTheme)
            ClassicToolbarButton(icon = Icons.Filled.Settings, label = "Preferences", palette = palette, onClick = onPreferences)
        }
    }
}

@Composable
private fun ClassicToolbarButton(
    icon: ImageVector,
    label: String,
    palette: Palette,
    enabled: Boolean = true,
    active: Boolean = false,
    destructive: Boolean = false,
    onClick: () -> Unit,
) {
    val foreground = when {
        !enabled -> palette.mutedForeground.toColor().copy(alpha = 0.48f)
        destructive -> palette.destructive.toColor()
        active -> palette.primary.toColor()
        else -> palette.foreground.toColor()
    }
    Column(
        modifier = Modifier
            .defaultMinSize(minWidth = 30.dp)
            .height(25.dp)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 5.dp, vertical = 3.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = label, tint = foreground, modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun ToolbarGlyph(
    label: String,
    glyph: String,
    palette: Palette,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val foreground = if (enabled) palette.foreground.toColor() else palette.mutedForeground.toColor()
    val border = if (enabled) palette.border.toColor() else palette.secondary.toColor()
    val shape = RoundedCornerShape((palette.radius.coerceAtMost(3)).dp)
    val labelText = label.ifBlank { glyph }
    Column(
        modifier = modifier
            .defaultMinSize(minWidth = 50.dp, minHeight = 0.dp)
            .height(26.dp)
            .background(
                Brush.verticalGradient(
                    if (enabled) {
                        listOf(palette.card.toColor(), palette.chromeGradientEnd.toColor())
                    } else {
                        listOf(palette.muted.toColor(), palette.secondary.toColor())
                    },
                ),
                shape,
            )
            .border(1.dp, border, shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 6.dp, vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = labelText,
            color = foreground,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold, fontSize = 10.sp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun ToolbarDivider(palette: Palette) {
    Spacer(
        Modifier
            .size(width = 1.dp, height = 22.dp)
            .background(palette.border.toColor()),
    )
}

@Composable
private fun DocumentStrip(
    documents: List<TextDocument>,
    activeId: String,
    palette: Palette,
    onSelect: (String) -> Unit,
    onClose: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        documents.forEach { document ->
            val active = document.id == activeId
            Row(
                modifier = Modifier
                    .height(30.dp)
                    .width(documentTabWidthDp(document.title).dp)
                    .background(
                        if (active) {
                            Brush.verticalGradient(listOf(palette.titleGradientStart.toColor(), palette.titleGradientEnd.toColor()))
                        } else {
                            Brush.verticalGradient(listOf(palette.card.toColor(), palette.muted.toColor()))
                        },
                        RoundedCornerShape(palette.radius.dp),
                    )
                    .border(
                        1.dp,
                        if (active) palette.primary.toColor() else palette.border.toColor(),
                        RoundedCornerShape(palette.radius.dp),
                    )
                    .clickable { onSelect(document.id) }
                    .padding(horizontal = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = documentTabDisplayTitle(document.title),
                    color = if (active) palette.primaryForeground.toColor() else palette.foreground.toColor(),
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (documents.size > 1) {
                    Text(
                        text = "X",
                        color = if (active) palette.primaryForeground.toColor() else palette.mutedForeground.toColor(),
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.clickable { onClose(document.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun OpenDocumentsPanel(
    documents: List<TextDocument>,
    activeId: String,
    palette: Palette,
    onSelect: (String) -> Unit,
    onNew: () -> Unit,
    onOpenFile: () -> Unit,
    onClose: (String) -> Unit,
) {
    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text("Tabs", color = palette.foreground.toColor(), style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                CommandButton(text = "New", palette = palette, primary = true, onClick = onNew)
                CommandButton(text = "Open File", palette = palette, onClick = onOpenFile)
            }
            documents.forEach { document ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    OutlinedButton(
                        onClick = { onSelect(document.id) },
                        border = BorderStroke(1.dp, if (document.id == activeId) palette.primary.toColor() else palette.border.toColor()),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = if (document.id == activeId) palette.muted.toColor() else palette.card.toColor(),
                            contentColor = palette.foreground.toColor(),
                        ),
                        shape = RoundedCornerShape(palette.radius.dp),
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(document.title)
                    }
                    if (documents.size > 1) {
                        CommandButton(text = "Close", palette = palette, onClick = { onClose(document.id) })
                    }
                }
            }
        }
    }
}

@Composable
private fun FindPanel(
    document: TextDocument,
    query: String,
    replacement: String,
    options: SearchOptions,
    palette: Palette,
    replaceEnabled: Boolean,
    onQueryChange: (String) -> Unit,
    onReplacementChange: (String) -> Unit,
    onToggleCaseSensitive: () -> Unit,
    onToggleWholeWord: () -> Unit,
    onToggleRegex: () -> Unit,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onReplaceCurrent: () -> Unit,
    onReplaceAll: () -> Unit,
) {
    val matchCount = EditorCommands.findMatches(document.body, query, options).size
    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = query,
                    onValueChange = onQueryChange,
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    placeholder = { Text("Find") },
                )
                Text(
                    text = "$matchCount found",
                    color = palette.mutedForeground.toColor(),
                    modifier = Modifier.padding(top = 16.dp),
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OutlinedTextField(
                    value = replacement,
                    onValueChange = onReplacementChange,
                    enabled = replaceEnabled,
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    placeholder = { Text("Replace") },
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(
                    text = "Aa",
                    palette = palette,
                    primary = options.caseSensitive,
                    modifier = Modifier.weight(1f),
                    onClick = onToggleCaseSensitive,
                )
                CommandButton(
                    text = "Word",
                    palette = palette,
                    primary = options.wholeWord,
                    modifier = Modifier.weight(1f),
                    onClick = onToggleWholeWord,
                )
                CommandButton(
                    text = "Regex",
                    palette = palette,
                    primary = options.regex,
                    modifier = Modifier.weight(1f),
                    onClick = onToggleRegex,
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(text = "Prev", palette = palette, enabled = matchCount > 0, onClick = onPrevious)
                CommandButton(text = "Next", palette = palette, enabled = matchCount > 0, onClick = onNext)
                CommandButton(
                    text = "Replace",
                    palette = palette,
                    enabled = replaceEnabled && query.isNotBlank(),
                    modifier = Modifier.weight(1f),
                    onClick = onReplaceCurrent,
                )
                CommandButton(
                    text = "All",
                    palette = palette,
                    enabled = replaceEnabled && query.isNotBlank(),
                    modifier = Modifier.weight(1f),
                    onClick = onReplaceAll,
                )
            }
        }
    }
}

@Composable
private fun LanguagePanel(
    current: DocumentLanguage,
    palette: Palette,
    onSelect: (DocumentLanguage) -> Unit,
    onCancel: () -> Unit,
) {
    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .padding(8.dp)
                .heightIn(max = 320.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text("Change syntax", color = palette.foreground.toColor(), style = MaterialTheme.typography.labelLarge)
            DocumentLanguage.selectableLanguages.forEach { language ->
                val selected = language == current
                OutlinedButton(
                    onClick = { onSelect(language) },
                    border = BorderStroke(1.dp, if (selected) palette.primary.toColor() else palette.border.toColor()),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = if (selected) palette.muted.toColor() else palette.card.toColor(),
                        contentColor = palette.foreground.toColor(),
                    ),
                    shape = RoundedCornerShape(palette.radius.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(language.displayName)
                }
            }
            CommandButton(text = "Cancel", palette = palette, modifier = Modifier.fillMaxWidth(), onClick = onCancel)
        }
    }
}

@Composable
private fun GotoPanel(
    document: TextDocument,
    value: String,
    palette: Palette,
    onValueChange: (String) -> Unit,
    onGo: () -> Unit,
    onCancel: () -> Unit,
) {
    val maxLine = document.body.lines().size.coerceAtLeast(1)
    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text("Go to line", color = palette.foreground.toColor(), style = MaterialTheme.typography.labelLarge)
            Text("Line 1 to $maxLine", color = palette.mutedForeground.toColor())
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedTextField(
                    value = value,
                    onValueChange = onValueChange,
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    placeholder = { Text("Line number") },
                )
                CommandButton(text = "Go", palette = palette, enabled = value.toIntOrNull() != null, onClick = onGo)
                CommandButton(text = "Cancel", palette = palette, onClick = onCancel)
            }
        }
    }
}

@Composable
private fun RenamePanel(
    value: String,
    palette: Palette,
    onValueChange: (String) -> Unit,
    onSave: () -> Unit,
    onCancel: () -> Unit,
) {
    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text("Rename document", color = palette.foreground.toColor(), style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedTextField(
                    value = value,
                    onValueChange = onValueChange,
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    placeholder = { Text("Document name") },
                )
                CommandButton(text = "Save", palette = palette, enabled = value.trim().isNotEmpty(), onClick = onSave)
                CommandButton(text = "Cancel", palette = palette, onClick = onCancel)
            }
        }
    }
}

@Composable
private fun AboutPanel(
    palette: Palette,
    onDismiss: () -> Unit,
) {
    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "Notepad 3++",
                color = palette.foreground.toColor(),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            )
            Text(
                text = "A mobile text editor with classic desktop utility chrome.",
                color = palette.mutedForeground.toColor(),
                style = MaterialTheme.typography.bodyMedium,
            )
            CommandButton(text = "Close", palette = palette, modifier = Modifier.fillMaxWidth(), onClick = onDismiss)
        }
    }
}

@Composable
private fun MarkdownPreviewPane(
    document: TextDocument,
    palette: Palette,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = palette.editorBackground.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            val blocks = MarkdownPreview.parse(document.body)
            if (blocks.isEmpty()) {
                Text(
                    text = "Empty preview",
                    color = palette.mutedForeground.toColor(),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            blocks.forEach { block ->
                MarkdownPreviewBlock(block = block, palette = palette)
            }
        }
    }
}

@Composable
private fun MarkdownPreviewBlock(block: MarkdownBlock, palette: Palette) {
    when (block) {
        is MarkdownBlock.Heading -> Text(
            text = block.text,
            color = palette.foreground.toColor(),
            style = when (block.level) {
                1 -> MaterialTheme.typography.headlineSmall
                2 -> MaterialTheme.typography.titleLarge
                else -> MaterialTheme.typography.titleMedium
            },
        )

        is MarkdownBlock.Paragraph -> Text(
            text = block.text,
            color = palette.foreground.toColor(),
            style = MaterialTheme.typography.bodyLarge,
        )

        is MarkdownBlock.Bullet -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("-", color = palette.mutedForeground.toColor(), fontFamily = FontFamily.Monospace)
            Text(
                text = block.text,
                color = palette.foreground.toColor(),
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
            )
        }

        is MarkdownBlock.Code -> Text(
            text = block.text,
            color = palette.foreground.toColor(),
            fontFamily = FontFamily.Monospace,
            modifier = Modifier
                .fillMaxWidth()
                .background(palette.muted.toColor(), RoundedCornerShape(4.dp))
                .padding(8.dp),
        )
    }
}

@Composable
private fun ComparePanel(
    active: TextDocument,
    documents: List<TextDocument>,
    target: TextDocument?,
    palette: Palette,
    onTargetSelect: (String) -> Unit,
) {
    if (target == null) return
    val comparable = documents.filter { it.id != active.id }
    val diff = LineDiff.compute(top = active.body, bottom = target.body)
    val summary = diff.summary
    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text("Compare", color = palette.foreground.toColor(), style = MaterialTheme.typography.labelLarge)
            Text("${active.title} | ${target.title}", color = palette.foreground.toColor())
            if (comparable.size > 1) {
                Text("Compare with", color = palette.mutedForeground.toColor(), style = MaterialTheme.typography.labelSmall)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    comparable.forEach { document ->
                        val selected = document.id == target.id
                        OutlinedButton(
                            onClick = { onTargetSelect(document.id) },
                            border = BorderStroke(1.dp, if (selected) palette.primary.toColor() else palette.border.toColor()),
                            colors = ButtonDefaults.outlinedButtonColors(
                                containerColor = if (selected) palette.muted.toColor() else palette.card.toColor(),
                                contentColor = palette.foreground.toColor(),
                            ),
                            shape = RoundedCornerShape(palette.radius.dp),
                        ) {
                            Text(document.title, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
            }
            Text(
                "${summary.percentSimilar}% similar | ${summary.added} added | ${summary.removed} removed | ${summary.changed} changed",
                color = palette.foreground.toColor(),
            )
            Text(
                "${diff.topLines.size} lines | ${diff.bottomLines.size} lines",
                color = palette.mutedForeground.toColor(),
            )
            DiffRowsPreview(
                rows = diff.rows,
                palette = palette,
            )
        }
    }
}

@Composable
private fun DiffRowsPreview(
    rows: List<LineDiff.Row>,
    palette: Palette,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(max = 220.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
            Text("Active", color = palette.mutedForeground.toColor(), modifier = Modifier.weight(1f))
            Text("Other", color = palette.mutedForeground.toColor(), modifier = Modifier.weight(1f))
        }
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                DiffCell(line = row.topLine, status = row.topStatus, palette = palette, modifier = Modifier.weight(1f))
                DiffCell(line = row.bottomLine, status = row.bottomStatus, palette = palette, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun DiffCell(
    line: String?,
    status: LineDiff.Status?,
    palette: Palette,
    modifier: Modifier = Modifier,
) {
    Text(
        text = line ?: "",
        color = if (line == null) palette.mutedForeground.toColor() else palette.foreground.toColor(),
        fontFamily = FontFamily.Monospace,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier
            .background(diffStatusColor(status, palette), RoundedCornerShape(2.dp))
            .padding(horizontal = 6.dp, vertical = 4.dp),
    )
}

private fun diffStatusColor(status: LineDiff.Status?, palette: Palette): Color =
    when (status) {
        LineDiff.Status.Added -> palette.success.toColor().copy(alpha = 0.18f)
        LineDiff.Status.Removed -> palette.destructive.toColor().copy(alpha = 0.18f)
        LineDiff.Status.Changed -> Color(0xFFFFD94D).copy(alpha = 0.25f)
        LineDiff.Status.Unchanged -> palette.editorBackground.toColor()
        null -> palette.muted.toColor()
    }

@Composable
private fun PreferencesPage(
    palette: Palette,
    destination: PreferencesDestination,
    activeTheme: ThemeName,
    layoutMode: EditorLayoutMode,
    displayOptions: EditorDisplayOptions,
    onDismiss: () -> Unit,
    onNavigate: (PreferencesDestination) -> Unit,
    onThemeSelect: (ThemeName) -> Unit,
    onSetLayoutMode: (EditorLayoutMode) -> Unit,
    onToggleWordWrap: () -> Unit,
    onToggleLineNumbers: () -> Unit,
    onToggleAccessoryBar: () -> Unit,
    onToolbarRowsDown: () -> Unit,
    onToolbarRowsUp: () -> Unit,
    onToolbarButtonSizeSelect: (AccessoryToolbarButtonSize) -> Unit,
    onToolbarContentModeSelect: (AccessoryToolbarContentMode) -> Unit,
    onToggleStaticAccessoryButton: (AccessoryToolbarButton) -> Unit,
    onToggleHiddenAccessoryButton: (AccessoryToolbarButton) -> Unit,
    onFontSizeDown: () -> Unit,
    onFontSizeUp: () -> Unit,
) {
    BackHandler {
        preferencesBackDestination(destination)?.let(onNavigate) ?: onDismiss()
    }
    Surface(
        color = palette.background.toColor(),
        modifier = Modifier.fillMaxSize(),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            listOf(palette.chromeGradientStart.toColor(), palette.chromeGradientEnd.toColor()),
                        ),
                    )
                    .border(1.dp, palette.border.toColor())
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = destination.title,
                    color = palette.foreground.toColor(),
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    modifier = Modifier.weight(1f),
                )
                CommandButton(text = "Done", palette = palette, primary = true, onClick = onDismiss)
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 18.dp),
            ) {
                if (destination != PreferencesDestination.GENERAL) {
                    MenuActionRow(Icons.AutoMirrored.Filled.ArrowBack, "All preferences", palette) {
                        onNavigate(PreferencesDestination.GENERAL)
                    }
                }

                when (destination) {
                    PreferencesDestination.GENERAL -> {
                        MenuSectionHeader("Preferences", palette)
                        preferencesHomeRows().forEach { row ->
                            val target = when (row.title) {
                                "Appearance" -> PreferencesDestination.APPEARANCE
                                "Toolbar" -> PreferencesDestination.TOOLBAR
                                else -> PreferencesDestination.EDITOR
                            }
                            val icon = when (target) {
                                PreferencesDestination.APPEARANCE -> Icons.Filled.Palette
                                PreferencesDestination.TOOLBAR -> Icons.Filled.Keyboard
                                PreferencesDestination.EDITOR -> Icons.Filled.TextFields
                                PreferencesDestination.GENERAL -> Icons.Filled.Settings
                            }
                            MenuActionRow(icon, row.title, palette, subtitle = target.preferenceSubtitle) {
                                onNavigate(target)
                            }
                        }
                    }

                    PreferencesDestination.APPEARANCE -> {
                        MenuSectionHeader("Themes", palette)
                        ThemeName.entries.filterNot { it == ThemeName.CUSTOM }.forEach { theme ->
                            MenuActionRow(
                                icon = Icons.Filled.Palette,
                                title = theme.displayTitle,
                                palette = palette,
                                checked = theme == activeTheme,
                            ) { onThemeSelect(theme) }
                        }

                        MenuSectionHeader("Layout", palette)
                        MenuActionRow(
                            icon = Icons.Filled.PhoneAndroid,
                            title = "Mobile layout",
                            palette = palette,
                            checked = layoutMode == EditorLayoutMode.MOBILE,
                        ) { onSetLayoutMode(EditorLayoutMode.MOBILE) }
                        MenuActionRow(
                            icon = Icons.Filled.DesktopWindows,
                            title = "Classic layout",
                            palette = palette,
                            checked = layoutMode == EditorLayoutMode.CLASSIC,
                        ) { onSetLayoutMode(EditorLayoutMode.CLASSIC) }
                        MenuActionRow(Icons.Filled.Keyboard, "Toolbar preferences", palette, subtitle = "Rows, size, pinned buttons") {
                            onNavigate(PreferencesDestination.TOOLBAR)
                        }
                    }

                    PreferencesDestination.TOOLBAR -> {
                        MenuSectionHeader("Toolbar", palette)
                        MenuActionRow(Icons.Filled.Keyboard, "Accessory toolbar", palette, checked = displayOptions.accessoryBar) {
                            onToggleAccessoryBar()
                        }
                        PreferenceStepperRow(
                            icon = Icons.Filled.ViewColumn,
                            title = "Toolbar rows",
                            value = displayOptions.accessoryToolbarRows.toString(),
                            palette = palette,
                            onDown = onToolbarRowsDown,
                            onUp = onToolbarRowsUp,
                        )
                        AccessoryToolbarButtonSize.entries.forEach { size ->
                            MenuActionRow(
                                icon = Icons.Filled.FormatSize,
                                title = "${size.displayTitle} buttons",
                                palette = palette,
                                checked = size == displayOptions.accessoryToolbarButtonSize,
                            ) { onToolbarButtonSizeSelect(size) }
                        }
                        AccessoryToolbarContentMode.entries.forEach { mode ->
                            MenuActionRow(
                                icon = mode.preferenceIcon,
                                title = mode.displayTitle,
                                palette = palette,
                                checked = mode == displayOptions.accessoryToolbarContentMode,
                            ) { onToolbarContentModeSelect(mode) }
                        }

                        MenuSectionHeader("Pinned Buttons", palette)
                        AccessoryToolbarButton.entries.forEach { button ->
                            MenuActionRow(
                                icon = button.preferenceIcon,
                                title = button.displayTitle,
                                palette = palette,
                                checked = button in displayOptions.staticAccessoryButtons,
                            ) { onToggleStaticAccessoryButton(button) }
                        }

                        MenuSectionHeader("Hidden Buttons", palette)
                        AccessoryToolbarButton.entries.forEach { button ->
                            MenuActionRow(
                                icon = button.preferenceIcon,
                                title = button.displayTitle,
                                palette = palette,
                                checked = button in displayOptions.hiddenAccessoryButtons,
                            ) { onToggleHiddenAccessoryButton(button) }
                        }
                    }

                    PreferencesDestination.EDITOR -> {
                        MenuSectionHeader("Editor", palette)
                        MenuActionRow(Icons.AutoMirrored.Filled.WrapText, "Word wrap", palette, checked = displayOptions.wordWrap) {
                            onToggleWordWrap()
                        }
                        MenuActionRow(Icons.Filled.FormatListNumbered, "Line numbers", palette, checked = displayOptions.lineNumbers) {
                            onToggleLineNumbers()
                        }
                        PreferenceStepperRow(
                            icon = Icons.Filled.FormatSize,
                            title = "Font size",
                            value = "${displayOptions.fontSizeSp} sp",
                            palette = palette,
                            onDown = onFontSizeDown,
                            onUp = onFontSizeUp,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PreferenceStepperRow(
    icon: ImageVector,
    title: String,
    value: String,
    palette: Palette,
    onDown: () -> Unit,
    onUp: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = palette.foreground.toColor(), modifier = Modifier.size(21.dp))
        Text(
            text = title,
            color = palette.foreground.toColor(),
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
            modifier = Modifier.weight(1f),
        )
        CommandButton(text = "-", palette = palette, modifier = Modifier.size(width = 44.dp, height = 30.dp), onClick = onDown)
        Text(
            text = value,
            color = palette.mutedForeground.toColor(),
            style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
        )
        CommandButton(text = "+", palette = palette, modifier = Modifier.size(width = 44.dp, height = 30.dp), onClick = onUp)
    }
}

@Composable
private fun MorePanel(
    palette: Palette,
    canUndo: Boolean,
    canRedo: Boolean,
    readMode: Boolean,
    zenMode: Boolean,
    layoutMode: EditorLayoutMode,
    activeLanguage: DocumentLanguage,
    displayOptions: EditorDisplayOptions,
    trackpadActive: Boolean,
    onDismiss: () -> Unit,
    onNew: () -> Unit,
    onOpenDocuments: () -> Unit,
    onOpenFile: () -> Unit,
    onSave: () -> Unit,
    onDuplicateDocument: () -> Unit,
    onRenameDocument: () -> Unit,
    onCloseDocument: () -> Unit,
    onCloseOthers: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onCut: () -> Unit,
    onCopy: () -> Unit,
    onPaste: () -> Unit,
    onFind: () -> Unit,
    onInsertDateTime: () -> Unit,
    onGotoLine: () -> Unit,
    onCompare: () -> Unit,
    onSelectAll: () -> Unit,
    onSelectWord: () -> Unit,
    onSelectLine: () -> Unit,
    onSelectParagraph: () -> Unit,
    onUppercase: () -> Unit,
    onLowercase: () -> Unit,
    onIndent: () -> Unit,
    onUnindent: () -> Unit,
    onToggleComment: () -> Unit,
    onMoveLineUp: () -> Unit,
    onMoveLineDown: () -> Unit,
    onTrim: () -> Unit,
    onTrimLeading: () -> Unit,
    onJoinLines: () -> Unit,
    onReverseLines: () -> Unit,
    onRemoveDuplicateLines: () -> Unit,
    onSort: () -> Unit,
    onDuplicateLine: () -> Unit,
    onDeleteLine: () -> Unit,
    onLanguageSelect: (DocumentLanguage) -> Unit,
    commentEnabled: Boolean,
    previewEnabled: Boolean,
    previewActive: Boolean,
    onTogglePreview: () -> Unit,
    onToggleReadMode: () -> Unit,
    onToggleZenMode: () -> Unit,
    onToggleLayoutMode: () -> Unit,
    onToggleTrackpad: () -> Unit,
    onFontSizeDown: () -> Unit,
    onFontSizeUp: () -> Unit,
    onToggleWordWrap: () -> Unit,
    onToggleLineNumbers: () -> Unit,
    onToggleAccessoryBar: () -> Unit,
    onCycleTheme: () -> Unit,
    onPreferences: () -> Unit,
    onAppearancePreferences: () -> Unit,
    onToolbarPreferences: () -> Unit,
    onShowAbout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    fun run(action: () -> Unit) {
        onDismiss()
        action()
    }

    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.border.toColor()),
        shape = RoundedCornerShape(topStart = palette.radius.dp, topEnd = palette.radius.dp),
        modifier = modifier
            .fillMaxWidth()
            .heightIn(max = 560.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 10.dp),
            verticalArrangement = Arrangement.spacedBy(0.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            listOf(palette.chromeGradientStart.toColor(), palette.chromeGradientEnd.toColor()),
                        ),
                    )
                    .border(1.dp, palette.border.toColor())
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "More",
                    color = palette.foreground.toColor(),
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = onDismiss, modifier = Modifier.size(34.dp)) {
                    Icon(Icons.Filled.Close, contentDescription = "Close menu", tint = palette.foreground.toColor())
                }
            }

            mobileMenuSections(MobileMenuSurface.MENU_BAR).forEach { section ->
                MenuSectionHeader(section.title, palette)
                section.rows.forEach { row ->
                    val title = row.title
                    when (section.title) {
                        "File" -> when (title) {
                            "New blank" -> MenuActionRow(Icons.AutoMirrored.Filled.NoteAdd, title, palette) { run(onNew) }
                            "Open documents" -> MenuActionRow(Icons.AutoMirrored.Filled.List, title, palette) { run(onOpenDocuments) }
                            "Open from Files" -> MenuActionRow(Icons.Filled.FolderOpen, title, palette) { run(onOpenFile) }
                            "Save" -> MenuActionRow(Icons.Filled.Save, title, palette) { run(onSave) }
                            "Duplicate current" -> MenuActionRow(Icons.Filled.ContentCopy, title, palette) { run(onDuplicateDocument) }
                            "Rename current" -> MenuActionRow(Icons.Filled.Edit, title, palette) { run(onRenameDocument) }
                            "Close current" -> MenuActionRow(Icons.Filled.Close, title, palette, destructive = true) { run(onCloseDocument) }
                            "Close others" -> MenuActionRow(Icons.Filled.DisabledByDefault, title, palette) { run(onCloseOthers) }
                        }
                        "Edit" -> when (title) {
                            "Undo" -> MenuActionRow(Icons.AutoMirrored.Filled.Undo, title, palette, enabled = canUndo) { run(onUndo) }
                            "Redo" -> MenuActionRow(Icons.AutoMirrored.Filled.Redo, title, palette, enabled = canRedo) { run(onRedo) }
                            "Cut" -> MenuActionRow(Icons.Filled.ContentCut, title, palette, enabled = !readMode) { run(onCut) }
                            "Copy" -> MenuActionRow(Icons.Filled.ContentCopy, title, palette) { run(onCopy) }
                            "Paste" -> MenuActionRow(Icons.Filled.ContentPaste, title, palette, enabled = !readMode) { run(onPaste) }
                            "Select all" -> MenuActionRow(Icons.Filled.SelectAll, title, palette) { run(onSelectAll) }
                            "Select word" -> MenuActionRow(Icons.AutoMirrored.Filled.ShortText, title, palette) { run(onSelectWord) }
                            "Select line" -> MenuActionRow(Icons.AutoMirrored.Filled.Subject, title, palette) { run(onSelectLine) }
                            "Select paragraph" -> MenuActionRow(Icons.Filled.FormatAlignJustify, title, palette) { run(onSelectParagraph) }
                            "Insert date/time" -> MenuActionRow(Icons.Filled.AccessTime, title, palette, enabled = !readMode) { run(onInsertDateTime) }
                            "Uppercase selection" -> MenuActionRow(Icons.Filled.FormatSize, title, palette, enabled = !readMode) { run(onUppercase) }
                            "Lowercase selection" -> MenuActionRow(Icons.Filled.TextFields, title, palette, enabled = !readMode) { run(onLowercase) }
                            "Indent" -> MenuActionRow(Icons.AutoMirrored.Filled.FormatIndentIncrease, title, palette, enabled = !readMode) { run(onIndent) }
                            "Unindent" -> MenuActionRow(Icons.AutoMirrored.Filled.FormatIndentDecrease, title, palette, enabled = !readMode) { run(onUnindent) }
                            "Toggle comment" -> MenuActionRow(Icons.Filled.Code, title, palette, enabled = !readMode && commentEnabled) { run(onToggleComment) }
                        }
                        "Search" -> when (title) {
                            "Find/Replace" -> MenuActionRow(Icons.Filled.Search, title, palette) { run(onFind) }
                            "Go to line" -> MenuActionRow(Icons.AutoMirrored.Filled.KeyboardTab, title, palette) { run(onGotoLine) }
                            "Compare documents" -> MenuActionRow(Icons.Filled.ViewColumn, title, palette) { run(onCompare) }
                        }
                        "View" -> when (title) {
                            "Read mode" -> MenuActionRow(if (readMode) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, title, palette, checked = readMode) { run(onToggleReadMode) }
                            "Zen mode" -> MenuActionRow(if (zenMode) Icons.Filled.FullscreenExit else Icons.Filled.Fullscreen, title, palette, checked = zenMode) { run(onToggleZenMode) }
                            "Preview markdown" -> MenuActionRow(Icons.Filled.Visibility, title, palette, enabled = previewEnabled, checked = previewActive) { run(onTogglePreview) }
                            "Virtual trackpad" -> MenuActionRow(Icons.Filled.TouchApp, title, palette, checked = trackpadActive) { run(onToggleTrackpad) }
                            "Switch to classic layout" -> MenuActionRow(Icons.Filled.DesktopWindows, layoutMode.toggleLabel, palette) { run(onToggleLayoutMode) }
                            "Word wrap" -> MenuActionRow(Icons.AutoMirrored.Filled.WrapText, title, palette, checked = displayOptions.wordWrap) { run(onToggleWordWrap) }
                            "Line numbers" -> MenuActionRow(Icons.Filled.FormatListNumbered, title, palette, checked = displayOptions.lineNumbers) { run(onToggleLineNumbers) }
                            "Keyboard toolbar" -> MenuActionRow(Icons.Filled.Keyboard, title, palette, checked = displayOptions.accessoryBar) { run(onToggleAccessoryBar) }
                        }
                        "Language" -> {
                            val language = DocumentLanguage.selectableLanguages.firstOrNull { it.displayName == title }
                            if (language != null) {
                                MenuActionRow(Icons.Filled.Code, title, palette, checked = language == activeLanguage) {
                                    run { onLanguageSelect(language) }
                                }
                            }
                        }
                        "Settings" -> when (title) {
                            "Preferences" -> MenuActionRow(Icons.Filled.Settings, title, palette, subtitle = "Full-screen settings page") { run(onPreferences) }
                            "Appearance preferences" -> MenuActionRow(Icons.Filled.Palette, title, palette, subtitle = "Themes and layout") { run(onAppearancePreferences) }
                            "Toolbar preferences" -> MenuActionRow(Icons.Filled.Keyboard, title, palette, subtitle = "Rows, size, pinned buttons") { run(onToolbarPreferences) }
                            "Cycle theme" -> MenuActionRow(Icons.Filled.Palette, title, palette) { run(onCycleTheme) }
                        }
                        "Tools" -> when (title) {
                            "Duplicate current line" -> MenuActionRow(Icons.Filled.AddBox, title, palette, enabled = !readMode) { run(onDuplicateLine) }
                            "Delete current line" -> MenuActionRow(Icons.Filled.IndeterminateCheckBox, title, palette, enabled = !readMode, destructive = true) { run(onDeleteLine) }
                            "Move line up" -> MenuActionRow(Icons.Filled.KeyboardArrowUp, title, palette, enabled = !readMode) { run(onMoveLineUp) }
                            "Move line down" -> MenuActionRow(Icons.Filled.KeyboardArrowDown, title, palette, enabled = !readMode) { run(onMoveLineDown) }
                            "Sort lines" -> MenuActionRow(Icons.Filled.SortByAlpha, title, palette, enabled = !readMode) { run(onSort) }
                            "Trim trailing spaces" -> MenuActionRow(Icons.AutoMirrored.Filled.FormatAlignLeft, title, palette, enabled = !readMode) { run(onTrim) }
                            "Trim leading spaces" -> MenuActionRow(Icons.Filled.ContentCut, title, palette, enabled = !readMode) { run(onTrimLeading) }
                            "Join selected lines" -> MenuActionRow(Icons.AutoMirrored.Filled.FormatAlignLeft, title, palette, enabled = !readMode) { run(onJoinLines) }
                            "Reverse lines" -> MenuActionRow(Icons.Filled.SwapVert, title, palette, enabled = !readMode) { run(onReverseLines) }
                            "Unique lines" -> MenuActionRow(Icons.Filled.FilterList, title, palette, enabled = !readMode) { run(onRemoveDuplicateLines) }
                        }
                        "Help" -> when (title) {
                            "About Notepad 3++" -> MenuActionRow(Icons.Filled.Info, title, palette) { run(onShowAbout) }
                        }
                    }
                }
                if (section.title == "View") {
                    MenuFontRow(displayOptions.fontSizeSp, palette, onFontSizeDown, onFontSizeUp)
                }
            }
        }
    }
}

@Composable
private fun MenuSectionHeader(text: String, palette: Palette) {
    Text(
        text = text.uppercase(Locale.ROOT),
        color = palette.mutedForeground.toColor(),
        style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp, fontWeight = FontWeight.Bold),
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.muted.toColor().copy(alpha = 0.55f))
            .padding(horizontal = 14.dp, vertical = 6.dp),
    )
}

@Composable
private fun MenuActionRow(
    icon: ImageVector,
    title: String,
    palette: Palette,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    enabled: Boolean = true,
    checked: Boolean = false,
    destructive: Boolean = false,
    onClick: () -> Unit,
) {
    val color = when {
        !enabled -> palette.mutedForeground.toColor().copy(alpha = 0.50f)
        destructive -> palette.destructive.toColor()
        else -> palette.foreground.toColor()
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(21.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                color = color,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    color = palette.mutedForeground.toColor(),
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (checked) {
            Icon(Icons.Filled.Check, contentDescription = null, tint = palette.primary.toColor(), modifier = Modifier.size(19.dp))
        }
    }
}

@Composable
private fun MenuFontRow(
    fontSizeSp: Int,
    palette: Palette,
    onFontSizeDown: () -> Unit,
    onFontSizeUp: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.FormatSize, contentDescription = null, tint = palette.foreground.toColor(), modifier = Modifier.size(21.dp))
        Text(
            text = "Font size",
            color = palette.foreground.toColor(),
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
            modifier = Modifier.weight(1f),
        )
        CommandButton(text = "-", palette = palette, modifier = Modifier.size(width = 44.dp, height = 30.dp), onClick = onFontSizeDown)
        Text(
            text = "$fontSizeSp sp",
            color = palette.mutedForeground.toColor(),
            style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
        )
        CommandButton(text = "+", palette = palette, modifier = Modifier.size(width = 44.dp, height = 30.dp), onClick = onFontSizeUp)
    }
}

private class EditorEditText(context: android.content.Context) : EditText(context) {
    var editableKeyListener: KeyListener? = null
    var selectionChangedCallback: ((TextSelection) -> Unit)? = null
    var showLineNumbers: Boolean = true
        set(value) {
            field = value
            syncGutterPadding()
            invalidate()
        }
    private var gutterReady = false
    private val lineBounds = Rect()
    private val gutterBackgroundPaint = Paint()
    private val gutterDividerPaint = Paint()
    private val lineNumberPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.RIGHT
    }
    private var textPaddingLeftPx = 18
    private var textPaddingTopPx = 18
    private var textPaddingRightPx = 18
    private var textPaddingBottomPx = 18
    private var gutterSidePaddingPx = 10

    init {
        gutterReady = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            setAutoHandwritingEnabled(false)
        }
    }

    fun configureGutter(palette: Palette, showLineNumbers: Boolean) {
        this.showLineNumbers = showLineNumbers
        gutterBackgroundPaint.color = AndroidColor.parseColor(palette.muted)
        gutterDividerPaint.color = AndroidColor.parseColor(palette.border)
        gutterDividerPaint.strokeWidth = 1f
        lineNumberPaint.color = AndroidColor.parseColor(palette.mutedForeground)
        lineNumberPaint.typeface = Typeface.MONOSPACE
        lineNumberPaint.textSize = textSize
        syncGutterPadding()
        invalidate()
    }

    fun setEditorContentPadding(left: Int, top: Int, right: Int, bottom: Int) {
        textPaddingLeftPx = left
        textPaddingTopPx = top
        textPaddingRightPx = right
        textPaddingBottomPx = bottom
        syncGutterPadding()
    }

    override fun onSelectionChanged(selStart: Int, selEnd: Int) {
        super.onSelectionChanged(selStart, selEnd)
        if (selStart >= 0 && selEnd >= 0) {
            selectionChangedCallback?.invoke(TextSelection(selStart, selEnd))
        }
    }

    override fun onTextChanged(text: CharSequence?, start: Int, lengthBefore: Int, lengthAfter: Int) {
        super.onTextChanged(text, start, lengthBefore, lengthAfter)
        syncGutterPadding()
    }

    override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection? {
        val connection = super.onCreateInputConnection(outAttrs)
        outAttrs.imeOptions = outAttrs.imeOptions or
            EditorInfo.IME_FLAG_NO_EXTRACT_UI or
            EditorInfo.IME_FLAG_NO_FULLSCREEN
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            outAttrs.setStylusHandwritingEnabled(false)
        }
        return connection
    }

    override fun onDraw(canvas: Canvas) {
        drawLineNumberGutter(canvas)
        super.onDraw(canvas)
    }

    private fun drawLineNumberGutter(canvas: Canvas) {
        if (!gutterReady || !showLineNumbers) return
        val body = text?.toString().orEmpty()
        val gutterWidth = gutterWidthPx(body)
        val left = scrollX.toFloat()
        val top = scrollY.toFloat()
        val right = left + gutterWidth
        val bottom = top + height
        canvas.drawRect(left, top, right, bottom, gutterBackgroundPaint)
        canvas.drawLine(right - 1f, top, right - 1f, bottom, gutterDividerPaint)

        val layout = layout ?: return
        val firstVisibleLine = layout.getLineForVertical(scrollY)
        val lastVisibleLine = layout.getLineForVertical(scrollY + height)
        var previousLogicalLine = 0
        for (visualLine in firstVisibleLine..lastVisibleLine) {
            val lineStart = layout.getLineStart(visualLine)
            val logicalLine = EditorGutter.logicalLineNumberAtOffset(body, lineStart)
            if (logicalLine == previousLogicalLine) continue
            previousLogicalLine = logicalLine
            val baseline = getLineBounds(visualLine, lineBounds)
            canvas.drawText(
                logicalLine.toString(),
                right - gutterSidePaddingPx,
                baseline.toFloat(),
                lineNumberPaint,
            )
        }
    }

    private fun syncGutterPadding() {
        if (!gutterReady) return
        val left = if (showLineNumbers) {
            EditorGutter.totalLeftPaddingPx(
                lineCount = EditorGutter.visibleLineCount(text?.toString().orEmpty()),
                digitWidthPx = lineNumberPaint.measureText("0"),
                sidePaddingPx = gutterSidePaddingPx,
                textPaddingPx = textPaddingLeftPx,
            )
        } else {
            textPaddingLeftPx
        }
        if (
            paddingLeft != left ||
            paddingTop != textPaddingTopPx ||
            paddingRight != textPaddingRightPx ||
            paddingBottom != textPaddingBottomPx
        ) {
            super.setPadding(left, textPaddingTopPx, textPaddingRightPx, textPaddingBottomPx)
        }
    }

    private fun gutterWidthPx(body: String): Int =
        EditorGutter.gutterWidthPx(
            lineCount = EditorGutter.visibleLineCount(body),
            digitWidthPx = lineNumberPaint.measureText("0"),
            sidePaddingPx = gutterSidePaddingPx,
        )
}

@Composable
private fun EditorTextArea(
    document: TextDocument,
    palette: Palette,
    selection: TextSelection,
    readOnly: Boolean,
    fontSizeSp: Int,
    wordWrap: Boolean,
    showLineNumbers: Boolean,
    keyboardSuppressed: Boolean,
    onSelectionChange: (TextSelection) -> Unit,
    onFocusChange: (Boolean) -> Unit,
    onEditorReady: (EditorEditText) -> Unit,
    onBodyChange: (String, TextSelection) -> Unit,
    modifier: Modifier = Modifier,
) {
    val latestBody = rememberUpdatedState(document.body)
    val latestOnBodyChange = rememberUpdatedState(onBodyChange)
    val latestOnSelectionChange = rememberUpdatedState(onSelectionChange)
    val latestOnFocusChange = rememberUpdatedState(onFocusChange)
    val latestOnEditorReady = rememberUpdatedState(onEditorReady)

    AndroidView(
        modifier = modifier
            .fillMaxWidth()
            .onFocusChanged { onFocusChange(it.isFocused) }
            .border(1.dp, palette.border.toColor(), RoundedCornerShape(palette.radius.dp)),
        factory = { context ->
            EditorEditText(context).apply {
                showSoftInputOnFocus = shouldShowSoftKeyboardOnEditorFocus(readOnly, keyboardSuppressed)
                setOnFocusChangeListener { view, hasFocus ->
                    latestOnFocusChange.value(hasFocus)
                    if (hasFocus && shouldShowSoftKeyboardOnEditorFocus(readOnly, keyboardSuppressed)) {
                        (view as? EditText)?.showSoftKeyboard()
                    }
                }
                selectionChangedCallback = { latestOnSelectionChange.value(it) }
                latestOnEditorReady.value(this)
                gravity = Gravity.TOP or Gravity.START
                isSingleLine = false
                minLines = 12
                typeface = Typeface.MONOSPACE
                inputType = InputType.TYPE_CLASS_TEXT or
                    InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                    InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                editableKeyListener = keyListener
                setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp.toFloat())
                setHorizontallyScrolling(!wordWrap)
                setEditorContentPadding(18, 18, 18, 18)
                configureGutter(palette, showLineNumbers)
                setText(document.body)
                addTextChangedListener(object : TextWatcher {
                    private var pendingSelection: TextSelection? = null

                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                        pendingSelection = TextSelection(start + count)
                    }

                    override fun afterTextChanged(s: Editable?) {
                        val next = s?.toString().orEmpty()
                        val nativeSelection = TextSelection(selectionStart, selectionEnd).clamped(next.length)
                        val editSelection = pendingSelection?.clamped(next.length)
                        val nextSelection = maxOfSelection(nativeSelection, editSelection)
                        if (selectionStart != nextSelection.start || selectionEnd != nextSelection.end) {
                            setSelection(nextSelection.start, nextSelection.end)
                        }
                        pendingSelection = null
                        if (next != latestBody.value) {
                            latestOnBodyChange.value(next, nextSelection)
                        } else {
                            latestOnSelectionChange.value(nextSelection)
                        }
                    }
                })
            }
        },
        update = { editText ->
            latestOnEditorReady.value(editText)
            val shouldShowSoftKeyboard = shouldShowSoftKeyboardOnEditorFocus(readOnly, keyboardSuppressed)
            editText.setOnFocusChangeListener { view, hasFocus ->
                latestOnFocusChange.value(hasFocus)
                if (hasFocus && shouldShowSoftKeyboard) {
                    (view as? EditText)?.showSoftKeyboard()
                }
            }
            editText.selectionChangedCallback = { latestOnSelectionChange.value(it) }
            val safeSelection = selection.clamped(document.body.length)
            val bodyChangedExternally = editText.text.toString() != document.body
            editText.isCursorVisible = !readOnly
            editText.showSoftInputOnFocus = shouldShowSoftKeyboard
            if (readOnly) {
                editText.keyListener = null
            } else if (editText.keyListener == null) {
                editText.keyListener = editText.editableKeyListener
            }
            if (editText.isFocused && shouldShowSoftKeyboard) {
                editText.showSoftKeyboard()
            } else if (editText.isFocused) {
                editText.hideSoftKeyboardNow()
            }
            editText.setTextColor(palette.foreground.toColor().toArgb())
            editText.setBackgroundColor(palette.editorBackground.toColor().toArgb())
            editText.setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp.toFloat())
            editText.setHorizontallyScrolling(!wordWrap)
            editText.configureGutter(palette, showLineNumbers)
            if (bodyChangedExternally) {
                editText.setText(document.body)
            }
            if (
                editText.selectionStart != safeSelection.start ||
                editText.selectionEnd != safeSelection.end
            ) {
                editText.setSelection(safeSelection.start, safeSelection.end)
            }
        },
    )
}

@Composable
private fun StatusBar(document: TextDocument, selection: TextSelection, readOnly: Boolean, palette: Palette) {
    Text(
        text = EditorStatus.summary(
            languageName = document.language.displayName,
            body = document.body,
            selection = selection,
            readOnly = readOnly,
        ),
        color = palette.mutedForeground.toColor(),
        style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp),
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.muted.toColor(), RoundedCornerShape(palette.radius.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

@Composable
private fun MobileBottomBar(
    palette: Palette,
    compareEnabled: Boolean,
    compareActive: Boolean,
    findActive: Boolean,
    onOpen: () -> Unit,
    onFind: () -> Unit,
    onCompare: () -> Unit,
    onSwitchToClassic: () -> Unit,
    onMore: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .background(palette.card.toColor())
            .border(1.dp, palette.border.toColor())
            .padding(horizontal = 4.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.SpaceAround,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        MobileNavButton(icon = Icons.Filled.FolderOpen, label = "File", palette = palette, modifier = Modifier.weight(1f), onClick = onOpen)
        MobileNavButton(icon = Icons.Filled.Search, label = "Find", palette = palette, active = findActive, modifier = Modifier.weight(1f), onClick = onFind)
        MobileNavButton(
            icon = Icons.Filled.ViewColumn,
            label = "Compare",
            palette = palette,
            active = compareActive,
            enabled = compareEnabled,
            modifier = Modifier.weight(1f),
            onClick = onCompare,
        )
        MobileNavButton(icon = Icons.Filled.DesktopWindows, label = "Classic", palette = palette, modifier = Modifier.weight(1f), onClick = onSwitchToClassic)
        MobileNavButton(icon = Icons.Filled.MoreHoriz, label = "More", palette = palette, modifier = Modifier.weight(1f), onClick = onMore)
    }
}

@Composable
private fun TrackpadPanel(
    palette: Palette,
    onMoveLeft: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onMoveRight: () -> Unit,
    onHide: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = palette.card.toColor(),
        border = BorderStroke(1.dp, palette.primary.toColor()),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = modifier.widthIn(min = 220.dp, max = 280.dp),
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Trackpad",
                    color = palette.foreground.toColor(),
                    style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = onHide, modifier = Modifier.size(30.dp)) {
                    Icon(Icons.Filled.Close, contentDescription = "Hide trackpad", tint = palette.foreground.toColor())
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                Spacer(Modifier.weight(1f))
                CommandButton(text = "^", palette = palette, modifier = Modifier.weight(1f), onClick = onMoveUp)
                Spacer(Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(text = "<", palette = palette, modifier = Modifier.weight(1f), onClick = onMoveLeft)
                CommandButton(text = "v", palette = palette, modifier = Modifier.weight(1f), onClick = onMoveDown)
                CommandButton(text = ">", palette = palette, modifier = Modifier.weight(1f), onClick = onMoveRight)
            }
        }
    }
}

@Composable
private fun MobileKeyboardAccessory(
    palette: Palette,
    displayOptions: EditorDisplayOptions,
    canUndo: Boolean,
    canRedo: Boolean,
    canCut: Boolean,
    canPaste: Boolean,
    readOnly: Boolean,
    shiftActive: Boolean,
    keyboardSuppressed: Boolean,
    findActive: Boolean,
    compareEnabled: Boolean,
    compareActive: Boolean,
    onToggleKeyboardSuppression: () -> Unit,
    onReadToggle: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onCut: () -> Unit,
    onCopy: () -> Unit,
    onPaste: () -> Unit,
    onShiftToggle: () -> Unit,
    onDeleteBackward: () -> Unit,
    onMoveLeft: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onMoveRight: () -> Unit,
    onMoveHome: () -> Unit,
    onMoveEnd: () -> Unit,
    onPageUp: () -> Unit,
    onPageDown: () -> Unit,
    onFind: () -> Unit,
    onInsertDateTime: () -> Unit,
    onInsertText: (String) -> Unit,
    onOpenDocuments: () -> Unit,
    onSelectAll: () -> Unit,
    onSelectWord: () -> Unit,
    onSelectLine: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
) {
    val buttonSize = displayOptions.accessoryToolbarButtonSize
    val keyboardToggle = keyboardAccessoryToggleState(
        keyboardSuppressed = keyboardSuppressed,
        readOnly = readOnly,
    )
    var deckPage by rememberSaveable { mutableStateOf(defaultAccessoryDeckPage()) }
    var ctrlActive by rememberSaveable { mutableStateOf(false) }
    var altActive by rememberSaveable { mutableStateOf(false) }
    val stripHeight = when (buttonSize) {
        AccessoryToolbarButtonSize.SMALL -> 50
        AccessoryToolbarButtonSize.MEDIUM -> 56
        AccessoryToolbarButtonSize.LARGE -> 62
    }
    val keyHeight = when (buttonSize) {
        AccessoryToolbarButtonSize.SMALL -> 58
        AccessoryToolbarButtonSize.MEDIUM -> 66
        AccessoryToolbarButtonSize.LARGE -> 74
    }
    val railWidth = when (buttonSize) {
        AccessoryToolbarButtonSize.SMALL -> 54
        AccessoryToolbarButtonSize.MEDIUM -> 62
        AccessoryToolbarButtonSize.LARGE -> 70
    }
    val deckBackground = Color(0xFF373737)
    val deckBorder = Color(0xFF4A4A4A)
    var dragTotal by remember { mutableStateOf(0f) }
    fun showNextDeckPage() {
        deckPage = nextAccessoryDeckPage(deckPage)
    }
    fun showPreviousDeckPage() {
        deckPage = previousAccessoryDeckPage(deckPage)
    }

    fun renderKey(spec: AccessoryDeckKeySpec): AccessoryDeckRenderKey {
        val enabled = when (spec.id) {
            AccessoryDeckActionId.BACKSPACE,
            AccessoryDeckActionId.ENTER,
            AccessoryDeckActionId.TAB,
            AccessoryDeckActionId.INSERT_TEXT,
            AccessoryDeckActionId.INSERT_DATE -> !readOnly
            AccessoryDeckActionId.CUT -> canCut
            AccessoryDeckActionId.PASTE -> canPaste && !readOnly
            AccessoryDeckActionId.UNDO -> canUndo
            AccessoryDeckActionId.REDO -> canRedo
            AccessoryDeckActionId.COMPARE -> compareEnabled
            AccessoryDeckActionId.HIDE_KEYBOARD,
            AccessoryDeckActionId.ESCAPE -> keyboardToggle.enabled
            else -> true
        }
        val active = when (spec.id) {
            AccessoryDeckActionId.SHIFT -> shiftActive
            AccessoryDeckActionId.CTRL -> ctrlActive
            AccessoryDeckActionId.ALT -> altActive
            AccessoryDeckActionId.READ_MODE -> readOnly
            AccessoryDeckActionId.FIND -> findActive
            AccessoryDeckActionId.COMPARE -> compareActive
            AccessoryDeckActionId.SWITCH_DECK -> keyboardSuppressed
            AccessoryDeckActionId.HIDE_KEYBOARD,
            AccessoryDeckActionId.ESCAPE -> keyboardToggle.active
            else -> false
        }
        val icon = when (spec.id) {
            AccessoryDeckActionId.OPEN_DOCUMENTS -> Icons.Filled.Window
            AccessoryDeckActionId.COPY -> Icons.Filled.ContentCopy
            AccessoryDeckActionId.CUT -> Icons.Filled.ContentCut
            AccessoryDeckActionId.PASTE -> Icons.Filled.ContentPaste
            AccessoryDeckActionId.BACKSPACE -> Icons.AutoMirrored.Filled.Backspace
            AccessoryDeckActionId.SWITCH_DECK -> Icons.AutoMirrored.Filled.CompareArrows
            AccessoryDeckActionId.UNDO -> Icons.AutoMirrored.Filled.Undo
            AccessoryDeckActionId.REDO -> Icons.AutoMirrored.Filled.Redo
            AccessoryDeckActionId.FIND -> Icons.Filled.Search
            AccessoryDeckActionId.SELECT_WORD -> Icons.AutoMirrored.Filled.ShortText
            AccessoryDeckActionId.SELECT_LINE -> Icons.AutoMirrored.Filled.Subject
            AccessoryDeckActionId.SELECT_ALL -> Icons.Filled.SelectAll
            AccessoryDeckActionId.INSERT_DATE -> Icons.Filled.AccessTime
            AccessoryDeckActionId.READ_MODE -> if (readOnly) Icons.Filled.Visibility else Icons.Filled.VisibilityOff
            AccessoryDeckActionId.COMPARE -> Icons.Filled.ViewColumn
            AccessoryDeckActionId.MORE -> Icons.Filled.MoreHoriz
            AccessoryDeckActionId.HIDE_KEYBOARD -> Icons.Filled.Keyboard
            AccessoryDeckActionId.MOVE_UP -> Icons.Filled.KeyboardArrowUp
            AccessoryDeckActionId.MOVE_DOWN -> Icons.Filled.KeyboardArrowDown
            AccessoryDeckActionId.MOVE_LEFT -> Icons.AutoMirrored.Filled.KeyboardArrowLeft
            AccessoryDeckActionId.MOVE_RIGHT -> Icons.AutoMirrored.Filled.KeyboardArrowRight
            else -> null
        }
        return AccessoryDeckRenderKey(
            spec = spec,
            icon = icon,
            enabled = enabled,
            active = active,
            labelOverride = accessoryDeckVisualLabel(spec, deckPage),
            onClick = {
                when (spec.id) {
                    AccessoryDeckActionId.OPEN_DOCUMENTS -> onOpenDocuments()
                    AccessoryDeckActionId.ESCAPE,
                    AccessoryDeckActionId.HIDE_KEYBOARD -> onToggleKeyboardSuppression()
                    AccessoryDeckActionId.SHIFT -> onShiftToggle()
                    AccessoryDeckActionId.CTRL -> ctrlActive = !ctrlActive
                    AccessoryDeckActionId.ALT -> altActive = !altActive
                    AccessoryDeckActionId.ENTER,
                    AccessoryDeckActionId.TAB,
                    AccessoryDeckActionId.INSERT_TEXT -> spec.insertText?.let(onInsertText)
                    AccessoryDeckActionId.COPY -> onCopy()
                    AccessoryDeckActionId.CUT -> onCut()
                    AccessoryDeckActionId.PASTE -> onPaste()
                    AccessoryDeckActionId.PAGE_DOTS,
                    AccessoryDeckActionId.SWITCH_DECK -> showNextDeckPage()
                    AccessoryDeckActionId.BACKSPACE -> onDeleteBackward()
                    AccessoryDeckActionId.UNDO -> onUndo()
                    AccessoryDeckActionId.REDO -> onRedo()
                    AccessoryDeckActionId.FIND -> onFind()
                    AccessoryDeckActionId.SELECT_WORD -> onSelectWord()
                    AccessoryDeckActionId.SELECT_LINE -> onSelectLine()
                    AccessoryDeckActionId.SELECT_ALL -> onSelectAll()
                    AccessoryDeckActionId.INSERT_DATE -> onInsertDateTime()
                    AccessoryDeckActionId.READ_MODE -> onReadToggle()
                    AccessoryDeckActionId.COMPARE -> onCompare()
                    AccessoryDeckActionId.MORE -> onMore()
                    AccessoryDeckActionId.HOME -> onMoveHome()
                    AccessoryDeckActionId.END -> onMoveEnd()
                    AccessoryDeckActionId.PAGE_UP -> onPageUp()
                    AccessoryDeckActionId.PAGE_DOWN -> onPageDown()
                    AccessoryDeckActionId.MOVE_LEFT -> onMoveLeft()
                    AccessoryDeckActionId.MOVE_UP -> onMoveUp()
                    AccessoryDeckActionId.MOVE_DOWN -> onMoveDown()
                    AccessoryDeckActionId.MOVE_RIGHT -> onMoveRight()
                    AccessoryDeckActionId.PRINT_SCREEN,
                    AccessoryDeckActionId.SCROLL_LOCK,
                    AccessoryDeckActionId.BREAK,
                    AccessoryDeckActionId.INSERT -> Unit
                }
            },
        )
    }

    if (!keyboardSuppressed) {
        CompactKeyboardAccessoryStrip(
            palette = palette,
            buttonSize = buttonSize,
            renderKey = ::renderKey,
            onShowDeck = onToggleKeyboardSuppression,
        )
        return
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height((stripHeight + keyHeight * 4 + 42).dp)
            .animateContentSize()
            .background(deckBackground)
            .border(2.dp, deckBorder)
            .pointerInput(deckPage) {
                detectHorizontalDragGestures(
                    onDragStart = { dragTotal = 0f },
                    onHorizontalDrag = { _, dragAmount ->
                        dragTotal += dragAmount
                    },
                    onDragEnd = {
                        when {
                            dragTotal <= -72f -> showNextDeckPage()
                            dragTotal >= 72f -> showPreviousDeckPage()
                        }
                        dragTotal = 0f
                    },
                    onDragCancel = {
                        dragTotal = 0f
                    },
                )
            }
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(stripHeight.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val modifierSpecs = accessoryDeckModifierStrip()
            val switchSpec = AccessoryDeckKeySpec(AccessoryDeckActionId.SWITCH_DECK, "ABC")
            modifierSpecs.take(1).forEach { spec ->
                AccessoryDeckKeyButton(
                    key = renderKey(spec),
                    keyHeight = stripHeight,
                    iconOnly = true,
                    textScale = 0.27f,
                    modifier = Modifier.width(railWidth.dp),
                )
            }
            Row(
                modifier = Modifier
                    .weight(1f)
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                modifierSpecs.drop(1).forEach { spec ->
                    AccessoryDeckKeyButton(
                        key = renderKey(spec),
                        keyHeight = stripHeight,
                        textOnly = true,
                        textScale = 0.27f,
                        modifier = Modifier.width(86.dp),
                    )
                }
            }
            AccessoryDeckKeyButton(
                key = renderKey(switchSpec).copy(
                    onClick = onToggleKeyboardSuppression,
                    labelOverride = "Keyboard",
                ),
                keyHeight = stripHeight,
                iconOnly = true,
                textScale = 0.27f,
                modifier = Modifier.width(railWidth.dp),
            )
        }
        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier
                    .width(railWidth.dp)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                accessoryDeckLeftRail().forEach { spec ->
                    AccessoryDeckKeyButton(
                        key = renderKey(spec),
                        keyHeight = keyHeight,
                        modifier = Modifier.weight(1f),
                        iconOnly = spec.id != AccessoryDeckActionId.PAGE_DOTS,
                    )
                }
            }
            AccessoryDeckPageGrid(
                page = deckPage,
                renderKey = ::renderKey,
                keyHeight = keyHeight,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
            )
            Column(
                modifier = Modifier
                    .width(railWidth.dp)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                val rightRail = accessoryDeckRightRail()
                AccessoryDeckKeyButton(
                    key = renderKey(rightRail.first()),
                    keyHeight = keyHeight,
                    modifier = Modifier.weight(1f),
                    iconOnly = true,
                )
                Spacer(Modifier.weight(1f))
                AccessoryDeckKeyButton(
                    key = renderKey(rightRail.last()),
                    keyHeight = keyHeight,
                    textOnly = true,
                    textScale = 0.28f,
                    modifier = Modifier.weight(2f),
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(16.dp),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .width(112.dp)
                    .height(5.dp)
                    .background(Color.White.copy(alpha = 0.48f), RoundedCornerShape(999.dp)),
            )
        }
    }
}

private data class AccessoryDeckRenderKey(
    val spec: AccessoryDeckKeySpec,
    val icon: ImageVector?,
    val enabled: Boolean,
    val active: Boolean,
    val onClick: () -> Unit,
    val labelOverride: String? = null,
) {
    val label: String
        get() = labelOverride ?: spec.label
    val accessibilityLabel: String
        get() = spec.label
}

@Composable
private fun CompactKeyboardAccessoryStrip(
    palette: Palette,
    buttonSize: AccessoryToolbarButtonSize,
    renderKey: (AccessoryDeckKeySpec) -> AccessoryDeckRenderKey,
    onShowDeck: () -> Unit,
) {
    val stripHeight = when (buttonSize) {
        AccessoryToolbarButtonSize.SMALL -> 50
        AccessoryToolbarButtonSize.MEDIUM -> 56
        AccessoryToolbarButtonSize.LARGE -> 62
    }
    val darkBackground = Color(0xFF3A3A3A)
    val darkBorder = Color(0xFF4A4A4A)
    val leftSpec = AccessoryDeckKeySpec(AccessoryDeckActionId.OPEN_DOCUMENTS, "Windows")
    val switchSpec = AccessoryDeckKeySpec(AccessoryDeckActionId.SWITCH_DECK, "Keys")
    val compactSpecs = listOf(
        AccessoryDeckKeySpec(AccessoryDeckActionId.ESCAPE, "esc"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.SHIFT, "shift"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.CTRL, "ctrl"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.ALT, "alt"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.ENTER, "enter", insertText = "\n"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.COPY, "Copy"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.CUT, "Cut"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.PASTE, "Paste"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.BACKSPACE, "Backspace", repeatOnHold = true),
        AccessoryDeckKeySpec(AccessoryDeckActionId.MOVE_LEFT, "Left", repeatOnHold = true),
        AccessoryDeckKeySpec(AccessoryDeckActionId.MOVE_UP, "Up", repeatOnHold = true),
        AccessoryDeckKeySpec(AccessoryDeckActionId.MOVE_DOWN, "Down", repeatOnHold = true),
        AccessoryDeckKeySpec(AccessoryDeckActionId.MOVE_RIGHT, "Right", repeatOnHold = true),
        AccessoryDeckKeySpec(AccessoryDeckActionId.FIND, "Find"),
        AccessoryDeckKeySpec(AccessoryDeckActionId.MORE, "More"),
    )
    val scrollState = rememberScrollState()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height((stripHeight + 14).dp)
            .background(darkBackground)
            .border(1.dp, darkBorder)
            .horizontalScroll(scrollState)
            .padding(horizontal = 8.dp, vertical = 7.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AccessoryDeckKeyButton(
            key = renderKey(leftSpec),
            keyHeight = stripHeight,
            iconOnly = true,
            textScale = 0.29f,
            modifier = Modifier.width(58.dp),
        )
        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .horizontalScroll(scrollState),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
        compactSpecs.forEach { spec ->
            val key = renderKey(spec)
            val fixedWidth = when (spec.id) {
                AccessoryDeckActionId.COPY,
                AccessoryDeckActionId.CUT,
                AccessoryDeckActionId.PASTE,
                AccessoryDeckActionId.BACKSPACE,
                AccessoryDeckActionId.FIND,
                AccessoryDeckActionId.MORE -> 54.dp
                AccessoryDeckActionId.MOVE_LEFT,
                AccessoryDeckActionId.MOVE_UP,
                AccessoryDeckActionId.MOVE_DOWN,
                AccessoryDeckActionId.MOVE_RIGHT -> 50.dp
                else -> 86.dp
            }
            AccessoryDeckKeyButton(
                key = key,
                keyHeight = stripHeight,
                iconOnly = spec.id in setOf(
                    AccessoryDeckActionId.COPY,
                    AccessoryDeckActionId.CUT,
                    AccessoryDeckActionId.PASTE,
                    AccessoryDeckActionId.BACKSPACE,
                    AccessoryDeckActionId.FIND,
                    AccessoryDeckActionId.MORE,
                ),
                textOnly = spec.id !in setOf(
                    AccessoryDeckActionId.COPY,
                    AccessoryDeckActionId.CUT,
                    AccessoryDeckActionId.PASTE,
                    AccessoryDeckActionId.BACKSPACE,
                    AccessoryDeckActionId.FIND,
                    AccessoryDeckActionId.MORE,
                    AccessoryDeckActionId.MOVE_LEFT,
                    AccessoryDeckActionId.MOVE_UP,
                    AccessoryDeckActionId.MOVE_DOWN,
                    AccessoryDeckActionId.MOVE_RIGHT,
                ),
                textScale = 0.29f,
                modifier = Modifier.width(fixedWidth),
            )
        }
        }
        AccessoryDeckKeyButton(
            key = renderKey(switchSpec).copy(
                onClick = onShowDeck,
                labelOverride = "Deck",
            ),
            keyHeight = stripHeight,
            iconOnly = true,
            textScale = 0.29f,
            modifier = Modifier.width(64.dp),
        )
    }
}

@Composable
private fun AccessoryDeckPageGrid(
    page: AccessoryDeckPage,
    renderKey: (AccessoryDeckKeySpec) -> AccessoryDeckRenderKey,
    keyHeight: Int,
    modifier: Modifier = Modifier,
) {
    val columns = accessoryDeckColumnCount(page)
    val rows = accessoryDeckRowCount(page)
    val keys = accessoryDeckKeys(page)
    var keyIndex = 0
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        repeat(rows) {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                var usedColumns = 0
                while (usedColumns < columns) {
                    val key = keys.getOrNull(keyIndex)
                    if (key == null) {
                        Spacer(Modifier.weight((columns - usedColumns).toFloat()))
                        usedColumns = columns
                    } else {
                        val span = key.columnSpan.coerceIn(1, columns - usedColumns)
                        AccessoryDeckKeyButton(
                            key = renderKey(key),
                            keyHeight = keyHeight,
                            textOnly = page == AccessoryDeckPage.NUMERIC,
                            textScale = if (page == AccessoryDeckPage.NUMERIC) 0.38f else 0.36f,
                            modifier = Modifier.weight(span.toFloat()),
                        )
                        keyIndex += 1
                        usedColumns += span
                    }
                }
            }
        }
    }
}

@Composable
private fun AccessoryDeckKeyButton(
    key: AccessoryDeckRenderKey,
    keyHeight: Int,
    modifier: Modifier = Modifier,
    textOnly: Boolean = false,
    iconOnly: Boolean = false,
    textScale: Float = 0.36f,
) {
    val shape = RoundedCornerShape(14.dp)
    val latestOnClick = rememberUpdatedState(key.onClick)
    val pressModifier = if (key.spec.repeatOnHold) {
        Modifier.pointerInput(key.enabled, key.spec.id) {
            detectTapGestures(
                onPress = {
                    if (!key.enabled) return@detectTapGestures
                    latestOnClick.value()
                    kotlinx.coroutines.coroutineScope {
                        val repeatJob = launch {
                            delay(accessoryRepeatPressSpec.initialDelayMillis)
                            var iteration = 0
                            while (true) {
                                latestOnClick.value()
                                delay(repeatDelayForIteration(iteration))
                                iteration += 1
                            }
                        }
                        try {
                            tryAwaitRelease()
                        } finally {
                            repeatJob.cancel()
                        }
                    }
                },
            )
        }
    } else {
        Modifier.clickable(enabled = key.enabled, onClick = key.onClick)
    }
    val foreground = when {
        !key.enabled -> Color.White.copy(alpha = 0.34f)
        key.active -> Color.White
        else -> Color.White
    }
    val background = when {
        key.active -> Color(0xFF4A4A4A)
        key.spec.id == AccessoryDeckActionId.INSERT_TEXT -> Color(0xFF101010)
        key.spec.id == AccessoryDeckActionId.PAGE_DOTS -> Color(0xFF343434)
        else -> Color(0xFF383838)
    }
    val resolvedTextScale = when {
        key.label.length >= 4 -> minOf(textScale, 0.28f)
        else -> textScale
    }
    Box(
        modifier = modifier
            .heightIn(min = keyHeight.dp)
            .background(background, shape)
            .border(
                2.dp,
                Color.White.copy(alpha = if (key.active) 0.18f else 0.055f),
                shape,
            )
            .then(pressModifier)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (key.icon != null && (!textOnly || iconOnly)) {
            Icon(
                key.icon,
                contentDescription = key.accessibilityLabel,
                tint = foreground,
                modifier = Modifier.size(
                    (keyHeight * when {
                        key.spec.id.isDeckArrowKey() -> 0.62f
                        iconOnly -> 0.46f
                        else -> 0.42f
                    }).dp,
                ),
            )
        } else {
            Text(
                text = key.label,
                color = foreground,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontSize = (keyHeight * when {
                        key.spec.id.isDeckArrowKey() -> 0.58f
                        key.spec.id == AccessoryDeckActionId.PAGE_DOTS -> 0.34f
                        else -> resolvedTextScale
                    }).sp,
                    fontWeight = if (key.spec.id.isDeckArrowKey()) FontWeight.Bold else FontWeight.SemiBold,
                ),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

private fun AccessoryDeckActionId.isDeckArrowKey(): Boolean =
    this == AccessoryDeckActionId.MOVE_UP ||
        this == AccessoryDeckActionId.MOVE_DOWN ||
        this == AccessoryDeckActionId.MOVE_LEFT ||
        this == AccessoryDeckActionId.MOVE_RIGHT

private data class AccessoryToolbarAction(
    val id: AccessoryToolbarButton,
    val icon: ImageVector? = null,
    val label: String = id.displayTitle,
    val enabled: Boolean = true,
    val active: Boolean = false,
    val onClick: () -> Unit,
)

@Composable
private fun AccessoryStaticCluster(
    actions: List<AccessoryToolbarAction>,
    toolbarRows: Int,
    buttonSize: AccessoryToolbarButtonSize,
    contentMode: AccessoryToolbarContentMode,
    palette: Palette,
) {
    val columns = ((actions.size + toolbarRows - 1) / toolbarRows).coerceAtLeast(1)
    Column(
        modifier = Modifier
            .width((buttonSize.minWidthDp(contentMode) * columns + 8).dp)
            .fillMaxHeight()
            .padding(horizontal = 4.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        repeat(toolbarRows) { rowIndex ->
            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                repeat(columns) { columnIndex ->
                    val action = actions.getOrNull(rowIndex * columns + columnIndex)
                    if (action == null) {
                        Spacer(Modifier.weight(1f))
                    } else {
                        AccessoryToolbarActionButton(
                            action = action,
                            buttonSize = buttonSize,
                            contentMode = contentMode,
                            palette = palette,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AccessoryToolbarActionButton(
    action: AccessoryToolbarAction,
    buttonSize: AccessoryToolbarButtonSize,
    contentMode: AccessoryToolbarContentMode,
    palette: Palette,
    modifier: Modifier = Modifier,
) {
    val color = when {
        !action.enabled -> palette.mutedForeground.toColor().copy(alpha = 0.42f)
        action.active -> palette.primary.toColor()
        else -> palette.foreground.toColor()
    }
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val latestOnClick = rememberUpdatedState(action.onClick)
    val repeats = action.id.repeatsOnHold
    if (repeats) {
        LaunchedEffect(isPressed, action.enabled) {
            if (isPressed && action.enabled) {
                latestOnClick.value()
                delay(accessoryRepeatPressSpec.initialDelayMillis)
                var iteration = 0
                while (true) {
                    latestOnClick.value()
                    delay(repeatDelayForIteration(iteration))
                    iteration += 1
                }
            }
        }
    }
    val pressModifier = if (repeats) {
        Modifier.clickable(
            enabled = action.enabled,
            interactionSource = interactionSource,
            indication = null,
            onClick = {},
        )
    } else {
        Modifier.clickable(enabled = action.enabled, onClick = action.onClick)
    }
    val showIcon = action.icon != null && contentMode != AccessoryToolbarContentMode.TEXT_ONLY
    val showText = contentMode != AccessoryToolbarContentMode.ICON_ONLY || action.icon == null
    Box(
        modifier = modifier
            .defaultMinSize(minWidth = buttonSize.minWidthDp(contentMode).dp)
            .fillMaxHeight()
            .background(if (action.active) palette.muted.toColor() else Color.Transparent, RoundedCornerShape(3.dp))
            .then(pressModifier),
        contentAlignment = Alignment.Center,
    ) {
        when {
            showIcon && showText -> Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp),
            ) {
                Icon(action.icon, contentDescription = action.label, tint = color, modifier = Modifier.size(buttonSize.iconDp.dp))
                Text(
                    text = action.label,
                    color = color,
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = buttonSize.labelSp.sp,
                        fontWeight = FontWeight.SemiBold,
                    ),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            showIcon -> Icon(
                action.icon,
                contentDescription = action.label,
                tint = color,
                modifier = Modifier.size(buttonSize.iconDp.dp),
            )
            else -> Text(
                text = action.label,
                color = color,
                style = MaterialTheme.typography.labelSmall.copy(
                    fontSize = (buttonSize.labelSp + 1).sp,
                    fontWeight = FontWeight.SemiBold,
                ),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 5.dp),
            )
        }
    }
}

private val AccessoryToolbarButton.repeatsOnHold: Boolean
    get() = this in setOf(
        AccessoryToolbarButton.MOVE_UP,
        AccessoryToolbarButton.DELETE_BACKWARD,
        AccessoryToolbarButton.MOVE_LEFT,
        AccessoryToolbarButton.MOVE_DOWN,
        AccessoryToolbarButton.MOVE_RIGHT,
    )

private val AccessoryToolbarButtonSize.rowHeightDp: Int
    get() = when (this) {
        AccessoryToolbarButtonSize.SMALL -> 34
        AccessoryToolbarButtonSize.MEDIUM -> 44
        AccessoryToolbarButtonSize.LARGE -> 54
    }

private val AccessoryToolbarButtonSize.iconDp: Int
    get() = when (this) {
        AccessoryToolbarButtonSize.SMALL -> 16
        AccessoryToolbarButtonSize.MEDIUM -> 19
        AccessoryToolbarButtonSize.LARGE -> 23
    }

private val AccessoryToolbarButtonSize.labelSp: Int
    get() = when (this) {
        AccessoryToolbarButtonSize.SMALL -> 8
        AccessoryToolbarButtonSize.MEDIUM -> 9
        AccessoryToolbarButtonSize.LARGE -> 11
    }

private fun AccessoryToolbarButtonSize.minWidthDp(contentMode: AccessoryToolbarContentMode): Int =
    when (contentMode) {
        AccessoryToolbarContentMode.ICON_AND_TEXT -> when (this) {
            AccessoryToolbarButtonSize.SMALL -> 48
            AccessoryToolbarButtonSize.MEDIUM -> 56
            AccessoryToolbarButtonSize.LARGE -> 68
        }
        AccessoryToolbarContentMode.ICON_ONLY -> when (this) {
            AccessoryToolbarButtonSize.SMALL -> 36
            AccessoryToolbarButtonSize.MEDIUM -> 44
            AccessoryToolbarButtonSize.LARGE -> 54
        }
        AccessoryToolbarContentMode.TEXT_ONLY -> when (this) {
            AccessoryToolbarButtonSize.SMALL -> 52
            AccessoryToolbarButtonSize.MEDIUM -> 62
            AccessoryToolbarButtonSize.LARGE -> 76
        }
    }

private fun chunkToolbarActions(
    actions: List<AccessoryToolbarAction>,
    rows: Int,
): List<List<AccessoryToolbarAction>> {
    val safeRows = rows.coerceIn(
        EditorDisplayOptions.MIN_ACCESSORY_TOOLBAR_ROWS,
        EditorDisplayOptions.MAX_ACCESSORY_TOOLBAR_ROWS,
    )
    if (actions.isEmpty()) return List(safeRows) { emptyList() }
    val chunkSize = ((actions.size + safeRows - 1) / safeRows).coerceAtLeast(1)
    return List(safeRows) { index ->
        actions.drop(index * chunkSize).take(chunkSize)
    }
}

@Composable
private fun MobileNavButton(
    icon: ImageVector,
    label: String,
    palette: Palette,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    active: Boolean = false,
    onClick: () -> Unit,
) {
    val color = when {
        !enabled -> palette.mutedForeground.toColor().copy(alpha = 0.45f)
        active -> palette.primary.toColor()
        else -> palette.foreground.toColor()
    }
    Column(
        modifier = modifier
            .height(52.dp)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = label, tint = color, modifier = Modifier.size(23.dp))
        Text(
            text = label,
            color = color,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.SemiBold),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun AccessoryButton(
    icon: ImageVector,
    label: String,
    palette: Palette,
    enabled: Boolean = true,
    active: Boolean = false,
    showLabel: Boolean = true,
    onClick: () -> Unit,
) {
    val color = when {
        !enabled -> palette.mutedForeground.toColor().copy(alpha = 0.42f)
        active -> palette.primary.toColor()
        else -> palette.foreground.toColor()
    }
    Column(
        modifier = Modifier
            .defaultMinSize(minWidth = if (showLabel) 48.dp else 36.dp)
            .height(34.dp)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 5.dp, vertical = 1.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = label, tint = color, modifier = Modifier.size(18.dp))
        if (showLabel) {
            Text(
                text = label,
                color = color,
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun AccessoryDivider(palette: Palette) {
    Spacer(
        Modifier
            .size(width = 1.dp, height = 28.dp)
            .background(palette.border.toColor()),
    )
}

@Composable
private fun CommandButton(
    text: String,
    palette: Palette,
    modifier: Modifier = Modifier,
    primary: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val container = if (primary) palette.primary.toColor() else palette.secondary.toColor()
    val content = if (primary) palette.primaryForeground.toColor() else palette.foreground.toColor()
    Button(
        onClick = onClick,
        enabled = enabled,
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = container,
            contentColor = content,
            disabledContainerColor = palette.muted.toColor(),
            disabledContentColor = palette.mutedForeground.toColor(),
        ),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = modifier
            .defaultMinSize(minWidth = 0.dp, minHeight = 0.dp)
            .heightIn(min = 30.dp),
    ) {
        Text(
            text,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            maxLines = 1,
            softWrap = false,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

private fun String.lineColumn(caret: Int): Pair<Int, Int> {
    val clamped = caret.coerceIn(0, length)
    var line = 1
    var lastNewline = -1
    for (index in 0 until clamped) {
        if (this[index] == '\n') {
            line += 1
            lastNewline = index
        }
    }
    return line to clamped - lastNewline
}

private fun TextSelection.lineNumberIn(body: String): Int =
    body.lineColumn(min).first

private fun String.toColor(): Color =
    Color(android.graphics.Color.parseColor(this))

private val ThemeName.displayTitle: String
    get() = when (this) {
        ThemeName.CLASSIC -> "Classic"
        ThemeName.WINDOWS7 -> "Windows 7"
        ThemeName.LIGHT -> "Light"
        ThemeName.DARK -> "Dark"
        ThemeName.RETRO -> "Retro"
        ThemeName.MODERN -> "Modern"
        ThemeName.CYBERPUNK -> "Cyberpunk"
        ThemeName.SUNSET -> "Rachel's Sunset"
        ThemeName.CUSTOM -> "Custom"
    }

private val PreferencesDestination.preferenceSubtitle: String
    get() = when (this) {
        PreferencesDestination.GENERAL -> ""
        PreferencesDestination.APPEARANCE -> "Themes and layout"
        PreferencesDestination.TOOLBAR -> "Rows, size, pinned and hidden buttons"
        PreferencesDestination.EDITOR -> "Text wrapping, line numbers, font size"
    }

private val AccessoryToolbarContentMode.preferenceIcon: ImageVector
    get() = when (this) {
        AccessoryToolbarContentMode.ICON_AND_TEXT -> Icons.Filled.Keyboard
        AccessoryToolbarContentMode.ICON_ONLY -> Icons.Filled.Visibility
        AccessoryToolbarContentMode.TEXT_ONLY -> Icons.Filled.TextFields
    }

private val AccessoryToolbarButton.preferenceIcon: ImageVector
    get() = when (this) {
        AccessoryToolbarButton.HIDE_KEYBOARD -> Icons.Filled.Keyboard
        AccessoryToolbarButton.CUT -> Icons.Filled.ContentCut
        AccessoryToolbarButton.COPY -> Icons.Filled.ContentCopy
        AccessoryToolbarButton.PASTE -> Icons.Filled.ContentPaste
        AccessoryToolbarButton.SELECT_WORD -> Icons.AutoMirrored.Filled.ShortText
        AccessoryToolbarButton.SELECT_LINE -> Icons.AutoMirrored.Filled.Subject
        AccessoryToolbarButton.SELECT_ALL -> Icons.Filled.SelectAll
        AccessoryToolbarButton.UNDO -> Icons.AutoMirrored.Filled.Undo
        AccessoryToolbarButton.REDO -> Icons.AutoMirrored.Filled.Redo
        AccessoryToolbarButton.READ_MODE -> Icons.Filled.Visibility
        AccessoryToolbarButton.FIND -> Icons.Filled.Search
        AccessoryToolbarButton.INSERT_DATE -> Icons.Filled.AccessTime
        AccessoryToolbarButton.OPEN_DOCUMENTS -> Icons.Filled.FolderOpen
        AccessoryToolbarButton.COMPARE -> Icons.Filled.ViewColumn
        AccessoryToolbarButton.MORE -> Icons.Filled.MoreHoriz
        AccessoryToolbarButton.SHIFT -> Icons.Filled.Keyboard
        AccessoryToolbarButton.MOVE_UP -> Icons.Filled.KeyboardArrowUp
        AccessoryToolbarButton.DELETE_BACKWARD -> Icons.AutoMirrored.Filled.Backspace
        AccessoryToolbarButton.MOVE_LEFT -> Icons.AutoMirrored.Filled.KeyboardArrowLeft
        AccessoryToolbarButton.MOVE_DOWN -> Icons.Filled.KeyboardArrowDown
        AccessoryToolbarButton.MOVE_RIGHT -> Icons.AutoMirrored.Filled.KeyboardArrowRight
    }

private fun Context.hideSoftKeyboard() {
    val activity = this as? Activity ?: return
    val view = activity.currentFocus ?: activity.window.decorView
    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
    imm.hideSoftInputFromWindow(view.windowToken, 0)
}

private fun EditText.focusWithoutSoftKeyboard() {
    post {
        showSoftInputOnFocus = false
        if (!isFocused) requestFocus()
        hideSoftKeyboardNow()
        postDelayed({ hideSoftKeyboardNow() }, 80)
        postDelayed({ hideSoftKeyboardNow() }, 220)
    }
}

private fun EditText.hideSoftKeyboardNow() {
    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
    imm.hideSoftInputFromWindow(windowToken, 0)
}

@Suppress("DEPRECATION")
private fun EditText.showSoftKeyboard(force: Boolean = false) {
    post {
        showSoftInputOnFocus = true
        if (!isFocused) requestFocus()
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager ?: return@post
        val flag = if (force) InputMethodManager.SHOW_FORCED else InputMethodManager.SHOW_IMPLICIT
        imm.showSoftInput(this, flag)
        if (force) {
            imm.toggleSoftInputFromWindow(windowToken, InputMethodManager.SHOW_FORCED, 0)
        }
    }
}

private fun maxOfSelection(first: TextSelection, second: TextSelection?): TextSelection {
    if (second == null) return first
    return if (second.max > first.max) second else first
}

private enum class ClassicMenu {
    FILE,
    EDIT,
    SEARCH,
    VIEW,
    LANGUAGE,
    SETTINGS,
    TOOLS,
    HELP,
}
