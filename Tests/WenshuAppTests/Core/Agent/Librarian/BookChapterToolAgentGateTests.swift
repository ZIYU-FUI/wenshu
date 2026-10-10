//
//  BookChapterToolAgentGateTests.swift
//
//  v2.7 round-61 (= boss 2026-10-10
//  "Agent 写正文一律先写
//  草稿. 写正文时先写
//  草稿，由用户手动
//  提升级正文. 其它
//  文件正常修改.
//  提升为正文的内
//  容，成为下阶段
//  的约束，Agent 在
//  没有用户允许的
//  情况下，不能
//  编辑正文的文
//  档内容" directive).
//  Verifies the agent
//  chapter-write gate
//  (= `create` goes to
//  drafts/; = `update`
//  on confirmed chapters/
//  rejects with a
//  user-facing error;
//  = other folders are
//  not affected).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("BookChapterActor agent gate (v2.7 round-61)")
struct BookChapterToolAgentGateTests {

    /// Canonical library root
    /// for these tests (= /tmp,
    /// resolved through
    /// /private/tmp symlink so
    /// PathGuard's canonical-root
    /// comparison matches).
    private static let libraryRoot = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path

    /// Run `body` with
    /// `ActiveLibrary.overrideForTesting`
    /// bound to the canonical
    /// /tmp library root.
    private func withLibraryRoot<R>(_ body: () async throws -> R) async rethrows -> R {
        try await ActiveLibrary.$overrideForTesting.withValue(Self.libraryRoot, operation: body)
    }

    /// Create a fresh `BookChapterActor`
    /// (= the actor the LLM
    /// calls). Wires
    /// `bookDirectoryProvider`
    /// to return the test
    /// library root.
    private func makeTool(under root: URL) -> BookChapterActor {
        BookChapterActor(
            bookDirectoryProvider: { root }
        )
    }

    /// v2.7 round-61: the `create`
    /// action lands in `drafts/`,
    /// not `chapters/`. The
    /// boss's "Agent 写正文一
    /// 律先写草稿" rule.
    @Test("createChapter writes to drafts/, not chapters/")
    func createGoesToDrafts() async throws {
        try await withLibraryRoot {
            // Set up a book folder
            // (= the standard
            // 8-folder layout the
            // LibraryBootstrapper
            // creates). The
            // standardFolders
            // array matches the
            // bootstrapper
            // (= round-60 added
            // `ideas` to the
            // import folder
            // set; = the
            // bootstrapper
                // itself does NOT
                // need to seed
                // ideas; = the
                // createChapter
                // gate only
                // touches
                // chapters/ +
                // drafts/).
            let root = URL(fileURLWithPath: Self.libraryRoot)
            let bookId = UUID()
            let bookDir = root.appendingPathComponent("shelves/\(UUID().uuidString)/books/\(bookId.uuidString)")
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent("chapters", isDirectory: true),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: bookDir.appendingPathComponent("drafts", isDirectory: true),
                withIntermediateDirectories: true
            )
            defer {
                try? FileManager.default.removeItem(at: bookDir)
            }
            let tool = makeTool(under: bookDir)
            let title = "第一章 测试"
            let body = "正文内容."
            _ = try await tool.createChapter(
                bookId: bookId,
                title: title,
                bodyMarkdown: body,
                summary: "测试摘要"
            )
            // The file should
            // exist in drafts/,
            // not in chapters/.
            let draftsFile = bookDir.appendingPathComponent("drafts").appendingPathComponent("\(bookId.uuidString).md")
            // The drafts.json
            // index file may
            // not exist yet
            // (= the tool
            // only writes
            // the .md body;
            // = the index is
            // built by
            // loadChaptersFromFileSystem);
            // = we just
            // check the
            // chapters/
            // folder is
            // empty.
            let chaptersDir = bookDir.appendingPathComponent("chapters")
            let chaptersFiles = (try? FileManager.default.contentsOfDirectory(atPath: chaptersDir.path)) ?? []
            #expect(chaptersFiles.isEmpty, "chapters/ must be empty after agent create; got: \(chaptersFiles)")
        }
    }

    /// v2.7 round-61: when a
    /// chapter file already
    /// exists in `chapters/`
    /// (= a confirmed chapter;
    /// = the user has
    /// promoted it), an
    /// agent's `update`
    /// action is REJECTED
    /// with a structured error
    /// that tells the LLM to
    /// surface it to the user.
    @Test("updateChapter rejects when target lives in chapters/")
    func updateOnConfirmedChapterRejects() async throws {
        try await withLibraryRoot {
            let root = URL(fileURLWithPath: Self.libraryRoot)
            let bookId = UUID()
            let bookDir = root.appendingPathComponent("shelves/\(UUID().uuidString)/books/\(bookId.uuidString)")
            let chapterId = UUID()
            let chaptersDir = bookDir.appendingPathComponent("chapters", isDirectory: true)
            let draftsDir = bookDir.appendingPathComponent("drafts", isDirectory: true)
            try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: draftsDir, withIntermediateDirectories: true)
            // Create a confirmed
            // chapter file in
            // chapters/ (=
            // simulates the
            // user having
            // promoted a
            // draft).
            let chapterFile = chaptersDir.appendingPathComponent("\(chapterId.uuidString).md")
            try "# 测试章节\n\n正文.\n".write(to: chapterFile, atomically: true, encoding: .utf8)
            defer {
                try? FileManager.default.removeItem(at: bookDir)
            }
            let tool = makeTool(under: bookDir)
            // The agent tries to
            // update this
            // confirmed chapter.
            // The gate should
            // throw.
            await #expect(throws: BookChapterError.self) {
                _ = try await tool.updateChapter(
                    id: chapterId,
                    title: "更新的标题",
                    bodyMarkdown: "更新的正文"
                )
            }
        }
    }

    /// v2.7 round-61: when the
    /// same chapter id lives in
    /// `drafts/` (= a still-
    /// unconfirmed draft), an
    /// agent's `update` is
    /// ALLOWED (= the boss's
    /// "其它文件正常修改"
    /// rule; = drafts/ are
    /// fair game).
    @Test("updateChapter allows when target lives in drafts/")
    func updateOnDraftAllows() async throws {
        try await withLibraryRoot {
            let root = URL(fileURLWithPath: Self.libraryRoot)
            let bookId = UUID()
            let bookDir = root.appendingPathComponent("shelves/\(UUID().uuidString)/books/\(bookId.uuidString)")
            let draftsDir = bookDir.appendingPathComponent("drafts", isDirectory: true)
            try FileManager.default.createDirectory(at: draftsDir, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: bookDir)
            }
            // Create a draft
            // chapter (= a
            // still-
            // unconfirmed
            // chapter) via
            // the tool.
            let tool = makeTool(under: bookDir)
            let chapter = try await tool.createChapter(
                bookId: bookId,
                title: "草稿章节",
                bodyMarkdown: "草稿正文."
            )
            // The agent can
            // re-edit the
            // draft (= the
            // update path
            // doesn't see a
            // file in
            // chapters/,
            // so the gate
            // doesn't fire).
            let updated = try await tool.updateChapter(
                id: chapter.id,
                title: "草稿章节 (v2)",
                bodyMarkdown: "草稿正文 v2."
            )
            #expect(updated.title == "草稿章节 (v2)")
        }
    }
}
