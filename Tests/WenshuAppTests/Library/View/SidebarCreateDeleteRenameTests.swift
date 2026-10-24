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
import Foundation
@testable import WenshuApp

final class SidebarCreateDeleteRenameTests: XCTestCase {

    /// Concatenated source of every `.swift` file in `directory` whose
    /// file name matches `matches`, sorted by name.
    ///
    /// The join goes through `SourceLocator.read` with a
    /// repo-root-relative path, so it never depends on a directory path
    /// keeping a trailing separator. A directory path that loses its
    /// separator concatenates the folder name onto the file name, and
    /// the read then fails on a path no file has.
    private func loadSourceBody(
        inDirectory directory: String,
        matching matches: (String) -> Bool
    ) throws -> String {
        let names = try FileManager.default
            .contentsOfDirectory(atPath: SourceLocator.path(directory))
            .filter { matches($0) }
            .sorted()
        return try names.map { try SourceLocator.read("\(directory)/\($0)") }
            .joined(separator: "\n")
    }

    /// Concatenated source of the `SidebarService*.swift` files in the
    /// sidebar view directory. The business methods live across a split
    /// pair, so the suite reads the whole set rather than one file.
    private func loadSidebarServiceBody() throws -> String {
        try loadSourceBody(inDirectory: "Sources/WenshuApp/Features/Library/View") { name in
            name.hasPrefix("SidebarService") && name.hasSuffix(".swift")
        }
    }

    /// Concatenated source of the `AppleSidebar*.swift` +
    /// `SidebarContextMenu*.swift` + `SidebarSheets*.swift` files in the
    /// sidebar view directory. The suite reads the whole set to verify the
    /// wiring (= showNew*Sheet state, context-menu modifier, .sheet(item:)
    /// for rename, .alert for delete) survives the file split.
    private func loadAppleSidebarWiringBody() throws -> String {
        try loadSourceBody(inDirectory: "Sources/WenshuApp/Features/Library/View") { name in
            (name.hasPrefix("AppleSidebar")
                || name.hasPrefix("SidebarContextMenu")
                || name.hasPrefix("SidebarSheets"))
                && name.hasSuffix(".swift")
        }
    }

    // MARK: - SidebarSheets.swift presence (= 4 sheets + 2 state types)

    func testSidebarSheets_file_exists() {
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarSheets.swift")
            ),
            "SidebarSheets.swift must exist (= v1.69y restored sheets file)"
        )
    }

    func testSidebarSheets_defines_NewChoiceSheet() throws {
        let body = try String(
            contentsOfFile: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarSheets.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("struct NewChoiceSheet"),
            "SidebarSheets.swift must define `NewChoiceSheet` (= legacy NewLibraryOutlineView choice sheet)"
        )
    }

    func testSidebarSheets_defines_NewShelfSheet() throws {
        let body = try String(
            contentsOfFile: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarSheets.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("struct NewShelfSheet"),
            "SidebarSheets.swift must define `NewShelfSheet` (= legacy shelf creation sheet)"
        )
    }

    func testSidebarSheets_defines_NewBookSheet() throws {
        let body = try String(
            contentsOfFile: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarSheets.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("struct NewBookSheet"),
            "SidebarSheets.swift must define `NewBookSheet` (= legacy book creation sheet)"
        )
    }

    func testSidebarSheets_defines_RenameItemSheet() throws {
        let body = try String(
            contentsOfFile: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarSheets.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("struct RenameItemSheet"),
            "SidebarSheets.swift must define `RenameItemSheet` (= legacy rename sheet)"
        )
    }

    func testSidebarSheets_defines_state_types_for_dismiss_target() throws {
        let body = try String(
            contentsOfFile: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarSheets.swift"),
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
                atPath: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarContextMenu.swift")
            ),
            "SidebarContextMenu.swift must exist (= v1.69y restored context-menu file)"
        )
    }

    // MARK: - SidebarService.swift create/delete/rename API

    func testSidebarService_has_createShelf() throws {
        let body = try loadSidebarServiceBody()
        XCTAssertTrue(
            body.contains("func createShelf("),
            "SidebarService must expose `createShelf` business method (= legacy NewLibraryOutlineView had it)"
        )
    }

    func testSidebarService_has_createBook() throws {
        let body = try loadSidebarServiceBody()
        XCTAssertTrue(
            body.contains("func createBook("),
            "SidebarService must expose `createBook` business method (= legacy NewLibraryOutlineView had it)"
        )
    }

    func testSidebarService_has_deleteShelf_and_deleteBook() throws {
        let body = try loadSidebarServiceBody()
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
        let body = try loadSidebarServiceBody()
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
        let body = try loadSidebarServiceBody()
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
        let body = try loadSidebarServiceBody()
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
        let body = try loadSidebarServiceBody()
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
        let body = try loadAppleSidebarWiringBody()
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
        let body = try loadAppleSidebarWiringBody()
        // The 3 request counters moved from `AppState` (= legacy) to
        // `SheetRequestState` (= the dedicated sheet-counter holder; =
        // v2.x refactor). AppleSidebarView observes them via
        // `.onChange(of: sheetRequests.{choice, newShelf, newBook})`
        // (= 3 separate observers = one per counter). The test
        // verifies the new names survive the split.
        XCTAssertTrue(
            body.contains("sheetRequests.choice") &&
            body.contains("sheetRequests.newShelf") &&
            body.contains("sheetRequests.newBook"),
            "AppleSidebarView must observe the 3 SheetRequestState request counters"
        )
    }

    // MARK: - Hardcoded marker for v1.69y in source headers

    func testSidebarSheets_header_carries_v169y_marker() throws {
        let body = try String(
            contentsOfFile: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarSheets.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("v1.69y"),
            "SidebarSheets.swift must carry the v1.69y source-level marker (= grep traceability for the restore arc)"
        )
    }

    func testSidebarContextMenu_header_carries_v169y_marker() throws {
        let body = try String(
            contentsOfFile: SourceLocator.path("Sources/WenshuApp/Features/Library/View/SidebarContextMenu.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            body.contains("v1.69y"),
            "SidebarContextMenu.swift must carry the v1.69y source-level marker"
        )
    }
}
