import SwiftUI

/// Content of the mascot's panel: the robot, driven by the launcher's query.
/// It owns the entrance timing that decides when `appearing` gives way to `idle`.
struct MascotOverlayView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let placement: MascotPlacement
    // Plays the entrance until it ends or the user types.
    @State private var justOpened = true

    var body: some View {
        // No background on purpose: the panel is transparent, and the robot should
        // look like it stands beside or on the launcher.
        MascotView(state: mascotState, query: viewModel.query, placement: placement)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + MascotChoreography.appearDuration) {
                    justOpened = false
                }
            }
            .onChange(of: viewModel.query) { justOpened = false }
    }

    private var mascotState: MascotState {
        MascotState.derive(
            query: viewModel.query, candidateCount: viewModel.candidates.count, justOpened: justOpened)
    }
}
