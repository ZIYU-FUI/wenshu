//
//  WenshuConductor.swift · Wenshu · v0.21 ticket 04 (文枢单显多 agent 隐身)
//
//  文枢主 agent 调度器: 收 user message → 调 LLM intent classify → 派 0-N 个 v0.19 模块 agent → 等结果 → 调 LLM 合成最终回复.
//  调度进度走 KanbanStore 看板 (user 查 Kanban), ChatView 不显 subagent 隐身 (老板 2026-08-21 拍).
//
//  复用 v0.19 12 模块后端 (LinkGraph / Search / Template / Composer / Graph / Canvas / Bases / QuickSwitcher / WordCount / Outline / Bookmarks / Verifier),
//  范式跟 AgentRuntime 一致 (actor in-process 真值).
//

import Foundation

/// 文枢调度器 (actor 线程安全, 跟 AgentRuntime / KanbanStore / MemoryStore 一致).
public actor WenshuConductor {
    private let runtime: AgentRuntime
    private let verifier: MiniMaxVerifier
    private let kanbanStore: KanbanStore
    private let sessionStore: ChatSessionStore?

    public init(runtime: AgentRuntime, verifier: MiniMaxVerifier, kanbanStore: KanbanStore, sessionStore: ChatSessionStore? = nil) {
        self.runtime = runtime
        self.verifier = verifier
        self.kanbanStore = kanbanStore
        self.sessionStore = sessionStore
    }

    /// handle: 收 user message, 派子 agent, 合成最终回复
    /// 真值: user 看不到多 agent 调度痕迹, ChatView 永远只看到 .wenshu 1 个回复
    public func handle(userMessage: String, sessionId: String) async throws -> String {
        // 步骤 1: 写 1 个 conductor 父 task 到 KanbanStore (看板进度, ChatView 不显)
        let conductorTask = try await kanbanStore.add(title: "conductor: \(userMessage.prefix(50))", status: .running)

        // 步骤 2: 调 LLM intent classify (简单 prompt, 不需要真 submodule)
        // 真值: 给 LLM 子 agent list + user message, 让 LLM 选派 0-N 个
        let intentPrompt = """
        你是 wenshu 文枢调度器. 收到 user 消息: "\(userMessage)"

        可派子 agent (wenshu v0.19 模块):
        - search: 全文搜索 (SQLite FTS5 trigram)
        - outline: 章节大纲 (H1-H6 tree)
        - wordcount: 字数统计
        - linkgraph: 内部链接 + backlinks
        - composer: 笔记合并 / 拆分 / 重命名

        派 0-N 个子 agent (JSON array, 仅 agent name, 不要解释):
        ["search", "outline"]
        """
        let intentResponse = try await verifier.chat(intentPrompt)
        let intentRaw = intentResponse.content.first?.text ?? "[]"
        let selectedAgents = parseAgentList(intentRaw)

        // 步骤 3: 派 0-N 个子 agent task 到 KanbanStore + 收集结果
        var subResults: [(String, String)] = []  // (agentName, result)
        for agentName in selectedAgents {
            do {
                let subTask = try await kanbanStore.add(title: "\(agentName): \(userMessage.prefix(30))", status: .running)
                // 调 AgentRuntime 派给子 agent (in-process 真值)
                let task = try await runtime.delegateTask(to: agentName, content: userMessage, fromAgent: "wenshu-conductor")
                let agentReply = task.messages.last(where: { $0.role == .agent })?.content ?? "(no reply)"
                subResults.append((agentName, agentReply))
                try await kanbanStore.transition(id: subTask.id, to: .done)
            } catch {
                // 子 agent 失败不影响整体
                subResults.append((agentName, "(error: \(error.localizedDescription))"))
            }
        }

        // 步骤 4: 调 LLM 合成最终回复 (子 agent results + user message)
        let synthesisPrompt = buildSynthesisPrompt(userMessage: userMessage, subResults: subResults)
        let finalResponse = try await verifier.chat(synthesisPrompt)
        let finalReply = finalResponse.content.first?.text ?? "(no reply)"

        // 步骤 5: 标 conductor 父 task done
        try await kanbanStore.transition(id: conductorTask.id, to: .done)

        return finalReply
    }

    /// parseAgentList: 解析 LLM 输出的 JSON array (容错: 真值可能返 ["search"] 或 [search, outline] 或 ['search'])
    private func parseAgentList(_ raw: String) -> [String] {
        // 简单 regex: 抓 [...] 内容
        guard let start = raw.firstIndex(of: "["),
              let end = raw[start...].firstIndex(of: "]") else {
            return []
        }
        let inner = String(raw[start...end])
        // 拆 + 清洗 (去 ", ', 空白)
        return inner
            .components(separatedBy: ",")
            .compactMap { token -> String? in
                let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                return trimmed.isEmpty ? nil : trimmed
            }
    }

    /// buildSynthesisPrompt: 子 agent 结果拼装 prompt
    private func buildSynthesisPrompt(userMessage: String, subResults: [(String, String)]) -> String {
        var prompt = """
        你是 wenshu 文枢. user 问: "\(userMessage)"

        """
        if subResults.isEmpty {
            prompt += "无子 agent 调度, 直接答.\n"
        } else {
            prompt += "子 agent 调度结果:\n"
            for (name, result) in subResults {
                prompt += "- \(name): \(result.prefix(200))\n"
            }
        }
        prompt += "\n基于以上信息, 用中文给 user 一个完整自然的回复 (200 字内)."
        return prompt
    }
}