// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AtlasXPC",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AtlasWorkerXPC", targets: ["AtlasWorkerXPC"]),
    ],
    dependencies: [
        .package(path: "../Packages"),
    ],
    targets: [
        .executableTarget(
            name: "AtlasWorkerXPC",
            dependencies: [
                .product(name: "AtlasCoreAdapters", package: "Packages"),
                .product(name: "AtlasInfrastructure", package: "Packages"),
                .product(name: "AtlasProtocol", package: "Packages"),
            ],
            path: "AtlasWorkerXPC/Sources/AtlasWorkerXPC"
        ),
    ]
)
