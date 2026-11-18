import XCTest

@testable import Something

final class LocalLLMProviderTests: XCTestCase {
    private let baseURL = URL(string: "http://localhost:11434/v1")!

    private func makeProvider(
        timeout: TimeInterval = 300,
        transport: @escaping LLMLineTransport
    ) -> LocalLLMProvider {
        LocalLLMProvider(
            baseURL: baseURL,
            modelName: "gemma",
            timeout: timeout,
            transport: transport
        )
    }

    private func makeLines(_ lines: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            lines.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
        var chunks: [String] = []
        for try await chunk in stream { chunks.append(chunk) }
        return chunks
    }

    private func chunkLine(_ text: String) -> String {
        #"data: {"choices":[{"delta":{"content":"\#(text)"}}]}"#
    }

    func test_should_stream_chunks_until_done() async throws {
        let lines = makeLines([chunkLine("Hel"), "", chunkLine("lo"), "data: [DONE]"])
        let provider = makeProvider { _ in LLMHTTPResponse(statusCode: 200, lines: lines) }

        let chunks = try await collect(provider.streamCompletion(prompt: "hi"))

        XCTAssertEqual(chunks, ["Hel", "lo"])
    }

    func test_should_post_the_streaming_chat_request() async throws {
        let box = RequestBox()
        let doneLines = makeLines(["data: [DONE]"])
        let provider = makeProvider(timeout: 123) { request in
            box.request = request
            return LLMHTTPResponse(statusCode: 200, lines: doneLines)
        }

        _ = try await collect(provider.streamCompletion(prompt: "Fix this"))

        let request = try XCTUnwrap(box.request)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.timeoutInterval, 123)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "gemma")
        XCTAssertEqual(body["stream"] as? Bool, true)
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages, [["role": "user", "content": "Fix this"]])
    }

    func test_should_report_http_error_with_the_server_message() async {
        let errorLines = makeLines([#"{"error":{"message":"model 'gemma' not found"}}"#])
        let provider = makeProvider { _ in LLMHTTPResponse(statusCode: 404, lines: errorLines) }

        await assertThrows(
            .httpError(statusCode: 404, message: "model 'gemma' not found"),
            from: provider.streamCompletion(prompt: "hi")
        )
    }

    func test_should_report_server_not_running_when_connection_is_refused() async {
        let provider = makeProvider { _ in throw URLError(.cannotConnectToHost) }

        await assertThrows(.serverNotRunning, from: provider.streamCompletion(prompt: "hi"))
    }

    func test_should_report_timeout() async {
        let provider = makeProvider { _ in throw URLError(.timedOut) }

        await assertThrows(.timedOut, from: provider.streamCompletion(prompt: "hi"))
    }

    func test_should_report_malformed_response() async {
        let lines = makeLines(["data: {oops"])
        let provider = makeProvider { _ in LLMHTTPResponse(statusCode: 200, lines: lines) }

        await assertThrows(.malformedResponse, from: provider.streamCompletion(prompt: "hi"))
    }

    func test_should_report_malformed_response_when_stream_ends_without_done() async {
        let lines = makeLines([chunkLine("a")])
        let provider = makeProvider { _ in LLMHTTPResponse(statusCode: 200, lines: lines) }

        await assertThrows(.malformedResponse, from: provider.streamCompletion(prompt: "hi"))
    }

    func test_should_map_a_timeout_in_the_middle_of_the_stream() async {
        let firstLine = chunkLine("a")
        let failingLines = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield(firstLine)
            continuation.finish(throwing: URLError(.timedOut))
        }
        let provider = makeProvider { _ in LLMHTTPResponse(statusCode: 200, lines: failingLines) }

        await assertThrows(.timedOut, from: provider.streamCompletion(prompt: "hi"))
    }

    private func assertThrows(
        _ expected: LLMProviderError,
        from stream: AsyncThrowingStream<String, Error>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await collect(stream)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? LLMProviderError, expected, file: file, line: line)
        }
    }
}

private final class RequestBox: @unchecked Sendable {
    var request: URLRequest?
}
