package com.corey.notepad3.persistence

import com.corey.notepad3.models.DocumentLanguage
import com.corey.notepad3.models.StarterContent
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DocumentStoreTest {
    @Test
    fun startsWithWelcomeScratchpadWhenNoSavedSessionExists() {
        val store = DocumentStore(Files.createTempDirectory("np3").resolve("documents-v1.json").toFile())

        val snapshot = store.state.value

        assertEquals("welcome", snapshot.activeId)
        assertEquals("scratchpad.txt", snapshot.documents.single().title)
        assertTrue(snapshot.documents.single().body.contains("Welcome to Notepad 3++"))
        assertTrue(snapshot.documents.single().body.contains("text editor"))
    }

    @Test
    fun canStartWithBlankScratchpadWhenConfigured() {
        val store = DocumentStore(
            file = Files.createTempDirectory("np3").resolve("documents-v1.json").toFile(),
            starterContent = StarterContent.BLANK,
        )

        assertEquals("scratchpad.txt", store.activeDocument.title)
        assertEquals("", store.activeDocument.body)
    }

    @Test
    fun updatesActiveDocumentAndReloadsItFromDisk() {
        val file = Files.createTempDirectory("np3").resolve("documents-v1.json").toFile()
        val store = DocumentStore(file)

        store.updateActive(title = "demo.py", body = "print('hi')", language = DocumentLanguage.PYTHON)
        val reloaded = DocumentStore(file)

        assertEquals("demo.py", reloaded.activeDocument.title)
        assertEquals("print('hi')", reloaded.activeDocument.body)
        assertEquals(DocumentLanguage.PYTHON, reloaded.activeDocument.language)
    }

    @Test
    fun importsDocumentsAndDetectsTheirLanguage() {
        val store = DocumentStore(Files.createTempDirectory("np3").resolve("documents-v1.json").toFile())

        val imported = store.importDocument(title = "settings.jsonc", body = "{ }")

        assertEquals(imported.id, store.state.value.activeId)
        assertEquals("settings.jsonc", store.activeDocument.title)
        assertEquals(DocumentLanguage.JSON, store.activeDocument.language)
    }

    @Test
    fun createsUntitledTextFilesAndMakesTheNewestDocumentActive() {
        val store = DocumentStore(Files.createTempDirectory("np3").resolve("documents-v1.json").toFile())

        val first = store.createBlank()
        val second = store.createBlank()

        assertEquals("untitled-1.txt", first.title)
        assertEquals("untitled-2.txt", second.title)
        assertEquals(second.id, store.state.value.activeId)
    }

    @Test
    fun duplicatesRenamesAndClosesDocumentsLikeTheIosStore() {
        val store = DocumentStore(Files.createTempDirectory("np3").resolve("documents-v1.json").toFile())
        store.importDocument(title = "main.py", body = "print('hi')")

        val duplicate = store.duplicateActive()
        store.rename(duplicate.id, "copy.py")
        store.closeOthers(duplicate.id)

        assertEquals(1, store.state.value.documents.size)
        assertEquals("copy.py", store.activeDocument.title)
        assertEquals("print('hi')", store.activeDocument.body)

        store.close(duplicate.id)

        assertEquals(1, store.state.value.documents.size)
        assertEquals("scratchpad.txt", store.activeDocument.title)
        assertEquals("", store.activeDocument.body)
    }
}
