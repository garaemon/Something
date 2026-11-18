import Foundation

/// What one line of a chat completion event stream means.
enum ChatCompletionStreamEvent: Equatable {
    case text(String)
    case done
    /// A blank line, a comment, or a delta that carries no text.
    case skip
}

private struct ChatCompletionDelta: Decodable {
    let content: String?
}

private struct ChatCompletionChoice: Decodable {
    let delta: ChatCompletionDelta?
}

private struct ChatCompletionChunk: Decodable {
    let choices: [ChatCompletionChoice]
}

/// Parses the server-sent events of an OpenAI-compatible
/// `/v1/chat/completions` request with `stream: true`.
enum ChatCompletionStreamParser {
    private static let dataPrefix = "data:"
    private static let doneMarker = "[DONE]"

    /// Throws `LLMProviderError.malformedResponse` for a line that is neither
    /// an event field nor valid chunk JSON.
    static func parse(line: String) throws -> ChatCompletionStreamEvent {
        if line.isEmpty || line.hasPrefix(":") { return .skip }
        guard line.hasPrefix(dataPrefix) else { throw LLMProviderError.malformedResponse }
        let payload = line.dropFirst(dataPrefix.count).trimmingCharacters(in: .whitespaces)
        if payload == doneMarker { return .done }
        guard let payloadData = payload.data(using: .utf8),
            let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: payloadData)
        else { throw LLMProviderError.malformedResponse }
        guard let content = chunk.choices.first?.delta?.content, !content.isEmpty else {
            return .skip
        }
        return .text(content)
    }
}
