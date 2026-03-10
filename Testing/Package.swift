// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AtlasTesting",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AtlasTestingSupport", targets: ["AtlasTestingSupport"]),
    ],
    dependencies: [
        .package(path: "../Packages"),
    ],
    targets: [
        .target(
            name: "AtlasTestingSupport",
            dependencies: [
                .product(name: "AtlasApplication", package: "Packages"),
                .product(name: "AtlasDomain", package: "Packages"),
                .product(name: "AtlasProtocol", package: "Packages"),
            ],
            path: "AtlasTestingSupport/Sources/AtlasTestingSupport"
        ),
    ]
)
