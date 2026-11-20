import Foundation

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

/// Captures a task into the org-roam daily note of the current day.
///
/// The capturer appends to the file itself instead of going through Emacs, so
/// that a capture works the same whether Emacs runs or not. An Emacs buffer of
/// the note picks up the heading through `global-auto-revert-mode`, and Emacs
/// warns before saving a modified buffer over it.
struct OrgTaskCapturer {
    let orgDirectory: URL
    let calendar: Calendar
    let now: () -> Date
    let makeNoteID: () -> String
    let fileSystem: OrgFileSystem

    /// Appends `title` as a TODO heading to the daily note of the capture day,
    /// and creates the note when it is missing. Returns false for a blank
    /// title or an unreadable or unwritable note.
    func capture(title: String) -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let format = OrgTaskFormat(calendar: calendar)
        let captureDate = now()
        return appendDirectly(
            entry: format.makeEntry(title: title, at: captureDate),
            newNoteHeader: format.makeNewNoteHeader(noteID: makeNoteID(), at: captureDate),
            to: format.makeDailyNoteURL(orgDirectory: orgDirectory, at: captureDate)
        )
    }

    private func appendDirectly(
        entry: String,
        newNoteHeader: String,
        to noteURL: URL
    ) -> Bool {
        do {
            let existingText = try fileSystem.readText(noteURL)
            let updatedText = Self.makeUpdatedText(
                existingText: existingText,
                entry: entry,
                newNoteHeader: newNoteHeader
            )
            try fileSystem.writeText(updatedText, noteURL)
            return true
        } catch {
            return false
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
