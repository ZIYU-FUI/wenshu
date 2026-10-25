//
//  SidebarPartStateTests.swift · wenshu
//
//  The sidebar has three parts, and each part remembers what was
//  selected in it.
//
//  Coverage:
//    1. The part enumeration has three cases with non-empty display
//       names.
//    2. The selection per part round-trips through the user's defaults.
//    3. Changing the current part restores that part's remembered
//       selection.
//    4. Changing the current part to one with no remembered selection
//       leaves the selection empty.
//    5. The lookup resolves a shelf, a book, a folder, a category row,
//       and a tag row against a tree that holds all of them.
//    6. The sidebar service exposes the shelf hierarchy and the
//       reference library hierarchy as separate collections, and the
//       divider row is gone.
//

import XCTest
@testable import WenshuApp

@MainActor
final class SidebarPartStateTests: XCTestCase {

    // MARK: - The part enumeration

    func testThePartEnumerationHasThreeCasesWithDisplayNames() {
        XCTAssertEqual(SidebarPart.allCases.count, 3)
        for part in SidebarPart.allCases {
            XCTAssertFalse(
                part.displayName.isEmpty,
                "Every part carries a display name."
            )
            XCTAssertTrue(
                part.displayNameKey.allSatisfy { $0.isASCII },
                "The display name key must be plain ASCII."
            )
        }
    }


    // MARK: - The per-part selection

    func testTheSelectionPerPartRoundTripsThroughTheDefaults() {
        let defaults = UserDefaults(suiteName: "sidebar-part-state-test")!
        defaults.removePersistentDomain(forName: "sidebar-part-state-test")
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        state.currentSidebarPart = .library
        state.sidebarSelection = .tag("poet")

        // A fresh state over the same defaults restores the part and its
        // remembered selection.
        let restored = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        XCTAssertEqual(restored.currentSidebarPart, .library)
        XCTAssertEqual(restored.sidebarSelection, .tag("poet"))
        defaults.removePersistentDomain(forName: "sidebar-part-state-test")
    }

    func testChangingTheCurrentPartRestoresThatPartsRememberedSelection() {
        let defaults = UserDefaults(suiteName: "sidebar-part-state-test-2")!
        defaults.removePersistentDomain(forName: "sidebar-part-state-test-2")
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))

        state.currentSidebarPart = .shelves
        state.sidebarSelection = .shelf(UUID())
        let shelfSelection = state.sidebarSelection

        state.currentSidebarPart = .library
        state.sidebarSelection = .tag("poet")

        state.currentSidebarPart = .shelves
        XCTAssertEqual(
            state.sidebarSelection,
            shelfSelection,
            "The shelves part must remember what was selected in it."
        )
        defaults.removePersistentDomain(forName: "sidebar-part-state-test-2")
    }

    func testChangingToAPartWithNoRememberedSelectionLeavesItEmpty() {
        let defaults = UserDefaults(suiteName: "sidebar-part-state-test-3")!
        defaults.removePersistentDomain(forName: "sidebar-part-state-test-3")
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))

        state.currentSidebarPart = .shelves
        state.sidebarSelection = .shelf(UUID())

        state.currentSidebarPart = .library
        XCTAssertNil(
            state.sidebarSelection,
            "A part with no remembered selection leaves nothing selected."
        )
        defaults.removePersistentDomain(forName: "sidebar-part-state-test-3")
    }

    // MARK: - The two hierarchies

    func testTheServiceExposesTheShelfAndTheLibraryHierarchiesSeparately() async {
        let service = SidebarService(
            loadShelves: { [] },
            loadAllBooks: { [] },
            loadReferences: { [] }
        )
        await service.reload()
        // The service loads the two hierarchies separately; = the sidebar
        // shows one per part.
        XCTAssertTrue(service.shelfNodes.isEmpty)
        XCTAssertEqual(service.libraryNodes.count, 1)
        XCTAssertEqual(service.libraryNodes.first?.kind, .reference)
        XCTAssertFalse(
            service.libraryNodes.contains { $0.kind == .divider },
            "The divider row is gone: = the parts no longer share a list."
        )
        XCTAssertFalse(
            service.shelfNodes.contains { $0.kind == .divider },
            "The divider row is gone: = the parts no longer share a list."
        )
    }

    // MARK: - The lookup

    func testTheLookupResolvesEverySelectionCaseAgainstTheTree() {
        let shelfId = UUID()
        let bookId = UUID()
        let tree: [SidebarNode] = [
            SidebarNode(
                id: shelfId,
                kind: .shelf,
                title: "Shelf",
                subtitle: nil,
                systemImage: "books.vertical",
                children: [
                    SidebarNode(
                        id: bookId,
                        kind: .book,
                        title: "Book",
                        subtitle: nil,
                        systemImage: "book",
                        children: [
                            SidebarNode(
                                id: UUID(),
                                kind: .book,
                                title: "Worldview",
                                subtitle: nil,
                                systemImage: "globe",
                                children: nil
                            )
                        ]
                    )
                ]
            ),
            SidebarNode(
                id: UUID(),
                kind: .referenceCategory,
                title: "Literature",
                subtitle: nil,
                systemImage: "book.pages",
                children: [
                    SidebarNode(
                        id: UUID(),
                        kind: .tag,
                        title: "poet",
                        subtitle: nil,
                        systemImage: "tag",
                        children: nil,
                        routingKey: "poet"
                    )
                ]
            )
        ]

        XCTAssertEqual(
            AppleSidebarView.node(for: .shelf(shelfId), in: tree)?.id,
            shelfId
        )
        XCTAssertEqual(
            AppleSidebarView.node(for: .book(bookId), in: tree)?.id,
            bookId
        )
        XCTAssertEqual(
            AppleSidebarView.node(for: .folder(bookId: bookId, folderName: "Worldview"), in: tree)?.title,
            "Worldview"
        )
        XCTAssertEqual(
            AppleSidebarView.node(for: .referenceCategory("Literature"), in: tree)?.title,
            "Literature"
        )
        XCTAssertEqual(
            AppleSidebarView.node(for: .tag("poet"), in: tree)?.title,
            "poet"
        )
        XCTAssertNil(AppleSidebarView.node(for: nil, in: tree))
    }
}
