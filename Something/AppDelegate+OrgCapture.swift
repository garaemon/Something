import Foundation

extension AppDelegate {
    // Serial, so that two quick captures reach the daily note in order.
    private static let orgCaptureQueue = DispatchQueue(
        label: "com.garaemon.Something.orgCapture",
        qos: .userInitiated
    )

    /// Captures `title` as a task into the daily note of the org directory.
    /// `emacsclient` blocks until Emacs answers, so the capture runs off the
    /// main thread while the launcher closes at once.
    func captureTask(titled title: String) {
        let capturer = OrgTaskCapturer.makeLive(
            orgDirectory: URL(fileURLWithPath: settings.orgDirectoryPath, isDirectory: true)
        )
        Self.orgCaptureQueue.async {
            let result = capturer.capture(title: title)
            if result == .failed {
                NSLog("Something: could not capture the task \"%@\"", title)
            }
        }
    }
}
