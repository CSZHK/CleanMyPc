import AtlasDomain
import Foundation

public actor AtlasUpdateChecker {
    public typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let releaseURL: URL
    private let dataLoader: DataLoader

    public init() {
        self.releaseURL = URL(string: "https://api.github.com/repos/CSZHK/CleanMyPc/releases/latest")!
        self.dataLoader = { request in
            try await URLSession.shared.data(for: request)
        }
    }

    init(
        releaseURL: URL = URL(string: "https://api.github.com/repos/CSZHK/CleanMyPc/releases/latest")!,
        dataLoader: @escaping DataLoader
    ) {
        self.releaseURL = releaseURL
        self.dataLoader = dataLoader
    }

    public func checkForUpdate(currentVersion: String) async throws -> AtlasAppUpdate {
        var request = URLRequest(url: releaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await dataLoader(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AtlasUpdateCheckerError.requestFailed
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 404:
            throw AtlasUpdateCheckerError.noPublishedRelease
        default:
            throw AtlasUpdateCheckerError.requestFailed
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        let latestVersion = release.tagName
        let isNewer = AtlasVersionComparator.isNewer(latestVersion, than: currentVersion)

        return AtlasAppUpdate(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseURL: URL(string: release.htmlURL),
            releaseNotes: release.body,
            isUpdateAvailable: isNewer
        )
    }
}

public enum AtlasUpdateCheckerError: LocalizedError, Sendable, Equatable {
    case requestFailed
    case noPublishedRelease

    public var errorDescription: String? {
        switch self {
        case .requestFailed:
            return AtlasL10n.string("update.error.requestFailed")
        case .noPublishedRelease:
            return AtlasL10n.string("update.notice.noPublishedRelease")
        }
    }
}

private struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let htmlURL: String
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}
