//
//  SkillMetaTests.swift · Wenshu · v0.23 ticket 013.008 (hermes gap 5)
//
//  Boss 2026-08-23 拍: hermes SkillMeta trust_level parity.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("SkillMeta (hermes trust_level + source parity)")
struct SkillMetaTests {

    // MARK: - SkillTrustLevel cases

    @Test("SkillTrustLevel has 3 cases (builtin / trusted / community)")
    func testTrustLevelCases() {
        #expect(SkillTrustLevel.allCases.count == 3)
        #expect(SkillTrustLevel.builtin.rawValue == "builtin")
        #expect(SkillTrustLevel.trusted.rawValue == "trusted")
        #expect(SkillTrustLevel.community.rawValue == "community")
    }

    @Test("SkillSource has 3 cases (builtin / github / local)")
    func testSourceCases() {
        #expect(SkillSource.builtin.rawValue == "builtin")
        #expect(SkillSource.github.rawValue == "github")
        #expect(SkillSource.local.rawValue == "local")
    }

    // MARK: - SkillTrustPolicy

    @Test("builtin skill always allowed (no user approval needed)")
    func testBuiltinAlwaysAllowed() {
        let skill = SkillMeta(
            name: "wenshu-builtin-memory",
            description: "Built-in memory skill",
            source: .builtin,
            trustLevel: .builtin,
            path: "/wenshu/skills/memory.md"
        )
        #expect(SkillTrustPolicy.shouldAllow(skill: skill) == true)
    }

    @Test("trusted skill always allowed (boss pre-approved)")
    func testTrustedAlwaysAllowed() {
        let skill = SkillMeta(
            name: "wenshu-trusted-wuxia-style",
            description: "Wuxia style writer",
            source: .github,
            trustLevel: .trusted,
            path: "/skills/wuxia.md"
        )
        #expect(SkillTrustPolicy.shouldAllow(skill: skill) == true)
    }

    @Test("community skill blocked by default (no user approval)")
    func testCommunityBlockedByDefault() {
        let skill = SkillMeta(
            name: "user-installed-custom",
            description: "Custom community skill",
            source: .github,
            trustLevel: .community,
            path: "/skills/custom.md"
        )
        #expect(SkillTrustPolicy.shouldAllow(skill: skill) == false)
    }

    @Test("community skill allowed when user explicitly approved")
    func testCommunityAllowedWithUserApproval() {
        let skill = SkillMeta(
            name: "user-installed-custom",
            description: "Custom community skill",
            source: .github,
            trustLevel: .community,
            path: "/skills/custom.md"
        )
        let approved: Set<String> = ["user-installed-custom"]
        #expect(SkillTrustPolicy.shouldAllow(skill: skill, userApprovedCommunity: approved) == true)
    }

    @Test("community skill blocked when user approved different skill")
    func testCommunityBlockedForDifferentApproval() {
        let skill = SkillMeta(
            name: "user-installed-A",
            description: "Skill A",
            source: .github,
            trustLevel: .community,
            path: "/skills/A.md"
        )
        let approved: Set<String> = ["user-installed-B"]  // B is approved, not A
        #expect(SkillTrustPolicy.shouldAllow(skill: skill, userApprovedCommunity: approved) == false)
    }

    // MARK: - SkillQuarantine path

    @Test("SkillQuarantine.quarantinePath is under ~/.hermes/wenshu/skills/quarantine/")
    func testQuarantinePath() {
        #expect(SkillQuarantine.quarantinePath.contains(".hermes/wenshu/skills/quarantine"))
    }

    @Test("SkillQuarantine: quarantine then promote round-trip")
    func testQuarantineThenPromote() throws {
        let fm = FileManager.default
        let tmp = NSTemporaryDirectory() + "wenshu-skill-test-\(UUID().uuidString)"
        try fm.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let skillPath = tmp + "/test-skill.md"
        try "test content".write(toFile: skillPath, atomically: true, encoding: .utf8)

        // Quarantine: move to ~/.hermes/.../quarantine/
        let qPath = try SkillQuarantine.quarantineSkill(skillPath: skillPath)
        #expect(fm.fileExists(atPath: qPath))
        #expect(!fm.fileExists(atPath: skillPath))

        // Promote: move from quarantine to installed
        let installedDir = tmp + "/installed"
        let finalPath = try SkillQuarantine.promoteSkill(quarantinedPath: qPath, installedDir: installedDir)
        #expect(fm.fileExists(atPath: finalPath))
        #expect(!fm.fileExists(atPath: qPath))

        // Cleanup
        try? fm.removeItem(atPath: installedDir)
    }

    // MARK: - SkillMeta Equatable

    @Test("SkillMeta Equatable (hermes metadata parity)")
    func testEquatable() {
        let fixedDate = Date(timeIntervalSince1970: 1000)
        let a = SkillMeta(name: "x", description: "y", source: .builtin, trustLevel: .builtin, path: "/p", installedAt: fixedDate)
        let b = SkillMeta(name: "x", description: "y", source: .builtin, trustLevel: .builtin, path: "/p", installedAt: fixedDate)
        #expect(a == b)
        let c = SkillMeta(name: "x", description: "y", source: .github, trustLevel: .trusted, path: "/p", installedAt: fixedDate)
        #expect(a != c)
    }
}