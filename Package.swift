// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Copiest",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Copiest", path: "Sources/Copiest")
    ]
)
