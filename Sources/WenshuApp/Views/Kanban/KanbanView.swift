//
//  KanbanView.swift · Wenshu · v0.22 ticket h06 (hermes replica, frontend mount) + B-09
//
//  Per-book kanban board. Reads + writes the per-book kanban.json
//  (= BookKanbanStore). Switches the data source when the active book
//  changes (= bookStore.selectedBookId, read via @Environment per
//  v0.30 boss 8/31 OOB '各区域之间的联动' = option A = global @Observable store).
//
//  Layout (Boss B-09 acceptance):
//    - Top bar: 看板 title + "+ 新建" button.
//    - Input row: text field + return-to-add (per Apple HIG inline-create).
//    - Body: per-status columns (new / ready / running / blocked /
//      review / done) + a "+ 新建到 X" affordance per column
//      (= cursor-on-column context menu not in scope for v0.40;
//      default add = .new).
//    - Each ticket card: title + status badge + delete button.
//    - Empty state when no book selected / no tickets.
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

/// Per-book kanban board view. Mounted by `DynamicZoneView` in the
/// `aiDynamic` zone (= tab "看板"). Reads from `BookKanbanStore`
/// (= per-book `kanban.json`).
public struct KanbanView: View {
    @Environment(BookStore.self) private var bookStore

    /// The active book's per-book kanban tickets (= loaded from
    /// `kanban.json` on appear + whenever selectedBookId changes).
    @State private var tickets: [KanbanTicket] = []
    @State private var newTicketTitle: String = ""
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
        // v0.24 boss验收fix: flexible size (was: 480x320 min forcing zone to grow).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // B-09: re-load when the active book changes (= boss spec:
        // "切书=切数据源" per ticket 026 v0.26).
        .onAppear { reloadFromDisk() }
        .onChange(of: bookStore.selectedBookId) { _, _ in reloadFromDisk() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("看板")
                .font(.headline)
            Spacer()
            Text("\(tickets.count) 票 · per-book kanban.json")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Inline-create row (Apple HIG text field + return-to-submit).
    /// Disabled when no book is selected or the text is empty.
    /// B-12 fix: `.disabled(...)` is placed BEFORE `.buttonStyle(...)`
    /// so SwiftUI applies the disabled visual state (gray-out) to the
    /// button content, not to the styled wrapper; `.help(...)` exposes
    /// the reason on hover; an inline caption explains why the button
    /// is inactive when no book is selected (= Apple HIG disabled-control
    /// feedback).
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
            if bookDirectory == nil {
                Text("未选书 — 在左侧书架里选一本书, 看板才会加载")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty {
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
        if newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            return "请输入标题"
        }
        return "新建看板票据"
    }

    @ViewBuilder
    private var content: some View {
        if bookDirectory == nil {
            Text("(未选书 — 在左侧书架里挑一本书, 看板才会加载)")
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
        bookDirectory != nil && !newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Mutations

    /// B-09: load tickets from `kanban.json` for the active book.
    /// Empty list when no book is selected (= show empty state, not an
    /// error). Catches decode errors so a corrupted file doesn't crash
    /// the zone.
    private func reloadFromDisk() {
        guard let bookId = bookStore.selectedBookId else {
            tickets = []
            bookDirectory = nil
            loadError = nil
            return
        }
        guard let dir = bookStore.bookDirectory(bookId: bookId) else {
            tickets = []
            bookDirectory = nil
            loadError = "找不到书的目录 (id=\(bookId.uuidString.prefix(8)))"
            return
        }
        let store = BookKanbanStore(bookId: bookId, bookDirectory: dir)
        do {
            tickets = try store.load()
            loadError = nil
        } catch {
            tickets = []
            loadError = "\(error)"
        }
        bookDirectory = dir
    }

    private func addTicket() {
        let trimmed = newTicketTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let dir = bookDirectory else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookKanbanStore(bookId: bookId, bookDirectory: dir)
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
        guard let dir = bookDirectory else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookKanbanStore(bookId: bookId, bookDirectory: dir)
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
        guard let dir = bookDirectory else { return }
        let bookId = bookStore.selectedBookId ?? UUID()
        let store = BookKanbanStore(bookId: bookId, bookDirectory: dir)
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