import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct AltDependencyClientMacro: MemberMacro {
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
                message: "'@AltDependencyClient' can only be applied to structs"
            )
            return []
        }

        guard let interfaceProtocolDecl = structDecl.memberBlock.members.first?.decl.as(ProtocolDeclSyntax.self),
              interfaceProtocolDecl.name.text == interfaceName
        else {
            context.emitDiagnostic(
                node: structDecl,
                message: "'@AltDependencyClient' requires a nested protocol named '\(interfaceName)'"
            )
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
        return InitializerDeclSyntax(
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax {
                        let lastIndex = interfaceFunctionDecls.count - 1
                        for (index, functionDecl) in interfaceFunctionDecls.enumerated() {
                            FunctionParameterSyntax(
                                leadingTrivia: .newline,
                                firstName: .identifier(functionDecl.name.text),
                                type: TypeSyntax(
                                    AttributedTypeSyntax(
                                        attributes: AttributeListSyntax {
                                            .attribute(.atEscaping(trailingTrivia: .space))
                                        },
                                        baseType: closureFunctionType(from: functionDecl)
                                    )
                                ),
                                trailingComma: index < lastIndex ? .commaToken() : nil
                            )
                        }
                    },
                    rightParen: .rightParenToken(leadingTrivia: .newline)
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax {
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
                                            LabeledExprListSyntax {
                                                for functionDecl in interfaceFunctionDecls {
                                                    LabeledExprSyntax(
                                                        leadingTrivia: .newline,
                                                        label: functionDecl.name,
                                                        colon: .colonToken(),
                                                        expression: DeclReferenceExprSyntax(baseName: functionDecl.name)
                                                    )
                                                }
                                            }
                                        }
                                    )
                                )
                            )
                        )
                    )
                }
            )
        )
    }

    // MARK: - `struct Impl` generation

    static func implStructDecl(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> StructDeclSyntax {
        StructDeclSyntax(name: Self.implStructName) {
            for functionDecl in interfaceFunctionDecls {
                VariableDeclSyntax(
                    attributes: functionDecl.attributes,
                    modifiers: functionDecl.modifiers,
                    bindingSpecifier: .keyword(.var)
                ) {
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: functionDecl.name),
                        typeAnnotation: TypeAnnotationSyntax(type: closureFunctionType(from: functionDecl))
                    )
                }
            }
        }
    }

    static func closureFunctionType(from functionDecl: FunctionDeclSyntax) -> FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: TupleTypeElementListSyntax {
                for functionParameter in functionDecl.signature.parameterClause.parameters {
                    TupleTypeElementSyntax(
                        firstName: .wildcardToken(),
                        secondName: functionParameter.secondName ?? functionParameter.firstName,
                        colon: .colonToken(),
                        type: functionParameter.type
                    )
                }
            },
            effectSpecifiers: typeEffectSpecifiers(from: functionDecl.signature.effectSpecifiers),
            returnClause: functionDecl.signature.returnClause ?? .void
        )
    }

    static func typeEffectSpecifiers(from functionEffectSpecifiers: FunctionEffectSpecifiersSyntax?) -> TypeEffectSpecifiersSyntax? {
        TypeEffectSpecifiersSyntax(
            asyncSpecifier: functionEffectSpecifiers?.asyncSpecifier,
            throwsSpecifier: functionEffectSpecifiers?.throwsSpecifier
        )
    }

    // MARK: - Wrapper function generation

    static func wrapperFunctionDecls(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> [FunctionDeclSyntax] {
        interfaceFunctionDecls
            .map(wrapperFunctionDecl(from:))
    }

    static func wrapperFunctionDecl(from functionDecl: FunctionDeclSyntax) -> FunctionDeclSyntax {
        var newDecl = functionDecl
        newDecl.attributes = AttributeListSyntax {
            AttributeSyntax.atInlinable(trailingTrivia: .newline)
            AttributeSyntax.atInline(option: .always)
        }
        // After adding attributes above, the inherited func keyword retains its leading indent,
        // resulting in bad formatting. So we replace it with one without the indent.
        newDecl.funcKeyword = .keyword(.func, leadingTrivia: .newline)
        newDecl.body = newFunctionBody(from: functionDecl)
        return newDecl
    }

    static func newFunctionBody(from functionDecl: FunctionDeclSyntax) -> CodeBlockSyntax {
        CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(
                    item: .expr(
                        ExprSyntax(
                            maybeTry(
                                expression: maybeAwait(
                                    expression: functionCallExpr(from: functionDecl),
                                    from: functionDecl
                                ),
                                from: functionDecl
                            )
                        )
                    )
                )
            }
        )
    }

    static func functionCallExpr(from functionDecl: FunctionDeclSyntax) -> FunctionCallExprSyntax {
        FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: Self.implMemberName),
                declName: DeclReferenceExprSyntax(baseName: functionDecl.name)
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                for parameter in functionDecl.signature.parameterClause.parameters {
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(
                            baseName: parameter.secondName ?? parameter.firstName
                        )
                    )
                }
            },
            rightParen: .rightParenToken()
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

extension AttributeSyntax {
    static func atEscaping(leadingTrivia: Trivia? = nil, trailingTrivia: Trivia? = nil) -> Self {
        .init(
            leadingTrivia: leadingTrivia,
            attributeName: IdentifierTypeSyntax(name: .keyword(.escaping)),
            trailingTrivia: trailingTrivia
        )
    }

    enum InlineOption: String {
        case always = "__always"
        case never  = "never"
    }

    static func atInline(leadingTrivia: Trivia? = nil, option: InlineOption, trailingTrivia: Trivia? = nil) -> Self {
        .init(
            leadingTrivia: leadingTrivia,
            attributeName: IdentifierTypeSyntax(name: .identifier("inline")),
            leftParen: .leftParenToken(),
            arguments: .token(.identifier(option.rawValue)),
            rightParen: .rightParenToken(),
            trailingTrivia: trailingTrivia
        )
    }

    static func atInlinable(leadingTrivia: Trivia? = nil, trailingTrivia: Trivia? = nil) -> Self {
        .init(
            leadingTrivia: leadingTrivia,
            attributeName: IdentifierTypeSyntax(name: .identifier("inlinable")),
            trailingTrivia: trailingTrivia
        )
    }
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
struct AltDependencyClientPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AltDependencyClientMacro.self
    ]
}
