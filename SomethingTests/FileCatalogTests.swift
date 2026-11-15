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

    func test_should_skip_files_deeper_than_limit() throws {
        try createFile("a/b/c/d/e/deep.txt")

        let files = FileCatalog.scanFiles(in: [folder])

        XCTAssertTrue(files.isEmpty)
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
}
