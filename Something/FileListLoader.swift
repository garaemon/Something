import Foundation

/// Keeps the last scan of the file folders and rescans them on a background
/// queue, one scan at a time.
@MainActor
final class FileListLoader {
    var catalog: FileCatalog
    /// The files of the last finished scan, shown while a new scan runs.
    private(set) var cachedFiles: [LocalFile] = []
    /// Receives each scan of the current folders on the main thread.
    var onFilesLoaded: ([LocalFile]) -> Void = { _ in }

    private let readFolderPaths: () -> [String]
    // A walk of a large folder can outlast a hotkey press, so repeated
    // presses would otherwise pile up stale scans.
    private var isLoading = false
    private let queue = DispatchQueue(label: "com.garaemon.Something.fileList", qos: .userInitiated)

    /// Creates a loader that scans the folders that `readFolderPaths` returns
    /// when each scan starts and finishes.
    init(catalog: FileCatalog, readFolderPaths: @escaping () -> [String]) {
        self.catalog = catalog
        self.readFolderPaths = readFolderPaths
    }

    /// Starts a scan unless one is running. A settings sink passes
    /// `pendingFolderPaths`, because @Published emits before the setting
    /// holds the new folders.
    func refresh(pendingFolderPaths: [String]? = nil) {
        guard !isLoading else { return }
        isLoading = true
        let catalog = catalog
        let scannedFolderPaths = pendingFolderPaths ?? readFolderPaths()
        let folders = scannedFolderPaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
        queue.async { [weak self] in
            let files = catalog.loadFiles(folders)
            DispatchQueue.main.async {
                self?.finishRefresh(files, scannedFolderPaths: scannedFolderPaths)
            }
        }
    }

    // A folder change during a scan was skipped by the isLoading guard, so
    // the stale result is dropped and the new folders are scanned.
    private func finishRefresh(_ files: [LocalFile], scannedFolderPaths: [String]) {
        isLoading = false
        guard scannedFolderPaths == readFolderPaths() else {
            refresh()
            return
        }
        cachedFiles = files
        onFilesLoaded(files)
    }
}
