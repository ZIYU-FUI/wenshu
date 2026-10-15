//
//  ImportTargets.swift
//
//  Per-import destination metadata (= the file-system dependencies the
//  orchestrator needs but doesn't own; = the caller supplies these handles
//  at `ImportService.importFiles(in:into:router:)` call time).
//

import Foundation

// MARK: - ImportTarget (the import destination metadata)

/// What the sheet passes to ImportService (= the user's
/// picked book + the shelvesRoot + the referenceStore
/// handle for the reference-library path). Holds the
/// file-system dependencies (= the orchestrator is
/// stateless but the storage layer is not; = the
/// caller supplies the storage handles here).
struct ImportTarget: Sendable {
    /// Where the orchestrator should land the imported
    /// files (= boss 2026-10-09 (see OOB.md #2026-10-09)
    /// reduced to a metadata-only role (= title
    /// + summary + tags; = the destination
    /// itself is user-pinned)).
    let destination: ImportTargetDestination
    /// The .ws library root (= the same root that
    /// `LibraryLifecycleHook` constructed; = the single
    /// source of truth for "where the user's library is").
    let wsRoot: URL
    /// The book the user picked (= the book.id from
    /// `SidebarService.availableBooks()`). Nil when
    /// `destination == .referenceLibrary` (= the user
    /// picked the reference library as the target; = no
    /// book is involved).
    let bookId: UUID?
    /// The shelf the target book lives under. Nil when
    /// `destination == .referenceLibrary` (= same
    /// reason as `bookId`).
    let shelfId: UUID?
    /// (= boss
    /// 2026-10-10 "用
    /// 户在
    /// 导入
    /// 书的
    /// 时候，
    /// 要选
    /// 择二
    /// 级目
    /// 录
    /// ...
    /// 让用
    /// 户来
    /// 决定
    /// 哪
    /// 些是
    /// 世界
    /// 观，
    /// 哪
    /// 些是
    /// 角色
    /// " 反馈).
    /// The user-picked
    /// book folder (= the
    /// "二级目录"
    /// option in the
    /// sheet; = the
    /// sheet now shows a
    /// folder picker
    /// after the book
    /// picker; = the
    /// user picks ONE
    /// of the 6 import
    /// folders:
    /// world / characters
    /// / outlines /
    /// chapters / drafts
    /// / ideas). When
    /// `target.destination
    /// == .book` AND
    /// `bookFolder` is
    /// non-nil, the
    /// orchestrator
    /// forces
    /// `routing.destination
    /// = .bookFolder(bookFolder)`
    /// (= the LLM's
    /// classification is
    /// ignored; = the
    /// user is the source
    /// of truth). Nil
    /// when
    /// `destination ==
    /// .referenceLibrary`
    /// (= reference library
    /// has no folder
    /// hierarchy; = every
    /// file lands at the
    /// flat reference
    /// library root).
    let bookFolder: BookFolder?
    /// The reference library's `ReferenceStoring` (= the
    /// existing storage handle; = passed in by the
    /// `LibraryStores` factory at launch).
    let referenceStore: any ReferenceStoring

    /// (= boss 2026-10-09 (see OOB.md #2026-10-09)
    /// 程度"). The user-picked rewrite mode; = the
    /// orchestrator reads this in `processFile` and
    /// forwards to the LLM router (= the LLM
    /// either runs the consolidate path with no
    /// tools OR the searchAndRewrite path with
    /// the `web_search` tool loop).
    let rewriteMode: ImportFileInput.RewriteMode

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// directive). The user-picked
    /// parallelism for the 5-way
    /// concurrent LLM dispatch loop.
    /// Range: 1..5 (the boss's five
    /// options; = the user picks
    /// ONCE in the sheet). The LLM
    /// provider's rate limit is the
    /// upper bound (= 1 = most
    /// conservative; = 5 = the
    /// historical default). Boss's
    /// default: 3 (= the middle
    /// option; = a safe rate for
    /// most LLM providers; = the
    /// tradeoff between throughput
    /// and rate-limit risk). The
    /// orchestrator reads this in
    /// `importFiles` and
    /// `retryFailedTasksTitleOnly`
    /// to size the TaskGroup's seed
    /// + drain loop (= the in-flight
    /// count is capped at
    /// `target.maxParallel`).
    let maxParallel: Int

    enum ImportTargetDestination: Sendable, Equatable {
        case book              // → LLM picks world/characters/outlines/chapters/drafts
        case referenceLibrary  // → everything lands in the reference library
    }

    /// Standard library layout (= matches
    /// `LibraryStores.shelvesRoot`).
    var shelvesRoot: URL {
        wsRoot.appendingPathComponent("shelves")
    }
    /// Per-library import cache (= the sidecar that
    /// powers the idempotent re-import).
    var cacheRoot: URL {
        wsRoot.appendingPathComponent(".import-cache")
    }

    /// custom init that defaults
    /// `maxParallel` to 3 (= the boss's "默认
    /// 选3" directive). Synthesized memberwise
    /// init would require every call site to
    /// pass `maxParallel:` explicitly (= 5
    /// call sites; = brittle to the next
    /// `ImportTarget` field addition; = the
    /// custom init keeps existing call sites
    /// compiling).
    init(
        destination: ImportTargetDestination,
        wsRoot: URL,
        bookId: UUID?,
        shelfId: UUID?,
        referenceStore: any ReferenceStoring,
        rewriteMode: ImportFileInput.RewriteMode,
        maxParallel: Int = 3,
        // 
        // `bookFolder` is a new
        // optional field
        // (= the user-picked
        // 2nd-level folder
        // for the book
        // destination; =
        // nil = the old
        // "LLM picks" /
        // "drafts fallback"
        // behavior; = the
        // default keeps all
        // existing call
        // sites compiling).
        // Callers that want
        // the user-pinned
        // 2nd-level folder
        // (= ImportSheet)
        // pass a non-nil
        // value.
        bookFolder: BookFolder? = nil
    ) {
        // Clamp to the supported range (= 1..5;
        // = the Picker UI exposes these five
        // options; = the sheet's `maxParallel`
        // `@State` is constrained to the
        // same range; = out-of-range values
        // (= 0 / 6 / negative) would cause the
        // TaskGroup loop to either spin (5) or
        // never seed (0); = the clamp is
        // defensive).
        self.destination = destination
        self.wsRoot = wsRoot
        self.bookId = bookId
        self.shelfId = shelfId
        self.referenceStore = referenceStore
        self.rewriteMode = rewriteMode
        self.maxParallel = Swift.max(1, Swift.min(5, maxParallel))
        self.bookFolder = bookFolder
    }
}
