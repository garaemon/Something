import Foundation

extension OrgFileSystem {
    /// The real file system.
    static let live = OrgFileSystem(
        readText: { url in
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                return nil
            }
        },
        writeText: { text, url in
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    )
}

extension OrgTaskCapturer {
    /// A capturer for the org directory that uses the real clock and file
    /// system.
    static func makeLive(orgDirectory: URL) -> OrgTaskCapturer {
        OrgTaskCapturer(
            orgDirectory: orgDirectory,
            calendar: .current,
            now: Date.init,
            makeNoteID: { UUID().uuidString.lowercased() },
            fileSystem: .live
        )
    }
}
