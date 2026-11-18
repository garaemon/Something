import Cocoa

extension AppDelegate {
    // The launcher view closes the window right after the action returns. The
    // delay lets the window leave the screen before the capture tool looks.
    func startCapture(_ command: CaptureCommand) {
        window?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            CaptureLauncher.run(command)
        }
    }
}
