import Foundation

/// Lists the result of a query such as `10 km in miles` and copies the result
/// on pick.
struct UnitConversionSource: CandidateSource {
    let sourceID = CandidateSourceID("unitConversion")
    /// Puts the result text on the clipboard. Tests inject a recorder.
    let copyText: (String) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        guard let result = UnitConversion.convert(query) else { return [] }
        let resultText = "\(result.valueText) \(result.unitSymbol)"
        let resultCandidate = LauncherCandidate(
            id: LauncherCandidateID(sourceID: sourceID, item: resultText),
            name: "= \(resultText)",
            icon: .systemSymbol("ruler"),
            kind: .unit,
            actions: [LauncherAction(title: "Copy Result", perform: { copyText(resultText) })]
        )
        return [resultCandidate]
    }
}
