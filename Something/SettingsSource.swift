import Foundation

/// Lists one row that opens the settings window when the query matches
/// "Settings" or "Preferences".
struct SettingsSource: CandidateSource {
    static let candidateName = "Something Settings"
    // "Preferences" is the name that macOS used before Ventura, and users still type it.
    private static let searchableName = "Something Settings Preferences"

    let sourceID = CandidateSourceID("settings")
    let openSettings: () -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
            !ApplicationMatcher.filterItems([Self.searchableName], matching: query, name: { $0 })
                .isEmpty
        else { return [] }
        let settingsCandidate = LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: Self.candidateName),
            name: Self.candidateName,
            icon: .systemSymbol("gearshape"),
            kind: .settings,
            actions: [LauncherAction(title: "Open Settings", perform: openSettings)]
        )
        return [settingsCandidate]
    }
}
