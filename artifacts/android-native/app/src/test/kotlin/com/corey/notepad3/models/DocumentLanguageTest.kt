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
        assertEquals(DocumentLanguage.WEB, DocumentLanguage.detect("index.HTML"))
        assertEquals(DocumentLanguage.JSON, DocumentLanguage.detect("settings.jsonc"))
        assertEquals(DocumentLanguage.PLAIN, DocumentLanguage.detect("scratchpad.txt"))
    }
}
