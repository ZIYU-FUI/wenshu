//
//  EditorPersistenceAnnouncementTests.swift · Wenshu
//
//  The editor's save path and the library's own announcement.
//
//  WHY THIS EXISTS
//
//  The library announces its own changes: `LibraryChangeNotifier` posts
//  `.wenshuLibraryDidChange` after every write that the app makes (= =
//  the agent's reference and book-doc writes, the import, the sidebar's
//  delete). = = That announcement is the invalidation signal for the
//  caches that read the library (= = `LibraryContentFingerprint`'s own
//  docblock says so), = = and the material zone's ONE list is keyed on it
//  too (= = the scope, = = the library-change tick, = = and the sort
//  order).
//
//  ⇒ ⇒ ⇒ AND THE EDITOR'S AUTO-SAVE WAS A WRITE PATH THAT DID NOT
//  ANNOUNCE: = = `EditorPersistence.save` wrote the chapter's .md to disk
//  and said nothing. = = ⇒ The material zone's card for an edited
//  chapter kept its pre-edit summary and chip tag until the user changed
//  scope or sort order (= = the review's finding on the materials scope).
//
//  Pattern (= the house's editor-test pattern): Swift Testing +
//  @MainActor + a real fixture in /tmp. = = No mock framework (= the
//  filesystem IS the test target).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("The editor's save announces the library change (= = so the material zone's list refreshes)")
struct EditorPersistenceAnnouncementTests {
    // MARK: - The fixture

    /// A library on disk (= = a shelves root + a reference library root),
    /// = = and the root to clean up.
    private func makeLibrary() throws -> (BookStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-editor-announce-\(UUID().uuidString)")
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: referenceLibraryRoot, withIntermediateDirectories: true)
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        )
        return (BookStore(stores: stores), root)
    }

    /// Count the announcements (= = the notification the library posts).
    private func countAnnouncements(
        _ body: () -> Void
    ) -> Int {
        var count = 0
        let token = NotificationCenter.default.addObserver(
            forName: .wenshuLibraryDidChange,
            object: nil,
            queue: nil
        ) { _ in
            count += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }
        body()
        return count
    }

    // MARK: - The tests

    @Test("A save that lands inside the library announces the change")
    func aSaveInsideTheLibraryAnnounces() throws {
        let (bookStore, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        // A chapter inside the library's shelves root.
        let chapterDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        let chapter = chapterDir.appendingPathComponent("第一章.md")
        try "# 第一章\n\n旧正文。\n".write(to: chapter, atomically: true, encoding: .utf8)

        let tab = EditorTab(
            id: UUID(),
            documentPath: chapter.path,
            draft: "# 第一章\n\n新正文。\n",
            originalBody: "# 第一章\n\n旧正文。\n",
            mode: .preview,
            title: nil
        )

        let announcements = countAnnouncements {
            EditorPersistence.save(tab: tab, bookStore: bookStore)
        }

        #expect(
            announcements == 1,
            "a save inside the library MUST announce the change (= \(announcements) announcement(s))"
        )
        #expect(
            (try? String(contentsOf: chapter, encoding: .utf8)) == tab.draft,
            "the save MUST have written the draft (= the announcement must follow a real write)"
        )
    }

    @Test("A save OUTSIDE the library announces nothing")
    func aSaveOutsideTheLibraryAnnouncesNothing() throws {
        let (bookStore, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        // A file outside every library root (= = the editor's /tmp
        // fallback's shape, = = and a preview document the library never
        // saw).
        let outside = root.appendingPathComponent("outside.md")
        try "# 外面\n\n正文。\n".write(to: outside, atomically: true, encoding: .utf8)
        let tab = EditorTab(
            id: UUID(),
            documentPath: outside.path,
            draft: "# 外面\n\n新正文。\n",
            originalBody: "# 外面\n\n正文。\n",
            mode: .preview,
            title: nil
        )

        let announcements = countAnnouncements {
            EditorPersistence.save(tab: tab, bookStore: bookStore)
        }

        #expect(
            announcements == 0,
            "a write OUTSIDE the library MUST NOT announce (= \(announcements) announcement(s))"
        )
    }
}
