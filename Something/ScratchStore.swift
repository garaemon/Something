import Foundation

/// Reads and writes the text of the scratch buffer as one file.
struct ScratchStore {
    /// The text of a scratch buffer that has never been saved.
    static let initialText = """
        # Scratch buffer for Python. Edits save automatically.
        # C-j runs the block at the cursor, C-c C-c runs every block, and C-c C-k forgets
        # all variables. Results appear under each block as "# => " lines.

        1 + 2

        """

    let fileURL: URL

    /// Returns the store at `~/Library/Application Support/Something/scratch.py`.
    static func makeDefault() -> ScratchStore {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let fileURL = supportURL.appendingPathComponent("Something/scratch.py")
        return ScratchStore(fileURL: fileURL)
    }

    /// Returns the saved text, or `initialText` when no file exists yet.
    ///
    /// Throws when the file exists but cannot be read as UTF-8, so that the caller does not
    /// overwrite it with an empty buffer.
    func loadText() throws -> String {
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch CocoaError.fileReadNoSuchFile {
            return Self.initialText
        }
    }

    /// Replaces the file with `text`, and creates its folder when missing.
    ///
    /// Throws when the folder cannot be created or the file cannot be written.
    func saveText(_ text: String) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
