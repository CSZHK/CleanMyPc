// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AtlasPackages",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AtlasApplication", targets: ["AtlasApplication"]),
        .library(name: "AtlasCoreAdapters", targets: ["AtlasCoreAdapters"]),
        .library(name: "AtlasDesignSystem", targets: ["AtlasDesignSystem"]),
        .library(name: "AtlasDomain", targets: ["AtlasDomain"]),
        .library(name: "AtlasFeaturesApps", targets: ["AtlasFeaturesApps"]),
        .library(name: "AtlasFeaturesHistory", targets: ["AtlasFeaturesHistory"]),
        .library(name: "AtlasFeaturesOverview", targets: ["AtlasFeaturesOverview"]),
        .library(name: "AtlasFeaturesPermissions", targets: ["AtlasFeaturesPermissions"]),
        .library(name: "AtlasFeaturesAbout", targets: ["AtlasFeaturesAbout"]),
        .library(name: "AtlasFeaturesSettings", targets: ["AtlasFeaturesSettings"]),
        .library(name: "AtlasFeaturesSmartClean", targets: ["AtlasFeaturesSmartClean"]),
        .library(name: "AtlasFeaturesStorage", targets: ["AtlasFeaturesStorage"]),
        .library(name: "AtlasInfrastructure", targets: ["AtlasInfrastructure"]),
        .library(name: "AtlasProtocol", targets: ["AtlasProtocol"]),
    ],
    targets: [
        .target(
            name: "AtlasDesignSystem",
            dependencies: ["AtlasDomain"],
            path: "AtlasDesignSystem/Sources/AtlasDesignSystem",
            resources: [.process("Resources")]
        ),
        .target(
            name: "AtlasDomain",
            path: "AtlasDomain/Sources/AtlasDomain",
            resources: [.process("Resources")]
        ),
        .target(
            name: "AtlasProtocol",
            dependencies: ["AtlasDomain"],
            path: "AtlasProtocol/Sources/AtlasProtocol"
        ),
        .target(
            name: "AtlasApplication",
            dependencies: ["AtlasDomain", "AtlasProtocol"],
            path: "AtlasApplication/Sources/AtlasApplication"
        ),
        .target(
            name: "AtlasInfrastructure",
            dependencies: ["AtlasApplication", "AtlasDomain", "AtlasProtocol"],
            path: "AtlasInfrastructure/Sources/AtlasInfrastructure"
        ),
        .target(
            name: "AtlasCoreAdapters",
            dependencies: ["AtlasApplication", "AtlasDomain", "AtlasInfrastructure", "AtlasProtocol"],
            path: "AtlasCoreAdapters/Sources/AtlasCoreAdapters",
            resources: [.copy("Resources/MoleRuntime")]
        ),
        .target(
            name: "AtlasFeaturesOverview",
            dependencies: ["AtlasApplication", "AtlasDesignSystem", "AtlasDomain"],
            path: "AtlasFeaturesOverview/Sources/AtlasFeaturesOverview"
        ),
        .target(
            name: "AtlasFeaturesSmartClean",
            dependencies: ["AtlasApplication", "AtlasDesignSystem", "AtlasDomain"],
            path: "AtlasFeaturesSmartClean/Sources/AtlasFeaturesSmartClean"
        ),
        .target(
            name: "AtlasFeaturesAbout",
            dependencies: ["AtlasDesignSystem", "AtlasDomain"],
            path: "AtlasFeaturesAbout/Sources/AtlasFeaturesAbout"
        ),
        .target(
            name: "AtlasFeaturesApps",
            dependencies: ["AtlasDesignSystem", "AtlasDomain"],
            path: "AtlasFeaturesApps/Sources/AtlasFeaturesApps"
        ),
        .target(
            name: "AtlasFeaturesStorage",
            dependencies: ["AtlasDesignSystem", "AtlasDomain"],
            path: "AtlasFeaturesStorage/Sources/AtlasFeaturesStorage"
        ),
        .target(
            name: "AtlasFeaturesHistory",
            dependencies: ["AtlasDesignSystem", "AtlasDomain"],
            path: "AtlasFeaturesHistory/Sources/AtlasFeaturesHistory"
        ),
        .target(
            name: "AtlasFeaturesPermissions",
            dependencies: ["AtlasDesignSystem", "AtlasDomain"],
            path: "AtlasFeaturesPermissions/Sources/AtlasFeaturesPermissions"
        ),
        .target(
            name: "AtlasFeaturesSettings",
            dependencies: ["AtlasDesignSystem", "AtlasDomain"],
            path: "AtlasFeaturesSettings/Sources/AtlasFeaturesSettings"
        ),
        .testTarget(
            name: "AtlasApplicationTests",
            dependencies: ["AtlasApplication", "AtlasDomain", "AtlasProtocol"],
            path: "AtlasApplication/Tests/AtlasApplicationTests"
        ),
        .testTarget(
            name: "AtlasCoreAdaptersTests",
            dependencies: ["AtlasCoreAdapters", "AtlasDomain", "AtlasApplication"],
            path: "AtlasCoreAdapters/Tests/AtlasCoreAdaptersTests"
        ),
        .testTarget(
            name: "AtlasDomainTests",
            dependencies: ["AtlasDomain"],
            path: "AtlasDomain/Tests/AtlasDomainTests"
        ),
        .testTarget(
            name: "AtlasProtocolTests",
            dependencies: ["AtlasProtocol"],
            path: "AtlasProtocol/Tests/AtlasProtocolTests"
        ),
        .testTarget(
            name: "AtlasInfrastructureTests",
            dependencies: ["AtlasInfrastructure", "AtlasApplication", "AtlasDomain", "AtlasProtocol"],
            path: "AtlasInfrastructure/Tests/AtlasInfrastructureTests"
        ),
    ]
)
