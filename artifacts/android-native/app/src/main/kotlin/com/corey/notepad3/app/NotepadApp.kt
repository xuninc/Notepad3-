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
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
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

    fun insertDateTime() {
        val formatted = LocalDateTime.now().format(
            DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT).withLocale(Locale.getDefault()),
        )
        commitEdit(EditorCommands.insertText(active.body, activeSelection, formatted))
    }

    fun applySelection(selection: TextSelection) {
        selections[active.id] = selection.clamped(active.body.length)
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
        selections[active.id] = if (anchor == null) TextSelection(next) else TextSelection(anchor, next)
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

    fun openReplacePanel() {
        showFind = true
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
                        compareEnabled = snapshot.documents.size > 1,
                        compareActive = showCompare,
                        canUndo = canUndo,
                        canRedo = canRedo,
                        readOnly = readMode,
                        zenMode = zenMode,
                        previewEnabled = active.language == DocumentLanguage.MARKDOWN,
                        previewActive = showingMarkdownPreview,
                        trackpadActive = showTrackpad,
                        onCycleTheme = ::cycleTheme,
                        onThemeSelect = ::setTheme,
                        onOpenDocuments = ::toggleDocumentsPanel,
                        onOpenFile = onOpenFile,
                        onSave = { onSaveFile(active) },
                        onFind = ::toggleFindPanel,
                        onReplace = ::openReplacePanel,
                        onCompare = ::toggleComparePanel,
                        onMore = ::toggleMorePanel,
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
                        onTogglePreview = ::togglePreviewMode,
                        onToggleTrackpad = ::toggleTrackpad,
                        onToggleReadMode = ::toggleReadMode,
                        onToggleZenMode = ::toggleZenMode,
                        onSwitchToMobile = ::switchToMobile,
                        onCloseApp = onCloseApp,
                    )
                    Spacer(Modifier.height(if (layoutMode == EditorLayoutMode.CLASSIC) 0.dp else 4.dp))
                    DocumentStrip(
                        documents = snapshot.documents,
                        activeId = snapshot.activeId,
                        palette = palette,
                        onSelect = store::setActive,
                        onClose = store::close,
                    )
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
                                store.updateActive(language = it)
                                showLanguage = false
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
                    if (layoutMode == EditorLayoutMode.MOBILE) {
                        if (displayOptions.accessoryBar) {
                            MobileKeyboardAccessory(
                                palette = palette,
                                canUndo = canUndo,
                                canRedo = canRedo,
                                canCut = activeSelection.min != activeSelection.max && !readMode,
                                canPaste = !readMode,
                                readOnly = readMode,
                                shiftActive = shiftAnchor != null,
                                keyboardSuppressed = keyboardSuppressed,
                                findActive = showFind,
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
                                onFind = ::toggleFindPanel,
                                onReplace = ::openReplacePanel,
                                onInsertDateTime = ::insertDateTime,
                                onOpenDocuments = ::toggleDocumentsPanel,
                                onSelectAll = ::selectAllText,
                                onSelectWord = ::selectWord,
                                onSelectLine = ::selectLine,
                                onCompare = ::toggleComparePanel,
                                onMore = ::toggleMorePanel,
                            )
                            Spacer(Modifier.height(2.dp))
                        }
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
                            onReplace = ::openReplacePanel,
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
                            onChangeLanguage = {
                                showLanguage = true
                                showMore = false
                            },
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
                            onShowAbout = ::showAboutPanel,
                            modifier = Modifier.padding(8.dp),
                        )
                    }
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
    compareEnabled: Boolean,
    compareActive: Boolean,
    canUndo: Boolean,
    canRedo: Boolean,
    readOnly: Boolean,
    zenMode: Boolean,
    previewEnabled: Boolean,
    previewActive: Boolean,
    trackpadActive: Boolean,
    onCycleTheme: () -> Unit,
    onThemeSelect: (ThemeName) -> Unit,
    onOpenDocuments: () -> Unit,
    onOpenFile: () -> Unit,
    onSave: () -> Unit,
    onFind: () -> Unit,
    onReplace: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
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
    onTogglePreview: () -> Unit,
    onToggleTrackpad: () -> Unit,
    onToggleReadMode: () -> Unit,
    onToggleZenMode: () -> Unit,
    onSwitchToMobile: () -> Unit,
    onCloseApp: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(if (layoutMode == EditorLayoutMode.CLASSIC) 0.dp else 4.dp)) {
        if (layoutMode == EditorLayoutMode.CLASSIC) {
            ClassicCaptionBar(document = document, palette = palette, onCloseApp = onCloseApp)
            ClassicMenuBar(
                palette = palette,
                activeTheme = activeTheme,
                compareEnabled = compareEnabled,
                compareActive = compareActive,
                readOnly = readOnly,
                zenMode = zenMode,
                onNew = onNew,
                onOpenFile = onOpenFile,
                onSave = onSave,
                onOpenDocuments = onOpenDocuments,
                onDuplicateDocument = onDuplicateDocument,
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
                onReplace = onReplace,
                onGotoLine = onGotoLine,
                onInsertDateTime = onInsertDateTime,
                onDuplicateLine = onDuplicateLine,
                onDeleteLine = onDeleteLine,
                onTrim = onTrim,
                onSort = onSort,
                onCompare = onCompare,
                onMore = onMore,
                onThemeSelect = onThemeSelect,
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
                onReplace = onReplace,
                onCompare = onCompare,
                onMore = onMore,
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
                onFind = onFind,
                onCycleTheme = onCycleTheme,
                onMore = onMore,
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
    onFind: () -> Unit,
    onCycleTheme: () -> Unit,
    onMore: () -> Unit,
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
        RoundIconButton(icon = Icons.AutoMirrored.Filled.NoteAdd, label = "New document", palette = palette, onClick = onNew)
        RoundIconButton(icon = Icons.Filled.Search, label = "Find", palette = palette, onClick = onFind)
        RoundIconButton(icon = Icons.Filled.Brightness6, label = "Theme", palette = palette, onClick = onCycleTheme)
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
                ClassicDropdownMenuItem("Preferences...", Icons.Filled.Settings, palette) { runQuick(onMore) }
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
    compareEnabled: Boolean,
    compareActive: Boolean,
    readOnly: Boolean,
    zenMode: Boolean,
    onNew: () -> Unit,
    onOpenFile: () -> Unit,
    onSave: () -> Unit,
    onOpenDocuments: () -> Unit,
    onDuplicateDocument: () -> Unit,
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
    onReplace: () -> Unit,
    onGotoLine: () -> Unit,
    onInsertDateTime: () -> Unit,
    onDuplicateLine: () -> Unit,
    onDeleteLine: () -> Unit,
    onTrim: () -> Unit,
    onSort: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
    onThemeSelect: (ThemeName) -> Unit,
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
            ) { runMenuAction(onUndo) }
            ClassicDropdownMenuItem(
                "Redo",
                Icons.AutoMirrored.Filled.Redo,
                palette,
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
            ClassicDropdownMenuItem(
                "Find",
                Icons.Filled.Search,
                palette,
            ) { runMenuAction(onFind) }
            ClassicDropdownMenuItem(
                "Replace",
                Icons.Filled.FindReplace,
                palette,
            ) { runMenuAction(onReplace) }
            ClassicDropdownMenuItem("Goto line...", Icons.AutoMirrored.Filled.KeyboardTab, palette) { runMenuAction(onGotoLine) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuItem("Insert date/time", Icons.Filled.AccessTime, palette, enabled = !readOnly) { runMenuAction(onInsertDateTime) }
            ClassicDropdownMenuItem("Duplicate line", Icons.Filled.AddBox, palette, enabled = !readOnly) { runMenuAction(onDuplicateLine) }
            ClassicDropdownMenuItem("Delete line", Icons.Filled.IndeterminateCheckBox, palette, enabled = !readOnly, destructive = true) { runMenuAction(onDeleteLine) }
            ClassicDropdownMenuItem("Sort lines", Icons.Filled.SortByAlpha, palette, enabled = !readOnly) { runMenuAction(onSort) }
            ClassicDropdownMenuItem("Trim trailing spaces", Icons.AutoMirrored.Filled.FormatAlignLeft, palette, enabled = !readOnly) { runMenuAction(onTrim) }
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
            ClassicDropdownMenuItem("Compare", Icons.Filled.ViewColumn, palette, enabled = compareEnabled, checked = compareActive) { runMenuAction(onCompare) }
            ClassicDropdownMenuItem("Read mode", if (readOnly) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, palette, checked = readOnly) { runMenuAction(onToggleReadMode) }
            ClassicDropdownMenuItem("Zen mode", if (zenMode) Icons.Filled.FullscreenExit else Icons.Filled.Fullscreen, palette, checked = zenMode) { runMenuAction(onToggleZenMode) }
        }
        ClassicMenuButton(
            text = "Settings",
            menu = ClassicMenu.SETTINGS,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem("Preferences...", Icons.Filled.Settings, palette) { runMenuAction(onMore) }
            ClassicDropdownSeparator(palette)
            ClassicDropdownMenuHeader("Theme", palette)
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
        ClassicMenuButton(
            text = "Tools",
            menu = ClassicMenu.TOOLS,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem("Compare documents", Icons.Filled.ViewColumn, palette, enabled = compareEnabled, checked = compareActive) { runMenuAction(onCompare) }
            ClassicDropdownMenuItem("Language...", Icons.Filled.Code, palette) { runMenuAction(onMore) }
            ClassicDropdownMenuItem("More commands...", Icons.Filled.MoreHoriz, palette) { runMenuAction(onMore) }
        }
        ClassicMenuButton(
            text = "Help",
            menu = ClassicMenu.HELP,
            openMenu = openMenu,
            palette = palette,
            onOpen = { openMenu = it },
        ) {
            ClassicDropdownMenuItem("About Notepad 3++", Icons.Filled.Info, palette) { runMenuAction(onMore) }
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
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Normal, fontSize = 13.sp),
            modifier = Modifier
                .height(23.dp)
                .background(if (selected) palette.primary.toColor() else Color.Transparent)
                .clickable { onOpen(if (selected) null else menu) }
                .padding(horizontal = 8.dp, vertical = 3.dp),
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
    onReplace: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
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
            ClassicToolbarButton(
                icon = Icons.Filled.FindReplace,
                label = "Replace",
                palette = palette,
                onClick = onReplace,
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
            ClassicToolbarButton(icon = Icons.Filled.Settings, label = "Preferences", palette = palette, onClick = onMore)
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
                    .widthIn(min = 126.dp, max = 240.dp)
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
                    text = document.title,
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
            Text("Open documents", color = palette.foreground.toColor(), style = MaterialTheme.typography.labelLarge)
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
            DocumentLanguage.entries.forEach { language ->
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
private fun MorePanel(
    palette: Palette,
    canUndo: Boolean,
    canRedo: Boolean,
    readMode: Boolean,
    zenMode: Boolean,
    layoutMode: EditorLayoutMode,
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
    onReplace: () -> Unit,
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
    onChangeLanguage: () -> Unit,
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

            MenuSectionHeader("File", palette)
            MenuActionRow(Icons.AutoMirrored.Filled.NoteAdd, "New blank", palette) { run(onNew) }
            MenuActionRow(Icons.AutoMirrored.Filled.List, "Open documents", palette) { run(onOpenDocuments) }
            MenuActionRow(Icons.Filled.FolderOpen, "Open from Files", palette) { run(onOpenFile) }
            MenuActionRow(Icons.Filled.Save, "Save", palette) { run(onSave) }
            MenuActionRow(Icons.Filled.ContentCopy, "Duplicate current", palette) { run(onDuplicateDocument) }
            MenuActionRow(Icons.Filled.Edit, "Rename current", palette) { run(onRenameDocument) }
            MenuActionRow(Icons.Filled.Close, "Close current", palette, destructive = true) { run(onCloseDocument) }
            MenuActionRow(Icons.Filled.DisabledByDefault, "Close others", palette) { run(onCloseOthers) }

            MenuSectionHeader("Edit", palette)
            MenuActionRow(Icons.AutoMirrored.Filled.Undo, "Undo", palette, enabled = canUndo) { run(onUndo) }
            MenuActionRow(Icons.AutoMirrored.Filled.Redo, "Redo", palette, enabled = canRedo) { run(onRedo) }
            MenuActionRow(Icons.Filled.ContentCut, "Cut", palette, enabled = !readMode) { run(onCut) }
            MenuActionRow(Icons.Filled.ContentCopy, "Copy", palette) { run(onCopy) }
            MenuActionRow(Icons.Filled.ContentPaste, "Paste", palette, enabled = !readMode) { run(onPaste) }
            MenuActionRow(Icons.Filled.SelectAll, "Select all", palette) { run(onSelectAll) }
            MenuActionRow(Icons.AutoMirrored.Filled.ShortText, "Select word", palette) { run(onSelectWord) }
            MenuActionRow(Icons.AutoMirrored.Filled.Subject, "Select line", palette) { run(onSelectLine) }
            MenuActionRow(Icons.Filled.FormatAlignJustify, "Select paragraph", palette) { run(onSelectParagraph) }
            MenuActionRow(Icons.Filled.Search, "Find", palette) { run(onFind) }
            MenuActionRow(Icons.Filled.FindReplace, "Find and replace", palette) { run(onReplace) }
            MenuActionRow(Icons.AutoMirrored.Filled.KeyboardTab, "Go to line", palette) { run(onGotoLine) }
            MenuActionRow(Icons.Filled.AccessTime, "Insert date/time", palette, enabled = !readMode) { run(onInsertDateTime) }
            MenuActionRow(Icons.Filled.SortByAlpha, "Sort lines", palette, enabled = !readMode) { run(onSort) }
            MenuActionRow(Icons.AutoMirrored.Filled.FormatAlignLeft, "Trim trailing spaces", palette, enabled = !readMode) { run(onTrim) }
            MenuActionRow(Icons.Filled.ContentCut, "Trim leading spaces", palette, enabled = !readMode) { run(onTrimLeading) }
            MenuActionRow(Icons.AutoMirrored.Filled.FormatAlignLeft, "Join selected lines", palette, enabled = !readMode) { run(onJoinLines) }
            MenuActionRow(Icons.Filled.SwapVert, "Reverse lines", palette, enabled = !readMode) { run(onReverseLines) }
            MenuActionRow(Icons.Filled.FilterList, "Unique lines", palette, enabled = !readMode) { run(onRemoveDuplicateLines) }
            MenuActionRow(Icons.Filled.FormatSize, "Uppercase selection", palette, enabled = !readMode) { run(onUppercase) }
            MenuActionRow(Icons.Filled.TextFields, "Lowercase selection", palette, enabled = !readMode) { run(onLowercase) }
            MenuActionRow(Icons.AutoMirrored.Filled.FormatIndentIncrease, "Indent", palette, enabled = !readMode) { run(onIndent) }
            MenuActionRow(Icons.AutoMirrored.Filled.FormatIndentDecrease, "Unindent", palette, enabled = !readMode) { run(onUnindent) }
            MenuActionRow(Icons.Filled.Code, "Toggle comment", palette, enabled = !readMode && commentEnabled) { run(onToggleComment) }
            MenuActionRow(Icons.Filled.KeyboardArrowUp, "Move line up", palette, enabled = !readMode) { run(onMoveLineUp) }
            MenuActionRow(Icons.Filled.KeyboardArrowDown, "Move line down", palette, enabled = !readMode) { run(onMoveLineDown) }
            MenuActionRow(Icons.Filled.AddBox, "Duplicate current line", palette, enabled = !readMode) { run(onDuplicateLine) }
            MenuActionRow(Icons.Filled.IndeterminateCheckBox, "Delete current line", palette, enabled = !readMode, destructive = true) { run(onDeleteLine) }

            MenuSectionHeader("View", palette)
            MenuActionRow(if (readMode) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, "Read mode", palette, checked = readMode) { run(onToggleReadMode) }
            MenuActionRow(if (zenMode) Icons.Filled.FullscreenExit else Icons.Filled.Fullscreen, "Zen mode", palette, checked = zenMode) { run(onToggleZenMode) }
            MenuActionRow(Icons.Filled.ViewColumn, "Compare documents", palette) { run(onCompare) }
            MenuActionRow(
                if (previewActive) Icons.Filled.Edit else Icons.Filled.Visibility,
                if (previewActive) "Edit markdown" else "Preview markdown",
                palette,
                enabled = previewEnabled,
                checked = previewActive,
            ) { run(onTogglePreview) }
            MenuActionRow(Icons.Filled.TouchApp, "Virtual trackpad", palette, checked = trackpadActive) { run(onToggleTrackpad) }
            MenuActionRow(Icons.Filled.DesktopWindows, layoutMode.toggleLabel, palette) { run(onToggleLayoutMode) }
            MenuActionRow(Icons.AutoMirrored.Filled.WrapText, "Word wrap", palette, checked = displayOptions.wordWrap) { run(onToggleWordWrap) }
            MenuActionRow(Icons.Filled.FormatListNumbered, "Line numbers", palette, checked = displayOptions.lineNumbers) { run(onToggleLineNumbers) }
            MenuActionRow(Icons.Filled.Keyboard, "Keyboard toolbar", palette, checked = displayOptions.accessoryBar) { run(onToggleAccessoryBar) }
            MenuFontRow(displayOptions.fontSizeSp, palette, onFontSizeDown, onFontSizeUp)

            MenuSectionHeader("Tools", palette)
            MenuActionRow(Icons.Filled.Settings, "Preferences", palette, subtitle = "Editor settings are in this sheet", enabled = false) {}
            MenuActionRow(Icons.Filled.Code, "Change language", palette) { run(onChangeLanguage) }
            MenuActionRow(Icons.Filled.Palette, "Theme quick toggle", palette) { run(onCycleTheme) }

            MenuSectionHeader("Help", palette)
            MenuActionRow(Icons.Filled.Info, "About Notepad 3++", palette) { run(onShowAbout) }
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
    canUndo: Boolean,
    canRedo: Boolean,
    canCut: Boolean,
    canPaste: Boolean,
    readOnly: Boolean,
    shiftActive: Boolean,
    keyboardSuppressed: Boolean,
    findActive: Boolean,
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
    onFind: () -> Unit,
    onReplace: () -> Unit,
    onInsertDateTime: () -> Unit,
    onOpenDocuments: () -> Unit,
    onSelectAll: () -> Unit,
    onSelectWord: () -> Unit,
    onSelectLine: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(92.dp)
            .background(palette.card.toColor())
            .border(1.dp, palette.border.toColor())
            .padding(vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AccessoryStaticCluster(
            palette = palette,
            shiftActive = shiftActive,
            readOnly = readOnly,
            onShiftToggle = onShiftToggle,
            onMoveUp = onMoveUp,
            onDeleteBackward = onDeleteBackward,
            onMoveLeft = onMoveLeft,
            onMoveDown = onMoveDown,
            onMoveRight = onMoveRight,
        )
        Spacer(
            Modifier
                .fillMaxHeight()
                .width(1.dp)
                .background(palette.border.toColor()),
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                val keyboardToggle = keyboardAccessoryToggleState(
                    keyboardSuppressed = keyboardSuppressed,
                    readOnly = readOnly,
                )
                AccessoryButton(
                    Icons.Filled.KeyboardArrowDown,
                    keyboardToggle.label,
                    palette,
                    enabled = keyboardToggle.enabled,
                    active = keyboardToggle.active,
                    onClick = onToggleKeyboardSuppression,
                )
                AccessoryDivider(palette)
                AccessoryButton(Icons.Filled.ContentCut, "Cut", palette, enabled = canCut, onClick = onCut)
                AccessoryButton(Icons.Filled.ContentCopy, "Copy", palette, onClick = onCopy)
                AccessoryButton(Icons.Filled.ContentPaste, "Paste", palette, enabled = canPaste && !readOnly, onClick = onPaste)
                AccessoryDivider(palette)
                AccessoryButton(Icons.AutoMirrored.Filled.ShortText, "Word", palette, onClick = onSelectWord)
                AccessoryButton(Icons.AutoMirrored.Filled.Subject, "Line", palette, onClick = onSelectLine)
                AccessoryButton(Icons.Filled.SelectAll, "All", palette, onClick = onSelectAll)
            }
            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                AccessoryButton(Icons.AutoMirrored.Filled.Undo, "Undo", palette, enabled = canUndo, onClick = onUndo)
                AccessoryButton(Icons.AutoMirrored.Filled.Redo, "Redo", palette, enabled = canRedo, onClick = onRedo)
                AccessoryDivider(palette)
                AccessoryButton(if (readOnly) Icons.Filled.Visibility else Icons.Filled.VisibilityOff, "Read", palette, active = readOnly, onClick = onReadToggle)
                AccessoryButton(Icons.Filled.Search, "Find", palette, active = findActive, onClick = onFind)
                AccessoryButton(Icons.Filled.FindReplace, "Replace", palette, onClick = onReplace)
                AccessoryDivider(palette)
                AccessoryButton(Icons.Filled.AccessTime, "Date", palette, enabled = !readOnly, onClick = onInsertDateTime)
                AccessoryButton(Icons.Filled.FolderOpen, "Open", palette, onClick = onOpenDocuments)
                AccessoryButton(Icons.Filled.ViewColumn, "Compare", palette, active = compareActive, onClick = onCompare)
                AccessoryButton(Icons.Filled.MoreHoriz, "More", palette, onClick = onMore)
            }
        }
    }
}

@Composable
private fun AccessoryStaticCluster(
    palette: Palette,
    shiftActive: Boolean,
    readOnly: Boolean,
    onShiftToggle: () -> Unit,
    onMoveUp: () -> Unit,
    onDeleteBackward: () -> Unit,
    onMoveLeft: () -> Unit,
    onMoveDown: () -> Unit,
    onMoveRight: () -> Unit,
) {
    Column(
        modifier = Modifier
            .width(140.dp)
            .fillMaxHeight()
            .padding(horizontal = 4.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            AccessoryClusterTextButton("Shift", palette, active = shiftActive, modifier = Modifier.weight(1f), onClick = onShiftToggle)
            AccessoryClusterButton(Icons.Filled.KeyboardArrowUp, "Up", palette, modifier = Modifier.weight(1f), onClick = onMoveUp)
            AccessoryClusterButton(Icons.AutoMirrored.Filled.Backspace, "Delete", palette, enabled = !readOnly, modifier = Modifier.weight(1f), onClick = onDeleteBackward)
        }
        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            AccessoryClusterButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Left", palette, modifier = Modifier.weight(1f), onClick = onMoveLeft)
            AccessoryClusterButton(Icons.Filled.KeyboardArrowDown, "Down", palette, modifier = Modifier.weight(1f), onClick = onMoveDown)
            AccessoryClusterButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Right", palette, modifier = Modifier.weight(1f), onClick = onMoveRight)
        }
    }
}

@Composable
private fun AccessoryClusterTextButton(
    label: String,
    palette: Palette,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    active: Boolean = false,
    onClick: () -> Unit,
) {
    val color = when {
        !enabled -> palette.mutedForeground.toColor().copy(alpha = 0.42f)
        active -> palette.primary.toColor()
        else -> palette.foreground.toColor()
    }
    Box(
        modifier = modifier
            .fillMaxHeight()
            .background(if (active) palette.muted.toColor() else Color.Transparent, RoundedCornerShape(3.dp))
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = color,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Clip,
        )
    }
}

@Composable
private fun AccessoryClusterButton(
    icon: ImageVector,
    label: String,
    palette: Palette,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    active: Boolean = false,
    onClick: () -> Unit,
) {
    val color = when {
        !enabled -> palette.mutedForeground.toColor().copy(alpha = 0.42f)
        active -> palette.primary.toColor()
        else -> palette.foreground.toColor()
    }
    Box(
        modifier = modifier
            .fillMaxHeight()
            .background(if (active) palette.muted.toColor() else Color.Transparent, RoundedCornerShape(3.dp))
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = label, tint = color, modifier = Modifier.size(19.dp))
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
        ThemeName.LIGHT -> "Light"
        ThemeName.DARK -> "Dark"
        ThemeName.RETRO -> "Retro"
        ThemeName.MODERN -> "Modern"
        ThemeName.CYBERPUNK -> "Cyberpunk"
        ThemeName.SUNSET -> "Rachel's Sunset"
        ThemeName.CUSTOM -> "Custom"
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
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager ?: return@post
        imm.hideSoftInputFromWindow(windowToken, 0)
    }
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
    VIEW,
    SETTINGS,
    TOOLS,
    HELP,
}
