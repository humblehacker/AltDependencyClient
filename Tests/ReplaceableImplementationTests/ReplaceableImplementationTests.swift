import MacroTesting
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(ReplaceableImplementationMacros)
import ReplaceableImplementationMacros

final class ReplaceableImplementationTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
//            isRecording: true,
            macros: [ReplaceableImplementationMacro.self]
        ) {
            super.invokeTest()
        }
    }

    static let mainMacroInput =
        """
        @ReplaceableImplementation
        struct Foo {
          protocol Interface {
            func foo(integer: Int) -> String
            func bar(from string: String) -> Int
            func baz() async throws
          }
        }
        """

    func testReplaceableImplementationMacro() throws {
        assertMacroExpansion(Self.mainMacroInput,
            expandedSource: """
            struct Foo {
              protocol Interface {
                func foo(integer: Int) -> String
                func bar(from string: String) -> Int
                func baz() async throws
              }

              let impl: Impl

              init(
                foo: @escaping (_ integer: Int) -> String,
                bar: @escaping (_ string: String) -> Int,
                baz: @escaping () async throws -> Void
              ) {
                impl = Impl(
                  foo: foo,
                  bar: bar,
                  baz: baz
                )
              }

              func foo(integer: Int) -> String {
                impl.foo(integer)
              }

              func bar(from string: String) -> Int {
                impl.bar(string)
              }

              func baz() async throws {
                impl.baz()
              }

              struct Impl {
                var foo: (_ integer: Int) -> String
                var bar: (_ string: String) -> Int
                var baz: () async throws -> Void
              }
            }
            """,
            macros: ["ReplaceableImplementation": ReplaceableImplementationMacro.self],
            indentationWidth: .spaces(2)
        )
    }

    func testReplaceableImplementationMacro2() throws {
        assertMacro {
            Self.mainMacroInput
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func foo(integer: Int) -> String
                func bar(from string: String) -> Int
                func baz() async throws
              }

              let impl: Impl

              init(
                foo: @escaping (_ integer: Int) -> String,
                bar: @escaping (_ string: String) -> Int,
                baz: @escaping () async throws -> Void
              ) {
                impl = Impl(
                  foo: foo,
                  bar: bar,
                  baz: baz
                )
              }

              func foo(integer: Int) -> String {
                impl.foo(integer)
              }

              func bar(from string: String) -> Int {
                impl.bar(string)
              }

              func baz() async throws {
                impl.baz()
              }

              struct Impl {
                var foo: (_ integer: Int) -> String
                var bar: (_ string: String) -> Int
                var baz: () async throws -> Void
              }
            }
            """
        }
    }

    func testIncorrectApplicationEmitsDiagnostics() throws {
        assertMacro {
            """
            @ReplaceableImplementation
            class Foo {}
            """
        } diagnostics: {
            """
            @ReplaceableImplementation
            ╰─ 🛑 '@ReplaceableImplementation' can only be applied to structs
            class Foo {}
            """
        }
    }

    func testMissingImplProtocolEmitsDiagnostics() throws {
        assertMacro {
            """
            @ReplaceableImplementation
            struct Foo {}
            """
        } diagnostics: {
            """
            @ReplaceableImplementation
            ╰─ 🛑 '@ReplaceableImplementation' requires a nested protocol named 'Interface'
            struct Foo {}
            """
        }
    }
}
#endif
