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
//   carries no colour of its own (= the group above it wears the
//   status colour on its own label).
//
//  The USER does not schedule: the status is the scheduler's, so the
//  card carries no status control and no way to move itself. The card
//  opens its read-only body sheet on a click anywhere on it, and its
//  context menu deletes it.
//
//  product: small icon button + .bordered / .borderedProminent
//  button styles per the macOS 26 (Tahoe) release. No sheet (per
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

    /// The board's cards (= the focused book's tasks, = read from the
    /// app's task store on appear + whenever the focused session's
    /// book changes).
    ///
    /// The cards are bucketed by status HERE (= at the load), = so a
    /// body pass does not re-filter the whole board, = and each card
    /// carries its body ALREADY PARSED (= the markdown is parsed once
    /// per task, = at the load, = not once per card per body pass).
    @State private var cardsByStatus: [KanbanStatus: [KanbanCardContent]] = [:]
    @State private var loadError: String? = nil

    /// Whether the board's read is still running.
    ///
    /// = = The read crosses an await (= = the store read and the
    /// = = markdown parse), = = so the board's cards land a frame or
    /// = = more after the request. = = While it runs the board draws
    /// = = the project's one loading placeholder = = so the column
    /// = = says "the work is arriving" and not "this session has no
    /// = = work".
    @State private var isLoading = false

    /// The board's read counter (= a reference, = so the read can move
    /// = = it without a View struct needing a mutating self).
    @State private var loadCounter = KanbanLoadCounter()

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
            Task { await reloadFromStore() }
        }
        .onChange(of: focusedBookID) { _, _ in
            Task { await reloadFromStore() }
        }
        // apple-001 HIG absent batch: .refreshable (iOS
        // pull-to-refresh; = the macOS HIG publishes no such standard).
        // On macOS this becomes a
        // refresh button in the toolbar (= Cmd-R equivalent). The
        // reloadFromStore() action re-reads the board from the store.
        .refreshable { await reloadFromStore() }
        // kanban-detail-sheet 2026-09-28: tapping a KanbanCard opens
        // this read-only body modal. the product sheet (= no
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

    @ViewBuilder
    private var content: some View {
        if isLoading {
            // The board's read is still running (= the store read and
            // the markdown parse). The rows the board will hold are
            // reserved (= the project's one loading placeholder), so the
            // column reads as WORKING while they arrive = = and the column
            // says "the work is arriving" and not "this session has no
            // work".
            LoadingPlaceholder(.groups(count: KanbanStatus.boardOrder.count))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(DesignTokens.spacingStandard)
        } else if cardCount == 0 {
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
                // One vertical stack of the board's groups (= the
                // groups fill the column's width and the stack scrolls
                // down = = the board reads as one surface, = not eight
                // independent scrollers).
                VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
                    ForEach(KanbanStatus.boardOrder, id: \.self) { status in
                        KanbanGroup(
                            status: status,
                            cards: cardsByStatus[status] ?? [],
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

    // MARK: - Derived

    /// How many cards the board holds (= every group's cards).
    private var cardCount: Int {
        cardsByStatus.values.reduce(0) { $0 + $1.count }
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
    ///
    /// The read is where the board's per-task work happens (= ONCE per
    /// task, = not once per body pass): the body's markdown is parsed
    /// here, = so a body pass draws the parsed text and parses nothing.
    ///
    /// ⇒ ⇒ ⇒ THE READ IS ASYNC AND THE BOARD SAYS SO WHILE IT RUNS:
    /// = = the read crosses an await (= = the store read and the
    /// = = markdown parse are both off the frame that started the
    /// = = read), = = so the board's cards land a frame or more after
    /// = = the request. = = A board that drew its cards only at the
    /// = = end would show an EMPTY board for those frames = = and an
    /// = = empty board says "this session has no work" = = which is a
    /// = = different claim from "this session's work is still
    /// = = arriving". = = So the board holds a loading state and
    /// = = draws the project's one loading placeholder in it.
    ///
    /// ⇒ ⇒ ⇒ AND THE MARKDOWN IS PARSED OFF THE MAIN ACTOR: = = the
    /// = = parse is pure text work (= `parseMarkdown` is nonisolated
    /// = = and the task that carries it is Sendable), = = so it runs
    /// = = on a background task = = and the main thread is free for
    /// = = the frame that drew the tab switch.
    private func reloadFromStore() async {
        isLoading = true
        // ⇒ ⇒ ⇒ AND THE BOOK IS READ NOW, NOT AFTER THE YIELD: = = the
        // board can be asked for two books in a row (= = the user
        // switched books while the first read was still running),
        // and a read that read the book AFTER its yield would
        // answer for the WRONG book.
        let bookID = focusedBookID?.rawValue
        let generation = loadCounter.next()
        // The read yields first (= the house's own discipline in
        // `loadShelfBooksAsync` and in `LibraryDocumentStore`), = so
        // the board can finish rendering the frame it is on before the
        // work starts.
        await Task.yield()
        do {
            let tasks = try store.list(bookID: bookID).map { model in
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
            // The cards are bucketed by status at the load (= a body
            // pass reads the buckets, = and does not re-filter the
            // whole board).
            //
            // The body's markdown is parsed HERE (= once per task, = at
            // the load), = so a body pass draws the parsed text and
            // parses nothing.
            //
            // ⇒ ⇒ ⇒ AND THE PARSE RUNS OFF THE MAIN ACTOR: = = the
            // body text is a plain string and the parser is
            // nonisolated, = = so the parse needs no actor to
            // hand the text over. = = The library-level board holds
            // hundreds of cards (= = the probe
            // `Tools/wenshu-devtool/probes/card_surfaces_load_cost.swift`
            // counts them on the user's own library, = = and it prices
            // the parse of the ones carrying a body), = = and that parse
            // spends milliseconds = = and that is not the main thread's
            // job while the user is switching tabs.
            let buckets = await Self.parseBodies(tasks)
            // ⇒ ⇒ ⇒ AND A STALE READ IS DROPPED: = = the parse is the
            // long part of the read, = = so the board can be asked for
            // another book while it runs. = = ⇒ ⇒ ⇒ The read that
            // started first must not answer for the book that came
            // second (= = or the board would draw book A's cards under
            // book B's name).
            guard loadCounter.isCurrent(generation) else { return }
            cardsByStatus = buckets
            loadError = nil
            isLoading = false
        } catch {
            guard loadCounter.isCurrent(generation) else { return }
            loadError = String(describing: error)
            isLoading = false
        }
    }

    /// Parse every task's markdown OFF the main actor and bucket the
    /// cards by status.
    ///
    /// = = The parse is pure text work (= `parseMarkdown` is
    /// = = nonisolated and the task that carries it is Sendable), = =
    /// = = so it runs on a background task = = and the main thread
    /// = = stays free for the frames that draw the board.
    ///
    /// = = ⇒ ⇒ ⇒ AND WHY A DETACHED TASK IS THE RIGHT DOOR HERE: = =
    /// AGENTS.md 4.5's rule is about background WRITES (= = "never a
    /// detached task on the context" = = the SwiftData context). = = This
    /// parse writes NOTHING (= = it reads plain strings and returns
    /// plain values), = = so the context's rule does not reach it. = = And
    /// the house's own background READ uses this exact shape (= =
    /// `CoverIndex.prefill` walks the covers in a detached task).
    ///
    /// = = The markdown goes through the same inline-markdown parser
    /// = = chat uses (= `ChatTextPartView.parseMarkdown`), = = so
    /// = = wenshu keeps ONE markdown pipeline across the app (= no
    /// = = per-surface parser).
    @Sendable
    private static func parseBodies(
        _ tasks: [KanbanTask]
    ) async -> [KanbanStatus: [KanbanCardContent]] {
        let parsed = await Task.detached(priority: .userInitiated) {
            tasks.map { task in
                let parsedBody: AttributedString?
                if let body = task.body, !body.isEmpty {
                    parsedBody = ChatTextPartView.parseMarkdown(body)
                } else {
                    parsedBody = nil
                }
                return KanbanCardContent(task: task, parsedBody: parsedBody)
            }
        }.value
        var buckets: [KanbanStatus: [KanbanCardContent]] = [:]
        for card in parsed {
            buckets[card.task.status, default: []].append(card)
        }
        return buckets
    }


    /// Remove a task from the board.
    private func deleteTask(_ task: KanbanTask) {
        do {
            try store.delete(id: task.id)
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
        Task { await reloadFromStore() }
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
    /// The group's cards (= already parsed, = so the group draws text
    /// and parses nothing).
    let cards: [KanbanCardContent]
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
            // A LAZY stack (= Apple's own container for a long list in
            // a scroll view), = so a body pass builds the cards that
            // are on screen and not every card in the group.
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(cards) { card in
                    KanbanCard(
                        card: card,
                        onDelete: { onDelete(card.task) },
                        // kanban-detail-sheet 2026-09-28:
                        // tapping a card surfaces the body sheet.
                        onOpen: { onOpen(card.task) }
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
                Text(String(cards.count))
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
/// card carries no status colour of its own (= the group it sits in
/// wears the colour on its own label, = = so a card reads as belonging
/// to its group from the group above it).
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
    /// The card's content (= its task and its already-parsed body).
    let card: KanbanCardContent
    let onDelete: () -> Void
    let onOpen: () -> Void

    var body: some View {
        // The shared card (= the same card the column's other two pages
        // wear). The card carries no status symbol (= the user does not
        // schedule, = the card's group says the state, = and the group
        // wears the colour on its own label), = but the marker column
        // still holds its width (= so the board's cards and the plan's
        // cards and the sub-agent's cards all start their words at the
        // same place).
        InspectorCard(
            marker: AnyView(EmptyView()),
            // ⇒ THE CARD IS THE CONTROL: = = the whole card answers
            // the click (= = its padding, = = its background, = = and
            // the empty space beside the body preview all belong to
            // the tap, = = not just the text), = = and the whole card
            // answers the hover, = = and the pointer says "this opens"
            // over the whole card.
            onOpen: { onOpen() }
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                // The title comes FIRST: it is what the user scans the
                // board for. The body is the preview under it.
                Text(card.task.title)
                    .font(.body.weight(.medium))
                    .lineLimit(3)
                // The body's markdown arrives PARSED (= the board's
                // load parsed it, = = so the card draws text and parses
                // nothing). The rendered text is the shared parser's
                // output (= unchanged).
                //
                // ⇒ AND THE CARD'S WORDS ARE NOT SELECTABLE: = = a
                // selectable text answers the pointer with a TEXT
                // CURSOR, = = and a text cursor over a card says "this
                // is a document", = = not "this opens something". = =
                // The whole card's words are still selectable where
                // they belong (= = in the sheet the card opens).
                if let parsedBody = card.parsedBody {
                    Text(parsedBody)
                        .font(.callout)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .lineLimit(3)
                }
            }
        }
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
        // ⇒ The card wears NO hover wash of its own: = = the shared
        // card draws it (= = in the card's own shape, = = and over the
        // card's material, = = which is the only place the wash can be
        // seen at all). = = ⇒ The board's card and the column's other
        // two pages' cards answer the pointer the SAME way.
    }
}

/// Which read of the board is the current one.
///
/// ⇒ ⇒ ⇒ AND IT IS A COUNTER, NOT THE BOOK: = = the board can be asked
/// for two books in a row (= = the user switched books while the first
/// read was still running), = = and the first read can land SECOND. = =
/// ⇒ ⇒ ⇒ So every read takes the next number, = = and only the newest
/// number may write (= = or the board would draw book A's cards under
/// book B's name).
///
/// ⇒ ⇒ ⇒ AND IT IS A REFERENCE: = = the board is a View STRUCT, = = and
/// a struct's own counter would need a mutating self = = = which an
/// async read cannot have.
@MainActor
final class KanbanLoadCounter {
    /// The newest read that started.
    private(set) var generation = 0

    /// The next generation (= the one the caller owns).
    func next() -> Int {
        generation += 1
        return generation
    }

    /// Whether the given generation is still the current one.
    func isCurrent(_ generation: Int) -> Bool {
        self.generation == generation
    }
}
