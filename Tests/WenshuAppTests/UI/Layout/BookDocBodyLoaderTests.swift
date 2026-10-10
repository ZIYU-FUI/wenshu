// BookDocBodyLoaderTests.swift
//
// v2.7 round-66 commit H (= boss 2026-10-10
// "指定目录实现了，但导入的内容少了好我" 反馈).
// The previous `CardOpenOps.computeCardTriad`
// returned only `doc.summary` (= 200-char
// preview prefix) for `.bookDoc` cards, with a
// comment deferring real body loading to "ticket
// 027-35". This commit implements that ticket:
// the helper now reads the full .md file from
// disk by walking the shelves root to find the
// file matching the BookDoc's UUID v5 (= the same
// path resolution as `SidebarService.findBookDocFile`).
//
// These tests use the URL-based overload
// (= no need to construct a full BookStore stub).

import XCTest
@testable import WenshuApp

@MainActor
final class BookDocBodyLoaderTests: XCTestCase {

    /// v2.7 round-66 commit H: the
    /// helper finds the
    /// book doc on disk
    /// and returns the
    /// full .md body
    /// (= not the
    /// 200-char summary).
    func testLoadBookDocBodyReturnsFullContent() throws {
        // Set up a temp shelves tree
        // that matches the
        // real wenshu layout
        // (= shelves/<shelf-uuid>/books/<book-uuid>/<folder>/<file>.md).
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-bookdoc-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: wsRoot, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: wsRoot) }
        let bookId = UUID()
        let folder = "world"
        let fileName = "故事宪法.md"
        let folderURL = wsRoot
            .appendingPathComponent("shelves")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(bookId.uuidString)
            .appendingPathComponent(folder)
        try FileManager.default.createDirectory(
            at: folderURL, withIntermediateDirectories: true
        )
        let body = """
        # 故事宪法 v13（已加 20 节"现代知识应用守则"）

        ## 0. 项目母本

        - 本文档 = 整部小说的世界观 / 风格 / 节奏 / 核心设定的母本
        - 所有 13 份主角团档案、所有调研、所有大纲、最终所有正文——都从本文档推
        - 修改本文档 = 改基线 = 改整部小说
        - 修改历史：v1-v6 = 早期讨论；v7 = 加入"民俗神不路过"；v8 = 加入"民国去文字化平行世界"；v9 = 加入"蛇是宋慈上一代"；v10 = 爷爷 1945 生，退休法医；v11 = 收忆者 = 五大家族；v12 = 当前——家传三代链条断在 4 岁多；v13 = 加 20 节"现代知识应用守则"——3 不可越线 + 3 应用方向 + 5 应用原则 + 12 卷应用清单 + 1 核心原则

        ## 1. 架空点（核心设定）

        **真实历史的一个分叉**：

        > 如果民国新文化运动真的把汉字废了，会怎样？

        - 新文化运动的那一派人——钱玄同 / 胡适 / 吴稚晖 / 瞿秋白 / 傅斯年——他们的主张真的成功了
        - 汉字被废——汉语拼音化
        - 其他一切都照常：抗战照打、49 年新中国成立（点一下架空不写）、改革开放照走

        ## 2. 12 节弧线

        整部小说按 12 卷展开 = 12 节 = 1 主角 1 民俗神 1 卷 = 12 个独立故事，又互为前后。
        """
        let fileURL = folderURL.appendingPathComponent(fileName)
        try body.write(to: fileURL, atomically: true, encoding: .utf8)
        // Build the BookDoc (= the
        // editor passes this
        // to computeCardTriad).
        let docId = PreviewPane.stableBookDocId(
            bookId: bookId,
            folderName: folder,
            fileName: fileName
        )
        let doc = BookDoc(
            id: docId,
            bookId: bookId,
            folderName: folder,
            fileName: fileName,
            modifiedAt: Date(),
            createdAt: Date(),
            body: String(body.prefix(200))
        )
        // The shelvesRoot is the
        // `shelves/` dir (= the
        // orchestrator's
        // `target.shelvesRoot`
        // = the constant
        // root for book
        // storage). Path:
        // wsRoot/shelves
        // (= 4 levels up from
        // folderURL: folder →
        // <bookId> → books →
        // <shelf>).
        let shelvesRoot = folderURL
            .deletingLastPathComponent() // books/
            .deletingLastPathComponent() // <bookId>/
            .deletingLastPathComponent() // <shelf-uuid>/
            .deletingLastPathComponent() // shelves/
        let loaded = CardOpenOps.loadBookDocBody(shelvesRoot: shelvesRoot, doc: doc)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, body)
        // Specifically NOT the
        // 200-char summary.
        XCTAssertTrue(loaded!.count > 200, "expected full body, got summary-sized chunk")
        XCTAssertTrue(loaded!.contains("## 1. 架空点"), "expected full body to include the H2 sections")
    }

    /// v2.7 round-66 commit H: when
    /// the file is gone
    /// (= the user
    /// deleted it
    /// after the card
    /// was generated),
    /// the helper
    /// returns nil (=
    /// the caller falls
    /// back to
    /// `doc.summary`).
    func testLoadBookDocBodyReturnsNilWhenFileMissing() throws {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-bookdoc-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: wsRoot, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: wsRoot) }
        let bookId = UUID()
        let folder = "world"
        let fileName = "ghost.md"
        let docId = PreviewPane.stableBookDocId(
            bookId: bookId,
            folderName: folder,
            fileName: fileName
        )
        let doc = BookDoc(
            id: docId,
            bookId: bookId,
            folderName: folder,
            fileName: fileName,
            modifiedAt: Date(),
            createdAt: Date(),
            body: "ghost"
        )
        // Don't create the file
        // (= the test is
        // "file is gone").
        let loaded = CardOpenOps.loadBookDocBody(shelvesRoot: wsRoot, doc: doc)
        XCTAssertNil(loaded)
    }

    /// v2.7 round-66 commit H: when
    /// the bookId in the
    /// BookDoc doesn't
    /// match any
    /// directory on
    /// disk (= the book
    /// was deleted
    /// between the
    /// card creation
    /// and the open),
    /// the helper
    /// returns nil.
    func testLoadBookDocBodyReturnsNilWhenBookDirMissing() throws {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-bookdoc-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: wsRoot, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: wsRoot) }
        let docId = PreviewPane.stableBookDocId(
            bookId: UUID(),
            folderName: "world",
            fileName: "ghost.md"
        )
        let doc = BookDoc(
            id: docId,
            bookId: UUID(),
            folderName: "world",
            fileName: "ghost.md",
            modifiedAt: Date(),
            createdAt: Date(),
            body: "ghost"
        )
        // No shelves/<shelf>/books/<bookId> directory exists
        let loaded = CardOpenOps.loadBookDocBody(shelvesRoot: wsRoot, doc: doc)
        XCTAssertNil(loaded)
    }
}
