//
//  SkillPreprocessingHermesGapPortTests.swift · Wenshu · P3-SKILL-PREPROCESSING-HERMES-PORT (2026-09-19)
//
//  Verifies the new hermes port addition to
//  `Core/Agent/Skill/SkillPreprocessing.swift` (= hermes
//  `agent/skill_preprocessing.py` 144 LOC Python).
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure helper port; = no
//  real subprocess execution (= wenshu ProcessTools future
//  ticket wires it).
//

import XCTest
@testable import WenshuApp

final class SkillPreprocessingHermesGapPortTests: XCTestCase {

    // MARK: -- loadSkillsConfig tests (= hermes L25-L37)

    func testLoadSkillsConfig_returnsDict() {
        let cfg = loadSkillsConfig()
        XCTAssertNotNil(cfg)
    }

    // MARK: -- substituteTemplateVars tests (= hermes L39-L62)

    func testSubstituteTemplateVars_emptyContent_returnsEmpty() {
        XCTAssertEqual(
            substituteTemplateVars(content: "", skillDir: URL(fileURLWithPath: "/tmp"), sessionID: "s1"),
            ""
        )
    }

    func testSubstituteTemplateVars_skillDirSubstitution() {
        let result = substituteTemplateVars(
            content: "Loaded from ${HERMES_SKILL_DIR}",
            skillDir: URL(fileURLWithPath: "/tmp/skills/foo"),
            sessionID: nil
        )
        XCTAssertEqual(result, "Loaded from /tmp/skills/foo")
    }

    func testSubstituteTemplateVars_sessionIDSubstitution() {
        let result = substituteTemplateVars(
            content: "Session: ${HERMES_SESSION_ID}",
            skillDir: nil,
            sessionID: "sess_abc123"
        )
        XCTAssertEqual(result, "Session: sess_abc123")
    }

    func testSubstituteTemplateVars_unresolvedTokenLeftAsIs() {
        let result = substituteTemplateVars(
            content: "Hello ${HERMES_SESSION_ID} world",
            skillDir: nil,
            sessionID: nil
        )
        XCTAssertEqual(result, "Hello ${HERMES_SESSION_ID} world")
    }

    func testSubstituteTemplateVars_bothTokens() {
        let result = substituteTemplateVars(
            content: "${HERMES_SKILL_DIR}/${HERMES_SESSION_ID}",
            skillDir: URL(fileURLWithPath: "/skills"),
            sessionID: "s1"
        )
        XCTAssertEqual(result, "/skills/s1")
    }

    func testSubstituteTemplateVars_noTokens_returnsUnchanged() {
        let result = substituteTemplateVars(
            content: "Plain text",
            skillDir: URL(fileURLWithPath: "/tmp"),
            sessionID: "s1"
        )
        XCTAssertEqual(result, "Plain text")
    }

    func testSubstituteTemplateVars_multipleOccurrencesOfSameToken() {
        let result = substituteTemplateVars(
            content: "${HERMES_SKILL_DIR}/a and ${HERMES_SKILL_DIR}/b",
            skillDir: URL(fileURLWithPath: "/skills"),
            sessionID: nil
        )
        XCTAssertEqual(result, "/skills/a and /skills/b")
    }

    // MARK: -- runInlineShell tests (= hermes L65-L103)

    func testRunInlineShell_successfulEcho() {
        let result = runInlineShell(
            command: "echo hello",
            cwd: nil,
            timeout: 5
        )
        XCTAssertEqual(result, "hello")
    }

    func testRunInlineShell_trimsTrailingNewlines() {
        let result = runInlineShell(
            command: "echo hello",
            cwd: nil,
            timeout: 5
        )
        XCTAssertFalse(result.hasSuffix("\n"))
    }

    func testRunInlineShell_truncatesLongOutput() {
        // Generate > 4000 chars of output
        let result = runInlineShell(
            command: "python3 -c \"print('a' * 5000)\"",
            cwd: nil,
            timeout: 10
        )
        XCTAssertTrue(result.count <= inlineShellMaxOutput + 20) // +20 for the truncation marker
        if result.count > inlineShellMaxOutput {
            XCTAssertTrue(result.contains("...[truncated]"))
        }
    }

    func testRunInlineShell_stderrWhenStdoutEmpty() {
        let result = runInlineShell(
            command: "echo error >&2",
            cwd: nil,
            timeout: 5
        )
        XCTAssertEqual(result, "error")
    }

    func testRunInlineShell_failedCommandReturnsEmpty() {
        // bash exits non-zero but still returns stdout. An
        // empty command results in an error message.
        let result = runInlineShell(
            command: "false",
            cwd: nil,
            timeout: 5
        )
        // 'false' returns no output but exits 1
        XCTAssertEqual(result, "")
    }

    func testRunInlineShell_executorOverrideSuccess() {
        let executor: (String, URL?, Int) -> InlineShellResult = { _, _, _ in
            InlineShellResult(stdout: "mocked", stderr: "", exitCode: 0)
        }
        let result = runInlineShell(command: "anything", cwd: nil, timeout: 5, executor: executor)
        XCTAssertEqual(result, "mocked")
    }

    func testRunInlineShell_executorOverrideTimedOut() {
        let executor: (String, URL?, Int) -> InlineShellResult = { _, _, _ in
            InlineShellResult(stdout: "", stderr: "", exitCode: -1, timedOut: true)
        }
        let result = runInlineShell(command: "anything", cwd: nil, timeout: 5, executor: executor)
        XCTAssertTrue(result.contains("[inline-shell timeout after 5s"))
    }

    func testRunInlineShell_executorOverrideStderrFallback() {
        let executor: (String, URL?, Int) -> InlineShellResult = { _, _, _ in
            InlineShellResult(stdout: "", stderr: "fallback error", exitCode: 1)
        }
        let result = runInlineShell(command: "anything", cwd: nil, timeout: 5, executor: executor)
        XCTAssertEqual(result, "fallback error")
    }

    func testRunInlineShell_executorOverrideTruncates() {
        let executor: (String, URL?, Int) -> InlineShellResult = { _, _, _ in
            InlineShellResult(stdout: String(repeating: "x", count: 5000), stderr: "", exitCode: 0)
        }
        let result = runInlineShell(command: "anything", cwd: nil, timeout: 5, executor: executor)
        XCTAssertTrue(result.count <= inlineShellMaxOutput + 20)
    }

    func testRunInlineShell_timeoutClampedToMinimum1() {
        // timeout=0 should be clamped to >=1 (= hermes behavior).
        let executor: (String, URL?, Int) -> InlineShellResult = { cmd, _, timeout in
            InlineShellResult(stdout: "got timeout=\(timeout)", stderr: "", exitCode: 0)
        }
        let result = runInlineShell(command: "echo", cwd: nil, timeout: 0, executor: executor)
        XCTAssertTrue(result.contains("timeout=1"))
    }

    // MARK: -- expandInlineShell tests (= hermes L106-L124)

    func testExpandInlineShell_noSnippets_returnsUnchanged() {
        let result = expandInlineShell(
            content: "Plain text",
            skillDir: nil,
            timeout: 5
        )
        XCTAssertEqual(result, "Plain text")
    }

    func testExpandInlineShell_emptySnippetReplacedWithEmpty() {
        let executor: (String, URL?, Int) -> InlineShellResult = { cmd, _, _ in
            InlineShellResult(stdout: "[\(cmd)]", stderr: "", exitCode: 0)
        }
        let result = expandInlineShell(
            content: "Before `` after",
            skillDir: nil,
            timeout: 5,
            executor: executor
        )
        XCTAssertEqual(result, "Before  after")
    }

    func testExpandInlineShell_replacesSnippetWithOutput() {
        let executor: (String, URL?, Int) -> InlineShellResult = { cmd, _, _ in
            InlineShellResult(stdout: "[\(cmd)]", stderr: "", exitCode: 0)
        }
        let result = expandInlineShell(
            content: "Date is !`date +%Y`",
            skillDir: nil,
            timeout: 5,
            executor: executor
        )
        XCTAssertEqual(result, "Date is [date +%Y]")
    }

    func testExpandInlineShell_multipleSnippets() {
        let executor: (String, URL?, Int) -> InlineShellResult = { cmd, _, _ in
            InlineShellResult(stdout: "[\(cmd)]", stderr: "", exitCode: 0)
        }
        let result = expandInlineShell(
            content: "A !`echo 1` B !`echo 2` C",
            skillDir: nil,
            timeout: 5,
            executor: executor
        )
        XCTAssertEqual(result, "A [echo 1] B [echo 2] C")
    }

    // MARK: -- preprocessSkillContent tests (= hermes L128-L143)

    func testPreprocessSkillContent_emptyContent() {
        XCTAssertEqual(
            preprocessSkillContent(content: "", skillDir: nil),
            ""
        )
    }

    func testPreprocessSkillContent_defaultTemplateVarsEnabled() {
        let result = preprocessSkillContent(
            content: "Session: ${HERMES_SESSION_ID}",
            skillDir: nil,
            sessionID: "sess_1"
        )
        XCTAssertEqual(result, "Session: sess_1")
    }

    func testPreprocessSkillContent_defaultInlineShellDisabled() {
        let result = preprocessSkillContent(
            content: "Date is !`date`",
            skillDir: nil,
            sessionID: nil
        )
        XCTAssertEqual(result, "Date is !`date`") // unchanged
    }

    func testPreprocessSkillContent_explicitConfigOverrides() {
        let cfg: [String: Any] = [
            "template_vars": false,
            "inline_shell": false,
        ]
        let result = preprocessSkillContent(
            content: "Session: ${HERMES_SESSION_ID}",
            skillDir: nil,
            sessionID: "sess_1",
            skillsConfig: cfg
        )
        XCTAssertEqual(result, "Session: ${HERMES_SESSION_ID}") // unchanged
    }

    func testPreprocessSkillContent_inlineShellEnabled() {
        let cfg: [String: Any] = [
            "template_vars": false,
            "inline_shell": true,
        ]
        let executor: (String, URL?, Int) -> InlineShellResult = { cmd, _, _ in
            InlineShellResult(stdout: "[\(cmd)]", stderr: "", exitCode: 0)
        }
        let result = preprocessSkillContent(
            content: "Date: !`date`",
            skillDir: nil,
            sessionID: nil,
            skillsConfig: cfg,
            executor: executor
        )
        XCTAssertEqual(result, "Date: [date]")
    }

    func testPreprocessSkillContent_combinedPreprocessing() {
        let cfg: [String: Any] = [
            "template_vars": true,
            "inline_shell": true,
            "inline_shell_timeout": 5,
        ]
        let executor: (String, URL?, Int) -> InlineShellResult = { cmd, _, _ in
            InlineShellResult(stdout: "[\(cmd)]", stderr: "", exitCode: 0)
        }
        let result = preprocessSkillContent(
            content: "Dir: ${HERMES_SKILL_DIR}, Cmd: !`echo hi`",
            skillDir: URL(fileURLWithPath: "/skills"),
            sessionID: "sess_1",
            skillsConfig: cfg,
            executor: executor
        )
        XCTAssertEqual(result, "Dir: /skills, Cmd: [echo hi]")
    }

    // MARK: -- Constants tests

    func testInlineShellMaxOutput_matchesHermes() {
        XCTAssertEqual(inlineShellMaxOutput, 4000)
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        // v1.57 stale-helper: per wenshu-stale-test-cleanup Class A recipe.
        guard let source = HermesGapPortTestHelpers.readSource(
            relativeToTest: #filePath,
            sourceFileName: "SkillPreprocessing.swift"
        ) else {
            XCTFail("HermesGapPortTestHelpers could not locate SkillPreprocessing.swift")
            return
        }
        XCTAssertTrue(source.contains("P3-SKILL-PREPROCESSING-HERMES-PORT"))
        XCTAssertTrue(source.contains("agent/skill_preprocessing.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("substituteTemplateVars"))
        XCTAssertTrue(source.contains("runInlineShell"))
        XCTAssertTrue(source.contains("expandInlineShell"))
        XCTAssertTrue(source.contains("preprocessSkillContent"))
    }
}
