// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AtlasApps",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AtlasApp", targets: ["AtlasApp"]),
    ],
    dependencies: [
        .package(path: "../Packages"),
    ],
    targets: [
        .executableTarget(
            name: "AtlasApp",
            dependencies: [
                .product(name: "AtlasApplication", package: "Packages"),
                .product(name: "AtlasCoreAdapters", package: "Packages"),
                .product(name: "AtlasDesignSystem", package: "Packages"),
                .product(name: "AtlasDomain", package: "Packages"),
                .product(name: "AtlasFeaturesApps", package: "Packages"),
                .product(name: "AtlasFeaturesHistory", package: "Packages"),
                .product(name: "AtlasFeaturesOverview", package: "Packages"),
                .product(name: "AtlasFeaturesPermissions", package: "Packages"),
                .product(name: "AtlasFeaturesSettings", package: "Packages"),
                .product(name: "AtlasFeaturesSmartClean", package: "Packages"),
                .product(name: "AtlasInfrastructure", package: "Packages"),
            ],
            path: "AtlasApp/Sources/AtlasApp",
            resources: [.process("Assets.xcassets")]
        ),
        .testTarget(
            name: "AtlasAppTests",
            dependencies: [
                "AtlasApp",
                .product(name: "AtlasApplication", package: "Packages"),
                .product(name: "AtlasDomain", package: "Packages"),
                .product(name: "AtlasInfrastructure", package: "Packages"),
            ],
            path: "AtlasApp/Tests/AtlasAppTests"
        ),
    ]
)
