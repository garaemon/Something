import Foundation

/// The outcome of reading the quicklinks file.
enum QuicklinkLoadResult: Equatable {
    case loaded([Quicklink])
    /// The file exists but cannot be read or parsed. Holds the reason.
    case failed(String)
}

/// Reads the quicklinks from one JSON file.
struct QuicklinkStore {
    let fileURL: URL

    /// Returns the store at `~/Library/Application Support/Something/quicklinks.json`.
    static func makeDefault() -> QuicklinkStore {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return QuicklinkStore(
            fileURL: supportURL.appendingPathComponent("Something/quicklinks.json")
        )
    }

    /// Reads the file again. A missing file means no quicklinks, and any other
    /// failure comes back as `.failed`, so that the launcher can show it.
    func load() -> QuicklinkLoadResult {
        do {
            let data = try Data(contentsOf: fileURL)
            return .loaded(try JSONDecoder().decode([Quicklink].self, from: data))
        } catch CocoaError.fileReadNoSuchFile {
            return .loaded([])
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
