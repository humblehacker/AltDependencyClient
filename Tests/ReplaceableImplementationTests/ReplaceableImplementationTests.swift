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
            protocol FooDependency {
              func foo(integer: Int) -> String
            }
            """,
            expandedSource: """
            protocol FooDependency {
              func foo(integer: Int) -> String
            }

            struct Foo {
              let impl: Impl

              func foo(integer: Int) -> String {
                return impl.foo(integer)
              }

              struct Impl {
                var foo: (_ integer: Int) -> String
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
            protocol FooDependency {
              func foo(integer: Int) -> String
            }
            """
        } expansion: {
            """
            protocol FooDependency {
              func foo(integer: Int) -> String
            }

            struct Foo {
              let impl: Impl

              func foo(integer: Int) -> String {
                return impl.foo(integer)
              }

              struct Impl {
                var foo: (_ integer: Int) -> String
              }
            }
            """
        }
    }

    func testIncorrectApplicationEmitsDiagnostics() throws {
        assertMacro {
            """
            @ReplaceableImplementation
            struct Foo {}
            """
        } diagnostics: {
            """
            @ReplaceableImplementation
            ╰─ 🛑 '@ReplaceableImplementation' can only be applied to protocols
            struct Foo {}
            """
        } 
    }

    func testIncorrectProtocolSuffixEmitsDiagnostics() throws {
        assertMacro {
            """
            @ReplaceableImplementation
            protocol Foo {}
            """
        } diagnostics: {
            """
            @ReplaceableImplementation
            protocol Foo {}
                     ┬──
                     ╰─ 🛑 '@ReplaceableImplementation' requires protocol name with 'Dependency' suffix
            """
        }
    }
}
#endif
