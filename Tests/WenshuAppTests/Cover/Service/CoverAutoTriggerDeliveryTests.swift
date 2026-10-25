//
//  CoverAutoTriggerDeliveryTests.swift · Wenshu
//
//  Proves the automatic pass REACHES the documents the agent wrote.
//
//  The trigger's own tests prove it makes a cover for a document
//  created after the switch. That is not enough on its own: a trigger
//  nobody calls makes no cover at all, and the caller is the part
//  that broke.
//
//  The agent writes a file and returns. Nothing in the app reloads
//  afterwards, so a reference the agent wrote is invisible to the
//  material zone until the user clicks something else, and the
//  automatic pass never sees it.
//
//  So these tests drive the REAL write path (the agent's own tool,
//  against a real file system) and check that the library says it
//  changed. The listener on the other side is the material zone's
//  automatic pass.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover automatic pass delivery", .serialized)
@MainActor
struct CoverAutoTriggerDeliveryTests {

    /// A throwaway reference-library root.
    private static func makeStore() throws -> FileSystemReferenceStore {
        let root = URL(fileURLWithPath: "/tmp/wenshu-cover-delivery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return FileSystemReferenceStore(referenceLibraryRoot: root)
    }

    /// Counts the library-change announcements from ONE source.
    ///
    /// The count is filtered by the source, because the notification
    /// is global and another suite's write would otherwise land in
    /// this counter.
    private final class ChangeCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var _count = 0

        var count: Int { lock.withLock { _count } }

        func observe(_ source: LibraryChangeNotifier.Source) -> NSObjectProtocol {
            NotificationCenter.default.addObserver(
                forName: .wenshuLibraryDidChange,
                object: source,
                queue: nil
            ) { [weak self] _ in
                self?.lock.withLock { self?._count += 1 }
            }
        }
    }

    @Test("A reference the agent wrote announces that the library changed")
    func anAgentWrittenReferenceAnnouncesTheChange() async throws {
        let counter = ChangeCounter()
        let token = counter.observe(.agentReference)
        defer { NotificationCenter.default.removeObserver(token) }

        let actor = try ReferenceLibraryActor(referenceStore: Self.makeStore())
        _ = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "# Ming tax\n\nKey concepts.",
            layer: "raw",
            summary: "Tax records"
        )

        // Without this announcement the new reference never reaches
        // the material zone, so the automatic pass never sees it and
        // it never gets a cover.
        #expect(counter.count == 1)
    }

    @Test("A book doc the agent wrote announces that the library changed")
    func anAgentWrittenBookDocAnnouncesTheChange() async throws {
        let counter = ChangeCounter()
        let token = counter.observe(.agentBookDoc)
        defer { NotificationCenter.default.removeObserver(token) }

        // The book doc needs a book to live in, so the tool's path
        // guard is given a real directory under /tmp.
        let bookRoot = URL(fileURLWithPath: "/tmp/wenshu-cover-delivery-book-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bookRoot, withIntermediateDirectories: true)

        let tool = WriteBookDocTool(
            bookPathProvider: { bookRoot.path },
            targetFolderName: "world"
        )
        _ = try await tool.execute(input: """
        {"path": "world/notes.md", "body": "# Notes\\n\\nA note."}
        """)

        #expect(counter.count == 1)
    }

    @Test("A read of the library announces nothing")
    func aReadAnnouncesNothing() async throws {
        let counter = ChangeCounter()
        let token = counter.observe(.agentReference)
        defer { NotificationCenter.default.removeObserver(token) }

        let actor = try ReferenceLibraryActor(referenceStore: Self.makeStore())
        _ = try await actor.createReference(
            title: "Beijing history",
            bodyMarkdown: "# Beijing\n\nCity history.",
            layer: "raw"
        )
        // The create announced once. A read must not announce again,
        // or every lookup would reload the library.
        let afterCreate = counter.count
        _ = try await actor.listReferences()
        _ = try await actor.findReference(title: "Beijing history")
        #expect(counter.count == afterCreate)
    }
}
