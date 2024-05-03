import AltDependencyClient

@AltDependencyClient
struct Example {
    protocol Interface {
        func foo(integer: Int) -> String
        func bar(from string: String) -> Int
        func baz() async throws
    }
}
