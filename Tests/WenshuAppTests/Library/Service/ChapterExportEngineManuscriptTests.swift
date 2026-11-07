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
//  production path is `ChapterExportEngine.exportManuscript(fileURL:to:target:)`,
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
//  - Jinjiang's exported FILE carries two full-width spaces on every
//    segment and a blank line between them.
//  - Qidian / Tomato's exported FILE carries neither.
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
    ) throws -> (root: URL, chapterID: UUID, chapterFile: URL) {
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
        let file = chapters.appendingPathComponent("\(chapterID.uuidString).md")
        try Data(body.utf8).write(to: file)
        return (root, chapterID, file)
    }

    /// A library whose chapter is an IMPORTED one (= = the file is
    /// named after the chapter's title, = = not after an id, = = and
    /// there is no index row at all).
    ///
    /// = = This is the shape the importer produces, = = and the shape
    /// an id lookup cannot find: = = the resolver mints a DERIVED id
    /// for the file, = = so `<id>.md` is not a file on disk.
    private static func makeImportedLibrary(
        body: String,
        title: String = "我的第一章"
    ) throws -> (root: URL, chaptersDir: URL, chapterFile: URL) {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-manuscript-imported-\(UUID().uuidString)")
        let chapters = root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000000", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000001", isDirectory: true)
            .appendingPathComponent("chapters", isDirectory: true)
        try fm.createDirectory(at: chapters, withIntermediateDirectories: true)
        let file = chapters.appendingPathComponent("\(title).md")
        try Data(body.utf8).write(to: file)
        return (root, chapters, file)
    }

    /// Export the chapter and read the written file's bytes back.
    private static func export(
        libraryRoot: URL,
        chapterFile: URL,
        target: ManuscriptTarget
    ) async throws -> String {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-manuscript-out-\(UUID().uuidString).txt")
        try await PathGuard.$libraryRootOverride.withValue(libraryRoot.path) {
            let engine = ChapterExportEngine()
            _ = try await engine.exportManuscript(
                fileURL: chapterFile,
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
        let (root, chapterID, chapterFile) = try Self.makeLibrary(body: "第一段。\n\n第二段。")
        let written = try await Self.export(
            libraryRoot: root,
            chapterFile: chapterFile,
            target: .jinjiang
        )

        #expect(written == "\u{3000}\u{3000}第一段。\n\n\u{3000}\u{3000}第二段。")
        #expect(written.hasPrefix("\u{3000}\u{3000}"))
    }

    @Test("起点 and 番茄's exported FILE carry neither the indent nor the blank line")
    func theExportedFileCarriesNeitherForQidianAndFanqie() async throws {
        let (root, chapterID, chapterFile) = try Self.makeLibrary(body: "第一段。\n\n第二段。")
        for target in [ManuscriptTarget.qidian, .fanqie] {
            let written = try await Self.export(
                libraryRoot: root,
                chapterFile: chapterFile,
                target: target
            )
            #expect(written == "第一段。\n第二段。")
            #expect(!written.contains("\u{3000}"))
            #expect(!written.contains("\n\n"))
        }
    }

    @Test("the exported FILE is plain text (= the app's own markers are gone)")
    func theExportedFileIsPlainText() async throws {
        let (root, chapterID, chapterFile) = try Self.makeLibrary(
            body: "这是**粗体**和==高亮==和~~删除~~。\n\n- 列表项"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterFile: chapterFile,
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
        let (root, chapterID, chapterFile) = try Self.makeLibrary(body: "正文。")
        let written = try await Self.export(
            libraryRoot: root,
            chapterFile: chapterFile,
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
        let (root, chapterID, chapterFile) = try Self.makeLibrary(
            body: "---\ntitle: 第三章 风起\ndate: 2026-11-06\n---\n\n他推开门。\n\n屋里没有人。"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterFile: chapterFile,
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
        let (root, chapterID, chapterFile) = try Self.makeLibrary(
            body: "正文。\n\n```python\ndef f(a, **kw):\n    return a == kw\n```"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterFile: chapterFile,
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
        let (root, chapterID, chapterFile) = try Self.makeLibrary(
            body: "# 第三章 风起\n\n他推开门。\n\n屋里没有人。"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterFile: chapterFile,
            target: .qidian
        )

        #expect(!written.contains("第三章"))
        #expect(written == "他推开门。\n屋里没有人。")
    }

    @Test("a '# ' line inside a code fence is NOT the title (= the code survives)")
    func aCommentInsideAFenceIsNotTheTitle() async throws {
        // The fence's comment is the author's own code, = and the
        // body's REAL title comes after the fence. = So the code
        // survives and the title goes.
        let (root, chapterID, chapterFile) = try Self.makeLibrary(
            body: "```python\n# c\nprint(1)\n```\n\n# 真正的标题\n\n正文。"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterFile: chapterFile,
            target: .qidian
        )

        #expect(written.contains("# c"), "the code's own comment must survive")
        #expect(written.contains("print(1)"), "the code must survive")
        #expect(!written.contains("真正的标题"), "the body's own title must not")
        #expect(written.contains("正文。"))
    }

    @Test("two rules with PROSE between them are two rules (= the prose survives)")
    func twoRulesWithProseBetweenThemKeepTheProse() async throws {
        // A body that opens with a rule and carries prose between two
        // rules is NOT frontmatter, = and that prose is the author's.
        let (root, chapterID, chapterFile) = try Self.makeLibrary(
            body: "---\n\n段落一。\n\n---\n\n段落二。"
        )
        let written = try await Self.export(
            libraryRoot: root,
            chapterFile: chapterFile,
            target: .qidian
        )

        #expect(written.contains("段落一。"), "the prose between two rules must survive")
        #expect(written.contains("段落二。"))
    }

    @Test("the MARKDOWN export is unchanged (= the body bytes are preserved verbatim)")
    func theMarkdownExportStillPreservesTheBodyBytes() async throws {
        let body = "第一段。\n\n==高亮==与**粗体**。"
        let (root, chapterID, chapterFile) = try Self.makeLibrary(body: body)
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

    /// The number the PANEL shows is the number the exported FILE
    /// carries.
    ///
    /// = The panel calls `ChapterExportEngine.manuscriptWordCount`, =
    /// which is a DIFFERENT seam from the shaper's own `wordCount` =
    /// so a defect in the engine's method = (= taking the SHAPED
    /// text's length = = the indent and the blank lines the platform
    /// adds) = is invisible to the shaper's suite. = This drives the
    /// engine's own method against a real library root, = and holds it
    /// to the CONTENT's characters.
    @Test("the number the panel shows is the CONTENT's characters (= and not the shaped file's length)")
    func thePanelCountIsTheContentCount() async throws {
        // The Jinjiang target = the one whose shape adds the most (= two
        // full-width spaces on every segment, = and a blank line
        // between them), = so a count that took the shaped file's
        // length would differ from the content's by a visible amount.
        let body = "第一段。\n\n第二段。"
        let (root, chapterID, chapterFile) = try Self.makeLibrary(body: body)
        let engine = ChapterExportEngine()
        let count = try await PathGuard.$libraryRootOverride.withValue(root.path) {
            await engine.manuscriptWordCount(fileURL: chapterFile, target: .jinjiang)
        }

        let content = body.replacingOccurrences(of: "\n\n", with: "").count
        #expect(count == content, "the count must be the content's characters")
        #expect(count != body.count, "the content's characters are not the body's characters")
    }

    // MARK: - The imported chapter

    /// An IMPORTED chapter is exported, = = and the file it writes is
    /// the chapter's own.
    ///
    /// = = The importer names a chapter's file after the TITLE, = = so
    /// the id the resolver mints is not the file's name, = = and an id
    /// lookup (= = `<id>.md`) = = finds nothing. = = The export takes
    /// the FILE the resolver handed over, = = so the chapter is
    /// exported.
    ///
    /// = = The chain this drives is the production one: = = the
    /// resolver reads the folder, = = the sheet's selection picks the
    /// chapter out of the resolved list, = = and the engine writes the
    /// file that selection names.
    ///
    /// MUTATION: = the export locates the chapter by id again = = the
    /// file is not found, = = nothing is written, = = and this case
    /// fails.
    @Test("an imported chapter is exported (= and the file is its own)")
    func anImportedChapterIsExported() async throws {
        let body = "第一段。\n\n第二段。"
        let (root, chaptersDir, chapterFile) = try Self.makeImportedLibrary(body: body)

        // The resolver's answer: = the chapters on disk, = with the
        // file each one lives in.
        let resolved = ChapterResolver.resolveChapters(
            bookId: UUID(),
            chaptersDirectory: chaptersDir,
            indexURL: root.appendingPathComponent("chapters.json")
        )
        #expect(resolved.count == 1, "the imported chapter must be resolved")
        #expect(
            resolved[0].fileURL.lastPathComponent == "我的第一章.md",
            "the resolved file is the imported one (= = named after the title)"
        )

        // The sheet's selection: = the file the resolver handed over.
        let selected = ResolvedChapter.fileURL(for: resolved[0].id, in: resolved)
        #expect(
            selected?.standardizedFileURL == chapterFile.standardizedFileURL,
            "the selection hands over the resolver's own file"
        )

        // The export: = = that file, = = written.
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-manuscript-imported-out-\(UUID().uuidString).txt")
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let engine = ChapterExportEngine()
            _ = try await engine.exportManuscript(
                fileURL: selected ?? chapterFile,
                to: destination,
                target: .qidian
            )
        }

        let written = try String(contentsOf: destination, encoding: .utf8)
        try? FileManager.default.removeItem(at: destination)
        #expect(
            written.contains("第一段。"),
            "the imported chapter's body must reach the exported file"
        )
    }

    /// The panel's count reaches an imported chapter too.
    ///
    /// = = The count and the export read the same chapter, = = so a
    /// count that found nothing while the export found everything would
    /// be a panel that says nothing about a chapter it can export.
    @Test("the panel's count reaches an imported chapter")
    func thePanelCountReachesAnImportedChapter() async throws {
        let body = "第一段。\n\n第二段。"
        let (root, chaptersDir, chapterFile) = try Self.makeImportedLibrary(body: body)
        let resolved = ChapterResolver.resolveChapters(
            bookId: UUID(),
            chaptersDirectory: chaptersDir,
            indexURL: root.appendingPathComponent("chapters.json")
        )
        #expect(resolved.count == 1)
        let selected = ResolvedChapter.fileURL(for: resolved[0].id, in: resolved)

        let engine = ChapterExportEngine()
        let count = try await PathGuard.$libraryRootOverride.withValue(root.path) {
            await engine.manuscriptWordCount(fileURL: selected, target: .qidian)
        }

        let content = body.replacingOccurrences(of: "\n\n", with: "").count
        #expect(
            count == content,
            "the count must reach the imported chapter (= = the same chapter the export writes)"
        )
    }
}
