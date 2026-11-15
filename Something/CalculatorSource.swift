import Foundation

/// Lists the result of a query that reads as arithmetic, such as `10 + 30`,
/// and copies the result on pick.
struct CalculatorSource: CandidateSource {
    let sourceID = CandidateSourceID("calculator")
    /// Puts the result text on the clipboard. Tests inject a recorder.
    let copyText: (String) -> Void

    func makeCandidates(matching query: String) -> [LauncherCandidate] {
        guard let value = Calculator.evaluate(query) else { return [] }
        let resultText = Calculator.formatResult(value)
        return [
            LauncherCandidate(
                id: LauncherCandidateID(sourceID: sourceID, item: resultText),
                name: "= \(resultText)", icon: .systemSymbol("equal.circle"), kind: .calculator,
                actions: [LauncherAction(title: "Copy Result") { copyText(resultText) }])
        ]
    }
}
