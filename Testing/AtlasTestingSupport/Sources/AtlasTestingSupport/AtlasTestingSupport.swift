import AtlasApplication
import AtlasDomain
import AtlasProtocol
import Foundation

public enum AtlasTestingFixtures {
    public static let workspace = AtlasScaffoldWorkspace.snapshot()
    public static let request = AtlasRequestEnvelope(command: .inspectPermissions)
    public static let firstFinding = AtlasScaffoldFixtures.findings.first
}
