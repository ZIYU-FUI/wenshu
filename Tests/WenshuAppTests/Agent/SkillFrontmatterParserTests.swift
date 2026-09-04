//
//  SkillFrontmatterParserTests.swift · Wenshu · HERMES-PARTIAL-016 (2026-09-04)
//
//  Round-trip tests for the dedicated SkillFrontmatterParser surface
//  (= hermes skill_preprocessing.py = 144 LOC):
//    1. testTemplateVarsSubstitution     — ${HERMES_SKILL_DIR} replaced
//    2. testTemplateVarsUnresolved       — unresolved left as-is
//    3. testPreprocessSkillContentDefault — config-driven pipeline
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SkillFrontmatterParser (HERMES-PARTIAL-016)")
struct SkillFrontmatterParserTests {

    // MARK: - Test 1: Template substitution

    @Test("substituteTemplateVars replaces ${HERMES_SKILL_DIR}")
    func testTemplateVarsSubstitution() {
        let content = "Skill lives at ${HERMES_SKILL_DIR}"
        let out = SkillFrontmatterParser.substituteTemplateVars(
            content,
            skillDir: "/tmp/skills/foo"
        )
        #expect(out.contains("/tmp/skills/foo"))
        #expect(!out.contains("${HERMES_SKILL_DIR}"))
    }

    // MARK: - Test 2: Unresolved tokens

    @Test("substituteTemplateVars leaves unresolved tokens in place")
    func testTemplateVarsUnresolved() {
        let content = "Skill: ${HERMES_SKILL_DIR}, session: ${HERMES_SESSION_ID}"
        let out = SkillFrontmatterParser.substituteTemplateVars(
            content,
            skillDir: "/x",
            sessionId: nil  // unresolved
        )
        #expect(out.contains("/x"))
        #expect(out.contains("${HERMES_SESSION_ID}"))  // unresolved → left as-is
    }

    // MARK: - Test 3: preprocessSkillContent pipeline

    @Test("preprocessSkillContent applies template vars per SkillsConfig")
    func testPreprocessSkillContentDefault() {
        let content = "Hello ${HERMES_SKILL_DIR}"
        let out = SkillFrontmatterParser.preprocessSkillContent(
            content,
            skillDir: "/skills/bar",
            skillsCfg: .default
        )
        #expect(out.contains("/skills/bar"))
    }

    // MARK: - Test 4: SkillsConfig from dict

    @Test("SkillsConfig(fromDict:) parses a YAML-like dict")
    func testSkillsConfigFromDict() {
        let cfg = SkillFrontmatterParser.SkillsConfig(fromDict: [
            "template_vars": false,
            "inline_shell": true,
            "inline_shell_timeout": 30
        ])
        #expect(cfg.templateVars == false)
        #expect(cfg.inlineShell == true)
        #expect(cfg.inlineShellTimeout == 30)
    }
}