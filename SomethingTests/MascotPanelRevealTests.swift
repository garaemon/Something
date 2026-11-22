import SceneKit
import XCTest

@testable import Something

@MainActor
final class MascotPanelRevealTests: XCTestCase {
    private func makePanel() -> MascotPanel {
        MascotPanel.make(
            viewModel: LauncherViewModel(sources: []),
            launcherFrame: CGRect(x: 100, y: 200, width: 600, height: 400),
            placement: .right,
            model: .default
        )
    }

    func test_should_start_the_panel_transparent() {
        let panel = makePanel()

        XCTAssertEqual(panel.alphaValue, 0)
    }

    func test_should_make_the_panel_opaque_when_the_reveal_handler_runs() {
        let panel = makePanel()
        let revealPanel = MascotPanel.makeRevealHandler(for: panel)

        revealPanel()

        XCTAssertEqual(panel.alphaValue, 1)
    }

    func test_should_report_the_first_rendered_frame_on_the_main_thread() {
        let firstFrameReported = expectation(description: "first frame reported")
        let renderer = MascotRenderer(
            model: .default,
            placement: .right,
            onFirstFrameRendered: {
                XCTAssertTrue(Thread.isMainThread)
                firstFrameReported.fulfill()
            }
        )
        let sceneRenderer = SCNRenderer(device: nil, options: nil)

        DispatchQueue.global().async {
            renderer.renderer(sceneRenderer, didRenderScene: renderer.rig.scene, atTime: 0)
        }

        wait(for: [firstFrameReported], timeout: 2)
    }

    func test_should_report_only_the_first_rendered_frame() {
        var reportCount = 0
        let renderer = MascotRenderer(
            model: .default,
            placement: .right,
            onFirstFrameRendered: { reportCount += 1 }
        )
        let sceneRenderer = SCNRenderer(device: nil, options: nil)
        renderer.renderer(sceneRenderer, didRenderScene: renderer.rig.scene, atTime: 0)
        renderer.renderer(sceneRenderer, didRenderScene: renderer.rig.scene, atTime: 1)

        // The main queue is FIFO, so every report block has run before this one.
        let queueDrained = expectation(description: "main queue drained")
        DispatchQueue.main.async { queueDrained.fulfill() }
        wait(for: [queueDrained], timeout: 1)

        XCTAssertEqual(reportCount, 1)
    }
}
