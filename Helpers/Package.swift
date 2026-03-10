// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AtlasHelpers",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AtlasPrivilegedHelperCore", targets: ["AtlasPrivilegedHelperCore"]),
        .executable(name: "AtlasPrivilegedHelper", targets: ["AtlasPrivilegedHelper"]),
    ],
    dependencies: [
        .package(path: "../Packages"),
    ],
    targets: [
        .target(
            name: "AtlasPrivilegedHelperCore",
            dependencies: [
                .product(name: "AtlasProtocol", package: "Packages"),
            ],
            path: "AtlasPrivilegedHelper/Sources/AtlasPrivilegedHelperCore"
        ),
        .executableTarget(
            name: "AtlasPrivilegedHelper",
            dependencies: [
                "AtlasPrivilegedHelperCore",
                .product(name: "AtlasProtocol", package: "Packages"),
            ],
            path: "AtlasPrivilegedHelper/Sources/AtlasPrivilegedHelper"
        ),
        .testTarget(
            name: "AtlasPrivilegedHelperTests",
            dependencies: ["AtlasPrivilegedHelperCore", .product(name: "AtlasProtocol", package: "Packages")],
            path: "AtlasPrivilegedHelper/Tests/AtlasPrivilegedHelperTests"
        ),
    ]
)
