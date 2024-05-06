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

              public var impl: Impl

              public init(
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
              public
              func foo(integer: Int) -> String {
                impl.foo(integer)
              }

              @inlinable
              @inline(__always)
              public
              func bar(from string: String) -> Int {
                impl.bar(string)
              }

              @inlinable
              @inline(__always)
              public
              func baz() async throws {
                try await impl.baz()
              }

              public struct Impl {
                public var foo: (_ integer: Int) -> String
                public var bar: (_ string: String) -> Int
                public var baz: () async throws -> Void
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
               ✏️ Insert 'protocol Interface'
            struct Foo {}
            """
        } fixes: {
            """
            @AltDependencyClient
            struct Foo {
            protocol Interface { }}
            """
        } expansion: {
            """
            struct Foo {
            protocol Interface { }

                public var impl: Impl

                public init(
                ) {
                    impl = Impl(
                    )
                }

                public struct Impl {
                }}
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

              public var impl: Impl

              public init(
                bar: @escaping (_ from: Integer) -> (String, Float)
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              public
              func bar(from: Integer) -> (String, Float) {
                impl.bar(from)
              }

              public struct Impl {
                public var bar: (_ from: Integer) -> (String, Float)
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

              public var impl: Impl

              public init(
                bar: @escaping (_ from: Integer) -> ()
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              public
              func bar(from: Integer) -> () {
                impl.bar(from)
              }

              public struct Impl {
                public var bar: (_ from: Integer) -> ()
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

              public var impl: Impl

              public init(
                bar: @escaping () -> Int?
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              public
              func bar() -> Int? {
                impl.bar()
              }

              public struct Impl {
                public var bar: () -> Int?
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

              public var impl: Impl

              public init(
                bar: @escaping () -> Optional<Int>
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              public
              func bar() -> Optional<Int> {
                impl.bar()
              }

              public struct Impl {
                public var bar: () -> Optional<Int>
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

              public var impl: Impl

              public init(
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
              public
              func bar(from: Int) -> Void {
                impl.bar(from)
              }

              @inlinable
              @inline(__always)
              public
              func baz(with something: String) -> Void {
                impl.baz(something)
              }

              public struct Impl {
                public var bar: (_ from: Int) -> Void
                public var baz: (_ something: String) -> Void
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

              public var impl: Impl

              public init(
                `return`: @escaping (_ from: Int) -> Void
              ) {
                impl = Impl(
                  return: `return`
                )
              }

              @inlinable
              @inline(__always)
              public
              func `return`(from: Int) -> Void {
                impl.`return`(from)
              }

              public struct Impl {
                public var `return`: (_ from: Int) -> Void
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

              public var impl: Impl

              public init(
                bar: @escaping (_ from: inout Int) -> Void
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              public
              func bar(from: inout Int) -> Void {
                impl.bar(&from)
              }

              public struct Impl {
                public var bar: (_ from: inout Int) -> Void
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

              public var impl: Impl

              public init(
                bar: @escaping (_ from: (Int) -> Void) -> Void
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              public
              func bar(from: (Int) -> Void) -> Void {
                impl.bar(from)
              }

              public struct Impl {
                public var bar: (_ from: (Int) -> Void) -> Void
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

              public var impl: Impl

              public init(
                bar: @escaping (_ from: @autoclosure () -> Void) -> Void
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              public
              func bar(from: @autoclosure () -> Void) -> Void {
                impl.bar(from())
              }

              public struct Impl {
                public var bar: (_ from: @autoclosure () -> Void) -> Void
              }
            }
            """
        }
    }

    func testSendableStruct() {
        assertMacro {
            """
            @AltDependencyClient
            struct Foo: Sendable {
              protocol Interface {
                func bar(int: Int) -> Void
              }
            }
            """
        } expansion: {
            """
            struct Foo: Sendable {
              protocol Interface {
                func bar(int: Int) -> Void
              }

              public var impl: Impl

              public init(
                bar: @Sendable @escaping (_ int: Int) -> Void
              ) {
                impl = Impl(
                  bar: bar
                )
              }

              @inlinable
              @inline(__always)
              public
              func bar(int: Int) -> Void {
                impl.bar(int)
              }

              public struct Impl: Sendable {
                public var bar: @Sendable (_ int: Int) -> Void
              }
            }
            """
        }
    }
}
#endif
