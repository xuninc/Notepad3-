package com.corey.notepad3.models

import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.UUID
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

@Serializable
data class TextDocument(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val body: String = "",
    @Serializable(with = IsoInstantSerializer::class)
    val createdAt: Instant = Instant.now(),
    @Serializable(with = IsoInstantSerializer::class)
    val updatedAt: Instant = Instant.now(),
    val language: DocumentLanguage = DocumentLanguage.PLAIN,
) {
    companion object {
        fun scratchpad(starterContent: StarterContent = StarterContent.WELCOME): TextDocument =
            when (starterContent) {
                StarterContent.WELCOME -> welcomeScratchpad()
                StarterContent.BLANK -> blankScratchpad()
            }

        fun welcomeScratchpad(): TextDocument =
            TextDocument(
                id = "welcome",
                title = "scratchpad.txt",
                body = """
                    Welcome to Notepad 3++

                    A fast Android text editor with the feel of classic desktop notepad utilities.

                    Try this:
                    - Tap any document tab above to switch
                    - Tools > Preferences to switch theme or layout
                    - File > Open from Files... to open any file
                    - Edit > line tools without leaving the editor

                    Everything autosaves locally on this device.
                """.trimIndent(),
                language = DocumentLanguage.PLAIN,
            )

        fun blankScratchpad(): TextDocument =
            TextDocument(id = "welcome", title = "scratchpad.txt", body = "", language = DocumentLanguage.PLAIN)
    }
}

@Serializable
data class DocumentSnapshot(
    val documents: List<TextDocument>,
    val activeId: String,
)

enum class StarterContent {
    WELCOME,
    BLANK,
}

fun List<TextDocument>.nextUntitledName(): String {
    val next = count { it.title.startsWith("untitled") } + 1
    return "untitled-$next.txt"
}

fun TextDocument.duplicateTitle(): String {
    val dot = title.lastIndexOf('.')
    return if (dot > 0) {
        "${title.substring(0, dot)} copy${title.substring(dot)}"
    } else {
        "$title copy"
    }
}

object IsoInstantSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("IsoInstant", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Instant) {
        encoder.encodeString(DateTimeFormatter.ISO_INSTANT.format(value))
    }

    override fun deserialize(decoder: Decoder): Instant =
        Instant.parse(decoder.decodeString())
}
