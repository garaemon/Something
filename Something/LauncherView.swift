import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Shows the windows of running applications, every application, and then the
/// git repositories under a query field, and narrows the list on each
/// keystroke, in the style of Emacs anything.el. A non-empty query also lists
/// the files of the file folders and web searches for it at the end.
struct LauncherView: View {
    static let minimumSize = CGSize(width: 600, height: 400)

    // AppDelegate owns the view model and pushes rescans into it.
    @ObservedObject var viewModel: LauncherViewModel
    let dismiss: () -> Void
    let copyText: (String) -> Void
    @FocusState private var isQueryFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField(
                "Window, Application, Repository, File, or Web Search",
                text: $viewModel.query
            )
            .textFieldStyle(.plain)
            .font(.title2)
            .padding(12)
            .focused($isQueryFieldFocused)
            .onSubmit(activateAndDismiss)
            Divider()
            if let resultPanel = viewModel.resultPanel {
                ResultPanelView(
                    panel: resultPanel,
                    copyText: copyText,
                    closePanel: viewModel.closeResult
                )
            } else {
                candidateList
            }
        }
        // A held key sends repeat presses, so a held Down keeps moving. The
        // handler sits on the container so that Esc still works after a click
        // in the selectable result text moves the focus off the query field.
        .onKeyPress(phases: [.down, .repeat], action: handleKeyPress)
        // NSHostingView shrinks the window to the view's minimum size, which
        // is tiny for a lazy list, so pin a usable minimum.
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        // Focus on open was verified only with both mechanisms in place. The
        // onAppear assignment is deferred because SwiftUI ignores a focus change
        // before the window becomes key, and onAppear runs earlier than that.
        .defaultFocus($isQueryFieldFocused, true)
        .onAppear { DispatchQueue.main.async { isQueryFieldFocused = true } }
    }

    private var candidateList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.candidates) { candidate in
                        CandidateRow(
                            candidate: candidate,
                            isSelected: candidate == viewModel.selectedCandidate
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectCandidate(candidate)
                            activateAndDismiss()
                        }
                    }
                }
            }
            .onChange(of: viewModel.selectedCandidate) { _, candidate in
                guard let candidate else { return }
                scrollProxy.scrollTo(candidate.id)
            }
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let command = LauncherKeyBindings.resolve(
            key: keyPress.key,
            isControlPressed: keyPress.modifiers.contains(.control),
            isRepeat: keyPress.phase == .repeat
        )
        switch command {
        case .dismiss where viewModel.resultPanel != nil:
            viewModel.closeResult()
        case .moveSelection(let offset):
            viewModel.moveSelection(by: offset)
        case .dismiss:
            dismiss()
        case .swallow:
            break
        case nil:
            return .ignored
        }
        return .handled
    }

    // Keep the window open when no action runs, such as on an empty list or
    // a row without actions, so the user can keep typing.
    private func activateAndDismiss() {
        guard viewModel.activateSelectedCandidate() else { return }
        dismiss()
    }
}

private struct CandidateRow: View {
    // Every folder row shares the generic folder icon, because reading each
    // directory's own icon would hit the disk on every render.
    private static let folderIcon = NSWorkspace.shared.icon(for: .folder)

    let candidate: LauncherCandidate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
            // One line per row keeps the rows the same height when a long
            // window title meets the badge column.
            Text(candidate.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            KindBadge(kind: candidate.kind)
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? Color.accentColor : Color.clear)
    }

    private var icon: NSImage {
        switch candidate.icon {
        case .applicationBundle(let application):
            return ApplicationIconCache.shared.loadIcon(for: application)
        case .runningApplication(let processIdentifier):
            return ApplicationIconCache.shared.loadIcon(forProcess: processIdentifier)
        case .folder:
            return Self.folderIcon
        case .fileType(let fileExtension):
            return ApplicationIconCache.shared.loadIcon(forFileExtension: fileExtension)
        case .systemSymbol(let symbolName):
            return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage()
        }
    }
}

// A fixed width lines the badges up in a column, so that the eye can scan
// the kinds down the right edge of the list.
private struct KindBadge: View {
    private static let width: CGFloat = 84

    let kind: LauncherCandidateKind

    var body: some View {
        Label(kind.label, systemImage: kind.symbolName)
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .frame(width: Self.width, alignment: .leading)
    }
}

/// The result panel: a scrolling, selectable text with a footer of actions.
private struct ResultPanelView: View {
    @ObservedObject var panel: ResultPanelModel
    let copyText: (String) -> Void
    let closePanel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            Divider()
            footer
        }
    }

    @ViewBuilder private var content: some View {
        switch panel.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView().controlSize(.small)
        case .streaming(let text), .finished(let text):
            Text(text).textSelection(.enabled)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(Color.red)
                .textSelection(.enabled)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(panel.title)
                .font(.caption)
                .foregroundStyle(Color.secondary)
            Spacer()
            ForEach(panel.actions) { action in
                Button(action.title) { panel.perform(action) }
                    .disabled(panel.state.text == nil)
            }
            Button("Copy") { copyText(panel.state.text ?? "") }
                .disabled(panel.state.text == nil)
            Button("Back (Esc)", action: closePanel)
        }
        .padding(8)
    }
}
