package com.corey.notepad3.app

import com.corey.notepad3.models.DocumentLanguage
import com.corey.notepad3.models.TextDocument
import java.util.Locale

object DocumentExport {
    fun fileNameFor(document: TextDocument): String =
        document.title.trim().ifEmpty { "untitled.txt" }

    fun mimeTypeFor(document: TextDocument): String {
        val title = fileNameFor(document).lowercase(Locale.ROOT)
        return when {
            title.endsWithAny(".md", ".markdown") || document.language == DocumentLanguage.MARKDOWN -> {
                "text/markdown"
            }
            title.endsWithAny(".json", ".jsonc") || document.language == DocumentLanguage.JSON -> {
                "application/json"
            }
            title.endsWithAny(".py", ".pyw") || document.language == DocumentLanguage.PYTHON -> {
                "text/x-python"
            }
            title.endsWithAny(".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs") ||
                document.language == DocumentLanguage.JAVA_SCRIPT -> {
                "application/javascript"
            }
            title.endsWithAny(".kt", ".kts") || document.language == DocumentLanguage.KOTLIN -> "text/x-kotlin"
            title.endsWith(".swift") || document.language == DocumentLanguage.SWIFT -> "text/x-swift"
            title.endsWithAny(".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx") ||
                document.language == DocumentLanguage.C_PLUS_PLUS -> "text/x-c++src"
            title.endsWithAny(".html", ".htm") || document.language == DocumentLanguage.HTML -> "text/html"
            title.endsWith(".css") || document.language == DocumentLanguage.CSS -> "text/css"
            title.endsWithAny(".xml", ".svg") ||
                document.language == DocumentLanguage.XML ||
                document.language == DocumentLanguage.WEB -> "text/xml"
            else -> "text/plain"
        }
    }

    private fun String.endsWithAny(vararg suffixes: String): Boolean =
        suffixes.any(::endsWith)
}
