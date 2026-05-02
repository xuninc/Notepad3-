package com.corey.notepad3.app

import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.text.method.KeyListener
import android.util.TypedValue
import android.view.Gravity
import android.widget.EditText
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.corey.notepad3.editor.EditResult
import com.corey.notepad3.editor.EditorCommands
import com.corey.notepad3.editor.EditorGutter
import com.corey.notepad3.editor.EditorHistory
import com.corey.notepad3.editor.EditorStatus
import com.corey.notepad3.editor.LineDiff
import com.corey.notepad3.editor.MarkdownBlock
import com.corey.notepad3.editor.MarkdownPreview
import com.corey.notepad3.editor.TextSelection
import com.corey.notepad3.models.DocumentLanguage
import com.corey.notepad3.models.TextDocument
import com.corey.notepad3.persistence.DocumentStore
import com.corey.notepad3.theme.Palette
import com.corey.notepad3.theme.ThemeController
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
    onCloseApp: () -> Unit = {},
) {
    val snapshot by store.state.collectAsState()
    val palette by themeController.palette.collectAsState()
    val layoutMode by editorPreferenceController.layoutMode.collectAsState()
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
    var showGoto by rememberSaveable { mutableStateOf(false) }
    var gotoValue by rememberSaveable { mutableStateOf("") }
    var showLanguage by rememberSaveable { mutableStateOf(false) }
    var previewMode by rememberSaveable { mutableStateOf(false) }
    var showCompare by rememberSaveable { mutableStateOf(false) }
    var compareTargetId by rememberSaveable { mutableStateOf<String?>(null) }
    var showMore by rememberSaveable { mutableStateOf(false) }
    var readMode by rememberSaveable { mutableStateOf(false) }
    var zenMode by rememberSaveable { mutableStateOf(false) }
    val showingMarkdownPreview = previewMode && active.language == DocumentLanguage.MARKDOWN

    fun rememberSelection(selection: TextSelection) {
        selections[active.id] = selection
    }

    fun commitEdit(result: EditResult) {
        val safeSelection = result.selection.clamped(result.body.length)
        history.record(result.body)
        historyVersion += 1
        selections[active.id] = safeSelection
        store.updateActive(body = result.body)
    }

    fun replaceBodyFromHistory(nextBody: String?) {
        if (nextBody == null) return
        historyVersion += 1
        val safeSelection = activeSelection.clamped(nextBody.length)
        selections[active.id] = safeSelection
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
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(if (zenMode) 0.dp else 12.dp),
            ) {
                if (!zenMode) {
                    WindowBar(
                        document = active,
                        palette = palette,
                        layoutMode = layoutMode,
                        compareEnabled = snapshot.documents.size > 1,
                        onTitleChange = { store.updateActive(title = it) },
                        onCycleTheme = { themeController.cycleEarlyThemes() },
                        onOpen = { showDocuments = !showDocuments },
                        onFind = { showFind = !showFind },
                        onCompare = { showCompare = !showCompare },
                        onMore = { showMore = !showMore },
                        onNew = store::createBlank,
                        onCloseApp = onCloseApp,
                    )
                    Spacer(Modifier.height(8.dp))
                    DocumentStrip(
                        documents = snapshot.documents,
                        activeId = snapshot.activeId,
                        palette = palette,
                        onSelect = store::setActive,
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
                            palette = palette,
                            replaceEnabled = !readMode,
                            onQueryChange = { findQuery = it },
                            onReplacementChange = { replacement = it },
                            onNext = {
                                EditorCommands.findNext(active.body, findQuery, activeSelection)
                                    ?.let { selections[active.id] = it }
                            },
                            onPrevious = {
                                EditorCommands.findPrevious(active.body, findQuery, activeSelection)
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
                                        ),
                                    )
                                }
                            },
                            onReplaceAll = {
                                if (!readMode) {
                                    commitEdit(EditorCommands.replaceAll(active.body, findQuery, replacement))
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
                    if (showMore) {
                        Spacer(Modifier.height(8.dp))
                        MorePanel(
                            palette = palette,
                            canUndo = historyVersion.let { history.canUndo },
                            canRedo = historyVersion.let { history.canRedo },
                            readMode = readMode,
                            zenMode = zenMode,
                            layoutMode = layoutMode,
                            onUndo = { replaceBodyFromHistory(history.undo()) },
                            onRedo = { replaceBodyFromHistory(history.redo()) },
                            onInsertDateTime = ::insertDateTime,
                            onGotoLine = {
                                gotoValue = activeSelection.lineNumberIn(active.body).toString()
                                showGoto = true
                                showMore = false
                            },
                            onSelectAll = {
                                applySelection(EditorCommands.selectAll(active.body))
                            },
                            onSelectLine = {
                                applySelection(EditorCommands.selectLine(active.body, activeSelection.min))
                            },
                            onSelectParagraph = {
                                applySelection(EditorCommands.selectParagraph(active.body, activeSelection.min))
                            },
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
                            onTrim = {
                                commitEdit(EditorCommands.trimTrailingSpaces(active.body, activeSelection))
                            },
                            onSort = {
                                commitEdit(EditorCommands.sortLines(active.body))
                            },
                            onDuplicateLine = {
                                commitEdit(EditorCommands.duplicateCurrentLine(active.body, activeSelection.min))
                            },
                            onDeleteLine = {
                                commitEdit(EditorCommands.deleteCurrentLine(active.body, activeSelection.min))
                            },
                            onDuplicateDocument = {
                                store.duplicateActive()
                                showMore = false
                            },
                            onCloseOthers = {
                                store.closeOthers(active.id)
                                showMore = false
                            },
                            onChangeLanguage = {
                                showLanguage = true
                                showMore = false
                            },
                            previewEnabled = active.language == DocumentLanguage.MARKDOWN,
                            previewActive = showingMarkdownPreview,
                            onTogglePreview = {
                                previewMode = !previewMode
                                showMore = false
                            },
                            onToggleReadMode = {
                                readMode = !readMode
                                showMore = false
                            },
                            onToggleZenMode = ::toggleZenMode,
                            onToggleLayoutMode = {
                                editorPreferenceController.toggleLayoutMode()
                                showMore = false
                            },
                            onCycleTheme = {
                                themeController.cycleEarlyThemes()
                                showMore = false
                            },
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                }
                if (showingMarkdownPreview) {
                    MarkdownPreviewPane(document = active, palette = palette, modifier = Modifier.weight(1f))
                } else {
                    EditorTextArea(
                        document = active,
                        palette = palette,
                        selection = activeSelection,
                        readOnly = readMode,
                        onSelectionChange = ::rememberSelection,
                        onBodyChange = { next, nextSelection ->
                            if (!readMode) {
                                selections[active.id] = nextSelection
                                history.recordUserEdit(next)
                                historyVersion += 1
                                store.updateActive(body = next)
                            }
                        },
                        modifier = Modifier.weight(1f),
                    )
                }
                if (!zenMode) {
                    Spacer(Modifier.height(8.dp))
                    StatusBar(document = active, selection = activeSelection, readOnly = readMode, palette = palette)
                    Spacer(Modifier.height(8.dp))
                    if (layoutMode.showMobileBottomBar) {
                        MobileBottomBar(
                            palette = palette,
                            compareEnabled = snapshot.documents.size > 1,
                            onOpen = { showDocuments = !showDocuments },
                            onFind = { showFind = !showFind },
                            onCompare = { showCompare = !showCompare },
                            onMore = { showMore = !showMore },
                            onNew = store::createBlank,
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
    compareEnabled: Boolean,
    onTitleChange: (String) -> Unit,
    onCycleTheme: () -> Unit,
    onOpen: () -> Unit,
    onFind: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
    onNew: () -> Unit,
    onCloseApp: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "Notepad 3++",
                color = palette.foreground.toColor(),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.weight(1f),
            )
            if (layoutMode.showClassicCloseButton) {
                CommandButton(text = "X", palette = palette, onClick = onCloseApp)
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            OutlinedTextField(
                value = document.title,
                onValueChange = onTitleChange,
                modifier = Modifier.weight(1f),
                singleLine = true,
                textStyle = MaterialTheme.typography.titleMedium.copy(color = palette.foreground.toColor()),
            )
            CommandButton(text = "Theme", palette = palette, onClick = onCycleTheme)
        }
        if (layoutMode == EditorLayoutMode.CLASSIC) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                CommandButton(text = "Open", palette = palette, modifier = Modifier.weight(1f), onClick = onOpen)
                CommandButton(text = "Find", palette = palette, modifier = Modifier.weight(1f), onClick = onFind)
                CommandButton(text = "Compare", palette = palette, enabled = compareEnabled, modifier = Modifier.weight(1f), onClick = onCompare)
                CommandButton(text = "More", palette = palette, modifier = Modifier.weight(1f), onClick = onMore)
                CommandButton(text = "New", palette = palette, primary = true, modifier = Modifier.weight(1f), onClick = onNew)
            }
        }
    }
}

@Composable
private fun DocumentStrip(
    documents: List<TextDocument>,
    activeId: String,
    palette: Palette,
    onSelect: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        documents.forEach { document ->
            val active = document.id == activeId
            OutlinedButton(
                onClick = { onSelect(document.id) },
                border = BorderStroke(1.dp, if (active) palette.primary.toColor() else palette.border.toColor()),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = if (active) palette.muted.toColor() else palette.card.toColor(),
                    contentColor = palette.foreground.toColor(),
                ),
                shape = RoundedCornerShape(palette.radius.dp),
            ) {
                Text(document.title)
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
    palette: Palette,
    replaceEnabled: Boolean,
    onQueryChange: (String) -> Unit,
    onReplacementChange: (String) -> Unit,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onReplaceCurrent: () -> Unit,
    onReplaceAll: () -> Unit,
) {
    val matchCount = EditorCommands.findMatches(document.body, query).size
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
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onInsertDateTime: () -> Unit,
    onGotoLine: () -> Unit,
    onSelectAll: () -> Unit,
    onSelectLine: () -> Unit,
    onSelectParagraph: () -> Unit,
    onUppercase: () -> Unit,
    onLowercase: () -> Unit,
    onIndent: () -> Unit,
    onUnindent: () -> Unit,
    onTrim: () -> Unit,
    onSort: () -> Unit,
    onDuplicateLine: () -> Unit,
    onDeleteLine: () -> Unit,
    onDuplicateDocument: () -> Unit,
    onCloseOthers: () -> Unit,
    onChangeLanguage: () -> Unit,
    previewEnabled: Boolean,
    previewActive: Boolean,
    onTogglePreview: () -> Unit,
    onToggleReadMode: () -> Unit,
    onToggleZenMode: () -> Unit,
    onToggleLayoutMode: () -> Unit,
    onCycleTheme: () -> Unit,
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
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(text = "Undo", palette = palette, enabled = canUndo, modifier = Modifier.weight(1f), onClick = onUndo)
                CommandButton(text = "Redo", palette = palette, enabled = canRedo, modifier = Modifier.weight(1f), onClick = onRedo)
                CommandButton(text = "Date/Time", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onInsertDateTime)
                CommandButton(text = "Goto", palette = palette, modifier = Modifier.weight(1f), onClick = onGotoLine)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(text = "Select All", palette = palette, modifier = Modifier.weight(1f), onClick = onSelectAll)
                CommandButton(text = "Line", palette = palette, modifier = Modifier.weight(1f), onClick = onSelectLine)
                CommandButton(text = "Paragraph", palette = palette, modifier = Modifier.weight(1f), onClick = onSelectParagraph)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(text = "Upper", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onUppercase)
                CommandButton(text = "Lower", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onLowercase)
                CommandButton(text = "Indent", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onIndent)
                CommandButton(text = "Unindent", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onUnindent)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(text = "Trim", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onTrim)
                CommandButton(text = "Sort", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onSort)
                CommandButton(text = "Dup Line", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onDuplicateLine)
                CommandButton(text = "Del Line", palette = palette, enabled = !readMode, modifier = Modifier.weight(1f), onClick = onDeleteLine)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(text = "Dup Doc", palette = palette, modifier = Modifier.weight(1f), onClick = onDuplicateDocument)
                CommandButton(text = "Close Others", palette = palette, modifier = Modifier.weight(1f), onClick = onCloseOthers)
                CommandButton(text = "Lang", palette = palette, modifier = Modifier.weight(1f), onClick = onChangeLanguage)
                CommandButton(
                    text = if (previewActive) "Edit" else "Preview",
                    palette = palette,
                    enabled = previewEnabled,
                    modifier = Modifier.weight(1f),
                    onClick = onTogglePreview,
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                CommandButton(text = "Theme", palette = palette, modifier = Modifier.weight(1f), onClick = onCycleTheme)
                CommandButton(
                    text = if (readMode) "Edit Mode" else "Read Mode",
                    palette = palette,
                    modifier = Modifier.weight(1f),
                    onClick = onToggleReadMode,
                )
                CommandButton(
                    text = if (zenMode) "Exit Zen" else "Zen",
                    palette = palette,
                    modifier = Modifier.weight(1f),
                    onClick = onToggleZenMode,
                )
                CommandButton(
                    text = layoutMode.toggleLabel,
                    palette = palette,
                    modifier = Modifier.weight(1f),
                    onClick = onToggleLayoutMode,
                )
            }
        }
    }
}

private class EditorEditText(context: android.content.Context) : EditText(context) {
    var editableKeyListener: KeyListener? = null
    var selectionChangedCallback: ((TextSelection) -> Unit)? = null
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

    fun configureGutter(palette: Palette) {
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

    override fun onDraw(canvas: Canvas) {
        drawLineNumberGutter(canvas)
        super.onDraw(canvas)
    }

    private fun drawLineNumberGutter(canvas: Canvas) {
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
        val left = EditorGutter.totalLeftPaddingPx(
            lineCount = EditorGutter.visibleLineCount(text?.toString().orEmpty()),
            digitWidthPx = lineNumberPaint.measureText("0"),
            sidePaddingPx = gutterSidePaddingPx,
            textPaddingPx = textPaddingLeftPx,
        )
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
    onSelectionChange: (TextSelection) -> Unit,
    onBodyChange: (String, TextSelection) -> Unit,
    modifier: Modifier = Modifier,
) {
    val latestBody = rememberUpdatedState(document.body)
    val latestOnBodyChange = rememberUpdatedState(onBodyChange)
    val latestOnSelectionChange = rememberUpdatedState(onSelectionChange)

    AndroidView(
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, palette.border.toColor(), RoundedCornerShape(palette.radius.dp)),
        factory = { context ->
            EditorEditText(context).apply {
                selectionChangedCallback = { latestOnSelectionChange.value(it) }
                gravity = Gravity.TOP or Gravity.START
                isSingleLine = false
                minLines = 12
                typeface = Typeface.MONOSPACE
                inputType = InputType.TYPE_CLASS_TEXT or
                    InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                    InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                editableKeyListener = keyListener
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setHorizontallyScrolling(false)
                setEditorContentPadding(18, 18, 18, 18)
                configureGutter(palette)
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
            editText.selectionChangedCallback = { latestOnSelectionChange.value(it) }
            val safeSelection = selection.clamped(document.body.length)
            val bodyChangedExternally = editText.text.toString() != document.body
            editText.isCursorVisible = !readOnly
            editText.showSoftInputOnFocus = !readOnly
            if (readOnly) {
                editText.keyListener = null
            } else if (editText.keyListener == null) {
                editText.keyListener = editText.editableKeyListener
            }
            editText.setTextColor(palette.foreground.toColor().toArgb())
            editText.setBackgroundColor(palette.editorBackground.toColor().toArgb())
            editText.configureGutter(palette)
            if (bodyChangedExternally) {
                editText.setText(document.body)
            }
            val shouldApplySelection =
                bodyChangedExternally || !editText.isFocused || safeSelection.start != safeSelection.end
            if (
                shouldApplySelection &&
                (editText.selectionStart != safeSelection.start || editText.selectionEnd != safeSelection.end)
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
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.muted.toColor(), RoundedCornerShape(palette.radius.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

@Composable
private fun MobileBottomBar(
    palette: Palette,
    compareEnabled: Boolean,
    onOpen: () -> Unit,
    onFind: () -> Unit,
    onCompare: () -> Unit,
    onMore: () -> Unit,
    onNew: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            CommandButton(text = "Open", palette = palette, modifier = Modifier.weight(1f), onClick = onOpen)
            CommandButton(text = "Find", palette = palette, modifier = Modifier.weight(1f), onClick = onFind)
            CommandButton(
                text = "Compare",
                palette = palette,
                modifier = Modifier.weight(1f),
                enabled = compareEnabled,
                onClick = onCompare,
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            CommandButton(text = "More", palette = palette, modifier = Modifier.weight(1f), onClick = onMore)
            CommandButton(text = "New", palette = palette, primary = true, modifier = Modifier.weight(1f), onClick = onNew)
        }
    }
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
        colors = ButtonDefaults.buttonColors(
            containerColor = container,
            contentColor = content,
            disabledContainerColor = palette.muted.toColor(),
            disabledContentColor = palette.mutedForeground.toColor(),
        ),
        shape = RoundedCornerShape(palette.radius.dp),
        modifier = modifier,
    ) {
        Text(text, style = MaterialTheme.typography.labelSmall, maxLines = 1, softWrap = false)
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

private fun maxOfSelection(first: TextSelection, second: TextSelection?): TextSelection {
    if (second == null) return first
    return if (second.max > first.max) second else first
}
