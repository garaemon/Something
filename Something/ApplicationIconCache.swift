import AppKit
import UniformTypeIdentifiers

/// Caches application icons so that list rows do not reload them from disk
/// every time SwiftUI re-renders the rows.
final class ApplicationIconCache {
    static let shared = ApplicationIconCache()

    private let iconsByPath = NSCache<NSString, NSImage>()
    private let iconsByProcessIdentifier = NSCache<NSNumber, NSImage>()
    private let iconsByFileExtension = NSCache<NSString, NSImage>()

    func loadIcon(for application: LaunchableApplication) -> NSImage {
        let path = application.url.path as NSString
        if let cachedIcon = iconsByPath.object(forKey: path) {
            return cachedIcon
        }
        let icon = NSWorkspace.shared.icon(forFile: application.url.path)
        iconsByPath.setObject(icon, forKey: path)
        return icon
    }

    /// Returns the icon of the running application with `processIdentifier`,
    /// or the generic application icon when no such process runs.
    ///
    /// A missing process is not cached, so the icon appears once the process
    /// is found on a later call.
    func loadIcon(forProcess processIdentifier: pid_t) -> NSImage {
        let key = NSNumber(value: processIdentifier)
        if let cachedIcon = iconsByProcessIdentifier.object(forKey: key) {
            return cachedIcon
        }
        guard let runningIcon = NSRunningApplication(processIdentifier: processIdentifier)?.icon else {
            return NSWorkspace.shared.icon(for: .application)
        }
        iconsByProcessIdentifier.setObject(runningIcon, forKey: key)
        return runningIcon
    }

    /// Returns the icon of files with `fileExtension`, such as "pdf", or the
    /// generic document icon for an empty or unknown extension.
    func loadIcon(forFileExtension fileExtension: String) -> NSImage {
        let key = fileExtension as NSString
        if let cachedIcon = iconsByFileExtension.object(forKey: key) {
            return cachedIcon
        }
        let fileType = UTType(filenameExtension: fileExtension) ?? .data
        let icon = NSWorkspace.shared.icon(for: fileType)
        iconsByFileExtension.setObject(icon, forKey: key)
        return icon
    }
}
