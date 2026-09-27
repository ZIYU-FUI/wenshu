//
//  Core/Agent/Librarian/EditChapterToolWireTests.swift · wenshu · edit-chapter-tool 2026-09-28 T5
//
//  RED tests for Phase 5 of edit-chapter-tool arc: EditChapterTool
//  (= hermes 0.21.5 edit_file 1:1) is a thin wrapper around
//  EditChapterActor that surfaces a JSON envelope via the standard
//  tool-call path. Mirrors BookChapterTool's shared-singleton +
//  module-load ToolRegistry bootstrap pattern (= Q112 reference).
//
//  Async Swift Testing — drives the actor directly via the
//  EditChapterTool.execute(input:) entry point.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("EditChapterTool wire-up (edit-chapter-tool 2026-09-28 T5)")
struct EditChapterToolWireTests {

    @Test("EditChapterTool.execute(input:) routes the JSON envelope to the actor and returns the diff envelope")
    func executeRoutesToActor() async throws {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-edit-tool-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)

        UserDefaultsStore.shared.setString(
            URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path,
            forKey: .libraryPath
        )

        // Seed a chapter row + body on disk so the actor has
        // something to patch.
        let bookId = UUID()
        let chapter = Document(
            id: UUID(),
            bookId: bookId,
            category: .chapter,
            title: "T",
            summary: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        let store = FileSystemChapterStore(bookDirectory: tmpRoot)
        try store.saveChapter(chapter, bodyMarkdown: "before-patch")

        let tool = EditChapterTool(
            actor: EditChapterActor(bookDirectoryProvider: { tmpRoot })
        )
        let input = """
        {"action":"edit","id":"\(chapter.id.uuidString)","book_id":"\(bookId.uuidString)","old_text":"before-patch","new_text":"after-patch"}
        """
        let output = try await tool.execute(input: input)
        let payload = try jsonObject(output)

        // Mirror BookChapterTool.update's success envelope so
        // ChatToolDiffPreview's input stays stable.
        #expect(payload["ok"] as? Bool == true)
        #expect(payload["action"] as? String == "edit")
        #expect(payload["kind"] as? String == "diff")
        let diff = payload["diff"] as? [String: Any]?
        #expect(diff != nil)
        if let diffBlock = payload["diff"] as? [String: Any],
           let stats = diffBlock["stats"] as? [String: Any] {
            #expect((stats["added_chars"] as? Int) != nil)
            #expect((stats["removed_chars"] as? Int) != nil)
        }
    }

    @Test("EditChapterTool.execute surfaces oldTextNotFound when old_text is missing")
    func missingOldTextSurfacesError() async throws {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-edit-tool-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        UserDefaultsStore.shared.setString(
            URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path,
            forKey: .libraryPath
        )

        let bookId = UUID()
        let chapter = Document(
            id: UUID(),
            bookId: bookId,
            category: .chapter,
            title: "T",
            summary: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        let store = FileSystemChapterStore(bookDirectory: tmpRoot)
        try store.saveChapter(chapter, bodyMarkdown: "alpha\nbeta\ngamma\n")

        let tool = EditChapterTool(
            actor: EditChapterActor(bookDirectoryProvider: { tmpRoot })
        )
        let input = """
        {"action":"edit","id":"\(chapter.id.uuidString)","book_id":"\(bookId.uuidString)","old_text":"delta","new_text":"epsilon"}
        """
        let output = try await tool.execute(input: input)
        let payload = try jsonObject(output)
        #expect(payload["ok"] as? Bool == false)
        #expect(payload["error_kind"] as? String == "old_text_not_found")
    }

    @Test("WenshuConductor wires EditChapterTool under book_edit_chapter")
    func isWiredInWenshuConductor() throws {
        // Source-content anchor: verify the WenshuConductor's tool
        // declarations and tools dict both contain book_edit_chapter.
        // (= mirrors the v1.85 hermes 0.21.5 wire-up; = same shape
        // as BookChapterTool / BookEntityTool.)
        let conductorPath = Self.repoSourcePath("Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift")
        let source = try String(contentsOfFile: conductorPath, encoding: .utf8)
        #expect(source.contains("\"book_edit_chapter\""), "conductor must declare the new tool name")
        #expect(source.contains("EditChapterTool("), "conductor must wire EditChapterTool into tools dict")
    }

    // MARK: - Repo-root path helper (= Q112 source-content anchor)
    //
    // Tests live at Tests/WenshuAppTests/Core/Agent/Librarian/,
    // which is 4 dirs deep under Tests/, plus the worktree
    // (= Tests/WenshuAppTests/Core/Agent/Librarian/<file>.swift
    //  => /Volumes/ANAN/Engineering/wenshu/wt/<wt-name>/Sources/...).
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/wt/edit-chapter-tool-2026-09-28/\(relativeFromRepoRoot)"
        return path
    }
}

private func jsonObject(_ raw: String) throws -> [String: Any] {
    let data = Data(raw.utf8)
    guard let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "not a JSON object: \(raw)"])
    }
    return obj
}