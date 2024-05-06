import SwiftSyntax
import Foundation

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

extension InheritanceClauseSyntax {
    static var sendable: Self {
        InheritanceClauseSyntax(
            inheritedTypes: InheritedTypeListSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: .identifier("Sendable"))
                )
            }
        )
    }
}

extension TokenSyntax {
    var withoutBackticks: Self {
        guard case TokenKind.identifier(let identifier) = tokenKind else { return self }
        var copy = self
        copy.tokenKind = .identifier(identifier.trimmingCharacters(in: CharacterSet(charactersIn: "`")))
        return copy
    }
}

extension TokenKind {
    var identifier: String? {
        switch self {
        case .identifier(let string): return string
        default: return nil
        }
    }
}

extension StructDeclSyntax {
    var sendable: Bool {
        inheritanceClause?.inheritedTypes
            .compactMap { $0.type.as(IdentifierTypeSyntax.self)?.name.tokenKind.identifier }
            .contains { $0 == "Sendable" }
        ?? false
    }
}

extension FunctionParameterSyntax {
    var isInOut: Bool {
        type.as(AttributedTypeSyntax.self)?.specifier?.text == "inout"
    }
    
    var isAutoClosure: Bool {
        type.as(AttributedTypeSyntax.self)?.attributes
            .compactMap { $0.as(AttributeSyntax.self) }
            .compactMap { $0.attributeName.as(IdentifierTypeSyntax.self) }
            .contains { $0.name.tokenKind == .identifier("autoclosure") }
        ?? false
    }
}

extension DeclModifierSyntax {
    static func `public`(leadingTrivia: Trivia? = nil, trailingTrivia: Trivia? = nil) -> Self {
        .init(leadingTrivia: leadingTrivia, name: .keyword(.public), trailingTrivia: trailingTrivia)
    }
}
