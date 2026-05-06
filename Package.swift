// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Stash", targets: ["Stash"])
    ],
    targets: [
        .executableTarget(
            name: "Stash",
            path: "Sources/Stash",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
