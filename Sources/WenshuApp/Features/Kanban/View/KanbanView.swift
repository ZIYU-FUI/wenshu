//
//  KanbanView.swift
//  wenshu
//
//  The board of long-running work, in the trailing column.
//
//  The board reads the APP'S TASK STORE (= SwiftData, = the same store
//  the `kanban` tool writes when the agent schedules work), so the
//  board and the scheduler read one list. The board follows the
//  focused chat session (= one board per session, = the session names
//  its book), so it carries no picker of its own: the filter the user
//  means is the left column's directory tree.
//
//  Layout (= the Hermes board, rendered with Apple's own controls):
// - Header: board title + ticket count + the new-task button on the
//   trailing edge.
// - Body: one vertical stack of groups (= one per status). The stack
//   scrolls down; a group is as wide as the column it sits in and
//   keeps its own leading alignment. A group does not scroll on its
//   own, so the board reads as one surface.
// - Each group: a permanent header (= the status dot, the label, the
//   count) with the cards folding away under it. A group with no
//   cards shows its header and nothing else.
// - Each task card: title first, then the body preview. The card
//   carries a colored left edge in its group's status color.
//
//  The USER does not schedule: the status is the scheduler's, so the
//  card carries no status control and no way to move itself. The card
//  opens its read-only body sheet on a click anywhere on it, and its
//  context menu deletes it.
//
//  Apple HIG: small icon button + .bordered / .borderedProminent
//  button styles per macOS 26 Tahoe guidance. No sheet (per
//  ).
//

import SwiftUI
import WenshuData

/// The board of long-running work. Mounted by the trailing column's
/// task page (`InspectorTaskPageView`). Reads from the app's task
/// store (= SwiftData, = where the `kanban` tool writes).
struct KanbanView: View {
    /// The app's shared workspace state (= the selection that names
    /// the book the board shows). The board follows it, so the board
    /// and the rest of the app read one book.
    let workspaceUI: WorkspaceUIState

    /// The book the focused chat session is reading.
    ///
    /// The board follows the SESSION (= one board per session, = the
    /// session is per-book by construction, = so the book comes from
    /// the session and the board carries no picker of its own). The
    /// filter the user means is the left column's directory tree, and
    /// a second answer on the board (= a text field) would be two
    /// answers to one question.
    let focusedBookID: BookID?

    /// The board's tasks (= the focused book's tasks, = read from the
    /// app's task store on appear + whenever the focused session's
    /// book changes).
    @State private var tasks: [KanbanTask] = []
    @State private var newTaskTitle: String = ""
    @State private var loadError: String? = nil

    /// Whether the inline title field is showing. The new-task button
    /// reveals it; submitting it creates the task.
    @State private var isCreating: Bool = false

    /// kanban-detail-sheet 2026-09-28: nil means no sheet is open.
    /// The identity is the task itself (= sheet(items:) requires
    /// Identifiable input on macOS).
    @State private var sheetTask: KanbanTask?

    init(workspaceUI: WorkspaceUIState, focusedBookID: BookID?) {
        self.workspaceUI = workspaceUI
        self.focusedBookID = focusedBookID
    }

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
        // The board follows the focused session (= one board per
        // session), so a new session means a new board.
        .onAppear {
            reloadFromStore()
        }
        .onChange(of: focusedBookID) { _, _ in reloadFromStore() }
        // apple-001 HIG absent batch: .refreshable (= Apple
        // HIG pull-to-refresh standard). On macOS this becomes a
        // refresh button in the toolbar (= Cmd-R equivalent). The
        // reloadFromStore() action re-reads the board from the store.
        .refreshable { reloadFromStore() }
        // kanban-detail-sheet 2026-09-28: tapping a KanbanCard opens
        // this read-only body modal. Apple HIG canonical sheet (= no
        // custom chrome wrapper). .sheet(item:) gives us the task
        // identity (= sheet auto-dismisses when sheetTask = nil).
        .sheet(item: $sheetTask) { task in
            KanbanTicketDetailSheet(
                task: task,
                onDismiss: { sheetTask = nil }
            )
        }
    }

    /// kanban-detail-sheet 2026-09-28: callback from KanbanCard.onOpen.
    /// Stashes the task into sheetTask; = the .sheet(item:) binding
    /// observes the change and animates the modal in.
    private func onOpenSheet(_ task: KanbanTask) {
        sheetTask = task
    }

    // MARK: - Subviews

    /// Header: board title + task count + the new-task button on
    /// the trailing edge.
    ///
    /// The board carries NO picker and NO filter field: the board
    /// follows the focused session (= one board per session), and the
    /// filter the user means is the left column's directory tree.
    ///
    /// The count is the NUMBER of tasks on the board. A label that
    /// reads "task count" belongs next to a number, not in its place.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingStandard) {
            Text(String(localized: "auto.kanbanview.l100.h57246144"))
                .font(.headline)
            Text(String(tasks.count))
                .font(.caption)
                .foregroundStyle(DesignTokens.statusForeground)
            Spacer(minLength: DesignTokens.spacingStandard)
            newTaskButton
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

    /// Inline-create row (Apple HIG text field + return-to-submit).
    /// Disabled when the text is empty.
    ///
    /// A new task starts in the FIRST status (= the scheduler's queue,
    /// = the user does not pick a status = the user does not schedule).
    private var inputRow: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            TextField(String(localized: "auto2.kanbanview.l142.h68849992"), text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addTask() }
            Button(action: addTask) {
                Label { Text(String(localized: "auto2.kanbanview.l146.h37112406")) } icon: { SFIcon("plus", style: .inlineSmall, color: IconColor.tint) }
            }
            .disabled(!canAdd)
            .buttonStyle(.borderedProminent)
            .help(addButtonHelp)
        }
    }

    /// Tooltip for the add button. Empty when the button is enabled, so
    /// hovering an enabled button shows no stale "please…" text.
    private var addButtonHelp: String {
        if newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            return String(localized: "auto.kanbanview.l157.h65127890")
        }
        return String(localized: "kanban.new_task.writes")
    }

    @ViewBuilder
    private var content: some View {
        if tasks.isEmpty {
            EmptyStateView(
                icon: "rectangle.split.3x1",
                title: String(localized: "kanban.empty.title"),
                body: String(localized: "kanban.empty.body")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // One vertical stack. The groups fill the column's width
            // and the stack scrolls down (= the board reads as one
            // surface, not eight independent scrollers).
            ScrollView(.vertical, showsIndicators: false) {
                // One glass container for the board's glass surfaces (= 
                // the system's own grouping for glass). The spacing
                // EQUALS the card spacing (= a larger container spacing
                // makes neighbouring glass blend at rest, = and the
                // cards would melt into one sheet while the board sits
                // still).
                GlassEffectContainer(spacing: DesignTokens.spacingTight) {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
                    ForEach(KanbanStatus.boardOrder, id: \.self) { status in
                        KanbanGroup(
                            status: status,
                            tasks: visibleTasks(in: status),
                            onDelete: { task in
                                deleteTask(task)
                            },
                            // kanban-detail-sheet 2026-09-28:
                            // open request bubbles up to KanbanView
                            // (= the View owns the sheetTask state).
                            onOpen: { task in onOpenSheet(task) }
                        )
                    }
                    }
                    .padding(.vertical, DesignTokens.spacingIconic)
                }
            }
        }
    }

    // MARK: - Derived

    /// The cards a group shows.
    private func visibleTasks(in status: KanbanStatus) -> [KanbanTask] {
        tasks.filter { $0.status == status }
    }

    private var canAdd: Bool {
        !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Mutations

    /// The store the board reads and writes.
    ///
    /// The board is a view, so it reads the app's task store directly
    /// (= the store the `kanban` tool writes, = one list for the board
    /// and the scheduler).
    private var store: WSKanbanRepository {
        WSKanbanRepository()
    }

    /// Re-read the board from the task store.
    private func reloadFromStore() {
        do {
            tasks = try store.list(bookID: focusedBookID?.rawValue).map { model in
                KanbanTask(
                    id: model.id,
                    title: model.title,
                    status: KanbanStatus(rawValue: model.status) ?? .new,
                    createdAt: model.createdAt,
                    updatedAt: model.updatedAt,
                    priority: model.priority,
                    assignee: model.assignee,
                    startedAt: model.startedAt,
                    completedAt: model.completedAt,
                    modelOverride: model.modelOverride,
                    body: model.body
                )
            }
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }

    /// Add a task to this book's board.
    ///
    /// The task starts in the FIRST status (= the scheduler's queue).
    /// The user does not pick a status (= the user does not schedule),
    /// so the task waits for the scheduler to move it.
    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        do {
            _ = try store.add(
                title: title,
                status: KanbanStatus.boardOrder.first?.rawValue ?? "new",
                bookID: focusedBookID?.rawValue
            )
            newTaskTitle = ""
            isCreating = false
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
        reloadFromStore()
    }

    /// Remove a task from the board.
    private func deleteTask(_ task: KanbanTask) {
        do {
            try store.delete(id: task.id)
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
        reloadFromStore()
    }
}

// MARK: - Group

/// One group of the board (= a single KanbanStatus). Renders the
/// group header + a vertical list of task cards. Pure layout;
/// mutations bubble up via closures (KanbanView owns the truth).
///
/// The header is a permanent row: the group stays on the board whether
/// or not it holds cards, and the cards under it fold away on demand.
/// A group with no cards shows its header and nothing else (= the
/// header already carries the count, = so an empty group reads as
/// "nothing here" without a placeholder line).
private struct KanbanGroup: View {
    let status: KanbanStatus
    let tasks: [KanbanTask]
    let onDelete: (KanbanTask) -> Void
    // kanban-detail-sheet 2026-09-28: group forwards the open
    // request upward (KanbanView owns the sheet state).
    let onOpen: (KanbanTask) -> Void

    /// Whether the group's cards are showing.
    @State private var isExpanded = true

    var body: some View {
        // The fold (= SwiftUI's DisclosureGroup, = the accordion the
        // chat's reasoning panel and its plan panel use for their
        // steps). The group's name and its count ARE the label (= the
        // system draws the disclosure triangle beside the label, = so
        // the group reads as one accordion row, = not as a bare row
        // with a stray triangle beside it).
        //
        // A group with no cards shows its header and nothing else, so
        // an empty group takes no room.
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(tasks) { task in
                    KanbanCard(
                        task: task,
                        onDelete: { onDelete(task) },
                        // kanban-detail-sheet 2026-09-28:
                        // tapping a card surfaces the body sheet.
                        onOpen: { onOpen(task) }
                    )
                }
            }
            .padding(.top, DesignTokens.spacingTight)
        } label: {
            HStack(spacing: DesignTokens.spacingIconic) {
                Circle()
                    .fill(status.boardTone)
                    .frame(
                        width: DesignTokens.kanbanColumnDotSize,
                        height: DesignTokens.kanbanColumnDotSize
                    )
                Text(status.boardLabel)
                    .font(.subheadline.weight(.semibold))
                Text(String(tasks.count))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
        }
        .padding(DesignTokens.spacingStandard)
        // The group is as wide as the column it sits in (= the
        // trailing column decides the width; = a fixed width would
        // overflow a narrower trailing column).
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Card

/// Single kanban task card. Title first, then the body preview. The
/// card carries a colored left edge in its group's status color, so a
/// card reads as belonging to its group at a glance.
///
/// The card answers the mouse two ways (= the board's own interaction
/// language):
/// - the WHOLE card opens the read-only body sheet (= tapping the
///   card's empty space opens it too, = the card is one target, = not
///   just its text);
/// - the card's CONTEXT MENU deletes it (= the trash button that used
///   to sit in the corner is gone, = the menu is where a destructive
///   action belongs).
///
/// The card carries NO status control (= the user does not schedule:
/// the status is the scheduler's).
private struct KanbanCard: View {
    let task: KanbanTask
    let onDelete: () -> Void
    let onOpen: () -> Void

    var body: some View {
        // The shared card (= the same card the column's other two pages
        // wear). The card carries no status symbol (= the user does not
        // schedule, = the card's group says the state, = and the group
        // wears the colour on the card's edge), = but the marker column
        // still holds its width (= so the board's cards and the plan's
        // cards and the sub-agent's cards all start their words at the
        // same place).
        InspectorCard(
            marker: AnyView(EmptyView()),
            hasStatusEdge: true,
            statusEdgeColor: task.status.boardTone
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                // The title comes FIRST: it is what the user scans the
                // board for. The body is the preview under it.
                Text(task.title)
                    .font(.body.weight(.medium))
                    .lineLimit(3)
                    .textSelection(.enabled)
                // Per iron-rule I-4 (= wenshu-comment-policy): task.body renders
                // when present, going through the same inline-markdown parser
                // chat uses (= ChatTextPartView.parseMarkdown). Mirrors
                // hermes 0.21.5 commit 63f5bc0999: the kanban drawer
                // reuses MessageTextContent. wenshu's reuse keeps ONE
                // markdown pipeline across the app — no per-surface parser.
                if let body = task.body, !body.isEmpty {
                    Text(ChatTextPartView.parseMarkdown(body))
                        .font(.callout)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
        // The whole card is one tap target (= its padding, its
        // background, and the empty space beside the body preview all
        // belong to the tap, = not just the text).
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
        // The delete lives in the context menu (= the trash button that
        // used to sit in the corner is gone).
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label(
                    String(localized: "kanban.card.delete"),
                    systemImage: "trash"
                )
            }
        }
        .hoverWash()
    }
}
