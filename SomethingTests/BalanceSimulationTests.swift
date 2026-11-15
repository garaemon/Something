import XCTest

@testable import Something

final class BalanceSimulationTests: XCTestCase {
    private func run(
        _ simulation: inout BalanceSimulation, seconds: Double, command: BalanceSimulation.Command = .init(),
        onStep: (BalanceSimulation) -> Void = { _ in }
    ) {
        let steps = Int(seconds / BalanceSimulation.fixedStep)
        for _ in 0..<steps {
            simulation.step(dt: BalanceSimulation.fixedStep, command: command)
            onStep(simulation)
        }
    }

    func test_should_stay_upright_and_bounded_over_many_seconds() {
        var simulation = BalanceSimulation()
        var maxLean = 0.0
        var maxPosition = 0.0

        run(&simulation, seconds: 30) {
            maxLean = max(maxLean, abs($0.lean))
            maxPosition = max(maxPosition, abs($0.position))
        }

        XCTAssertLessThan(maxLean, 0.1)
        XCTAssertLessThan(maxPosition, 0.3)
    }

    func test_should_wobble_instead_of_standing_perfectly_still() {
        var simulation = BalanceSimulation()

        run(&simulation, seconds: 2)

        XCTAssertNotEqual(simulation.lean, 0)
    }

    func test_should_converge_to_commanded_target() {
        var simulation = BalanceSimulation()

        run(&simulation, seconds: 12, command: .init(target: 1.0))

        XCTAssertEqual(simulation.position, 1.0, accuracy: 0.2)
        XCTAssertLessThan(abs(simulation.lean), 0.1)
    }

    func test_should_recover_from_a_kick() {
        var simulation = BalanceSimulation()
        run(&simulation, seconds: 1)

        simulation.step(command: .init(kick: 1.2))
        var maxLean = 0.0
        run(&simulation, seconds: 1) { maxLean = max(maxLean, abs($0.lean)) }
        run(&simulation, seconds: 5)

        XCTAssertLessThan(maxLean, 0.5)
        XCTAssertLessThan(abs(simulation.lean), 0.05)
        XCTAssertLessThan(abs(simulation.position), 0.3)
    }

    func test_should_be_deterministic() {
        var first = BalanceSimulation()
        var second = BalanceSimulation()

        run(&first, seconds: 5, command: .init(target: 0.5))
        run(&second, seconds: 5, command: .init(target: 0.5))

        XCTAssertEqual(first, second)
    }

    func test_should_drive_in_from_the_start_position() {
        var simulation = BalanceSimulation(position: MascotChoreography.startPosition)

        run(&simulation, seconds: 6)

        XCTAssertEqual(simulation.position, 0, accuracy: 0.2)
        XCTAssertLessThan(abs(simulation.lean), 0.1)
    }
}
