@attached(member, names: arbitrary)
public macro AltDependencyClient() = #externalMacro(
    module: "AltDependencyClientMacros",
    type: "AltDependencyClientMacro"
)
