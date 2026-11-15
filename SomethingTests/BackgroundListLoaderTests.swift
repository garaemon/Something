import XCTest

@testable import Something

@MainActor
final class BackgroundListLoaderTests: XCTestCase {
    private final class KeyBox {
        var key: String
        init(_ key: String) { self.key = key }
    }

    private func makeLoader(
        keyBox: KeyBox, load: @escaping (String) -> [String]
    ) -> BackgroundListLoader<String, String> {
        BackgroundListLoader(
            queueLabel: "BackgroundListLoaderTests", readKey: { keyBox.key }, makeLoadFunction: { load })
    }

    func test_should_deliver_loaded_items() {
        let loader = makeLoader(keyBox: KeyBox("root")) { key in ["\(key)/item"] }
        let delivered = expectation(description: "the loader delivers the items")
        loader.onItemsLoaded = { items in
            if items == ["root/item"] { delivered.fulfill() }
        }

        loader.refresh()

        wait(for: [delivered], timeout: 5)
    }

    func test_should_cache_last_loaded_items() {
        let loader = makeLoader(keyBox: KeyBox("root")) { _ in ["item"] }
        let delivered = expectation(description: "the loader delivers the items")
        loader.onItemsLoaded = { _ in delivered.fulfill() }

        loader.refresh()
        wait(for: [delivered], timeout: 5)

        XCTAssertEqual(loader.cachedItems, ["item"])
    }

    func test_should_load_pending_key_instead_of_current_key() {
        let keyBox = KeyBox("old")
        let loadedPendingKey = expectation(description: "the loader loads the pending key")
        loadedPendingKey.assertForOverFulfill = false
        let loader = makeLoader(keyBox: keyBox) { key in
            if key == "new" { loadedPendingKey.fulfill() }
            return []
        }
        keyBox.key = "new"

        loader.refresh(pendingKey: "new")

        wait(for: [loadedPendingKey], timeout: 5)
    }

    func test_should_not_start_second_load_while_one_runs() {
        let loadRelease = DispatchSemaphore(value: 0)
        let loads = expectation(description: "a second load runs")
        loads.isInverted = true
        loads.expectedFulfillmentCount = 2
        let loader = makeLoader(keyBox: KeyBox("root")) { _ in
            loads.fulfill()
            loadRelease.wait()
            return []
        }
        loader.refresh()

        loader.refresh()
        wait(for: [loads], timeout: 0.5)

        loadRelease.signal()
        loadRelease.signal()
    }

    func test_should_load_new_key_when_key_changes_during_load() {
        let keyBox = KeyBox("old")
        let loadRelease = DispatchSemaphore(value: 0)
        let loadedNewKey = expectation(description: "the loader loads the new key")
        let loader = makeLoader(keyBox: keyBox) { key in
            if key == "new" {
                loadedNewKey.fulfill()
            } else {
                loadRelease.wait()
            }
            return []
        }
        loader.refresh()

        keyBox.key = "new"
        loadRelease.signal()

        wait(for: [loadedNewKey], timeout: 5)
    }

    func test_should_not_deliver_stale_items_when_key_changes_during_load() {
        let keyBox = KeyBox("old")
        let loadRelease = DispatchSemaphore(value: 0)
        let loadedNewKey = expectation(description: "the loader delivers the new key")
        var deliveredItems: [[String]] = []
        let loader = makeLoader(keyBox: keyBox) { key in
            if key == "old" { loadRelease.wait() }
            return [key]
        }
        loader.onItemsLoaded = { items in
            deliveredItems.append(items)
            loadedNewKey.fulfill()
        }
        loader.refresh()

        keyBox.key = "new"
        loadRelease.signal()
        wait(for: [loadedNewKey], timeout: 5)

        XCTAssertEqual(deliveredItems, [["new"]])
    }
}
