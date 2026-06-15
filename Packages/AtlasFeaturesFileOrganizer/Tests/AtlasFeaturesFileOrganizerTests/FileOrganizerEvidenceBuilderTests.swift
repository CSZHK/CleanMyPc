@testable import AtlasFeaturesFileOrganizer
import AtlasDesignSystem
import AtlasDomain
import XCTest

/// FileOrganizerEvidenceBuilder — pure functions (rule-hit chain, conflict
/// detection, metrics, panel state). Fail-closed (spec §1.6): no fabricated
/// rule attribution, no conflict row without a real filesystem mark.
final class FileOrganizerEvidenceBuilderTests: XCTestCase {

    // MARK: - Fixtures

    private func entry(
        _ name: String,
        bytes: Int64 = 100,
        category: FileOrganizerCategory = .images,
        dest: String? = nil
    ) -> FileOrganizerEntry {
        FileOrganizerEntry(
            path: "~/Desktop/\(name)",
            fileName: name,
            bytes: bytes,
            category: category,
            proposedDestination: dest ?? "~/Organized/Images/\(name)"
        )
    }

    private let imageRule = FileOrganizerRule(
        name: "Image Files", extensionPatterns: ["png", "jpg"], category: .images)
    private let docRule = FileOrganizerRule(
        name: "Document Files", extensionPatterns: ["pdf", "docx"], category: .documents)

    // MARK: - matchingRule (first-match wins, ordered)

    func testMatchingRuleByExtension() {
        let e = entry("photo.png")
        let match = FileOrganizerEvidenceBuilder.matchingRule(for: e, rules: [docRule, imageRule])
        XCTAssertEqual(match?.id, imageRule.id)
    }

    func testMatchingRuleFirstMatchWins() {
        // Two rules could match; the first in list order wins (classifier precedence).
        let earlier = FileOrganizerRule(name: "Earlier", extensionPatterns: ["png"], category: .other)
        let e = entry("photo.png")
        let match = FileOrganizerEvidenceBuilder.matchingRule(for: e, rules: [earlier, imageRule])
        XCTAssertEqual(match?.id, earlier.id)
    }

    func testMatchingRuleReturnsNilWhenNoRuleMatches() {
        let e = entry("photo.xyz", category: .other)
        let match = FileOrganizerEvidenceBuilder.matchingRule(for: e, rules: [imageRule, docRule])
        XCTAssertNil(match) // fail-closed: no fabricated attribution
    }

    func testMatchingRuleByNamePattern() {
        let screenshotRule = FileOrganizerRule(
            name: "Screenshots", extensionPatterns: [], namePatterns: ["screenshot"], category: .images)
        let e = entry("screenshot-2024.png", category: .images)
        let match = FileOrganizerEvidenceBuilder.matchingRule(for: e, rules: [screenshotRule])
        XCTAssertEqual(match?.id, screenshotRule.id)
    }

    func testMatchingRuleCatchAllByCategory() {
        // Empty patterns but matching category + no size constraints ⇒ catch-all.
        let catchAll = FileOrganizerRule(
            name: "All Images", extensionPatterns: [], namePatterns: [], category: .images)
        let e = entry("weird.qxz", category: .images)
        let match = FileOrganizerEvidenceBuilder.matchingRule(for: e, rules: [catchAll])
        XCTAssertEqual(match?.id, catchAll.id)
    }

    func testMatchingRuleSizeBandExcludesWhenOutOfRange() {
        // Size-band gating applies to catch-all rules (no extension/name
        // patterns): an out-of-range file is not matched by this rule. The
        // extension/name paths return before the size check (precedence).
        let bigImagesCatchAll = FileOrganizerRule(
            name: "Big Images", extensionPatterns: [], namePatterns: [],
            category: .images, minSizeBytes: 1_000_000)
        let small = entry("tiny.qxz", bytes: 500, category: .images)
        let match = FileOrganizerEvidenceBuilder.matchingRule(for: small, rules: [bigImagesCatchAll])
        XCTAssertNil(match) // size band excludes; no later rule matches
    }

    // MARK: - classificationWhy (human-readable chain, fail-closed)

    func testClassificationWhyExtensionHit() {
        let e = entry("photo.png")
        let why = FileOrganizerEvidenceBuilder.classificationWhy(for: e, rules: [imageRule])
        // Localized; assert it mentions the rule name and the extension signal.
        XCTAssertTrue(why.contains("Image Files"))
        XCTAssertTrue(why.contains("png"))
    }

    func testClassificationWhyDefaultWhenNoMatch() {
        // No rule matches ⇒ default-classification sentence (fail-closed, no invented rule).
        // The fallback surfaces the category title (localized — zh or en).
        let e = entry("weird.qxz", category: .other)
        let why = FileOrganizerEvidenceBuilder.classificationWhy(for: e, rules: [imageRule])
        let otherTitle = FileOrganizerCategory.other.title
        XCTAssertTrue(why.contains(otherTitle)) // category title surfaces in the fallback sentence
        XCTAssertFalse(why.contains("Image Files")) // no fabricated rule attribution
    }

    func testClassificationWhyNamePatternHit() {
        let screenshotRule = FileOrganizerRule(
            name: "Screenshots", extensionPatterns: [], namePatterns: ["screen"], category: .images)
        let e = entry("screenshot-2024.png", category: .images)
        let why = FileOrganizerEvidenceBuilder.classificationWhy(for: e, rules: [screenshotRule])
        XCTAssertTrue(why.contains("Screenshots"))
    }

    // MARK: - conflict detection (real filesystem; fail-closed)

    func testConflictingEntryIDsEmptyWhenNoDestinationExists() {
        // Entries point at ~/Organized/... which does not exist ⇒ no conflicts.
        let entries = [entry("a.png"), entry("b.png"), entry("c.pdf", category: .documents, dest: "~/Organized/Documents/c.pdf")]
        let conflicts = FileOrganizerEvidenceBuilder.conflictingEntryIDs(entries)
        XCTAssertTrue(conflicts.isEmpty)
    }

    func testConflictingEntryIDsDetectsRealExistingDestination() throws {
        // Create a real temp directory + file at the proposed destination ⇒ conflict.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let dest = tmp.appendingPathComponent("exists.png").path
        try Data().write(to: URL(fileURLWithPath: dest))
        // ~/Organized/... tilde-expansion isn't used here; use the real path so
        // conflictingEntryIDs' expandingTildeInPath resolves to itself.
        let e = FileOrganizerEntry(
            path: "/tmp/src.png", fileName: "exists.png", bytes: 1, category: .images,
            proposedDestination: dest)
        let conflicts = FileOrganizerEvidenceBuilder.conflictingEntryIDs([e])
        XCTAssertEqual(conflicts, [e.id])
    }

    // MARK: - metrics (mono, fail-closed)

    func testTotalBytes() {
        let entries = [entry("a.png", bytes: 100), entry("b.png", bytes: 250)]
        XCTAssertEqual(FileOrganizerEvidenceBuilder.totalBytes(entries), 350)
    }

    func testSelectedBytesRespectsSelection() {
        let entries = [entry("a.png", bytes: 100), entry("b.png", bytes: 250), entry("c.png", bytes: 50)]
        let selected: Set<UUID> = [entries[0].id, entries[2].id]
        XCTAssertEqual(FileOrganizerEvidenceBuilder.selectedBytes(entries, selectedIDs: selected), 150)
    }

    func testSelectedBytesEmptyForNoSelection() {
        let entries = [entry("a.png", bytes: 100)]
        XCTAssertEqual(FileOrganizerEvidenceBuilder.selectedBytes(entries, selectedIDs: []), 0)
    }

    // MARK: - insight detectors (large / duplicate)

    func testLargeFileIDsAboveThreshold() {
        let big = entry("big.png", bytes: FileOrganizerEvidenceBuilder.largeFileThreshold)
        let huge = entry("huge.png", bytes: FileOrganizerEvidenceBuilder.largeFileThreshold + 1)
        let small = entry("small.png", bytes: 10)
        let ids = FileOrganizerEvidenceBuilder.largeFileIDs([big, huge, small])
        XCTAssertEqual(ids, Set([big.id, huge.id]))
    }

    func testDuplicateFileIDsGroupByNameAndBytes() {
        // Same name + same bytes ⇒ duplicate group.
        let a = entry("dup.png", bytes: 500)
        let b = entry("dup.png", bytes: 500)
        let c = entry("unique.png", bytes: 500)
        let ids = FileOrganizerEvidenceBuilder.duplicateFileIDs([a, b, c])
        XCTAssertEqual(ids, Set([a.id, b.id]))
    }

    func testDuplicateFileIDsDistinguishesBySize() {
        // Same name, different bytes ⇒ not duplicates.
        let a = entry("dup.png", bytes: 500)
        let b = entry("dup.png", bytes: 501)
        let ids = FileOrganizerEvidenceBuilder.duplicateFileIDs([a, b])
        XCTAssertTrue(ids.isEmpty)
    }

    // MARK: - panelState (whole-panel state machine, fail-closed)

    func testPanelStateEmptyWhenNoSelection() {
        let entries = [entry("a.png")]
        let state = FileOrganizerEvidenceBuilder.panelState(
            entries: entries, selectedID: nil, selectedIDs: [], rules: [imageRule])
        XCTAssertEqual(state.kind, .empty)
        XCTAssertFalse(state.showsRecoveryBox) // no recovery promise surfaced
    }

    func testPanelStateEmptyWhenSelectionNotInEntries() {
        let entries = [entry("a.png")]
        let bogus = UUID()
        let state = FileOrganizerEvidenceBuilder.panelState(
            entries: entries, selectedID: bogus, selectedIDs: [], rules: [imageRule])
        XCTAssertEqual(state.kind, .empty)
    }

    func testPanelStateSingleForSelectedID() {
        let a = entry("photo.png")
        let state = FileOrganizerEvidenceBuilder.panelState(
            entries: [a], selectedID: a.id, selectedIDs: [], rules: [imageRule])
        XCTAssertEqual(state.kind, .single)
        XCTAssertFalse(state.showsRecoveryBox) // recoveryText nil for file-organizer (ledger-backed, not per-file)
    }

    func testPanelStateSingleFallsBackToSelectedIDs() {
        // selectedID nil but selectedIDs non-empty ⇒ first selected drives the panel.
        let a = entry("photo.png")
        let b = entry("doc.pdf", category: .documents, dest: "~/Organized/Documents/doc.pdf")
        let state = FileOrganizerEvidenceBuilder.panelState(
            entries: [a, b], selectedID: nil, selectedIDs: [b.id], rules: [imageRule, docRule])
        XCTAssertEqual(state.kind, .single)
    }

    func testPanelContentEvidenceRowsIncludeCoreKV() {
        let a = entry("photo.png", bytes: 2048)
        let content = FileOrganizerEvidenceBuilder.panelContent(
            entries: [a], selectedID: a.id, selectedIDs: [], rules: [imageRule])
        let labels = content.evidence.map(\.label)
        // Core rows always present (source / size / category / destination).
        XCTAssertGreaterThanOrEqual(content.evidence.count, 4)
        XCTAssertTrue(labels.contains { $0.contains("Source") || $0.contains("原始") })
        XCTAssertTrue(labels.contains { $0.contains("Size") || $0.contains("大小") })
        XCTAssertTrue(labels.contains { $0.contains("Category") || $0.contains("分类") })
        XCTAssertTrue(labels.contains { $0.contains("Destination") || $0.contains("目标") })
    }

    // MARK: - shortenDestination (preview list compactness)

    func testShortenDestinationTrimsToLastTwoSegments() {
        let shortened = FileOrganizerEvidenceBuilder.shortenDestination(
            "~/Source/a.png → ~/Organized/Images/sub/photo.png")
        XCTAssertTrue(shortened.hasPrefix("~/"))
        XCTAssertTrue(shortened.contains("/"))
    }

    func testShortenDestinationPassthroughForShortPath() {
        let shortened = FileOrganizerEvidenceBuilder.shortenDestination("noprefix")
        XCTAssertEqual(shortened, "noprefix")
    }

    // MARK: - search filter

    func testSearchFilterEmptyQueryReturnsAll() {
        let entries = [entry("a.png"), entry("b.pdf", category: .documents, dest: "~/Organized/Documents/b.pdf")]
        let filtered = FileOrganizerEvidenceBuilder.searchFiltered(entries, query: "")
        XCTAssertEqual(filtered.count, 2)
    }

    func testSearchFilterMatchesFileName() {
        let entries = [entry("invoice.pdf", category: .documents, dest: "~/Organized/Documents/invoice.pdf"),
                       entry("photo.png")]
        let filtered = FileOrganizerEvidenceBuilder.searchFiltered(entries, query: "invoice")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.fileName, "invoice.pdf")
    }
}
