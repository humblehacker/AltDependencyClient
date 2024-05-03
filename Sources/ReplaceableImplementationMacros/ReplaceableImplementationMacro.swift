import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct ReplaceableImplementationMacro: MemberMacro {
    static let interfaceName = "Interface"
    static let implStructName = TokenSyntax.identifier("Impl")
    static let implMemberName = TokenSyntax.identifier("impl")

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.emitDiagnostic(
                node: declaration,
                message: "'@ReplaceableImplementation' can only be applied to structs"
            )
            return []
        }

        guard let interfaceProtocolDecl = structDecl.memberBlock.members.first?.decl.as(ProtocolDeclSyntax.self),
              interfaceProtocolDecl.name.text == interfaceName
        else {
            context.emitDiagnostic(node: structDecl, message: "'@ReplaceableImplementation' requires a nested protocol named '\(interfaceName)'")

            return []
        }

        let interfaceFunctionDecls = interfaceFunctionDecls(from: interfaceProtocolDecl)

        let result = [DeclSyntax("let \(raw: Self.implMemberName): \(raw: Self.implStructName)")]
                   + [DeclSyntax(initDecl(from: interfaceFunctionDecls))]
                   + wrapperFunctionDecls(from: interfaceFunctionDecls).map(DeclSyntax.init)
                   + [DeclSyntax(implStructDecl(from: interfaceFunctionDecls))]

        return result
    }

    static func interfaceFunctionDecls(from interfaceProtocolDecl: ProtocolDeclSyntax) -> [FunctionDeclSyntax] {
        interfaceProtocolDecl
            .memberBlock
            .members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
    }

    // MARK: - initializer generation

    static func initDecl(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> InitializerDeclSyntax {
        let lastIndex = interfaceFunctionDecls.count - 1
        return InitializerDeclSyntax(
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax(
                        interfaceFunctionDecls.enumerated()
                            .map { (index, functionDecl) in
                                FunctionParameterSyntax(
                                    leadingTrivia: .newline,
                                    firstName: .identifier(functionDecl.name.text),
                                    type: TypeSyntax(
                                        AttributedTypeSyntax(
                                            attributes: AttributeListSyntax(
                                                [
                                                    .attribute(
                                                        AttributeSyntax(
                                                            attributeName: IdentifierTypeSyntax(name: .keyword(.escaping)),
                                                            trailingTrivia: .space
                                                        )
                                                    )
                                                ]
                                            ),
                                            baseType: closureFunctionType(from: functionDecl)
                                        )
                                    ),
                                    trailingComma: index < lastIndex ? .commaToken() : nil
                                )
                            }
                    ),
                    rightParen: .rightParenToken(leadingTrivia: .newline)
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax( [
                    CodeBlockItemSyntax(
                        item: .expr(
                            ExprSyntax(
                                InfixOperatorExprSyntax(
                                    leftOperand: DeclReferenceExprSyntax(baseName: Self.implMemberName),
                                    operator: AssignmentExprSyntax(),
                                    rightOperand: FunctionCallExprSyntax(
                                        calledExpression: DeclReferenceExprSyntax(baseName: Self.implStructName),
                                        leftParen: .leftParenToken(),
                                        rightParen: .rightParenToken(leadingTrivia: .newline),
                                        argumentsBuilder: {
                                            LabeledExprListSyntax(
                                                interfaceFunctionDecls
                                                    .map { functionDecl in
                                                        let functionName = functionDecl.name.text
                                                        return LabeledExprSyntax(
                                                            leadingTrivia: .newline,
                                                            label: .identifier(functionName),
                                                            colon: .colonToken(),
                                                            expression: DeclReferenceExprSyntax(baseName: .identifier(functionName))
                                                        )
                                                    }
                                            )
                                        }
                                    )
                                )
                            )
                        )
                    )
                ] )
            )
        )
    }

    // MARK: - `struct Impl` generation

    static func implStructDecl(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> StructDeclSyntax {
        StructDeclSyntax(
            name: Self.implStructName,
            memberBlock: MemberBlockSyntax(
                members: implStructMembers(from: interfaceFunctionDecls)
            )
        )
    }

    static func implStructMembers(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> MemberBlockItemListSyntax {
        MemberBlockItemListSyntax(
            implStructVariableDecls(from: interfaceFunctionDecls)
                .map { MemberBlockItemSyntax(decl: $0) }
        )
    }

    // Generates block of closure vars corresponding to functions defined in `protocol Interface`
    // This forms the body of `struct Impl`.
    static func implStructVariableDecls(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> [VariableDeclSyntax] {
        interfaceFunctionDecls
            .map { functionDecl in
                VariableDeclSyntax.init(
                    attributes: functionDecl.attributes,
                    modifiers: functionDecl.modifiers,
                    .var,
                    name: PatternSyntax(stringLiteral: functionDecl.name.text),
                    type: TypeAnnotationSyntax(type: closureFunctionType(from: functionDecl)),
                    initializer: nil
                )
            }
    }

    static func closureFunctionType(from functionDecl: FunctionDeclSyntax) -> FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: closureParameters(from: functionDecl.signature.parameterClause.parameters),
            effectSpecifiers: typeEffectSpecifiers(from: functionDecl.signature.effectSpecifiers),
            returnClause: functionDecl.signature.returnClause ?? .void
        )
    }

    static func typeEffectSpecifiers(from functionEffectSpecifiers: FunctionEffectSpecifiersSyntax?) -> TypeEffectSpecifiersSyntax? {
        guard let functionEffectSpecifiers else { return nil }
        return TypeEffectSpecifiersSyntax(
            asyncSpecifier: functionEffectSpecifiers.asyncSpecifier,
            throwsSpecifier: functionEffectSpecifiers.throwsSpecifier
        )
    }

    static func closureParameters(from functionParameterList: FunctionParameterListSyntax) -> TupleTypeElementListSyntax {
        TupleTypeElementListSyntax(functionParameterList.map(tupleTypeElement(from:)))
    }

    static func tupleTypeElement(from functionParameter: FunctionParameterSyntax) -> TupleTypeElementSyntax {
        TupleTypeElementSyntax(
            firstName: .wildcardToken(),
            secondName: functionParameter.secondName ?? functionParameter.firstName,
            colon: .colonToken(),
            type: functionParameter.type
        )
    }

    // MARK: - Wrapper function generation

    static func wrapperFunctionDecls(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> [FunctionDeclSyntax] {
        interfaceFunctionDecls
            .map(wrapperFunctionDecl(from:))
    }

    static func wrapperFunctionDecl(from functionDecl: FunctionDeclSyntax) -> FunctionDeclSyntax {
        var newDecl = functionDecl
        newDecl.body = newFunctionBody(from: functionDecl)
        return newDecl
    }

    static func newFunctionBody(from functionDecl: FunctionDeclSyntax) -> CodeBlockSyntax {
        let functionCallExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: Self.implMemberName),
                declName: DeclReferenceExprSyntax(baseName: functionDecl.name)
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(
                functionDecl.signature.parameterClause.parameters.map {
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(
                            baseName: .identifier(($0.secondName ?? $0.firstName).text)
                        )
                    )
                }
            ),
            rightParen: .rightParenToken()
        )

        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(
                    item: .expr(
                        ExprSyntax(
                            maybeTry(
                                expression: maybeAwait(
                                    expression: functionCallExpr,
                                    from: functionDecl
                                ),
                                from: functionDecl
                            )
                        )
                    )
                )]
            )
        )
    }

    static func maybeAwait(expression: some ExprSyntaxProtocol, from functionDecl: FunctionDeclSyntax) -> any ExprSyntaxProtocol {
        guard functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil else { return expression }
        return AwaitExprSyntax(expression: expression)
    }

    static func maybeTry(expression: some ExprSyntaxProtocol, from functionDecl: FunctionDeclSyntax) -> any ExprSyntaxProtocol {
        guard functionDecl.signature.effectSpecifiers?.throwsSpecifier != nil else { return expression }
        return TryExprSyntax(expression: expression)
    }

}

// MARK: - Extensions

extension TypeSyntaxProtocol where Self == TypeSyntax {
    static var void: TypeSyntax { TypeSyntax(stringLiteral: "Void") }
}

extension ReturnClauseSyntax {
    static var void: Self { ReturnClauseSyntax(type: .void) }
}

extension MacroExpansionContext {
    func emitDiagnostic(
        node: some SyntaxProtocol,
        message: @autoclosure () -> String
    ) {
        diagnose(
            Diagnostic(
                node: node,
                message: MacroExpansionErrorMessage(message())
            )
        )
    }
}

@main
struct ReplaceableImplementationPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ReplaceableImplementationMacro.self
    ]
}
