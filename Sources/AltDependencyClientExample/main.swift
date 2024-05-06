import AltDependencyClient

@AltDependencyClient
struct Example: Sendable {
    protocol Interface {
        func foo(integer: inout Int) -> String
        func bar(from string: String) -> Int
        func auto_closure(x: @autoclosure () -> ())
        func `return`() async throws
    }
}
