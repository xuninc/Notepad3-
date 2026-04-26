import Foundation

/// Single source of truth for the user's notes. Backed by a JSON file in the
/// app's Documents directory. Observers are notified on every mutation;
/// observers register a closure keyed by an opaque token.
final class NotesStore {
    static let shared = NotesStore()

    private(set) var notes: [Note]
    private(set) var activeId: String

    private let url: URL
    private var observers: [UUID: () -> Void] = [:]

    init(fileManager: FileManager = .default) {
        let docs = (try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.url = docs.appendingPathComponent("notes-v1.json")

        if let data = try? Data(contentsOf: url),
           let snap = try? JSONDecoder.iso.decode(Snapshot.self, from: data),
           !snap.notes.isEmpty {
            self.notes = snap.notes
            self.activeId = snap.notes.contains(where: { $0.id == snap.activeId }) ? snap.activeId : snap.notes[0].id
        } else {
            let isBlank = UserDefaults.standard.string(forKey: "notepad3pp.starterContent") == "blank"
            let starter: Note = isBlank ? .blankWelcome : .welcome
            self.notes = [starter]
            self.activeId = starter.id
        }
    }

    var activeNote: Note {
        notes.first(where: { $0.id == activeId }) ?? notes[0]
    }

    @discardableResult
    func observe(_ block: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = block
        return id
    }

    func unobserve(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    private func notify() {
        for block in observers.values { block() }
    }

    private func persist() {
        let snap = Snapshot(notes: notes, activeId: activeId)
        if let data = try? JSONEncoder.iso.encode(snap) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func mutate(_ block: () -> Void) {
        block()
        persist()
        notify()
    }

    func setActive(_ id: String) {
        guard notes.contains(where: { $0.id == id }), id != activeId else { return }
        mutate { activeId = id }
    }

    func updateActive(title: String? = nil, body: String? = nil, language: NoteLanguage? = nil) {
        guard let idx = notes.firstIndex(where: { $0.id == activeId }) else { return }
        var n = notes[idx]
        if let title { n.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "untitled.txt" : title }
        if let body { n.body = body }
        if let language { n.language = language }
        n.updatedAt = Date()
        mutate { notes[idx] = n }
    }

    @discardableResult
    func createBlank() -> Note {
        let note = Note(title: notes.nextUntitledName())
        mutate {
            notes.insert(note, at: 0)
            activeId = note.id
        }
        return note
    }

    @discardableResult
    func importNote(title: String, body: String, language: NoteLanguage = .plain) -> Note {
        let note = Note(title: title, body: body, language: language)
        mutate {
            notes.insert(note, at: 0)
            activeId = note.id
        }
        return note
    }

    func delete(id: String) {
        guard notes.count > 1 else {
            // Keep at least one note around — replace with a fresh blank.
            let blank = Note(title: "scratchpad.txt")
            mutate {
                notes = [blank]
                activeId = blank.id
            }
            return
        }
        mutate {
            notes.removeAll { $0.id == id }
            if activeId == id { activeId = notes[0].id }
        }
    }

    func closeOthers(keep id: String) {
        guard let keep = notes.first(where: { $0.id == id }) else { return }
        mutate {
            notes = [keep]
            activeId = keep.id
        }
    }

    func rename(id: String, title: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        var n = notes[idx]
        n.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "untitled.txt" : title
        n.updatedAt = Date()
        mutate { notes[idx] = n }
    }

    @discardableResult
    func duplicate(id: String) -> Note? {
        guard let src = notes.first(where: { $0.id == id }) else { return nil }
        var newTitle = src.title
        if let dot = newTitle.lastIndex(of: ".") {
            newTitle.insert(contentsOf: " copy", at: dot)
        } else {
            newTitle += " copy"
        }
        let copy = Note(title: newTitle, body: src.body, language: src.language)
        mutate {
            notes.insert(copy, at: 0)
            activeId = copy.id
        }
        return copy
    }

    private struct Snapshot: Codable {
        var notes: [Note]
        var activeId: String
    }
}

private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

private extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
