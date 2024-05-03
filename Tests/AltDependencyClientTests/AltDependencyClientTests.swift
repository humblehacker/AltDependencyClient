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

    func testTupleReturnValue() throws {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func bar(from: Integer) -> (String, Float)
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func bar(from: Integer) -> (String, Float)
              }

              let impl: Impl

              init(
                bar: @escaping (_ from: Integer) -> (String, Float)
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              func bar(from: Integer) -> (String, Float) {
                impl.bar(from)
              }

              struct Impl {
                var bar: (_ from: Integer) -> (String, Float)
              }
            }
            """
        }
    }

    func testVoidTupleReturnValue() throws {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func bar(from: Integer) -> ()
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func bar(from: Integer) -> ()
              }

              let impl: Impl

              init(
                bar: @escaping (_ from: Integer) -> ()
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              func bar(from: Integer) -> () {
                impl.bar(from)
              }

              struct Impl {
                var bar: (_ from: Integer) -> ()
              }
            }
            """
        }
    }

    func testOptionalReturnValue() {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func bar() -> Int?
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func bar() -> Int?
              }

              let impl: Impl

              init(
                bar: @escaping () -> Int?
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              func bar() -> Int? {
                impl.bar()
              }

              struct Impl {
                var bar: () -> Int?
              }
            }
            """
        }
    }

    func testExplicitOptionalReturnValue() {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func bar() -> Optional<Int>
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func bar() -> Optional<Int>
              }

              let impl: Impl

              init(
                bar: @escaping () -> Optional<Int>
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              func bar() -> Optional<Int> {
                impl.bar()
              }

              struct Impl {
                var bar: () -> Optional<Int>
              }
            }
            """
        }
    }

    func testLabledArguments() {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func bar(from: Int) -> Void
                func baz(with something: String) -> Void
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func bar(from: Int) -> Void
                func baz(with something: String) -> Void
              }

              let impl: Impl

              init(
                bar: @escaping (_ from: Int) -> Void,
                baz: @escaping (_ something: String) -> Void
              ) {
                impl = Impl(
                  bar: bar,
                  baz: baz
                )
              }

              @inlinable
              @inline(__always)
              func bar(from: Int) -> Void {
                impl.bar(from)
              }

              @inlinable
              @inline(__always)
              func baz(with something: String) -> Void {
                impl.baz(something)
              }

              struct Impl {
                var bar: (_ from: Int) -> Void
                var baz: (_ something: String) -> Void
              }
            }
            """
        }
    }

    func testEscapedIdentifier() {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func `return`(from: Int) -> Void
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func `return`(from: Int) -> Void
              }

              let impl: Impl

              init(
                `return`: @escaping (_ from: Int) -> Void
              ) {
                impl = Impl(
                  return: `return`
                )
              }

              @inlinable
              @inline(__always)
              func `return`(from: Int) -> Void {
                impl.`return`(from)
              }

              struct Impl {
                var `return`: (_ from: Int) -> Void
              }
            }
            """
        }
    }

    func testInOut() {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func bar(from: inout Int) -> Void
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func bar(from: inout Int) -> Void
              }

              let impl: Impl

              init(
                bar: @escaping (_ from: inout Int) -> Void
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              func bar(from: inout Int) -> Void {
                impl.bar(&from)
              }

              struct Impl {
                var bar: (_ from: inout Int) -> Void
              }
            }
            """
        }
    }

    func testClosureParameter() {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func bar(from: (Int) -> Void) -> Void
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func bar(from: (Int) -> Void) -> Void
              }

              let impl: Impl

              init(
                bar: @escaping (_ from: (Int) -> Void) -> Void
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              func bar(from: (Int) -> Void) -> Void {
                impl.bar(from)
              }

              struct Impl {
                var bar: (_ from: (Int) -> Void) -> Void
              }
            }
            """
        }
    }

    func testAutoclosure() {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo {
              protocol Interface {
                func bar(from: @autoclosure () -> Void) -> Void
              }
            }
            """
        } expansion: {
            """
            struct Foo {
              protocol Interface {
                func bar(from: @autoclosure () -> Void) -> Void
              }

              let impl: Impl

              init(
                bar: @escaping (_ from: @autoclosure () -> Void) -> Void
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              func bar(from: @autoclosure () -> Void) -> Void {
                impl.bar(from())
              }

              struct Impl {
                var bar: (_ from: @autoclosure () -> Void) -> Void
              }
            }
            """
        }
    }
}
#endif
