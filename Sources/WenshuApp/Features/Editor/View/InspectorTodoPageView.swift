//
//  InspectorTodoPageView.swift
//  wenshu
//
//  The todo page of the trailing inspector column.
//
//  The page lists the todos the assistant wrote: the outstanding ones
//  first, then the finished ones, each row showing the todo's title
//  and its state. A header line carries the count of the outstanding
//  ones, so the column answers "how much is queued" without the user
//  opening anything.
//
//  The list comes from the todo store through its repository (= the
//  same store the agent's todo tool writes), so the rows on screen and
//  the count in the header come from one read and cannot disagree.
//
//

import SwiftUI
import WenshuData

/// The trailing inspector column's todo page.
///
/// Lists the todos the assistant wrote (= the app's todo store), the
/// outstanding ones first, with a header line counting the outstanding
/// ones and a way to finish or remove a todo from the list.
struct InspectorTodoPageView: View {
    /// The page's mirror of the todo store (= the store stays the
    /// source of truth; = the view holds a snapshot and re-reads it).
    @State private var model = InspectorTodoModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            loadFailureLine
            content
        }
        .task { await refreshLoop() }
    }

    /// The header line (= the count of the outstanding todos).
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

    /// The count line (= the outstanding count, interpolated).
    private var countText: String {
        String.localizedStringWithFormat(
            NSLocalizedString("inspector.todo.queue.count", comment: "Outstanding todo count"),
            model.outstandingCount
        )
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
    /// rows and the count below are the last good read, so the line
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

    /// The empty state (= the store holds no todo).
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

    /// The todo rows (= the outstanding ones first, then the finished
    /// ones; = the order the snapshot carries).
    private var todoList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(model.todos) { todo in
                    InspectorTodoRow(
                        todo: todo,
                        onFinish: { model.finish(id: todo.id) },
                        onRemove: { model.remove(id: todo.id) }
                    )
                }
            }
            .padding(DesignTokens.spacingStandard)
        }
    }

    /// Re-reads the store, then keeps re-reading it (= the assistant
    /// writes todos while the user watches the page, = the store
    /// changes outside the view).
    @MainActor
    private func refreshLoop() async {
        while !Task.isCancelled {
            model.refresh()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

// MARK: - Row

/// One todo in the page's list (= its title and its state marker).
///
/// The state rides on a symbol, never on dimming the row, so the
/// title stays the primary content of the row.
private struct InspectorTodoRow: View {
    let todo: InspectorTodo
    let onFinish: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            stateMarker
            Text(todo.title)
                .font(.body)
                .foregroundStyle(DesignTokens.textBody)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button(action: onRemove) {
                SFIcon("trash", style: .inlineSmall, color: IconColor.tint)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(String(localized: "inspector.todo.action.remove"))
            .accessibilityLabel(String(localized: "inspector.todo.action.remove"))
        }
        .padding(.vertical, DesignTokens.spacingIconic)
    }

    /// The state marker (= an outstanding todo's marker is the button
    /// that finishes it; = a finished todo's marker is a symbol).
    @ViewBuilder
    private var stateMarker: some View {
        if todo.isOutstanding {
            Button(action: onFinish) {
                SFIcon("circle", style: .inlineSmall, color: IconColor.secondary)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "inspector.todo.action.finish"))
            .accessibilityLabel(String(localized: "inspector.todo.action.finish"))
        } else {
            SFIcon("checkmark.circle", style: .inlineSmall, color: IconColor.green)
        }
    }
}

// MARK: - Mirror

/// The todo page's mirror of the todo store.
///
/// The store stays the source of truth; this holds the snapshot the
/// view draws from and re-reads it.
@MainActor
@Observable
final class InspectorTodoModel {
    /// The todos the page shows (= a snapshot of the store's rows).
    private(set) var todos: [InspectorTodo] = []

    /// The number of outstanding todos (= the count in the header).
    /// Derived from the same read as the rows, so the two agree.
    private(set) var outstandingCount = 0

    /// Whether the first read has landed (= the page shows a spinner
    /// until it has).
    private(set) var isLoaded = false

    /// Whether the last read failed (= the page says so, = the rows
    /// and the count are the last good read).
    private(set) var loadFailed = false

    /// The store the page reads and writes.
    private let repository: WSTodoRepository

    /// The store's reader (= the repository's own read by default; = a
    /// seam so the read-failure path can be driven).
    private let readTodos: () throws -> [WSTodo]

    init(repository: WSTodoRepository = .shared) {
        self.repository = repository
        self.readTodos = { try repository.list() }
    }

    /// A reader the caller supplies (= the repository still writes; =
    /// only the read is replaced).
    init(repository: WSTodoRepository, readTodos: @escaping () throws -> [WSTodo]) {
        self.repository = repository
        self.readTodos = readTodos
    }

    /// One read of the store: the rows and the count come from the same
    /// read, so the count can never disagree with the rows.
    func refresh() {
        let rows: [WSTodo]
        do {
            rows = try readTodos()
        } catch {
            // A failed read keeps the last good snapshot, so the count
            // never reads as zero because the store could not be read.
            loadFailed = true
            isLoaded = true
            return
        }
        loadFailed = false
        let snapshot = rows.map {
            InspectorTodo(id: $0.id, title: $0.title, status: $0.status)
        }
        let outstanding = snapshot.filter(\.isOutstanding)
        todos = outstanding + snapshot.filter { !$0.isOutstanding }
        outstandingCount = outstanding.count
        isLoaded = true
    }

    /// Finishes a todo (= the status the agent's todo tool writes when
    /// it completes one, so both sides read the same state).
    func finish(id: String) {
        try? repository.setStatus(id: id, status: InspectorTodoStatus.finished)
        refresh()
    }

    /// Removes a todo from the store.
    func remove(id: String) {
        try? repository.delete(id: id)
        refresh()
    }
}

/// One todo as the page draws it (= a snapshot of one stored row).
struct InspectorTodo: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    /// The stored status (= the spelling the store really holds).
    let status: String

    /// Whether the todo is still outstanding (= its status is not a
    /// finished one).
    var isOutstanding: Bool {
        InspectorTodoStatus.isOutstanding(status)
    }
}

// MARK: - Status

/// The status vocabulary the todo store really holds.
///
/// Measured from the writers: the repository's add writes "pending",
/// and the agent's todo tool writes "completed" when it completes a
/// todo. The other two finished spellings are the tool's own removal
/// sentinel ("cancelled", = the Hermes-side spelling of the same
/// state) and the todo model's own vocabulary ("done"). Every status
/// that is not one of those is outstanding work.
enum InspectorTodoStatus {
    /// The status a finished todo carries (= the spelling the agent's
    /// todo tool writes when it completes one).
    static let finished = TodoStatus.completed.rawValue

    /// The spellings that mean the todo is finished.
    static let finishedSpellings: Set<String> = [
        TodoStatus.completed.rawValue,
        TodoStatus.cancelled.rawValue,
        "done",
    ]

    /// Whether a todo in this status is still outstanding.
    static func isOutstanding(_ status: String) -> Bool {
        !finishedSpellings.contains(status)
    }
}
