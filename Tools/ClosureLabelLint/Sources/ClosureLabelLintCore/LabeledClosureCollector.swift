import SwiftSyntax

/// Collects callees that a trailing closure would strip of a closure label, keyed by base name.
///
/// A function maps from its own name, and an initializer from the name of its type, because
/// a call names the type, as in `SettingsSource(openSettings:)`. The value is the label.
final class LabeledClosureCollector: SyntaxVisitor {
    private(set) var labelsByCalleeName: [String: String] = [:]
    /// `nil` marks a protocol, whose initializer requirements no call can name.
    private var enclosingTypeNames: [String?] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        recordClosureLabel(of: node.signature.parameterClause, calleeName: node.name.text)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if let typeName = enclosingTypeNames.last ?? nil {
            recordClosureLabel(of: node.signature.parameterClause, calleeName: typeName)
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

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypeNames.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        enclosingTypeNames.removeLast()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypeNames.append(nil)
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
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

    /// Records the label of the only closure parameter when every later parameter has a default.
    ///
    /// Swift binds a single trailing closure to the first parameter that accepts one, and lets
    /// the later defaulted parameters take their defaults (SE-0286). With two closure
    /// parameters, the trailing closure may bind to either, so the callee is skipped.
    private func recordClosureLabel(
        of clause: FunctionParameterClauseSyntax,
        calleeName: String
    ) {
        let parameters = Array(clause.parameters)
        let closureIndices = parameters.indices.filter { isClosureType(parameters[$0].type) }
        guard closureIndices.count == 1, let closureIndex = closureIndices.first else {
            return
        }
        let closureParameter = parameters[closureIndex]
        guard closureParameter.firstName.tokenKind != .wildcard,
            !hasResultBuilderAttribute(closureParameter.attributes),
            !hasResultBuilderAttribute(in: closureParameter.type),
            parameters[(closureIndex + 1)...].allSatisfy({ $0.defaultValue != nil })
        else {
            return
        }
        labelsByCalleeName[calleeName] = closureParameter.firstName.text
    }

    /// Returns the label of the memberwise initializer's closure parameter that a trailing
    /// closure fills.
    ///
    /// Swift synthesizes the memberwise initializer only when the struct body declares no
    /// initializer. Its parameters follow the stored instance properties in order, except a
    /// `let` with an initial value, which the initializer cannot set. As for a function, the
    /// struct qualifies only with one closure parameter, followed by omittable ones.
    private func findMemberwiseClosureLabel(of memberBlock: MemberBlockSyntax) -> String? {
        let declarations = memberBlock.members.map(\.decl)
        guard !declarations.contains(where: { $0.is(InitializerDeclSyntax.self) }) else {
            return nil
        }
        let storedVariables = declarations.compactMap { $0.as(VariableDeclSyntax.self) }
            .filter(isStoredInstanceProperty)
        guard !storedVariables.contains(where: { hasResultBuilderAttribute($0.attributes) }) else {
            return nil
        }
        let parameters = storedVariables.flatMap { variable in
            variable.bindings.filter { isMemberwiseParameter($0, of: variable) }
                .map { MemberwiseParameter(binding: $0, variable: variable) }
        }
        let closureIndices = parameters.indices.filter { parameters[$0].takesClosure }
        guard closureIndices.count == 1, let closureIndex = closureIndices.first,
            parameters[(closureIndex + 1)...].allSatisfy(\.isOmittable)
        else {
            return nil
        }
        return parameters[closureIndex].binding.pattern.as(IdentifierPatternSyntax.self)?
            .identifier.text
    }

    private func isMemberwiseParameter(
        _ binding: PatternBindingSyntax,
        of variable: VariableDeclSyntax
    ) -> Bool {
        let isInitializedLet =
            variable.bindingSpecifier.tokenKind == .keyword(.let) && binding.initializer != nil
        return isStored(binding) && !isInitializedLet
    }

    /// Returns whether `binding` stores a value: it has no accessors, or only observers.
    private func isStored(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessorBlock = binding.accessorBlock else {
            return true
        }
        guard case .accessors(let accessors) = accessorBlock.accessors else {
            return false
        }
        let observerKinds: [TokenKind] = [.keyword(.willSet), .keyword(.didSet)]
        return accessors.allSatisfy { observerKinds.contains($0.accessorSpecifier.tokenKind) }
    }

    private func isStoredInstanceProperty(_ variable: VariableDeclSyntax) -> Bool {
        let excludedModifiers: Set<String> = ["static", "class", "lazy"]
        return !variable.modifiers.contains { excludedModifiers.contains($0.name.text) }
    }
}

/// One parameter of a synthesized memberwise initializer.
private struct MemberwiseParameter {
    let binding: PatternBindingSyntax
    let variable: VariableDeclSyntax

    var takesClosure: Bool {
        binding.typeAnnotation.map { isClosureType($0.type) } ?? false
    }

    /// Whether a call may leave the parameter out: a `var` with an initial value, or an
    /// optional `var`, which defaults to `nil`.
    var isOmittable: Bool {
        guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
            return false
        }
        if binding.initializer != nil {
            return true
        }
        guard let type = binding.typeAnnotation?.type else {
            return false
        }
        return type.is(OptionalTypeSyntax.self)
            || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
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

/// Returns whether `attributes` holds a result builder, such as `@ViewBuilder`.
///
/// The style guide keeps trailing closures for builders. The check goes by the `Builder`
/// suffix that result builder types follow by convention, because it cannot resolve types.
private func hasResultBuilderAttribute(_ attributes: AttributeListSyntax) -> Bool {
    attributes.contains { element in
        element.as(AttributeSyntax.self)?.attributeName.trimmedDescription.hasSuffix("Builder")
            ?? false
    }
}

/// Returns whether the attributes on `type`, such as `@ViewBuilder () -> V`, hold a builder.
private func hasResultBuilderAttribute(in type: TypeSyntax) -> Bool {
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return hasResultBuilderAttribute(attributed.attributes)
            || hasResultBuilderAttribute(in: attributed.baseType)
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
