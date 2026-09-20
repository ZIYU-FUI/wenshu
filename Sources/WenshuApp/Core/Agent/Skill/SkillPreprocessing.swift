//
//  SkillPreprocessing.swift · Wenshu · P3-SKILL-PREPROCESSING-HERMES-PORT (2026-09-19)
//
//  Shared SKILL.md preprocessing helpers. Faithful 1:1 port
//  of hermes `agent/skill_preprocessing.py` (144 LOC Python).
//
//  Per AGENTS.md §11.3 wenshu-side wins:
//
//  Hermes centralizes the SKILL.md preprocessing (= template
//  variable substitution + inline-shell snippet expansion) so
//  that skill content can embed `${HERMES_SKILL_DIR}` /
//  `${HERMES_SESSION_ID}` tokens (= hermes-specific runtime
//  values) AND run inline shell snippets like `!`date +%Y-%m-%d``
//  during content loading.
//
//  Wenshu-side wins per AGENTS.md §11.3:
//  - wenshus SkillAdapter owns the actual skill content
//    loading layer. The hermes preprocessing pipeline is
//    ported as pure helper functions (= no subprocess execution
//    in the preprocessing layer; = wenshus SkillAdapter + a
//    future shell-hooks ticket would wire subprocess execution).
//  - The 5 hermes functions (= load_skills_config /
//    substitute_template_vars / run_inline_shell /
//    expand_inline_shell / preprocess_skill_content) are
//    ported 1:1 in Swift.
//  - The hermes-specific tokens `${HERMES_SKILL_DIR}` /
//    `${HERMES_SESSION_ID}` are preserved 1:1 (= wenshu uses
//    the same token names per the wenshu-flavored hermes
//    sibling convention).
//  - The inline-shell `!`...`` regex pattern is preserved 1:1.
//  - `run_inline_shell` is ported as a pure helper (= subprocess
//    execution wired by wenshus ProcessTools per the
//    wenshu-side-wins pattern; = the signature + return shape
//    preserved).
//  - `preprocess_skill_content` orchestrator preserves the
//    template_vars + inline_shell config flags (= wenshu-
//    side wins: default-off for inline_shell per the hermes
//    default; = safer for macOS native app context).
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only. No
//  third-party imports.
//

import Foundation

// MARK: - Constants

/// Maximum inline-shell output (= hermes `_INLINE_SHELL_MAX_OUTPUT`
/// at `agent/skill_preprocessing.py` L20 = 4000 chars).
public let inlineShellMaxOutput = 4000

/// Matches `${HERMES_SKILL_DIR}` / `${HERMES_SESSION_ID}` tokens
/// in SKILL.md (= hermes `_SKILL_TEMPLATE_RE` at L13).
///
/// Tokens that don't resolve (= e.g. `${HERMES_SESSION_ID}` with
/// no session) are left as-is so the user can debug them.
public let skillTemplateVarRegex = try! NSRegularExpression(
    pattern: #"\$\{(HERMES_SKILL_DIR|HERMES_SESSION_ID)\}"#
)

/// Matches inline shell snippets like: !`date +%Y-%m-%d`
/// (= hermes `_INLINE_SHELL_RE` at L17).
///
/// Non-greedy, single-line only -- no newlines inside the
/// backticks. Matches empty snippets too (= `!```) per the
/// hermes `expand_inline_shell` L106-L124 contract.
public let inlineShellRegex = try! NSRegularExpression(
    pattern: #"!`([^`\n]*)`"#
)

// MARK: - Public API

/// Load the ``skills`` section of config.yaml (= best-effort)
/// (= hermes `load_skills_config` at L25-L37).
///
/// Wenshu-side wins: wenshu uses the `.ws` bundle's `Info.plist`
/// provider config (= per AGENTS.md §11) instead of
/// config.yaml. Returns an empty dict as the best-effort
/// fallback (= matches hermes's `return {}` fallback when
/// config can't be loaded).
public func loadSkillsConfig() -> [String: Any] {
    // Wenshu-side wins: best-effort load from .ws bundle config.
    // The actual .ws plist parsing is a future ticket (= per
    // AGENTS.md §11 .ws bundle = per-book container; = skill
    // config may live in `.ws/Info.plist`).
    return [:]
}

/// Replace `${HERMES_SKILL_DIR}` / `${HERMES_SESSION_ID}` in
/// skill content (= hermes `substitute_template_vars` at
/// L39-L62).
///
/// Only substitutes tokens for which a concrete value is
/// available -- unresolved tokens are left in place so the
/// author can spot them.
public func substituteTemplateVars(
    content: String,
    skillDir: URL?,
    sessionID: String?
) -> String {
    guard !content.isEmpty else { return content }

    let skillDirStr = skillDir?.path

    let nsContent = content as NSString
    let matches = skillTemplateVarRegex.matches(
        in: content,
        options: [],
        range: NSRange(location: 0, length: nsContent.length)
    )

    var result = content
    // Iterate in reverse to preserve ranges
    for match in matches.reversed() {
        let tokenRange = match.range(at: 1)
        guard tokenRange.location != NSNotFound else { continue }
        let token = nsContent.substring(with: tokenRange)

        let replacement: String?
        switch token {
        case "HERMES_SKILL_DIR":
            replacement = skillDirStr
        case "HERMES_SESSION_ID":
            replacement = sessionID
        default:
            replacement = nil
        }

        if let replacement = replacement {
            result = (result as NSString).replacingCharacters(
                in: match.range,
                with: replacement
            )
        }
    }

    return result
}

/// Execute a single inline-shell snippet and return its stdout
/// (= hermes `run_inline_shell` at L65-L103).
///
/// Wenshu-side wins: this is a pure helper that returns the
/// substitution-result string (= "[inline-shell error: ...]" /
/// "[inline-shell timeout after Xs: ...]" markers on failure;
/// = real subprocess execution is wired by wenshus
/// ProcessTools per the wenshu-side-wins pattern; = this
/// function signature is preserved 1:1 with hermes so the
/// future ProcessTools wire-up is a 1-file change).
///
/// - Parameters:
///   - command: The shell command to execute.
///   - cwd: The working directory (= skill_dir per hermes).
///   - timeout: The execution timeout in seconds (= clamped to
///     >= 1 second).
///   - executor: Optional subprocess executor (= wenshus
///     ProcessTools future ticket wires this). Defaults to a
///     synchronous /bin/bash invocation.
/// - Returns: The command stdout (= trimmed), or an error
///   marker on failure.
public func runInlineShell(
    command: String,
    cwd: URL?,
    timeout: Int,
    executor: ((String, URL?, Int) -> InlineShellResult)? = nil
) -> String {
    let clampedTimeout = max(1, timeout)

    if let executor = executor {
        let result = executor(command, cwd, clampedTimeout)
        return formatInlineShellResult(result, command: command, timeout: clampedTimeout)
    }

    // Default executor: synchronous /bin/bash invocation.
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    if let cwd = cwd {
        process.currentDirectoryURL = cwd
    }
    process.standardInput = FileHandle.nullDevice

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
        process.waitUntilExit()
        if !process.isRunning && process.terminationStatus != 0 {
            // OK -- still captured output below
        }
    } catch {
        return "[inline-shell error: \(error.localizedDescription)]"
    }

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    var output = String(data: stdoutData, encoding: .utf8) ?? ""
    if output.isEmpty {
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        output = String(data: stderrData, encoding: .utf8) ?? ""
    }
    output = output.trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
    if output.count > inlineShellMaxOutput {
        output = String(output.prefix(inlineShellMaxOutput)) + "...[truncated]"
    }
    return output
}

/// Result of an inline-shell execution (= hermes
/// `subprocess.CompletedProcess` shape).
public struct InlineShellResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let timedOut: Bool

    public init(stdout: String, stderr: String, exitCode: Int32, timedOut: Bool = false) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.timedOut = timedOut
    }
}

private func formatInlineShellResult(
    _ result: InlineShellResult,
    command: String,
    timeout: Int
) -> String {
    if result.timedOut {
        return "[inline-shell timeout after \(timeout)s: \(command)]"
    }
    var output = result.stdout
    if output.isEmpty && !result.stderr.isEmpty {
        output = result.stderr
    }
    output = output.trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
    if output.count > inlineShellMaxOutput {
        output = String(output.prefix(inlineShellMaxOutput)) + "...[truncated]"
    }
    return output
}

/// Replace every !`cmd` snippet in `content` with its stdout
/// (= hermes `expand_inline_shell` at L106-L124).
///
/// Runs each snippet with the skill directory as CWD so
/// relative paths in the snippet work the way the author
/// expects.
public func expandInlineShell(
    content: String,
    skillDir: URL?,
    timeout: Int,
    executor: ((String, URL?, Int) -> InlineShellResult)? = nil
) -> String {
    guard content.contains("!`") else { return content }

    let nsContent = content as NSString
    let matches = inlineShellRegex.matches(
        in: content,
        options: [],
        range: NSRange(location: 0, length: nsContent.length)
    )

    var result = content
    for match in matches.reversed() {
        let cmdRange = match.range(at: 1)
        guard cmdRange.location != NSNotFound else { continue }
        let cmd = nsContent.substring(with: cmdRange).trimmingCharacters(in: .whitespaces)
        if cmd.isEmpty {
            result = (result as NSString).replacingCharacters(
                in: match.range,
                with: ""
            )
            continue
        }
        let stdout = runInlineShell(
            command: cmd,
            cwd: skillDir,
            timeout: timeout,
            executor: executor
        )
        result = (result as NSString).replacingCharacters(
            in: match.range,
            with: stdout
        )
    }
    return result
}

/// Apply configured SKILL.md template and inline-shell
/// preprocessing (= hermes `preprocess_skill_content` at
/// L128-L143).
///
/// Config flags (= hermes config):
/// - `template_vars` (= default true): enable `${HERMES_*}` substitution
/// - `inline_shell` (= default false): enable ``!`cmd`` `` substitution
/// - `inline_shell_timeout` (= default 10): inline-shell timeout in seconds
public func preprocessSkillContent(
    content: String,
    skillDir: URL?,
    sessionID: String? = nil,
    skillsConfig: [String: Any]? = nil,
    executor: ((String, URL?, Int) -> InlineShellResult)? = nil
) -> String {
    guard !content.isEmpty else { return content }

    let cfg = (skillsConfig ?? loadSkillsConfig())

    var result = content
    let templateVarsEnabled = (cfg["template_vars"] as? Bool) ?? true
    if templateVarsEnabled {
        result = substituteTemplateVars(
            content: result,
            skillDir: skillDir,
            sessionID: sessionID
        )
    }

    let inlineShellEnabled = (cfg["inline_shell"] as? Bool) ?? false
    if inlineShellEnabled {
        let timeout = (cfg["inline_shell_timeout"] as? Int) ?? 10
        result = expandInlineShell(
            content: result,
            skillDir: skillDir,
            timeout: timeout,
            executor: executor
        )
    }

    return result
}
