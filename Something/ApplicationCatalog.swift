import Foundation

/// Finds application bundles installed under a set of directories.
struct ApplicationCatalog {
    let searchDirectories: [URL]
    /// Bundles listed one by one because their folders hold many apps that
    /// users never launch directly.
    var individualApplications: [URL] = []

    /// Returns a catalog of the standard macOS application folders and Finder.
    static func makeDefault() -> ApplicationCatalog {
        ApplicationCatalog(
            searchDirectories: [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                findRealHomeDirectory().appendingPathComponent("Applications"),
            ],
            individualApplications: [
                URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            ])
    }

    /// Returns every `.app` bundle under the search directories, in no
    /// particular order.
    ///
    /// Subfolders such as `/Applications/Utilities` are searched, but bundles
    /// nested inside another bundle are not. Unreadable directories and
    /// missing individual applications are skipped.
    func loadApplications() -> [LaunchableApplication] {
        let existingIndividualApplications = individualApplications
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map(makeApplication(at:))
        return searchDirectories.flatMap(findApplications(in:)) + existingIndividualApplications
    }

    private func findApplications(in directory: URL) -> [LaunchableApplication] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: nil,
                options: [.skipsPackageDescendants, .skipsHiddenFiles])
        else {
            return []
        }
        return enumerator.compactMap { element in
            guard let url = element as? URL, url.pathExtension == "app" else {
                return nil
            }
            return makeApplication(at: url)
        }
    }

    private func makeApplication(at url: URL) -> LaunchableApplication {
        LaunchableApplication(name: url.deletingPathExtension().lastPathComponent, url: url)
    }

    // The sandbox makes NSHomeDirectory() point at the app container, so read
    // the account's home from the password database instead.
    private static func findRealHomeDirectory() -> URL {
        guard let passwordEntry = getpwuid(getuid()), let homePath = passwordEntry.pointee.pw_dir else {
            return URL(fileURLWithPath: NSHomeDirectory())
        }
        return URL(fileURLWithPath: String(cString: homePath))
    }
}
