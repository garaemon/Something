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
            return .failed(Self.describe(error))
        }
    }

    // DecodingError.localizedDescription only says the data is in the wrong format.
    private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decodingError {
        case .dataCorrupted(let context), .keyNotFound(_, let context),
            .typeMismatch(_, let context), .valueNotFound(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            let location = path.isEmpty ? "" : " at \(path)"
            return "\(context.debugDescription)\(location)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
