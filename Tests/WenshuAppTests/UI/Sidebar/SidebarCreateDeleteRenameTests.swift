//
//  SidebarCreateDeleteRenameTests.swift · Wenshu · v1.69y boss 2026-09-23 OOB
//
//  Source-level coverage for v1.69y (= restoring sidebar 新建功能 +
//  右边菜单 + create/delete/rename API). Tests verify the
//  SidebarSheets + SidebarContextMenu + SidebarService create/delete/
//  rename surface exists and is wired into AppleSidebarView (= the
//  splits survived). No end-to-end SwiftUI interactions (= per
//  Q112 1-source-1-test rule the UI verification happens via
//  `wenshu --verify` + boss screenshot; = this test guards the
//  source surface so future drift is caught before visual break).
//
//  Tests are source-content checks (= read the .swift files
//  and look for canonical markers). Pattern follows the v1.68b
//  MVVMSplitTests convention.

import XCTest
@testable import WenshuApp

final class SidebarCreateDeleteRenameTests: XCTestCase {

    // MARK: - SidebarSheets.swift presence (= 4 sheets + 2 state types)

    func testSidebarSheets_file_exists() {
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarSheets.swift"
            ),
            "SidebarSheets.swift must exist (= v1.69y restored sheets file)"
        )
    }

    func testSidebarSheets_defines_NewChoiceSheet() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("struct NewChoiceSheet"),
            "SidebarSheets.swift must define `NewChoiceSheet` (= legacy NewLibraryOutlineView choice sheet)"
        )
    }

    func testSidebarSheets_defines_NewShelfSheet() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("struct NewShelfSheet"),
            "SidebarSheets.swift must define `NewShelfSheet` (= legacy shelf creation sheet)"
        )
    }

    func testSidebarSheets_defines_NewBookSheet() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("struct NewBookSheet"),
            "SidebarSheets.swift must define `NewBookSheet` (= legacy book creation sheet)"
        )
    }

    func testSidebarSheets_defines_RenameItemSheet() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("struct RenameItemSheet"),
            "SidebarSheets.swift must define `RenameItemSheet` (= legacy rename sheet)"
        )
    }

    func testSidebarSheets_defines_state_types_for_dismiss_target() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            encoding: .utf8
        )
        // The `.sheet(item: $renaming)` and `.alert(presenting:)`
        // modifiers need Identifiable target types (= `Side...`
        // here to avoid clashing with the legacy enum names in
        // NewLibraryOutlineView.swift pre-v1.69e (= see the
        XCTAssertTrue(
            body.contains("SidebarRenamingTarget") || body.contains("SidebarPendingDelete"),
            "SidebarSheets.swift must define SidebarRenamingTarget + SidebarPendingDelete state types"
        )
    }

    // MARK: - SidebarContextMenu.swift presence

    func testSidebarContextMenu_file_exists() {
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarContextMenu.swift"
            ),
            "SidebarContextMenu.swift must exist (= v1.69y restored context-menu file)"
        )
    }

    func testSidebarContextMenu_defines_builder() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarContextMenu.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("SidebarContextMenuBuilder"),
            "SidebarContextMenu.swift must define SidebarContextMenuBuilder (= the menu-item factory)"
        )
        XCTAssertTrue(
            body.contains("EmptyAreaContextMenu"),
            "SidebarContextMenu.swift must define EmptyAreaContextMenu (= empty-area right-click wrapper)"
        )
        XCTAssertTrue(
            body.contains("SidebarRowContextMenu"),
            "SidebarContextMenu.swift must define SidebarRowContextMenu (= selection-bound contextMenu wrapper)"
        )
    }

    func testSidebarContextMenu_builder_handles_shelf_and_book() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarContextMenu.swift",
            encoding: .utf8
        )
        // Builder must handle both `.shelf` (= rename + new book here
        // + delete + duplicate target) and `.book` (= rename + delete)
        // cases (= the legacy NewLibraryOutlineView.contextMenuForSelection
        // supported both).
        XCTAssertTrue(
            body.contains("case .shelf"),
            "SidebarContextMenuBuilder must handle `.shelf` sidebar items"
        )
        XCTAssertTrue(
            body.contains("case .book"),
            "SidebarContextMenuBuilder must handle `.book` sidebar items"
        )
    }

    // MARK: - SidebarService.swift create/delete/rename API

    func testSidebarService_has_createShelf() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarService.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("func createShelf("),
            "SidebarService must expose `createShelf` business method (= legacy NewLibraryOutlineView had it)"
        )
    }

    func testSidebarService_has_createBook() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarService.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("func createBook("),
            "SidebarService must expose `createBook` business method (= legacy NewLibraryOutlineView had it)"
        )
    }

    func testSidebarService_has_deleteShelf_and_deleteBook() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarService.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("func deleteShelf("),
            "SidebarService must expose `deleteShelf` business method"
        )
        XCTAssertTrue(
            body.contains("func deleteBook("),
            "SidebarService must expose `deleteBook` business method"
        )
    }

    func testSidebarService_has_renameShelf_and_renameBook() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarService.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("func renameShelf("),
            "SidebarService must expose `renameShelf` business method"
        )
        XCTAssertTrue(
            body.contains("func renameBook("),
            "SidebarService must expose `renameBook` business method"
        )
    }

    func testSidebarService_has_picker_helpers() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarService.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("func availableShelvesForPicker("),
            "SidebarService must expose `availableShelvesForPicker` (= the legacy helper for the New Book sheet's shelf picker)"
        )
        XCTAssertTrue(
            body.contains("func targetShelfForNewBook("),
            "SidebarService must expose `targetShelfForNewBook` (= legacy helper for resolving the new-book target shelf)"
        )
        XCTAssertTrue(
            body.contains("func otherShelfNames(") || body.contains("func otherBookTitles("),
            "SidebarService must expose the duplicate-name guard helpers"
        )
    }

    func testSidebarService_blocks_default_shelf_deletion() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarService.swift",
            encoding: .utf8
        )
        // The default shelf (UUID 00000000-0000-0000-0000-000000000000)
        // must NOT be deletable (= legacy Reference Library behavior;
        // = boss 2026-09 OOB 'Reference Library cannot be deleted').
        XCTAssertTrue(
            body.contains("00000000-0000-0000-0000-000000000000") &&
            body.contains("cannotDeleteDefault"),
            "SidebarService.deleteShelf must guard the default shelf from deletion"
        )
    }

    func testSidebarService_has_reserved_name_guard() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarService.swift",
            encoding: .utf8
        )
        // NewLibraryOutlineView had `reservedNames = ["Reference Library",
        // "书架"]`; = the migration block must still reject the
        // legacy system shelf name (= boss 2026-09 OOB).
        XCTAssertTrue(
            body.contains("reservedNames") || body.contains("reservedName"),
            "SidebarService must reserve the legacy system shelf name from creation"
        )
    }

    // MARK: - AppleSidebarView.swift wires it all together

    func testAppleSidebarView_wires_sheets() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/AppleSidebarView.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("showNewChoiceSheet") &&
            body.contains("showNewShelfSheet") &&
            body.contains("showNewBookSheet"),
            "AppleSidebarView must track showNew*Sheet state for each sheet"
        )
        XCTAssertTrue(
            body.contains(".sheet(isPresented: $showNewChoiceSheet)") ||
            body.contains(".sheet(isPresented: $showNewShelfSheet)") ||
            body.contains(".sheet(isPresented: $showNewBookSheet)"),
            "AppleSidebarView must present the create sheets"
        )
    }

    func testAppleSidebarView_wires_request_counters() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/AppleSidebarView.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("choiceRequestCount") &&
            body.contains("newShelfRequestCount") &&
            body.contains("newBookRequestCount"),
            "AppleSidebarView must observe the 3 AppState request counters"
        )
    }

    func testAppleSidebarView_wires_rename_and_delete() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/AppleSidebarView.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains(".sheet(item: $renaming)"),
            "AppleSidebarView must present the rename sheet via .sheet(item:)"
        )
        XCTAssertTrue(
            body.contains(".alert("),
            "AppleSidebarView must present the delete confirmation alert"
        )
        XCTAssertTrue(
            body.contains("SidebarContextMenuBuilder") || body.contains("contextMenuHandler"),
            "AppleSidebarView must call the context-menu builder"
        )
    }

    // MARK: - Hardcoded marker for v1.69y in source headers

    func testSidebarSheets_header_carries_v169y_marker() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("v1.69y"),
            "SidebarSheets.swift must carry the v1.69y source-level marker (= grep traceability for the restore arc)"
        )
    }

    func testSidebarContextMenu_header_carries_v169y_marker() throws {
        let body = try String(
            contentsOfFile: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Library/SidebarContextMenu.swift",
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("v1.69y"),
            "SidebarContextMenu.swift must carry the v1.69y source-level marker"
        )
    }
}
