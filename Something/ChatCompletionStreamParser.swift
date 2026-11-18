import Foundation

/// What one line of a chat completion event stream means.
enum ChatCompletionStreamEvent: Equatable {
    case text(String)
    case done
    /// A blank line, a comment, an unused SSE field, or a delta without text.
    case skip
}

private struct ChatCompletionDelta: Decodable {
    let content: String?
}

private struct ChatCompletionChoice: Decodable {
    let delta: ChatCompletionDelta?
}

private struct ChatCompletionChunk: Decodable {
    let choices: [ChatCompletionChoice]?
}

/// Reads the explanation that OpenAI-compatible servers put under `error`.
enum ChatCompletionErrorMessage {
    /// Returns the message of `{"error":{"message":...}}` (OpenAI style) or
    /// `{"error":"..."}` (Ollama style), or nil when the JSON holds neither.
    static func extract(from jsonData: Data) -> String? {
        let errorBody = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        if let openAIMessage = (errorBody?["error"] as? [String: Any])?["message"] as? String {
            return openAIMessage
        }
        return errorBody?["error"] as? String
    }
}

/// Parses the server-sent events of an OpenAI-compatible
/// `/v1/chat/completions` request with `stream: true`.
enum ChatCompletionStreamParser {
    private static let dataPrefix = "data:"
    private static let doneMarker = "[DONE]"
    /// SSE fields other than `data` that a client may ignore. Some servers
    /// send them.
    private static let ignoredFieldPrefixes = ["event:", "id:", "retry:"]

    /// Returns the meaning of one line of the stream. Throws
    /// `LLMProviderError.malformedResponse` for a line that is not an SSE
    /// field or for a `data:` line that is not chunk JSON, and
    /// `LLMProviderError.streamError` for an error that the server reports
    /// after it started the stream with status 200.
    static func parse(line: String) throws -> ChatCompletionStreamEvent {
        if line.isEmpty || line.hasPrefix(":") { return .skip }
        if ignoredFieldPrefixes.contains(where: line.hasPrefix) { return .skip }
        guard line.hasPrefix(dataPrefix) else { throw LLMProviderError.malformedResponse }
        let payload = line.dropFirst(dataPrefix.count).trimmingCharacters(in: .whitespaces)
        if payload == doneMarker { return .done }
        guard let payloadData = payload.data(using: .utf8),
            let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: payloadData)
        else { throw LLMProviderError.malformedResponse }
        if let message = ChatCompletionErrorMessage.extract(from: payloadData) {
            throw LLMProviderError.streamError(message: message)
        }
        guard let content = chunk.choices?.first?.delta?.content, !content.isEmpty else {
            return .skip
        }
        return .text(content)
    }
}
