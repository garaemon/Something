import XCTest

@testable import Something

final class ApplicationCatalogTests: XCTestCase {
    private var rootDirectory: URL!

    override func setUpWithError() throws {
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: rootDirectory)
    }

    private func createDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: rootDirectory.appendingPathComponent(relativePath),
            withIntermediateDirectories: true)
    }

    private func loadNames(searching relativePaths: [String]) -> Set<String> {
        let directories = relativePaths.map { rootDirectory.appendingPathComponent($0) }
        return Set(ApplicationCatalog(searchDirectories: directories).loadApplications().map(\.name))
    }

    func test_should_list_app_bundles_without_extension() throws {
        try createDirectory("Apps/Safari.app")

        let names = loadNames(searching: ["Apps"])

        XCTAssertEqual(names, ["Safari"])
    }

    func test_should_ignore_non_app_entries() throws {
        try createDirectory("Apps/Safari.app")
        try createDirectory("Apps/NotAnApp")

        let names = loadNames(searching: ["Apps"])

        XCTAssertEqual(names, ["Safari"])
    }

    func test_should_find_apps_in_subfolders() throws {
        try createDirectory("Apps/Utilities/Terminal.app")

        let names = loadNames(searching: ["Apps"])

        XCTAssertEqual(names, ["Terminal"])
    }

    func test_should_not_list_apps_nested_inside_app_bundles() throws {
        try createDirectory("Apps/Xcode.app/Contents/Applications/Instruments.app")

        let names = loadNames(searching: ["Apps"])

        XCTAssertEqual(names, ["Xcode"])
    }

    func test_should_skip_missing_directories() throws {
        try createDirectory("Apps/Mail.app")

        let names = loadNames(searching: ["Missing", "Apps"])

        XCTAssertEqual(names, ["Mail"])
    }

    func test_should_list_individual_applications_outside_search_directories() throws {
        try createDirectory("CoreServices/Finder.app")
        let finderURL = rootDirectory.appendingPathComponent("CoreServices/Finder.app")

        let catalog = ApplicationCatalog(searchDirectories: [], individualApplications: [finderURL])

        XCTAssertEqual(catalog.loadApplications().map(\.name), ["Finder"])
    }

    func test_should_skip_missing_individual_applications() throws {
        let missingURL = rootDirectory.appendingPathComponent("CoreServices/Finder.app")

        let catalog = ApplicationCatalog(searchDirectories: [], individualApplications: [missingURL])

        XCTAssertEqual(catalog.loadApplications(), [])
    }

    func test_should_combine_apps_from_all_directories() throws {
        try createDirectory("A/Safari.app")
        try createDirectory("B/Calendar.app")

        let names = loadNames(searching: ["A", "B"])

        XCTAssertEqual(names, ["Safari", "Calendar"])
    }
}
