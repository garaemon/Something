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

@Test func should_skip_static_property_for_memberwise_initializer() {
    let violations = lint(
        """
        struct Source {
            let title: String
            static var fallback: () -> Void = {}
        }
        let source = Source { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_skip_computed_property_for_memberwise_initializer() {
    let violations = lint(
        """
        struct Source {
            let title: String
            var action: () -> Void { {} }
        }
        let source = Source { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_skip_initialized_let_for_memberwise_initializer() {
    let violations = lint(
        """
        struct Source {
            let action: () -> Void
            let suffix: String = ""
        }
        let source = Source { }
        """
    )

    #expect(violations.map(\.label) == ["action"])
}

@Test func should_keep_initialized_var_for_memberwise_initializer() {
    let violations = lint(
        """
        struct Source {
            let title: String
            var action: () -> Void = {}
        }
        let source = Source(title: "x") { }
        """
    )

    #expect(violations.map(\.label) == ["action"])
}

@Test func should_report_trailing_closure_of_actor_initializer() {
    let violations = lint(
        """
        actor Worker {
            init(onFinish: @escaping () -> Void) {}
        }
        let worker = Worker { }
        """
    )

    #expect(violations.map(\.calleeName) == ["Worker"])
}

@Test func should_skip_initializer_requirement_of_nested_protocol() {
    let violations = lint(
        """
        enum Namespace {
            protocol Factory {
                init(build: @escaping () -> Void)
            }
        }
        let value = Namespace { }
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

@Test func should_report_closure_followed_by_defaulted_parameters() {
    let violations = lint(
        """
        func run(action: () -> Void, count: Int = 1) {}
        run { }
        """
    )

    #expect(violations.map(\.label) == ["action"])
}

@Test func should_report_nothing_when_closure_is_followed_by_required_parameter() {
    let violations = lint(
        """
        func run(action: () -> Void, count: Int) {}
        run { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_memberwise_closure_followed_by_omittable_properties() {
    let violations = lint(
        """
        struct Row {
            let onTap: () -> Void
            var isHovered = false
            var subtitle: String?
        }
        let row = Row { }
        """
    )

    #expect(violations.map(\.label) == ["onTap"])
}

@Test func should_report_nothing_when_memberwise_closure_is_followed_by_required_property() {
    let violations = lint(
        """
        struct Row {
            let onTap: () -> Void
            let title: String
        }
        let row = Row { }
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

@Test func should_report_nothing_when_earlier_parameter_takes_closure() {
    let violations = lint(
        """
        func animate(changes: () -> Void, completion: (() -> Void)? = nil) {}
        animate { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_nothing_when_earlier_memberwise_parameter_takes_closure() {
    let violations = lint(
        """
        struct Animation {
            let changes: () -> Void
            var completion: (() -> Void)? = nil
        }
        let animation = Animation { }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_keep_observed_property_for_memberwise_initializer() {
    let violations = lint(
        """
        struct Source {
            let title: String
            var action: () -> Void { didSet { print("changed") } }
        }
        let source = Source(title: "x") { }
        """
    )

    #expect(violations.map(\.label) == ["action"])
}

@Test func should_report_nothing_for_result_builder_property() {
    let violations = lint(
        """
        struct Card<Content: View>: View {
            @ViewBuilder let content: () -> Content
        }
        let card = Card { Text("a") }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_nothing_for_result_builder_parameter() {
    let violations = lint(
        """
        func section(@ViewBuilder content: () -> some View) {}
        section { Text("a") }
        """
    )

    #expect(violations.isEmpty)
}

@Test func should_report_trailing_closure_of_generic_specialized_call() {
    let violations = lint(
        """
        struct Box<Value> {
            let onChange: (Value) -> Void
        }
        let box = Box<Int> { _ in }
        """
    )

    #expect(violations.map(\.calleeName) == ["Box"])
}

@Test func should_report_trailing_closure_of_initializer_in_extension_of_member_type() {
    let violations = lint(
        """
        enum Namespace {
            struct Source {}
        }
        extension Namespace.Source {
            init(openSettings: @escaping () -> Void) { self.init() }
        }
        let source = Namespace.Source { }
        """
    )

    #expect(violations.map(\.calleeName) == ["Source"])
}
