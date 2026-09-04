//
//  TodoListView.swift · Wenshu · v0.22 ticket h07 (hermes replica, frontend mount) + B-09
//
//  Per-book todo list. Reads + writes the per-book todo.json
//  (= BookTodoStore). Same data-source-switch pattern as KanbanView:
//  when bookStore.selectedBookId changes, reload from disk.
//
//  Layout (Boss B-09 acceptance):
//    - Top bar: 待办 title + "+ 新建" button.
//    - Input row: text field + priority picker + return-to-add
//      (Apple HIG inline-create).
//    - Body: per-status sectioned list (= pending / inProgress /
//      cancelled). Each row = checkbox + title + priority badge + delete
//      + "开始" / "完成" / "取消" context actions.
//    - Empty state when no book selected / no items.
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

/// Per-book todo list view. Mounted by `DynamicZoneView` in the
/// `aiDynamic` zone (= tab "待办"). Reads from `BookTodoStore`
/// (= per-book `todo.json`).
public struct TodoListView: View {
    @Environment(BookStore.self) private var bookStore

    @State private var items: [PerBookTodoItem] = []
    @State private var newItemTitle: String = ""
    @State private var newItemPriority: TodoPriority = .medium
    @State private var loadError: String? = nil
    @State private var bookDirectory: URL? = nil

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
        // B-09: re-load when the active book changes.
        .onAppear { reloadFromDisk() }
        .onChange(of: bookStore.selectedBookId) { _, _ in reloadFromDisk() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("待办")
                .font(.headline)
            Spacer()
            Text("\(items.count) 项 · per-book todo.json")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Inline-create row (Apple HIG text field + priority picker
    /// + return-to-submit). Disabled when no book is selected or
    /// the text is empty.
    /// B-12 fix: `.disabled(...)` is placed BEFORE `.buttonStyle(...)`
    /// so SwiftUI applies the disabled visual state (gray-out) to the
    /// button content, not to the styled wrapper; `.help(...)` exposes
    /// the reason on hover; an inline caption explains why the button
    /// is inactive when no book is selected (= Apple HIG disabled-control
    /// feedback).
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
                    Label("新建", systemImage: "plus")
                }
                .disabled(!canAdd)
                .buttonStyle(.borderedProminent)
                .help(addButtonHelp)
            }
            if bookDirectory == nil {
                Text("未选书 — 在左侧书架里选一本书, 待办才会加载")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("输入标题后才能新建")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Tooltip for the disabled/disabled-reason-aware add button.
    /// Empty when canAdd so hovering an enabled button shows no stale
    /// "please…" text.
    private var addButtonHelp: String {
        if bookDirectory == nil {
            return "先在左侧书架里选一本书"
        }
        if newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            return "请输入标题"
        }
        return "新建待办项"
    }

    @ViewBuilder
    private var content: some View {
        if bookDirectory == nil {
            Text("(未选书 — 在左侧书架里挑一本书, 待办才会加载)")
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
        bookDirectory != nil && !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty
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

    /// B-09: load items from `todo.json` for the active book.
    /// Empty list when no book is selected (= show empty state, not an
    /// error). Catches decode errors so a corrupted file doesn't crash
    /// the zone.
    private func reloadFromDisk() {
        guard let bookId = bookStore.selectedBookId else {
            items = []
            bookDirectory = nil
            loadError = nil
            return
        }
        guard let dir = bookStore.bookDirectory(bookId: bookId) else {
            items = []
            bookDirectory = nil
            loadError = "找不到书的目录 (id=\(bookId.uuidString.prefix(8)))"
            return
        }
        let store = BookTodoStore(bookId: bookId, bookDirectory: dir)
        do {
            items = try store.load()
            loadError = nil
        } catch {
            items = []
            loadError = "\(error)"
        }
        bookDirectory = dir
    }

    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let dir = bookDirectory else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookTodoStore(bookId: bookId, bookDirectory: dir)
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
        guard let dir = bookDirectory else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookTodoStore(bookId: bookId, bookDirectory: dir)
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
        guard let dir = bookDirectory else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookTodoStore(bookId: bookId, bookDirectory: dir)
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
/// priority badge, delete button + context actions per status.
private struct TodoRow: View {
    let item: PerBookTodoItem
    let onSetStatus: (TodoStatus) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            statusToggle
            Text(item.title)
                .font(.body)
                .strikethrough(item.status == .completed, color: .secondary)
                .foregroundStyle(item.status == .cancelled ? .secondary : .primary)
                .lineLimit(2)
            Spacer()
            priorityBadge
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

    @ViewBuilder
    private var priorityBadge: some View {
        let (icon, color) = badgeStyle(for: item.priority)
        Image(systemName: icon)
            .font(.caption2)
            .foregroundStyle(color)
            .help("优先级: \(label(for: item.priority))")
    }

    private func badgeStyle(for priority: TodoPriority) -> (String, Color) {
        switch priority {
        case .low: return ("arrow.down", .secondary)
        case .medium: return ("minus", .secondary)
        case .high: return ("arrow.up", .orange)
        case .urgent: return ("exclamationmark.2", .red)
        }
    }

    private func label(for priority: TodoPriority) -> String {
        switch priority {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        }
    }
}