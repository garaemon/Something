import Foundation

/// Lists the files under the folders that the user picked, such as
/// `~/Downloads`.
struct FileCatalog {
    /// Returns the current files under the given folders. Runs on a
    /// background queue.
    let loadFiles: ([URL]) -> [LocalFile]

    /// Returns a catalog that scans the directory trees under the folders
    /// that each load receives.
    static func makeDefault() -> FileCatalog {
        FileCatalog(loadFiles: scanFiles(in:))
    }

    /// Returns the files under `folders`, most recently modified first.
    ///
    /// Skips hidden files and lists a package, such as a Keynote document, as
    /// one file. Returns no files for a missing folder.
    static func scanFiles(in folders: [URL]) -> [LocalFile] {
        folders.flatMap(collectFiles(in:))
            .sorted { $0.modificationDate > $1.modificationDate }
            .map(\.file)
    }

    // ~/Documents can hold source trees with deep node_modules folders. The
    // limits keep such a tree from making every scan slow and every keystroke
    // narrow a huge list.
    private static let maximumDepth = 4
    private static let maximumFileCountPerFolder = 20_000

    private static let resourceKeys: [URLResourceKey] = [
        .isRegularFileKey, .isPackageKey, .contentModificationDateKey,
    ]

    private struct DatedFile {
        let file: LocalFile
        let modificationDate: Date
    }

    private static func collectFiles(in folder: URL) -> [DatedFile] {
        // The enumerator does not descend into a symbolic link to a folder, so
        // it walks the target and the names keep the link's own name.
        guard
            let enumerator = FileManager.default.enumerator(
                at: folder.resolvingSymlinksInPath(), includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return [] }
        let folderPathPrefix = folder.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        var collectedFiles: [DatedFile] = []
        for case let itemURL as URL in enumerator {
            if enumerator.level >= maximumDepth { enumerator.skipDescendants() }
            guard let datedFile = makeDatedFile(itemURL, folder: folder, folderPathPrefix: folderPathPrefix)
            else { continue }
            collectedFiles.append(datedFile)
            if collectedFiles.count >= maximumFileCountPerFolder { break }
        }
        return collectedFiles
    }

    private static func makeDatedFile(_ itemURL: URL, folder: URL, folderPathPrefix: String) -> DatedFile? {
        guard let values = try? itemURL.resourceValues(forKeys: Set(resourceKeys)),
            values.isRegularFile == true || values.isPackage == true
        else { return nil }
        let itemPath = itemURL.standardizedFileURL.path
        guard itemPath.hasPrefix(folderPathPrefix) else { return nil }
        let relativePath = String(itemPath.dropFirst(folderPathPrefix.count))
        let file = LocalFile(
            name: "\(folder.lastPathComponent)/\(relativePath)",
            url: folder.appendingPathComponent(relativePath))
        return DatedFile(file: file, modificationDate: values.contentModificationDate ?? .distantPast)
    }
}
