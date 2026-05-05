package com.corey.notepad3.models

import org.junit.Assert.assertEquals
import org.junit.Test

class DocumentLanguageTest {
    @Test
    fun detectsLanguagesFromFileExtensions() {
        assertEquals(DocumentLanguage.ASSEMBLY, DocumentLanguage.detect("boot.asm"))
        assertEquals(DocumentLanguage.MARKDOWN, DocumentLanguage.detect("README.markdown"))
        assertEquals(DocumentLanguage.JAVA_SCRIPT, DocumentLanguage.detect("app.tsx"))
        assertEquals(DocumentLanguage.PYTHON, DocumentLanguage.detect("tool.pyw"))
        assertEquals(DocumentLanguage.HTML, DocumentLanguage.detect("index.HTML"))
        assertEquals(DocumentLanguage.CSS, DocumentLanguage.detect("site.css"))
        assertEquals(DocumentLanguage.KOTLIN, DocumentLanguage.detect("MainActivity.kt"))
        assertEquals(DocumentLanguage.SWIFT, DocumentLanguage.detect("NotepadApp.swift"))
        assertEquals(DocumentLanguage.C_PLUS_PLUS, DocumentLanguage.detect("editor.hpp"))
        assertEquals(DocumentLanguage.XML, DocumentLanguage.detect("layout.svg"))
        assertEquals(DocumentLanguage.JSON, DocumentLanguage.detect("settings.jsonc"))
        assertEquals(DocumentLanguage.PLAIN, DocumentLanguage.detect("scratchpad.txt"))
    }

    @Test
    fun exposesPrimaryLineCommentPrefixForEditorCommands() {
        assertEquals(";", DocumentLanguage.ASSEMBLY.lineCommentPrefix)
        assertEquals("//", DocumentLanguage.JAVA_SCRIPT.lineCommentPrefix)
        assertEquals("//", DocumentLanguage.KOTLIN.lineCommentPrefix)
        assertEquals("//", DocumentLanguage.SWIFT.lineCommentPrefix)
        assertEquals("//", DocumentLanguage.C_PLUS_PLUS.lineCommentPrefix)
        assertEquals("#", DocumentLanguage.PYTHON.lineCommentPrefix)
        assertEquals("//", DocumentLanguage.JSON.lineCommentPrefix)
        assertEquals(null, DocumentLanguage.HTML.lineCommentPrefix)
        assertEquals(null, DocumentLanguage.CSS.lineCommentPrefix)
        assertEquals(null, DocumentLanguage.PLAIN.lineCommentPrefix)
    }

    @Test
    fun exposesManualWebSyntaxMode() {
        assertEquals(true, DocumentLanguage.selectableLanguages.contains(DocumentLanguage.WEB))
    }
}
