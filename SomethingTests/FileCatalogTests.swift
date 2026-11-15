import XCTest

@testable import Something

final class FileCatalogTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder.deletingLastPathComponent())
    }

    private func createFile(_ relativePath: String, modifiedAt date: Date = Date()) throws {
        let fileURL = folder.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: fileURL)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: fileURL.path)
    }

    func test_should_name_files_with_folder_name_and_relative_path() throws {
        try createFile("reports/q3.pdf")

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertEqual(files.map(\.name), ["Downloads/reports/q3.pdf"])
    }

    func test_should_point_files_at_their_location() throws {
        try createFile("memo.txt")

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertEqual(
            files.map(\.url.standardizedFileURL.path),
            [folder.appendingPathComponent("memo.txt").standardizedFileURL.path])
    }

    func test_should_not_list_directories() throws {
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("empty", isDirectory: true), withIntermediateDirectories: true)

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertTrue(files.isEmpty)
    }

    func test_should_skip_hidden_files() throws {
        try createFile(".DS_Store")

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertTrue(files.isEmpty)
    }

    func test_should_list_package_as_one_file() throws {
        try createFile("Slides.key/Index.zip")

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertEqual(files.map(\.name), ["Downloads/Slides.key"])
    }

    func test_should_list_recently_modified_files_first() throws {
        try createFile("old.txt", modifiedAt: Date(timeIntervalSince1970: 1_000))
        try createFile("new.txt", modifiedAt: Date(timeIntervalSince1970: 2_000))

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertEqual(files.map(\.name), ["Downloads/new.txt", "Downloads/old.txt"])
    }

    func test_should_list_files_four_levels_deep() throws {
        try createFile("a/b/c/deep.txt")

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertEqual(files.map(\.name), ["Downloads/a/b/c/deep.txt"])
    }

    func test_should_skip_files_five_levels_deep() throws {
        try createFile("a/b/c/d/deep.txt")

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertTrue(files.isEmpty)
    }

    func test_should_list_file_of_nested_folders_once() throws {
        try createFile("papers/a.pdf")
        let nestedFolder = folder.appendingPathComponent("papers", isDirectory: true)

        let files = FileCatalog.scanFiles(in: [folder, nestedFolder])

        XCTAssertEqual(files.map(\.name), ["Downloads/papers/a.pdf"])
    }

    func test_should_return_no_files_when_folder_is_missing() {
        let missingFolder = folder.appendingPathComponent("missing", isDirectory: true)

        let files = FileCatalog.scanFiles(in: [missingFolder])

        XCTAssertTrue(files.isEmpty)
    }

    func test_should_list_files_of_every_folder() throws {
        try createFile("a.txt")
        let otherFolder = folder.deletingLastPathComponent().appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: otherFolder, withIntermediateDirectories: true)
        try Data().write(to: otherFolder.appendingPathComponent("b.txt"))

        let files = FileCatalog.scanFiles(in: [folder, otherFolder])

        XCTAssertEqual(Set(files.map(\.name)), ["Downloads/a.txt", "Documents/b.txt"])
    }

    func test_should_list_files_through_symbolic_link_folder_with_link_name() throws {
        try createFile("a.txt")
        let linkFolder = folder.deletingLastPathComponent().appendingPathComponent("Linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkFolder, withDestinationURL: folder)

        let files = FileCatalog.scanFiles(in: [linkFolder])

        XCTAssertEqual(files.map(\.name), ["Linked/a.txt"])
    }

    func test_should_skip_node_modules() throws {
        try createFile("project/node_modules/lib/index.js")

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertTrue(files.isEmpty)
    }

    func test_should_stop_at_file_count_limit() throws {
        try createFile("a.txt")
        try createFile("b.txt")
        try createFile("c.txt")

        let files = FileCatalog.scanFiles(in: [folder], maximumFileCountPerFolder: 2)

        XCTAssertEqual(files.count, 2)
    }
}
