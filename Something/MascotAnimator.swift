import Foundation

/// Everything the renderer needs for one frame, already in scene units and radians.
struct MascotFrame: Equatable {
    var position = 0.0
    var lift = 0.0
    var yaw = MascotChoreography.restingYaw
    var lean = 0.0
    var headPitch = 0.0
    var headTilt = 0.0
    var leftHandLift = 0.0
    var rightHandLift = 0.0
    var rightHandSideways = 0.0
    var leftWheelRoll = 0.0
    var rightWheelRoll = 0.0
    var screenText = ""
}

/// Runs the balance simulation behind the render loop and maps its state to a pose.
/// It has no SceneKit dependency so that the frame logic stays testable.
struct MascotAnimator {
    static let wheelRadius = 0.2
    static let wheelHalfTrack = 0.32
    /// Visual lean is exaggerated against the simulated lean for readability.
    static let leanExaggeration = 1.4
    static let headCounterTilt = 0.4
    /// A frame gap longer than this (window hidden, debugger) must not trigger a catch-up burst.
    static let maximumFrameGap = 0.1
    static let maximumYawSpeed = 6.0

    private var simulation = BalanceSimulation()
    private var accumulator = 0.0
    private var appliedEpoch = -1
    private var appliedInputCount = 0
    private var state = MascotState.appearing
    private var stateTime = 0.0
    private var sinceInput = 9.0
    private var yaw = MascotChoreography.restingYaw
    // Keystroke kicks are applied once, in the first step after the query changed.
    private var carriedKick = 0.0

    init() {
        // Wobble naturally from the first frame, as the prototype does.
        simulation.settle(seconds: 2)
    }

    mutating func advance(by frameGap: Double, snapshot: MascotSnapshot) -> MascotFrame {
        applyChanges(snapshot)
        accumulator += min(max(frameGap, 0), Self.maximumFrameGap)
        let dt = BalanceSimulation.fixedStep
        var pendingKick = carriedKick
        while accumulator >= dt {
            let pose = currentPose(snapshot)
            simulation.step(dt: dt, command: .init(target: pose.target, kick: pendingKick))
            pendingKick = 0
            approachYaw(pose.yaw, dt: dt)
            let previousTime = stateTime
            stateTime += dt
            if state == .appearing && previousTime < MascotChoreography.landingTime
                && stateTime >= MascotChoreography.landingTime
            {
                // The landing jolt makes the robot wobble instead of landing dead still.
                pendingKick += MascotChoreography.landingKick
            }
            sinceInput += dt
            accumulator -= dt
        }
        // A kick that arrived while no whole step fit yet is kept for the next call.
        carriedKick = pendingKick
        return makeFrame(snapshot)
    }

    private mutating func applyChanges(_ snapshot: MascotSnapshot) {
        if snapshot.stateEpoch != appliedEpoch {
            appliedEpoch = snapshot.stateEpoch
            state = snapshot.state
            stateTime = 0
            if state == .appearing {
                // Start upright and still, hidden behind the window edge.
                simulation = BalanceSimulation()
                simulation.settle(seconds: 2)
            }
        }
        if snapshot.inputCount != appliedInputCount {
            appliedInputCount = snapshot.inputCount
            sinceInput = 0
            // Alternate the direction. Kicks that all push the same way act as a
            // steady force, and a held key then drives the robot out of view.
            let direction = appliedInputCount % 2 == 0 ? -1.0 : 1.0
            carriedKick += direction * MascotChoreography.typingKick
        }
    }

    private func currentPose(_ snapshot: MascotSnapshot) -> MascotPose {
        MascotChoreography.pose(
            state: state, elapsed: stateTime, sinceInput: sinceInput, inputCount: snapshot.inputCount)
    }

    private mutating func approachYaw(_ desired: Double, dt: Double) {
        let limit = Self.maximumYawSpeed * dt
        yaw += min(max(desired - yaw, -limit), limit)
    }

    private func makeFrame(_ snapshot: MascotSnapshot) -> MascotFrame {
        let pose = currentPose(snapshot)
        let roll = simulation.position / Self.wheelRadius
        let turn = (yaw - MascotChoreography.restingYaw) * Self.wheelHalfTrack / Self.wheelRadius
        // Typing restarts the text clock at each keystroke so the cursor reacts.
        let textElapsed = state == .typing ? sinceInput : stateTime
        return MascotFrame(
            position: simulation.position,
            lift: pose.lift,
            yaw: yaw,
            lean: simulation.lean * Self.leanExaggeration,
            headPitch: pose.headNod - simulation.lean * Self.headCounterTilt,
            headTilt: pose.headTilt,
            leftHandLift: pose.leftHandLift,
            rightHandLift: pose.rightHandLift,
            rightHandSideways: pose.rightHandSideways,
            leftWheelRoll: roll + turn,
            rightWheelRoll: roll - turn,
            screenText: MascotScreen.text(for: state, query: snapshot.query, elapsed: textElapsed))
    }
}
