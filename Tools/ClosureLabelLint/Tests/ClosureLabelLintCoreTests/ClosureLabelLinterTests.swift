import ClosureLabelLintCore
import Testing

private func lint(_ text: String) -> [LintViolation] {
    findViolations(in: [LintSource(path: "Test.swift", text: text)])
}

@Test func should_report_nothing_when_closure_is_labeled() {
    let violations = lint(
        """
        func schedule(after delay: Double, perform action: () -> Void) {}
        schedule(after: 1, perform: { print("hi") })
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_trailing_closure_of_function_with_labeled_closure() {
    let violations = lint(
        """
        func schedule(after delay: Double, perform action: () -> Void) {}
        schedule(after: 1) { print("hi") }
        """
    )

    #expect(violations.map(\.calleeName) == ["schedule"])
}

@Test func should_report_label_of_dropped_closure() {
    let violations = lint(
        """
        func schedule(after delay: Double, perform action: () -> Void) {}
        schedule(after: 1) { print("hi") }
        """
    )

    #expect(violations.map(\.label) == ["perform"])
}

@Test func should_report_location_of_trailing_closure_brace() {
    let violations = lint(
        """
        func schedule(perform action: () -> Void) {}
        func run() {
            schedule { print("hi") }
        }
        """
    )

    #expect(violations.map { [$0.line, $0.column] } == [[3, 14]])
}

@Test func should_report_trailing_closure_of_method_call() {
    let violations = lint(
        """
        final class Loader {
            func reload(completion: @escaping () -> Void) {}
        }
        Loader().reload { }
        """
    )

    #expect(violations.map(\.calleeName) == ["reload"])
}

@Test func should_report_trailing_closure_of_initializer() {
    let violations = lint(
        """
        struct SettingsSource {
            init(openSettings: @escaping () -> Void) {}
        }
        let source = SettingsSource { }
        """
    )

    #expect(violations.map(\.calleeName) == ["SettingsSource"])
}

@Test func should_report_trailing_closure_of_initializer_in_extension() {
    let violations = lint(
        """
        struct SettingsSource {}
        extension SettingsSource {
            init(openSettings: @escaping () -> Void) { self.init() }
        }
        let source = SettingsSource { }
        """
    )

    #expect(violations.map(\.calleeName) == ["SettingsSource"])
}

@Test func should_report_trailing_closure_of_memberwise_initializer() {
    let violations = lint(
        """
        struct SettingsSource {
            let title: String
            let openSettings: () -> Void
        }
        let source = SettingsSource(title: "Settings") { }
        """
    )

    #expect(violations.map(\.label) == ["openSettings"])
}

@Test func should_skip_memberwise_initializer_when_struct_declares_initializer() {
    let violations = lint(
        """
        struct SettingsSource {
            let openSettings: () -> Void
            init(_ openSettings: @escaping () -> Void) { self.openSettings = openSettings }
        }
        let source = SettingsSource { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_skip_static_and_computed_properties_for_memberwise_initializer() {
    let violations = lint(
        """
        struct Source {
            let title: String
            static let fallback: () -> Void = {}
            var action: () -> Void { {} }
        }
        func make(_ build: () -> Source) {}
        make { Source(title: "x") }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_trailing_closure_for_optional_closure_parameter() {
    let violations = lint(
        """
        func close(completion: (() -> Void)? = nil) {}
        close { }
        """
    )

    #expect(violations.map(\.calleeName) == ["close"])
}

@Test func should_report_nothing_when_closure_parameter_has_no_label() {
    let violations = lint(
        """
        func withLock(_ body: () -> Void) {}
        withLock { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_nothing_when_last_parameter_is_not_closure() {
    let violations = lint(
        """
        func run(action: () -> Void, count: Int = 1) {}
        run { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_nothing_when_last_closure_keeps_label_in_multiple_trailing_closures() {
    let violations = lint(
        """
        func animate(changes: () -> Void, completion: () -> Void) {}
        animate { } completion: { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_nothing_for_swiftui_builders_and_standard_library() {
    let violations = lint(
        """
        struct ContentView: View {
            var body: some View {
                VStack { Text("a") }.onAppear { print([1, 2].map { $0 * 2 }) }
            }
        }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_call_in_other_file_than_declaration() {
    let sources = [
        LintSource(path: "Declaration.swift", text: "func reload(completion: () -> Void) {}"),
        LintSource(path: "Call.swift", text: "reload { }"),
    ]

    let violations = findViolations(in: sources)

    #expect(violations.map(\.path) == ["Call.swift"])
}

@Test func should_format_violation_for_editors() {
    let violations = lint(
        """
        func reload(completion: () -> Void) {}
        reload { }
        """
    )

    #expect(
        violations.map(\.description) == [
            "Test.swift:2:8: error: Pass the closure to 'reload' with its label 'completion:' "
                + "instead of as a trailing closure (closure_label)"
        ]
    )
}
