//
//  ActiveBookIdentityTests.swift · Wenshu
//
//  WHO NAMES THE BOOK. The format page and the editor both act on the book
//  the store names as selected (= `BookStore.selectedBookId`), so the whole
//  question is who writes that field.
//
//  THE DEFECT THESE HOLD
//
//  Before this, one call site wrote it: an outline click in the sidebar. A
//  session that opened a manuscript from the card grid, or one that merely
//  restarted, named no book, and the format page's every click returned
//  early at that nil (= the switcher sprang back to the set it already
//  showed, and the open document never re-rendered).
//
//  WHY THESE ARE NOT PAGE TESTS
//
//  The page's own suite measures what the page paints and writes. This one
//  measures the identity that reaches it, through the shapes the app really
//  keeps: a tab opened by the production open path, a snapshot persisted and
//  restored, and a store told to adopt.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The active book's identity — the tab, the snapshot, the store", .serialized)
@MainActor
struct ActiveBookIdentityTests {
    init() {
        //  The persisted-tab keys are shared process state, and
        //  `AppState.init` restores from them, so every case in this suite
        //  starts from no tabs at all. The keys are named by the SAME enum
        //  the writer uses (= `WenshuDefaultsKey`): `AppState.openTabsKey`
        //  is a DIFFERENT string ("wenshu.editor.openTabs.v1" against the
        //  writer's "wenshu.openTabs"), so clearing it clears nothing, which
        //  is recorded as its own finding rather than repeated here.
        UserDefaults.standard.removeObject(forKey: WenshuDefaultsKey.openTabs.rawValue)
        UserDefaults.standard.removeObject(forKey: WenshuDefaultsKey.activeTabId.rawValue)
    }

    /// A store over two empty temporary roots (no book is needed to name one).
    private func makeStore() -> BookStore {
        let root = URL(fileURLWithPath: "/tmp/wenshu-identity-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let shelves = root.appendingPathComponent("shelves", isDirectory: true)
        let references = root.appendingPathComponent("references", isDirectory: true)
        try? FileManager.default.createDirectory(at: shelves, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: references, withIntermediateDirectories: true)
        return BookStore(
            stores: LibraryStores(
                shelvesRoot: shelves,
                referenceLibraryRoot: references,
                referenceStore: FileSystemReferenceStore(referenceLibraryRoot: references)
            )
        )
    }

    /// The production open path: a manuscript card double-clicked in the grid.
    private func openManuscript(ofBook bookId: UUID, in appState: AppState) {
        _ = CardOpenOps.openTab(
            triad: CardOpenOps.CardTriad(
                path: "/tmp/wenshu-identity-\(UUID().uuidString).md",
                content: "# Chapter\n\nA page of the manuscript.",
                title: "Chapter one"
            ),
            previewScope: .bookScope(bookId: bookId, folderName: nil),
            appState: appState
        )
    }

    /// A BOOK'S DOCUMENT NAMES ITS BOOK.
    ///
    /// The tab is the record the app already keeps of what is in front of the
    /// user, and it already carries the scope it was opened from; what it did
    /// not carry was an answer to "which book".
    @Test("a tab opened from a book's document names that book")
    func aBookDocumentTabNamesItsBook() {
        let appState = AppState()
        let bookId = UUID()
        #expect(appState.activeBookId == nil, "a session with no tab names no book")
        openManuscript(ofBook: bookId, in: appState)
        #expect(
            appState.activeBookId == bookId,
            "the card grid knows which book the card belongs to (= `PreviewScope.bookScope`), so the open tab must be able to say it"
        )
    }

    /// A TAB THAT NAMES NO BOOK NAMES NO BOOK.
    ///
    /// The placeholder tab and any tab opened outside a book's scope keep
    /// `activeBookId` nil, which is what lets the sidebar's outline click
    /// stay a legitimate way to name a book.
    @Test("a tab with no book scope names no book")
    func aScopelessTabNamesNoBook() {
        let appState = AppState()
        let tab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "",
            originalBody: "",
            mode: .edit,
            title: nil
        )
        appState.openTabs.append(tab)
        appState.activeTabId = tab.id
        #expect(appState.activeBookId == nil)
    }

    /// THE ADOPTION NEVER CLEARS.
    ///
    /// Coming to the front of a reference card must not cost the page the
    /// book it was editing.
    @Test("a tab that names no book leaves the store's record alone")
    func adoptionLeavesTheRecordAloneWhenNoBookIsNamed() {
        let store = makeStore()
        let bookId = UUID()
        store.adoptActiveBook(bookId)
        #expect(store.selectedBookId == bookId)
        store.adoptActiveBook(nil)
        #expect(
            store.selectedBookId == bookId,
            "adopting 'nothing' wiped the book the user was working on"
        )
    }

    /// THE BOOK SURVIVES A RELAUNCH.
    ///
    /// The restart was the common case of the defect: the tabs came back, the
    /// document came back, and the book it belongs to did not, because the
    /// scope was never persisted.
    @Test("a relaunched session still names the open document's book")
    func theBookSurvivesARelaunch() throws {
        let bookId = UUID()
        let appState = AppState()
        openManuscript(ofBook: bookId, in: appState)
        let tabId = try #require(appState.openTabs.first?.id)

        //  A new AppState is what launching the app again is: the tabs come
        //  back out of the same defaults `persistOpenTabs` wrote.
        let relaunched = AppState()
        #expect(relaunched.openTabs.count == 1, "the tab itself did not survive the restart")
        #expect(relaunched.activeTabId == tabId, "the active tab was not the one that came back")
        #expect(
            relaunched.activeBookId == bookId,
            "the restored tab shows a document and names no book (= the scope is not carried across the snapshot)"
        )

        let store = makeStore()
        store.adoptActiveBook(relaunched.activeBookId)
        #expect(store.selectedBookId == bookId)
    }

    /// A SNAPSHOT FROM BEFORE THE FIELD EXISTS STILL LOADS.
    ///
    /// The persisted shape grew a key; the store on the reader's disk was
    /// written without it, and a decoder that made the new key required would
    /// cost him every tab he has open.
    @Test("a snapshot written before the scope field still restores its tabs")
    func anOldSnapshotStillLoads() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","documentPath":"/tmp/wenshu-identity-legacy.md",\
        "draft":"A page typed before the scope existed","originalBody":"",\
        "mode":"edit","title":"Chapter one"}]
        """
        UserDefaults.standard.set(
            legacy.data(using: .utf8)!,
            forKey: WenshuDefaultsKey.openTabs.rawValue
        )
        let appState = AppState()
        #expect(
            appState.openTabs.count == 1,
            "a snapshot without the scope key was refused (= the reader lost the tabs he had open)"
        )
        #expect(appState.openTabs[0].sourceScope == nil)
        #expect(appState.activeBookId == nil)
    }
}
