@attached(peer)
public macro ReplaceableImplementation() = #externalMacro(
    module: "ReplaceableImplementationMacros",
    type: "ReplaceableImplementationMacro"
)
