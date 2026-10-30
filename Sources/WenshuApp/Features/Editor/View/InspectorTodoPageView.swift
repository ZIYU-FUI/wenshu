//
//  InspectorTodoPageView.swift
//  wenshu
//
//  The todo page of the trailing inspector column.
//
//  The page shows the plan the ASSISTANT wrote: the rows come from the
//  agent's own plan store, the assistant writes them, and the user
//  cannot edit them (= the page is read-only, because the assistant's
//  next turn owns that list). A header line counts the plan the way a
//  plan is counted (= done over total, and a dropped item counts on
//  neither side), so the column answers "how much is left" without the
//  user opening anything.
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

import SwiftUI

/// The trailing inspector column's todo page.
///
/// Shows the plan the assistant wrote (= the agent's plan store), the
/// outstanding items first, with a header line counting the plan and a
/// card per item.
struct InspectorTodoPageView: View {
    /// The page's own mirror of the plan store (= the store stays the
    /// source of truth; = the view holds a snapshot and re-reads it).
    @State private var model = InspectorTodoModel()

    /// Whether the plan's cards are visible (= the header folds them).
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            header
            loadFailureLine
            content
        }
        .task { await refreshLoop() }
    }

    /// The header line (= the plan's count).
    ///
    /// The count reads done over total (= "3/7"), which is how a plan is
    /// counted. A dropped item (= cancelled) is on neither side of the
    /// fraction, because it is neither done nor still to do.
    private var header: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            Text(countText)
                .font(.callout)
                .foregroundStyle(DesignTokens.textChrome)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.spacingStandard)
        .padding(.vertical, DesignTokens.spacingTight)
    }

    /// The count line (= the done count over the total).
    private var countText: String {
        "\(model.doneCount)/\(model.totalCount)"
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
    /// cards and the count below are the last good read, so the line
    /// says the list may be stale).
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
    /// The cards fold under the header: a folded plan shows its count
    /// and nothing else, so the column stays quiet when the user is
    /// not reading the plan.
    private var todoList: some View {
        ScrollView {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                    ForEach(model.todos) { todo in
                        InspectorTodoCard(todo: todo)
                    }
                }
                .padding(.top, DesignTokens.spacingTight)
            } label: {
                EmptyView()
            }
            .padding(.horizontal, DesignTokens.spacingStandard)
            .padding(.bottom, DesignTokens.spacingStandard)
        }
    }

    /// Re-reads the plan store, then keeps re-reading it (= the assistant
    /// writes the plan while the user watches the page, = the store
    /// changes outside the view).
    @MainActor
    private func refreshLoop() async {
        while !Task.isCancelled {
            model.refresh()
            try? await Task.sleep(for: .seconds(1))
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
        HStack(alignment: .top, spacing: DesignTokens.spacingIconic) {
            // The marker sits in a column of its own width (= the
            // inline-small glyph's point size), so every card's words
            // start at the same place (= a spinner and a symbol have
            // different intrinsic widths, = without the column the
            // rows read ragged).
            stateMarker
                .frame(width: DesignTokens.inspectionMarkerColumnWidth, alignment: .leading)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 0) {
                Text(todo.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(InspectorTodoStateStyle.foreground(for: todo.status))
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.spacingStandard)
        .frame(maxWidth: .infinity, alignment: .leading)
        // An item that belongs to another item reads indented under it
        // (= the plan is a tree, and the tree shows in the shape).
        .padding(.leading, CGFloat(todo.depth) * DesignTokens.spacingLoose)
        .background(.background, in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                .stroke(.separator, lineWidth: DesignTokens.separatorThicknessHairline)
        )
        .overlay(alignment: .leading) {
            // The state edge (= the board's card carries one, = the plan's
            // cards carry the item's state the same way).
            Rectangle()
                .fill(InspectorTodoStateStyle.tone(for: todo.status).style)
                .frame(width: DesignTokens.kanbanCardStatusEdgeWidth)
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
            SFIcon("tray", style: .inlineSmall, color: InspectorTodoStateStyle.tone(for: todo.status))
                .symbolRenderingMode(.hierarchical)
        case HermesTodoStatus.inProgress:
            ProgressView()
                .controlSize(.mini)
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

    /// The number of resolved items (= the left side of the count).
    private(set) var doneCount = 0

    /// The number of items the plan holds (= the right side of the count).
    private(set) var totalCount = 0

    /// Whether the first read has landed (= the page shows a spinner
    /// until it has).
    private(set) var isLoaded = false

    /// Whether the last read failed (= the page says so, = the cards
    /// and the count are the last good read).
    private(set) var loadFailed = false

    /// The store the page reads.
    private let readPlan: () throws -> [HermesTodoItem]

    init(readPlan: @escaping () throws -> [HermesTodoItem] = { HermesTodoTool.shared.readPlan() }) {
        self.readPlan = readPlan
    }

    /// One read of the store: the cards and the count come from the same
    /// read, so the count can never disagree with the cards.
    func refresh() {
        let items: [HermesTodoItem]
        do {
            items = try readPlan()
        } catch {
            // A failed read keeps the last good snapshot, so the count
            // never reads as zero because the store could not be read.
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

        // The count reads done over total, and a dropped item is on
        // neither side (= it is neither done nor still to do).
        doneCount = snapshot.filter { $0.status == .completed }.count
        totalCount = snapshot.filter { $0.status != .cancelled }.count
        isLoaded = true
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
    let depth: Int

    init(id: String, title: String, status: HermesTodoStatus, parent: String? = nil, depth: Int = 0) {
        self.id = id
        self.title = title
        self.status = status
        self.parent = parent
        self.depth = depth
    }

    /// Whether the item is still outstanding (= its state is not a
    /// resolved one).
    var isOutstanding: Bool {
        status == .pending || status == .inProgress
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
        // The parent's own depth is the base (= 0 for a top-level item,
        // = so its child is one step in). A parent whose chain has no
        // root reports -1, = the chain degrades to the top.
        let parentDepth = depth(of: parent, byId: byId, seen: seen + [todo.id])
        guard parentDepth >= 0 else { return -1 }
        return parentDepth + 1
    }
}

// MARK: - State presentation

/// How a plan item's state reads on a card.
enum InspectorTodoStateStyle {
    /// The state's tint (= the system semantic colour the glyph wears).
    static func tone(for status: HermesTodoStatus) -> IconColor {
        switch status {
        case .pending:      return .primary
        case .inProgress:  return .tint
        case .completed:   return .green
        case .cancelled:   return .tertiary
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
