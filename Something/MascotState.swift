import Foundation

/// What the mascot is doing. The launcher state only picks one of these.
enum MascotState: Equatable {
    case appearing
    case idle
    case typing
    case noMatch

    /// Derives the state from launcher facts. A fresh window plays the entrance
    /// first, but only while the query is still empty, so that typing is never
    /// held back by an animation.
    static func derive(query: String, candidateCount: Int, justOpened: Bool) -> MascotState {
        if query.isEmpty {
            return justOpened ? .appearing : .idle
        }
        return candidateCount == 0 ? .noMatch : .typing
    }
}

/// Text on the robot's screen.
enum MascotScreen {
    /// Characters of the query that fit next to the cursor at the screen's font size.
    static let visibleQueryCharacters = 4
    static let blinkPeriod = 0.5
    /// How long the cursor stays solid after a keystroke so that typing feels responsive.
    static let solidCursorDuration = 0.5

    /// `elapsed` is the time since the state began, or since the last query change
    /// while typing.
    static func text(for state: MascotState, query: String, elapsed: Double) -> String {
        switch state {
        case .appearing:
            return elapsed > MascotChoreography.cursorAppearsAt ? blinkingCursor(elapsed) : ""
        case .idle:
            return blinkingCursor(elapsed)
        case .typing:
            // The tail keeps the newest characters visible, which are the ones being typed.
            let cursor = elapsed < solidCursorDuration ? "_" : blinkingCursor(elapsed)
            return String(query.suffix(visibleQueryCharacters)) + cursor
        case .noMatch:
            return "?"
        }
    }

    private static func blinkingCursor(_ elapsed: Double) -> String {
        (elapsed / blinkPeriod).truncatingRemainder(dividingBy: 1) < 0.6 ? "_" : ""
    }
}
