// TodoListViewTests.swift · Wenshu · v0.93 ticket 004
//
// Source-level structural tests for TodoListView (= per-(book × scope)
// todo list view mounted by DynamicZoneView in the aiDynamic zone).
// 464 LOC body / 30 in_degree dependents / 6 prior fixes in 90d /
// bug_magnet (= repowise health score 4.15, untested_hotspot critical).
//
// Per Q34 5.4 + v0.77 spec + v0.93 ticket 003 EditorPlaceholder pattern:
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

    /// v1.33 ticket 001 pattern: derive the TodoListView source path
    /// from THIS test file's path. Tests work regardless of where
    /// the worktree is mounted (= v1.32 hit a build failure when
    /// EditorPlaceholder was in a worktree because the old hardcoded
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
        let startRange = source.range(of: "public struct TodoListView")!
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
        #expect(section.contains("public struct TodoListView: View"),
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
        #expect(section.contains("public init() {}"),
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

        // v0.22 ticket h07: data-source-switch pattern (= reload from disk
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

    @Test("canAdd requires scopeDir + non-empty trimmed title (= input gate)")
    func canAddRequiresBothScopeDirAndTitle() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("private var canAdd: Bool {"),
                "TodoListView must declare canAdd computed (= input row enable gate)")
        #expect(section.contains("scopeDir != nil && !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty"),
                "canAdd must require BOTH scopeDir + non-empty trimmed title (= prevents empty / whitespace-only adds)")
    }

    @Test("reloadFromDisk resolves scope via bookStore.scopeDirectory (= B-09 data source switch)")
    func reloadFromDiskUsesBookStoreScopeDirectory() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("bookStore.scopeDirectory("),
                "reloadFromDisk must resolve scope via bookStore.scopeDirectory (= B-09 acceptance)")
        #expect(section.contains("let store = BookTodoStore(bookId: bookId, directory: dir, scope: scope)"),
                "reloadFromDisk must construct BookTodoStore with (bookId, directory, scope)")
        #expect(section.contains("items = try store.load()"),
                "reloadFromDisk must call store.load() (= the JSON read path)")
    }

    @Test("addItem persists via BookTodoStore.save + clears newItemTitle + resets priority (= B-09)")
    func addItemPersistsAndResetsState() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("PerBookTodoItem(title: trimmed, status: .pending, priority: newItemPriority)"),
                "addItem must construct PerBookTodoItem with .pending status (= new items start pending)")
        #expect(codeRegion.contains("try store.save(next)"),
                "addItem must persist via BookTodoStore.save (= B-09 acceptance: every add writes JSON)")
        #expect(codeRegion.contains("newItemTitle = \"\""),
                "addItem must clear newItemTitle after save (= inline-create reset)")
        #expect(codeRegion.contains("newItemPriority = .medium"),
                "addItem must reset newItemPriority to .medium after save (= inline-create reset)")
    }

    @Test("updateStatus persists + updates updatedAt (= B-09)")
    func updateStatusPersistsAndUpdatesTimestamp() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("next[idx].status = newStatus"),
                "updateStatus must mutate next[idx].status (= the in-memory update)")
        #expect(codeRegion.contains("next[idx].updatedAt = .now"),
                "updateStatus must refresh updatedAt (= ISO timestamp refresh per spec)")
        #expect(codeRegion.contains("try store.save(next)"),
                "updateStatus must persist via BookTodoStore.save (= B-09 acceptance)")
    }

    @Test("deleteItem filters by id + persists (= B-09)")
    func deleteItemFiltersByIdAndPersists() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("let next = items.filter { $0.id != item.id }"),
                "deleteItem must filter by item.id (= identity-based removal)")
        #expect(codeRegion.contains("try store.save(next)"),
                "deleteItem must persist via BookTodoStore.save (= B-09 acceptance)")
    }

    @Test("label(for:) covers all 4 TodoPriority cases with Chinese labels (= B-13)")
    func labelCoversAllFourPriorities() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        #expect(section.contains("case .low: return \"低\""),
                "label(for:) must map .low → \"低\"")
        #expect(section.contains("case .medium: return \"中\""),
                "label(for:) must map .medium → \"中\"")
        #expect(section.contains("case .high: return \"高\""),
                "label(for:) must map .high → \"高\"")
        #expect(section.contains("case .urgent: return \"紧急\""),
                "label(for:) must map .urgent → \"紧急\"")
    }

    @Test("TodoRow renders statusToggle with SF Symbol per status (= 4 cases)")
    func todoRowRendersStatusToggle() throws {
        let source = try readTodoListViewSource()
        // Find the TodoRow struct section
        let startRange = source.range(of: "private struct TodoRow")!
        let section = String(source[startRange.lowerBound...])
        #expect(section.contains("case .pending:") && section.contains("Image(systemName: \"circle\")"),
                "TodoRow statusToggle .pending must render circle SF Symbol (= empty checkbox)")
        #expect(section.contains("case .inProgress:") && section.contains("Image(systemName: \"circle.dotted\")"),
                "TodoRow statusToggle .inProgress must render circle.dotted SF Symbol (= in-progress marker)")
        #expect(section.contains("case .completed:") && section.contains("Image(systemName: \"checkmark.circle\")"),
                "TodoRow statusToggle .completed must render checkmark.circle SF Symbol (= done marker)")
        #expect(section.contains("case .cancelled:") && section.contains("Image(systemName: \"xmark.circle\")"),
                "TodoRow statusToggle .cancelled must render xmark.circle SF Symbol (= cancelled marker, no button)")
    }

    @Test("priorityChip uses chipStyle palette for all 4 priorities (= B-13 visual distinction)")
    func priorityChipCoversAllFourPriorities() throws {
        let source = try readTodoListViewSource()
        let startRange = source.range(of: "private func chipStyle(for priority: TodoPriority)")!
        let section = String(source[startRange.lowerBound...])
        // Take the switch body — until the closing brace of the function
        let endRange = section.range(of: "}\n}", options: .literal)?.lowerBound ?? section.endIndex
        let chipSection = String(section[..<endRange])

        // B-13: low/medium = neutral palette, high/urgent = warm warning palette
        #expect(chipSection.contains("case .low: return (\"低\", Color.secondary"),
                "chipStyle .low must use secondary foreground")
        #expect(chipSection.contains("case .medium: return (\"中\", Color.primary"),
                "chipStyle .medium must use primary foreground")
        #expect(chipSection.contains("case .high: return (\"高\", Color.orange"),
                "chipStyle .high must use orange foreground (= warm warning)")
        #expect(chipSection.contains("case .urgent: return (\"紧急\", Color.red"),
                "chipStyle .urgent must use red foreground (= urgent warning)")
    }

    @Test("dueDateLabel renders overdue state in red + .secondary otherwise (= B-13)")
    func dueDateLabelOverdueStateIsRed() throws {
        let source = try readTodoListViewSource()
        let startRange = source.range(of: "private var dueDateLabel: some View")!
        let section = String(source[startRange.lowerBound...])
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("isOverdue ? Color.red : Color.secondary"),
                "dueDateLabel must render red when overdue, .secondary otherwise (= B-13 visual urgency)")
        #expect(codeRegion.contains("if isOverdue {"),
                "dueDateLabel must render an overdue label when isOverdue (= \"已过期\")")
    }

    @Test("scopeUnavailableHint differentiates referenceLibrary from book/folder (= B-13)")
    func scopeUnavailableHintDifferentiatesByScope() throws {
        let source = try readTodoListViewSource()
        let section = todoListViewSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        // B-13: different message for reference library vs missing book.
        #expect(codeRegion.contains("case .referenceLibrary:"),
                "scopeUnavailableHint must special-case .referenceLibrary (= \"资料库未 bootstrap\")")
        #expect(codeRegion.contains("case .book, .folder:"),
                "scopeUnavailableHint must merge .book + .folder (= \"先在左侧书架里选一本书\")")
    }
}