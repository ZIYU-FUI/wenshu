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
//  and re-reads it when the actor says a record changed; the actor
//  stays the source of truth.
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
            .task(id: refreshKey) { await model.follow(scope: scope) }
            .sheet(item: $model.selection) { selection in
                InspectorStatusOutputSheet(model: model, taskID: selection.id)
            }
    }

    @ViewBuilder
    private var content: some View {
        if scope == nil {
            emptyState
        } else if !model.isLoaded {
            // The tasks have not landed yet (= the registry read is
            // still running). The rows the list will hold are reserved
            // (= the project's one loading placeholder), so the column
            // reads as WORKING while they arrive.
            LoadingPlaceholder(.rows(count: 3, unit: .inspectorCard))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(DesignTokens.spacingStandard)
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
    ///
    /// The page carries NO timer (= the clock lives in the one card
    /// that shows a running time, = so a second passing no longer
    /// rebuilds every card on the page).
    private var taskList: some View {
        ScrollView {
            // A LAZY stack (= Apple's own container for a long list in a
            // scroll view), = so a body pass builds the cards that are
            // on screen and not every card on the page.
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(model.tasks) { task in
                    InspectorStatusTaskCard(task: task) {
                        model.selection = InspectorStatusSelection(id: task.id)
                    }
                }
            }
            .padding(DesignTokens.spacingStandard)
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

    /// Follows the registry for one scope: reads it once on subscribe
    /// and then once per change the registry announces, until the
    /// calling task is cancelled (= the view's `.task(id:)` is the only
    /// teardown, and a page that sits idle reads nothing).
    func follow(scope: AgentScope?) async {
        guard let scope else {
            // No session in focus: there is no scope to follow, so the
            // page says it is loaded and holds no subscriber (= a page
            // with nothing to mirror has no reason to keep asking).
            tasks = []
            isLoaded = true
            return
        }
        // The first signal is the subscribe itself, so it paints at
        // once; later ones wait out a quiet window first, so a burst of
        // per-chunk output appends costs one read instead of one each.
        var painted = false
        for await _ in await registry.changes() {
            if painted {
                try? await Task.sleep(for: .milliseconds(250))
            }
            painted = true
            await refresh(scope: scope)
        }
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
    /// What the sub-agent just did. Nil = it has done nothing the card
    /// can name (= the card draws its fallback line instead of the
    /// line vanishing, = = so the card's height does not change while
    /// the agent runs).
    let activityText: String?

    init(handle: BackgroundDelegationHandle) {
        id = handle.id
        agentName = handle.agentName
        taskText = handle.userMessage
        state = handle.state
        startedAt = handle.startedAt
        completedAt = handle.completedAt
        // Only a running task is calling a tool (= a finished task's
        // last tool is history, = the card shows the present).
        currentTool = handle.state == .running ? handle.currentTool : nil
        // The activity line says what the agent did, = = and a card is
        // a history: = = a finished task's last action is still what it
        // did. = = When there is none, the line falls back to a word
        // that fits the STATE (= = the card never says "waiting" about
        // a task that is done).
        activityText = handle.activityText
        switch handle.state {
        case .running:
            // A running task streams its text into the tail.
            output = handle.outputTail.isEmpty ? nil : handle.outputTail
        case .pending:
            output = nil
        case .completed, .failed, .timeout:
            // A finished task carries its answer.
            output = handle.result?.isEmpty == false ? handle.result : nil
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
    var canOpen: Bool {
        output != nil
    }
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
    let onOpen: () -> Void

    var body: some View {
        // The shared card (= the same card the column's other two
        // pages wear), = = and the card IS the control: = = the whole
        // card answers the click, = = the whole card answers the
        // hover, = = and the pointer says "this opens" over the whole
        // card (= = the agent's name and its task sit on the card's
        // first line, = = the state and the task's own words under it,
        // = = and the elapsed time at the trailing edge (= the card's
        // layout is the column's layout, = = and the cards differ in
        // HEIGHT, = never in LAYOUT)).
        //
        // ⇒ A CARD WITHOUT OUTPUT CANNOT BE OPENED (= there is nothing
        // to read), = = and it wears NO open card's answers (= = no
        // hand, = = no hover wash, = = and no button at all), = = for
        // the same reason the old code turned the hit test off rather
        // than disabling the control (= = a disabled control dims the
        // whole card, = = and a running agent that has produced nothing
        // yet would read as finished).
        InspectorCard(
            marker: AnyView(
                SFIcon(
                    InspectorStatusStateStyle.icon(for: task.state),
                    style: .inlineSmall,
                    color: InspectorStatusStateStyle.color(for: task.state)
                )
            ),
            onOpen: task.output != nil ? { onOpen() } : nil
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                HStack(spacing: DesignTokens.spacingIconic) {
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
                }
                Text(InspectorStatusStateStyle.label(for: task.state))
                    .font(.caption)
                    .foregroundStyle(InspectorStatusStateStyle.foreground(for: task.state))
                Text(task.taskText)
                    .font(.callout)
                    .foregroundStyle(InspectorStatusStateStyle.foreground(for: task.state))
                    .lineLimit(3)
                // The activity line: = = what the agent just did,
                // under the task it was given. = It is ALWAYS drawn
                // (= = the fallback says the agent has not done
                // anything yet), = = so the card's height does not
                // change while the agent runs.
                Text(InspectorStatusActivityStyle.text(for: task))
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } trailing: {
            InspectorStatusElapsedLabel(task: task)
        }
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
        SubAgentActivityLine.readableToolName(tool)
    }
}

/// The card's activity line.
///
/// The line always has words: = = a running agent that has not done
/// anything yet says so (= = "Waiting"), = = so the card does not
/// change its height when the agent's first action arrives.
enum InspectorStatusActivityStyle {
    static func text(for task: InspectorStatusTask) -> String {
        if let activity = task.activityText, !activity.isEmpty {
            return activity
        }
        // The fallback is PICKED BY THE STATE, = = the way upstream
        // picks it (= = its sub-agent row falls back to the queued word
        // or the waiting word, = = and it never shows that row for a
        // finished task at all). = = So a card that is done never says
        // it is waiting.
        switch task.state {
        case .pending:
            return String(localized: "inspector.status.activity.queued")
        case .running:
            return String(localized: "inspector.status.activity.waiting")
        case .completed:
            return String(localized: "inspector.status.activity.finished")
        case .failed:
            return String(localized: "inspector.status.activity.failed")
        case .timeout:
            return String(localized: "inspector.status.activity.timedOut")
        }
    }
}

// MARK: - State presentation

/// How a delegation state reads on a card.
enum InspectorStatusStateStyle {
    /// The state label.
    static func label(for state: BackgroundDelegationState) -> String {
        switch state {
        case .pending: return String(localized: "inspector.status.state.pending")
        case .running: return String(localized: "inspector.status.state.running")
        case .completed: return String(localized: "inspector.status.state.done")
        case .failed: return String(localized: "inspector.status.state.failed")
        case .timeout: return String(localized: "inspector.status.state.timeout")
        }
    }

    /// The state's glyph (= the system symbol the card wears).
    static func icon(for state: BackgroundDelegationState) -> String {
        switch state {
        case .pending: return "clock"
        case .running: return "bolt.horizontal"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .timeout: return "clock.badge.exclamationmark"
        }
    }

    /// The state's tint (= the system semantic colour the glyph wears).
    static func color(for state: BackgroundDelegationState) -> IconColor {
        switch state {
        case .pending: return .primary
        case .running: return .tint
        case .completed: return .green
        case .failed: return .red
        case .timeout: return .orange
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
