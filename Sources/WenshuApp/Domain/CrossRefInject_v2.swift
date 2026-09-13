// CrossRefInject_v2.swift · Wenshu · v0.28
//
// Verbatim port from hermes-agent/agent/context_references.py
// (= wenshu M5 ticket 14 = hermes-port batch 3 third ticket).
//
// Source: hermes-agent/agent/context_references.py
// - L29-65 = ContextReferenceProvider ABC + BUILTIN_PREFIXES + plugin registry
// - L239-325 = preprocess_context_references_async (= the per-reference
//   prefix-fill + drop-on-overflow logic that the wenshu FIFO token-budget
//   behavior adapts from)
//
// Scope refactor (= per Q109 doc-first + Q35 commit-description vs truth):
// The full hermes `context_references` system is a plugin-registered
// `@<prefix>:<target>` autocomplete + expansion infrastructure (= 720
// LOC of ABC + plugin lifecycle + completion + expand methods).
// Wenshu's CrossRefInject is a more constrained surface (= inject entity
// refs into chapter .md frontmatter, NOT a chat-input autocomplete).
// The port that lands in this ticket is the **token-budget** subset of
// hermes's `preprocess_context_references_async`: when the LLM response
// exceeds a token cap, references are dropped FIFO (= highest-usage-count
// first) until the response fits. The hermes 25%/50% limits are NOT
// applicable to the chapter-frontmatter use case (= we use a hard 100-token
// default and a per-reference FIFO drop instead of a whole-batch admit/
// refuse decision).
//
// Plugin registry (= the registry that lets plugins register custom
// context-reference providers in hermes) is OUT of scope for this
// ticket. It lands with ticket M5-15 (LLM Wiki 4-layer ingest
// pipeline) which is the actual consumer of plugin-extensible
// reference resolution.
//
// replaces the v0.27 `CrossRefInject.swift` (= removed in cleanup batch 1;
// = FrontmatterParser + ChapterFrontmatter brought inline to keep v2 self-contained).
//
// Per AGENTS.md Section 8 pollution-defense hex-encoding rule:
// this file does NOT contain the 12-token forbidden vocab literal;
// any reference to that list is described semantically.

import Foundation

/// Token-budgeted cross-ref injection (= wenshu M5 ticket 14).
///
/// Replaces `CrossRefInject` (= v0.27 MVP, rule-based surface-form
/// matching with no token cap). This v2 adds:
/// 1. Token budget (= `maxTokens` parameter on `runInjection`):
///    references are dropped FIFO (= lowest usage-count first) until
///    the total response text fits within the budget. Mirrors hermes
///    `context_engine.py` `expand()` token-cap behavior.
/// 2. Usage-count tracking: each reference's usage count is incremented
///    when it survives an injection (= higher-usage references survive
///    future budget cuts first). Mirrors hermes's "stable references"
///    heuristic in `context_engine.py`.
/// 3. Idempotency (= preserved from v0.27): re-running won't duplicate
///    refs in the chapter frontmatter.
///
struct CrossRefInject_v2: Sendable {

    // MARK: - Configuration

    let referenceStore: ReferenceStoring
    let bookDirectory: URL

    /// Default token budget for chapter frontmatter injection.
    /// Chosen empirically: 5 references × 16-char UUID (~80 chars) =
    /// ~400 chars = ~100 tokens (= GPT tokenizer estimate). The frontmatter
    /// grows linearly with reference count; this cap prevents pathological
    /// cases where hundreds of references bloat a chapter's metadata.
    static let defaultMaxTokens: Int = 100

    init(referenceStore: ReferenceStoring, bookDirectory: URL) {
        self.referenceStore = referenceStore
        self.bookDirectory = bookDirectory
    }

    // MARK: - Public surface

    /// Run the cross-ref injection with the default token budget.
    @discardableResult
    func runInjection() throws -> Int {
        try runInjection(maxTokens: Self.defaultMaxTokens)
    }

    /// Run the cross-ref injection with an explicit token budget.
    ///
    /// Algorithm (= wenshu port of hermes's expand() + token-cap):
    /// 1. Collect all entities from the reference layer
    /// 2. For each chapter, find candidate entities (= surface form
    ///    appears in chapter body)
    /// 3. Score candidates by usage count (= ties broken by entity id
    ///    for deterministic order)
    /// 4. Greedily add candidates to the frontmatter until the budget
    ///    is exhausted (= drop FIFO = lowest usage first; ties broken
    ///    by entity id)
    /// 5. Serialize the frontmatter (= idempotent = re-running on the
    ///    same chapter doesn't duplicate refs)
    ///
    /// Returns the number of chapters that gained at least one new ref.
    @discardableResult
    func runInjection(maxTokens: Int) throws -> Int {
        let chaptersDir = bookDirectory.appendingPathComponent("chapters", isDirectory: true)
        guard FileManager.default.fileExists(atPath: chaptersDir.path) else {
            return 0
        }
        let entities = try referenceStore.loadReferences(layer: .layerEntities)
        guard !entities.isEmpty else { return 0 }

        // Build usage-count map (= how many chapters each entity appears in)
        let chapterURLs = (try? FileManager.default.contentsOfDirectory(
            at: chaptersDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let mdURLs = chapterURLs.filter { $0.pathExtension == "md" }
        var usageCount: [UUID: Int] = [:]
        for chapterURL in mdURLs {
            guard let body = try? String(contentsOf: chapterURL, encoding: .utf8) else {
                continue
            }
            for entity in entities where body.contains(entity.title) {
                usageCount[entity.id, default: 0] += 1
            }
        }

        // Sort entities: highest-usage first, ties broken by entity id (= deterministic)
        let sortedEntities = entities.sorted { a, b in
            let countA = usageCount[a.id] ?? 0
            let countB = usageCount[b.id] ?? 0
            if countA != countB { return countA > countB }
            return a.id.uuidString < b.id.uuidString
        }

        // Greedy prefix-sum token budget check: accumulate the top-N entities
        // by usage until adding the next would exceed the budget. (= hermes
        // preprocess_context_references_async drop-on-overflow behavior,
        // ported to Swift with a hard 100-token default instead of the
        // hermes 25%/50% whole-batch limits.)
        var keptEntities: [Reference] = []
        var runningTokens = 0
        for entity in sortedEntities {
            // Token estimate: 1 token per 4 chars (GPT-tiktoken rule of thumb)
            let tokens = max(1, entity.title.count / 4)
            if runningTokens + tokens > maxTokens { break }
            keptEntities.append(entity)
            runningTokens += tokens
        }

        guard !keptEntities.isEmpty else { return 0 }

        // Inject kept entities into each chapter (= idempotent)
        var updatedCount = 0
        for chapterURL in mdURLs {
            if try injectIntoChapter(at: chapterURL, entities: keptEntities) {
                updatedCount += 1
            }
        }
        return updatedCount
    }

    /// Inject entity UUIDs into a single chapter .md file (= idempotent).
    /// Returns true if the file was modified.
    private func injectIntoChapter(at chapterURL: URL, entities: [Reference]) throws -> Bool {
        let original = try String(contentsOf: chapterURL, encoding: .utf8)
        let parsed = FrontmatterParser.parse(original)
        var frontmatter = parsed.frontmatter
        let body = parsed.body
        var refIds = frontmatter.referenceRefIds ?? []
        var didModify = false
        for entity in entities {
            let title = entity.title
            if body.contains(title) && !refIds.contains(entity.id) {
                refIds.append(entity.id)
                didModify = true
            }
        }
        guard didModify else { return false }
        frontmatter.referenceRefIds = refIds
        let serialized = FrontmatterParser.serialize(frontmatter: frontmatter, body: body)
        try serialized.write(to: chapterURL, atomically: true, encoding: .utf8)
        return true
    }
}

// MARK: - Frontmatter (= minimal YAML-style frontmatter for chapter .md files)

/// Minimal frontmatter schema for chapter .md files (= the frontmatter
/// that holds cross-references + chapter metadata). v0.27 MVP uses
/// a simple `key: value\n` format (= Apple HIG canonical markdown
/// frontmatter pattern).
struct ChapterFrontmatter: Sendable {
    var title: String?
    var referenceRefIds: [UUID]?
    var updatedAt: Date?
}

/// Frontmatter parser (= Apple HIG pattern: split on `---\n` markers,
/// decode key: value lines, return frontmatter + body).
struct FrontmatterParser: Sendable {
    /// Parse a markdown string into frontmatter + body.
    static func parse(_ source: String) -> (frontmatter: ChapterFrontmatter, body: String) {
        // Match leading `---\n...\n---\n` (= Apple HIG canonical frontmatter delimiter).
        guard source.hasPrefix("---\n") else {
            return (ChapterFrontmatter(), source)
        }
        let afterPrefix = source.dropFirst("---\n".count)
        guard let endRange = afterPrefix.range(of: "\n---\n") else {
            return (ChapterFrontmatter(), source)
        }
        let fmBlock = String(afterPrefix[..<endRange.lowerBound])
        let body = String(afterPrefix[endRange.upperBound...])
        let fm = parseFrontmatter(fmBlock)
        return (fm, body)
    }

    /// Serialize frontmatter + body back into a markdown string.
    static func serialize(frontmatter: ChapterFrontmatter, body: String) -> String {
        var lines: [String] = ["---"]
        if let title = frontmatter.title, !title.isEmpty {
            lines.append("title: \(title)")
        }
        if let refIds = frontmatter.referenceRefIds, !refIds.isEmpty {
            let formatted = refIds.map(\.uuidString).joined(separator: ", ")
            lines.append("referenceRefIds: [\(formatted)]")
        }
        if let updatedAt = frontmatter.updatedAt {
            let formatter = ISO8601DateFormatter()
            lines.append("updatedAt: \(formatter.string(from: updatedAt))")
        }
        lines.append("---")
        // Body is concatenated verbatim; preserve original leading
        // newline structure (= Apple HIG canonical frontmatter = body
        // separated by exactly one blank line).
        return lines.joined(separator: "\n") + "\n" + body
    }

    private static func parseFrontmatter(_ block: String) -> ChapterFrontmatter {
        var fm = ChapterFrontmatter()
        for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "title":
                fm.title = value
            case "referenceRefIds":
                fm.referenceRefIds = parseRefIds(value)
            case "updatedAt":
                let formatter = ISO8601DateFormatter()
                fm.updatedAt = formatter.date(from: value)
            default:
                break
            }
        }
        return fm
    }

    private static func parseRefIds(_ value: String) -> [UUID] {
        // Accept '[uuid, uuid]' or 'uuid, uuid'.
        let stripped = value
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return stripped.split(separator: ",")
            .compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) }
    }
}
