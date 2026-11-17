import SwiftSyntax

/// Finds calls that pass a trailing closure to a callee in `labelsByCalleeName`.
final class TrailingClosureFinder: SyntaxVisitor {
    private(set) var violations: [LintViolation] = []
    private let labelsByCalleeName: [String: String]
    private let path: String
    private let locationConverter: SourceLocationConverter

    init(labelsByCalleeName: [String: String], path: String, tree: SourceFileSyntax) {
        self.labelsByCalleeName = labelsByCalleeName
        self.path = path
        self.locationConverter = SourceLocationConverter(fileName: path, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // With several trailing closures, the last one is written with its label.
        guard let trailingClosure = node.trailingClosure,
            node.additionalTrailingClosures.isEmpty,
            let calleeName = findCalleeName(of: node.calledExpression),
            let label = labelsByCalleeName[calleeName]
        else {
            return .visitChildren
        }
        let location = trailingClosure.leftBrace.startLocation(converter: locationConverter)
        violations.append(
            LintViolation(
                path: path,
                line: location.line,
                column: location.column,
                calleeName: calleeName,
                label: label
            )
        )
        return .visitChildren
    }
}

/// Returns the base name that a call names, such as `reload` for `loader.reload`.
private func findCalleeName(of expression: ExprSyntax) -> String? {
    if let reference = expression.as(DeclReferenceExprSyntax.self) {
        return reference.baseName.text
    }
    if let member = expression.as(MemberAccessExprSyntax.self) {
        return member.declName.baseName.text
    }
    if let specialization = expression.as(GenericSpecializationExprSyntax.self) {
        return findCalleeName(of: specialization.expression)
    }
    return nil
}
