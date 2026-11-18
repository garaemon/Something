import Foundation

/// How a capture ended.
enum OrgCaptureResult: Equatable {
    /// A running Emacs appended the heading to its buffer and saved it.
    case sentToEmacs
    /// No Emacs server answered, so the heading went into the file directly.
    case wroteFile
    case failed
}

/// Reads and writes the text files of the org directory.
struct OrgFileSystem {
    /// Returns the text of the file, or nil when the file does not exist.
    /// Throws when the file exists but cannot be read, so that a capture
    /// never overwrites a note it could not read.
    let readText: (URL) throws -> String?
    /// Replaces the file with the text, creating missing folders.
    let writeText: (String, URL) throws -> Void
}

/// The text of Org entries and the path of the daily note. Pure, so that tests
/// pin every character.
struct OrgTaskFormat {
    let calendar: Calendar

    /// The top-level heading of a captured task, in the shape of the other
    /// entries of a daily note. The title is one line.
    func makeEntry(title: String, at date: Date) -> String {
        let oneLineTitle = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let createdTimestamp = format(date, pattern: "yyyy-MM-dd EEE HH:mm")
        return "* TODO \(oneLineTitle)\n:PROPERTIES:\n:CREATED:  [\(createdTimestamp)]\n:END:\n"
    }

    /// `<org directory>/org-roam/daily/YYYY-MM-DD.org` of the day of `date`.
    func makeDailyNoteURL(orgDirectory: URL, at date: Date) -> URL {
        orgDirectory
            .appendingPathComponent("org-roam", isDirectory: true)
            .appendingPathComponent("daily", isDirectory: true)
            .appendingPathComponent("\(format(date, pattern: "yyyy-MM-dd")).org")
    }

    /// The header that org-roam writes into a new daily note: a drawer with a
    /// fresh ID, then the title.
    func makeNewNoteHeader(noteID: String, at date: Date) -> String {
        let title = format(date, pattern: "yyyy-MM-dd")
        return ":PROPERTIES:\n:ID:       \(noteID)\n:END:\n#+title: \(title)\n"
    }

    // The POSIX locale keeps day names in English, as Org writes them, on a
    // Mac whose language is not English.
    private func format(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

/// Builds the Emacs Lisp that `emacsclient --eval` runs.
enum OrgElisp {
    /// Returns `text` as an Emacs Lisp string literal. Only the backslash and
    /// the double quote need escaping; a newline may stay in the literal.
    static func makeStringLiteral(_ text: String) -> String {
        let escaped =
            text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Returns an expression that appends `entry` to the buffer of the file
    /// and saves it. Going through the buffer keeps unsaved edits of the
    /// user. An empty buffer, which is a missing note, gets `newNoteHeader`
    /// first.
    static func makeAppendExpression(
        filePath: String,
        entry: String,
        newNoteHeader: String
    ) -> String {
        [
            "(let ((file \(makeStringLiteral(filePath))))",
            "(make-directory (file-name-directory file) t)",
            "(with-current-buffer (find-file-noselect file)",
            "(save-restriction (widen)",
            "(save-excursion (goto-char (point-max))",
            "(when (= (buffer-size) 0) (insert \(makeStringLiteral(newNoteHeader))))",
            "(unless (or (bobp) (bolp)) (insert \"\\n\"))",
            "(insert \(makeStringLiteral(entry)))))",
            "(save-buffer)))",
        ].joined(separator: "\n")
    }
}

/// Captures a task into the org-roam daily note of the current day.
///
/// A running Emacs gets the heading through `emacsclient`, so that an unsaved
/// buffer of the note is not overwritten. Without a server, the capturer
/// writes the file itself, so that a capture never fails just because Emacs
/// is closed.
struct OrgTaskCapturer {
    let orgDirectory: URL
    let calendar: Calendar
    let now: () -> Date
    let makeNoteID: () -> String
    /// Runs `emacsclient` with the arguments. Returns whether it exited
    /// successfully, and false when no server answers or the program is missing.
    let runEmacsclient: ([String]) -> Bool
    let fileSystem: OrgFileSystem

    func capture(title: String) -> OrgCaptureResult {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failed
        }
        let format = OrgTaskFormat(calendar: calendar)
        let captureDate = now()
        let entry = format.makeEntry(title: title, at: captureDate)
        let noteURL = format.makeDailyNoteURL(orgDirectory: orgDirectory, at: captureDate)
        let newNoteHeader = format.makeNewNoteHeader(noteID: makeNoteID(), at: captureDate)
        let expression = OrgElisp.makeAppendExpression(
            filePath: noteURL.path,
            entry: entry,
            newNoteHeader: newNoteHeader
        )
        if runEmacsclient(["--eval", expression]) {
            return .sentToEmacs
        }
        return appendDirectly(entry: entry, newNoteHeader: newNoteHeader, to: noteURL)
    }

    private func appendDirectly(
        entry: String,
        newNoteHeader: String,
        to noteURL: URL
    ) -> OrgCaptureResult {
        do {
            let existingText = try fileSystem.readText(noteURL)
            let updatedText = Self.makeUpdatedText(
                existingText: existingText,
                entry: entry,
                newNoteHeader: newNoteHeader
            )
            try fileSystem.writeText(updatedText, noteURL)
            return .wroteFile
        } catch {
            return .failed
        }
    }

    private static func makeUpdatedText(
        existingText: String?,
        entry: String,
        newNoteHeader: String
    ) -> String {
        guard let existingText, !existingText.isEmpty else { return newNoteHeader + entry }
        let separator = existingText.hasSuffix("\n") ? "" : "\n"
        return existingText + separator + entry
    }
}
