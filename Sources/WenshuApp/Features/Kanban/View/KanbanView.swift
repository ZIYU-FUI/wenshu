//
//  KanbanView.swift
//
//  Per-(book × scope) kanban board. Reads + writes a scope-aware kanban
//  JSON file (= BookKanbanStore). Switches the data source when the
//  active book OR the active scope changes (= bookStore.selectedBookId
//  + the local `@State scope`, both read via @Environment per v0.30 spec
//  8/31 OOB 'region' = option A = global @Observable store).
//
//  Layout (= the Hermes board, rendered with Apple's own controls):
// - Header row: board title + ticket count + book picker + scope picker
//   + a search field + the new-task button on the trailing edge.
// - Body: one horizontal strip of columns (= one per status). The strip
//   scrolls sideways; the columns fill the window height. A column does
//   not scroll on its own, so the board reads as one surface.
// - Each ticket card: title first, then the body preview, then the
//   status control. The card carries a colored left edge in its
//   column's status color.
//
//  (= (see OOB.md #2026-09-04) OOB "kanbanissue"): the scope
//  picker (= .menu Picker over the 6 standard sub-folders + book root
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
//  ).
//

import SwiftUI

/// Per-(book × scope) kanban board view. Mounted by `KanbanWindow`
/// in the `aiDynamic` zone (= tab "kanban"). Reads from `BookKanbanStore`
/// (= scope-aware kanban JSON: `kanban.json` / `kanban-<folder>.json`
/// / `library-kanban.json`).
struct KanbanView: View {
    @Environment(BookStore.self) private var bookStore

    /// The active scope (book root / 6 sub-folders / reference library).
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

    /// The header's filter text. It narrows what the board SHOWS and
    /// never changes what is on disk.
    @State private var searchText: String = ""

    /// Whether the inline title field is showing. The new-task button
    /// reveals it; submitting it creates the card.
    @State private var isCreating: Bool = false

    /// kanban-detail-sheet 2026-09-28: nil means no sheet is open.
    /// The identity is the ticket itself (= sheet(items:) requires
    /// Identifiable input on macOS; KanbanTicket is already Identifiable).
    @State private var sheetTicket: KanbanTicket?

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            header
            if isCreating {
                inputRow
            }
            if loadError != nil {
                Text(String(localized: "auto.kanbanview.l69.h78022707"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            content
        }
        .padding(DesignTokens.spacingStandard)
        // wenshu-verification-fix: flexible size (was: 480x320 min forcing zone to grow).
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

    /// Header: board title + ticket count + book picker + scope picker
    /// + search field + the new-task button.
    ///
    /// The count is the NUMBER of tickets on the board. A label that
    /// reads "ticket count" belongs next to a number, not in its place.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingStandard) {
            Text(String(localized: "auto.kanbanview.l100.h57246144"))
                .font(.headline)
            Text(String(tickets.count))
                .font(.caption)
                .foregroundStyle(DesignTokens.statusForeground)
            bookPicker
            scopePicker
            searchField
            Spacer(minLength: DesignTokens.spacingStandard)
            newTaskButton
        }
    }

    /// The books the board can show. The board needs one, because the
    /// ticket file lives inside the book's folder.
    @ViewBuilder
    private var bookPicker: some View {
        if !bookStore.books.isEmpty {
            Picker(String(localized: "kanban.book.picker"), selection: bookSelectionBinding) {
                ForEach(bookStore.books) { book in
                    Text(book.title).tag(Optional(book.id))
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .help(String(localized: "kanban.book.picker.help"))
        }
    }

    /// The board's book selection, bound to the store (= the window
    /// seeds the store from the main window's sidebar selection, so
    /// the two agree until the user picks a different book here).
    private var bookSelectionBinding: Binding<UUID?> {
        Binding(
            get: { bookStore.selectedBookId },
            set: { bookStore.selectedBookId = $0 }
        )
    }

    /// The scope picker. It is a `.menu` Picker (= compact for the
    /// DynamicZone width; the cadence is `.menu` for narrow zone).
    private var scopePicker: some View {
        Picker("scope", selection: $scope) {
            ForEach(bookStore.availableScopes(bookId: bookStore.selectedBookId)) { s in
                Text(s.displayName).tag(s)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .help(String(localized: "auto2.kanbanview.l109.h72695635"))
    }

    /// The board's filter field. It narrows the VISIBLE cards only.
    private var searchField: some View {
        HStack(spacing: DesignTokens.spacingIconic) {
            SFIcon("magnifyingglass", style: .inlineSmall, color: IconColor.secondary)
            TextField(String(localized: "kanban.search.placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .frame(minWidth: DesignTokens.kanbanSearchFieldWidth)
        }
    }

    /// The new-task button. It reveals the inline title field.
    private var newTaskButton: some View {
        Button {
            isCreating.toggle()
        } label: {
            Label {
                Text(String(localized: "kanban.new_task"))
            } icon: {
                SFIcon("plus", style: .inlineSmall, color: IconColor.tint)
            }
        }
        .buttonStyle(.borderedProminent)
        .help(String(localized: "kanban.new_task.help"))
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
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            HStack(spacing: DesignTokens.spacingTight) {
                TextField(String(localized: "auto2.kanbanview.l142.h68849992"), text: $newTicketTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTicket() }
                Button(action: addTicket) {
                    Label { Text(String(localized: "auto2.kanbanview.l146.h37112406")) } icon: { SFIcon("plus", style: .inlineSmall, color: IconColor.tint) }
                }
                .disabled(!canAdd)
                .buttonStyle(.borderedProminent)
                .help(addButtonHelp)
            }
            if !canAdd, scopeDir != nil {
                Text(String(localized: "auto.kanbanview.l157.h65127890"))
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
            return String(localized: "error.reference_library_not_bootstrapped")
        case .book, .folder:
            return String(localized: "kanban.unselected_book")
        }
    }

    /// Tooltip for the disabled/disabled-reason-aware add button.
    /// Empty when canAdd so hovering an enabled button shows no stale
    /// "please…" text.
    private var addButtonHelp: String {
        if scopeDir == nil {
            switch scope {
            case .referenceLibrary:
                return String(localized: "error.reference_library_not_bootstrapped")
            case .book, .folder:
                return String(localized: "kanban.unselected_book")
            }
        }
        if newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            return String(localized: "auto.kanbanview.l157.h65127890")
        }
        return String(localized: "kanban.new_task.writes") + " " + jsonHint
    }

    @ViewBuilder
    private var content: some View {
        if scopeDir == nil {
            // ONE explanation, not two. The board cannot resolve a
            // directory, so it says why and stops.
            EmptyStateView(
                icon: "rectangle.split.3x1",
                title: String(localized: "kanban.no_book.title"),
                body: scopeUnavailableHint
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tickets.isEmpty {
            EmptyStateView(
                icon: "rectangle.split.3x1",
                title: String(localized: "kanban.empty.title"),
                body: String(localized: "kanban.empty.body")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // One horizontal strip. The columns fill the window height
            // and the strip scrolls sideways (= the board reads as one
            // surface, not eight independent scrollers).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DesignTokens.spacingModerate) {
                    ForEach(KanbanStatus.boardOrder, id: \.self) { status in
                        KanbanColumn(
                            status: status,
                            tickets: visibleTickets(in: status),
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

    /// The cards a column shows, after the header's filter.
    private func visibleTickets(in status: KanbanStatus) -> [KanbanTicket] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tickets.filter { ticket in
            guard ticket.status == status else { return false }
            guard !query.isEmpty else { return true }
            let haystack = "\(ticket.title) \(ticket.body ?? "")".lowercased()
            return haystack.contains(query)
        }
    }

    private var canAdd: Bool {
        scopeDir != nil && !newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Mutations

    /// lift the disk-IO + state-transition logic into
    /// `KanbanOps` (= the stateless business layer at
    /// `Sources/WenshuApp/Views/Kanban/KanbanOps.swift`). Per
    /// ADR-0009 (= UI// separation), the View is now a pure
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
            isCreating = false
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
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            HStack(spacing: DesignTokens.spacingIconic) {
                Circle()
                    .fill(status.boardTone)
                    .frame(
                        width: DesignTokens.kanbanColumnDotSize,
                        height: DesignTokens.kanbanColumnDotSize
                    )
                Text(status.boardLabel)
                    .font(.subheadline.weight(.semibold))
                Text(String(tickets.count))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            .padding(.horizontal, DesignTokens.spacingIconic)
            if tickets.isEmpty {
                Text(String(localized: "auto.kanbanview.l343.h97636928"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .padding(.horizontal, DesignTokens.spacingIconic)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
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
        }
        .padding(DesignTokens.spacingStandard)
        .frame(width: DesignTokens.kanbanColumnWidth)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard)
                .stroke(.separator, lineWidth: DesignTokens.separatorThicknessHairline)
        )
    }
}

// MARK: - Card

/// Single Kanban ticket card. Title first, then the body preview, then
/// the status control + delete button. The card carries a colored left
/// edge in its column's status color, so a card reads as belonging to
/// its column at a glance.
///
/// kanban-detail-sheet (= the v2.9 arc of kanban-markdown work): tap
/// target added on the card body (= Menu area excluded so the
/// status-stepper still works). Clicking the card opens the
/// read-only body sheet (= mirrors hermes 0.21.5 drawer opening on
/// card click).
private struct KanbanCard: View {
    let ticket: KanbanTicket
    let onMove: (KanbanStatus) -> Void
    let onDelete: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            // The title comes FIRST: it is what the user scans the
            // board for. The body is the preview under it.
            Text(ticket.title)
                .font(.body.weight(.medium))
                .lineLimit(3)
                .textSelection(.enabled)
            // Per iron-rule I-4 (= wenshu-comment-policy): ticket.body renders
            // when present, going through the same inline-markdown parser
            // chat uses (= ChatTextPartView.parseMarkdown). Mirrors
            // hermes 0.21.5 commit 63f5bc0999: the kanban drawer
            // reuses MessageTextContent. wenshu's reuse keeps ONE
            // markdown pipeline across the app — no per-surface parser.
            if let body = ticket.body, !body.isEmpty {
                Text(ChatTextPartView.parseMarkdown(body))
                    .font(.callout)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            HStack(spacing: DesignTokens.spacingIconic) {
                Menu {
                    ForEach(KanbanStatus.boardOrder, id: \.self) { s in
                        Button(s.boardLabel) { onMove(s) }
                    }
                } label: {
                    Text(ticket.status.boardLabel)
                        .font(.caption)
                        .padding(.horizontal, DesignTokens.spacingTight)
                        .padding(.vertical, DesignTokens.spacingCaption)
                        .background(
                            ticket.status.boardTone.opacity(DesignTokens.accentTintOpacityHero),
                            in: Capsule()
                        )
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
        .overlay(alignment: .leading) {
            // The status edge (= the Hermes board's colored left border).
            Rectangle()
                .fill(ticket.status.boardTone)
                .frame(width: DesignTokens.kanbanCardStatusEdgeWidth)
        }
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
}
