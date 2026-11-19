import Foundation

/// The status code and the body lines of an HTTP response.
struct LLMHTTPResponse {
    let statusCode: Int
    let lines: AsyncThrowingStream<String, Error>
}

/// Sends a request and returns the response as soon as its headers arrive.
/// Tests inject a fake so that they never touch the network.
typealias LLMLineTransport = @Sendable (URLRequest) async throws -> LLMHTTPResponse

/// A client of the OpenAI-compatible chat endpoint that Ollama, LM Studio,
/// and the llama.cpp server serve on localhost.
struct LocalLLMProvider: LLMProvider {
    /// The first request after an idle period waits for the runtime to load
    /// the model. `URLRequest` applies this limit between received bytes.
    static let defaultTimeout: TimeInterval = 300

    let baseURL: URL
    let modelName: String
    let timeout: TimeInterval
    let transport: LLMLineTransport

    init(
        baseURL: URL,
        modelName: String,
        timeout: TimeInterval = LocalLLMProvider.defaultTimeout,
        transport: @escaping LLMLineTransport = LocalLLMProvider.sendWithURLSession
    ) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.timeout = timeout
        self.transport = transport
    }

    func streamCompletion(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.stream(prompt: prompt, into: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.mapToProviderError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Sends the request through `URLSession`. The `lines` of the response
    /// skip empty lines, which the parser would skip anyway.
    @Sendable
    static func sendWithURLSession(_ request: URLRequest) async throws -> LLMHTTPResponse {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.malformedResponse
        }
        let lines = AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines { continuation.yield(line) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return LLMHTTPResponse(statusCode: httpResponse.statusCode, lines: lines)
    }

    /// Converts a transport error to an `LLMProviderError`. A
    /// `CancellationError` passes through, so that a caller that cancelled the
    /// stream does not see it as a failure.
    private static func mapToProviderError(_ error: Error) -> Error {
        if error is LLMProviderError || error is CancellationError { return error }
        guard let urlError = error as? URLError else {
            return LLMProviderError.other(description: error.localizedDescription)
        }
        switch urlError.code {
        case .cannotConnectToHost, .cannotFindHost:
            return LLMProviderError.serverNotRunning
        case .timedOut:
            return LLMProviderError.timedOut
        default:
            return LLMProviderError.other(description: urlError.localizedDescription)
        }
    }

    private func stream(
        prompt: String,
        into continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let response = try await transport(try makeRequest(prompt: prompt))
        guard (200..<300).contains(response.statusCode) else {
            throw try await makeHTTPError(response)
        }
        for try await line in response.lines {
            switch try ChatCompletionStreamParser.parse(line: line) {
            case .text(let chunk): continuation.yield(chunk)
            case .done: return
            case .skip: continue
            }
        }
        // The server must end the answer with [DONE]; a cut connection looks
        // like a clean end otherwise.
        throw LLMProviderError.malformedResponse
    }

    private func makeRequest(prompt: String) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let body: [String: Any] = [
            "model": modelName,
            "stream": true,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func makeHTTPError(_ response: LLMHTTPResponse) async throws -> LLMProviderError {
        var bodyLines: [String] = []
        for try await line in response.lines { bodyLines.append(line) }
        let bodyText = bodyLines.joined(separator: "\n")
        return .httpError(
            statusCode: response.statusCode,
            message: Self.extractErrorMessage(from: bodyText)
        )
    }

    /// Falls back to the raw body when it is not an error JSON. Returns nil
    /// for an empty body.
    private static func extractErrorMessage(from bodyText: String) -> String? {
        guard !bodyText.isEmpty else { return nil }
        return ChatCompletionErrorMessage.extract(from: Data(bodyText.utf8)) ?? bodyText
    }
}
