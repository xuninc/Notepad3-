package com.corey.notepad3.app

import com.corey.notepad3.models.DocumentLanguage
import com.corey.notepad3.models.TextDocument
import org.junit.Assert.assertEquals
import org.junit.Test

class DocumentExportTest {
    @Test
    fun choosesUsefulMimeTypesFromLanguageAndFileExtension() {
        assertEquals(
            "text/markdown",
            DocumentExport.mimeTypeFor(TextDocument(title = "notes.md", language = DocumentLanguage.MARKDOWN)),
        )
        assertEquals(
            "application/json",
            DocumentExport.mimeTypeFor(TextDocument(title = "settings.jsonc", language = DocumentLanguage.JSON)),
        )
        assertEquals(
            "text/x-python",
            DocumentExport.mimeTypeFor(TextDocument(title = "script.py", language = DocumentLanguage.PYTHON)),
        )
        assertEquals(
            "text/html",
            DocumentExport.mimeTypeFor(TextDocument(title = "index", language = DocumentLanguage.HTML)),
        )
        assertEquals(
            "text/css",
            DocumentExport.mimeTypeFor(TextDocument(title = "styles", language = DocumentLanguage.CSS)),
        )
        assertEquals(
            "text/x-kotlin",
            DocumentExport.mimeTypeFor(TextDocument(title = "MainActivity.kt", language = DocumentLanguage.KOTLIN)),
        )
        assertEquals(
            "text/x-swift",
            DocumentExport.mimeTypeFor(TextDocument(title = "NotepadApp.swift", language = DocumentLanguage.SWIFT)),
        )
        assertEquals(
            "text/x-c++src",
            DocumentExport.mimeTypeFor(TextDocument(title = "editor.cpp", language = DocumentLanguage.C_PLUS_PLUS)),
        )
        assertEquals(
            "text/plain",
            DocumentExport.mimeTypeFor(TextDocument(title = "scratch", language = DocumentLanguage.PLAIN)),
        )
    }

    @Test
    fun normalizesBlankExportNamesToTextFiles() {
        assertEquals("untitled.txt", DocumentExport.fileNameFor(TextDocument(title = "   ")))
        assertEquals("report", DocumentExport.fileNameFor(TextDocument(title = " report ")))
    }
}
