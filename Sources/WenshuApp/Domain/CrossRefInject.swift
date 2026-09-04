// CrossRefInject.swift · Wenshu (文枢) · v0.27 (FCP library replica)
//
// Auto-injects entity references into chapter .md files (= per boss
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// 8/26 '实体被整个项目自动引用').
//
// Strategy (v0.27 MVP):
// 1. For each chapter .md file under books/<book-id>/chapters/
// 2. Find entity surface forms that appear in the .md body
// 3. Inject entity UUIDs into the .md frontmatter (crossRefs field)
// 4. Idempotent: re-running won't duplicate refs
//
// v0.27 MVP uses rule-based surface-form matching (= reuse the
// ChatTrigger detection logic). v0.27 followups can swap in LLM-based
// entity recognition.

import Foundation

struct CrossRefInject: Sendable {
    let referenceStore: ReferenceStoring
    let bookDirectory: URL

    /// Run the cross-ref injection for all chapters in the book.
    /// Returns the number of chapters that gained at least one new ref.
    @discardableResult
    func runInjection() throws -> Int {
        let chaptersDir = bookDirectory.appendingPathComponent("chapters", isDirectory: true)
        guard FileManager.default.fileExists(atPath: chaptersDir.path) else {
            return 0
        }
        let entities = try referenceStore.loadReferences(layer: .layerEntities)
        guard !entities.isEmpty else { return 0 }
        let chapterURLs = (try? FileManager.default.contentsOfDirectory(
            at: chaptersDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        var updatedCount = 0
        for chapterURL in chapterURLs where chapterURL.pathExtension == "md" {
            if try injectIntoChapter(at: chapterURL, entities: entities) {
                updatedCount += 1
            }
        }
        return updatedCount
    }

    /// Inject entity UUIDs into a single chapter .md file. Returns
    /// true if the file was modified.
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