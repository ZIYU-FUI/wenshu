//
//  AgentRuntime.swift · Wenshu · v0.18 ticket 04 (hermes replica)
//
//  多 agent runtime (复刻 hermes delegation / gateway spawn worker).
//  老板 2026-08-19 拍 "文枢需要多 agent 需要 a2a 协议" + "用 Apple 体系实现".
//
//  真值: agent registry + spawn + delegateTask (hermes delegation.py 真值简化版).
//  Apple HIG 真值: actor 线程安全 + Sendable 跨 actor + Task 真值 (Swift 并发).
//

import Foundation

/// Agent 注册信息 (hermes delegation card 真值简化版)
public struct AgentRegistration: Sendable {
    public let name: String
    public let card: AgentCard
    public let process: AgentProtocol

    public init(name: String, card: AgentCard, process: AgentProtocol) {
        self.name = name
        self.card = card
        self.process = process
    }
}

/// AgentRuntime: 多 agent registry + delegateTask 真值
public actor AgentRuntime {
    private var agents: [String: AgentRegistration] = [:]
    /// 默认本地主 agent (wenshu 自己)
    private var mainAgent: AgentRegistration?

    public init() {}

    /// register: 注册 1 个 agent
    public func register(_ agent: AgentRegistration) {
        agents[agent.name] = agent
        if mainAgent == nil {
            mainAgent = agent
        }
    }

    /// unregister: 注销 1 个 agent
    public func unregister(name: String) {
        agents.removeValue(forKey: name)
    }

    /// list: 列所有 agent names
    public func list() -> [String] {
        Array(agents.keys).sorted()
    }

    /// resolve: 拿 1 个 agent (按 name)
    public func resolve(name: String) -> AgentRegistration? {
        agents[name]
    }

    /// main: 拿默认主 agent
    public func main() -> AgentRegistration? {
        mainAgent
    }

    /// delegateTask: 派任务给 1 个 agent (hermes delegation.py delegate_task 真值简化版)
    /// 真值: 发 A2A message/send + 等 reply
    public func delegateTask(to agentName: String, content: String, fromAgent: String = "main") async throws -> AgentTask {
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
        // 拿 task 详情
        let getRequest = A2ARequest(method: .taskGet, params: .taskGet(taskId: taskId))
        let getResponse = await agent.process.handle(getRequest)
        guard case .task(let task) = getResponse.result else {
            throw AgentRuntimeError.delegateFailed(agentName: agentName, error: "task not found")
        }
        return task
    }

    /// broadcast: 广播给所有 agent (hermes delegation swarm 真值简化版)
    public func broadcast(content: String, fromAgent: String = "main") async -> [String: Result<AgentTask, Error>] {
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

/// AgentRuntime 错误
public enum AgentRuntimeError: Error {
    case agentNotFound(name: String)
    case delegateFailed(agentName: String, error: String)
}