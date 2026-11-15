import Foundation

/// Lists windows of running applications, narrowed by application name and
/// title, and brings the picked one to the front.
struct WindowSource: CandidateSource {
    let sourceID = CandidateSourceID("windows")
    let windows: [SwitchableWindow]
    let raiseWindow: (SwitchableWindow) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        ApplicationMatcher.filterItems(windows, matching: query, name: \.name).map(makeCandidate)
    }

    private func makeCandidate(for window: SwitchableWindow) -> LauncherCandidate {
        LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: window),
            name: window.name, icon: .runningApplication(window.processIdentifier), kind: .window,
            actions: [LauncherAction(title: "Switch to Window") { raiseWindow(window) }])
    }
}
