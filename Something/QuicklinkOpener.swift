import AppKit

/// Opens the URL of a quicklink with the application that it names.
enum QuicklinkOpener {
    /// Opens `url` with `application`, a bundle identifier or a path, or with
    /// the default application when `application` is nil or cannot be found.
    static func open(_ url: URL, withApplication application: String?) {
        guard let application else {
            openWithDefaultApplication(url)
            return
        }
        guard let applicationURL = findApplication(application) else {
            NSLog("Cannot find %@ for quicklink %@", application, url.absoluteString)
            openWithDefaultApplication(url)
            return
        }
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard let error else { return }
            NSLog("Failed to open %@: %@", url.absoluteString, error.localizedDescription)
        }
    }

    private static func openWithDefaultApplication(_ url: URL) {
        guard !NSWorkspace.shared.open(url) else { return }
        NSLog("Failed to open %@", url.absoluteString)
    }

    private static func findApplication(_ bundleIdentifierOrPath: String) -> URL? {
        let expandedPath = (bundleIdentifierOrPath as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: expandedPath)
                ? URL(fileURLWithPath: expandedPath) : nil
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifierOrPath)
    }
}
