//
//  SidebarRowWritesTests.swift · wenshu
//
//  A clicked sidebar row writes two fields (= `workspaceUI.sidebarSelection`
//  and `BookStore.selectedBookId`), = and this suite measures WHICH TWO
//  for each kind of row (= `AppleSidebarView.writes(for:in:)`, = the one
//  decision `forwardSelection` exists to perform).
//
//  ⇒ WHY THE DECISION IS A FUNCTION AND NOT A LINE IN THE CLICK HANDLER:
//  the click handler is a mutation path on a view, = so the only thing a
//  test could read of its mapping was the SOURCE TEXT (= the shape this
//  card shipped with, = and the review's R2 finding: = a claim about a
//  write nobody can observe is not a guard). = Extracted, = every row
//  kind's answer is a value a test can name, = and the library root's
//  answer — the one the whole card turns on — is measured rather than
//  asserted.
//
//  Coverage:
//    1. The library root names itself (= `.referenceLibraryRoot`, = the
//       id the tree can resolve back to the row). = THE LOAD-BEARING
//       CASE: = the value it replaced (= `.referenceCategory(<title>)`)
//       named no row at all, = so clicking the root selected nothing.
//    2. A tag leaf names the tag string.
//    3. A divider writes nothing at all (= pure chrome).
//    4. A book row and the store name ONE book.
//    5. A folder row scopes the folder and still names the OWNING book.
//    6. The root's selection and the root's expansion key agree (= the
//       highlight and the reveal read the two, = so they cannot drift).
//
//  ⇒ ⇒ ⇒ Every case measures the PRODUCTION decision, = not a copy of
//  it in the test file.
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
struct SidebarRowWritesTests {
    private static func row(
        _ kind: SidebarNode.Kind,
        id: UUID = UUID(),
        title: String = "",
        routingKey: String? = nil,
        children: [SidebarNode]? = nil
    ) -> SidebarNode {
        SidebarNode(
            id: id,
            kind: kind,
            title: title,
            subtitle: nil,
            systemImage: "circle",
            children: children,
            routingKey: routingKey
        )
    }

    @Test("The library root names itself")
    func theLibraryRootNamesItself() {
        let root = Self.row(.reference, title: "Reference library", children: [
            Self.row(.tag, title: "poet", routingKey: "wenshu.tag.poet"),
        ])

        let writes = AppleSidebarView.writes(for: root, in: [root])

        // ⇒ ⇒ ⇒ `referenceLibraryRoot` is `.referenceCategory("__root__")`,
        // = so the assertion pins the IDENTITY and not the row's TITLE: =
        // the value this case replaced (= `.referenceCategory(node.title)`)
        // is a different value, = and deleting this case's rule sends
        // THIS test red (= the negative control the review asked for).
        #expect(writes.selection == .referenceLibraryRoot)
        #expect(writes.selectedBookId == nil)
    }

    @Test("A tag leaf names the tag string")
    func aTagLeafNamesTheTagString() {
        // ⇒ ⇒ ⇒ THE ROUTING KEY IS NOT THE TITLE: = a tag row's title
        // IS the tag string (= = = what the grid filters on), = = and
        // its routing key is a separate thing, = = so a writer that
        // took the wrong one of the two is caught here. = ⇒ ⇒ ⇒ With
        // the two equal, = = = the two spellings are indistinguishable
        // (= = = = = and the case would pass either way).
        let tag = Self.row(.tag, title: "poet", routingKey: "wenshu.tag.poet")

        let writes = AppleSidebarView.writes(for: tag, in: [tag])

        #expect(writes.selection == .tag("poet"))
        #expect(writes.selectedBookId == nil)
    }

    @Test("A divider writes nothing")
    func aDividerWritesNothing() {
        let divider = Self.row(.divider)

        let writes = AppleSidebarView.writes(for: divider, in: [divider])

        // ⇒ ⇒ ⇒ Both fields stay untouched (= the handler only assigns
        // what this returns, = so nil here means "keep what you had": =
        // the previous selection survives a click on chrome).
        #expect(writes.selection == nil)
        #expect(writes.selectedBookId == nil)
    }

    @Test("A book row and the store name one book")
    func aBookRowAndTheStoreNameOneBook() {
        let bookId = UUID()
        let book = Self.row(.book, id: bookId, title: "Li Bai")
        let shelf = Self.row(.shelf, title: "Works", children: [book])

        let writes = AppleSidebarView.writes(for: book, in: [shelf])

        #expect(writes.selection == .book(bookId))
        #expect(writes.selectedBookId == bookId)
    }

    @Test("A folder row scopes the folder and names the owning book")
    func aFolderRowNamesTheOwningBook() {
        let bookId = UUID()
        // A folder row shares the `.book` kind (= only a real book row
        // has children), = so the tree is what tells the two apart.
        let folder = Self.row(.book, title: "Drafts")
        let book = Self.row(.book, id: bookId, title: "Li Bai", children: [folder])
        let shelf = Self.row(.shelf, title: "Works", children: [book])

        let writes = AppleSidebarView.writes(for: folder, in: [shelf])

        // ⇒ THE INVARIANT the docblock claims: = the selection scopes the
        // FOLDER, = the store names the book that OWNS it, = and the two
        // are the same book, = so the style sheet's page and the editor
        // read one book.
        #expect(writes.selection == .folder(bookId: bookId, folderName: "Drafts"))
        #expect(writes.selectedBookId == bookId)
    }

    @Test("The root's selection and the root's expansion key agree")
    func theRootsTwoKeysAgree() {
        let root = Self.row(.reference, title: "Reference library", children: [
            Self.row(.tag, title: "poet", routingKey: "wenshu.tag.poet"),
        ])

        // ⇒ ⇒ ⇒ TWO readers, = ONE row: = the click writes
        // `writes(for:).selection`, = and the tree's expansion and reveal
        // read `expansionKey`. = If they drift, = the root highlights a
        // row the reveal cannot open. = Nothing but this assertion joins
        // them, = because they are two switch statements in two files.
        #expect(AppleSidebarView.writes(for: root, in: [root]).selection == root.expansionKey)
    }
}
