import SwiftParser

/// One Swift source file to lint.
public struct LintSource: Sendable {
    /// The path that violations report, such as `Something/AppDelegate.swift`.
    public let path: String
    public let text: String

    public init(path: String, text: String) {
        self.path = path
        self.text = text
    }
}

/// A call that passes a trailing closure to a callee whose last parameter is a labeled closure.
public struct LintViolation: Equatable, Sendable, CustomStringConvertible {
    public let path: String
    /// 1-based line of the trailing closure's `{`.
    public let line: Int
    /// 1-based column of the trailing closure's `{`.
    public let column: Int
    public let calleeName: String
    public let label: String

    /// The violation in the `path:line:column: error: message` form that Xcode and editors parse.
    public var description: String {
        "\(path):\(line):\(column): error: Pass the closure to '\(calleeName)' with its "
            + "label '\(label):' instead of as a trailing closure (closure_label)"
    }
}

/// Returns the trailing-closure calls in `sources` whose callee drops a closure label.
///
/// The callees come from the declarations in `sources` only, so calls of SwiftUI and
/// standard library APIs never match. Callees match by base name, without type checking.
public func findViolations(in sources: [LintSource]) -> [LintViolation] {
    let trees = sources.map { Parser.parse(source: $0.text) }
    let collector = LabeledClosureCollector()
    for tree in trees {
        collector.walk(tree)
    }
    return zip(sources, trees).flatMap { source, tree in
        let finder = TrailingClosureFinder(
            labelsByCalleeName: collector.labelsByCalleeName,
            path: source.path,
            tree: tree
        )
        finder.walk(tree)
        return finder.violations
    }
}
