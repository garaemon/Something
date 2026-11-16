import XCTest

@testable import Something

final class ScratchStoreTests: XCTestCase {
    private func makeStore() -> ScratchStore {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScratchStoreTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folderURL) }
        return ScratchStore(fileURL: folderURL.appendingPathComponent("scratch.py"))
    }

    func test_should_load_initial_text_when_no_file_exists() {
        let store = makeStore()

        let text = store.loadText()

        XCTAssertEqual(text, ScratchStore.initialText)
    }

    func test_should_load_saved_text() throws {
        let store = makeStore()
        try store.saveText("x = 1\n")

        let text = store.loadText()

        XCTAssertEqual(text, "x = 1\n")
    }

    func test_should_create_missing_folder_on_save() throws {
        let store = makeStore()

        try store.saveText("x = 1\n")

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func test_should_keep_an_emptied_buffer_empty() throws {
        let store = makeStore()
        try store.saveText("")

        let text = store.loadText()

        XCTAssertEqual(text, "")
    }

    func test_should_store_in_application_support_by_default() {
        let store = ScratchStore.makeDefault()

        XCTAssertTrue(store.fileURL.path.hasSuffix("Application Support/Something/scratch.py"))
    }
}
