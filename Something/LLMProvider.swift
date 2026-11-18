import Foundation

/// A model that turns a prompt into text. AI commands depend on this
/// protocol, so that tests inject a fake provider.
protocol LLMProvider: Sendable {
    /// Returns the text chunks of the answer in arrival order. The stream
    /// finishes when the answer is complete, and throws an
    /// `LLMProviderError` when the request fails.
    func streamCompletion(prompt: String) -> AsyncThrowingStream<String, Error>
}

/// Why a request to a language model failed.
enum LLMProviderError: Error, Equatable {
    /// Nothing accepts connections at the base URL.
    case serverNotRunning
    /// The server answered with a non-2xx status, such as 404 for a model
    /// that was never pulled. `message` is the server's explanation, if any.
    case httpError(statusCode: Int, message: String?)
    case timedOut
    /// The answer is not a well-formed chat completion stream.
    case malformedResponse
    case other(description: String)
}
