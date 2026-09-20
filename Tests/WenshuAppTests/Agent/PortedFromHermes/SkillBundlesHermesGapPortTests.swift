//
//  SkillBundlesHermesGapPortTests.swift · Wenshu · H5-SKILL-BUNDLES-HERMES-PORT (2026-09-19)
//
//  Verifies the 4 new hermes port additions to
//  `Core/Agent/Skill/SkillBundles.swift` (= hermes
//  `agent/skill_bundles.py` 438 LOC Python).
//
//  Hermes pure helpers ported:
//    - slugify (= hermes `_slugify` at L78-L82)
//    - bundlePath(for:) (= hermes `bundle_path_for` at L378-L383)
//    - scanBundles(directory:) (= hermes `scan_bundles` at
//      L160-L177 + `get_skill_bundles` at L195-L203)
//    - reloadBundles(directory:) (= hermes `reload_bundles` at
//      L211-L227)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure-function port; = no
//  YAML-disk-IO glue (= hermes `_load_bundle_file` + `save_bundle` +
//  `delete_bundle` deferred to future tickets per the file header
//  comment in SkillBundles.swift).

import XCTest
@testable import WenshuApp

final class SkillBundlesHermesGapPortTests: XCTestCase {

    // Per wenshu-stale-test-cleanup Class D recipe: SkillBundles.shared
    // is an actor with mutable state (= bundles dict); tests that share it
    // leak state across test runs. Reset in setUp to give every test a
    // known empty baseline.
    override func setUp() async throws {
        try await super.setUp()
        await SkillBundles.shared.unregisterAll()
    }

    override func tearDown() async throws {
        await SkillBundles.shared.unregisterAll()
        try await super.tearDown()
    }

    // MARK: -- H5.1 slugify tests (= hermes L78-L82)

    func testSlugify_lowercasesInput() {
        XCTAssertEqual(SkillBundles.slugify("MyBundle"), "mybundle")
    }

    func testSlugify_replacesSpacesWithHyphens() {
        XCTAssertEqual(SkillBundles.slugify("my bundle"), "my-bundle")
    }

    func testSlugify_replacesUnderscoresWithHyphens() {
        XCTAssertEqual(SkillBundles.slugify("my_bundle"), "my-bundle")
    }

    func testSlugify_stripsInvalidChars() {
        XCTAssertEqual(SkillBundles.slugify("my bundle!@#"), "my-bundle")
    }

    func testSlugify_collapsesMultipleHyphens() {
        XCTAssertEqual(SkillBundles.slugify("my---bundle"), "my-bundle")
    }

    func testSlugify_stripsLeadingTrailingHyphens() {
        XCTAssertEqual(SkillBundles.slugify("--my-bundle--"), "my-bundle")
    }

    func testSlugify_emptyStringReturnsEmpty() {
        XCTAssertEqual(SkillBundles.slugify(""), "")
    }

    func testSlugify_punctuationOnlyReturnsEmpty() {
        XCTAssertEqual(SkillBundles.slugify("!!!"), "")
    }

    // MARK: -- H5.2 bundlePath(for:) tests (= hermes L378-L383)

    func testBundlePath_buildsValidPath() throws {
        let url = try SkillBundles.bundlePath(for: "My Bundle")
        XCTAssertTrue(url.path.hasSuffix("/my-bundle.yaml"))
    }

    func testBundlePath_throwsForEmptySlug() {
        XCTAssertThrowsError(try SkillBundles.bundlePath(for: "!!!"))
    }

    func testBundlePath_stripsUnderscores() throws {
        let url = try SkillBundles.bundlePath(for: "alpha_beta")
        XCTAssertTrue(url.path.hasSuffix("/alpha-beta.yaml"))
    }

    // MARK: -- H5.3 scanBundles tests (= hermes L160-L177)

    func testScanBundles_emptyDirectory_returnsZero() async {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h5-empty-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundles = SkillBundles.shared
        let count = await bundles.scanBundles(directory: tmp)
        XCTAssertEqual(count, 0)
    }

    func testScanBundles_nonexistentDirectory_returnsZero() async {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h5-doesnotexist-\(UUID().uuidString)")
        let bundles = SkillBundles.shared
        let count = await bundles.scanBundles(directory: tmp)
        XCTAssertEqual(count, 0)
    }

    func testScanBundles_validYAMLFile_registersBundle() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h5-valid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let yaml = """
        id: alpha
        name: Alpha Bundle
        skill_ids:
          - skill-one
          - skill-two
        dependencies: []
        """
        let yamlURL = tmp.appendingPathComponent("alpha.yaml")
        try yaml.write(to: yamlURL, atomically: true, encoding: .utf8)

        let bundles = SkillBundles.shared
        let count = await bundles.scanBundles(directory: tmp)
        XCTAssertGreaterThan(count, 0)
        let alphaBundle = await bundles.current.first { $0.id == "alpha" }
        XCTAssertNotNil(alphaBundle)
        XCTAssertEqual(alphaBundle?.name, "Alpha Bundle")
    }

    // MARK: -- H5.4 reloadBundles tests (= hermes L211-L227)

    func testReloadBundles_emptyInitial_returnsEmptyDiff() async {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h5-reload-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundles = SkillBundles.shared
        let diff = await bundles.reloadBundles(directory: tmp)
        XCTAssertEqual(diff.added.count, 0)
        XCTAssertEqual(diff.removed.count, 0)
        XCTAssertEqual(diff.unchanged.count, 0)
        XCTAssertEqual(diff.total, 0)
    }

    func testReloadBundles_addedAfterFirstScan_marksAdded() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h5-reload-add-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundles = SkillBundles.shared
        let yaml = """
        id: beta
        name: Beta
        skill_ids:
          - skill-x
        dependencies: []
        """
        let yamlURL = tmp.appendingPathComponent("beta.yaml")
        try yaml.write(to: yamlURL, atomically: true, encoding: .utf8)

        let diff = await bundles.reloadBundles(directory: tmp)
        XCTAssertTrue(diff.added.contains("beta"))
        XCTAssertEqual(diff.total, 1)
    }

    // MARK: -- H5.5 ReloadDiff struct tests

    func testReloadDiff_equatable() {
        let d1 = ReloadDiff(added: ["a"], removed: [], unchanged: [], total: 1)
        let d2 = ReloadDiff(added: ["a"], removed: [], unchanged: [], total: 1)
        XCTAssertEqual(d1, d2)
    }

    func testReloadDiff_sendable() {
        let d = ReloadDiff(added: ["a"], removed: ["b"], unchanged: ["c"], total: 3)
        let _: any Sendable = d
        XCTAssertEqual(d.added, ["a"])
        XCTAssertEqual(d.removed, ["b"])
        XCTAssertEqual(d.unchanged, ["c"])
        XCTAssertEqual(d.total, 3)
    }
}
