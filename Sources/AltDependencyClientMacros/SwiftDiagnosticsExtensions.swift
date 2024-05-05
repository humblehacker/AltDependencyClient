import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacroExpansion

extension Diagnostic {
    public init(
        node: some SyntaxProtocol,
        position: AbsolutePosition? = nil,
        message: @autoclosure () -> String,
        highlights: [Syntax]? = nil,
        notes: [Note] = [],
        fixIts: [FixIt] = []
    ) {
        self = Diagnostic(
            node: node,
            position: position,
            message: MacroExpansionErrorMessage(message()),
            highlights: highlights,
            notes: notes,
            fixIts: fixIts
        )
    }

    public init(
        node: some SyntaxProtocol,
        position: AbsolutePosition? = nil,
        message: @autoclosure () -> String,
        highlights: [Syntax]? = nil,
        notes: [Note] = [],
        fixIt: FixIt
    ) {
        self = Diagnostic(
            node: node,
            position: position,
            message: MacroExpansionErrorMessage(message()),
            highlights: highlights,
            notes: notes,
            fixIt: fixIt
        )
    }
}

extension FixIt {
    public init(message: @autoclosure () -> String, changes: [Change]) {
        self = Self(message: MacroExpansionFixItMessage(message()), changes: changes)
    }
}
