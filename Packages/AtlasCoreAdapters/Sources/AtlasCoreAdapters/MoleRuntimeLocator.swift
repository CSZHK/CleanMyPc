import Foundation

enum MoleRuntimeLocator {
    static func runtimeURL() -> URL {
        if let bundled = Bundle.module.resourceURL?.appendingPathComponent("MoleRuntime", isDirectory: true),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        return sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func url(for relativePath: String) -> URL {
        runtimeURL().appendingPathComponent(relativePath)
    }
}
