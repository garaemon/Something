import Foundation

/// Where a result panel stands, from the request start to its outcome.
enum ResultPanelState: Equatable {
    case idle
    /// The request started, and no text has arrived yet.
    case loading
    case streaming(String)
    case finished(String)
    case failed(String)

    /// The text received so far, or nil before the first chunk and after a
    /// failure.
    var text: String? {
        switch self {
        case .streaming(let text), .finished(let text):
            return text
        case .idle, .loading, .failed:
            return nil
        }
    }
}

/// A button in the footer of a result panel.
struct ResultAction: Identifiable {
    let id = UUID()
    let title: String
    /// Receives the text that the panel shows.
    let perform: (String) -> Void
}

/// State of one result panel: a title, the text of an async stream as it
/// arrives, and the footer actions. Later AI commands stream into it.
@MainActor
final class ResultPanelModel: ObservableObject {
    @Published private(set) var state = ResultPanelState.idle

    let title: String
    let actions: [ResultAction]
    private var streamTask: Task<Void, Never>?

    init(title: String, actions: [ResultAction]) {
        self.title = title
        self.actions = actions
    }

    deinit {
        streamTask?.cancel()
    }

    /// Shows `loading` at once, then the accumulated text of `stream` as
    /// chunks arrive. A thrown error ends in `failed` with its description.
    /// Replaces a stream that is still running.
    func start(stream: AsyncThrowingStream<String, Error>) {
        streamTask?.cancel()
        state = .loading
        streamTask = Task { [weak self] in
            await Self.consume(stream, into: self)
        }
    }

    /// Stops the stream and returns to `idle`. Late chunks are dropped.
    func cancel() {
        streamTask?.cancel()
        state = .idle
    }

    /// Runs `action` with the current text. Does nothing before the first
    /// chunk or after a failure.
    func perform(_ action: ResultAction) {
        guard let text = state.text else { return }
        action.perform(text)
    }

    /// Returns after the stream task ends, including after a cancel. For tests.
    func waitUntilDone() async {
        await streamTask?.value
    }

    // The task holds the panel weakly between chunks, so that a panel with a
    // stream that never ends still deallocates, and its deinit cancels the task.
    private static func consume(
        _ stream: AsyncThrowingStream<String, Error>,
        into panel: ResultPanelModel?
    ) async {
        var accumulatedText = ""
        do {
            for try await chunk in stream {
                guard let panel, !Task.isCancelled else { return }
                accumulatedText += chunk
                panel.show(.streaming(accumulatedText))
            }
            guard let panel, !Task.isCancelled else { return }
            panel.show(.finished(accumulatedText))
        } catch {
            guard let panel, !Task.isCancelled else { return }
            panel.show(.failed(error.localizedDescription))
        }
    }

    private func show(_ newState: ResultPanelState) {
        state = newState
    }
}
