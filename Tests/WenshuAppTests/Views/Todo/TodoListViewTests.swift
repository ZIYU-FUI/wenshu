// TodoListViewTests.swift · Wenshu · v0.93 ticket 004
//
// Source-level structural tests for TodoListView (= per-(book × scope)
// todo list view mounted by DynamicZoneView in the aiDynamic zone).
// 464 LOC body / 30 in_degree dependents / 6 prior fixes in 90d /
// bug_magnet (= repowise health score 4.15, untested_hotspot critical).
//
// Per Q34 5.4 + v0.77 spec + v0.93 ticket 003 EditorView pattern:
// structural source-level assertions capture the boss-spec invariants
// (= scope picker, status sections, priority chip, due-date overdue,
// reload trigger conditions, BookTodoStore JSON file naming). ViewInspector
// behavior tests deferred (= requires BookStore + JSON file mock scaffolding
// per v0.77 spec; = exceeds 1-ticket Q112 scope).
//
// Each test reads the source file from THIS test file's path (#filePath),
// not Bundle.module.url (= Bundle.module doesn't expose source files at
// runtime in a SwiftPM testTarget; = worktree-aware per v1.33 ticket 001).

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("TodoListView (v0.93 ticket 004 — per-(book × scope) todo list)")
struct TodoListViewTests {

    /// 
    /// from THIS test file's path. Tests work regardless of where
    /// the worktree is mounted (= v1.32 hit a build failure when
    /// EditorView was in a worktree because the old hardcoded
    /// path pointed to the main worktree).
    private static var todoListViewPath: String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let testsDir = testFileURL.deletingLastPathComponent()  // Views/Todo/
        let repoRoot = testsDir
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        return repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("WenshuApp")
            .appendingPathComponent("Views")
            .appendingPathComponent("Todo")
            .appendingPathComponent("TodoListView.swift")
            .path
    }

    private func readTodoListViewSource() throws -> String {
        return try String(contentsOfFile: Self.todoListViewPath, encoding: .utf8)
    }

    /// Extract the TodoListView struct section (= until the next top-level
    /// struct or end-of-file). `TodoRow` is a separate private struct
    /// after the main one; = section delimiter = "private struct TodoRow".
    private func todoListViewSection(_ source: String) -> String {
        let startRange = source.range(of: "struct TodoListView")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "private struct TodoRow")?.lowerBound
            ?? section.endIndex
        return String(section[..<endOfStruct])
    }

    // MARK: - Structural tests

    @Test("struct conforms to View + is public (= API surface)")
    func conformsToViewAndIsPublic() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("struct TodoListView: View"),
                "TodoListView must be public + conform to View (= DynamicZoneView mounts it)")
    }

    @Test("reads BookStore from environment (= v0.22 ticket h07)")
    func readsBookStoreFromEnvironment() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("@Environment(BookStore.self) private var bookStore"),
                "TodoListView must read BookStore from environment (= scopeDirectory + selectedBookId source)")
    }

    @Test("declares scope picker state defaulting to .book (= B-13 spec)")
    func declaresScopeStateDefaultingToBook() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("@State private var scope: TaskScope = .book"),
                "TodoListView must default scope = .book (= B-13: book root is the primary working scope)")
    }

    @Test("declares items + newItemTitle + newItemPriority + loadError state (= 4 @State vars)")
    func declaresAllItemState() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("@State private var items: [PerBookTodoItem] = []"),
                "TodoListView must declare items @State (= the in-memory todo list)")
        #expect(section.contains("@State private var newItemTitle: String = \"\""),
                "TodoListView must declare newItemTitle @State (= inline-create row text field)")
        #expect(section.contains("@State private var newItemPriority: TodoPriority = .medium"),
                "TodoListView must declare newItemPriority @State defaulting to .medium (= B-13 visual distinction)")
        #expect(section.contains("@State private var loadError: String? = nil"),
                "TodoListView must declare loadError @State (= error feedback for save / load failures)")
    }

    @Test("declares scopeDir @State (= resolved directory cache for (book × scope))")
    func declaresScopeDirState() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("@State private var scopeDir: URL? = nil"),
                "TodoListView must cache scopeDir (= used by canAdd + addItem guard)")
    }

    @Test("declares public init() (= empty initializer)")
    func declaresEmptyPublicInit() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("init() {}"),
                "TodoListView must expose public init() (= DynamicZoneView mounts it with no args)")
    }

    @Test("body wires reloadFromDisk on appear + bookStore.selectedBookId + scope change (= 3 triggers)")
    func bodyWiresThreeReloadTriggers() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        // 
        // when book id OR scope changes). Boss B-09 acceptance.
        #expect(codeRegion.contains(".onAppear { reloadFromDisk() }"),
                "TodoListView body must call reloadFromDisk on .onAppear (= initial load trigger)")
        #expect(codeRegion.contains(".onChange(of: bookStore.selectedBookId)"),
                "TodoListView body must call reloadFromDisk on bookStore.selectedBookId change (= B-09 acceptance)")
        #expect(codeRegion.contains(".onChange(of: scope)"),
                "TodoListView body must call reloadFromDisk on scope change (= B-13 acceptance)")
    }

    @Test("header renders scope Picker with .menu style (= boss spec)")
    func headerRendersScopePicker() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("Picker(\"scope\", selection: $scope)"),
                "TodoListView header must declare a scope Picker (= B-13 acceptance)")
        #expect(section.contains(".pickerStyle(.menu)"),
                "TodoListView header scope Picker must use .menu style (= Apple HIG menu picker)")
    }

    @Test("jsonHint maps all 3 TaskScope cases to distinct JSON filenames (= B-13)")
    func jsonHintMapsAllThreeScopes() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("return \"todo.json\""),
                "jsonHint must return todo.json for .book scope")
        #expect(section.contains("return \"todo-\\(f.folderName).json\""),
                "jsonHint must return todo-<folder>.json for .folder scope (= per-folder JSON)")
        #expect(section.contains("return \"library-todo.json\""),
                "jsonHint must return library-todo.json for .referenceLibrary scope")
    }

    @Test("inputRow uses .borderedProminent style for add button (= Apple HIG)")
    func inputRowUsesBorderedProminentStyle() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains(".buttonStyle(.borderedProminent)"),
                "TodoListView add button must use .borderedProminent style (= Apple HIG primary action)")
        #expect(section.contains(".disabled(!canAdd)"),
                "TodoListView add button must be disabled when !canAdd (= inline-create guard)")
    }

    @Test("content ViewBuilder handles 3 branches (= no scope / empty / has items)")
    func contentViewBuilderHandlesThreeBranches() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        // content is @ViewBuilder, must have all 3 cases:
        //   1. scopeDir == nil → scopeUnavailableHint
        //   2. items.isEmpty → empty state Text
        //   3. else → 4 status sections
        #expect(codeRegion.contains("if scopeDir == nil"),
                "content must branch on scopeDir == nil (= show unavailable hint)")
        #expect(codeRegion.contains("else if items.isEmpty"),
                "content must branch on items.isEmpty (= show empty state)")
        // 4 status sections (= pending + inProgress + completed + cancelled)
        #expect(codeRegion.contains("section(title: \"待处理"),
                "content must render pending section (= 待处理 = first per boss spec)")
        #expect(codeRegion.contains("section(title: \"进行中"),
                "content must render inProgress section")
        #expect(codeRegion.contains("section(title: \"已完成"),
                "content must render completed section")
        #expect(codeRegion.contains("section(title: \"已取消"),
                "content must render cancelled section (= kept visible per boss spec)")
    }

    @Test("itemsByStatus sorts by priority desc then createdAt asc (= boss spec)")
    func itemsByStatusSortOrder() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("a.priority.rawValue != b.priority.rawValue"),
                "itemsByStatus must compare via priority.rawValue (= TodoPriority isn't Comparable)")
        #expect(codeRegion.contains("a.priority.rawValue > b.priority.rawValue"),
                "itemsByStatus must sort priority descending (= urgent first)")
        #expect(codeRegion.contains("return a.createdAt < b.createdAt"),
                "itemsByStatus tie-breaks by createdAt ascending (= earlier items surface first within same priority)")
    }
}
