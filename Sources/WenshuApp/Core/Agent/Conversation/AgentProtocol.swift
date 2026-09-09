//
//  AgentProtocol.swift · Wenshu · v0.18 ticket 03 (hermes replica)
//
// A2A (Google A2A spec): JSON-RPC 2.0 style, agent message + task.
// 2026-08-19 "need agent need a2a ".
//: in-process actor message (ticket 04 URLSession HTTP server).
//
//:
//  - AgentMessage: { role: .user / .agent, content: String, metadata: [String: String] }
//  - AgentTask: { id: UUID, status: .pending / .running / .completed / .failed, messages: [AgentMessage] }
//  - A2ARequest: { method: "message/send" / "task/get", params: JSON }
//  - A2AResponse: { result: JSON?, error: A2AError? }
//
// Apple HIG: actor (Swift 6 strict concurrency) + Sendable actor.
//

import Foundation

// MARK: - Agent + Card

/// Agent Card (Google A2A spec): agent
public struct AgentCard: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    public let skills: [String]
    public let endpoint: String  // 1 agent endpoint (in-process: actor reference; HTTP: URL)

    public init(name: String, description: String, skills: [String], endpoint: String) {
        self.name = name
        self.description = description
        self.skills = skills
        self.endpoint = endpoint
    }
}

// MARK: - Message + Task

/// Message role (A2A spec): user () / agent (agent)
public enum MessageRole: String, Codable, Sendable {
    case user
    case agent
}

/// message (A2A spec)
public struct AgentMessage: Codable, Equatable, Sendable {
    public let role: MessageRole
    public let content: String
    public let metadata: [String: String]

    public init(role: MessageRole, content: String, metadata: [String: String] = [:]) {
        self.role = role
        self.content = content
        self.metadata = metadata
    }
}

/// Task status (A2A spec)
public enum TaskStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}

/// Task (A2A spec): agent task
public struct AgentTask: Codable, Equatable, Sendable {
    public let id: UUID
    public var status: TaskStatus
    public var messages: [AgentMessage]
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), status: TaskStatus = .pending, messages: [AgentMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.status = status
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - A2A Request / Response

/// A2A method (Google A2A spec):
public enum A2AMethod: String, Codable, Sendable {
    case messageSend = "message/send"
    case taskGet = "task/get"
    case taskList = "task/list"
}

/// A2A Error (JSON-RPC 2.0 style)
public struct A2AError: Codable, Equatable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    public static let methodNotFound = A2AError(code: -32601, message: "Method not found")
    public static let invalidParams = A2AError(code: -32602, message: "Invalid params")
    public static let internalError = A2AError(code: -32603, message: "Internal error")
    public static let taskNotFound = A2AError(code: -32001, message: "Task not found")
}

/// A2A Request (JSON-RPC 2.0 style)
public struct A2ARequest: Codable, Sendable {
    public let jsonrpc: String  // "2.0"
    public let id: String
    public let method: A2AMethod
    public let params: A2AParams

    public init(id: String = UUID().uuidString, method: A2AMethod, params: A2AParams) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A2A Params
public enum A2AParams: Codable, Sendable {
    case messageSend(taskId: UUID, message: AgentMessage, fromAgent: String)
    case taskGet(taskId: UUID)
    case taskList(agentName: String?)
}

/// A2A Response
public struct A2AResponse: Codable, Sendable {
    public let jsonrpc: String  // "2.0"
    public let id: String
    public let result: A2AResult?
    public let error: A2AError?

    public init(id: String, result: A2AResult? = nil, error: A2AError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}

/// A2A Result
public enum A2AResult: Codable, Sendable {
    case messageReceived(taskId: UUID, status: TaskStatus)
    case task(AgentTask)
    case taskList([AgentTask])
}

// MARK: - Agent Protocol Actor (in-process A2A)

/// AgentProtocol: A2A (in-process actor, ticket 04 agent + URLSession HTTP)
/// Apple HIG: actor + Sendable
public actor AgentProtocol {
    private var tasks: [UUID: AgentTask] = [:]
    private var tasksByAgent: [String: [UUID]] = [:]
    private let agentCard: AgentCard
    private let verifier: WenshuVerifier?

    public init(agentCard: AgentCard, verifier: WenshuVerifier? = nil) {
        self.agentCard = agentCard
        self.verifier = verifier
    }

    public func getAgentCard() -> AgentCard {
        agentCard
    }

    /// handle: A2A Request (ticket 04 URLServer)
    public func handle(_ request: A2ARequest) async -> A2AResponse {
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
        guard case .messageSend(let taskId, let message, let fromAgent) = request.params else {
            return A2AResponse(id: request.id, error: .invalidParams)
        }
        var task = tasks[taskId] ?? AgentTask(id: taskId)
        task.status = .running
        task.messages.append(message)
        task.updatedAt = Date()
        //: WenshuVerifier agent (v0.21 ticket 03 + code-review S3 spec violation)
        // verifier, verifier → throw (spec ticket 03 step 1 ' echo ')
        guard let verifier = verifier else {
            task.status = .failed
            task.updatedAt = Date()
            tasks[taskId] = task  // v0.21 ticket 03 + S3: task save
            tasksByAgent[agentCard.name, default: []].append(taskId)
            return A2AResponse(id: request.id, error: A2AError(code: -32603, message: "verifier not configured"))
        }
        do {
            let response = try await verifier.chat(message.content)
            // v0.21 ticket 39: union decode (text / thinking / tool_use) — concat all text blocks
            let reply = response.content.map(\.displayText).joined()
            if reply.isEmpty { "(empty reply)" } else { reply }
            let agentMsg = AgentMessage(role: .agent, content: reply)
            task.messages.append(agentMsg)
            task.status = .completed
        } catch {
            task.status = .failed
            task.updatedAt = Date()
            tasks[taskId] = task  // v0.21 ticket 03 + S3: task save
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
    public func encode(_ request: A2ARequest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(request)
    }

    /// decode JSON (Apple JSONDecoder)
    public func decode(_ data: Data) throws -> A2ARequest {
        try JSONDecoder().decode(A2ARequest.self, from: data)
    }
}