//
//  SkillFrontmatterParser.swift · Wenshu · HERMES-PARTIAL-016 (2026-09-04)
//
//  Dedicated SKILL.md frontmatter parser extracted from SkillMeta.swift.
//  Direct port of hermes agent/skill_preprocessing.py (= 144 LOC;
//  provides load_skills_config + substitute_template_vars +
//  expand_inline_shell + preprocess_skill_content).
//
//  Per HERMES-PARTIAL-016: the frontmatter parsing surface is currently
//  inlined into SkillMeta.swift (= parseFrontmatter + splitFrontmatter +
//  parse(skillMDContent:)). This file extracts that surface into a
//  dedicated module so the SkillMeta.swift API stays focused on the
//  SkillMeta struct itself, and the parser + template substitution +
//  inline-shell expansion land here.
//
//  Four public surfaces (= hermes skill_preprocessing.py surface):
//    1. SkillsConfig
//       Per-skill config bag (= hermes load_skills_config). Holds:
//       templateVars (= default true), inlineShell (= default false,
//         gated), inlineShellTimeout (= default 10s).
//    2. substituteTemplateVars(_:skillDir:sessionId:)
//       Replace ${HERMES_SKILL_DIR} / ${HERMES_SESSION_ID} tokens in
//       skill content (= hermes substitute_template_vars L39-62).
//       Unresolved tokens are left in place so the author can spot them.
//    3. expandInlineShell(_:skillDir:timeout:)
//       Replace !`cmd` snippets with their stdout (= hermes
//       expand_inline_shell L106-125). Each snippet runs with the skill
//       directory as CWD so relative paths work as the author expects.
//       Output is capped at 4000 chars per snippet (= hermes
//       _INLINE_SHELL_MAX_OUTPUT).
//    4. preprocessSkillContent(_:skillDir:sessionId:skillsCfg:)
//       Apply template-var substitution + inline-shell expansion per
//       the configured skills section (= hermes preprocess_skill_content
//       L128-144).
//
//  v0.28 M6-19 refactor + HERMES-PARTIAL-016 (2026-09-04).
//

import Foundation

public enum SkillFrontmatterParser {

    // MARK: - Skills config (= hermes load_skills_config L25-36)

    public struct SkillsConfig: Sendable, Equatable {
        public var templateVars: Bool
        public var inlineShell: Bool
        public var inlineShellTimeout: Int

        public init(
            templateVars: Bool = true,
            inlineShell: Bool = false,
            inlineShellTimeout: Int = 10
        ) {
            self.templateVars = templateVars
            self.inlineShell = inlineShell
            self.inlineShellTimeout = inlineShellTimeout
        }

        /// Default config (= hermes load_skills_config fallback when
        /// config.yaml has no `skills` section).
        public static let `default` = SkillsConfig()

        /// Load from a YAML-like dictionary (= hermes load_skills_config
        /// reads `cfg.get('skills')` and treats the result as a dict).
        public init(fromDict dict: [String: Any]?) {
            self.templateVars = (dict?["template_vars"] as? Bool) ?? true
            self.inlineShell = (dict?["inline_shell"] as? Bool) ?? false
            self.inlineShellTimeout = (dict?["inline_shell_timeout"] as? Int) ?? 10
        }
    }

    // MARK: - Template var substitution (= hermes substitute_template_vars)

    /// Replace ${HERMES_SKILL_DIR} / ${HERMES_SESSION_ID} tokens in skill
    /// content. Only substitutes tokens for which a concrete value is
    /// available; unresolved tokens are left in place so the author
    /// can spot them.
    public static func substituteTemplateVars(
        _ content: String,
        skillDir: String? = nil,
        sessionId: String? = nil
    ) -> String {
        guard !content.isEmpty else { return content }
        var out = content
        if let dir = skillDir {
            out = out.replacingOccurrences(
                of: "${HERMES_SKILL_DIR}",
                with: dir
            )
        }
        if let sid = sessionId {
            out = out.replacingOccurrences(
                of: "${HERMES_SESSION_ID}",
                with: sid
            )
        }
        return out
    }

    // MARK: - Inline shell expansion (= hermes expand_inline_shell)

    private static let inlineShellPattern = try! NSRegularExpression(
        pattern: #"!`([^`\n]+)`"#,
        options: []
    )

    /// Replace every !`cmd` snippet in `content` with its stdout.
    /// Runs each snippet with the skill directory as CWD so relative
    /// paths in the snippet work the way the author expects.
    public static func expandInlineShell(
        _ content: String,
        skillDir: String? = nil,
        timeout: Int = 10
    ) -> String {
        guard content.contains("!`") else { return content }
        let ns = content as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = inlineShellPattern.matches(in: content, options: [], range: range)
        var out = content
        // Replace from the end to keep indices stable.
        for m in matches.reversed() {
            guard m.numberOfRanges >= 2 else { continue }
            let cmdRange = m.range(at: 1)
            let fullRange = m.range(at: 0)
            let cmd = ns.substring(with: cmdRange).trimmingCharacters(in: .whitespaces)
            if cmd.isEmpty {
                continue
            }
            let result = runInlineShell(command: cmd, cwd: skillDir, timeout: timeout)
            let fullNSRange = NSRange(fullRange.location, length: fullRange.length)
            if let swiftRange = Range(fullNSRange, in: out) {
                out.replaceSubrange(swiftRange, with: result)
            }
        }
        return out
    }

    /// Execute a single inline-shell snippet and return its stdout.
    /// Failures return a short `[inline-shell error: ...]` marker
    /// instead of raising, so one bad snippet can't wreck the whole
    /// skill message.
    private static func runInlineShell(command: String, cwd: String?, timeout: Int) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        if let cwd = cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return "[inline-shell error: \(error.localizedDescription)]"
        }

        // Cap at timeout seconds.
        let timeoutSeconds = max(1, timeout)
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return "[inline-shell timeout after \(timeout)s: \(command)]"
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        var output = String(data: stdoutData, encoding: .utf8) ?? ""
        if output.isEmpty, let stderrStr = String(data: stderrData, encoding: .utf8) {
            output = stderrStr
        }
        // Trim trailing newlines (= hermes .rstrip("\n")).
        while output.hasSuffix("\n") {
            output.removeLast()
        }
        // Cap at 4000 chars (= hermes _INLINE_SHELL_MAX_OUTPUT).
        if output.count > 4000 {
            output = String(output.prefix(4000)) + "...[truncated]"
        }
        return output
    }

    // MARK: - Combined preprocessor (= hermes preprocess_skill_content)

    /// Apply configured SKILL.md template + inline-shell preprocessing.
    public static func preprocessSkillContent(
        _ content: String,
        skillDir: String? = nil,
        sessionId: String? = nil,
        skillsCfg: SkillsConfig = .default
    ) -> String {
        guard !content.isEmpty else { return content }
        var out = content
        if skillsCfg.templateVars {
            out = substituteTemplateVars(out, skillDir: skillDir, sessionId: sessionId)
        }
        if skillsCfg.inlineShell {
            out = expandInlineShell(
                out,
                skillDir: skillDir,
                timeout: skillsCfg.inlineShellTimeout
            )
        }
        return out
    }
}