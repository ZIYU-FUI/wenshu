//
//  InspectorTodoPageView.swift
//  wenshu
//
//  The todo page of the trailing inspector column.
//
//  The page shows the plan the ASSISTANT wrote: the rows come from the
//  agent's own plan store, the assistant writes them, and the user
//  cannot edit them (= the page is read-only, because the assistant's
//  next turn owns that list).
//
//  The rows are cards, because the column is narrow: a card carries the
//  item's state marker, the item's own words, and the item's place in
//  the plan (= an item that belongs to another item reads indented
//  under it).
//
//  The plan store is the one the agent's todo tool writes, so the plan
//  on screen and the plan the assistant works from are the same list.
//
//

import Combine
import SwiftUI

/// The trailing inspector column's todo page.
///
/// Shows the plan the assistant wrote (= the agent's plan store), the
/// outstanding items first, with a card per item.
struct InspectorTodoPageView: View {
    /// The page's own mirror of the plan store (= the store stays the
    /// source of truth; = the view holds a snapshot and re-reads it).
    @State private var model = InspectorTodoModel()

    var body: some View {
        VStack(spacing: 0) {
            loadFailureLine
            content
        }
        .task { model.refresh() }
        // The plan store announces its own writes (= the assistant
        // writes the plan while the user watches this page), so the page
        // reads once per write instead of asking again on a clock. The
        // subscription names THIS page's store: the announcement is a
        // process-wide broadcast, and a write to some other
        // `HermesTodoStore` has nothing here to draw.
        //
        // The announcement is hopped where it is SUBSCRIBED, not where
        // it is drawn (= `hoppedToMain` is the one line that keeps
        // `refresh()` off the writing thread, and a hop the test can
        // drive is a hop that can be proven load-bearing).
        .onReceive(InspectorTodoModel.hoppedToMain(NotificationCenter.default.publisher(
            for: .wenshuTodoPlanDidChange, object: model.planSource
        ))) { _ in
            model.refresh()
        }
    }

    /// The page's body (= the list, or the empty state).
    @ViewBuilder
    private var content: some View {
        if !model.isLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.todos.isEmpty {
            emptyState
        } else {
            todoList
        }
    }

    /// The read-failure line (= the store could not be read; = the
    /// cards below are the last good read, so the line says the list
    /// may be stale).
    @ViewBuilder
    private var loadFailureLine: some View {
        if model.loadFailed {
            Text(String(localized: "inspector.todo.load.failed"))
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, DesignTokens.spacingStandard)
                .padding(.bottom, DesignTokens.spacingTight)
        }
    }

    /// The empty state (= the assistant has no plan).
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            EmptyStateView(
                icon: InspectorPage.todo.icon,
                title: String(localized: "inspector.todo.empty.title"),
                body: String(localized: "inspector.todo.empty.body")
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    /// The plan's cards (= one per item).
    ///
    /// The cards are always visible (= a fold here hid the plan behind
    /// one more click, = and the plan is the column's reason to be
    /// open).
    private var todoList: some View {
        ScrollView {
            // One glass container for the page's glass surfaces (= the
            // system's own grouping for glass, = so the cards blend
            // into one another the way the system's grouped surfaces
            // do). The spacing EQUALS the card spacing (= a larger
            // container spacing makes neighbouring glass blend at
            // rest, = and the cards would melt into one sheet while
            // the column sits still).
            GlassEffectContainer(spacing: DesignTokens.spacingTight) {
                // A LAZY stack (= Apple's own container for a long
                // list in a scroll view), = so a body pass builds the
                // cards that are on screen and not every card in the
                // plan.
                LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                    ForEach(model.todos) { todo in
                        InspectorTodoCard(todo: todo)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingStandard)
                .padding(.bottom, DesignTokens.spacingStandard)
            }
        }
    }
}

// MARK: - Card

/// One plan item as the page draws it (= a card).
///
/// The state rides on a symbol beside the item's own words, so the
/// words stay the primary content of the card.
private struct InspectorTodoCard: View {
    let todo: InspectorTodo

    var body: some View {
        // The shared card (= the same card the column's other two pages
        // wear). Every plan item is one card in one column (= the plan
        // is a list of steps, = and a step that belongs to another step
        // reads as its own step here, = the plan's own words carry the
        // step, = not an indent in the card).
        InspectorCard(
            marker: AnyView(stateMarker),
            hasStatusEdge: true,
            statusEdgeColor: AnyShapeStyle(InspectorTodoStateStyle.tone(for: todo.status).style)
        ) {
            Text(todo.title)
                .font(.body.weight(.medium))
                .foregroundStyle(InspectorTodoStateStyle.foreground(for: todo.status))
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    /// The state marker (= the plan's four states).
    ///
    /// An item waiting its turn wears a TRAY (= it sits in the queue
    /// with the other items, = a hollow ring would read as a checkbox
    /// the reader can tick, = and the reader cannot tick it). The item
    /// being worked on wears a spinner, a resolved item a checkmark, and
    /// a dropped one a slashed ring.
    @ViewBuilder
    private var stateMarker: some View {
        switch todo.status {
        case HermesTodoStatus.pending:
            SFIcon(
                "shippingbox",
                style: .inlineSmall,
                color: InspectorTodoStateStyle.tone(for: todo.status)
            )
            .symbolRenderingMode(.hierarchical)
        case HermesTodoStatus.inProgress:
            // The item being worked on wears the system's own rotating
            // symbol (= an SF Symbol with Apple's rotate effect, = the
            // system draws both the symbol and the motion).
            //
            // It is a SYMBOL, not a ProgressView (= a ProgressView
            // draws its own spinner at its own size and centres it in
            // the space it is offered, = so the spinner sat in the
            // middle of the column while the symbols sat at its edge,
            // and the spinner read smaller than every other marker).
            // One symbol set means one size means one column.
            SFIcon(
                "arrow.triangle.2.circlepath",
                style: .inlineSmall,
                color: InspectorTodoStateStyle.tone(for: todo.status)
            )
            .symbolEffect(.rotate, options: .repeating)
        case HermesTodoStatus.completed:
            SFIcon("checkmark.circle.fill", style: .inlineSmall, color: InspectorTodoStateStyle.tone(for: todo.status))
        case HermesTodoStatus.cancelled:
            SFIcon("circle.slash", style: .inlineSmall, color: InspectorTodoStateStyle.tone(for: todo.status))
        }
    }
}

// MARK: - Mirror

/// The todo page's mirror of the plan store.
///
/// The store stays the source of truth; this holds the snapshot the
/// view draws from and re-reads it.
@MainActor
@Observable
final class InspectorTodoModel {
    /// The plan items the page shows (= a snapshot of the store's rows).
    private(set) var todos: [InspectorTodo] = []

    /// Whether the first read has landed (= the page shows a spinner
    /// until it has).
    private(set) var isLoaded = false

    /// Whether the last read failed (= the page says so, = the cards
    /// are the last good read).
    private(set) var loadFailed = false

    /// The store the page reads.
    private let readPlan: () throws -> [HermesTodoItem]

    /// The store whose writes this page is told about.
    ///
    /// The page listens to ONE store (= the sender half of the plan
    /// announcement) instead of to every plan write in the process: the
    /// app builds a second `HermesTodoStore` (= `TodoStoreTool.shared`),
    /// and a wake caused by that one would draw this page from a plan
    /// that has not changed.
    let planSource: HermesTodoStore

    init(
        readPlan: @escaping () throws -> [HermesTodoItem] = { HermesTodoTool.shared.readPlan() },
        planSource: HermesTodoStore = HermesTodoTool.shared.planSender
    ) {
        self.readPlan = readPlan
        self.planSource = planSource
    }

    /// Delivers a store's announcement on the main actor.
    ///
    /// The store posts on the thread that WROTE (= its own contract,
    /// `HermesTodoTool.swift:220-223`: "a mirror that draws from it hops
    /// to the main actor itself"), and that thread is not the main
    /// actor's: the assistant's plan write reaches the store through
    /// `ToolExecutor`, a plain actor. `NotificationCenter` calls its
    /// observers on the posting thread, and SwiftUI hands an
    /// `onReceive` action straight to that call, so an unhopped
    /// subscription runs `refresh()` — main-actor state — on a
    /// background thread, which Swift 6 traps (`dispatch_assert_queue`).
    ///
    /// The hop sits on the subscription rather than inside the draw
    /// because removing it is then a compile-clean edit: the app's other
    /// mirrors wrap the draw in `Task { @MainActor in … }`
    /// (`Features/Editor/View/AssetsPane.swift:435-437`), a shape whose
    /// hop cannot be taken away without the file stopping build, = so
    /// nothing can show it is load-bearing.
    nonisolated static func hoppedToMain(
        _ announcements: NotificationCenter.Publisher
    ) -> AnyPublisher<Notification, Never> {
        announcements
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// One read of the store: the cards come from that one read, so
    /// they can never disagree with each other.
    func refresh() {
        let items: [HermesTodoItem]
        do {
            items = try readPlan()
        } catch {
            // A failed read keeps the last good snapshot, so the list
            // never empties because the store could not be read.
            loadFailed = true
            isLoaded = true
            return
        }
        loadFailed = false

        // The plan's order is the agent's order (= the item being worked
        // on comes first, = the store hands it over that way), so the
        // cards keep it.
        let snapshot = items.map {
            InspectorTodo(id: $0.id, title: $0.content, status: $0.status, parent: $0.parent)
        }
        let depths = InspectorTodoDepths.resolve(snapshot)

        var cards: [InspectorTodo] = []
        cards.reserveCapacity(snapshot.count)
        for item in snapshot {
            cards.append(
                InspectorTodo(
                    id: item.id,
                    title: item.title,
                    status: item.status,
                    parent: item.parent,
                    depth: depths[item.id] ?? 0
                )
            )
        }
        todos = cards

        isLoaded = true
    }
}

// MARK: - Depth

/// Where each plan item sits in the plan's tree.
///
/// The item's parent names the item it belongs to, so the depth is the
/// number of steps from the top. An item whose parent is missing (= the
/// parent was never written, or was dropped) reads as a top-level step,
/// and so does an item that is its own parent (= the plan would
/// otherwise never reach a root).
enum InspectorTodoDepths {
    /// The depth of every item, keyed by its id.
    static func resolve(_ todos: [InspectorTodo]) -> [String: Int] {
        let byId = Dictionary(todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var depths: [String: Int] = [:]
        for todo in todos {
            let depth = depth(of: todo, byId: byId, seen: [])
            // A chain with no root (= a cycle) reads as the top level.
            depths[todo.id] = depth < 0 ? 0 : depth
        }
        return depths
    }

    /// The depth of one item (= how many steps it is from the top).
    ///
    /// An item sits one step below its parent, and a parent that has no
    /// parent sits at the top. A chain that never reaches the top (= two
    /// items naming each other) is a cycle, and a cycle degrades to the
    /// top level (= the same rule the reference implementation uses, =
    /// a plan with a cycle still shows every item).
    private static func depth(of todo: InspectorTodo, byId: [String: InspectorTodo], seen: [String]) -> Int {
        // The chain came back to an item it already visited (= a cycle,
        // = the chain has no root).
        guard !seen.contains(todo.id) else { return -1 }
        guard let parentID = todo.parent, parentID != todo.id else { return 0 }
        guard let parent = byId[parentID] else { return 0 }
        // The parent's own depth
        let parentDepth = depth(of: parent, byId: byId, seen: seen + [todo.id])
        guard parentDepth >= 0 else { return -1 }
        return parentDepth + 1
    }
}

// MARK: - Item

/// One plan item as the page draws it (= a snapshot of one stored row).
struct InspectorTodo: Identifiable, Equatable, Sendable {
    let id: String
    /// The item's own words (= the agent wrote them).
    let title: String
    /// The item's state (= the plan's own vocabulary).
    let status: HermesTodoStatus
    /// The item this one belongs to (= a sub-step's parent).
    let parent: String?
    /// How deep the item sits in the plan (= 0 = a top-level step).
    ///
    /// The depth is the plan's own shape (= the store names each
    /// item's parent, = and the depth says how many steps from the
    /// top). The card does NOT indent by it (= every card in the
    /// column is one card in one column, = and the plan's words carry
    /// the step, = not an indent in the card).
    let depth: Int

    init(id: String, title: String, status: HermesTodoStatus, parent: String? = nil, depth: Int = 0) {
        self.id = id
        self.title = title
        self.status = status
        self.parent = parent
        self.depth = depth
    }
}

// MARK: - State presentation

/// How a plan item's state reads on a card.
enum InspectorTodoStateStyle {
    /// The state's tint (= the system semantic colour the glyph wears).
    static func tone(for status: HermesTodoStatus) -> IconColor {
        switch status {
        case .pending: return .primary
        case .inProgress: return .tint
        case .completed: return .green
        case .cancelled: return .tertiary
        }
    }

    /// The colour the card's text reads in.
    ///
    /// A step that is still to do reads loud (= the item's own words
    /// carry the eye), and a resolved step reads quiet (= the card
    /// recedes, = the eye goes to the open steps first).
    @MainActor
    static func foreground(for status: HermesTodoStatus) -> HierarchicalShapeStyle {
        switch status {
        case .pending, .inProgress:
            return DesignTokens.textBody
        case .completed, .cancelled:
            return DesignTokens.textMetadata
        }
    }
}
