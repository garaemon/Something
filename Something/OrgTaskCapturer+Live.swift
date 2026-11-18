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
    // A GUI app does not inherit the shell's PATH, so look where Homebrew and
    // the Emacs for Mac OS X bundle put the program.
    private static let emacsclientCandidatePaths = [
        "/opt/homebrew/bin/emacsclient",
        "/usr/local/bin/emacsclient",
        "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient",
    ]

    /// A capturer for the org directory that uses the real clock, file
    /// system, and `emacsclient`. `emacsclient` blocks until Emacs answers,
    /// so call `capture` off the main thread.
    static func makeLive(orgDirectory: URL) -> OrgTaskCapturer {
        OrgTaskCapturer(
            orgDirectory: orgDirectory,
            calendar: .current,
            now: Date.init,
            makeNoteID: { UUID().uuidString.lowercased() },
            runEmacsclient: runEmacsclientProcess,
            fileSystem: .live
        )
    }

    // emacsclient prints "can't find socket" or "connect: ..." when no server
    // listens. Any other failure means a server took the request, so treat it
    // as an evaluation failure to avoid writing the heading twice.
    private static let serverUnavailableMarkers = ["can't find socket", "connect", "No such file"]

    // The timeout keeps a prompt in Emacs, such as a file-changed question,
    // from blocking the serial capture queue forever.
    private static let emacsclientTimeoutSeconds = 10

    private static func runEmacsclientProcess(arguments: [String]) -> EmacsclientOutcome {
        guard
            let executablePath = emacsclientCandidatePaths.first(where: {
                FileManager.default.isExecutableFile(atPath: $0)
            })
        else { return .serverUnavailable }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--timeout=\(emacsclientTimeoutSeconds)"] + arguments
        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        do {
            try process.run()
        } catch {
            return .serverUnavailable
        }
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return .succeeded }
        let errorText = String(bytes: errorData, encoding: .utf8) ?? ""
        let isServerUnavailable = serverUnavailableMarkers.contains { errorText.contains($0) }
        return isServerUnavailable ? .serverUnavailable : .evaluationFailed
    }
}
