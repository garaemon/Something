import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Shows the windows of running applications, every application, and then the
/// ghq repositories under a query field, and narrows the list on each
/// keystroke, in the style of Emacs anything.el. A non-empty query also lists
/// web searches for it at the end.
struct LauncherView: View {
    static let minimumSize = CGSize(width: 600, height: 400)

    // AppDelegate owns the view model and pushes rescans into it.
    @ObservedObject var viewModel: LauncherViewModel
    let dismiss: () -> Void
    @FocusState private var isQueryFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Window, Application, Repository, or Web Search", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.title2)
                .padding(12)
                .focused($isQueryFieldFocused)
                .onSubmit(activateAndDismiss)
                .onKeyPress(phases: .down, action: handleKeyPress)
            Divider()
            candidateList
        }
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
        let isControlPressed = keyPress.modifiers.contains(.control)
        switch (keyPress.key, isControlPressed) {
        case (.downArrow, _), (KeyEquivalent("n"), true):
            viewModel.moveSelection(by: 1)
        case (.upArrow, _), (KeyEquivalent("p"), true):
            viewModel.moveSelection(by: -1)
        case (.escape, _), (KeyEquivalent("g"), true):
            dismiss()
        default:
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
