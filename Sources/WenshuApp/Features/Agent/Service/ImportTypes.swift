//
//  ImportTypes.swift
//
//  Pure data types for the markdown import feature (= ImportFileType enum +
//  ImportTaskState enum + ImportTask struct + ImportServiceError enum).
//  All Sendable (= cross-actor safe; = the per-file pipeline mutates
//  ImportTask fields from 5 parallel TaskGroup tasks; = no data race).
//

import Foundation
import UniformTypeIdentifiers

// MARK: - ImportTask (per-file state)

/// One task per file (= the unit of progress shown in
/// the sheet's per-file strip). The state machine is
/// linear:
//   pending → routing → writing → done
///                        ↘ failed
///                        ↘ skipped (= idempotent re-import
///                                   hit the cache; = no LLM
///                                   dispatch; = the source
///                                   file is byte-equal to
///                                   a previously-imported
///                                   file)
/// The file-type filter the user picked in the
/// import sheet (= the user's 2026-10-09 ask: "在
/// 目录树上一行，加一行文件类型图标，单选"; = the
/// how to walk + write
/// Markdown; = the .epub / .pdf / .txt cases are
/// rendered as "coming soon" in the picker UI; = a
/// future ticket can flip `isSupported` once the
/// orchestrator's walk + write paths handle them).
///
/// Apple canonical pattern: closed enum with a
/// canonical `extensions: Set<String>` per case (= the
/// orchestrator's `walkSourceDir` takes the
/// extension set as a parameter; = adding a new
/// file type forces a single source-of-truth change
/// at the type-definition site; = no string matching
/// at the call site = "make illegal states
/// unrepresentable").
enum ImportFileType: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case markdown
    case epub
    case pdf
    case text

    var id: String { rawValue }

    /// Chinese display name for the picker row
    /// (= the user's primary locale is .chinese;
    /// = the picker row's `Text(type.displayName)`
    /// is the visible label).
    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .epub:     return "EPUB 电子书"
        case .pdf:      return "PDF"
        case .text:     return "纯文本"
        }
    }

    /// The SF Symbol name for the row's leading
    /// icon (= Apple HIG canonical "leading icon"
    /// for a picker row; = the wenshu design
    /// system uses the `SFIcon` central factory; =
    /// no naked `Image(systemName:)`).
    var iconName: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .epub:     return "book.closed"
        case .pdf:      return "doc.fill"
        case .text:     return "doc.plaintext"
        }
    }

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// (= 重新设计文案)"
    /// directive). The
    /// placeholders are
    /// shortened to fit
    /// the row without
    /// truncation (= the
    /// sheet's
    /// 源目录 row
    /// has a fixed
    /// "选择…" button
    /// on the right;
    /// = the available
    /// width for the
    /// Text is
    /// limited; = the
    /// previous hints
    /// were long enough
    /// to be truncated
    /// in the middle;
    /// = the middle
    /// truncation hid
    /// the file
    /// extension; = the
    /// boss's exact
    /// critique "其实
    /// 应该是 .md
    /// 吧？"). The new
    /// hints are 9-11
    /// characters (= fit
    /// in the available
    /// space at body
    /// text size; =
    /// no truncation
    /// needed). The hint
    /// is still
    /// "选择一个目录"
    /// (= the action)
    /// + the file type
    /// extension
    /// (= the type of
    /// file the walker
    /// will import).
    var placeholderHint: String {
        switch self {
        case .markdown: return "选目录 (.md)"
        case .epub:     return "选目录 (.epub)"
        case .pdf:      return "选目录 (.pdf)"
        case .text:     return "选目录 (.txt)"
        }
    }

    /// the file
    /// extension list (= what
    /// `walkSourceDir` filters on;
    /// = the placeholder + the
    /// walker agree on the same
    /// extension list; = the user
    /// can't pick a PDF when the
    /// walker only knows .md).
    /// Returns a small set of
    /// extensions; = e.g. for
    /// .epub = ["epub"]; = for
    /// .markdown = ["md",
    /// "markdown"]; = the walker
    /// is case-insensitive
    /// (`FileManager.enumerator`
    /// normalizes the
    /// comparison; = the user
    /// can have
    /// `Notes.MD` /
    /// `Notes.Md` / `Notes.md`
    /// and they all get
    /// walked).
    ///  when the orchestrator can
    /// import this file type end-to-end (= the
    /// walker + writer both understand it; = a
    /// false value means the picker row renders
    /// the "（即将支持）" hint and the user can't
    /// pick it for an import run).
    var isSupported: Bool {
        switch self {
        case .markdown: return true
        case .epub, .pdf, .text: return false
        }
    }

    /// The file extensions the walker should
    /// match (= lower-cased; = the walker compares
    /// against `url.pathExtension` lower-cased too;
    /// = a Markdown file with a `.markdown`
    /// extension is matched; = a `.mdown` /
    /// `.mkd` is matched; = a future file type can
    /// add multiple extensions here without
    /// touching the walker).
    var extensions: Set<String> {
        switch self {
        case .markdown: return ["md", "markdown", "mdown", "mkd"]
        case .epub:     return ["epub"]
        case .pdf:      return ["pdf"]
        case .text:     return ["txt"]
        }
    }

    /// the
    /// `UTType` array
    /// used by
    /// `NSOpenPanel.allowedContentTypes`
    /// to filter the
    /// file picker's
    /// selectable
    /// files (= the
    /// Apple canonical
    /// way to filter
    /// an open panel
    /// by content
    /// type; = the
    /// user sees only
    /// the file types
    /// the walker
    /// understands; =
    /// `UTType.text` is
    /// the umbrella
    /// for plain text
    /// + markdown; =
    /// `UTType.pdf` for
    /// PDF; =
    /// `UTType.epub` is
    /// derived from
    /// the EPUB
    /// filename
    /// extension).
    var allowedContentTypes: [UTType] {
        switch self {
        case .markdown:
            return [UTType(filenameExtension: "md") ?? .plainText,
                    UTType(filenameExtension: "markdown") ?? .plainText]
        case .epub:
            return [UTType(filenameExtension: "epub") ?? .data]
        case .pdf:
            return [.pdf]
        case .text:
            return [.plainText, .text]
        }
    }
}

enum ImportTaskState: String, Codable, Sendable, Hashable {
    case pending
    case routing
    case writing
    case done
    case failed
    case skipped
}

/// What the orchestrator hands to the sheet (= one row
/// per file in the sheet's progress strip). The sheet
/// binds a `[ImportTask]` and re-renders on each state
/// transition.
struct ImportTask: Identifiable, Sendable, Hashable {
    let id: UUID
    /// Absolute path to the source .md file (= the row's
    /// filename comes from `URL(fileURLWithPath: sourcePath).lastPathComponent`).
    let sourcePath: String
    /// Where the task ended up (= populated at the
    /// `done` / `failed` / `skipped` transitions; = nil while
    /// pending / routing / writing).
    var destination: ImportDestination?
    /// Body SHA-256 (= the dedup key; = the orchestrator
    /// stores the hash before the routing step so the
    /// idempotent re-import can short-circuit before the
    /// LLM dispatch).
    var contentHash: String
    /// The task's current state (= mutated by the
    /// orchestrator; = read by the sheet for the per-file
    /// progress strip).
    var state: ImportTaskState
    /// Optional error message (= populated when `state ==
    /// .failed`; = the sheet renders it inline next to
    /// the row).
    var errorMessage: String?
    /// the
    /// reason the task was
    /// `.skipped` (= shown
    /// inline next to the
    /// row when state is
    /// `.skipped`; = the
    /// canonical "已跳过
    /// - 内容相同" message
    /// comes from the
    /// Phase 2 LLM
    /// content-same
    /// decision; = the
    /// "已跳过 - 同名
    /// 已重试" message
    /// from the title-only
    /// retry path; = nil
    /// for `.done` /
    /// `.failed` / in-
    /// flight states).
    var skippedReason: String?
    /// Routing result from the LLM (= populated when `state
    /// >= .writing`; = cached for the sheet's low-confidence
    /// warning indicator).
    var routing: ImportRoutingResult?
    /// ticket 04 (= boss
    /// 2026-10-10 "甚至原文
    /// 件 A 的内容, 与我们
    /// 的 B 模版不符合, 多
    /// 了很我非模版的内容,
    /// 我希望能自动拆出一个
    /// 文件, 放在合适的目
    /// 录中去" feedback).
    /// Number of extra files
    /// (= the LLM-suggested
    /// split-out files for
    /// A's non-B content).
    /// Default = 0 (= no
    /// extras; = the
    /// canonical case for
    /// A → B mappings
    /// where the entire
    /// source fits the
    /// template). Bumped
    /// by the orchestrator
    /// before the extraFiles
    /// loop.
    var extraFilesTotal: Int = 0
    /// Number of extra files
    /// successfully written
    /// (= 0 .. extraFilesTotal).
    /// Bumped in the
    /// orchestrator's
    /// extraFiles loop. (= the
    /// per-file progress
    /// strip shows "1 主 + N
    /// 拆出").
    var extraFilesDone: Int = 0
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
        /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// feedback). Real-time
    /// LLM activity log
    /// (= the orchestrator
    /// appends short human-
    /// readable messages as
    /// the LLM pipeline
    /// progresses; = the
    /// sheet shows the log
    /// in the row as a
    /// scrolling terminal-
    /// like view; = gives
    /// the user visible
    /// feedback for "what
    /// the LLM is doing
    /// right now"). Examples
    /// (= Chinese):
    /// - "读取源文件 23 KB"
    /// - "调用 LLM 分类 + 重组"
    /// - "LLM 返回: title=..., tags=[...]"
    /// - "LLM 返回: 6 必填 + 3 自定义子文件"
    /// - "写主文件: world/故事宪法.md (2.1 KB)"
    /// - "写子文件 1/9: world/核心设定.md (0.3 KB)"
    /// - "写子文件 2/9: world/地理或位置.md (0.2 KB)"
    /// - "..." (= 1 line per step)
    /// Capped at 30 entries
    /// (= the old entries
    /// drop off; = prevents
    /// unbounded memory
    /// growth; = 30 lines is
    /// enough to show
    /// the recent activity
    /// without scrolling
    /// forever).
    var activityLog: [String] = []
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// (= phase 1/2/3) is
    /// currently running).
    /// nil = no LLM call
    /// yet (= before
    /// phase 1); = a
    /// non-nil value
    /// means "this LLM
    /// call is currently
    /// active" (= useful
    /// for the sheet UI
    /// to show a
    /// progress
    /// indicator on the
    /// specific phase).
    init(sourcePath: String) {
        self.id = UUID()
        self.sourcePath = sourcePath
        self.destination = nil
        self.contentHash = ""  // populated at the read step
        self.state = .pending
        self.errorMessage = nil
        self.skippedReason = nil
        self.routing = nil
        self.extraFilesTotal = 0
        self.extraFilesDone = 0
        self.activityLog = []
    }
}
