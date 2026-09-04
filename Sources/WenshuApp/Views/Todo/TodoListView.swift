//
//  TodoListView.swift · Wenshu · v0.22 ticket h07 (hermes replica, frontend mount) + B-09 + B-13
//
//  Per-(book × scope) todo list. Reads + writes a scope-aware todo
//  JSON file (= BookTodoStore). Same data-source-switch pattern as
//  KanbanView: when `bookStore.selectedBookId` OR the local `@State
//  scope` changes, reload from disk.
//
//  Layout (Boss B-09 acceptance):
//    - Top bar: 待办 title + scope picker + "+ 添加待办" button
//      (= "添加待办" rather than Kanban's "新建" — visual distinction
//      per boss Issue 1: "Kanban 和 Todo 看起来是一回事呢").
//    - Input row: text field + priority picker + return-to-add
//      (Apple HIG inline-create).
//    - Body: per-status sectioned list (= pending / inProgress /
//      cancelled). Each row = checkbox + title + priority chip
//      (= B-13 visual distinction: Todo gets a PROMINENT color-coded
//      chip with priority text — Kanban doesn't have priority) +
//      due-date display (= red highlight if past today + no due
//      date text in `.secondary`) + delete + "开始" / "完成" / "取消"
//      context actions.
//    - Empty state when no book selected / no items.
//
//  B-13 (= boss 2026-09-04 OOB "这两个看板都有同一个问题"): the scope
//  picker (= .menu Picker over the 8 standard sub-folders + book root
//  + reference library) drives which JSON file the view reads from /
//  writes to. Scope is a view filter, not a data-layer change.
//
//  Persistence:
//    - BookTodoStore.save([PerBookTodoItem]) writes the whole array
//      atomically (= per spec v5 ticket 026). On every add / status
//      change / delete, the view reloads from disk + writes back.
//
//  Apple HIG: small icon button + .bordered / .borderedProminent
//  button styles per macOS 26 Tahoe guidance. No sheet (per
//  v0.24 boss 8/24 OOB 'dynamic zone 应该是 tab 模式, 不是 sheet').
//

import SwiftUI

/// Per-(book × scope) todo list view. Mounted by `DynamicZoneView` in
/// the `aiDynamic` zone (= tab "待办"). Reads from `BookTodoStore`
/// (= scope-aware todo JSON: `todo.json` / `todo-<folder>.json` /
/// `library-todo.json`).
public struct TodoListView: View {
    @Environment(BookStore.self) private var bookStore

    /// B-13: active scope (book root / 8 sub-folders / reference
    /// library). Reload-from-disk happens in `.onChange(of: scope)`.
    @State private var scope: TaskScope = .book

    @State private var items: [PerBookTodoItem] = []
    @State private var newItemTitle: String = ""
    @State private var newItemPriority: TodoPriority = .medium
    @State private var loadError: String? = nil

    /// Resolved directory for `(selectedBookId, scope)`. Nil when the
    /// active scope has no on-disk directory.
    @State private var scopeDir: URL? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            inputRow
            if let err = loadError {
                Text("(加载失败: \(err))")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            content
        }
        .padding(8)
        // v0.24 boss验收fix: flexible sizing (zone size controlled by splitter, not view).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // B-09 + B-13: re-load when the active book OR scope changes.
        .onAppear { reloadFromDisk() }
        .onChange(of: bookStore.selectedBookId) { _, _ in reloadFromDisk() }
        .onChange(of: scope) { _, _ in reloadFromDisk() }
    }

    // MARK: - Subviews

    /// Header: 待办 title + scope picker + count + json hint.
    /// B-13: scope picker drives the JSON file the view reads from.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("待办")
                .font(.headline)
            Picker("scope", selection: $scope) {
                ForEach(bookStore.availableScopes(bookId: bookStore.selectedBookId)) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .help("切换待办数据范围 (= 全书 / 8 标准子目录 / 资料库)")
            Spacer()
            Text("\(items.count) 项 · \(jsonHint)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// B-13: hint text showing which JSON file the active scope
    /// reads from (= mirror of `KanbanView.jsonHint`).
    private var jsonHint: String {
        switch scope {
        case .book:
            return "todo.json"
        case .folder(let f):
            return "todo-\(f.folderName).json"
        case .referenceLibrary:
            return "library-todo.json"
        }
    }

    /// Inline-create row (Apple HIG text field + priority picker
    /// + return-to-submit). Disabled when the scope has no resolved
    /// directory or the text is empty.
    /// B-12 fix: `.disabled(...)` is placed BEFORE `.buttonStyle(...)`
    /// so SwiftUI applies the disabled visual state (gray-out) to the
    /// button content, not to the styled wrapper; `.help(...)` exposes
    /// the reason on hover; an inline caption explains why the button
    /// is inactive when no directory is resolved (= Apple HIG
    /// disabled-control feedback).
    /// B-13 visual distinction: button label = "+ 添加待办" (= not
    /// Kanban's "+ 新建"). This + the priority chip on each row
    /// (= below) are the two boss-Issue-1 differentiators.
    private var inputRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TextField("新待办标题…", text: $newItemTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addItem() }
                Picker("优先级", selection: $newItemPriority) {
                    ForEach(TodoPriority.allCases, id: \.self) { p in
                        Text(label(for: p)).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                Button(action: addItem) {
                    Label("添加待办", systemImage: "plus")
                }
                .disabled(!canAdd)
                .buttonStyle(.borderedProminent)
                .help(addButtonHelp)
            }
            if scopeDir == nil {
                Text(scopeUnavailableHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("输入标题后才能新建")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// B-13: explain why the add row is inactive. Different message
    /// for the reference-library scope vs a missing-book selection.
    private var scopeUnavailableHint: String {
        switch scope {
        case .referenceLibrary:
            return "资料库未找到 (= workspace 未 bootstrap)"
        case .book, .folder:
            return "未选书 — 在左侧书架里选一本书, 待办才会加载"
        }
    }

    /// Tooltip for the disabled/disabled-reason-aware add button.
    private var addButtonHelp: String {
        if scopeDir == nil {
            switch scope {
            case .referenceLibrary:
                return "资料库未 bootstrap"
            case .book, .folder:
                return "先在左侧书架里选一本书"
            }
        }
        if newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            return "请输入标题"
        }
        return "添加待办 → \(jsonHint)"
    }

    @ViewBuilder
    private var content: some View {
        if scopeDir == nil {
            Text(scopeUnavailableHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if items.isEmpty {
            Text("(暂无待办 — 在上面输入框新建第一条)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            // Section by status (Apple HIG inset-grouped style).
            // Pending first (= highest attention), then inProgress,
            // then completed + cancelled (= collapsible to the bottom
            // but kept visible per boss spec 'todo list shows per-book items').
            VStack(alignment: .leading, spacing: 12) {
                section(title: "待处理 (\(itemsByStatus(.pending).count))", status: .pending)
                section(title: "进行中 (\(itemsByStatus(.inProgress).count))", status: .inProgress)
                section(title: "已完成 (\(itemsByStatus(.completed).count))", status: .completed)
                section(title: "已取消 (\(itemsByStatus(.cancelled).count))", status: .cancelled)
            }
        }
    }

    private func section(title: String, status: TodoStatus) -> some View {
        let subset = itemsByStatus(status)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if subset.isEmpty {
                Text("(空)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(subset) { item in
                    TodoRow(
                        item: item,
                        onSetStatus: { newStatus in updateStatus(item: item, to: newStatus) },
                        onDelete: { deleteItem(item) }
                    )
                }
            }
        }
    }

    // MARK: - Derived

    private func itemsByStatus(_ status: TodoStatus) -> [PerBookTodoItem] {
        items
            .filter { $0.status == status }
            .sorted { (a, b) in
                // Compare rawValue explicitly: TodoPriority conforms to
                // RawRepresentable (= Int-backed) but isn't directly
                // Comparable, so Swift's type inference can't deduce
                // the comparison's Int return from the enum itself.
                if a.priority.rawValue != b.priority.rawValue {
                    return a.priority.rawValue > b.priority.rawValue
                }
                return a.createdAt < b.createdAt
            }
    }

    private var canAdd: Bool {
        scopeDir != nil && !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func label(for priority: TodoPriority) -> String {
        switch priority {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        }
    }

    // MARK: - Mutations

    /// B-09 + B-13: load items from the scope's todo JSON. The scope
    /// is resolved via `bookStore.scopeDirectory(...)`. See
    /// `KanbanView.reloadFromDisk` for the symmetric flow.
    private func reloadFromDisk() {
        let dir = bookStore.scopeDirectory(
            bookId: bookStore.selectedBookId,
            scope: scope
        )
        scopeDir = dir
        guard let dir = dir else {
            items = []
            loadError = nil
            return
        }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookTodoStore(bookId: bookId, directory: dir, scope: scope)
        do {
            items = try store.load()
            loadError = nil
        } catch {
            items = []
            loadError = "\(error)"
        }
    }

    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let dir = scopeDir else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookTodoStore(bookId: bookId, directory: dir, scope: scope)
        var next = items
        next.append(PerBookTodoItem(title: trimmed, status: .pending, priority: newItemPriority))
        do {
            try store.save(next)
            items = next
            newItemTitle = ""
            newItemPriority = .medium
        } catch {
            loadError = "保存失败: \(error)"
        }
    }

    private func updateStatus(item: PerBookTodoItem, to newStatus: TodoStatus) {
        guard let dir = scopeDir else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookTodoStore(bookId: bookId, directory: dir, scope: scope)
        var next = items
        guard let idx = next.firstIndex(of: item) else { return }
        next[idx].status = newStatus
        next[idx].updatedAt = .now
        do {
            try store.save(next)
            items = next
        } catch {
            loadError = "保存失败: \(error)"
        }
    }

    private func deleteItem(_ item: PerBookTodoItem) {
        guard let dir = scopeDir else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookTodoStore(bookId: bookId, directory: dir, scope: scope)
        let next = items.filter { $0.id != item.id }
        do {
            try store.save(next)
            items = next
        } catch {
            loadError = "保存失败: \(error)"
        }
    }
}

// MARK: - Row

/// Single todo row. Checkbox (= start / complete toggle), title,
/// priority chip (= B-13 visual distinction), due-date (= red if
/// overdue), delete button + context actions per status.
///
/// B-13 visual distinction (= boss Issue 1, "Kanban 和 Todo 看起来是
/// 一回事呢"):
///   - **Priority chip** is now a colored text-in-capsule badge with
///     the priority label (= "高" / "紧急" etc.) — not just a tiny
///     icon. This makes the priority visible at a glance, distinct
///     from Kanban's status badge (= Kanban doesn't track priority).
///   - **Due-date display** appears to the right of the title when
///     set: gray when future, **red when past today** (= visually
///     urgent signal). When nil, just "(无截止)" in `.secondary`.
private struct TodoRow: View {
    let item: PerBookTodoItem
    let onSetStatus: (TodoStatus) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            statusToggle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .strikethrough(item.status == .completed, color: .secondary)
                    .foregroundStyle(item.status == .cancelled ? .secondary : .primary)
                    .lineLimit(2)
                dueDateLabel
            }
            Spacer()
            priorityChip
            Menu {
                Button("开始") { onSetStatus(.inProgress) }
                    .disabled(item.status == .inProgress)
                Button("完成") { onSetStatus(.completed) }
                    .disabled(item.status == .completed)
                Button("取消") { onSetStatus(.cancelled) }
                    .disabled(item.status == .cancelled)
                Divider()
                Button("删除", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 2)
    }

    /// B-13: due-date display — shows the date in red when overdue
    /// (= past today), in `.secondary` when future, "(无截止)" when nil.
    @ViewBuilder
    private var dueDateLabel: some View {
        if let due = item.dueDate {
            let isOverdue = due < Calendar.current.startOfDay(for: .now)
                && item.status != .completed
                && item.status != .cancelled
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(Self.dueDateFormatter.string(from: due))
                    .font(.caption)
                    .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                if isOverdue {
                    Text("已过期")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .help(isOverdue ? "已过期 — 请尽快处理" : "截止日")
        } else {
            Text("(无截止)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Apple HIG checkbox toggle: tap pending → inProgress; tap
    /// inProgress → completed; tap completed → pending (= round-trip).
    @ViewBuilder
    private var statusToggle: some View {
        switch item.status {
        case .pending:
            Button(action: { onSetStatus(.inProgress) }) {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("开始")
        case .inProgress:
            Button(action: { onSetStatus(.completed) }) {
                Image(systemName: "circle.inset.filled")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
            .help("完成")
        case .completed:
            Button(action: { onSetStatus(.pending) }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.borderless)
            .help("重开")
        case .cancelled:
            Image(systemName: "xmark.circle")
                .foregroundStyle(.tertiary)
        }
    }

    /// B-13 visual distinction: priority chip with text label +
    /// color-coded background. Replaces the v0.22 icon-only badge
    /// (= `arrow.up` etc.) so the priority is readable at a glance.
    private var priorityChip: some View {
        let (text, fg, bg) = chipStyle(for: item.priority)
        return Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg, in: Capsule())
            .help("优先级: \(text)")
    }

    private func chipStyle(for priority: TodoPriority) -> (String, Color, Color) {
        switch priority {
        case .low: return ("低", Color.secondary, Color.secondary.opacity(0.15))
        case .medium: return ("中", Color.primary, Color.secondary.opacity(0.2))
        case .high: return ("高", Color.orange, Color.orange.opacity(0.18))
        case .urgent: return ("紧急", Color.red, Color.red.opacity(0.18))
        }
    }
}
