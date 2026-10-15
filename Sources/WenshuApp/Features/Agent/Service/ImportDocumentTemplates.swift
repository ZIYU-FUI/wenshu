// ImportDocumentTemplates.swift · Wenshu (= boss 2026-10-10 (see OOB.md #2026-10-10) 下"
// directive). The 5 document templates that constrain the import rewrite (= each
// BookFolder type gets its own template; = the templates are NOT enforced by the LLM
// prompt alone; = the templates are the structural contract that the LLM must follow
// when generating content for the corresponding folder; = the templates use a fixed
// markdown skeleton that the user can scan to recognize "this is a wenshu-generated
// document" at a glance; = missing fields use the `[TODO: <field> = 需调研: <具体问题>]`
// placeholder (= the user can search for `TODO` to find gaps in their worldbuilding; =
// the placeholder names what needs to be researched; = the placeholder is NOT a
// failure marker; = the import is successful even with TODO fields; = the TODO is a
// prompt for the user to come back and fill the gap later). The 5 templates correspond
// to the 5 BookFolder cases: world / characters / outlines / chapters / drafts. The
// reference library has its own schema (= boss 2026-10-09 (see OOB.md #2026-10-09)
// story-document template). Each template is a markdown skeleton (= not a JSON schema;
// = the LLM produces markdown content that fills the template sections; = the template
// is the "shape" the content must take). The template design principles: 1. **Format
// tightens** (= boss 2026-10-10 (see OOB.md #2026-10-10) structure immediately). 2.
// **Missing fields use placeholders** (= boss 2026-10-10 "不够的要去 调研，或者用缺失 占位，告诉用户当
// 前世界观设定不足 ，无法成为约 束"; = the LLM uses `[TODO: <field> = 需 调研: <具体问题>]` when the source
// doesn't provide the information; = the LLM does NOT invent or hallucinate; = the
// user can see what's missing and decide to research it). 3. **Original content is
// preserved** (= boss 2026-10-10 "重写尽 量保留原文内容 ，但如果按模版 填入进缺失，需 要调研补充. 如 果原文内容的格 式过重，不符合
// 文档要求，需要 重写去格式. 符 合模版要求"; = the LLM is instructed to preserve the original content
// VERBATIM under the template headings; = reformatting is allowed (= strip Obsidian
// back-links / frontmatter / plugin comments; = re-organize content under the template
// headings); = the LLM does NOT delete or summarize the original content). Each
// template is a `static let` string (= the LLM router embeds the template in the
// system prompt; = the template is the authoritative shape the LLM must follow). The
// templates are not validated by the system (= the LLM might produce slightly
// different content under each heading; = the user reads the result and edits as
// needed; = the template is a STRONG GUIDELINE not a strict schema).

import Foundation
// (extracted to WorldSubSection.swift in A29; = see that file)


/// The 6 import document templates.
/// Each template is a markdown
/// skeleton that the LLM
/// produces content for (= the
/// LLM fills each section
/// under each heading; = the
/// user can see the canonical
/// wenshu structure at a
/// glance).
enum ImportDocumentTemplate: String, CaseIterable, Sendable {
    case world
    case characters
    case outlines
    case chapters
    case drafts
    case ideas

    /// The markdown skeleton (= the
    /// LLM fills the body of each
    /// section; = the section
    /// headings are the
    /// "wenshu signature" that
    /// makes the document
    /// recognizable as
    /// wenshu-generated; = missing
    /// fields use the `[TODO: ...]`
    /// placeholder).
    var skeleton: String {
        switch self {
        case .world:      return ImportDocumentTemplateSkeletons.worldSkeleton
        case .characters: return ImportDocumentTemplateSkeletons.charactersSkeleton
        case .outlines:   return ImportDocumentTemplateSkeletons.outlinesSkeleton
        case .chapters:   return ImportDocumentTemplateSkeletons.chaptersSkeleton
        case .drafts:     return ImportDocumentTemplateSkeletons.draftsSkeleton
        case .ideas:      return ImportDocumentTemplateSkeletons.ideasSkeleton
        }
    }

    /// (= boss
    /// 2026-10-10 "我选
    /// 故事宪法，直
    /// 接跳到了步
    /// 骤 3，没
    /// 有重新
    /// 分析是
    /// 不是
    /// 内容
    /// 相同
    /// " 反馈).
    /// The LLM-driven
    /// content-same
    /// decision
    /// threshold (= the
    /// orchestrator
    /// uses this to
    /// decide between
    /// `.skipped` and
    /// `.done` when
    /// the LLM says
    /// `isContentSame
    /// == true`).
    /// Boss's
    /// 2026-10-10
    /// grill
    /// response:
    /// "你来定,
    /// 现在反
    /// 正是拍
    /// 脑
    /// 袋,
    /// 这个
    /// 参数
    /// 大概
    /// 率需
    /// 要调
    /// ". The
    /// current value
    /// is 0.7 (= a
    /// permissive
    /// threshold =
    /// the LLM has
    /// to be 70%
    /// confident
    /// before we
    /// trust the
    /// skip; = below
    /// 0.7 we err on
    /// the side of
    /// overwriting
    /// = the user
    /// sees the
    /// new content
    /// rather than
    /// a false
    /// "已跳过"
    /// pill). The
    /// value is
    /// exposed as a
    /// static
    /// constant
    /// (= testable
    /// in isolation;
    /// = easy to
    /// tune later
    /// without
    /// touching the
    /// import
    /// service).
    static let contentSameConfidenceThreshold: Float = 0.7
    /// The LLM in
    /// `.consolidate` mode was
    /// "compressing" the
    /// source body (= the LLM
    /// interpreted the prompt's
    /// "整理 .ws 格式" as
    /// "summarize and rewrite",
    /// even though the intent was
    /// "preserve verbatim + strip
    /// noise + add template
    /// skeleton"). Boss's fix:
    /// the orchestrator now does
    /// the format work in code
    /// (= deterministic, no LLM
    /// guessing):
    /// 1. **strip** the body (= remove
    ///    Obsidian backlinks, useless
    ///    metadata lines, plugin
    ///    comments; = the round-25
    ///    canonical strip).
    /// 2. **append missing H2
    ///    skeleton** (= for each H2
    ///    in the folder's
    ///    `importTemplate.skeleton`
    ///    that the stripped body
    ///    doesn't already have,
    ///    append it as an empty
    ///    section with a `[TODO]`
    ///    placeholder; = the user
    ///    sees a complete template
    ///    that highlights which
    ///    sections are still
    ///    blank).
    /// 3. The result is a body
    ///    that has **100% of the
    ///    original content** (=
    ///    nothing summarized, nothing
    ///    dropped) + the folder's
    ///    canonical H2 skeleton (= the
    ///    user can fill in the blanks).
    /// The `consolidate` mode
    /// `rewrittenBody` from the LLM
    /// is now ignored entirely (=
    /// the parser forces nil for
    /// `consolidate`; = the LLM no
    /// longer has permission to
    /// rewrite the body in this
    /// mode).
    static func prepareBodyForWrite(
        rawBody: String,
        folder: BookFolder
    ) -> String {
        // 1. strip noise (= the round-25 canonical `stripObsidianBacklinks` helper on the
        // WenshuConductorImportRouter also covers the `isUselessMetadataLine`
        // filter; = we re-implement the same strip in-place here because the
        // orchestrator already calls the router helper above and we want this
        // helper to be self-contained for unit testing).
        let stripped = stripUselessLines(rawBody)
        // 2. collect the skeleton's H2 titles (= the `## ` lines in the skeleton string).
        let skeletonH2s: [String]
        if let template = folder.importTemplate {
            skeletonH2s = extractH2Titles(from: template.skeleton)
        } else {
            skeletonH2s = []
        }
        // 3. for each H2 in the skeleton, check if the body already has that header. If
        // not, append it as an empty section with a [TODO] marker.
        var appended: [String] = []
        for h2 in skeletonH2s {
            if !stripped.contains("## \(h2)\n") && !stripped.contains("## \(h2)\r\n") {
                appended.append("## \(h2)\n\n[TODO: 需调研补齐]\n")
            }
        }
        if appended.isEmpty {
            return stripped
        }
        return stripped + "\n\n" + appended.joined(separator: "\n\n")
    }

    /// Extract H2 titles (= lines starting with
    /// `## `) from a markdown skeleton. Returns the
    /// title text (= the part after `## `; = no
    /// leading/trailing whitespace).
    private static func extractH2Titles(from skeleton: String) -> [String] {
        skeleton.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("## ") else { return nil }
            let title = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            // Skip empty titles (= guard against `## ` with no text; = shouldn't happen
            // in the canonical skeletons).
            return title.isEmpty ? nil : title
        }
    }

    /// Strip useless metadata lines (= round-25
    /// canonical; = inlined here for
    /// self-contained testing). Each line in
    /// `rawBody` is checked against the
    /// "useless metadata" filter (= the
    /// canonical "type: xxx", "状态:
    /// 草稿/定稿" style noise that comes
    /// from old wenshu templates / Obsidian
    /// plugins / etc.). Lines that pass the
    /// filter are joined back together.
    static func stripUselessLines(_ rawBody: String) -> String {
        return rawBody
            .components(separatedBy: "\n")
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return line } // keep blank lines as-is
                // boss 2026-10-10 "强制去 反链" feedback = code-side strip of Obsidian
                // backlinks (= even when they appear mid-paragraph; =
                // the LLM-prompt-side rule is in
                // WCIRHelpers.rewriteModeBlock.reorganize;
                // = the code-side rule catches any stragglers the LLM
                // missed; = the user can have `[[xxx]]` in any of: -
                // whole line (e.g. "[[故事宪法]]" alone) - mid-paragraph
                // (e.g. "见 [[02-朝代]]") - image embed (e.g.
                // "![[图片.png]]") We strip all `[[...]]` AND `![[...]]`
                // from every line; = leaves the surrounding text
                // intact (= the LLM's reorg work isn't lost).
                let strippedLine = Self.stripBacklinksInline(in: line)
                // boss 2026-10-10 "强制去 版本记录" feedback (= wenshu's doc body is pure
                // content; = version metadata lives in entities.json /
                // file mtime; = A's body should NOT carry version
                // lines like "上次更新: 2026-XX-XX" / "修改记录: v1 / v2" /
                // "Created: ..." etc.). The LLM-side rule covers most
                // cases; = this code-side filter drops any line whose
                // leading label is a known version metadata prefix.
                if Self.isVersionRecordLine(strippedLine.trimmingCharacters(in: .whitespaces)) {
                    return "" // drop the line (= replace with empty)
                }
                return strippedLine
            }
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return true } // keep blank lines
                if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") { return false } // whole-line backlink
                if trimmed.hasPrefix("<!--") && trimmed.hasSuffix("-->") { return false } // plugin comment
                if Self.isUselessMetadataLine(trimmed) { return false }
                return true
            }
            .joined(separator: "\n")
    }

    /// boss 2026-10-10 (see OOB.md #2026-10-10)
    /// (= anywhere in the line, not just
    /// whole-line matches). The pattern is
    /// `[[xxx]]` OR `![[xxx]]` (= image
    /// embed); = returns the line with
    /// those tokens removed. Also cleans
    /// up the spaces around the deletion
    /// (= "见 [[02-朝代]] 这边" → "见  这边"
    /// then a follow-up pass removes
    /// double spaces; = the cost of
    /// careful inline stripping).
    private static func stripBacklinksInline(in line: String) -> String {
        var result = line
        // `![[xxx]]` first (= longer match; = would match `[[xxx]]` as a prefix if we
        // tried the latter first). Regex: `!\[\[xxx\]\]` where `xxx` is
        // anything that's not `]`.
        let imageEmbed = #"!\[\[[^\]]*\]\]"#
        if let regex = try? NSRegularExpression(pattern: imageEmbed) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result, range: range, withTemplate: ""
            )
        }
        let backlink = #"\[\[[^\]]*\]\]"#
        if let regex = try? NSRegularExpression(pattern: backlink) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result, range: range, withTemplate: ""
            )
        }
        // Collapse runs of 2+ spaces (= leftover from "见 [[xxx]] 这边" → "见  这边") into a
        // single space. The single-space collapse preserves the LLM's reorg
        // text alignment.
        let multiSpace = #" {2,}"#
        if let regex = try? NSRegularExpression(pattern: multiSpace) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result, range: range, withTemplate: " "
            )
        }
        return result
    }

    /// boss 2026-10-10 (see OOB.md #2026-10-10)
    /// (= the substring before the first
    /// `:`) matches one of the known version
    /// metadata prefixes (= Chinese or
    /// English). The pattern is intentionally
    /// narrow (= exact-prefix match) so it
    /// doesn't false-positive on legitimate
    /// body text like "日期: 2026 春节" (= the
    /// label is "日期" = NOT in our
    /// no-list; = the line stays). The full
    /// list:
    ///   Chinese: 上次更新 / 修改记录 /
    ///            版本 / 修订 / 更新于 /
    ///            创建于
    ///   English: Created / Modified /
    ///            Updated / Revision /
    ///            Last edited / Date / Time
    ///            (= the LLM-prompt-side
    ///            also lists these; = the
    ///            code-side is the
    ///            last-mile safety net).
    private static func isVersionRecordLine(_ trimmedLine: String) -> Bool {
        let versionPrefixes: [String] = [
            // Chinese
            "上次更新", "修改记录", "版本", "修订",
            "更新于", "创建于",
            // English
            "Created", "Modified", "Updated",
            "Revision", "Last edited",
            "Date", "Time"
        ]
        // Only consider lines that have a ":" (= the version record is a key:value line;
        // = a body sentence that happens to start with "Created" is rare
        // without a colon; = safe to require the colon).
        guard let colonIndex = trimmedLine.firstIndex(of: ":") else {
            return false
        }
        let label = String(trimmedLine[..<colonIndex])
            .trimmingCharacters(in: .whitespaces)
        return versionPrefixes.contains { label == $0 }
    }

    /// The canonical "useless metadata line" detector
    /// (= round-25). Matches the old wenshu template's
    /// noise lines (= e.g. "类型: 民俗神-A节气",
    /// "状态: 草稿") that the user never asked to
    /// preserve. The pattern is a Chinese-label line
    /// (= one or more Chinese chars) followed by ": "
    /// and a value, where the label is one of the
    /// known-noisy labels (= 类型 / 状态 / 标签 /
    /// 核心信息 / 详细描述 / 出处 / 链接).
    static func isUselessMetadataLine(_ line: String) -> Bool {
        let pattern = "^[A-Za-z\\u4e00-\\u9fff]+:\\s*[^:]+$"
        guard line.range(of: pattern, options: .regularExpression) != nil else {
            return false
        }
        return line.hasPrefix("类型")
            || line.hasPrefix("状态")
            || line.hasPrefix("标签")
            || line.hasPrefix("核心信息")
            || line.hasPrefix("详细描述")
            || line.hasPrefix("出处")
            || line.hasPrefix("链接")
    }

    static let commonHeader = """
    # <实体名>

    实体类型: <character | location | event | concept | artifact | organization | era | work | other>
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要>
    """

    // (worldSkeleton extracted to ImportDocumentTemplateSkeletons.swift in A30; = see that file)


    // (charactersSkeleton extracted to ImportDocumentTemplateSkeletons.swift in A30; = see that file)


    // (outlinesSkeleton extracted to ImportDocumentTemplateSkeletons.swift in A30; = see that file)


    // (chaptersSkeleton extracted to ImportDocumentTemplateSkeletons.swift in A30; = see that file)


    // (draftsSkeleton extracted to ImportDocumentTemplateSkeletons.swift in A30; = see that file)


    // (ideasSkeleton extracted to ImportDocumentTemplateSkeletons.swift in A30; = see that file)

}
