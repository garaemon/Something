import Cocoa

extension AppDelegate {
    private static let captureDelay: TimeInterval = 0.3

    // The launcher view closes the window right after the action returns. The
    // delay lets the window leave the screen before the capture tool looks.
    func startCapture(_ command: CaptureCommand) {
        window?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.captureDelay) {
            CaptureLauncher.run(command)
        }
    }
}
