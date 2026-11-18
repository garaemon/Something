import AppKit

/// Starts a `CaptureCommand`: opens an application or runs a process.
enum CaptureLauncher {
    static func run(_ command: CaptureCommand) {
        switch command {
        case .openApplication(let url):
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                guard let error else { return }
                NSLog("Failed to open %@: %@", url.path, error.localizedDescription)
            }
        case .runProcess(let path, let arguments):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            do {
                try process.run()
            } catch {
                NSLog("Failed to run %@: %@", path, error.localizedDescription)
            }
        }
    }
}
