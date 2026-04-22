import UIKit

/// "Go to line" prompt. Presents a UIAlertController with a numeric text field
/// and a Go button. Parses the user's input, clamps to `[1, maxLine]`, and
/// invokes `onLine` with the resulting 1-based line number. Mirrors the RN
/// `gotoOpen` / `gotoValue` modal.
enum GotoLine {
    /// Presents a UIAlertController with a numeric text field. Calls `onLine`
    /// with the parsed 1-based line number if user taps Go.
    static func prompt(from presenter: UIViewController, maxLine: Int, onLine: @escaping (Int) -> Void) {
        let upper = max(1, maxLine)
        let alert = UIAlertController(
            title: "Go to line",
            message: "Line 1 to \(upper)",
            preferredStyle: .alert
        )

        alert.addTextField { field in
            field.placeholder = "Line number"
            field.keyboardType = .numberPad
            field.returnKeyType = .go
            field.clearButtonMode = .whileEditing
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Go", style: .default) { [weak alert] _ in
            let raw = alert?.textFields?.first?.text ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let n = Int(trimmed), n >= 1 else { return }
            let clamped = min(max(n, 1), upper)
            onLine(clamped)
        })

        presenter.present(alert, animated: true)
    }
}
