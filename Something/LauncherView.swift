import AppKit
import SwiftUI

/// Shows every application under a query field and narrows the list on each
/// keystroke, in the style of Emacs anything.el.
struct LauncherView: View {
    static let minimumSize = CGSize(width: 600, height: 400)

    // AppDelegate owns the view model and pushes rescans into it.
    @ObservedObject var viewModel: LauncherViewModel
    let dismiss: () -> Void
    @FocusState private var isQueryFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Application", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.title2)
                .padding(12)
                .focused($isQueryFieldFocused)
                .onSubmit(launchAndDismiss)
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
                    ForEach(viewModel.candidates) { application in
                        CandidateRow(
                            application: application,
                            isSelected: application == viewModel.selectedApplication
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectApplication(application)
                            launchAndDismiss()
                        }
                    }
                }
            }
            .onChange(of: viewModel.selectedApplication) { _, application in
                guard let application else { return }
                scrollProxy.scrollTo(application.id)
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

    // Keep the window and the query when nothing matches, so the user can
    // fix a typo instead of retyping the whole query.
    private func launchAndDismiss() {
        guard viewModel.launchSelectedApplication() else { return }
        dismiss()
    }
}

private struct CandidateRow: View {
    let application: LaunchableApplication
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: ApplicationIconCache.shared.loadIcon(for: application))
                .resizable()
                .frame(width: 20, height: 20)
            Text(application.name)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? Color.accentColor : Color.clear)
    }
}
