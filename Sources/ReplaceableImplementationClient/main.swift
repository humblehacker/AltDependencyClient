import ReplaceableImplementation

//@ReplaceableImplementation
//protocol FooDependency {
//    func foo(integer: Int) -> String
//}

struct FooExample {
    let impl: Impl

    func foo(integer: Int) -> String {
        return impl.foo(integer)
    }

    struct Impl {
        var foo: (_ integer: Int) -> String
    }
}
