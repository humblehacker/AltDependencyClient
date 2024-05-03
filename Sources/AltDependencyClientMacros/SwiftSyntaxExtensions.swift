import SwiftSyntax

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


