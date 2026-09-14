// SkillBundlesYAMLDiscoveryTests.swift · Wenshu · v0.75 ticket 001
//
// Tests cover:
// - parseYAMLString handles valid file shape (id + name + skill_ids + dependencies)
// - parseYAMLString rejects missing required fields (id, name)
// - parseYAMLString rejects unknown top-level keys
// - parseYAMLString handles comments + blank lines
// - discover(into:from:) returns 0 when directory doesn't exist
//   (= first-launch UX; = don't error)
// - discover(into:from:) registers parsed bundles from YAML files

import Foundation
import Testing
@testable import WenshuApp

@Suite("SkillBundlesYAMLDiscovery (v0.75 ticket 001 — YAML discovery for SkillBundles)")
struct SkillBundlesYAMLDiscoveryTests {

    // MARK: - parseYAMLString

    @Test("parses valid YAML with all fields")
    func parseValid() throws {
        let yaml = """
        # This is a comment
        id: alpha
        name: Alpha Bundle

        skill_ids:
          - code-review
          - refactor

        dependencies:
          - core-libs
        """
        let parsed = try SkillBundlesYAMLDiscovery.parseYAMLString(yaml)
        #expect(parsed.id == "alpha")
        #expect(parsed.name == "Alpha Bundle")
        #expect(parsed.skillIDs == ["code-review", "refactor"])
        #expect(parsed.dependencies == ["core-libs"])
    }

    @Test("parses minimal YAML (id + name only, no arrays)")
    func parseMinimal() throws {
        let yaml = """
        id: minimal
        name: Minimal Bundle
        """
        let parsed = try SkillBundlesYAMLDiscovery.parseYAMLString(yaml)
        #expect(parsed.id == "minimal")
        #expect(parsed.name == "Minimal Bundle")
        #expect(parsed.skillIDs.isEmpty)
        #expect(parsed.dependencies.isEmpty)
    }

    @Test("rejects missing id field")
    func rejectMissingID() {
        let yaml = """
        name: No ID
        """
        #expect(throws: SkillBundlesYAMLDiscoveryError.self) {
            _ = try SkillBundlesYAMLDiscovery.parseYAMLString(yaml)
        }
    }

    @Test("rejects missing name field")
    func rejectMissingName() {
        let yaml = """
        id: no-name
        """
        #expect(throws: SkillBundlesYAMLDiscoveryError.self) {
            _ = try SkillBundlesYAMLDiscovery.parseYAMLString(yaml)
        }
    }

    @Test("rejects unknown top-level key")
    func rejectUnknownKey() {
        let yaml = """
        id: x
        name: X
        unknown_key: oops
        """
        #expect(throws: SkillBundlesYAMLDiscoveryError.self) {
            _ = try SkillBundlesYAMLDiscovery.parseYAMLString(yaml)
        }
    }

    @Test("rejects array item outside array context")
    func rejectOrphanArrayItem() {
        let yaml = """
        id: x
        - orphan
        """
        #expect(throws: SkillBundlesYAMLDiscoveryError.self) {
            _ = try SkillBundlesYAMLDiscovery.parseYAMLString(yaml)
        }
    }

    @Test("ignores comments and blank lines")
    func ignoreCommentsAndBlankLines() throws {
        let yaml = """

        # top-level comment
        id: with-comments

        # comment between fields
        name: With Comments

        # comment before array
        skill_ids:
          # comment in array
          - skill-a
          - skill-b
        """
        let parsed = try SkillBundlesYAMLDiscovery.parseYAMLString(yaml)
        #expect(parsed.id == "with-comments")
        #expect(parsed.name == "With Comments")
        #expect(parsed.skillIDs == ["skill-a", "skill-b"])
    }

    // MARK: - discover

    @Test("discover returns 0 when directory doesn't exist (= first-launch UX)")
    func discoverMissingDirectory() async throws {
        let bogus = URL(fileURLWithPath: "/tmp/wenshu-skillbundles-nonexistent-\(UUID().uuidString)")
        let bundles = SkillBundles()
        let count = await SkillBundlesYAMLDiscovery.discover(into: bundles, from: bogus)
        #expect(count == 0)
    }

    @Test("discover registers parsed bundles from YAML files")
    func discoverRegistersBundles() async throws {
        // Create a temp directory with 2 YAML files
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-skillbundles-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let yaml1 = """
        id: bundle-one
        name: Bundle One
        skill_ids:
          - skill-a
        """
        let yaml2 = """
        id: bundle-two
        name: Bundle Two
        skill_ids:
          - skill-b
          - skill-c
        dependencies:
          - bundle-one
        """
        try yaml1.write(to: tmp.appendingPathComponent("one.yaml"), atomically: true, encoding: .utf8)
        try yaml2.write(to: tmp.appendingPathComponent("two.yaml"), atomically: true, encoding: .utf8)

        let bundles = SkillBundles()
        let count = await SkillBundlesYAMLDiscovery.discover(into: bundles, from: tmp)
        #expect(count == 2)

        // Verify both bundles are registered + resolve correctly
        let resolved = try await bundles.resolve(bundleID: "bundle-two")
        #expect(resolved.contains("skill-b"))
        #expect(resolved.contains("skill-c"))
        #expect(resolved.contains("skill-a"))  // via bundle-one dependency
    }

    @Test("discover continues past malformed YAML (= Q34: log + continue)")
    func discoverContinuesPastMalformed() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-skillbundles-malformed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let good = """
        id: good
        name: Good Bundle
        """
        let bad = """
        unknown_key: this will fail
        """
        try good.write(to: tmp.appendingPathComponent("good.yaml"), atomically: true, encoding: .utf8)
        try bad.write(to: tmp.appendingPathComponent("bad.yaml"), atomically: true, encoding: .utf8)

        let bundles = SkillBundles()
        let count = await SkillBundlesYAMLDiscovery.discover(into: bundles, from: tmp)
        // 1 successful + 1 malformed (= reported to stderr but not counted)
        #expect(count == 1)
        #expect(await bundles.bundle(id: "good") != nil)
    }

    // MARK: - defaultDirectory

    @Test("defaultDirectory returns Application Support path on macOS")
    func defaultDirectoryUsesAppSupport() {
        let url = SkillBundlesYAMLDiscovery.defaultDirectory()
        // Path should contain 'wenshu/skill-bundles'
        #expect(url.path.contains("wenshu"))
        #expect(url.path.contains("skill-bundles"))
    }
}