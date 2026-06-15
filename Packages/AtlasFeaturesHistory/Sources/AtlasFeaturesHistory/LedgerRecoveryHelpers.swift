import AtlasDomain
import Foundation

// MARK: - Shared RecoveryItem helpers (review fix M-1 — single source of truth)

// Previously `isExpired` / `isExpiringSoon` were duplicated as `private
// extension RecoveryItem` in both LedgerFeatureView.swift and
// LedgerDetailView.swift, and `hasPhysicalRestorePath` lived only in the
// detail view. Hoisted here as a single package-internal truth so both views
// agree on expiry/restore-path semantics and the duplication (and the drift
// risk it carried) is gone. Consumers are in-package only; this never leaks
// across module boundaries (AtlasInfrastructure has its own parameterized
// `isExpired(asOf:)` on a different type — no collision).

extension RecoveryItem {
    /// True when the retention window has closed (or, for no-expiry items,
    /// never — they are permanently recoverable records). Fail-closed: a
    /// missing expiry is treated as *not* expired.
    var isExpired: Bool { expiresAt.map { $0 <= Date() } ?? false }

    /// True when the window closes within the next ~3 days (warning band).
    /// Items without an expiry never enter the warning band.
    var isExpiringSoon: Bool {
        guard let expiresAt else { return false }
        let cutoff = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return expiresAt <= cutoff
    }

    /// True when the item carries real file-backed restore mappings (as
    /// opposed to state-only records). Used to decide whether the
    /// restore-point stamp watermark renders and which restore copy/hint
    /// applies. Fail-closed: empty/nil mappings ⇒ state-only.
    var hasPhysicalRestorePath: Bool { !(restoreMappings ?? []).isEmpty }
}
