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

    func testReplaceableImplementationMacro() throws {
        assertMacroExpansion(
            """
            @ReplaceableImplementation
            struct Foo {
              protocol Interface {
                func foo(integer: Int) -> String
                func bar(from string: String) -> Int
                func baz()
              }
            }
            """,
            expandedSource: """
            struct Foo {
              protocol Interface {
                func foo(integer: Int) -> String
                func bar(from string: String) -> Int
                func baz()
              }

                let impl: Impl

                func foo(integer: Int) -> String {
                    return impl.foo(integer)
                }

                func bar(from string: String) -> Int {
                    return impl.bar(string)
                }

                func baz() {
                    return impl.baz()
                }

                struct Impl {
                    var foo: (_ integer: Int) -> String
                    var bar: (_ string: String) -> Int
                    var baz: () -> Void
                }
            }
            """,
            macros: ["ReplaceableImplementation": ReplaceableImplementationMacro.self]
        )
    }

    func testReplaceableImplementationMacro2() throws {
        assertMacro {
            """
            @ReplaceableImplementation
            struct Foo {
              protocol Interface {
                func foo(integer: Int) -> String
                func bar(from string: String) -> Int
                func baz()
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func foo(integer: Int) -> String
                func bar(from string: String) -> Int
                func baz()
              }

              let impl: Impl

              func foo(integer: Int) -> String {
                return impl.foo(integer)
              }

              func bar(from string: String) -> Int {
                return impl.bar(string)
              }

              func baz() {
                return impl.baz()
              }

              struct Impl {
                var foo: (_ integer: Int) -> String
                var bar: (_ string: String) -> Int
                var baz: () -> Void
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
