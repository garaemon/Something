import XCTest

/// Runs the main run loop until `condition` holds, so that work the code under
/// test dispatched to the main queue can finish.
///
/// Fails the calling test when `condition` still does not hold after `timeout`
/// seconds.
@MainActor
func runMainLoop(
    until condition: () -> Bool,
    timeout: TimeInterval = 5,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else {
            XCTFail("The condition did not hold within \(timeout) s.", file: file, line: line)
            return
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
}
