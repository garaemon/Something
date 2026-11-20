import AppKit

extension AppDelegate {
    // Serial, so that two quick captures reach the daily note in order.
    private static let orgCaptureQueue = DispatchQueue(
        label: "com.garaemon.Something.orgCapture",
        qos: .userInitiated
    )

    /// Captures `title` as a task into the daily note of the org directory.
    /// The capture reads and writes the note off the main thread, so that the
    /// launcher closes at once.
    func captureTask(titled title: String) {
        let capturer = OrgTaskCapturer.makeLive(
            orgDirectory: URL(fileURLWithPath: settings.orgDirectoryPath, isDirectory: true)
        )
        Self.orgCaptureQueue.async {
            let didCapture = capturer.capture(title: title)
            if !didCapture {
                NSLog("Something: could not capture the task \"%@\"", title)
                // The launcher is already closed, so a beep is the only signal.
                DispatchQueue.main.async { NSSound.beep() }
            }
        }
    }
}
