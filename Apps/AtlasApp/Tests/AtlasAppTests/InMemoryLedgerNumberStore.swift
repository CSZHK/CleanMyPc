import Foundation
@testable import AtlasApp

/// Shared in-memory ledger № counter for tests — keeps every `AtlasAppModel`
/// construction away from the real `UserDefaults.standard` store
/// (`atlas.ledger.nextNumber`), so test runs never pollute developer machines
/// (Batch H review issue: legacy model tests wrote through the default store).
final class InMemoryLedgerNumberStore: AtlasLedgerNumberStoring {
    private var counter = 0
    private(set) var recordedFallbackBases: [Int] = []

    func next(fallbackBase: Int) -> Int {
        recordedFallbackBases.append(fallbackBase)
        let number = counter > 0 ? counter : max(fallbackBase, 1)
        counter = number + 1
        return number
    }
}
