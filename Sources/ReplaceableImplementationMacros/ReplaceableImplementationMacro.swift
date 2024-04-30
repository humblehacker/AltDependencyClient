import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

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

public struct ReplaceableImplementationMacro: PeerMacro {
    static let protocolSuffix = "Dependency"

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protoDecl = declaration.as(ProtocolDeclSyntax.self) else {
            context.emitDiagnostic(
                node: declaration,
                message: "'@ReplaceableImplementation' can only be applied to protocols"
            )
//            context.diagnose(
//                Diagnostic(
//                    node: declaration,
//                    message: MacroExpansionErrorMessage(
//                        "'@ReplaceableImplementation' can only be applied to protocols"
//                    )
//                )
//            )

            return []
        }

        guard protoDecl.name.text.hasSuffix("Dependency") else {
            context.diagnose(
                Diagnostic(
                    node: protoDecl.name,
                    message: MacroExpansionErrorMessage(
                        "'@ReplaceableImplementation' requires protocol name with '\(protocolSuffix)' suffix"
                    )
                )
            )

            return []
        }


        let structName = String(protoDecl.name.text.dropLast(protocolSuffix.count))

        let structDecl = StructDeclSyntax(
            name: TokenSyntax(stringLiteral: structName),
            memberBlock: MemberBlockSyntax(
               """
               {
                 let impl: Impl

                 func foo(integer: Int) -> String {
                   return impl.foo(integer)
                 }

                 struct Impl {
                   var foo: (_ integer: Int) -> String
                 }
               }
               """
            )
        )
        return [DeclSyntax(structDecl)]
    }
}

@main
struct ReplaceableImplementationPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ReplaceableImplementationMacro.self
    ]
}
