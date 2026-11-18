import Foundation

/// One way to start a capture, as data so that tests check it without
/// launching anything.
enum CaptureCommand: Equatable {
    case openApplication(URL)
    case runProcess(path: String, arguments: [String])
}

/// Lists the screen capture commands that the query narrows. The empty query
/// lists nothing, so that the rows do not push the applications down.
struct CaptureSource: CandidateSource {
    private struct Entry {
        let name: String
        let symbolName: String
        let command: CaptureCommand
    }

    private static let entries = [
        Entry(
            name: "Record Screen",
            symbolName: "record.circle",
            command: .openApplication(
                URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")
            )
        ),
        Entry(
            name: "Capture Area to Clipboard",
            symbolName: "rectangle.dashed",
            command: .runProcess(path: "/usr/sbin/screencapture", arguments: ["-ic"])
        ),
        Entry(
            name: "Capture Window to Clipboard",
            symbolName: "macwindow",
            command: .runProcess(path: "/usr/sbin/screencapture", arguments: ["-iwc"])
        ),
    ]

    let sourceID = CandidateSourceID("capture")
    /// Receives the command when the user picks a row. The receiver hides the
    /// launcher first, so that the launcher stays out of the picture.
    let startCapture: (CaptureCommand) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let matchingNames = Set(
            ApplicationMatcher.filterItems(Self.entries.map(\.name), matching: query, name: { $0 })
        )
        return Self.entries.filter { matchingNames.contains($0.name) }.map { entry in
            LauncherCandidate(
                id: LauncherCandidateID(sourceID: sourceID, item: entry.name),
                name: entry.name,
                icon: .systemSymbol(entry.symbolName),
                kind: .capture,
                actions: [
                    LauncherAction(title: entry.name, perform: { startCapture(entry.command) })
                ]
            )
        }
    }
}
