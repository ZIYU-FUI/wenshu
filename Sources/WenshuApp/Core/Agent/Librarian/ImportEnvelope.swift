//
//  ImportEnvelope.swift
//
//  Wire envelope types for the v2.7 markdown import feature
//  (= boss 2026-10-09 directive "导入" / "File > 导入" menu
//  entry; = the path that lets the user point wenshu at a
//  folder of external .md files and have the agent route
//  each one to either a book folder (= world / characters /
//  outlines / chapters / drafts) or the reference library
//  (= research notes; = external knowledge the book can
//  reference).
//
//  This file holds the **data model** only (= the wire
//  contract the ImportService and the Librarian agent pass
//  back and forth; = the service / view / agent that produce
//  and consume the envelope live in other files per the
//  T1/T2/T3/T4 ticket split in
//  .scratch/2026-10-09-md-import-feature/tickets.md).
//
//  Apple canonical shape:
//   - The book-folder destination REUSES the existing
//     `BookFolder` enum (= the 8-case enum
//     that already carries the on-disk directoryName
//     canonical mapping; = the source of truth for
//     "5 standard folders" = its first 5 cases).
//   - The destination is `bookFolder(BookFolder)`
//     or `referenceLibrary` (= the same v2.6 split).
//   - Every Codable + Sendable type here is the wire contract
//     (= the conductor hands these across actor boundaries).
//

import Foundation

// MARK: - Destination (where the LLM routed the file)

/// The final landing site for an imported .md file. The
/// Librarian's "import" system prompt picks one of these per
/// file; = the ImportService writes the body verbatim to the
/// matching directory.
enum ImportDestination: Codable, Sendable, Hashable {
    /// A book folder (= one of the 8 case roles under a book
    /// in the user's library; = `BookFolder` is
    /// the canonical 8-case enum; = the 5 user-visible
    /// standard folders are its first 5 cases).
    /// The body lands at
    /// `<shelvesRoot>/<shelfId>/books/<bookId>/<bookFolder.directoryName>/<uuid>.md`.
    case bookFolder(BookFolder)
    /// The reference library (= the cross-book shared knowledge
    /// store at `<wsRoot>/reference-library/`). The body lands
    /// at `<wsRoot>/reference-library/entities/<uuid>.md` and
    /// the Reference is appended to `entities/entities.json`.
    case referenceLibrary
}

// MARK: - ImportFileInput (the wire request to the agent)

/// What the user picked (= the source file path + the target
/// book). Sent verbatim to the Librarian; = the agent reads
/// the file body from `filePath` and decides where to route.
struct ImportFileInput: Codable, Sendable, Hashable {
    /// Absolute path to the source .md file. The agent reads
    /// the file body from here (= the body is never copied
    /// into a long-lived Data blob; = see spec "Further Notes"
    /// on the 200+ MB source-directory memory budget).
    let filePath: String
    /// v2.7 round-36 (= boss 2026-10-09 "在红
    /// 字后面，加一个小操作文字，
    /// 就是基于标题重新调研" directive).
    /// Optional body override (= the
    /// orchestrator pre-constructed a body
    /// string from the filename + sibling
    /// .md names = the LLM can produce
    /// metadata + `.ws`-format body without
    /// ever reading the source file; = the
    /// canonical use case is "the source
    /// file failed to read" = the file is
    /// unreadable on disk = the orchestrator
    /// synthesizes a body from the filename
    /// and passes it here so the LLM has
    /// something to work with).
    /// `nil` (= the pre-round-36 default; = the
    /// orchestrator's normal `importFiles`
    /// path) = the router reads the body from
    /// `filePath`.
    let body: String?
    /// Default-value init (= the
    /// pre-round-36 call sites don't supply
    /// `body`; = the existing tests and the
    /// orchestrator's `importFiles` path
    /// compile unchanged).
    init(
        filePath: String,
        targetBookId: UUID?,
        targetShelfId: UUID?,
        rewriteMode: RewriteMode,
        body: String? = nil
    ) {
        self.filePath = filePath
        self.targetBookId = targetBookId
        self.targetShelfId = targetShelfId
        self.rewriteMode = rewriteMode
        self.body = body
    }
    /// The book the user picked in the import sheet (= the
    /// `book.id` from `SidebarService.availableBooks()`).
    /// Required when the user pinned a book as the
    /// destination; = nil when the user pinned the
    /// reference library as the destination (= the boss's
    /// 2026-10-09 round-18 "强制让用户分开导入"
    /// directive; = the LLM gets a nil targetBookId +
    /// the prompt steers it away from book-folder
    /// routing).
    let targetBookId: UUID?
    /// The shelf the target book lives under (= needed to
    /// resolve the on-disk path
    /// `<shelvesRoot>/<shelfId>/books/<bookId>/<folder>/`).
    /// Nil when `targetBookId` is nil (= same reason).
    let targetShelfId: UUID?

    /// v2.7 (= boss 2026-10-09 round-18 "AI 重写
    /// 程度: 基于现有内容整理 / 重写同时重新
    /// 搜索校对"; = the user picks the LLM's
    /// effort level ONCE at sheet open; = the
    /// LLM respects the choice; = the orchestrator
    /// carries it into `writeFile` to decide
    /// whether to land the original body or the
    /// LLM-rewritten body).
    let rewriteMode: RewriteMode

    enum RewriteMode: String, Codable, Sendable, Hashable, CaseIterable {
        /// "基于现有内容整理" (= Token 节约) = the
        /// LLM does NOT call any tools; = the LLM
        /// produces metadata (title / summary /
        /// tags); = the body lands verbatim on
        /// disk (= boss 2026-10-09 "原样落地"
        /// directive).
        case consolidate
        /// "重写同时重新搜索校对" (= Token 高消耗)
        /// = the LLM is permitted to call
        /// `web_search` (= the v0.74 / WenshuAgent
        /// toolset) to find the canonical content
        /// for the entity (= the LLM searches the
        /// web for the entity name; = then the LLM
        /// rewrites the body in light of the
        /// search results; = the new body lands on
        /// disk in place of the original).
        case searchAndRewrite
        /// v2.7 round-67 (= boss 2026-10-10
        /// "LLM 偷懒了, 没有把内容重新组织, 填入
        /// 到各个必填中去, 导致所有必填都空, MD
        /// 整体还保留了原来的格式和样式" 反馈; =
        /// "我希望的是, 如果用户原文件格式是 A,
        /// 我们的模版是 B, 导入时, 重新组织 A,
        /// 符合 B" 需求). The LLM **actively
        /// reorganizes** the source A into B's
        /// template structure (= 6 H2 for world
        /// folder, 4 H2 for characters, etc.);
        /// = the LLM fills the H2 with content
        /// from A (verbatim copy or rewrite
        /// decided by the LLM); = empty H2
        /// get `[TODO: 需调研补齐]`. The LLM
        /// **may also** return `extraFiles` in
        /// the routing result (= A's content that
        /// doesn't fit B's template; = e.g. an
        /// Obsidian 故事宪法 with "七夕" event
        /// descriptions → LLM splits that into a
        /// separate 七夕.md in the same book);
        /// = extra files are routed to the same
        /// book but a different folder
        /// (= LLM decides: world / characters /
        /// outlines / chapters / drafts / ideas).
        /// = the default rewrite mode for new
        /// imports (= boss chose "LLM 决定" for
        /// A → B 重组).
        case reorganize

        var label: String {
            switch self {
            case .consolidate: return "基于现有内容整理"
            case .searchAndRewrite: return "重写同时搜索校对"
            case .reorganize: return "智能重组"
            }
        }
    }
}

// MARK: - ImportRoutingResult (the agent's reply)

/// What the Librarian returns for each file (= the LLM's
/// classification + the metadata enrichment the .ws needs
/// to surface the entity in the sidebar / preview pane).
///
/// Boss 2026-10-09 directive: "LLM 的作用只是做分类, 还
/// 有补字段" = the LLM must NOT rewrite the body. The
/// body is written verbatim from the source file
/// (= verified by byte-equal test in
/// ImportRoutingTests.testRouteAndEnrich_doesNotRewriteBody);
/// = this struct carries only the metadata fields the
/// storage layer needs beyond the raw body.
struct ImportRoutingResult: Codable, Sendable, Hashable {
    /// Where the file lands (= the LLM's routing
    /// decision; = the orchestrator's
    /// `processFile` may OVERRIDE this when the
    /// user pinned a destination in the sheet
    /// (= the boss's 2026-10-09 round-18
    /// "强制让用户分开导入" directive); = the
    /// `var` is necessary so the orchestrator
    /// can replace the LLM's classification
    /// with the user-pinned destination).
    var destination: ImportDestination
    /// Title for the entity / book doc. The agent derives
    /// this from the file's H1 (= or the first non-empty
    /// heading; = the same heuristic `EntityClassifier` and
    /// the existing `ReferenceLibraryTool` already use).
    let title: String
    /// One-line summary shown on the card (= the same
    /// `summary` field the existing `Reference` struct
    /// already exposes).
    let summary: String
    /// Free-form tags (= the v2.6 cross-cutting facet; =
    /// written to the on-disk `Reference.tags` field for
    /// reference-destination files; = written to the
    /// BookDoc's frontmatter for book-folder files).
    let tags: Set<String>
    /// Entity type (= character / location / event / etc.;
    /// = ignored for book-folder destinations per the v2.6
    /// facet model; = required for reference-destination
    /// files).
    let entityType: String
    /// Optional CLC category (= only used for reference-
    /// destination files; = nil for book-folder destinations).
    let category: String?
    /// Confidence in the routing decision (= 0.0...1.0). The
    /// sheet surfaces a "low confidence" warning for
    /// `confidence < 0.7`; = a future ticket will let the user
    /// override the routing via chat (= the `confidence`
    /// field is plumbing for that feature).
    let confidence: Double
    /// v2.7 (= boss 2026-10-09 round-18 "重写同时
    /// 搜索校对" mode). When the user picked the
    /// `searchAndRewrite` rewriteMode, the LLM is
    /// expected to search the web for the
    /// canonical content + rewrite the body; = the
    /// LLM returns the new body here (= a
    /// complete, self-contained markdown file; =
    /// the original body is replaced wholesale
    /// when this is non-nil). Nil in
    /// `consolidate` mode (= the orchestrator
    /// keeps the original body verbatim).
    let rewrittenBody: String?
    /// v2.7 round-67 (= boss 2026-10-10
    /// "甚至原文件 A 的内容, 与我们的 B
    /// 模版不符合, 多了很我非模版的内
    /// 容, 我希望能自动拆出一个文件, 放
    /// 在合适的目录中去" 反馈). When the
    /// user picked the `reorganize` rewriteMode,
    /// the LLM may return additional files
    /// (= A's content that doesn't fit B's
    /// template structure; = e.g. an Obsidian
    /// 故事宪法 with "七夕" event descriptions
    /// → the LLM splits that into a separate
    /// 七夕.md in the same book). Each element
    /// is routed to the same book (= same
    /// shelfId / bookId UUIDs) but a different
    /// folder (= the LLM-decided `BookFolder`;
    /// = the orchestrator writes to the
    /// corresponding `<bookId>/<folder.directoryName>/`
    /// path). Capped at 5 elements (= boss
    /// 烤问约束 = 防止 LLM 过度拆). Empty
    /// array (= most common case) when A
    /// fully maps to B (= no extra content).
    let extraFiles: [ExtraFile]
}

/// v2.7 round-71 (= boss 2026-10-10
/// "B" pick for
/// "⚠️ LLM 没返回
/// extraFiles" =
/// multi-turn LLM
/// calls; = the
/// previous single-LLM-
/// call approach had
/// the LLM doing 5
/// things at once
/// (= classification +
/// metadata + main
/// body + 6 必填 +
/// N 自定义) and
/// the LLM would
/// silently drop the
/// `extraFiles` array
/// (= the boss saw
/// "导入后文件没
/// 有重新组织"
/// = a single LLM
/// call with too
/// much responsibility).
/// Fix: split the
/// `reorganize` mode
/// into 3 separate
/// LLM calls (= each
/// call does 1
/// thing; = the LLM
/// can't "forget" any
/// part; = the user
/// sees each call in
/// real time via the
/// round-70
/// `activityLog`).
enum LLMCallPhase: String, Codable, Sendable, Hashable, CaseIterable {
    /// Phase 1/3 (= the FIRST LLM call
    /// in .reorganize mode). The LLM
    /// reads A, decides the
    /// destination (= skipped if
    /// the user pinned it), and
    /// returns the metadata
    /// (= title + summary + tags)
    /// + the main INDEX file body
    /// (= the `rewrittenBody`
    /// field; = metadata header
    /// + 6 必填子文件路径引用
    /// + 1 段简短概述).
    /// This phase does NOT
    /// return `extraFiles` (= the
    /// orchestrator only fills
    /// the metadata fields from
    /// this call; = phase 2/3
    /// fills the extraFiles).
    case classifyAndIndex = "phase1_classify_and_index"
    /// Phase 2/3 (= the SECOND LLM
    /// call in .reorganize mode).
    /// The LLM reads A again
    /// (= the orchestrator
    /// caches the source body
    /// in `route(input)`) and
    /// returns the 6 必填
    /// sub-files (= the 6
    /// world/ H2 sections
    /// filled with content
    /// from A). `required: true`
    /// on all 6.
    case splitRequired = "phase2_split_6_required"
    /// Phase 3/3 (= the THIRD LLM
    /// call in .reorganize mode).
    /// The LLM returns 0-5
    /// custom world/ files
    /// (= A's non-B content;
    /// = "约等于备注" per
    /// boss; = LLM names
    /// them freely). If A
    /// has nothing else,
    /// return empty array
    /// (= that's the
    /// canonical case).
    case splitCustom = "phase3_split_custom"

    /// 1-based human-readable
    /// number for the activity
    /// log (= "phase 1/3" /
    /// "phase 2/3" / "phase
    /// 3/3").
    var displayIndex: Int {
        switch self {
        case .classifyAndIndex: return 1
        case .splitRequired: return 2
        case .splitCustom: return 3
        }
    }

    /// Chinese description for
    /// the activity log.
    var displayName: String {
        switch self {
        case .classifyAndIndex: return "分类 + 元数据 + 主索引"
        case .splitRequired: return "拆 6 必填子文件"
        case .splitCustom: return "拆 N 自定义子文件"
        }
    }
}

struct ExtraFile: Codable, Sendable, Hashable {
    /// Which book folder to write this file
    /// into (= the LLM's routing decision;
    /// = constrained to the 6 `BookFolder`
    /// cases that have an `importTemplate`;
    /// = `drafts` (= 草稿) is the
    /// safest default for ambiguous content).
    let folder: BookFolder
    /// Human-readable title for the new file
    /// (= used as the on-disk filename stem
    /// AND as the BookDoc card title; =
    /// sanitized against path-unsafe
    /// characters at write time; = max 30
    /// Chinese chars per the LLM prompt; =
    /// empty / unsafe-only title falls back
    /// to a UUID prefix).
    let title: String
    /// Full markdown body for the new file
    /// (= the LLM-supplied content; =
    /// stripped of Obsidian backlinks at
    /// write time; = no frontmatter
    /// required).
    let body: String
    /// v2.7 round-69 (= boss 2026-10-10
    /// "6 份必填, 其它不在
    /// 6 份里的, 可以自
    /// 定义名字" feedback).
    /// True = this is one of
    /// the 6 mandatory
    /// world/ sub-files
    /// (= filename = H2
    /// title, = wenshu
    /// canonical). False
    /// = this is a custom
    /// world/ file (= LLM
    /// chose the title =
    /// e.g. "十二生肖原
    /// 型" / "元炁体系"
    /// / "时间线" etc.;
    /// = "约等于备注" per
    /// boss; = no fixed
    /// filename, = LLM
    /// names them
    /// freely). The 6
    /// mandatory ones
    /// always get priority
    /// in the orchestrator
    /// (= if the LLM
    /// returns 11+
    /// elements, we keep
    /// the first 6 required
    /// + up to 5 custom).
    let required: Bool
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
/// The Phase 2
/// LLM-driven
/// content-same
/// decision (= the
/// LLM compares
/// the source body
/// against an
/// existing file's
/// body and
/// reports whether
/// they are
/// "the same
/// content";
/// = the
/// orchestrator
/// uses this to
/// decide between
/// `.skipped` (=
/// same content,
/// no write) and
/// `.done` (=
/// different
/// content,
/// overwrite the
/// existing file)).
/// This is a
/// separate envelope
/// from
/// `ImportRoutingResult`
/// because the
/// Phase 2 LLM call
/// is OPT-IN (= only
/// fires when
/// Phase 1 found a
/// same-titled
/// file in the
/// destination
/// folder; = most
/// imports skip
/// Phase 2
/// entirely).
struct ContentSameResult: Codable, Sendable, Hashable {
    /// Whether the
    /// source body and
    /// the existing
    /// body are the
    /// "same content"
    /// (= the LLM's
    /// binary decision;
    /// = the LLM
    /// returns true
    /// when the two
    /// bodies are
    /// semantically
    /// the same; =
    /// false when
    /// they differ in
    /// any meaningful
    /// way).
    let isContentSame: Bool
    /// The LLM's
    /// confidence in
    /// the decision
    /// (= 0.0...1.0).
    /// Above
    /// `ImportDocumentTemplates.contentSameConfidenceThreshold`
    /// (= 0.7) = trust
    /// the LLM and
    /// skip the
    /// write; below
    /// = the orchestrator
    /// overwrites
    /// (= conservative
    /// = the user
    /// would rather
    /// see a fresh
    /// import than
    /// a false skip).
    let confidence: Float
    /// The LLM's brief
    /// reasoning (= shown
    /// to the user in
    /// the sheet's
    /// per-row result;
    /// = a short Chinese
    /// sentence like
    /// "内容完全相同"
    /// or "existing 多
    /// 了一段新内容").
    let reasoning: String
}

// MARK: - ImportEnvelope (the wire envelope)

/// Discriminated union of wire envelopes the user can
/// trigger from the GUI. Today: only `.importFile`. The
/// shape mirrors `ReferenceLibraryTool.Input` (= the
/// existing reference-write envelope) so the conductor
/// can dispatch with a single switch.
enum ImportEnvelope: Codable, Sendable, Hashable {
    case importFile(ImportFileInput)

    // MARK: Wire format

    private enum CodingKeys: String, CodingKey {
        case kind
        case filePath, targetBookId, targetShelfId, rewriteMode
    }

    private enum Kind: String, Codable, Sendable {
        case importFile
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .importFile(let input):
            try c.encode(Kind.importFile, forKey: .kind)
            try c.encode(input.filePath, forKey: .filePath)
            try c.encode(input.targetBookId, forKey: .targetBookId)
            try c.encode(input.targetShelfId, forKey: .targetShelfId)
            try c.encode(input.rewriteMode, forKey: .rewriteMode)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .importFile:
            let filePath = try c.decode(String.self, forKey: .filePath)
            let bookId = try c.decode(UUID.self, forKey: .targetBookId)
            let shelfId = try c.decode(UUID.self, forKey: .targetShelfId)
            // v2.7 backwards-compat (= if a pre-v2.7
            // envelope omits `rewriteMode`, default to
            // `consolidate`; = the orchestrator's
            // pre-v2.7 behavior = no tools + original
            // body verbatim).
            let rewriteMode = (try? c.decode(ImportFileInput.RewriteMode.self, forKey: .rewriteMode)) ?? .consolidate
            self = .importFile(ImportFileInput(
                filePath: filePath,
                targetBookId: bookId,
                targetShelfId: shelfId,
                rewriteMode: rewriteMode
            ))
        }
    }
}
