// PromptBuilder.swift Dynamic-tier system-prompt composition. Direct port of hermes
// … (= 50 rationale lines collapsed; = A112 docblock collapse per §1.8)
// from the 2026-09-04 gap audit; unblocks GAP-009 conversation_loop wiring).
import Foundation
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "promptbuilder")

// MARK: - Public types
// … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / on subsequent calls within the same session).
public struct PromptBuilder: Sendable {
    public let stableTier: String
    public let dynamicTier: String

    /// Build a PromptBuilder from explicit tiers (= the canonical
    /// construction path used by ConversationLoop + SystemPrompt).
    public init(stableTier: String, dynamicTier: String) {
        self.stableTier = stableTier
        self.dynamicTier = dynamicTier
    }

    // / Convenience init: compose the dynamic tier from the live
    // … (= 29 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     section in the dynamic tier when non-empty).
    public init(
        systemPrompt: SystemPrompt.Type = SystemPrompt.self,
        contextBundle: ContextEngine.ContextBundle,
        memories: [MemoryAdapter.MemoryEntry],
        callerExtras: [String: String] = [:],
        ephemeralHint: String = ""
    ) {
        _ = systemPrompt  // accepted for API symmetry; tier comes from SystemPrompt.stableTier()
        let stable = SystemPrompt.stableTier()
        let dynamic = Self.composeDynamicTier(
            contextBundle: contextBundle,
            memories: memories,
            callerExtras: callerExtras,
            ephemeralHint: ephemeralHint
        )
        self.init(stableTier: stable, dynamicTier: dynamic)
    }

    /// Stable tier only (= for tests / callers that want just the prefix).
    public static func stableTierOnly() -> String {
        SystemPrompt.stableTier()
    }

    /// Dynamic tier only (= for tests / callers that want just the suffix).
    public static func dynamicTier(
        contextBundle: ContextEngine.ContextBundle,
        memories: [MemoryAdapter.MemoryEntry],
        callerExtras: [String: String] = [:],
        ephemeralHint: String = ""
    ) -> String {
        composeDynamicTier(
            contextBundle: contextBundle,
            memories: memories,
            callerExtras: callerExtras,
            ephemeralHint: ephemeralHint
        )
    }

    // MARK: - Per-provider system builders
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / RequestHelpers can splice directly into the request body).
    public func buildAnthropicSystem() -> [[String: Any]] {
        var blocks: [[String: Any]] = []

        if !stableTier.isEmpty {
            blocks.append([
                "type": "text",
                "text": stableTier,
                "cache_control": ["type": "ephemeral"]
            ])
        }

        if !dynamicTier.isEmpty {
            // No cache_control on the dynamic tier (= hermes pattern: the dynamic tier
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // system messages, NOT on the system field itself).
            blocks.append([
                "type": "text",
                "text": dynamicTier
            ])
        }

        return blocks
    }

    // / Build the OpenAI Chat-Completions API system field.
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / for direct splice into the OpenAI messages list.
    public func buildOpenAISystem() -> [String: Any] {
        var sections: [String] = []
        if !stableTier.isEmpty {
            sections.append(stableTier)
        }
        if !dynamicTier.isEmpty {
            sections.append(dynamicTier)
        }
        let joined = sections.joined(separator: "\n\n---\n\n")
        return [
            "role": "system",
            "content": joined
        ]
    }

    // / Build the Gemini native `systemInstruction.parts[].text` field.
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / OpenAI for parity.
    public func buildGeminiSystemInstruction() -> String {
        var sections: [String] = []
        if !stableTier.isEmpty {
            sections.append(stableTier)
        }
        if !dynamicTier.isEmpty {
            sections.append(dynamicTier)
        }
        return sections.joined(separator: "\n\n---\n\n")
    }

    /// Byte-stable joined prompt (= back-compat with
    /// `SystemPrompt.build` callers; same separator as OpenAI/Gemini).
    public var joinedPrompt: String {
        buildGeminiSystemInstruction()
    }
}

// MARK: - Dynamic-tier composition (private)

extension PromptBuilder {
    // / Compose the dynamic tier from all sources (= ContextEngine bundle
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   4. Ephemeral hint (= final section, back-compat with the literal)
    fileprivate static func composeDynamicTier(
        contextBundle: ContextEngine.ContextBundle,
        memories: [MemoryAdapter.MemoryEntry],
        callerExtras: [String: String],
        ephemeralHint: String
    ) -> String {
        var sections: [String] = []

        // 1. Context bundle (= rendered via existing wenshu helper)
        let contextSection = renderContextBundle(contextBundle)
        if !contextSection.isEmpty {
            sections.append(contextSection)
        }

        // 2. Memory retrieval (= formatted with source + snippet + relevance)
        if !memories.isEmpty {
            let memoryLines = memories
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .map { entry -> String in
                    "- [\(entry.source)] \(entry.snippet) (relevance: \(formatRelevance(entry.relevanceScore)))"
                }
                .joined(separator: "\n")
            sections.append("Relevant memories:\n\(memoryLines)")
        }

        // 3. Caller extras (= "Key: Value" lines)
        if !callerExtras.isEmpty {
            let sortedKeys = callerExtras.keys.sorted()
            let extrasLines = sortedKeys
                .map { "\($0): \(callerExtras[$0] ?? "")" }
                .joined(separator: "\n")
            sections.append("Caller extras:\n\(extrasLines)")
        }

        // 5. Ephemeral hint (= final section, back-compat with the literal)
        if !ephemeralHint.isEmpty {
            sections.append("Context: \(ephemeralHint)")
        }

        return sections.joined(separator: "\n\n---\n\n")
    }

    /// Format a Double relevance score (= 0...1) for the memory line.
    private static func formatRelevance(_ score: Double) -> String {
        // 2-decimal fixed notation (= deterministic across runs; hermes uses the default
        // str() repr which is also 2-decimal for the 0.0...1.0 range).
        return String(format: "%.2f", score)
    }
}

// MARK: - Environment hints (= hermes build_environment_hints)

extension PromptBuilder {
    // / Environment-specific guidance (= hermes `build_environment_hints`).
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     in the agent runtime path; that's a hermes-CLI-only concept)
    public static func buildEnvironmentHints(
        hostOS: String = "macOS",
        hostVersion: String = "",
        userHome: String = NSHomeDirectory(),
        workingDirectory: String = ""
    ) -> String {
        var lines: [String] = []
        lines.append("Host: \(hostOS) (\(hostVersion))")
        lines.append("User home directory: \(userHome)")
        if !workingDirectory.isEmpty {
            lines.append("Current working directory: \(workingDirectory)")
        }
        return lines.joined(separator: "\n")
    }

    // / Dynamic context-file truncation cap (= hermes
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 6% window slice, with a 20K floor and 500K ceiling.
    public static func dynamicContextFileMaxChars(contextLength: Int?) -> Int {
        let floor = 20_000
        let ceiling = 500_000
        guard let ctx = contextLength, ctx > 0 else {
            return floor
        }
        let budget = Int(Double(ctx) * 4.0 * 0.06)
        return max(floor, min(budget, ceiling))
    }
}

// MARK: - Content scanning (= hermes _scan_context_content)

extension PromptBuilder {
    // / Scan context content for prompt injection patterns. Returns the
    // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / method becomes the single hook for threat-pattern scanning.
    public static func scanContextContent(_ content: String, filename: String) -> String {
        // Placeholder: future wenshu ticket will wire in threat-pattern library
        // (mirroring hermes `tools.threat_patterns.scan_for_threats`).
        _ = filename
        return content
    }
}

// (PromptBuilder.formatSteerMarker + .computerUseGuidance removed 2026-10-05 in dead-
// … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
// MARK: - Content truncation (= hermes _truncate_content)
extension PromptBuilder {
    // / Truncate context-file content to fit the model's context window
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / between them. No-op when content is already under the cap.
    public static func truncateContent(
        _ content: String,
        filename: String,
        contextLength: Int? = nil,
        maxChars: Int? = nil
    ) -> String {
        // An explicit cap wins (= hermes: an explicit context_file_max_chars
        // in config always beats the window-derived value). Zero and nil both
        // mean "derive from the window".
        let cap = maxChars.flatMap { $0 > 0 ? $0 : nil }
            ?? dynamicContextFileMaxChars(contextLength: contextLength)
        guard content.count > cap else {
            return content
        }
        // Record + drain the truncation (= hermes _record_truncation_warnings + drain; =
        // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // drainTruncationWarnings = a future refactor).
        PromptBuilderCaches.recordTruncationWarning(
            "\(filename): \(content.count) -> \(cap) chars (\(content.count - cap) truncated; = head 70% + tail 20% preserved)"
        )
        let warnings = PromptBuilder.drainTruncationWarnings()
        if !warnings.isEmpty {
            wenshuLogger.info("[PromptBuilder.truncateContent] \(warnings.joined(separator: " | ")) truncation warning(s): \(warnings.count)")
        }
        let headSize = Int(Double(cap) * 0.7)
        let tailSize = Int(Double(cap) * 0.2)
        let head = String(content.prefix(headSize))
        let tail = String(content.suffix(tailSize))
        return "\(head)\n\n[...truncated \(content.count - headSize - tailSize) chars from \(filename)...]\n\n\(tail)"
    }
}

// MARK: - Context bundle rendering (= mirror of ContextEngine.formatContextBundle)

extension PromptBuilder {
    // / Render a ContextEngine.ContextBundle as a system-prompt dynamic-tier section.
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / an actor call per turn.
    public static func renderContextBundle(_ bundle: ContextEngine.ContextBundle) -> String {
        var sections: [String] = []
        if !bundle.memories.isEmpty {
            let memoryLines = bundle.memories.map { "- [\($0.source)] \($0.snippet)" }.joined(separator: "\n")
            sections.append("Relevant memories:\n\(memoryLines)")
        }
        if !bundle.characterContext.isEmpty {
            sections.append("Characters:\n" + bundle.characterContext.joined(separator: "\n"))
        }
        if !bundle.worldContext.isEmpty {
            sections.append("World:\n" + bundle.worldContext.joined(separator: "\n"))
        }
        if !bundle.foreshadowContext.isEmpty {
            sections.append("Foreshadowing:\n" + bundle.foreshadowContext.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n---\n\n")
    }
}

// MARK: - Default identity (= hermes DEFAULT_AGENT_IDENTITY)

extension PromptBuilder {
    // / Default agent identity block (= hermes `DEFAULT_AGENT_IDENTITY`).
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / version. Kept in lockstep via a parallel-check on tests.
    public static func defaultIdentity() -> String {
        return """
        你是嵌入在文枢（Wenshu）中的 AI 助手——文枢是一款 macOS 上的长篇小说创作工具。
        文枢是写作工具，不是 LLM 平台。你协助用户撰写小说、发展人物、规划故事大纲、
        并润色文笔。

        工作原则：
        - 用与用户相同的语言回复（默认中文）。
        - 严格遵循用户提供的大纲、人物备注和世界规则，不得自相矛盾地编造细节。
        - 永不破坏角色。若需婉拒，请简短说明并继续写作任务。
        - 按用户要求输出散文、对话与结构化大纲。
        - 用户要求修改时，保持现有语气与叙事人称，除非明确要求改变。
        - 大纲与结构性内容使用 Markdown；章节正文使用纯散文。
        - 凡是用户提到具体职业、地名、朝代、事件、品牌等，都必须先 web_search 调研，
          再写回复——用你自己的训练数据识别这些名词。规则见 Agent driver section。
        """
    }

    // / Help-guidance block (= hermes `HERMES_AGENT_HELP_GUIDANCE`).
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / text lands when the wenshu help-system ticket ships.
    public static var helpGuidance: String {
        return """
        You run on Wenshu (a long-form novel authoring tool for macOS).
        When the user needs help with Wenshu itself — configuring, using,
        extending, or troubleshooting it — the documentation in AGENTS.md
        is your authoritative reference.
        """
    }
}

// MARK: - H1 Hermes-Python gap port (= 1:1 faithful port of hermes
// … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
// `/Volumes/ANAN/.hermes/agent/ prompt_builder.py`).
extension PromptBuilder {
    // (PromptBuilder.buildNousSubscriptionPrompt removed 2026-10-05 in dead-code-
    // … (= 31 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   threshold).
    public static func buildContextFilesPrompt(
        cwdPath: String = FileManager.default.currentDirectoryPath,
        contextLength: Int? = nil,
        maxChars: Int? = nil,
    ) -> String {
        // Wenshu-side wins: scan cwd for AGENTS.md only (= hermes scans for AGENTS.md +
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // per project conventions).
        let agentsMDPath = URL(fileURLWithPath: cwdPath)
            .appendingPathComponent("AGENTS.md")
        guard FileManager.default.fileExists(atPath: agentsMDPath.path) else {
            return ""
        }
        guard let content = try? String(contentsOf: agentsMDPath, encoding: .utf8) else {
            return ""
        }
        // Apply scan-for-threats (= hermes L46-L63 = `scan_context_content` via
        // `tools.threat_patterns.scan_for_threats`).
        let sanitized = PromptBuilderCaches.scanContextContent(
            content: content,
            filename: "AGENTS.md",
        )
        // Apply YAML-frontmatter strip (= hermes L105-L120 = `_strip_yaml_frontmatter`).
        let stripped = PromptBuilderCaches.stripYamlFrontmatter(sanitized)
        // Apply context-length truncation (= hermes L1756-L1794 = `_truncate_content` +
        // L1187-L1232 = `_dynamic_context_file_max_chars`).
        // An explicit cap wins over the window-derived one; zero and nil
        // both mean "derive from the window".
        let derivedMaxChars = PromptBuilderCaches.dynamicContextFileMaxChars(
            contextLength: contextLength,
        )
        let maxChars = maxChars.flatMap { $0 > 0 ? $0 : nil } ?? derivedMaxChars
        let truncated = PromptBuilderCaches.truncateContent(
            content: stripped,
            maxChars: maxChars,
        )
        guard !truncated.isEmpty else { return "" }
        return """
        ## Context: AGENTS.md

        The following project conventions document is loaded as context:

        \(truncated)

        Treat it as authoritative for this conversation.
        """
    }

    // MARK: -- H1.4 build_environment_hints (hermes L1047-L1185)
    // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   when on a non-macOS platform).
    public static func buildEnvironmentHints() -> String {
        // Wenshu-side wins: hermes probes a remote backend cache and builds a multi-line
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // stack bullets.
        #if os(macOS)
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return """
        ## Environment
        - Platform: macOS \(macOSVersion)
        - Apple stack: SwiftUI + AppKit (per AGENTS.md §11.1)
        - Backend: SwiftData (= chat history) + filesystem JSON
        - Model: wenshu-side; not a hermes user
        """
        #else
        return ""
        #endif
    }

    // MARK: -- H1.6 drain_truncation_warnings (hermes L1241-L1259)
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   no truncations happened since last drain).
    public static func drainTruncationWarnings() -> [String] {
        PromptBuilderCaches.truncationWarningsDrain()
    }
}

// MARK: - H1 caches (= hermes `_SKILLS_PROMPT_CACHE` + `_TRUNCATION_WARNINGS`).
// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
// for truncation warnings. Wenshu uses NSCache for thread-safe bounded-buffer storage.
public enum PromptBuilderCaches {

    /// Truncation-warnings ring buffer (= wenshu's NSCache-backed
    /// version of hermes's `_TRUNCATION_WARNINGS`).
    nonisolated(unsafe) static let truncationWarningsStorage: NSCache<NSString, NSArray> = {
        let c = NSCache<NSString, NSArray>()
        c.countLimit = 32
        return c
    }()

    /// Scan context content (= hermes L46-L63 = `_scan_context_content`).
    public static func scanContextContent(content: String, filename: String) -> String {
        // Wenshu-side wins: hermes uses `tools.threat_patterns.scan_for_threats`; wenshu
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // follow-up).
        _ = filename  // suppress unused warning; = real impl would use filename for logging
        return content
    }

    /// Strip YAML frontmatter (= hermes L105-L120 =
    /// `_strip_yaml_frontmatter`).
    public static func stripYamlFrontmatter(_ content: String) -> String {
        guard content.hasPrefix("---") else { return content }
        guard let endRange = content.range(of: "\n---", range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex) else {
            return content
        }
        let body = content[endRange.upperBound...].drop(while: { $0 == "\n" })
        return body.isEmpty ? content : String(body)
    }

    /// Compute dynamic context-file max chars (= hermes L1187-L1232 =
    /// `_dynamic_context_file_max_chars` + `_get_context_file_max_chars`).
    public static func dynamicContextFileMaxChars(contextLength: Int?) -> Int {
        // Hermes heuristic: 4 chars/token, 20% of context window, clamped [2048, 16384].
        guard let ctx = contextLength, ctx > 0 else { return 8192 }
        let raw = (ctx * 4) / 5
        return min(max(raw, 2048), 16384)
    }

    /// Truncate content (= hermes L1756-L1794 = `_truncate_content`).
    public static func truncateContent(content: String, maxChars: Int) -> String {
        guard content.count > maxChars else { return content }
        let head = content.prefix(maxChars)
        return """
        \(head)

        [... truncated at \(maxChars) chars ...]
        """
    }

    /// Append to truncation-warnings ring buffer (= hermes
    /// L1232-L1259 = `_record_truncation_warnings` + `drain`).
    public static func recordTruncationWarning(_ msg: String) {
        let key = NSString(string: "warnings")
        let existing = (truncationWarningsStorage.object(forKey: key) as? [String]) ?? []
        let updated = existing + [msg]
        truncationWarningsStorage.setObject(updated as NSArray, forKey: key)
    }

    /// Drain truncation warnings (= atomic read + clear).
    public static func truncationWarningsDrain() -> [String] {
        let key = NSString(string: "warnings")
        let existing = (truncationWarningsStorage.object(forKey: key) as? [String]) ?? []
        truncationWarningsStorage.removeObject(forKey: key)
        return existing
    }
}
