import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct ReplaceableImplementationMacro: MemberMacro {
    static let interfaceName = "Interface"

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

        let interfaceFunctionDecls = interfaceProtocolDecl
            .memberBlock
            .members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }

        let implStructMemberDecls = interfaceFunctionDecls
            .map { functionDecl in
                let functionName = functionDecl.name.text
                let resultType = functionDecl.signature.returnClause?.type.description ?? "Void"
                let parameterList = functionDecl.signature.parameterClause.parameters
                    .map { parameter in
                        (
                            name: (parameter.secondName ?? parameter.firstName).text,
                            type: parameter.type.description
                        )
                    }
                    .map { paramTuple in
                        "_ \(paramTuple.name): \(paramTuple.type)"
                    }
                    .joined(separator: ", ")

                let declString = """
                      var \(functionName): (\(parameterList)) -> \(resultType)
                    """

                let variableDecl = DeclSyntax(stringLiteral: declString).as(VariableDeclSyntax.self)!

                let result = MemberBlockItemSyntax(decl: variableDecl)

                return result
            }

        let implStructDecl = StructDeclSyntax(
            name: TokenSyntax(stringLiteral: "Impl"),
            memberBlock: MemberBlockSyntax(
                members: MemberBlockItemListSyntax(implStructMemberDecls)
            )
        )

        let result = [
            [DeclSyntax("let impl: Impl")],
            wrapperFunctionDecls(from: interfaceFunctionDecls),
            [DeclSyntax(implStructDecl)]
        ].reduce([], +)

        return result
    }

    static func wrapperFunctionDecls(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> [DeclSyntax] {
        interfaceFunctionDecls
            .map(wrapperFunctionDecl(from:))
            .map(DeclSyntax.init)
    }

    static func wrapperFunctionDecl(from functionDecl: FunctionDeclSyntax) -> FunctionDeclSyntax {
        var newDecl = functionDecl
        newDecl.body = newFunctionBody(from: functionDecl)
        return newDecl
    }

    static func newFunctionBody(from functionDecl: FunctionDeclSyntax) -> CodeBlockSyntax {
        let functionName = functionDecl.name.text
        let parameterNames = functionDecl.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text }
        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax(
                stringLiteral: """
                return impl.\(functionName)(\(parameterNames.joined(separator: ", ")))
                """
            )
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
struct ReplaceableImplementationPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ReplaceableImplementationMacro.self
    ]
}
