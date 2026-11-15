import Foundation

/// Keeps the last load of a list, such as the repositories under a folder, and
/// loads it again on a background queue, one load at a time.
///
/// The key names what a load covers, such as the folder path. A load whose key
/// changed while it ran is dropped, and the new key is loaded.
@MainActor
final class BackgroundListLoader<Key: Equatable, Item> {
    /// The items of the last finished load, shown while a new load runs.
    private(set) var cachedItems: [Item] = []
    /// Receives each load of the current key on the main thread.
    var onItemsLoaded: ([Item]) -> Void = { _ in }

    private let readKey: () -> Key
    private let makeLoadFunction: () -> (Key) -> [Item]
    // A walk of a large folder can outlast a hotkey press, so repeated
    // presses would otherwise pile up stale loads.
    private var isLoading = false
    private let queue: DispatchQueue

    /// Creates a loader that reads the current key, and the function that
    /// loads it, on the main thread whenever a load starts. The function then
    /// runs on a background queue.
    init(
        queueLabel: String, readKey: @escaping () -> Key,
        makeLoadFunction: @escaping () -> (Key) -> [Item]
    ) {
        self.readKey = readKey
        self.makeLoadFunction = makeLoadFunction
        queue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    /// Starts a load unless one is running. A settings sink passes
    /// `pendingKey`, because @Published emits before the setting holds the
    /// new value.
    func refresh(pendingKey: Key? = nil) {
        guard !isLoading else { return }
        isLoading = true
        let load = makeLoadFunction()
        let loadedKey = pendingKey ?? readKey()
        queue.async { [weak self] in
            let items = load(loadedKey)
            DispatchQueue.main.async {
                self?.finishRefresh(items, loadedKey: loadedKey)
            }
        }
    }

    // A key change during a load was skipped by the isLoading guard, so the
    // stale result is dropped and the new key is loaded.
    private func finishRefresh(_ items: [Item], loadedKey: Key) {
        isLoading = false
        guard loadedKey == readKey() else {
            refresh()
            return
        }
        cachedItems = items
        onItemsLoaded(items)
    }
}
