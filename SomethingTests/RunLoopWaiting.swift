import Foundation

/// Runs the main run loop until `condition` holds or `timeout` seconds pass,
/// so that work the code under test dispatched to the main queue can finish.
@MainActor
func runMainLoop(until condition: () -> Bool, timeout: TimeInterval = 5) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
}
