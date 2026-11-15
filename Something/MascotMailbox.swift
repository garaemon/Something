import Foundation

/// What SwiftUI last told the mascot.
struct MascotSnapshot: Equatable {
    var state = MascotState.appearing
    var query = ""
    /// Bumps on every state change, so the animator can restart the state clock
    /// even when the same state is entered twice in a row.
    var stateEpoch = 0
    /// Bumps on every query change; each bump is one keystroke for the animator.
    var inputCount = 0
}

/// Hands commands from the main thread to the SceneKit render thread.
/// SceneKit calls its delegate on a private thread, so plain shared properties would race.
final class MascotMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = MascotSnapshot()

    func send(state: MascotState, query: String) {
        lock.lock()
        defer { lock.unlock() }
        if state != snapshot.state {
            snapshot.state = state
            snapshot.stateEpoch += 1
        }
        if query != snapshot.query {
            snapshot.query = query
            snapshot.inputCount += 1
        }
    }

    func read() -> MascotSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }
}
