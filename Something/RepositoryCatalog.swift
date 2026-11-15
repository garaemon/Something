import Foundation

/// Lists the git repositories under a root folder, such as the ghq root.
struct RepositoryCatalog {
    /// Returns the current repositories under the given root. Runs on a
    /// background queue.
    let loadRepositories: (URL) -> [GhqRepository]

    /// Returns a catalog that scans the directory tree.
    ///
    /// The catalog reads the tree instead of running ghq, so the app never
    /// starts a shell. A custom `ghq.root` setting is not read.
    static func makeDefault() -> RepositoryCatalog {
        RepositoryCatalog(loadRepositories: scanRepositories(under:))
    }

    /// Returns every directory under `rootDirectory` that holds a `.git`
    /// entry, in no particular order. Follows symbolic links. Returns no
    /// repositories when the root is missing.
    static func scanRepositories(under rootDirectory: URL) -> [GhqRepository] {
        collectRepositories(in: rootDirectory, relativePath: "", ancestorRealPaths: [])
    }

    // ghq places repositories at host/owner/name, and GitLab subgroups add a
    // few levels. The limit keeps a stray non-repository tree, such as a
    // copied node_modules, from making every scan slow.
    private static let maximumDepth = 6

    // Stops at the first repository on each path, because checkouts inside
    // it, such as vendored code, belong to that repository. Also stops at a
    // symbolic link back to an ancestor, which would list repositories again
    // under another name.
    private static func collectRepositories(
        in directory: URL, relativePath: String, ancestorRealPaths: Set<String>
    ) -> [GhqRepository] {
        let fileManager = FileManager.default
        let realPath = directory.resolvingSymlinksInPath().path
        guard !ancestorRealPaths.contains(realPath) else { return [] }
        let depth = ancestorRealPaths.count
        let gitPath = directory.appendingPathComponent(".git").path
        if depth > 0, fileManager.fileExists(atPath: gitPath) {
            return [GhqRepository(name: relativePath, url: directory)]
        }
        guard depth < maximumDepth else { return [] }
        // Listing a symbolic link to a directory fails, so list its target and
        // keep the link's own path in the names and URLs.
        let childNames =
            (try? fileManager.contentsOfDirectory(
                at: directory.resolvingSymlinksInPath(), includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]))?.map(\.lastPathComponent) ?? []
        let children = childNames.map { directory.appendingPathComponent($0) }
        return children.filter(isDirectory).flatMap { child in
            let childPath =
                relativePath.isEmpty ? child.lastPathComponent : "\(relativePath)/\(child.lastPathComponent)"
            return collectRepositories(
                in: child, relativePath: childPath,
                ancestorRealPaths: ancestorRealPaths.union([realPath]))
        }
    }

    // FileManager follows a symbolic link here, unlike the `isDirectory`
    // resource value, so linked repositories are listed.
    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectoryFlag: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectoryFlag)
            && isDirectoryFlag.boolValue
    }
}
