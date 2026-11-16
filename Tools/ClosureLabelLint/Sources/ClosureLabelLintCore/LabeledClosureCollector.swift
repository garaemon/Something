import SwiftSyntax

/// Collects callees whose last parameter is a labeled closure, keyed by base name.
///
/// A function maps from its own name, and an initializer from the name of its type, because
/// a call names the type, as in `SettingsSource(openSettings:)`. The value is the label.
final class LabeledClosureCollector: SyntaxVisitor {
    private(set) var labelsByCalleeName: [String: String] = [:]
    private var enclosingTypeNames: [String] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        recordLastClosureLabel(of: node.signature.parameterClause, calleeName: node.name.text)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if let typeName = enclosingTypeNames.last {
            recordLastClosureLabel(of: node.signature.parameterClause, calleeName: typeName)
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypeNames.append(node.name.text)
        if let label = findMemberwiseClosureLabel(of: node.memberBlock) {
            labelsByCalleeName[node.name.text] = label
        }
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        enclosingTypeNames.removeLast()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypeNames.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        enclosingTypeNames.removeLast()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypeNames.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        enclosingTypeNames.removeLast()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypeNames.append(findBaseName(of: node.extendedType))
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        enclosingTypeNames.removeLast()
    }

    private func recordLastClosureLabel(
        of clause: FunctionParameterClauseSyntax,
        calleeName: String
    ) {
        guard let lastParameter = clause.parameters.last,
            lastParameter.firstName.tokenKind != .wildcard,
            isClosureType(lastParameter.type)
        else {
            return
        }
        labelsByCalleeName[calleeName] = lastParameter.firstName.text
    }

    /// Returns the label of the memberwise initializer's last parameter when it takes a closure.
    ///
    /// Swift synthesizes the memberwise initializer only when the struct body declares no
    /// initializer. Its parameters follow the stored instance properties in order.
    private func findMemberwiseClosureLabel(of memberBlock: MemberBlockSyntax) -> String? {
        let declarations = memberBlock.members.map(\.decl)
        guard !declarations.contains(where: { $0.is(InitializerDeclSyntax.self) }) else {
            return nil
        }
        let storedBindings = declarations.compactMap { $0.as(VariableDeclSyntax.self) }
            .filter(isStoredInstanceProperty)
            .flatMap(\.bindings)
            .filter { $0.accessorBlock == nil }
        guard let lastBinding = storedBindings.last,
            let name = lastBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            let type = lastBinding.typeAnnotation?.type,
            isClosureType(type)
        else {
            return nil
        }
        return name
    }

    private func isStoredInstanceProperty(_ variable: VariableDeclSyntax) -> Bool {
        let excludedModifiers: Set<String> = ["static", "class", "lazy"]
        return !variable.modifiers.contains { excludedModifiers.contains($0.name.text) }
    }
}

/// Returns whether `type` is a function type, looking through `@escaping`, parentheses, and `?`.
func isClosureType(_ type: TypeSyntax) -> Bool {
    if type.is(FunctionTypeSyntax.self) {
        return true
    }
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return isClosureType(attributed.baseType)
    }
    if let optional = type.as(OptionalTypeSyntax.self) {
        return isClosureType(optional.wrappedType)
    }
    if let implicitlyUnwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return isClosureType(implicitlyUnwrapped.wrappedType)
    }
    if let tuple = type.as(TupleTypeSyntax.self), tuple.elements.count == 1,
        let element = tuple.elements.first, element.firstName == nil
    {
        return isClosureType(element.type)
    }
    return false
}

/// Returns the last name component of `type`, such as `Source` for `Module.Source<T>`.
private func findBaseName(of type: TypeSyntax) -> String {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return identifier.name.text
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return member.name.text
    }
    return type.trimmedDescription
}
