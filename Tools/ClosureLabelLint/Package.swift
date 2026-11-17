// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClosureLabelLint",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "closure-label-lint", targets: ["closure-label-lint"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0")
    ],
    targets: [
        .target(
            name: "ClosureLabelLintCore",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "closure-label-lint",
            dependencies: ["ClosureLabelLintCore"]
        ),
        .testTarget(
            name: "ClosureLabelLintCoreTests",
            dependencies: ["ClosureLabelLintCore"]
        ),
    ]
)
