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

extension TokenSyntax {
    var withoutBackticks: Self {
        guard case TokenKind.identifier(let identifier) = tokenKind else { return self }
        var copy = self
        copy.tokenKind = .identifier(identifier.trimmingCharacters(in: CharacterSet(charactersIn: "`")))
        return copy
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
