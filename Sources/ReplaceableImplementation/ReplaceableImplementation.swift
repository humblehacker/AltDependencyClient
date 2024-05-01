@attached(member, names: arbitrary)
public macro ReplaceableImplementation() = #externalMacro(
    module: "ReplaceableImplementationMacros",
    type: "ReplaceableImplementationMacro"
)
