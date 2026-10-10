//
//  ImportDocumentTemplates.swift · Wenshu
//
//  v2.7 round-59 (= boss 2026-10-10 "我
//  刚刚用单文件导入的方式，
//  导入了三个文件，你对比一
//  下源文件，就会发现文件
//  内容被删没了。没有真正
//  的落地. 为了解决这个问题
//  ，我觉的重写文件不能靠
//  LLM 来约束. 而是要有一
//  个模版，是文枢项目要求
//  的各目录文档模版. 这个
//  模版会约束导入的内容重
//  写，不够的要去调研，或
//  者用缺失占位，告诉用
//  户当前世界观设定不足
//  ，无法成为约束. 这个
//  模版我需要你去调研一
//  下" directive). The 5
//  document templates that
//  constrain the import
//  rewrite (= each BookFolder
//  type gets its own template;
//  = the templates are NOT
//  enforced by the LLM prompt
//  alone; = the templates
//  are the structural
//  contract that the LLM must
//  follow when generating
//  content for the
//  corresponding folder; =
//  the templates use a
//  fixed markdown skeleton
//  that the user can scan to
//  recognize "this is a
//  wenshu-generated document"
//  at a glance; = missing
//  fields use the
//  `[TODO: <field> = 需调研:
//  <具体问题>]` placeholder
//  (= the user can search for
//  `TODO` to find gaps in
//  their worldbuilding; = the
//  placeholder names what
//  needs to be researched; =
//  the placeholder is NOT a
//  failure marker; = the
//  import is successful
//  even with TODO fields; =
//  the TODO is a prompt for
//  the user to come back and
//  fill the gap later).
//
//  The 5 templates correspond
//  to the 5 BookFolder cases:
//  world / characters /
//  outlines / chapters /
//  drafts. The reference
//  library has its own
//  schema (= boss 2026-10-09
//  round-25 "不要参考 MD 的
//  格式，而是盘点文枢的
//  功能，做出文枢的头
//  部格式"; = the reference
//  library uses the
//  必填 3 行 + 可选 2 行
//  header; = that's
//  Reference's fields, not a
//  story-document template).
//
//  Each template is a
//  markdown skeleton (= not
//  a JSON schema; = the
//  LLM produces markdown
//  content that fills the
//  template sections; = the
//  template is the
//  "shape" the content must
//  take). The template
//  design principles:
//  1. **Format tightens** (=
//     boss 2026-10-10 "模版可
//     以在格式上收紧一
//     些. 让用户能一眼看
//     书这是文枢生成的
//     内容"; = the format
//     is fixed; = the
//     headings are
//     predetermined; = the
//     LLM fills the
//     content under each
//     heading; = the user
//     can scan the document
//     and see the canonical
//     structure immediately).
//  2. **Missing fields use
//     placeholders** (= boss
//     2026-10-10 "不够的要去
//     调研，或者用缺失
//     占位，告诉用户当
//     前世界观设定不足
//     ，无法成为约
//     束"; = the LLM uses
//     `[TODO: <field> = 需
//     调研: <具体问题>]`
//     when the source
//     doesn't provide the
//     information; = the
//     LLM does NOT invent
//     or hallucinate; = the
//     user can see what's
//     missing and decide to
//     research it).
//  3. **Original content is
//     preserved** (= boss
//     2026-10-10 "重写尽
//     量保留原文内容
//     ，但如果按模版
//     填入进缺失，需
//     要调研补充. 如
//     果原文内容的格
//     式过重，不符合
//     文档要求，需要
//     重写去格式. 符
//     合模版要求"; = the
//     LLM is instructed
//     to preserve the
//     original content
//     VERBATIM under the
//     template headings;
//     = reformatting is
//     allowed (= strip
//     Obsidian back-links
//     / frontmatter /
//     plugin comments; =
//     re-organize content
//     under the template
//     headings); = the
//     LLM does NOT delete
//     or summarize the
//     original content).
//
//  Each template is a
//  `static let` string
//  (= the LLM router embeds
//  the template in the
//  system prompt; = the
//  template is the
//  authoritative shape the
//  LLM must follow). The
//  templates are not
//  validated by the system
//  (= the LLM might produce
//  slightly different
//  content under each
//  heading; = the user
//  reads the result and
//  edits as needed; = the
//  template is a STRONG
//  GUIDELINE not a strict
//  schema).
//

import Foundation

/// v2.7 round-69 (= boss 2026-10-10
/// "6 份, 同时标题就是这
/// 6 份的标题, 无论用户
/// 导入的世界观文件是什
/// 么, 这六个文件是必须
/// 的. 不全就是世界观设
/// 定不完整" feedback).
/// The world/ folder is
/// split into 6 separate
/// .md files (= one per
/// mandatory H2 section).
/// Each file = ONE
/// wenshu-canonical H2;
/// = future-novel LLM
/// constraint lookups can
/// target a single H2
/// without loading the
/// whole 6-H2 file; = the
/// user can edit one H2 in
/// isolation. The 6 cases
/// below ARE the canonical
/// filenames (= boss
/// mandated "标题就是这
/// 6 份的标题" = filename
/// = H2 title, no aliases).
/// All 6 are MANDATORY for
/// every import (= boss
/// "无论用户导入的世界观
/// 文件是什么, 这六个
/// 文件是必须的"); = a
/// missing one (= the LLM
/// didn't produce content
/// for it) gets the
/// `[TODO: 需调研补齐]`
/// placeholder (= the
/// canonical wenshu
/// "worldview is incomplete"
/// affordance).
enum WorldSubSection: String, CaseIterable, Sendable, Hashable, Codable {
    case core       = "核心设定"
    case geography  = "地理或位置"
    case system     = "体系或规则"
    case history    = "历史脉络"
    case relations  = "与其他元素的关系"
    case scenes     = "关键场景种子"

    /// Human-readable name (= the H2 title;
    /// = the on-disk filename stem; =
    /// matches `rawValue`).
    var displayName: String { rawValue }

    /// The on-disk filename (= no `.md`
    /// extension; = the basename only;
    /// = the orchestrator appends the
    /// `.md` extension at write time).
    /// Convention: filename = H2
    /// title, verbatim (= boss
    /// mandated; = the sidebar
    /// card title = the filename
    /// stem = the H2 title = the
    /// enum rawValue; = no
    /// translation, no aliasing).
    var filename: String { rawValue }

    /// The mini-skeleton for this
    /// sub-section (= a 1-H2
    /// markdown stub the LLM
    /// fills; = the canonical
    /// wenshu format for this
    /// specific section). All 6
    /// are MANDATORY.
    var skeleton: String {
        switch self {
        case .core:
            return Self.coreSkeleton
        case .geography:
            return Self.geographySkeleton
        case .system:
            return Self.systemSkeleton
        case .history:
            return Self.historySkeleton
        case .relations:
            return Self.relationsSkeleton
        case .scenes:
            return Self.scenesSkeleton
        }
    }

    // MARK: - 6 mandatory mini-skeletons

    /// 核心设定 — one-line
    /// "what is this element
    /// and why does it matter".
    private static let coreSkeleton = """
    ## 核心设定

    <一句话回答：这个世界观元素"是什么"和"为什么重要"；不超过 80 字>
    """

    /// 地理或位置 — terrain,
    /// climate, resources,
    /// dangers.
    private static let geographySkeleton = """
    ## 地理或位置

    <位置描述：地形 / 气候 / 资源 / 危险；不超过 200 字>

    [TODO: 地理 = 需调研: <具体未知的细节>]
    """

    /// 体系或规则 — magic /
    /// tech / social system.
    private static let systemSkeleton = """
    ## 体系或规则

    ### 能力

    <系统能做什么；列举 2-3 条>

    ### 成本与限制

    <使用这个系统的代价是什么；硬性"不允许"的规则是什么>

    ### 边界情况

    <做得太过火会发生什么>
    """

    /// 历史脉络 — origin →
    /// turning point → current
    /// state.
    private static let historySkeleton = """
    ## 历史脉络

    <起源 → 关键转折 → 当前状态；不超过 300 字>

    [TODO: 历史 = 需调研: <具体未知的细节>]
    """

    /// 与其他元素的关系 —
    /// cross-references to
    /// other world/ elements +
    /// characters/ + antagonists.
    private static let relationsSkeleton = """
    ## 与其他元素的关系

    - 引用: <世界观里其他元素 A>（= A 也在 world/ 目录下有对应 .md）
    - 引用: <角色 B>（= B 在 characters/ 目录下有对应 .md）
    - 反派: <敌对势力 C>
    """

    /// 关键场景种子 — 2-3
    /// possible scenes this
    /// element forces the
    /// protagonist into.
    private static let scenesSkeleton = """
    ## 关键场景种子

    <这个世界观元素会迫使主角面临什么样的场景？列出 2-3 个可能场景>
    """
}

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
        case .world:      return Self.worldSkeleton
        case .characters: return Self.charactersSkeleton
        case .outlines:   return Self.outlinesSkeleton
        case .chapters:   return Self.chaptersSkeleton
        case .drafts:     return Self.draftsSkeleton
        case .ideas:      return Self.ideasSkeleton
        }
    }

    /// v2.7 round-66 commit F (= boss
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
        // 1. strip
        // noise (= the
        // round-25
        // canonical
        // `stripObsidianBacklinks`
        // helper on the
        // WenshuConductorImportRouter
        // also covers the
        // `isUselessMetadataLine`
        // filter; = we
        // re-implement the
        // same strip
        // in-place here
        // because the
        // orchestrator
        // already calls
        // the router
        // helper above
        // and we want
        // this helper to
        // be
        // self-contained
        // for unit
        // testing).
        let stripped = stripUselessLines(rawBody)
        // 2. collect
        // the
        // skeleton's
        // H2
        // titles
        // (= the
        // `## `
        // lines
        // in
        // the
        // skeleton
        // string).
        let skeletonH2s: [String]
        if let template = folder.importTemplate {
            skeletonH2s = extractH2Titles(from: template.skeleton)
        } else {
            skeletonH2s = []
        }
        // 3. for
        // each
        // H2 in
        // the
        // skeleton,
        // check
        // if
        // the
        // body
        // already
        // has
        // that
        // header.
        // If
        // not,
        // append
        // it
        // as
        // an
        // empty
        // section
        // with
        // a
        // [TODO]
        // marker.
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
            // Skip
            // empty
            // titles
            // (=
            // guard
            // against
            // `## ` with
            // no text;
            // = shouldn't
            // happen in
            // the
            // canonical
            // skeletons).
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
                // v2.7 round-67 boss
                // 2026-10-10 "强制去
                // 反链" feedback =
                // code-side strip of
                // Obsidian backlinks
                // (= even when they
                // appear mid-paragraph;
                // = the LLM-prompt-side
                // rule is in
                // WenshuConductorImportRouter.rewriteModeBlock.reorganize;
                // = the code-side rule
                // catches any stragglers
                // the LLM missed; = the
                // user can have
                // `[[xxx]]` in any of:
                //   - whole line (e.g.
                //     "[[故事宪法]]"
                //     alone)
                //   - mid-paragraph
                //     (e.g. "见
                //     [[02-朝代]]")
                //   - image embed
                //     (e.g.
                //     "![[图片.png]]")
                // We strip all `[[...]]`
                // AND `![[...]]` from
                // every line; = leaves
                // the surrounding text
                // intact (= the LLM's
                // reorg work isn't
                // lost).
                let strippedLine = Self.stripBacklinksInline(in: line)
                // v2.7 round-67 boss
                // 2026-10-10 "强制去
                // 版本记录" feedback
                // (= wenshu's doc body
                // is pure content; =
                // version metadata
                // lives in
                // entities.json / file
                // mtime; = A's body
                // should NOT carry
                // version lines like
                // "上次更新: 2026-XX-XX"
                // / "修改记录: v1 / v2"
                // / "Created: ..."
                // etc.). The LLM-side
                // rule covers most
                // cases; = this
                // code-side filter
                // drops any line
                // whose leading label
                // is a known version
                // metadata prefix.
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

    /// v2.7 round-67 boss 2026-10-10
    /// "强制去反链" feedback.
    /// Strip Obsidian backlinks **inline**
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
        // `![[xxx]]` first (= longer match; =
        // would match `[[xxx]]` as a prefix
        // if we tried the latter first).
        // Regex: `!\[\[xxx\]\]` where `xxx`
        // is anything that's not `]`.
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
        // Collapse runs of 2+ spaces (= leftover
        // from "见 [[xxx]] 这边" → "见  这边") into
        // a single space. The single-space
        // collapse preserves the LLM's reorg
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

    /// v2.7 round-67 boss 2026-10-10
    /// "强制去版本记录, 这些东西在我们的
    /// 项目没有意思" feedback. A line is a
    /// "version record" if its leading label
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
        // Only consider lines that have a ":"
        // (= the version record is a key:value
        // line; = a body sentence that happens
        // to start with "Created" is rare
        // without a colon; = safe to require
        // the colon).
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

    // MARK: - World template

    /// 世界观 (world/) template.
    /// A 世界观 document captures
    /// ONE element of the story's
    /// world (= a location, a
    /// magic system, a race, a
    /// historical event, a
    /// political faction; = NOT
    /// the entire world bible; =
    /// each world/ file is one
    /// element; = the union of all
    /// world/ files is the world
    /// bible). Research source:
    /// jerryjenkins.com character
    /// profile + novelists.cn
    /// worldbuilding template +
    /// adazing.com worldbuilding.
    ///
    /// v2.7 round-69 (= boss 2026-10-10
    /// "6 份, 同时标题就是
    /// 这 6 份的标题, 无论
    /// 用户导入的世界观文
    /// 件是什么, 这六个文
    /// 件是必须的. 不全就
    /// 是世界观设定不完整"
    /// feedback). The world/
    /// folder now has 6
    /// mandatory .md files
    /// (= one per H2); = this
    /// "main file" is the
    /// INDEX (= metadata +
    /// 6 sub-file references).
    /// The 6 sub-files are
    /// written via the
    /// `extraFiles` pipeline
    /// (= same path as
    /// round-67's "split out
    /// non-B content" feature;
    /// = the LLM populates
    /// each sub-section
    /// independently).
    private static let worldSkeleton = """
    # <世界观元素名>

    实体类型: <location | concept | event | era | organization | artifact | other>
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述这个元素在故事中的核心作用>

    ## 6 份必填子文档

    (= round-69 拆分后, 世界观 = 1 主索引 + 6 份独立 .md
    在 world/ 同目录下):

    - [`核心设定.md`](核心设定.md) — 这个元素"是什么"和"为什么重要"
    - [`地理或位置.md`](地理或位置.md) — 地形 / 气候 / 资源 / 危险
    - [`体系或规则.md`](体系或规则.md) — 能力 / 成本与限制 / 边界情况
    - [`历史脉络.md`](历史脉络.md) — 起源 → 关键转折 → 当前状态
    - [`与其他元素的关系.md`](与其他元素的关系.md) — 引用 / 反派 / 盟友
    - [`关键场景种子.md`](关键场景种子.md) — 主角会面临的场景
    """

    // MARK: - Characters template

    /// 角色 (characters/) template.
    /// A 角色 document captures
    /// ONE character's full
    /// profile. Research source:
    /// jerryjenkins.com character
    /// profile + reddit
    /// r/writing character profile
    /// thread + dramatica discussion.
    /// 8 mandatory sections (= the
    /// most detailed template
    /// because character motivation
    /// drives the plot).
    private static let charactersSkeleton = """
    # <角色名>

    实体类型: character
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述这个角色在故事中的位置>

    ## 基本信息

    - 姓名: <本名 / 化名 / 称号>
    - 年龄: <数字或年龄区间>
    - 性别: <男 / 女 / 其他>
    - 身份: <职业 / 地位 / 阵营>

    ## 外在形象

    <身高 / 体格 / 穿着 / 标志性特征 / 习惯性动作；不超过 200 字>

    [TODO: 外在 = 需调研: <具体未知的细节>]

    ## 内在性格

    ### 核心性格（一两个词）

    <例如：谨慎 / 冲动 / 矛盾>

    ### 优点

    <2-3 条>

    ### 缺点与盲点

    <2-3 条；这些是角色的戏剧张力来源>

    ## 动机与目标

    ### 表面目标（角色自己声称的）

    <角色口头说自己要做什么>

    ### 深层动机（角色不愿承认的）

    <真正驱动角色的是什么；通常与恐惧或过去相关>

    [TODO: 动机 = 需调研: <具体未知的细节>]

    ## 恐惧与弱点

    <角色最怕什么；什么会让角色崩溃或做出错误决定>

    ## 背景与过去

    <关键经历；不超过 300 字；这些经历塑造了角色的核心>

    ## 与其他角色的关系

    - 盟友: <角色 A>：<关系描述>
    - 敌对: <角色 B>：<关系描述>
    - 暧昧/师徒/家人: <角色 C>：<关系描述>

    ## 角色弧线

    <故事开始时这个角色是什么样 → 故事结束时变成什么样；不超过 200 字>

    ## 关键场景种子

    <这个角色会迫使主角面临什么样的场景？列出 2-3 个可能场景>

    ## 备注

    <其他元数据、来源、研究笔记；可省略>
    """

    // MARK: - Outlines template

    /// 大纲 (outlines/) template.
    /// An outlines document
    /// captures a story-level OR
    /// act-level outline (= the
    /// chapter-by-chapter outline
    /// lives in chapters/; = the
    /// outlines/ is the high-level
    /// structure = acts, blocks,
    /// key turns). Research source:
    /// scyn.app 27-chapter outline +
    /// litmemo.com novel outline +
    /// chapter.pub novel outline.
    /// 5 mandatory sections.
    private static let outlinesSkeleton = """
    # <大纲名>

    实体类型: event
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述这个大纲的范围（一卷 / 一幕 / 全书）>

    ## 故事核心问题

    <这个故事要回答的戏剧性问题是什么？不超过 50 字>

    ## 三幕骨架

    ### 第一幕（Setup，约 25%）

    - **Hook（0-5%）**: <故事开始时主角的"普通世界"是什么样>
    - **Inciting Incident（约 10%）**: <打破平衡、主角无法再回避的事件>
    - **First Plot Point（约 25%）**: <主角主动选择进入旅程；不可回头的门槛>

    ### 第二幕（Confrontation，约 50%）

    - **Midpoint（约 50%）**: <主角对冲突的理解发生反转；中点翻转>
    - **Second Plot Point（约 75%）**: <最低点；主角失去一切旧计划>

    ### 第三幕（Resolution，约 25%）

    - **Climax（约 90%）**: <主角面对核心敌人的最终对决>
    - **Resolution（95-100%）**: <新平衡；与 Hook 形成对照>

    [TODO: 大纲 = 需调研: <具体未知的细节>]

    ## 关键转折

    <3-5 个让读者"没想到"的转折点；每个转折点 = 改变主角理解的事件>

    ## 主题

    <这个故事要表达的核心命题；不超过 100 字>

    ## 备注

    <字数目标 / 题材 / 受众 / 风格参考；可省略>
    """

    // MARK: - Chapters template

    /// 章节 (chapters/) template.
    /// A chapters document captures
    /// a SINGLE chapter (= one
    /// chapter per file; = the
    /// chapter-by-chapter outline
    /// row lives in outlines/ as
    /// the master plan). Research
    /// source: litmemo.com chapter
    /// planner + chapter.pub
    /// chapter-by-chapter template.
    /// 5 mandatory sections.
    private static let chaptersSkeleton = """
    # 第 <N> 章 <章节标题>

    实体类型: event
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述本章发生什么>

    ## 章节目标

    <本章要让读者知道/感受到什么？不超过 50 字>

    ## 主要事件

    <2-3 句：发生了什么；本章结束时与开始时有什么不同>

    ## 出场角色

    - <角色 A>（= A 在 characters/ 目录下有对应 .md）
    - <角色 B>
    - <新引入角色 C>[TODO: 角色 C = 需调研: <这个角色还没有正式 profile>]

    ## 伏笔

    - **埋设**: <本章埋下一个细节，指向未来章节>
    - **兑现**: <本章兑现之前的某个伏笔，源自第 X 章>

    ## 字数目标

    <计划字数 / 实际字数 / 状态：草稿 / 定稿>

    ---

    <章节正文；按时间顺序的叙述；如果原文有正文，请尽量保留原内容>

    """

    // MARK: - Drafts template

    /// 草稿 (drafts/) template.
    /// v2.7 round-60 (= boss
    /// 2026-10-10 "drafts/
    /// 草稿和正文模版
    /// 一至" + "Agent
    /// 写的正文一律
    /// 先进草稿. 由
    /// 用户确认后进
    /// 入正文" + "
    /// 正式章节的
    /// 内容，除了导
    /// 入，草稿确认
    /// 后的，Agent 不
    /// 可以在里面新
    /// 增内容"
    /// directive). The
    /// drafts template
    /// is now structurally
    /// identical to the
    /// chapters template
    /// (= the only
    /// difference between
    /// a draft and a
    /// chapter is the
    /// folder it lives
    /// in; = a draft
    /// becomes a chapter
    /// when the user
    /// right-clicks the
    /// card and picks
    /// "确定为正式章节"
    /// (= the
    /// `drafts/chapters`
    /// folder becomes
    /// `chapters/`; = the
    /// status flips from
    /// 草稿 to 定稿)).
    /// Both templates
    /// share the same
    /// section structure
    /// (= 章节目标 /
    /// 主要事件 / 出场
    /// 角色 / 伏笔 / 字
    /// 数目标 + 正文);
    /// = the user can
    /// move a file from
    /// drafts/ to
    /// chapters/ without
    /// any rewriting
    /// (= the file is
    /// already in the
    /// correct shape; =
    /// only the
    /// folder + status
    /// change). The
    /// product rule
    /// "Agent 写的正
    /// 文一律先进草
    /// 稿" means the
    /// LLM router MUST
    /// write to drafts/
    /// (= not chapters/;
    /// = this is enforced
    /// in a separate
    /// future commit;
    /// = the template is
    /// the structural
    /// foundation).
    private static let draftsSkeleton = """
    # 第 <N> 章 <章节标题>

    实体类型: event
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述本章发生什么>

    ## 章节目标

    <本章要让读者知道/感受到什么？不超过 50 字>

    ## 主要事件

    <2-3 句：发生了什么；本章结束时与开始时有什么不同>

    ## 出场角色

    - <角色 A>（= A 在 characters/ 目录下有对应 .md）
    - <角色 B>
    - <新引入角色 C>[TODO: 角色 C = 需调研: <这个角色还没有正式 profile>]

    ## 伏笔

    - **埋设**: <本章埋下一个细节，指向未来章节>
    - **兑现**: <本章兑现之前的某个伏笔，源自第 X 章>

    ## 字数目标

    <计划字数 / 实际字数 / 状态：草稿>

    ---

    <章节正文；按时间顺序的叙述；如果原文有正文，请尽量保留原内容>

    """

    // MARK: - Ideas template

    /// 构思 (ideas/) template.
    /// v2.7 round-60 (= boss
    /// 2026-10-10 "需
    /// 要加一个目录
    /// ，放你现在的
    /// 草稿，类似
    /// 构思" + "新
    /// 文件夹构思
    /// ，是一些零
    /// 散的设定，
    /// 和未来的
    /// 一些想法，
    /// 不是草稿"
    /// directive). The
    /// ideas/ folder is
    /// a scratchpad for
    /// loose world-
    /// building fragments
    /// and future-story
    /// ideas (= NOT a
    /// draft; = the
    /// distinction
    /// between `ideas`
    /// and `drafts` is:
    /// `ideas` = "things
    /// that MIGHT become
    /// characters /
    /// locations /
    /// events / chapters
    /// later, but I
    /// don't know what
    /// yet"; = `drafts` =
    /// "this IS a chapter
    /// but I haven't
    /// finalized it yet";
    /// = `chapters` = "I
    /// confirmed this is
    /// the final text").
    /// The ideas template
    /// is the lightest
    /// template (= 4
    /// sections; = no
    /// chapter body; = no
    /// character profile;
    /// = just a quick
    /// capture). The
    /// `可能成为` section
    /// (= "what it might
    /// become") is the
    /// key differentiator
    /// (= forces the
    /// user to commit to
    /// a destination when
    /// they promote the
    /// idea to a folder;
    /// = the user can
    /// also leave it
    /// blank if the
    /// idea is too
    /// unformed).
    private static let ideasSkeleton = """
    # <想法名>

    实体类型: <character | location | event | concept | artifact | organization | era | work | other>
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述这个想法的核心>

    ## 灵感来源

    <这个想法是因为什么而产生？读了什么 / 看了什么 / 想到了什么？不超过 100 字>

    ## 当前形态

    <现在这个想法是什么状态？一段话 / 几个关键词 / 一个场景？可省略>

    [TODO: 当前形态 = 需调研: <这个想法还不够具体，需要更深入的研究或思考>]

    ## 可能成为

    <这个想法未来可能成为什么？character / location | event | chapter | outline | 世界观的一个子项？可省略>

    ## 备注

    <其他元数据、来源、研究笔记；可省略>

    """
}
