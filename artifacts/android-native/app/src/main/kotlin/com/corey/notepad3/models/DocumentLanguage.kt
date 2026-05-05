package com.corey.notepad3.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class DocumentLanguage(
    val displayName: String,
    val lineCommentPrefix: String?,
) {
    @SerialName("Plain")
    PLAIN("Plain", null),

    @SerialName("Markdown")
    MARKDOWN("Markdown", null),

    @SerialName("Assembly")
    ASSEMBLY("Assembly", ";"),

    @SerialName("JavaScript")
    JAVA_SCRIPT("JavaScript", "//"),

    @SerialName("Kotlin")
    KOTLIN("Kotlin", "//"),

    @SerialName("Swift")
    SWIFT("Swift", "//"),

    @SerialName("C++")
    C_PLUS_PLUS("C++", "//"),

    @SerialName("Python")
    PYTHON("Python", "#"),

    @SerialName("HTML")
    HTML("HTML", null),

    @SerialName("CSS")
    CSS("CSS", null),

    @SerialName("XML")
    XML("XML", null),

    @SerialName("Web")
    WEB("Web", "//"),

    @SerialName("JSON")
    JSON("JSON", "//");

    companion object {
        val selectableLanguages: List<DocumentLanguage> = listOf(
            PLAIN,
            MARKDOWN,
            JSON,
            HTML,
            CSS,
            JAVA_SCRIPT,
            KOTLIN,
            SWIFT,
            PYTHON,
            C_PLUS_PLUS,
            XML,
            ASSEMBLY,
        )

        fun detect(fileName: String): DocumentLanguage {
            val lower = fileName.lowercase()
            return when {
                lower.matchesExtension("asm", "s", "nasm", "masm", "inc") -> ASSEMBLY
                lower.matchesExtension("md", "markdown") -> MARKDOWN
                lower.matchesExtension("js", "jsx", "ts", "tsx", "mjs", "cjs") -> JAVA_SCRIPT
                lower.matchesExtension("kt", "kts") -> KOTLIN
                lower.matchesExtension("swift") -> SWIFT
                lower.matchesExtension("c", "cc", "cpp", "cxx", "h", "hh", "hpp", "hxx") -> C_PLUS_PLUS
                lower.matchesExtension("py", "pyw") -> PYTHON
                lower.matchesExtension("html", "htm") -> HTML
                lower.matchesExtension("css") -> CSS
                lower.matchesExtension("xml", "svg") -> XML
                lower.matchesExtension("json", "jsonc") -> JSON
                else -> PLAIN
            }
        }

        private fun String.matchesExtension(vararg extensions: String): Boolean =
            extensions.any { endsWith(".$it") }
    }
}
