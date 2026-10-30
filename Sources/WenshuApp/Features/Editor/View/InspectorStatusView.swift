//
//  InspectorStatusView.swift
//  wenshu
//
//  The status page of the trailing inspector column (= the column's
//  first page). It lists the focused chat session's sub-agent tasks
//  as cards; a card opens that task's output in a read-only sheet.
//
//  The delegation registry is an actor, so a view cannot read it from
//  its body. The page keeps its own snapshot of the scope's handles
//  and re-reads it on a timer; the actor stays the source of truth.
//

import SwiftUI
import WenshuData

/// The trailing inspector column's status page.
///
/// Shows one card per sub-agent task of the focused chat session.
/// The list is scoped: the registry is one instance for the whole
/// app, so a task that does not name this session and book never
/// appears here.
struct InspectorStatusView: View {
    /// The app state (= carries the session + book the list is scoped to).
    let appState: AppState

    /// The page's own mirror of the registry (= the actor stays the
    /// source of truth; = the view holds a snapshot and re-reads it).
    @State private var model = InspectorStatusModel()

    /// The scope the list is filtered by. Nil = no session in focus
    /// (= the page shows its empty state).
    private var scope: AgentScope? {
        InspectorStatusScope.make(
            sessionID: appState.chatSessionID,
            bookID: appState.chatBookID
        )
    }

    /// The identity of the current scope (= the refresh loop restarts
    /// when the focused session or book changes).
    private var refreshKey: String {
        let session = appState.chatSessionID?.rawValue ?? "-"
        let book = appState.chatBookID?.rawValue ?? "-"
        return "\(session)|\(book)"
    }

    var body: some View {
        content
            .task(id: refreshKey) { await refreshLoop() }
            .sheet(item: $model.selection) { selection in
                InspectorStatusOutputSheet(model: model, taskID: selection.id)
            }
    }

    @ViewBuilder
    private var content: some View {
        if scope == nil {
            emptyState
        } else if !model.isLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.tasks.isEmpty {
            emptyState
        } else {
            taskList
        }
    }

    /// The page's empty state (= no session in focus, or a session
    /// whose tasks have not run).
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            EmptyStateView(
                icon: InspectorPage.status.icon,
                title: String(localized: "inspector.status.empty.title"),
                body: String(localized: "inspector.status.empty.body")
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    /// The task cards (= one per handle the registry holds for this scope).
    private var taskList: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                    ForEach(model.tasks) { task in
                        InspectorStatusTaskCard(task: task, now: context.date) {
                            model.selection = InspectorStatusSelection(id: task.id)
                        }
                    }
                }
                .padding(DesignTokens.spacingStandard)
            }
        }
    }

    /// Re-reads the registry for this scope, then keeps re-reading it
    /// on a timer (= the actor's records change outside the view, so
    /// something has to ask again).
    @MainActor
    private func refreshLoop() async {
        while !Task.isCancelled {
            await model.refresh(scope: scope)
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

// MARK: - Mirror

/// The status page's mirror of the delegation registry.
///
/// The actor is the source of truth; this holds the snapshot the view
/// draws from and re-reads it. It is not a second record of the
/// delegations (= the registry stays the only place a task lives).
@MainActor
@Observable
final class InspectorStatusModel {
    /// The scope's tasks (= a snapshot of the registry's handles).
    private(set) var tasks: [InspectorStatusTask] = []

    /// Which task's output the read-only sheet shows.
    var selection: InspectorStatusSelection?

    /// Whether the first read has landed (= the page shows a spinner
    /// until it has).
    private(set) var isLoaded = false

    /// The registry the list reads (= the app-wide one by default).
    private let registry: AsyncDelegationRegistry

    init(registry: AsyncDelegationRegistry = .shared) {
        self.registry = registry
    }

    /// One read of the scope's handles (= an in-memory dictionary scan).
    func refresh(scope: AgentScope?) async {
        guard let scope else {
            tasks = []
            isLoaded = true
            return
        }
        let handles = await registry.handles(scope: scope)
        tasks = handles.map(InspectorStatusTask.init(handle:))
        isLoaded = true
    }
}

/// Which task's output the sheet shows (= the sheet follows the live
/// record, so a running task's text keeps growing while it is open).
struct InspectorStatusSelection: Identifiable, Equatable {
    let id: String
}

// MARK: - Scope

/// The scope the status page filters by.
enum InspectorStatusScope {
    /// The scope for a session + book pair. Nil = no session in focus
    /// (= no task can belong to it).
    static func make(sessionID: SessionID?, bookID: BookID?) -> AgentScope? {
        guard let sessionID else { return nil }
        return AgentScope(sessionID: sessionID, bookID: bookID)
    }
}

// MARK: - Task snapshot

/// One sub-agent task as the status page renders it (= a snapshot of
/// one registry handle).
///
/// The state comes from the handle, not from the lifecycle tracker:
/// the tracker's running + heartbeat records have no production
/// caller, so its stale sweep reports a live task as failed.
struct InspectorStatusTask: Identifiable, Equatable, Sendable {
    let id: String
    let agentName: String
    /// The task text the sub-agent was given.
    let taskText: String
    let state: BackgroundDelegationState
    let startedAt: Date
    let completedAt: Date?
    /// The text the sub-agent has produced. Nil = it has produced none
    /// yet (= the card has no output to open).
    let output: String?
    /// The tool the sub-agent is calling right now. Nil = it is not
    /// calling one (= the card shows no tool column).
    let currentTool: String?

    init(handle: BackgroundDelegationHandle) {
        self.id = handle.id
        self.agentName = handle.agentName
        self.taskText = handle.userMessage
        self.state = handle.state
        self.startedAt = handle.startedAt
        self.completedAt = handle.completedAt
        // Only a running task is calling a tool (= a finished task's
        // last tool is history, = the card shows the present).
        self.currentTool = handle.state == .running ? handle.currentTool : nil
        switch handle.state {
        case .running:
            // A running task streams its text into the tail.
            self.output = handle.outputTail.isEmpty ? nil : handle.outputTail
        case .pending:
            self.output = nil
        case .completed, .failed, .timeout:
            // A finished task carries its answer.
            self.output = handle.result?.isEmpty == false ? handle.result : nil
        }
    }

    /// The elapsed label. Nil while the task has not started running
    /// (= a pending task has no elapsed time to show).
    func elapsedText(at now: Date) -> String? {
        switch state {
        case .pending:
            return nil
        case .running:
            return InspectorStatusElapsed.text(since: startedAt, now: now)
        case .completed, .failed, .timeout:
            // A finished task's clock is frozen at its completion.
            return InspectorStatusElapsed.text(since: startedAt, now: completedAt ?? startedAt)
        }
    }

    /// Whether the card can be opened (= the task has output to read).
    var canOpen: Bool { output != nil }
}

// MARK: - Elapsed time

/// The elapsed-time format of a status card.
///
/// "M:SS" once the task has run for a minute (= the minutes are not
/// folded into hours, so a two-hour task reads "135:54"), and "Ns"
/// under a minute.
enum InspectorStatusElapsed {
    static func text(since start: Date, now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        if total < 60 {
            return "\(total)s"
        }
        let seconds = total % 60
        let padded = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return "\(total / 60):\(padded)"
    }
}

// MARK: - Card

/// One task card (= the sub-agent's name, its task, its state and its
/// elapsed time).
///
/// A card without output cannot be opened (= there is nothing to read).
private struct InspectorStatusTaskCard: View {
    let task: InspectorStatusTask
    /// The current time (= the clock the elapsed label reads).
    let now: Date
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                HStack(spacing: DesignTokens.spacingIconic) {
                    SFIcon(
                        InspectorStatusStateStyle.icon(for: task.state),
                        style: .inlineSmall,
                        color: InspectorStatusStateStyle.color(for: task.state)
                    )
                    Text(task.agentName)
                        .font(.headline)
                        .foregroundStyle(InspectorStatusStateStyle.foreground(for: task.state))
                        .lineLimit(1)
                    if let tool = task.currentTool {
                        // The tool the agent is calling right now, in a
                        // quieter column beside the name (= the agent's
                        // name stays the primary content of the row).
                        Text(InspectorStatusToolLabel.text(tool))
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.statusForeground)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                    if let elapsed = task.elapsedText(at: now) {
                        Text(elapsed)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(DesignTokens.statusForeground)
                    }
                }
                Text(InspectorStatusStateStyle.label(for: task.state))
                    .font(.caption)
                    .foregroundStyle(InspectorStatusStateStyle.foreground(for: task.state))
                Text(task.taskText)
                    .font(.callout)
                    .foregroundStyle(InspectorStatusStateStyle.foreground(for: task.state))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.spacingStandard)
            .background(
                RoundedRectangle(
                    cornerRadius: DesignTokens.surfaceCornerRadiusCard,
                    style: .continuous
                )
                .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
        // A card without output cannot be opened (= there is nothing to
        // read). The hit test is off rather than the control disabled,
        // because a disabled control dims the whole card (= a running
        // agent that has produced nothing yet would read as finished).
        .allowsHitTesting(task.output != nil)
    }
}

// MARK: - Tool label

/// How a tool's name reads on a card.
///
/// A tool's name is its code name (= "read_file"), and a card is for a
/// person. The name is split on its underscores and each part opens with
/// a capital (= "Read File"), so the column reads as words.
enum InspectorStatusToolLabel {
    static func text(_ tool: String) -> String {
        let words = tool
            .split(separator: "_")
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return words.isEmpty ? tool : words.joined(separator: " ")
    }
}

// MARK: - State presentation

/// How a delegation state reads on a card.
enum InspectorStatusStateStyle {
    /// The state label.
    static func label(for state: BackgroundDelegationState) -> String {
        switch state {
        case .pending:    return String(localized: "inspector.status.state.pending")
        case .running:    return String(localized: "inspector.status.state.running")
        case .completed:  return String(localized: "inspector.status.state.done")
        case .failed:     return String(localized: "inspector.status.state.failed")
        case .timeout:    return String(localized: "inspector.status.state.timeout")
        }
    }

    /// The state's glyph (= the system symbol the card wears).
    static func icon(for state: BackgroundDelegationState) -> String {
        switch state {
        case .pending:    return "clock"
        case .running:    return "bolt.horizontal"
        case .completed:  return "checkmark.circle"
        case .failed:     return "xmark.circle"
        case .timeout:    return "clock.badge.exclamationmark"
        }
    }

    /// The state's tint (= the system semantic colour the glyph wears).
    static func color(for state: BackgroundDelegationState) -> IconColor {
        switch state {
        case .pending:    return .primary
        case .running:    return .tint
        case .completed:  return .green
        case .failed:     return .red
        case .timeout:    return .orange
        }
    }

    /// The colour the card's text reads in.
    ///
    /// Work that is still going reads loud (= the state label and the
    /// task text carry the eye, = the column answers "what is happening
    /// now"). Work that is done reads quiet (= the card recedes, = the
    /// eye goes to the live cards first).
    ///
    /// A running agent that has produced no text yet is still live (= it
    /// is running), so it reads loud too (= the card's own state decides
    /// the colour, = not whether there is output to read).
    @MainActor
    static func foreground(for state: BackgroundDelegationState) -> HierarchicalShapeStyle {
        switch state {
        case .pending, .running:
            return DesignTokens.textBody
        case .completed, .failed, .timeout:
            return DesignTokens.textMetadata
        }
    }
}
