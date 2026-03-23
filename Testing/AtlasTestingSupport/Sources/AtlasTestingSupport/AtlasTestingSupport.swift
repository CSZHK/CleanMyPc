import AtlasApplication
import AtlasDomain
import AtlasProtocol
import Foundation

public struct AtlasFixtureAppDescriptor: Hashable, Sendable {
    public let scenario: String
    public let appName: String
    public let bundleIdentifier: String
    public let hasLaunchAgent: Bool
    public let expectedReviewOnlyCategories: [String]

    public init(
        scenario: String,
        appName: String,
        bundleIdentifier: String,
        hasLaunchAgent: Bool,
        expectedReviewOnlyCategories: [String]
    ) {
        self.scenario = scenario
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.hasLaunchAgent = hasLaunchAgent
        self.expectedReviewOnlyCategories = expectedReviewOnlyCategories
    }
}

public enum AtlasTestingFixtures {
    public static let workspace = AtlasScaffoldWorkspace.snapshot()
    public static let request = AtlasRequestEnvelope(command: .inspectPermissions)
    public static let firstFinding = AtlasScaffoldFixtures.findings.first
    public static let appEvidenceFixtures: [AtlasFixtureAppDescriptor] = [
        AtlasFixtureAppDescriptor(
            scenario: "mainstream-gui",
            appName: "Atlas Fixture Browser",
            bundleIdentifier: "com.example.atlas.fixture.browser",
            hasLaunchAgent: false,
            expectedReviewOnlyCategories: ["support files", "caches", "preferences"]
        ),
        AtlasFixtureAppDescriptor(
            scenario: "developer-heavy",
            appName: "Atlas Fixture Dev",
            bundleIdentifier: "com.example.atlas.fixture.dev",
            hasLaunchAgent: true,
            expectedReviewOnlyCategories: ["support files", "caches", "logs", "launch items"]
        ),
        AtlasFixtureAppDescriptor(
            scenario: "sparse-leftovers",
            appName: "Atlas Fixture Sparse",
            bundleIdentifier: "com.example.atlas.fixture.sparse",
            hasLaunchAgent: false,
            expectedReviewOnlyCategories: ["saved state"]
        ),
    ]

    public static let smartCleanSafeRoots: [String] = [
        "~/Library/Developer/CoreSimulator/Caches",
        "~/.gradle/caches",
        "~/.ivy2/cache",
    ]
}
