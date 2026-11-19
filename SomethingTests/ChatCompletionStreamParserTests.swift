import XCTest

@testable import Something

final class ChatCompletionStreamParserTests: XCTestCase {
    func test_should_return_text_for_a_content_delta_line() throws {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#

        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: line), .text("Hello"))
    }

    func test_should_return_done_for_the_done_marker() throws {
        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: "data: [DONE]"), .done)
    }

    func test_should_skip_blank_and_comment_lines() throws {
        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: ""), .skip)
        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: ": keep-alive"), .skip)
    }

    func test_should_skip_unused_sse_fields() throws {
        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: "event: message"), .skip)
        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: "id: 7"), .skip)
        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: "retry: 100"), .skip)
    }

    func test_should_throw_stream_error_for_an_error_event() {
        let line = #"data: {"error":"context length exceeded"}"#

        XCTAssertThrowsError(try ChatCompletionStreamParser.parse(line: line)) { error in
            XCTAssertEqual(
                error as? LLMProviderError,
                .streamError(message: "context length exceeded")
            )
        }
    }

    func test_should_skip_a_delta_without_content() throws {
        let line = #"data: {"choices":[{"delta":{"role":"assistant"}}]}"#

        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: line), .skip)
    }

    func test_should_accept_data_without_a_space_after_the_colon() throws {
        let line = #"data:{"choices":[{"delta":{"content":"x"}}]}"#

        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: line), .text("x"))
    }

    func test_should_keep_unicode_content() throws {
        let line = #"data: {"choices":[{"delta":{"content":"こん"}}]}"#

        XCTAssertEqual(try ChatCompletionStreamParser.parse(line: line), .text("\u{3053}\u{3093}"))
    }

    func test_should_throw_malformed_response_for_invalid_json() {
        XCTAssertThrowsError(try ChatCompletionStreamParser.parse(line: "data: {oops")) { error in
            XCTAssertEqual(error as? LLMProviderError, .malformedResponse)
        }
    }

    func test_should_throw_malformed_response_for_a_non_data_line() {
        XCTAssertThrowsError(try ChatCompletionStreamParser.parse(line: "hello")) { error in
            XCTAssertEqual(error as? LLMProviderError, .malformedResponse)
        }
    }
}
