//
//  KanbanView.swift · Wenshu · v0.22 ticket h06 (hermes replica, frontend mount) + B-09 + B-13
//
//  Per-(book × scope) kanban board. Reads + writes a scope-aware kanban
//  JSON file (= BookKanbanStore). Switches the data source when the
//  active book OR the active scope changes (= bookStore.selectedBookId
//  + the local `@State scope`, both read via @Environment per v0.30 boss
// 8/31 OOB 'region' = option A = global @Observable store).
//
//  Layout (Boss B-09 acceptance):
// - Top bar: kanban title + scope picker + "+ " button.
//    - Input row: text field + return-to-add (per Apple HIG inline-create).
//    - Body: per-status columns (new / ready / running / blocked /
// review / done) + a "+ X" affordance per column
//      (= cursor-on-column context menu not in scope for v0.40;
//      default add = .new).
//    - Each ticket card: title + status badge + delete button.
//    - Empty state when no book selected / no tickets.
//
// (= boss 2026-09-04 OOB "kanbanissue"): the scope
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
// ).
//

import SwiftUI

/// Per-(book × scope) kanban board view. Mounted by `DynamicZoneView`
/// in the `aiDynamic` zone (= tab "kanban"). Reads from `BookKanbanStore`
/// (= scope-aware kanban JSON: `kanban.json` / `kanban-<folder>.json`
/// / `library-kanban.json`).
struct KanbanView: View {
    @Environment(BookStore.self) private var bookStore

    /// The active scope (book root / 8 sub-folders / reference library).
    /// changes when the user picks a different scope from the
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

    /// kanban-detail-sheet 2026-09-28: nil means no sheet is open.
    /// The identity is the ticket itself (= sheet(items:) requires
    /// Identifiable input on macOS; KanbanTicket is already Identifiable).
    @State private var sheetTicket: KanbanTicket?

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            inputRow
            if let _ = loadError {
                Text(WenshuI18n.t("auto.kanbanview.l69.h78022707"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            content
        }
        .padding(DesignTokens.spacingStandard)
        // bossverificationfix: flexible size (was: 480x320 min forcing zone to grow).
        // "=" per ticket 026 v0.26).
        // re-load when the active scope changes (= user picked a
        // different sub-folder / reference library from the picker).
        .onAppear { reloadFromDisk() }
        .onChange(of: bookStore.selectedBookId) { _, _ in reloadFromDisk() }
        .onChange(of: scope) { _, _ in reloadFromDisk() }
        // apple-001 HIG absent batch: .refreshable (= Apple
        // HIG pull-to-refresh standard). On macOS this becomes a
        // refresh button in the toolbar (= Cmd-R equivalent). The
        // reloadFromDisk() action re-reads the kanban.json from disk,
        // = useful when the user edits the JSON file externally.
        .refreshable { reloadFromDisk() }
        // kanban-detail-sheet 2026-09-28: tapping a KanbanCard opens
        // this read-only body modal. Apple HIG canonical sheet (= no
        // custom chrome wrapper). .sheet(item:) gives us the ticket
        // identity (= sheet auto-dismisses when sheetTicket = nil).
        .sheet(item: $sheetTicket) { ticket in
            KanbanTicketDetailSheet(
                ticket: ticket,
                onDismiss: { sheetTicket = nil }
            )
        }
    }

    /// kanban-detail-sheet 2026-09-28: callback from KanbanCard.onOpen.
    /// Stashes the ticket into sheetTicket; = the .sheet(item:) binding
    /// observes the change and animates the modal in.
    private func onOpenSheet(_ ticket: KanbanTicket) {
        sheetTicket = ticket
    }

    // MARK: - Subviews

    /// Header: kanban title + scope picker + ticket count + json hint.
    /// the scope picker is a `.menu` Picker (= compact for the
    /// DynamicZone width; boss cadence is `.menu` for narrow zone).
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(WenshuI18n.t("auto.kanbanview.l100.h57246144"))
                .font(.headline)
            Picker("scope", selection: $scope) {
                ForEach(bookStore.availableScopes(bookId: bookStore.selectedBookId)) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .help(WenshuI18n.t("auto2.kanbanview.l109.h72695635"))
            Spacer()
            Text(WenshuI18n.t("auto.kanbanview.l111.h22166662"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Hint text showing which JSON file the active scope reads from.
    /// scope-aware (= changes when `scope` changes).
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
    /// fix: `.disabled(...)` is placed BEFORE `.buttonStyle(...)`
    /// so SwiftUI applies the disabled visual state (gray-out) to the
    /// button content, not to the styled wrapper; `.help(...)` exposes
    /// the reason on hover; an inline caption explains why the button
    /// is inactive when no directory is resolved (= Apple HIG
    /// disabled-control feedback).
    private var inputRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: DesignTokens.spacingTight) {
                TextField(WenshuI18n.t("auto2.kanbanview.l142.h68849992"), text: $newTicketTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTicket() }
                Button(action: addTicket) {
                    Label { Text(WenshuI18n.t("auto2.kanbanview.l146.h37112406")) } icon: { SFIcon("plus", style: .inlineSmall, color: IconColor.tint) }
                }
                .disabled(!canAdd)
                .buttonStyle(.borderedProminent)
                .help(addButtonHelp)
            }
            if scopeDir == nil {
                Text(scopeUnavailableHint)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            } else if newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(WenshuI18n.t("auto.kanbanview.l157.h65127890"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
        }
    }

    /// explain why the add row is inactive. Different message
    /// for the reference-library scope vs a missing-book selection.
    private var scopeUnavailableHint: String {
        switch scope {
        case .referenceLibrary:
            return WenshuI18n.t("error.reference_library_not_bootstrapped")
        case .book, .folder:
            return WenshuI18n.t("kanban.unselected_book")
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
                .foregroundStyle(DesignTokens.statusForeground)
        } else if tickets.isEmpty {
            Text(WenshuI18n.t("kanban.empty_state"))
                .font(.caption)
                .foregroundStyle(DesignTokens.statusForeground)
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
                            },
                            // kanban-detail-sheet 2026-09-28:
                            // open request bubbles up to KanbanView
                            // (= the View owns the sheetTicket state).
                            onOpen: { ticket in onOpenSheet(ticket) }
                        )
                    }
                }
                .padding(.vertical, DesignTokens.spacingIconic)
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

    /// lift the disk-IO + state-transition logic into
    /// `KanbanOps` (= the stateless business layer at
    /// `Sources/WenshuApp/Views/Kanban/KanbanOps.swift`). Per
    /// ADR-0009 (= UI/业务/数据 separation), the View is now a pure
    /// consumer: it holds the @State (tickets / newTicketTitle /
    /// scopeDir / loadError), reads via @Environment for the
    /// BookStore, and delegates every mutation to KanbanOps.
    private func reloadFromDisk() {
        let resolver = BookStoreScopeDirectoryResolver(bookStore: bookStore)
        let result = KanbanOps.loadTickets(
            bookId: bookStore.selectedBookId,
            scope: scope,
            resolver: resolver
        )
        tickets = result.tickets
        scopeDir = result.scopeDir
        loadError = result.loadError
    }

    private func addTicket() {
        let resolver = BookStoreScopeDirectoryResolver(bookStore: bookStore)
        let result = KanbanOps.addTicket(
            bookId: bookStore.selectedBookId,
            scope: scope,
            resolver: resolver,
            title: newTicketTitle,
            to: tickets
        )
        tickets = result.savedTickets
        if result.didSave {
            // SwiftUI-side reset (= inline-create TextField clears on
            // successful save; = a binding reset, NOT a business rule,
            // = stays in the view per ADR-0009).
            newTicketTitle = ""
        }
        if let err = result.error { loadError = err }
    }

    private func updateStatus(ticket: KanbanTicket, to newStatus: KanbanStatus) {
        let resolver = BookStoreScopeDirectoryResolver(bookStore: bookStore)
        let result = KanbanOps.updateStatus(
            bookId: bookStore.selectedBookId,
            scope: scope,
            resolver: resolver,
            ticket: ticket,
            to: newStatus,
            in: tickets
        )
        tickets = result.savedTickets
        if let err = result.error { loadError = err }
    }

    private func deleteTicket(_ ticket: KanbanTicket) {
        let resolver = BookStoreScopeDirectoryResolver(bookStore: bookStore)
        let result = KanbanOps.deleteTicket(
            bookId: bookStore.selectedBookId,
            scope: scope,
            resolver: resolver,
            ticket: ticket,
            in: tickets
        )
        tickets = result.savedTickets
        if let err = result.error { loadError = err }
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
    // kanban-detail-sheet 2026-09-28: column forwards the open
    // request upward (KanbanView owns the sheet state).
    let onOpen: (KanbanTicket) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: DesignTokens.spacingIconic) {
                Text(label(for: status))
                    .font(.subheadline.weight(.semibold))
                Text(WenshuI18n.t("b5.kanbanview.l336.h21576137"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.spacingIconic)
            Divider()
            if tickets.isEmpty {
                Text(WenshuI18n.t("auto.kanbanview.l343.h97636928"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .padding(.horizontal, DesignTokens.spacingIconic)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        ForEach(tickets) { ticket in
                            KanbanCard(
                                ticket: ticket,
                                onMove: { newStatus in onMove(ticket, newStatus) },
                                onDelete: { onDelete(ticket) },
                                // kanban-detail-sheet 2026-09-28:
                                // tapping a card surfaces the body sheet.
                                onOpen: { onOpen(ticket) }
                            )
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.kanbanBoardMaxHeight)
            }
        }
        .padding(DesignTokens.spacingStandard)
        .frame(width: DesignTokens.sidebarNarrowWidth)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard)
                .stroke(.separator, lineWidth: DesignTokens.separatorThicknessHairline)
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
///
/// kanban-detail-sheet 2026-09-28: tap target added on the card body
/// (= Menu area excluded so the status-stepper still works). Clicking
/// the card opens the read-only body sheet (= Phase 2 of the kanban-
/// markdown arc; = mirrors hermes 0.21.5 drawer opening on card click).
private struct KanbanCard: View {
    let ticket: KanbanTicket
    let onMove: (KanbanStatus) -> Void
    let onDelete: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Phase 1 T5/T8 (2026-09-28): render ticket.body when
            // present, going through the same inline-markdown parser
            // chat uses (= ChatTextPartView.parseMarkdown). Mirrors
            // hermes 0.21.5 commit 63f5bc0999: the kanban drawer
            // reuses MessageTextContent. wenshu's reuse keeps ONE
            // markdown pipeline across the app — no per-surface parser.
            if let body = ticket.body, !body.isEmpty {
                Text(ChatTextPartView.parseMarkdown(body))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .textSelection(.enabled)
            }
            Text(ticket.title)
                .font(.body)
                .lineLimit(3)
                .textSelection(.enabled)
            HStack(spacing: DesignTokens.spacingIconic) {
                Menu {
                    ForEach(KanbanStatus.allCases, id: \.self) { s in
                        Button(label(for: s)) { onMove(s) }
                    }
                } label: {
                    Text(label(for: ticket.status))
                        .font(.caption)
                        .padding(.horizontal, DesignTokens.spacingTight)
                        .padding(.vertical, DesignTokens.spacingCaption)
                        .background(.tint.opacity(0.18), in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Button(action: onDelete) {
                    SFIcon("trash", style: .inlineSmall, color: IconColor.tint)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.spacingStandard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                        .stroke(.separator, lineWidth: DesignTokens.separatorThicknessHairline)
                )
                // kanban-detail-sheet 2026-09-28: tap on the card body opens
                // the read-only body sheet. The trailing control row (status
                // stepper + delete) keeps its own gestures; = contentShape
                // limits the tap target to the card surface (= excluding the
                // Menu label / Button hit areas so the existing per-control
                // handlers still win).
                .contentShape(Rectangle())
                .onTapGesture { onOpen() }
                .hoverWash()
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
