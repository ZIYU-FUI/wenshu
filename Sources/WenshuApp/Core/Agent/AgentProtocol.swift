//
//  AgentProtocol.swift · Wenshu · v0.18 ticket 03 (hermes replica)
//
//  A2A 协议真值 (Google A2A spec): JSON-RPC 2.0 风格, agent 之间消息 + 任务.
//  老板 2026-08-19 拍 "文枢需要多 agent 需要 a2a 协议".
//  简化版: in-process actor 消息 (后续 ticket 04 加 URLSession HTTP server 扩展).
//
//  真值:
//  - AgentMessage: { role: .user / .agent, content: String, metadata: [String: String] }
//  - AgentTask: { id: UUID, status: .pending / .running / .completed / .failed, messages: [AgentMessage] }
//  - A2ARequest: { method: "message/send" / "task/get", params: JSON }
//  - A2AResponse: { result: JSON?, error: A2AError? }
//
//  Apple HIG 真值: actor 线程安全 (Swift 6 strict concurrency) + Sendable 跨 actor.
//

import Foundation

// MARK: - Agent 身份 + Card

/// Agent Card (Google A2A spec 真值): 描述 agent 能力
public struct AgentCard: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    public let skills: [String]
    public let endpoint: String  // 1 个 agent 唯一 endpoint (in-process: actor reference; HTTP: URL)

    public init(name: String, description: String, skills: [String], endpoint: String) {
        self.name = name
        self.description = description
        self.skills = skills
        self.endpoint = endpoint
    }
}

// MARK: - Message + Task

/// Message role 真值 (A2A spec): user (来自外部) / agent (来自 agent)
public enum MessageRole: String, Codable, Sendable {
    case user
    case agent
}

/// 单条消息真值 (A2A spec)
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

/// Task 状态真值 (A2A spec)
public enum TaskStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}

/// Task 真值 (A2A spec): agent 之间的长期异步任务
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

/// A2A method 真值 (Google A2A spec): 限定方法集
public enum A2AMethod: String, Codable, Sendable {
    case messageSend = "message/send"
    case taskGet = "task/get"
    case taskList = "task/list"
}

/// A2A Error 真值 (JSON-RPC 2.0 style)
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

/// A2A Request 真值 (JSON-RPC 2.0 style)
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

/// A2A Params 真值
public enum A2AParams: Codable, Sendable {
    case messageSend(taskId: UUID, message: AgentMessage, fromAgent: String)
    case taskGet(taskId: UUID)
    case taskList(agentName: String?)
}

/// A2A Response 真值
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

/// A2A Result 真值
public enum A2AResult: Codable, Sendable {
    case messageReceived(taskId: UUID, status: TaskStatus)
    case task(AgentTask)
    case taskList([AgentTask])
}

// MARK: - Agent Protocol Actor (in-process A2A 真值)

/// AgentProtocol: A2A 真值实现 (in-process actor, 后续 ticket 04 扩展多 agent + URLSession HTTP)
/// Apple HIG 真值: actor 线程安全 + Sendable 数据
public actor AgentProtocol {
    private var tasks: [UUID: AgentTask] = [:]
    private var tasksByAgent: [String: [UUID]] = [:]
    private let agentCard: AgentCard
    private let verifier: MiniMaxVerifier?

    public init(agentCard: AgentCard, verifier: MiniMaxVerifier? = nil) {
        self.agentCard = agentCard
        self.verifier = verifier
    }

    public func getAgentCard() -> AgentCard {
        agentCard
    }

    /// handle: 处理 A2A Request 真值入口 (后续 ticket 04 加 URLServer 真值)
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
        // 真值: 调 MiniMaxVerifier.send 真合成 agent 回复 (不再是 echo 占位)
        // 没 verifier (老调用) → fallback echo 保留向后兼容
        if let verifier = verifier {
            do {
                let request = MiniMaxRequest(model: "MiniMax-M3", max_tokens: 1024, messages: [MiniMaxMessage(role: "user", content: message.content)])
                let response = try await verifier.send(request: request)
                let reply = response.content.first?.text ?? "(empty reply)"
                let agentMsg = AgentMessage(role: .agent, content: reply)
                task.messages.append(agentMsg)
                task.status = .completed
            } catch {
                task.status = .failed
                task.updatedAt = Date()
                tasks[taskId] = task
                let err = A2AError(code: -32603, message: "LLM failed: \(error.localizedDescription)")
                return A2AResponse(id: request.id, error: err)
            }
        } else {
            // 没 verifier (向后兼容) → echo 占位
            let ack = AgentMessage(role: .agent, content: "received from \(fromAgent): \(message.content.prefix(50))")
            task.messages.append(ack)
            task.status = .completed
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

    /// encode JSON 真值 (Apple JSONEncoder 真值)
    public func encode(_ request: A2ARequest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(request)
    }

    /// decode JSON 真值 (Apple JSONDecoder 真值)
    public func decode(_ data: Data) throws -> A2ARequest {
        try JSONDecoder().decode(A2ARequest.self, from: data)
    }
}