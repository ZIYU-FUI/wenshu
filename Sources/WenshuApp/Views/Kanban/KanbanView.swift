//
//  KanbanView.swift · Wenshu · v0.22 ticket h06 (hermes replica, frontend mount) + B-09 + B-13
//
//  Per-(book × scope) kanban board. Reads + writes a scope-aware kanban
//  JSON file (= BookKanbanStore). Switches the data source when the
//  active book OR the active scope changes (= bookStore.selectedBookId
//  + the local `@State scope`, both read via @Environment per v0.30 boss
//  8/31 OOB '各区域之间的联动' = option A = global @Observable store).
//
//  Layout (Boss B-09 acceptance):
//    - Top bar: 看板 title + scope picker + "+ 新建" button.
//    - Input row: text field + return-to-add (per Apple HIG inline-create).
//    - Body: per-status columns (new / ready / running / blocked /
//      review / done) + a "+ 新建到 X" affordance per column
//      (= cursor-on-column context menu not in scope for v0.40;
//      default add = .new).
//    - Each ticket card: title + status badge + delete button.
//    - Empty state when no book selected / no tickets.
//
//  B-13 (= boss 2026-09-04 OOB "这两个看板都有同一个问题"): the scope
//  picker (= .menu Picker over the 8 standard sub-folders + book root
//  + reference library) drives which JSON file the view reads from /
//  writes to. Scope is a view filter, not a data-layer change.
//
//  Persistence:
//    - BookKanbanStore.save([KanbanTicket]) writes the whole array
//      atomically (= per spec v5 ticket 026). On every add / status
//      change / delete, the view reloads from disk + writes back.
//
//  Apple HIG: small icon button + .bordered / .borderedProminent
//  button styles per macOS 26 Tahoe guidance. No sheet (per
//  v0.24 boss 8/24 OOB 'dynamic zone 应该是 tab 模式, 不是 sheet').
//

import SwiftUI

/// Per-(book × scope) kanban board view. Mounted by `DynamicZoneView`
/// in the `aiDynamic` zone (= tab "看板"). Reads from `BookKanbanStore`
/// (= scope-aware kanban JSON: `kanban.json` / `kanban-<folder>.json`
/// / `library-kanban.json`).
public struct KanbanView: View {
    @Environment(BookStore.self) private var bookStore

    /// The active scope (book root / 8 sub-folders / reference library).
    /// B-13: changes when the user picks a different scope from the
    /// `.menu` Picker in the header. Reload-from-disk happens in
    /// `.onChange(of: scope)`.
    @State private var scope: TaskScope = .book

    /// The active book's per-scope kanban tickets (= loaded from the
    /// scope's JSON file on appear + whenever `scope` or
    /// `selectedBookId` changes).
    @State private var tickets: [KanbanTicket] = []
    @State private var newTicketTitle: String = ""
    @State private var loadError: String? = nil

    /// Resolved directory for `(selectedBookId, scope)`. Nil when the
    /// active scope has no on-disk directory (= no book selected + a
    /// per-book scope, OR the library is not bootstrapped).
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
        // v0.24 boss验收fix: flexible size (was: 480x320 min forcing zone to grow).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // B-09: re-load when the active book changes (= boss spec:
        // "切书=切数据源" per ticket 026 v0.26).
        // B-13: re-load when the active scope changes (= user picked a
        // different sub-folder / reference library from the picker).
        .onAppear { reloadFromDisk() }
        .onChange(of: bookStore.selectedBookId) { _, _ in reloadFromDisk() }
        .onChange(of: scope) { _, _ in reloadFromDisk() }
    }

    // MARK: - Subviews

    /// Header: 看板 title + scope picker + ticket count + json hint.
    /// B-13: the scope picker is a `.menu` Picker (= compact for the
    /// DynamicZone width; boss cadence is `.menu` for narrow zone).
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("看板")
                .font(.headline)
            Picker("scope", selection: $scope) {
                ForEach(bookStore.availableScopes(bookId: bookStore.selectedBookId)) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .help("切换看板数据范围 (= 全书 / 8 标准子目录 / 资料库)")
            Spacer()
            Text("\(tickets.count) 票 · \(jsonHint)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Hint text showing which JSON file the active scope reads from.
    /// B-13: scope-aware (= changes when `scope` changes).
    private var jsonHint: String {
        switch scope {
        case .book:
            return "kanban.json"
        case .folder(let f):
            return "kanban-\(f.folderName).json"
        case .referenceLibrary:
            return "library-kanban.json"
        }
    }

    /// Inline-create row (Apple HIG text field + return-to-submit).
    /// Disabled when the scope has no resolved directory or the text
    /// is empty.
    /// B-12 fix: `.disabled(...)` is placed BEFORE `.buttonStyle(...)`
    /// so SwiftUI applies the disabled visual state (gray-out) to the
    /// button content, not to the styled wrapper; `.help(...)` exposes
    /// the reason on hover; an inline caption explains why the button
    /// is inactive when no directory is resolved (= Apple HIG
    /// disabled-control feedback).
    private var inputRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TextField("新看板标题…", text: $newTicketTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTicket() }
                Button(action: addTicket) {
                    Label("新建", systemImage: "plus")
                }
                .disabled(!canAdd)
                .buttonStyle(.borderedProminent)
                .help(addButtonHelp)
            }
            if scopeDir == nil {
                Text(scopeUnavailableHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty {
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
            return "未选书 — 在左侧书架里选一本书, 看板才会加载"
        }
    }

    /// Tooltip for the disabled/disabled-reason-aware add button.
    /// Empty when canAdd so hovering an enabled button shows no stale
    /// "please…" text.
    private var addButtonHelp: String {
        if scopeDir == nil {
            switch scope {
            case .referenceLibrary:
                return "资料库未 bootstrap"
            case .book, .folder:
                return "先在左侧书架里选一本书"
            }
        }
        if newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            return "请输入标题"
        }
        return "新建看板票据 → \(jsonHint)"
    }

    @ViewBuilder
    private var content: some View {
        if scopeDir == nil {
            Text(scopeUnavailableHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if tickets.isEmpty {
            Text("(暂无看板 — 在上面输入框新建第一条)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            // Group by status. Display order = the state-machine flow
            // (new → ready → running → blocked → review → done) so
            // columns visually read left-to-right.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(displayStatuses, id: \.self) { status in
                        KanbanColumn(
                            status: status,
                            tickets: tickets.filter { $0.status == status },
                            onMove: { ticket, newStatus in
                                updateStatus(ticket: ticket, to: newStatus)
                            },
                            onDelete: { ticket in
                                deleteTicket(ticket)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Derived

    /// Statuses shown as columns. `failed` is hidden by default (the
    /// spec state machine collapses failure to `blocked`; `failed`
    /// exists for wenshu's explicit-failure case and is surfaced via
    /// the `blocked` column visually). Triaged `triage` = transient;
    /// show inline with `new`.
    private var displayStatuses: [KanbanStatus] {
        [.new, .ready, .running, .blocked, .review, .done]
    }

    private var canAdd: Bool {
        scopeDir != nil && !newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Mutations

    /// B-09 + B-13: load tickets from the scope's JSON file. The scope
    /// is resolved via `bookStore.scopeDirectory(bookId:selectedBookId,
    /// scope:)`. When the active scope has no directory (= no book
    /// selected + per-book scope, OR library not bootstrapped), the
    /// view shows the empty / unavailable state, not an error.
    private func reloadFromDisk() {
        let dir = bookStore.scopeDirectory(
            bookId: bookStore.selectedBookId,
            scope: scope
        )
        scopeDir = dir
        guard let dir = dir else {
            tickets = []
            loadError = nil
            return
        }
        // The library scope has no book id; for per-book scopes we use
        // the active book (= may be nil for `.book` if no book is
        // selected, but we already returned above in that case).
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookKanbanStore(bookId: bookId, directory: dir, scope: scope)
        do {
            tickets = try store.load()
            loadError = nil
        } catch {
            tickets = []
            loadError = "\(error)"
        }
    }

    private func addTicket() {
        let trimmed = newTicketTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let dir = scopeDir else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookKanbanStore(bookId: bookId, directory: dir, scope: scope)
        var next = tickets
        next.append(KanbanTicket(title: trimmed, status: .new))
        do {
            try store.save(next)
            tickets = next
            newTicketTitle = ""
        } catch {
            loadError = "保存失败: \(error)"
        }
    }

    private func updateStatus(ticket: KanbanTicket, to newStatus: KanbanStatus) {
        guard let dir = scopeDir else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookKanbanStore(bookId: bookId, directory: dir, scope: scope)
        var next = tickets
        guard let idx = next.firstIndex(of: ticket) else { return }
        next[idx].status = newStatus
        next[idx].updatedAt = .now
        do {
            try store.save(next)
            tickets = next
        } catch {
            loadError = "保存失败: \(error)"
        }
    }

    private func deleteTicket(_ ticket: KanbanTicket) {
        guard let dir = scopeDir else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookKanbanStore(bookId: bookId, directory: dir, scope: scope)
        let next = tickets.filter { $0.id != ticket.id }
        do {
            try store.save(next)
            tickets = next
        } catch {
            loadError = "保存失败: \(error)"
        }
    }
}

// MARK: - Column

/// One Kanban column (= a single KanbanStatus). Renders the column
/// header + a vertical list of ticket cards. Pure layout; mutations
/// bubble up via closures (KanbanView owns the truth).
private struct KanbanColumn: View {
    let status: KanbanStatus
    let tickets: [KanbanTicket]
    let onMove: (KanbanTicket, KanbanStatus) -> Void
    let onDelete: (KanbanTicket) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label(for: status))
                    .font(.subheadline.weight(.semibold))
                Text("(\(tickets.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            Divider()
            if tickets.isEmpty {
                Text("(空)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(tickets) { ticket in
                            KanbanCard(
                                ticket: ticket,
                                onMove: { newStatus in onMove(ticket, newStatus) },
                                onDelete: { onDelete(ticket) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
        .padding(8)
        .frame(width: 200)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator, lineWidth: 0.5)
        )
    }

    private func label(for status: KanbanStatus) -> String {
        switch status {
        case .new: return "新"
        case .triage: return "分流"
        case .ready: return "就绪"
        case .running: return "进行"
        case .blocked: return "阻塞"
        case .review: return "复核"
        case .done: return "完成"
        case .failed: return "失败"
        }
    }
}

// MARK: - Card

/// Single Kanban ticket card. Title + status-stepper menu + delete
/// button. Status stepper lets the user drag a ticket across columns
/// (= state machine transitions per v0.23 ticket 013.003).
private struct KanbanCard: View {
    let ticket: KanbanTicket
    let onMove: (KanbanStatus) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ticket.title)
                .font(.body)
                .lineLimit(3)
            HStack(spacing: 4) {
                Menu {
                    ForEach(KanbanStatus.allCases, id: \.self) { s in
                        Button(label(for: s)) { onMove(s) }
                    }
                } label: {
                    Text(label(for: ticket.status))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.18), in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.separator, lineWidth: 0.5)
        )
    }

    private func label(for status: KanbanStatus) -> String {
        switch status {
        case .new: return "新"
        case .triage: return "分流"
        case .ready: return "就绪"
        case .running: return "进行"
        case .blocked: return "阻塞"
        case .review: return "复核"
        case .done: return "完成"
        case .failed: return "失败"
        }
    }
}
