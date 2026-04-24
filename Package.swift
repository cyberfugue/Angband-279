// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Angband279Swift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "angband279-swift", targets: ["Angband279Swift"])
    ],
    targets: [
        .executableTarget(
            name: "Angband279Swift",
            path: "Sources"
        )
    ]
)
