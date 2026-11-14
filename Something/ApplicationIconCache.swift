import AppKit

/// Caches application icons so that list rows do not reload them from disk
/// every time SwiftUI re-renders the rows.
final class ApplicationIconCache {
    static let shared = ApplicationIconCache()

    private let iconsByPath = NSCache<NSString, NSImage>()

    func loadIcon(for application: LaunchableApplication) -> NSImage {
        let path = application.url.path as NSString
        if let cachedIcon = iconsByPath.object(forKey: path) {
            return cachedIcon
        }
        let icon = NSWorkspace.shared.icon(forFile: application.url.path)
        iconsByPath.setObject(icon, forKey: path)
        return icon
    }
}
