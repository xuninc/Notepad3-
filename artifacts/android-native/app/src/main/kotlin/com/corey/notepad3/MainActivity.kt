package com.corey.notepad3

import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.corey.notepad3.app.AndroidEditorPreferences
import com.corey.notepad3.app.EditorPreferenceController
import com.corey.notepad3.app.NotepadApp
import com.corey.notepad3.persistence.DocumentStore
import com.corey.notepad3.theme.AndroidThemePreferences
import com.corey.notepad3.theme.ThemeController

class MainActivity : ComponentActivity() {
    private lateinit var openDocumentLauncher: ActivityResultLauncher<Array<String>>

    private val documentStore: DocumentStore by lazy {
        DocumentStore(filesDir.resolve("documents-v1.json"))
    }

    private val themeController: ThemeController by lazy {
        ThemeController(AndroidThemePreferences(this))
    }

    private val editorPreferenceController: EditorPreferenceController by lazy {
        EditorPreferenceController(AndroidEditorPreferences(this))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        openDocumentLauncher = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            uri?.let(::importDocument)
        }
        setContent {
            NotepadApp(
                store = documentStore,
                themeController = themeController,
                editorPreferenceController = editorPreferenceController,
                onOpenFile = {
                    openDocumentLauncher.launch(
                        arrayOf("text/*", "application/json", "application/xml", "application/javascript"),
                    )
                },
                onCloseApp = ::finishAndRemoveTask,
            )
        }
    }

    private fun importDocument(uri: Uri) {
        val body = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } ?: return
        documentStore.importDocument(title = displayName(uri), body = body)
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) {
                return cursor.getString(column)
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')?.ifBlank { null } ?: "untitled.txt"
    }
}
