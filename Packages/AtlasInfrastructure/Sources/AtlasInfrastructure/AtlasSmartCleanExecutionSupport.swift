import AtlasDomain
import Foundation

public enum AtlasSmartCleanExecutionSupport {
    public static func requiresHelper(for targetURL: URL, homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let helperRoots = [
            "/Applications",
            homeDirectoryURL.appendingPathComponent("Applications", isDirectory: true).path,
            homeDirectoryURL.appendingPathComponent("Library/LaunchAgents", isDirectory: true).path,
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
        ]
        let path = targetURL.path
        return helperRoots.contains { root in
            path == root || path.hasPrefix(root + "/")
        }
    }

    public static func isDirectlyTrashable(_ targetURL: URL, homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let path = targetURL.path
        let home = homeDirectoryURL.path
        guard path.hasPrefix(home + "/") else { return false }
        if path == home || path == home + "/Library" { return false }

        let safePrefixes = [
            home + "/Library/Caches",
            home + "/Library/Logs",
            home + "/Library/Suggestions",
            home + "/Library/Messages/Caches",
            home + "/Library/Developer/CoreSimulator/Caches",
            home + "/Library/Developer/CoreSimulator/tmp",
            home + "/Library/Developer/Xcode/DerivedData",
            home + "/Library/pnpm/store",
            home + "/.npm",
            home + "/.npm_cache",
            home + "/.gradle/caches",
            home + "/.ivy2/cache",
            home + "/.oh-my-zsh/cache",
            home + "/.cache",
            home + "/.pytest_cache",
            home + "/.jupyter/runtime",
            home + "/.tnpm/_cacache",
            home + "/.tnpm/_logs",
            home + "/.yarn/cache",
            home + "/.bun/install/cache",
            home + "/.pyenv/cache",
            home + "/.conda/pkgs",
            home + "/anaconda3/pkgs",
            home + "/.cargo/registry/cache",
            home + "/.cargo/git",
            home + "/.rustup/downloads",
            home + "/.docker/buildx/cache",
            home + "/.kube/cache",
            home + "/.local/share/containers/storage/tmp",
            home + "/.aws/cli/cache",
            home + "/.config/gcloud/logs",
            home + "/.azure/logs",
            home + "/.node-gyp",
            home + "/.turbo/cache",
            home + "/.vite/cache",
            home + "/.parcel-cache",
            home + "/.android/build-cache",
            home + "/.android/cache",
            home + "/.cache/swift-package-manager",
            home + "/.swiftpm/cache",
            home + "/.expo/expo-go",
            home + "/.expo/android-apk-cache",
            home + "/.expo/ios-simulator-app-cache",
            home + "/.expo/native-modules-cache",
            home + "/.expo/schema-cache",
            home + "/.expo/template-cache",
            home + "/.expo/versions-cache",
            home + "/.vagrant.d/tmp",
        ]
        if safePrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }

        if isSupportedContainerCleanupPath(path, homeDirectoryURL: homeDirectoryURL) {
            return true
        }

        let safeFragments = [
            "/__pycache__",
            "/.next/cache",
            "/component_crx_cache",
            "/GoogleUpdater",
            "/CoreSimulator.log",
            "/Application Cache",
            "/GPUCache",
            "/cache2",
            "/extensions_crx_cache",
            "/GraphiteDawnCache",
            "/GrShaderCache",
            "/ShaderCache",
        ]
        if safeFragments.contains(where: { path.contains($0) }) {
            return true
        }

        let basename = targetURL.lastPathComponent.lowercased()
        if basename.hasSuffix(".pyc") {
            return true
        }

        let safeBasenamePrefixes = [
            ".zcompdump",
            ".zsh_history.bak",
        ]
        return safeBasenamePrefixes.contains(where: { basename.hasPrefix($0) })
    }

    private static func isSupportedContainerCleanupPath(_ path: String, homeDirectoryURL: URL) -> Bool {
        let containerRoot = homeDirectoryURL.appendingPathComponent("Library/Containers", isDirectory: true).path
        guard path == containerRoot || path.hasPrefix(containerRoot + "/") else {
            return false
        }

        let allowedContainerFragments = [
            "/Data/Library/Caches",
            "/Data/Library/Logs",
            "/Data/tmp",
            "/Data/Library/tmp",
        ]

        return allowedContainerFragments.contains(where: { fragment in
            path == containerRoot + fragment || path.contains(fragment + "/") || path.hasSuffix(fragment)
        })
    }

    public static func isSupportedExecutionTarget(_ targetURL: URL, homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        requiresHelper(for: targetURL, homeDirectoryURL: homeDirectoryURL)
            || isDirectlyTrashable(targetURL, homeDirectoryURL: homeDirectoryURL)
    }

    public static func isFindingExecutionSupported(_ finding: Finding, homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        guard let targetPaths = finding.targetPaths, !targetPaths.isEmpty else {
            return false
        }
        return targetPaths.allSatisfy { rawPath in
            let url = URL(fileURLWithPath: rawPath).resolvingSymlinksInPath()
            return isSupportedExecutionTarget(url, homeDirectoryURL: homeDirectoryURL)
        }
    }
}
