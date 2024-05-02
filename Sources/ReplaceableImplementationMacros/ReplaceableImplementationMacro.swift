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

        let interfaceFunctionDecls = interfaceFunctionDecls(from: interfaceProtocolDecl)

        let result = [DeclSyntax("let impl: Impl")]
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

    // Generates `struct Impl`
    static func implStructDecl(from interfaceFunctionDecls: [FunctionDeclSyntax]) -> StructDeclSyntax {
        StructDeclSyntax(
            name: TokenSyntax(stringLiteral: "Impl"),
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
                    type: closureVariableType(from: functionDecl),
                    initializer: nil
                )
            }
    }

    static func closureVariableType(from functionDecl: FunctionDeclSyntax) -> TypeAnnotationSyntax {
        TypeAnnotationSyntax(
            type: FunctionTypeSyntax(
                parameters: closureParameters(from: functionDecl.signature.parameterClause.parameters),
                returnClause: functionDecl.signature.returnClause ?? .void
            )
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
