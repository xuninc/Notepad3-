import Foundation

struct Note: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var language: NoteLanguage

    init(
        id: String = UUID().uuidString,
        title: String,
        body: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        language: NoteLanguage = .plain
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.language = language
    }

    static let welcome = Note(
        id: "welcome",
        title: "scratchpad.txt",
        body: """
        Welcome to Notepad 3++

        A fast iPhone text editor with the feel of classic desktop notepad utilities.

        Try this:
        - Tap any document tab above to switch
        - Tools > Preferences to switch theme or layout
        - File > Open from Files... to open any file
        - Edit > line tools without leaving the editor

        Everything autosaves locally on this device.
        """,
        language: .plain
    )

    static let blankWelcome = Note(id: "welcome", title: "scratchpad.txt", body: "", language: .plain)
}

extension Array where Element == Note {
    func nextUntitledName() -> String {
        let n = filter { $0.title.hasPrefix("untitled") }.count + 1
        return "untitled-\(n).txt"
    }
}
