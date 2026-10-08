// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SideKeyMacro",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "sidekey-macro", targets: ["SideKeyMacro"])
    ],
    targets: [
        .executableTarget(
            name: "SideKeyMacro",
            path: "Sources/SideKeyMacro"
        )
    ]
)
