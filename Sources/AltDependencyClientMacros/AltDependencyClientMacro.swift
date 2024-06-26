import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

let interfaceName = "Interface"
let implStructName = TokenSyntax.identifier("Impl")
let implMemberName = TokenSyntax.identifier("impl")

public struct AltDependencyClientMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        do {
            guard let structDecl = declaration.as(StructDeclSyntax.self) else {
                throw DiagnosticsError.incorrectApplication(declaration: declaration)
            }

            guard let interfaceProtocolDecl = interfaceProtocolDecl(from: structDecl) else {
                throw DiagnosticsError.missingInterfaceProtocol(structDecl)
            }

            let interfaceFunctionDecls = interfaceFunctionDecls(from: interfaceProtocolDecl)
            let sendable = structDecl.sendable

            return ["public var \(raw: implMemberName): \(raw: implStructName)"]
                + [initDecl(from: interfaceFunctionDecls, sendable: sendable).cast(DeclSyntax.self)]
                + wrapperFunctionDecls(from: interfaceFunctionDecls).map(DeclSyntax.init)
                + [implStructDecl(from: interfaceFunctionDecls, sendable: sendable).cast(DeclSyntax.self)]

        } catch let error as DiagnosticsError {
            for diagnostic in error.diagnostics {
                context.diagnose(diagnostic)
            }
            return []
        }
    }

    static func interfaceProtocolDecl(from structDecl: StructDeclSyntax) -> ProtocolDeclSyntax? {
        structDecl.memberBlock.members
            .compactMap { memberBlockItem in memberBlockItem.decl.as(ProtocolDeclSyntax.self) }
            .first(where: { $0.name.text == interfaceName })
    }

    static func interfaceFunctionDecls(from interfaceProtocolDecl: ProtocolDeclSyntax) -> [FunctionDeclSyntax] {
        interfaceProtocolDecl
            .memberBlock
            .members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
    }

    // MARK: - initializer generation

    static func initDecl(
        from interfaceFunctionDecls: [FunctionDeclSyntax],
        sendable: Bool
    ) -> InitializerDeclSyntax {
        return InitializerDeclSyntax(
            modifiers: DeclModifierListSyntax { .public() },
            signature: initializerSignature(from: interfaceFunctionDecls, sendable: sendable),
            body: initializerBody(from: interfaceFunctionDecls)
        )
    }

    static func initializerSignature(
        from interfaceFunctionDecls: [FunctionDeclSyntax],
        sendable: Bool
    ) -> FunctionSignatureSyntax {
        FunctionSignatureSyntax(
            parameterClause: FunctionParameterClauseSyntax(
                parameters: FunctionParameterListSyntax {
                    for functionDecl in interfaceFunctionDecls {
                        FunctionParameterSyntax(
                            leadingTrivia: .newline,
                            firstName: .identifier(functionDecl.name.text),
                            type: TypeSyntax(
                                AttributedTypeSyntax(
                                    attributes: AttributeListSyntax {
                                        if sendable {
                                            AttributeSyntax.atSendable(trailingTrivia: .space)
                                        }
                                        AttributeSyntax.atEscaping(trailingTrivia: .space)
                                    },
                                    baseType: closureFunctionType(from: functionDecl)
                                )
                            )
                        )
                    }
                },
                rightParen: .rightParenToken(leadingTrivia: .newline)
            )
        )
    }
    
    static func initializerBody(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> CodeBlockSyntax {
        CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                ExprSyntax(
                    InfixOperatorExprSyntax(
                        leftOperand: DeclReferenceExprSyntax(baseName: implMemberName),
                        operator: AssignmentExprSyntax(),
                        rightOperand: FunctionCallExprSyntax(
                            calledExpression: DeclReferenceExprSyntax(baseName: implStructName),
                            leftParen: .leftParenToken(),
                            rightParen: .rightParenToken(leadingTrivia: .newline),
                            argumentsBuilder: {
                                LabeledExprListSyntax {
                                    for functionDecl in interfaceFunctionDecls {
                                        LabeledExprSyntax(
                                            leadingTrivia: .newline,
                                            label: functionDecl.name.withoutBackticks,
                                            colon: .colonToken(),
                                            expression: DeclReferenceExprSyntax(baseName: functionDecl.name)
                                        )
                                    }
                                }
                            }
                        )
                    )
                )
            }
        )
    }

    // MARK: - `struct Impl` generation

    static func implStructDecl(
        from interfaceFunctionDecls: [FunctionDeclSyntax],
        sendable: Bool
    ) -> StructDeclSyntax {
        StructDeclSyntax(
            modifiers: DeclModifierListSyntax { .public() },
            name: implStructName,
            inheritanceClause: sendable ? .sendable : nil
        ) {
            for functionDecl in interfaceFunctionDecls {
                VariableDeclSyntax(
                    attributes: functionDecl.attributes,
                    modifiers: {
                        var modifiers = functionDecl.modifiers
                        modifiers.append(.public())
                        return modifiers
                    }(),
                    bindingSpecifier: .keyword(.var)
                ) {
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: functionDecl.name),
                        typeAnnotation: TypeAnnotationSyntax(
                            type: AttributedTypeSyntax(
                                attributes: AttributeListSyntax {
                                    if sendable {
                                        AttributeSyntax.atSendable(trailingTrivia: .space)
                                    }
                                },
                                baseType: closureFunctionType(from: functionDecl)
                            )
                        )
                    )
                }
            }
        }
    }

    static func closureFunctionType(from functionDecl: FunctionDeclSyntax) -> FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: TupleTypeElementListSyntax {
                for (index, functionParameter) in functionDecl.signature.parameterClause.parameters.enumerated() {
                    TupleTypeElementSyntax(
                        firstName: .wildcardToken(),
                        secondName: closureParameterName(parameter: functionParameter, index: index),
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

        var newDecl = functionDecl.with(\.signature.parameterClause.parameters, FunctionParameterListSyntax {
            for (index, parameter) in functionDecl.signature.parameterClause.parameters.enumerated() {
                if parameter.firstName.tokenKind == .wildcard && parameter.secondName == nil {
                    parameter.with(\.secondName, "p\(raw: index)")
                } else {
                    parameter
                }
            }
        })

        newDecl.modifiers = DeclModifierListSyntax { .public(leadingTrivia: .newline) }
        newDecl.attributes = AttributeListSyntax {
            AttributeSyntax.atInlinable(trailingTrivia: .newline)
            AttributeSyntax.atInline(option: .always)
        }
        // After adding attributes above, the inherited func keyword retains its leading indent,
        // resulting in bad formatting. So we replace it with one without the indent.
        newDecl.funcKeyword = .keyword(.func, leadingTrivia: .newline)
        newDecl.body = wrapperFunctionBody(from: functionDecl)
        return newDecl
    }

    static func wrapperFunctionBody(from functionDecl: FunctionDeclSyntax) -> CodeBlockSyntax {
        CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                ExprSyntax(
                    maybeTry(
                        expression: maybeAwait(
                            expression: functionCallExpr(from: functionDecl),
                            from: functionDecl
                        ),
                        from: functionDecl
                    )
                )
            }
        )
    }

    static func functionCallExpr(from functionDecl: FunctionDeclSyntax) -> FunctionCallExprSyntax {
        FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: implMemberName),
                declName: DeclReferenceExprSyntax(baseName: functionDecl.name)
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                for (index, parameter) in functionDecl.signature.parameterClause.parameters.enumerated() {
                    let baseExpr = DeclReferenceExprSyntax(
                        baseName: closureParameterName(parameter: parameter, index: index)
                    )

                    if parameter.isInOut {
                        LabeledExprSyntax(
                            expression: InOutExprSyntax(expression: baseExpr)
                        )
                    } else if parameter.isAutoClosure {
                        LabeledExprSyntax(
                            expression: FunctionCallExprSyntax(
                                calledExpression: baseExpr,
                                leftParen: .leftParenToken(),
                                arguments: [],
                                rightParen: .rightParenToken()
                            )
                        )
                    } else {
                        LabeledExprSyntax(expression: baseExpr)
                    }
                }
            },
            rightParen: .rightParenToken()
        )
    }

    static func closureParameterName(
        parameter: FunctionParameterSyntax,
        index: Int
    ) -> TokenSyntax {
        let result = parameter.secondName ?? parameter.firstName
        guard result.tokenKind != .wildcard else { return "p\(raw: index)" }
        return result
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

// MARK: - Errors & Diagnostics

extension DiagnosticsError {
    static func missingInterfaceProtocol(_ structDecl: StructDeclSyntax) -> DiagnosticsError {
        DiagnosticsError(diagnostics: [
            Diagnostic(
                node: structDecl,
                message: "'@AltDependencyClient' requires a nested protocol named '\(interfaceName)'",
                fixIt: FixIt(
                    message: "Insert 'protocol Interface'",
                    changes: [
                        .replace(
                            oldNode: Syntax(structDecl),
                            newNode: Syntax({
                                var newStructDecl = structDecl
                                newStructDecl.memberBlock = {
                                    var newMembers = structDecl.memberBlock.members
                                    newMembers.append(MemberBlockItemSyntax(decl: DeclSyntax("\nprotocol Interface { }\n")))
                                    var newMemberBlock = structDecl.memberBlock
                                    newMemberBlock.members = newMembers
                                    return newMemberBlock
                                }()
                                return newStructDecl
                            }())
                        )
                    ]
                )
            )
        ])
    }

    static func incorrectApplication(declaration: some DeclGroupSyntax) -> DiagnosticsError {
        DiagnosticsError(diagnostics: [
            Diagnostic(
                node: declaration,
                message: "'@AltDependencyClient' can only be applied to structs"
            )
        ])
    }
}

// MARK: - Plugin main

@main
struct AltDependencyClientPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AltDependencyClientMacro.self
    ]
}
