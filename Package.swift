// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "AltDependencyClient",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AltDependencyClient",
            targets: ["AltDependencyClient"]
        ),
        .executable(
            name: "AltDependencyClientExample",
            targets: ["AltDependencyClientExample"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "510.0.2"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.5.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "AltDependencyClientMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "AltDependencyClient", dependencies: ["AltDependencyClientMacros"]),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(name: "AltDependencyClientExample", dependencies: ["AltDependencyClient"]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "AltDependencyClientTests",
            dependencies: [
                "AltDependencyClientMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]
        ),
    ]
)
