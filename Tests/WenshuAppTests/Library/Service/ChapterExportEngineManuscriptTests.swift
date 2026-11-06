//
//  ChapterExportEngineManuscriptTests.swift
//  wenshu
//
//  The submission manuscript is measured THROUGH THE PRODUCTION
//  EXPORT PATH, = on disk.
//
//  WHY THE ON-DISK PATH AND NOT THE SHAPER ALONE
//
//  `ManuscriptShaperTests` holds the shaping rules, = but it
//  never proves that the exported FILE carries them. = The
//  production path is `ChapterExportEngine.exportManuscript(id:to:target:)`,
//  = and it is what the sheet calls. = So these tests drive that
//  method against a real library root (= the same
//  `PathGuard.libraryRootOverride` seam the other library tests
//  use), = write a chapter's `.md` on disk, = export it, = and read
//  the BYTES BACK.
//
//  A mutation that broke the seam (= the engine writing the raw
//  body instead of the shaped manuscript, = or writing the wrong
//  target's shape) = turns these red, = even though the shaper's
//  own suite stayed green.
//
//  WHAT IS ASSERTED
//
//  - 晋江's exported FILE carries two full-width spaces on every
//    segment and a blank line between them.
//  - 起点 / 番茄's exported FILE carries neither.
//  - The file is PLAIN TEXT: = the app's own markers are gone.
//  - The chapter title is NOT in the file (= it is the platform's
//    own separate title field).
//  - The Markdown export is UNCHANGED: = the same body exported as
//    Markdown is still byte-for-byte the body (= the editor's round
//    trip), = so the manuscript did not take that contract away.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

@Suite("Chapter export (= the submission manuscript is shaped on disk)")
struct ChapterExportEngineManuscriptTests {
    /// A library root with one book and one chapter, = written on
    /// disk in the shape the engine walks (= `shelves/<shelf>/books/
    /// <book>/chapters/<uuid>.md`).
    private static func makeLibrary(
        body: String,
        chapterID: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    ) throws -> (root: URL, chapterID: UUID) {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-manuscript-\(UUID().uuidString)")
        let chapters = root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000000", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000001", isDirectory: true)
            .appendingPathComponent("chapters", isDirectory: true)
        try fm.createDirectory(at: chapters, withIntermediateDirectories: true)
        try Data(body.utf8).write(
            to: chapters.appendingPathComponent("\(chapterID.uuidString).md")
        )
        return (root, chapterID)
    }

    /// Export the chapter and read the written file's bytes back.
    private static func export(
        libraryRoot: URL,
        chapterID: UUID,
        target: ManuscriptTarget
    ) async throws -> String {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-manuscript-out-\(UUID().uuidString).txt")
        try await PathGuard.$libraryRootOverride.withValue(libraryRoot.path) {
            let engine = ChapterExportEngine()
            _ = try await engine.exportManuscript(
                id: chapterID,
                to: destination,
                target: target
            )
        }
        let written = try String(contentsOf: destination, encoding: .utf8)
        try? FileManager.default.removeItem(at: destination)
        return written
    }

    @Test("晋江's exported FILE carries two full-width spaces on every segment")
    func theExportedFileCarriesJinjiangIndent() async throws {
        let (root, chapterID) = try Self.makeLibrary(body: "第一段。\n\n第二段。")
        let written = try await Self.export(
            libraryRoot: root,
            chapterID: chapterID,
            target: .jinjiang
        )

        #expect(written == "\u{3000}\u{3000}第一段。\n\n\u{3000}\u{3000}第二段。")
        #expect(written.hasPrefix("\u{3000}\u{3000}"))
    }

    @Test("起点 and 番茄's exported FILE carry neither the indent nor the blank line")
    func theExportedFileCarriesNeitherForQidianAndFanqie() async throws {
        let (root, chapterID) = try Self.makeLibrary(body: "第一段。\n\n第二段。")
        for target in [ManuscriptTarget.qidian, .fanqie] {
            let written = try await Self.export(
                libraryRoot: root,
                chapterID: chapterID,
                target: target
            )
            #expect(written == "第一段。\n第二段。")
            #expect(!written.contains("\u{3000}"))
            #expect(!written.contains("\n\n"))
        }
    }

    @Test("the exported FILE is plain text (= the app's own markers are gone)")
    func theExportedFileIsPlainText() async throws {
        let (root, chapterID) = try Self.makeLibrary(
            body: "这是**粗体**和==高亮==和~~删除~~。\n\n- 列表项"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterID: chapterID,
            target: .qidian
        )

        #expect(!written.contains("**"))
        #expect(!written.contains("=="))
        #expect(!written.contains("~~"))
        #expect(written.contains("粗体"))
        #expect(written.contains("高亮"))
        #expect(written.contains("删除"))
        #expect(written.contains("列表项"))
    }

    @Test("the chapter title is NOT in the exported FILE (= the platform's own field)")
    func theExportedFileCarriesNoTitle() async throws {
        // The body carries a heading, = and the export must not
        // invent a title of its own.
        let (root, chapterID) = try Self.makeLibrary(body: "正文。")
        let written = try await Self.export(
            libraryRoot: root,
            chapterID: chapterID,
            target: .qidian
        )

        #expect(written == "正文。")
    }

    @Test("the exported FILE carries no frontmatter (= the metadata is not the prose)")
    func theExportedFileCarriesNoFrontmatter() async throws {
        // The body carries a leading frontmatter block, = and the
        // exported FILE must not carry it: = a submission manuscript
        // that opens with "title: ..." is the author's prose polluted
        // with the file's own metadata.
        let (root, chapterID) = try Self.makeLibrary(
            body: "---\ntitle: 第三章 风起\ndate: 2026-11-06\n---\n\n他推开门。\n\n屋里没有人。"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterID: chapterID,
            target: .qidian
        )

        #expect(!written.contains("title:"))
        #expect(!written.contains("date:"))
        #expect(!written.contains("---"))
        #expect(written == "他推开门。\n屋里没有人。")
    }

    @Test("the exported FILE keeps a fenced code block's CONTENT verbatim")
    func theExportedFileKeepsFencedCodeVerbatim() async throws {
        // The marks inside a fence are the CODE's own (= `**bold**` is
        // an operator, = not the app's highlight), = and the engine
        // parses nothing inside a fence. = So the file must carry the
        // code exactly as the author wrote it.
        let (root, chapterID) = try Self.makeLibrary(
            body: "正文。\n\n```python\ndef f(a, **kw):\n    return a == kw\n```"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterID: chapterID,
            target: .qidian
        )

        #expect(!written.contains("```"), "the fence's markers are markup")
        #expect(written.contains("def f(a, **kw):"), "the code keeps its own marks")
        #expect(written.contains("return a == kw"), "the code's own == survives")
        #expect(written.contains("    return a == kw"), "the code keeps its own indentation")
    }

    @Test("the exported FILE carries no title line (= the title is the platform's own field)")
    func theExportedFileCarriesNoTitleLine() async throws {
        // The body carries its own title as the app's convention has it
        // (= the first "# " line, = which is where
        // `FileSystemLibraryStore.extractTitle` reads a document's
        // title from), = and the exported FILE must not repeat it.
        let (root, chapterID) = try Self.makeLibrary(
            body: "# 第三章 风起\n\n他推开门。\n\n屋里没有人。"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterID: chapterID,
            target: .qidian
        )

        #expect(!written.contains("第三章"))
        #expect(written == "他推开门。\n屋里没有人。")
    }

    @Test("the MARKDOWN export is unchanged (= the body bytes are preserved verbatim)")
    func theMarkdownExportStillPreservesTheBodyBytes() async throws {
        let body = "第一段。\n\n==高亮==与**粗体**。"
        let (root, chapterID) = try Self.makeLibrary(body: body)
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-markdown-out-\(UUID().uuidString).md")
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let engine = ChapterExportEngine()
            _ = try await engine.exportChapter(id: chapterID, to: destination)
        }
        let written = try String(contentsOf: destination, encoding: .utf8)
        try? FileManager.default.removeItem(at: destination)

        #expect(written == body, "the Markdown export must stay byte-for-byte the body")
    }
}
