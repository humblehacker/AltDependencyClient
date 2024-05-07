# @AltDependencyClient Macro

`@AltDependencyClient` serves a similar purpose to [Point-Free's](https://github.com/pointfreeco) [`@DependencyClient`](https://swiftpackageindex.com/pointfreeco/swift-dependencies/main/documentation/dependencies/designingdependencies#DependencyClient-macro) macro, but works in the opposite direction. That is, one of the features of `@DependencyClient` is the generation of wrapper functions to call the user's defined closure variables, allowing the use of function parameter names. `@AltDependencyClient` on the other hand generates the closure variables and the wrapper functions from the user-defined methods in a nested `Interface` protocol, which allows the use of both function parameter labels _and_ parameter names.

If you find this useful, or have suggestions for improvement, please let me know. This is my first Swift macro - be kind! 😃

## Example

### Input

```swift
@AltDependencyClient
struct AudioPlayerClient {
  protocol Interface {
      func loop(url: URL) async throws -> Void
      func play(url: URL) async throws -> Void
      func setVolume(volume: Float) async -> Void
      func stop() async -> Void
  }
}
```

### Expansion

```swift
struct AudioPlayerClient {
  protocol Interface {
      func loop(url: URL) async throws -> Void
      func play(url: URL) async throws -> Void
      func setVolume(volume: Float) async -> Void
      func stop() async -> Void
  }

  public var impl: Impl

  public init(
      loop: @escaping (_ url: URL) async throws -> Void,
      play: @escaping (_ url: URL) async throws -> Void,
      setVolume: @escaping (_ volume: Float) async -> Void,
      stop: @escaping () async -> Void
  ) {
      impl = Impl(
          loop: loop,
          play: play,
          setVolume: setVolume,
          stop: stop
      )
  }

  @inlinable
  @inline(__always)
  public
  func loop(url: URL) async throws -> Void {
      try await impl.loop(url)
  }

  @inlinable
  @inline(__always)
  public
  func play(url: URL) async throws -> Void {
      try await impl.play(url)
  }

  @inlinable
  @inline(__always)
  public
  func setVolume(volume: Float) async -> Void {
      await impl.setVolume(volume)
  }

  @inlinable
  @inline(__always)
  public
  func stop() async -> Void {
      await impl.stop()
  }

  public struct Impl {
      public var loop: (_ url: URL) async throws -> Void
      public var play: (_ url: URL) async throws -> Void
      public var setVolume: (_ volume: Float) async -> Void
      public var stop: () async -> Void
  }
}
```
</td>
</tr>
</table>

## Pros & Cons

### Pros
- Allows use of both function parameter labels and parameter names.
- The method implementations can still be replaced via access to the `impl` property.

### Cons
- Yes, defining the `Interface` protocol that is only used by the macro feels a bit strange.
- It doesn't support no-argument dependency construction like `@DependencyClient`, which generates a default "unimplemented" client.
- You can't use "show callers" on any of the methods defined in `Interface`, even after expanding the macro and trying it on the generated functions. `@DependencyClient` has the same limitation.
