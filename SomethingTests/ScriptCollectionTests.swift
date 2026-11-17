import XCTest

@testable import Something

final class ScriptCollectionTests: XCTestCase {
    func test_should_decode_items_with_the_generation_of_the_collection() throws {
        let json = """
            {"generation": 3, "items": [
              {"source": "demo", "title": "one", "action": 0},
              {"source": "demo", "title": "two", "action": null}],
             "errors": []}
            """

        let collection = try ScriptCollection.decode(fromJSON: json)

        XCTAssertEqual(
            collection.items,
            [
                ScriptItem(generation: 3, source: "demo", title: "one", action: 0),
                ScriptItem(generation: 3, source: "demo", title: "two", action: nil),
            ]
        )
    }

    func test_should_decode_source_errors() throws {
        let json = """
            {"generation": 1, "items": [],
             "errors": [{"source": "bad", "message": "ValueError: boom"}]}
            """

        let collection = try ScriptCollection.decode(fromJSON: json)

        XCTAssertEqual(
            collection.errors, [ScriptSourceError(source: "bad", message: "ValueError: boom")])
    }

    func test_should_throw_on_invalid_json() {
        XCTAssertThrowsError(try ScriptCollection.decode(fromJSON: "not json"))
    }
}
