// AgentProtocol.swift
//
// A2A (= Google A2A spec): JSON-RPC 2.0 style, agent message + task.
// In-process actor message (= the URLSession HTTP server surface is
// separately layered on top).
//
// Surface:
//   - `AgentMessage`:
//     `{ role: .user / .agent, content: String, metadata: [String: String] }`
//   - `AgentTask`:
//     `{ id: UUID, status: .pending / .running / .completed / .failed, messages: [AgentMessage] }`
//   - `A2ARequest`:
//     `{ method: "message/send" / "task/get", params: JSON }`
//   - `A2AResponse`: `{ result: JSON?, error: A2AError? }`
//
// Apple HIG: actor (Swift 6 strict concurrency) + Sendable actor.
//

import Foundation

// MARK: - Agent + Card

/// Agent Card (Google A2A spec): agent
struct AgentCard: Codable, Equatable, Sendable {
    let name: String
    let description: String
    let skills: [String]
    let endpoint: String  // 1 agent endpoint (in-process: actor reference; HTTP: URL)

    init(name: String, description: String, skills: [String], endpoint: String) {
        self.name = name
        self.description = description
        self.skills = skills
        self.endpoint = endpoint
    }
}

// MARK: - Message + Task

/// Message role (A2A spec): user () / agent (agent)
enum MessageRole: String, Codable, Sendable {
    case user
    case agent
}

/// message (A2A spec)
struct AgentMessage: Codable, Equatable, Sendable {
    let role: MessageRole
    let content: String
    let metadata: [String: String]

    init(role: MessageRole, content: String, metadata: [String: String] = [:]) {
        self.role = role
        self.content = content
        self.metadata = metadata
    }
}

/// Task status (A2A spec)
enum TaskStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}

/// Task (A2A spec): agent task
struct AgentTask: Codable, Equatable, Sendable {
    let id: UUID
    var status: TaskStatus
    var messages: [AgentMessage]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), status: TaskStatus = .pending, messages: [AgentMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.status = status
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - A2A Request / Response

/// A2A method (Google A2A spec):
enum A2AMethod: String, Codable, Sendable {
    case messageSend = "message/send"
    case taskGet = "task/get"
    case taskList = "task/list"
}

/// A2A Error (JSON-RPC 2.0 style)
struct A2AError: Codable, Equatable, Sendable {
    let code: Int
    let message: String

    init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
    static let invalidParams = A2AError(code: -32602, message: "Invalid params")
    static let taskNotFound = A2AError(code: -32001, message: "Task not found")
}

/// A2A Request (JSON-RPC 2.0 style)
struct A2ARequest: Codable, Sendable {
    let jsonrpc: String  // "2.0"
    let id: String
    let method: A2AMethod
    let params: A2AParams

    init(id: String = UUID().uuidString, method: A2AMethod, params: A2AParams) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A2A Params
enum A2AParams: Codable, Sendable {
    case messageSend(taskId: UUID, message: AgentMessage, fromAgent: String)
    case taskGet(taskId: UUID)
    case taskList(agentName: String?)
}

/// A2A Response
struct A2AResponse: Codable, Sendable {
    let jsonrpc: String  // "2.0"
    let id: String
    let result: A2AResult?
    let error: A2AError?

    init(id: String, result: A2AResult? = nil, error: A2AError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}

/// A2A Result
enum A2AResult: Codable, Sendable {
    case messageReceived(taskId: UUID, status: TaskStatus)
    case task(AgentTask)
    case taskList([AgentTask])
}

// MARK: - Agent Protocol Actor (in-process A2A)

/// A2A (= in-process actor + URLSession HTTP server).
/// Apple HIG: actor + `Sendable`.
actor AgentProtocol {
    private var tasks: [UUID: AgentTask] = [:]
    private var tasksByAgent: [String: [UUID]] = [:]
    private let agentCard: AgentCard
    private let verifier: WenshuVerifier?

    init(agentCard: AgentCard, verifier: WenshuVerifier? = nil) {
        self.agentCard = agentCard
        self.verifier = verifier
    }

    func getAgentCard() -> AgentCard {
        agentCard
    }

    /// handle: A2A request (= the canonical entry point).
    func handle(_ request: A2ARequest) async -> A2AResponse {
        switch request.method {
        case .messageSend:
            return await handleMessageSend(request)
        case .taskGet:
            return handleTaskGet(request)
        case .taskList:
            return handleTaskList(request)
        }
    }

    private func handleMessageSend(_ request: A2ARequest) async -> A2AResponse {
        guard case .messageSend(let taskId, let message, _) = request.params else {
            return A2AResponse(id: request.id, error: .invalidParams)
        }
        var task = tasks[taskId] ?? AgentTask(id: taskId)
        task.status = .running
        task.messages.append(message)
        task.updatedAt = Date()
        //  WenshuVerifier agent (= the canonical verifier surface)
        // verifier → throw (= no verifier configured).
        guard let verifier = verifier else {
            task.status = .failed
            task.updatedAt = Date()
            tasks[taskId] = task  // + S3: task save
            tasksByAgent[agentCard.name, default: []].append(taskId)
            return A2AResponse(id: request.id, error: A2AError(code: -32603, message: "verifier not configured"))
        }
        do {
            let response = try await verifier.chat(message.content)
            // union decode (text / thinking / tool_use) — concat all text blocks
            let reply = response.content.map(\.displayText).joined()
            let visibleReply = reply.isEmpty ? "(empty reply)" : reply
            let agentMsg = AgentMessage(role: .agent, content: visibleReply)
            task.messages.append(agentMsg)
            task.status = .completed
        } catch {
            task.status = .failed
            task.updatedAt = Date()
            tasks[taskId] = task  // + S3: task save
            tasksByAgent[agentCard.name, default: []].append(taskId)
            let err = A2AError(code: -32603, message: "LLM failed: \(error.localizedDescription)")
            return A2AResponse(id: request.id, error: err)
        }
        task.updatedAt = Date()
        tasks[taskId] = task
        tasksByAgent[agentCard.name, default: []].append(taskId)
        return A2AResponse(id: request.id, result: .messageReceived(taskId: task.id, status: task.status))
    }

    private func handleTaskGet(_ request: A2ARequest) -> A2AResponse {
        guard case .taskGet(let taskId) = request.params else {
            return A2AResponse(id: request.id, error: .invalidParams)
        }
        guard let task = tasks[taskId] else {
            return A2AResponse(id: request.id, error: .taskNotFound)
        }
        return A2AResponse(id: request.id, result: .task(task))
    }

    private func handleTaskList(_ request: A2ARequest) -> A2AResponse {
        guard case .taskList(let agentName) = request.params else {
            return A2AResponse(id: request.id, error: .invalidParams)
        }
        let filterName = agentName ?? agentCard.name
        let taskIds = tasksByAgent[filterName] ?? []
        let list = taskIds.compactMap { tasks[$0] }
        return A2AResponse(id: request.id, result: .taskList(list))
    }

    /// encode JSON (Apple JSONEncoder)
    func encode(_ request: A2ARequest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(request)
    }

    /// decode JSON (Apple JSONDecoder)
    func decode(_ data: Data) throws -> A2ARequest {
        try JSONDecoder().decode(A2ARequest.self, from: data)
    }
}