import AppKit

/// Writes text to the general pasteboard.
enum PasteboardWriter {
    /// Replaces the contents of the general pasteboard with `text`.
    static func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
