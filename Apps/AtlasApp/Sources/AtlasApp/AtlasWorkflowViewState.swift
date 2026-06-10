import AtlasDomain
import CryptoKit
import Foundation

// MARK: - Workflow ViewState (Calm Ledger spec §2.3 — state-machine host)

/// Per-route workflow view state, hosted on `AtlasAppModel` (keyed by `AtlasRoute`)
/// because `AppShellView` rebuilds feature views with `.id(route)` — feature-local
/// `@State` does not survive route switches (§7 behavior red line).
///
/// Stage indexes are 0-based: 0 ① scan · 1 ② review · 2 ③ execute · 3 ④ receipt
/// (FileOrganizer adds a 5th segment in Batch L; indexes stay 0-based).
struct AtlasWorkflowViewState: Equatable {
    /// The stage the user is looking at (≠ `currentStage` while reviewing a
    /// completed stage read-only — spec §2.3 回看 = 只读快照).
    var displayedStage: Int = 0
    /// The real workflow stage derived from model state (`AtlasWorkflowStageMap`).
    var currentStage: Int = 0
    /// Ledger plan number (№) — assigned when a scan completes with a plan.
    var planNumber: Int?
    /// Scan receipt `#XXXX` — first 4 uppercase hex of the scan-digest SHA256.
    var receiptCode: String?
    /// Checked rows. Scope = single plan: cleared whenever № changes (spec §2.3).
    var selectedIDs: Set<String> = []
    /// Active risk-filter chip. Plan-scoped like `selectedIDs`.
    var riskFilter: String?
    /// Selection driving the evidence panel / drawer.
    var evidenceSelectionID: String?
    /// Evidence drawer (<880pt) presentation.
    var drawerPresented: Bool = false
    /// Set by Cmd+Shift+R (`requestRescanConfirmation(for:)`); the confirmation
    /// dialog itself is presented by the feature screen (Batch I). Confirming
    /// runs `supersedePlan(for:)`, cancelling just clears the flag.
    var rescanConfirmationPending: Bool = false
}

// MARK: - Stage derivation (pure, unit-tested)

/// Pure mapping from model state to workflow stage — the §2.3 state-machine
/// table, shared by SmartClean / FileOrganizer hosts.
enum AtlasWorkflowStageMap {
    static let scanStage = 0
    static let reviewStage = 1
    static let executeStage = 2
    static let receiptStage = 3

    /// Model-state snapshot consumed by `resolve(_:)`. Callers map their module
    /// flags in (e.g. SmartClean: `isScanRunning`, `isPlanRunning`,
    /// `smartCleanExecutionIssue != nil`, `isCurrentSmartCleanPlanFresh`).
    struct Inputs: Equatable {
        var isScanning = false
        var isExecuting = false
        /// Execution issue present (e.g. `smartCleanExecutionIssue != nil`).
        var executionFailed = false
        var executionCompleted = false
        var isPlanFresh = false
        var findingsCount = 0
    }

    struct Resolution: Equatable {
        var current: Int
        /// ① with live progress (mono path scroll + percent).
        var isScanInProgress = false
        /// ② empty state — scan finished with 0 findings.
        var isReviewEmpty = false
        /// ③ error state — failed mid-execution (partial completion enters ledger).
        var isExecutionError = false
    }

    /// Spec §2.3 mapping table. Precedence (most live state wins):
    /// executing > scanning (a new cycle supersedes stale completion/failure)
    /// > failed > completed > plan-fresh (empty/non-empty) > no plan.
    static func resolve(_ inputs: Inputs) -> Resolution {
        if inputs.isExecuting {
            return Resolution(current: executeStage)
        }
        if inputs.isScanning {
            return Resolution(current: scanStage, isScanInProgress: true)
        }
        if inputs.executionFailed {
            return Resolution(current: executeStage, isExecutionError: true)
        }
        if inputs.executionCompleted {
            return Resolution(current: receiptStage)
        }
        if inputs.isPlanFresh {
            return Resolution(current: reviewStage, isReviewEmpty: inputs.findingsCount == 0)
        }
        return Resolution(current: scanStage)
    }
}

// MARK: - Receipt derivation (pure, deterministic)

/// Scan receipt `#XXXX` derivation (PER Decision Log): SHA256 over a stable
/// digest string — sorted `id:bytes` pairs of the findings plus the scan
/// timestamp — truncated to the first 4 hex digits, uppercase.
enum AtlasLedgerReceipt {
    static func code(findings: [Finding], scanDate: Date) -> String {
        let stableDigest = findings
            .map { "\($0.id.uuidString):\($0.bytes)" }
            .sorted()
            .joined(separator: "|")
        let payload = "\(stableDigest)@\(scanDate.timeIntervalSince1970)"
        let hash = SHA256.hash(data: Data(payload.utf8))
        let hex = hash.map { String(format: "%02X", $0) }.joined()
        return String(hex.prefix(4))
    }
}

// MARK: - Ledger number persistence (client-side only — PER revision da8c42f)

/// Ledger № counter store. Deliberately client-side (UserDefaults), NOT
/// `AtlasSettings`: settings round-trip the worker protocol and the worker's
/// `sanitized(settings:)` silently drops unknown fields — a counter there would
/// reset on every settings save (decision: option b, PER da8c42f).
protocol AtlasLedgerNumberStoring {
    /// Returns the next № and advances the counter. `fallbackBase` seeds the
    /// counter on first use (existing task-run count + 1).
    func next(fallbackBase: Int) -> Int
}

struct AtlasUserDefaultsLedgerNumberStore: AtlasLedgerNumberStoring {
    static let defaultsKey = "atlas.ledger.nextNumber"

    var defaults: UserDefaults = .standard

    func next(fallbackBase: Int) -> Int {
        let stored = defaults.integer(forKey: Self.defaultsKey)
        let number = stored > 0 ? stored : max(fallbackBase, 1)
        defaults.set(number + 1, forKey: Self.defaultsKey)
        return number
    }
}
