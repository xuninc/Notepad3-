package com.corey.notepad3.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class DocumentLanguage(val displayName: String) {
    @SerialName("Plain")
    PLAIN("Plain"),

    @SerialName("Markdown")
    MARKDOWN("Markdown"),

    @SerialName("Assembly")
    ASSEMBLY("Assembly"),

    @SerialName("JavaScript")
    JAVA_SCRIPT("JavaScript"),

    @SerialName("Python")
    PYTHON("Python"),

    @SerialName("Web")
    WEB("Web"),

    @SerialName("JSON")
    JSON("JSON");

    companion object {
        fun detect(fileName: String): DocumentLanguage {
            val lower = fileName.lowercase()
            return when {
                lower.matchesExtension("asm", "s", "nasm", "masm", "inc") -> ASSEMBLY
                lower.matchesExtension("md", "markdown") -> MARKDOWN
                lower.matchesExtension("js", "jsx", "ts", "tsx", "mjs", "cjs") -> JAVA_SCRIPT
                lower.matchesExtension("py", "pyw") -> PYTHON
                lower.matchesExtension("html", "htm", "css", "xml", "svg") -> WEB
                lower.matchesExtension("json", "jsonc") -> JSON
                else -> PLAIN
            }
        }

        private fun String.matchesExtension(vararg extensions: String): Boolean =
            extensions.any { endsWith(".$it") }
    }
}
