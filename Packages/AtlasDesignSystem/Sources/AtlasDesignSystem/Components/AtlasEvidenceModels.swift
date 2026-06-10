import AtlasDomain
import SwiftUI

// MARK: - Evidence Panel Models
// Value models + state machine for AtlasEvidencePanel (split out for the
// one-component-per-file ≤350-line discipline; the view lives in AtlasEvidencePanel.swift).


/// One mono key-value evidence row (label + value; value is often a path).
public struct AtlasEvidenceItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

/// Single-selection three-segment content (why / evidence / recovery).
public struct AtlasEvidenceContent {
    public let title: String
    public let whyText: String
    public let evidence: [AtlasEvidenceItem]
    /// nil ⇒ the ⛨ recovery box is NOT rendered (fail-closed, spec §1.6).
    public let recoveryText: String?

    public init(title: String, whyText: String, evidence: [AtlasEvidenceItem], recoveryText: String?) {
        self.title = title
        self.whyText = whyText
        self.evidence = evidence
        self.recoveryText = recoveryText
    }
}

/// Multi-selection aggregate (count + mono total + risk breakdown).
public struct AtlasEvidenceAggregate {
    public let count: Int
    public let totalText: String
    public let riskBreakdown: [(label: String, count: Int, tone: AtlasTone)]
    /// nil ⇒ no common recovery promise is shown (fail-closed, spec §1.6).
    public let commonRecoveryText: String?

    public init(
        count: Int,
        totalText: String,
        riskBreakdown: [(label: String, count: Int, tone: AtlasTone)],
        commonRecoveryText: String?
    ) {
        self.count = count
        self.totalText = totalText
        self.riskBreakdown = riskBreakdown
        self.commonRecoveryText = commonRecoveryText
    }
}

/// Panel display state. `executing` carries a live row-level status stream.
public enum AtlasEvidenceState {
    case empty
    case single(AtlasEvidenceContent)
    case aggregate(AtlasEvidenceAggregate)
    case executing(rows: [(title: String, status: AtlasTone, detail: String?)])
}

public extension AtlasEvidenceState {
    /// Discriminator for exhaustive state handling in hosts/tests.
    enum Kind: Equatable, Sendable { case empty, single, aggregate, executing }

    var kind: Kind {
        switch self {
        case .empty: return .empty
        case .single: return .single
        case .aggregate: return .aggregate
        case .executing: return .executing
        }
    }

    /// Whether the ⛨ recovery box renders. Fail-closed (spec §1.6): only a
    /// non-blank recovery text present in the state produces the box — empty,
    /// whitespace-only, and nil all suppress it.
    var showsRecoveryBox: Bool {
        switch self {
        case .single(let content):
            return Self.isPresent(content.recoveryText)
        case .aggregate(let aggregate):
            return Self.isPresent(aggregate.commonRecoveryText)
        case .empty, .executing:
            return false
        }
    }

    private static func isPresent(_ text: String?) -> Bool {
        guard let text else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
