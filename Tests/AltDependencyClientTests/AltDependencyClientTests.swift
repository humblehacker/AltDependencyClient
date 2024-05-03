import MacroTesting
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(AltDependencyClientMacros)
import AltDependencyClientMacros

final class AltDependencyClient: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
//            isRecording: true,
            macros: [AltDependencyClientMacro.self]
        ) {
            super.invokeTest()
        }
    }

    func testAltDependencyClientMacro() throws {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func foo(integer: Int) -> String
                func bar(from string: String) -> Int
                func baz() async throws
              }
            }
            """
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

              @inlinable
              @inline(__always)
              func foo(integer: Int) -> String {
                impl.foo(integer)
              }

              @inlinable
              @inline(__always)
              func bar(from string: String) -> Int {
                impl.bar(string)
              }

              @inlinable
              @inline(__always)
              func baz() async throws {
                try await impl.baz()
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
            @AltDependencyClient
            class Foo {}
            """
        } diagnostics: {
            """
            @AltDependencyClient
            ╰─ 🛑 '@AltDependencyClient' can only be applied to structs
            class Foo {}
            """
        }
    }

    func testMissingImplProtocolEmitsDiagnostics() throws {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {}
            """
        } diagnostics: {
            """
            @AltDependencyClient
            ╰─ 🛑 '@AltDependencyClient' requires a nested protocol named 'Interface'
            struct Foo {}
            """
        }
    }
}
#endif
