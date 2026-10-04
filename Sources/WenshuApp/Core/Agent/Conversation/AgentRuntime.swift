// AgentRuntime.swift
//
// Agent runtime (= hermes `delegation` / `gateway spawn worker`
// parity). Uses Swift `actor` + `Sendable` actor + `Task` (= Apple
// Swift concurrency; = the agent registry + spawn + delegateTask
// surface).

import Foundation

/// Agent registerinfo (hermes delegation card)
struct AgentRegistration: Sendable {
    let name: String
    let card: AgentCard
    let process: AgentProtocol

    init(name: String, card: AgentCard, process: AgentProtocol) {
        self.name = name
        self.card = card
        self.process = process
    }
}

/// AgentRuntime: agent registry + delegateTask
actor AgentRuntime {
    private var agents: [String: AgentRegistration] = [:]
    /// defaultlocal agent (wenshu)
    private var mainAgent: AgentRegistration?

    init() {}

    /// register: register 1 agent
    func register(_ agent: AgentRegistration) {
        agents[agent.name] = agent
        if mainAgent == nil {
            mainAgent = agent
        }
    }

    /// unregister: log out 1 agent
    func unregister(name: String) {
        agents.removeValue(forKey: name)
    }

    /// list: agent names
    func list() -> [String] {
        Array(agents.keys).sorted()
    }

    /// resolve: 1 agent (name)
    func resolve(name: String) -> AgentRegistration? {
        agents[name]
    }

    /// main: default agent
    func main() -> AgentRegistration? {
        mainAgent
    }

    /// delegateTask: task 1 agent (hermes delegation.py delegate_task)
    ///: A2A message/send + wait reply
    func delegateTask(to agentName: String, content: String, fromAgent: String = "main") async throws -> AgentTask {
        guard let agent = agents[agentName] else {
            throw AgentRuntimeError.agentNotFound(name: agentName)
        }
        let taskId = UUID()
        let request = A2ARequest(method: .messageSend, params: .messageSend(
            taskId: taskId,
            message: AgentMessage(role: .user, content: content),
            fromAgent: fromAgent
        ))
        let response = await agent.process.handle(request)
        guard response.error == nil, case .messageReceived = response.result else {
            throw AgentRuntimeError.delegateFailed(agentName: agentName, error: response.error?.message ?? "unknown")
        }
        // task
        let getRequest = A2ARequest(method: .taskGet, params: .taskGet(taskId: taskId))
        let getResponse = await agent.process.handle(getRequest)
        guard case .task(let task) = getResponse.result else {
            throw AgentRuntimeError.delegateFailed(agentName: agentName, error: "task not found")
        }
        return task
    }

    /// broadcast: agent (hermes delegation swarm)
    func broadcast(content: String, fromAgent: String = "main") async -> [String: Result<AgentTask, Error>] {
        var results: [String: Result<AgentTask, Error>] = [:]
        for name in agents.keys {
            do {
                let task = try await delegateTask(to: name, content: content, fromAgent: fromAgent)
                results[name] = .success(task)
            } catch {
                results[name] = .failure(error)
            }
        }
        return results
    }
}

/// AgentRuntime error
enum AgentRuntimeError: Error {
    case agentNotFound(name: String)
    case delegateFailed(agentName: String, error: String)
}

extension AgentRuntimeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .agentNotFound(let name):
            return "Agent not found: \(name)"
        case .delegateFailed(let agentName, let error):
            return "Agent \(agentName) delegation failed: \(error)"
        }
    }
}
