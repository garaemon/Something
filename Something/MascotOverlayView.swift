import SwiftUI

/// Content of the mascot's panel: the robot, driven by the launcher's query.
/// It owns the entrance timing that decides when `appearing` gives way to `idle`.
struct MascotOverlayView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let placement: MascotPlacement
    let model: MascotModel
    // Plays the entrance until it ends or the user types.
    @State private var justOpened = true

    var body: some View {
        // No background on purpose: the panel is transparent, and the robot should
        // look like it stands beside or on the launcher.
        MascotView(state: mascotState, query: viewModel.query, placement: placement, model: model)
            .onAppear {
                let entranceEnd = DispatchTime.now() + MascotChoreography.appearDuration
                DispatchQueue.main.asyncAfter(deadline: entranceEnd) { justOpened = false }
            }
            .onChange(of: viewModel.query) { justOpened = false }
    }

    private var mascotState: MascotState {
        // Web searches and "Add task" are listed for every non-empty query, so they
        // do not count as a match. Counting them would keep the robot from ever
        // showing "?".
        let alwaysListedSourceIDs = [
            WebSearchSource.webSearchSourceID, AddTaskSource.addTaskSourceID,
        ]
        let matchCount = viewModel.candidates.filter {
            !alwaysListedSourceIDs.contains($0.id.sourceID)
        }.count
        return MascotState.derive(
            query: viewModel.query,
            candidateCount: matchCount,
            justOpened: justOpened
        )
    }
}
