import AppKit
import CoreText
import SceneKit
import SwiftUI

/// Hosts the mascot's SceneKit scene. SwiftUI only passes state and query in;
/// the balance simulation keeps running on SceneKit's render loop.
struct MascotView: NSViewRepresentable {
    let state: MascotState
    let query: String
    let placement: MascotPlacement
    /// The shapes are read once, when the scene is built. Later changes repaint
    /// the colors only.
    let model: MascotModel

    func makeCoordinator() -> MascotRenderer {
        MascotRenderer(model: model, placement: placement)
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.rig.scene
        view.pointOfView = context.coordinator.rig.cameraNode
        view.delegate = context.coordinator
        // Transparent so the launcher background shows around the robot.
        view.backgroundColor = .clear
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        // The delegate only fires while the scene is playing.
        view.isPlaying = true
        context.coordinator.mailbox.send(state: state, query: query)
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.mailbox.send(state: state, query: query)
        context.coordinator.updateColors(of: model)
    }
}

/// Steps the animator and applies its frame to the nodes. SceneKit calls the
/// delegate on its render thread. After setup, only that thread touches the
/// pose and the screen texture. The main thread touches only the mailbox and,
/// through `updateColors(of:)`, the part colors, which SceneKit lets any
/// thread change.
final class MascotRenderer: NSObject, SCNSceneRendererDelegate, @unchecked Sendable {
    let mailbox = MascotMailbox()
    let rig: MascotRig
    private var animator: MascotAnimator
    private let placement: MascotPlacement
    private var lastTime: TimeInterval?
    private var shownText: String?
    private var paintedModel: MascotModel

    init(model: MascotModel, placement: MascotPlacement) {
        self.placement = placement
        paintedModel = model
        animator = MascotAnimator(placement: placement)
        rig = MascotSceneBuilder.build(model, placement: placement)
        textColor = MascotModel.rgb(hex: model.screen.textColor) ?? (red: 1, green: 1, blue: 1)
        super.init()
    }

    private let textColor: (red: Double, green: Double, blue: Double)

    /// Repaints the parts when the colors of `model` differ from the last ones.
    /// Call it on the main thread only, because `paintedModel` has no lock.
    func updateColors(of model: MascotModel) {
        guard model != paintedModel else { return }
        paintedModel = model
        MascotSceneBuilder.applyColors(of: model, to: rig)
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let gap = lastTime.map { time - $0 } ?? 0
        lastTime = time
        let frame = animator.advance(by: gap, snapshot: mailbox.read())
        apply(frame)
    }

    private func apply(_ frame: MascotFrame) {
        // The resting yaw faces screen-left, toward the launcher for `.top` and `.right`.
        // On the left the whole pose is mirrored, which is cheaper than a second resting yaw.
        let yaw = placement == .left ? -frame.yaw : frame.yaw
        rig.root.position = SCNVector3(
            CGFloat(sin(yaw) * frame.position), CGFloat(frame.lift), CGFloat(cos(yaw) * frame.position))
        rig.root.eulerAngles = SCNVector3(0, CGFloat(yaw), 0)
        rig.groups[.tilt]?.eulerAngles = SCNVector3(CGFloat(frame.lean), 0, 0)
        rig.groups[.head]?.eulerAngles = SCNVector3(CGFloat(frame.headPitch), 0, CGFloat(frame.headTilt))
        rig.groups[.wheelLeft]?.eulerAngles = SCNVector3(CGFloat(frame.leftWheelRoll), 0, 0)
        rig.groups[.wheelRight]?.eulerAngles = SCNVector3(CGFloat(frame.rightWheelRoll), 0, 0)
        offset(.handLeft, x: 0, y: frame.leftHandLift)
        offset(.handRight, x: frame.rightHandSideways, y: frame.rightHandLift)

        // Redrawing the texture is the expensive part, so only do it on change.
        if frame.screenText != shownText {
            shownText = frame.screenText
            rig.screenMaterial.diffuse.contents = renderText(frame.screenText)
        }
    }

    private func offset(_ group: MascotModel.Group, x: Double, y: Double) {
        guard let node = rig.groups[group], let base = rig.groupBasePositions[group] else { return }
        node.position = SCNVector3(base.x + CGFloat(x), base.y + CGFloat(y), base.z)
    }

    // Texture size and font follow the prototype's canvas; the text capacity in
    // MascotScreen.visibleQueryCharacters assumes this font size.
    private static let textureWidth = 360
    private static let textureHeight = 200
    private static let fontSize: CGFloat = 84

    /// Core Graphics and Core Text only, because this runs on the render thread
    /// where AppKit drawing is not safe to assume.
    private func renderText(_ text: String) -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: Self.textureWidth, height: Self.textureHeight, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let font = CTFontCreateWithName("Menlo-Bold" as CFString, Self.fontSize, nil)
        let color = CGColor(
            red: CGFloat(textColor.red), green: CGFloat(textColor.green), blue: CGFloat(textColor.blue), alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        // Centre the glyph band vertically; the left margin matches the prototype.
        let baseline = CGFloat(Self.textureHeight) / 2 - (CTFontGetAscent(font) - CTFontGetDescent(font)) / 2
        context.textPosition = CGPoint(x: 26, y: baseline)
        CTLineDraw(line, context)
        return context.makeImage()
    }
}
