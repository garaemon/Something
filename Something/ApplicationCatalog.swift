import Foundation

/// Finds application bundles installed under a set of directories.
struct ApplicationCatalog {
    let searchDirectories: [URL]

    /// Returns a catalog of the standard macOS application folders.
    static func makeDefault() -> ApplicationCatalog {
        ApplicationCatalog(searchDirectories: [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            findRealHomeDirectory().appendingPathComponent("Applications"),
        ])
    }

    /// Returns every `.app` bundle under the search directories, sorted by name.
    ///
    /// Subfolders such as `/Applications/Utilities` are searched, but bundles
    /// nested inside another bundle are not. Unreadable directories are skipped.
    func loadApplications() -> [LaunchableApplication] {
        let applications = searchDirectories.flatMap(findApplications(in:))
        return applications.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
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
            return LaunchableApplication(name: url.deletingPathExtension().lastPathComponent, url: url)
        }
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
