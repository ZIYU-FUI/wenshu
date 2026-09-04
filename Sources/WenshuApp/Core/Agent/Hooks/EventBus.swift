import Foundation

/// Events emitted by the agent runtime.
public enum AgentEvent: Sendable {
    case chatSessionStarted(sessionId: UUID, userId: UUID?)
    case chatSessionEnded(sessionId: UUID)
    case llmRequestStarted(request: LLMRequest, provider: String)
    case llmRequestCompleted(response: LLMResponse, provider: String, duration: TimeInterval)
    case llmRequestFailed(provider: String, error: String, httpStatusCode: Int?)
    case toolCallStarted(toolName: String, input: [String: String])
    case toolCallCompleted(toolName: String, output: String)
    case toolCallFailed(toolName: String, error: String)
    case kanbanTaskCreated(taskId: UUID, title: String)
    case kanbanTaskCompleted(taskId: UUID, title: String)
    case kanbanTaskMoved(taskId: UUID, fromStatus: String, toStatus: String)
    case todoCreated(todoId: UUID, title: String)
    case todoCompleted(todoId: UUID, title: String)
    case connectorError(provider: String, error: String, httpStatusCode: Int?)
    case connectorRotated(provider: String, fromKey: UUID, toKey: UUID, reason: String)
    case connectorRateLimited(provider: String, retryAfter: TimeInterval)
    case cronTick(jobId: String, scheduledAt: Date)
    case cronJobStarted(jobId: String)
    case cronJobCompleted(jobId: String, output: String)
    case cronJobFailed(jobId: String, error: String)
    case skillLoaded(skillName: String, version: String)
    case skillInvoked(skillName: String, args: [String: String])
    case subAgentSpawned(profileSlug: String, taskId: UUID)
    case subAgentCompleted(profileSlug: String, taskId: UUID, result: String)
    case goalStarted(goalId: UUID, goal: String)
    case goalIterationCompleted(goalId: UUID, iteration: Int, work: String)
    case goalCompleted(goalId: UUID, result: String)
    case goalFailed(goalId: UUID, reason: String)
}

public struct EventFilter: Hashable, Sendable {
    public let category: String
    public let specificKind: String?
    public init(category: String, specificKind: String? = nil) {
        self.category = category; self.specificKind = specificKind
    }
}

public protocol AgentEventHandler: Sendable {
    var eventFilter: Set<EventFilter> { get }
    func handle(_ event: AgentEvent) async
    var handlerName: String { get }
}

public actor EventBus {
    public static let shared = EventBus()
    private var handlers: [String: any AgentEventHandler] = [:]
    public init() {}
    public func register(_ handler: any AgentEventHandler) { handlers[handler.handlerName] = handler }
    public func unregister(_ name: String) { handlers.removeValue(forKey: name) }
    public func registeredHandlers() -> [String] { handlers.keys.sorted() }
    public func publish(_ event: AgentEvent) async {
        let filter = Self.filter(for: event)
        let selected = handlers.values.filter { handler in
            handler.eventFilter.contains(filter) || handler.eventFilter.contains(where: { $0.category == filter.category && $0.specificKind == nil })
        }
        await withTaskGroup(of: Void.self) { group in
            for handler in selected { group.addTask { await handler.handle(event) } }
        }
    }
    private static func filter(for event: AgentEvent) -> EventFilter {
        let mirror = Mirror(reflecting: event)
        let kind = String(describing: event).split(separator: "(").first.map(String.init) ?? ""
        let category: String
        switch mirror.enumCaseName {
        case "chatSessionStarted", "chatSessionEnded": category = "conversation"
        case "llmRequestStarted", "llmRequestCompleted", "llmRequestFailed": category = "llm"
        case "toolCallStarted", "toolCallCompleted", "toolCallFailed": category = "tool"
        case "kanbanTaskCreated", "kanbanTaskCompleted", "kanbanTaskMoved", "todoCreated", "todoCompleted": category = "kanban"
        case "connectorError", "connectorRotated", "connectorRateLimited": category = "connector"
        case "cronTick", "cronJobStarted", "cronJobCompleted", "cronJobFailed": category = "cron"
        case "skillLoaded", "skillInvoked": category = "skill"
        case "subAgentSpawned", "subAgentCompleted": category = "subAgent"
        default: category = "goal"
        }
        return EventFilter(category: category, specificKind: kind)
    }
}

private extension Mirror {
    var enumCaseName: String {
        children.first.map { String(describing: $0.label ?? "") } ?? String(describing: self).split(separator: "(").first.map(String.init) ?? ""
    }
}
