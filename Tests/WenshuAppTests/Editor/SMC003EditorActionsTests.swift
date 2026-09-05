//
//  SMC003EditorActionsTests.swift · Wenshu · SMC ticket 003
//
// Focused tests for the editor action helpers that close the
// confirmed red paths from the v0.39 SMC audit.
//
import Testing
import Foundation
import AppKit
import MarkdownEngine
@testable import WenshuApp

@MainActor
@Suite("SMC ticket 003 editor actions")
struct SMC003EditorActionsTests {

    private func makeBookStoreBundle() throws -> (shelvesRoot: URL, referenceLibraryRoot: URL, referenceStore: FileSystemReferenceStore) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-smc003-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: referenceLibraryRoot, withIntermediateDirectories: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        return (shelvesRoot, referenceLibraryRoot, referenceStore)
    }

    private func saveReference(
        _ store: FileSystemReferenceStore,
        id: UUID,
        title: String,
        body: String
    ) throws {
        let reference = Reference(
            id: id,
            title: title,
            source: nil,
            url: nil,
            layer: .layerEntities,
            category: .k,
            subcategory: nil,
            entityType: .other,
            summary: title,
            characterRefIds: [],
            worldRefIds: [],
            bookRefIds: [],
            createdAt: .now,
            updatedAt: .now
        )
        try store.saveReference(reference, bodyMarkdown: body)
    }

    @Test("WikiLinkNavigation miss returns nil")
    func wikiLinkMiss() async throws {
        let bundle = try makeBookStoreBundle()
        let result = WikiLinkNavigation.handle(
            displayName: "Ghost",
            referenceStore: bundle.referenceStore,
            bookStore: nil
        )
        #expect(result == nil)
    }

    @Test("WikiLinkNavigation nil store returns nil")
    func wikiLinkNilStore() async throws {
        let result = WikiLinkNavigation.handle(
            displayName: "Anna",
            referenceStore: nil,
            bookStore: nil
        )
        #expect(result == nil)
    }

    @Test("WikiLinkNavigation empty name returns nil")
    func wikiLinkEmptyName() async throws {
        let bundle = try makeBookStoreBundle()
        let result = WikiLinkNavigation.handle(
            displayName: "   ",
            referenceStore: bundle.referenceStore,
            bookStore: nil
        )
        #expect(result == nil)
    }

    @Test("DraftPersistence proposedPath returns chapters/<uuid>.md")
    func draftPersistenceProposedPath() async throws {
        let bundle = try makeBookStoreBundle()
        let stores = LibraryStores(
            shelvesRoot: bundle.shelvesRoot,
            referenceLibraryRoot: bundle.referenceLibraryRoot,
            referenceStore: bundle.referenceStore
        )
        let bookStore = BookStore(stores: stores)
        let tab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "hello",
            originalBody: "hello"
        )
        let path = DraftPersistence.proposedPath(for: tab, bookStore: bookStore)
        #expect(path != nil)
        #expect(path?.lastPathComponent == "\(tab.id.uuidString).md")
        #expect(path?.path.contains("chapters") == true)
    }

    @Test("DraftPersistence persist writes bytes atomically")
    func draftPersistencePersist() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-smc003-\(UUID().uuidString).md")
        try DraftPersistence.persist(text: "hello", to: url)
        let read = try String(contentsOf: url, encoding: .utf8)
        #expect(read == "hello")
        try? FileManager.default.removeItem(at: url)
    }

    @Test("MarkdownEditorBus.buildWenshu fills every Notification.Name")
    func busBuildWenshu() async throws {
        let bus = MarkdownEditorBus.buildWenshu()
        #expect(bus.applyBoldRequest != nil)
        #expect(bus.applyItalicRequest != nil)
        #expect(bus.applyHeadingRequest != nil)
        #expect(bus.applyHighlightRequest != nil)
        #expect(bus.applyStrikethroughRequest != nil)
        #expect(bus.applyInlineCodeRequest != nil)
        #expect(bus.applyBlockquoteRequest != nil)
        #expect(bus.applyUnorderedListRequest != nil)
        #expect(bus.applyOrderedListRequest != nil)
        #expect(bus.applyLinkRequest != nil)
        #expect(bus.applyCodeBlockRequest != nil)
        #expect(bus.applyHorizontalRuleRequest != nil)
        #expect(bus.applyImageRequest != nil)
        #expect(bus.selectionBoldDidChange != nil)
        #expect(bus.selectionItalicDidChange != nil)
        #expect(bus.selectionHighlightDidChange != nil)
        #expect(bus.findScrollToRange != nil)
        #expect(bus.findClearHighlights != nil)
        #expect(bus.findQuery != nil)
        #expect(bus.findResults != nil)
        #expect(bus.replaceCurrent != nil)
        #expect(bus.replaceAll != nil)
    }

    @Test("FormatDispatcher applyBold posts bus name")
    func formatBold() async throws {
        let bus = MarkdownEditorBus.buildWenshu()
        let format = FormatDispatcher(bus: bus)
        var received = false
        let token = NotificationCenter.default.addObserver(
            forName: bus.applyBoldRequest, object: nil, queue: nil
        ) { _ in received = true }
        format.applyBold()
        #expect(received)
        NotificationCenter.default.removeObserver(token)
    }

    @Test("FindReplaceDispatcher runFind carries query")
    func findQuery() async throws {
        let bus = MarkdownEditorBus.buildWenshu()
        let find = FindReplaceDispatcher(bus: bus)
        var capturedQuery: String?
        let token = NotificationCenter.default.addObserver(
            forName: bus.findQuery, object: nil, queue: nil
        ) { note in capturedQuery = note.userInfo?["query"] as? String }
        find.runFind(query: "Anna")
        #expect(capturedQuery == "Anna")
        NotificationCenter.default.removeObserver(token)
    }
}
