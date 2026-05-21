// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhostTerm",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ghostterm", targets: ["GhostTerm"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.13.0")
    ],
    targets: [
        .executableTarget(
            name: "GhostTerm",
            dependencies: ["SwiftTerm"],
            path: "Sources/GhostTerm"
        )
    ]
)
