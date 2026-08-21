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
    /// code-review S4 graceful degradation: LLM fail 不抛, fallback synthesis 仍返 reply (老板 macOS 不见 Error 系统消息)
    /// v0.21 ticket 34: 返回 (reply, totalTokens) — totalTokens = intent + sub-agent + synthesis 真实 LLM API usage 累加
    /// v0.21 ticket 38: handle 增加 model 参数 (boss 反馈 "切换了 AI 没有真的换" = 原 handle 用 verifier.init 的 hardcoded model)
    public func handle(userMessage: String, sessionId: String, model: String) async -> (reply: String, totalTokens: Int) {
        // 步骤 1: 写 1 个 conductor 父 task 到 KanbanStore (看板进度, ChatView 不显)
        let conductorTask: KanbanTask?
        do {
            conductorTask = try await kanbanStore.add(title: "conductor: \(userMessage.prefix(50))", status: .running)
        } catch {
            conductorTask = nil
        }

        // v0.21 ticket 34: 累加全部 LLM API real usage (intent classify + sub-agent LLM calls + synthesis)
        var totalTokens = 0

        // 步骤 2: 调 LLM intent classify, 失败 fallback → 0 子 agent, 不抛
        var selectedAgents: [String] = []
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
        if let intentResponse = try? await verifier.chat(intentPrompt, model: model),
           let intentRaw = intentResponse.content.first?.text {
            selectedAgents = parseAgentList(intentRaw)
            // v0.21 ticket 34: 累加 intent classify real token usage
            totalTokens += intentResponse.usage?.total_tokens ?? 0
        }
        // intent classify fail → selectedAgents 仍空 [] → S4 graceful degradation

        // 步骤 3: 派 0-N 个子 agent task 到 KanbanStore + 收集结果 (子 agent 失败不影响整体)
        var subResults: [(String, String)] = []
        for agentName in selectedAgents {
            if let subTask = try? await kanbanStore.add(title: "\(agentName): \(userMessage.prefix(30))", status: .running) {
                if let task = try? await runtime.delegateTask(to: agentName, content: userMessage, fromAgent: "wenshu-conductor"),
                   let agentReply = task.messages.last(where: { $0.role == .agent })?.content {
                    subResults.append((agentName, agentReply))
                } else {
                    subResults.append((agentName, "(subagent unreachable)"))
                }
                _ = try? await kanbanStore.transition(id: subTask.id, to: .done)
            }
        }

        // 步骤 4: 调 LLM 合成最终回复 (S4 fallback: synthesis fail → 返原文 + 默认合成语)
        let synthesisPrompt = buildSynthesisPrompt(userMessage: userMessage, subResults: subResults)
        let finalReply: String
        if let response = try? await verifier.chat(synthesisPrompt, model: model),
           let text = response.content.first?.text, !text.isEmpty {
            finalReply = text
            // v0.21 ticket 34: 累加 synthesis real token usage
            totalTokens += response.usage?.total_tokens ?? 0
        } else {
            // S4 graceful degradation: synthesis 失败仍返自然回复
            if subResults.isEmpty {
                finalReply = "（文枢暂时无法回复, 请稍后再试）"
            } else {
                let summary = subResults.map { "• \($0.0): \($0.1.prefix(80))" }.joined(separator: "\n")
                finalReply = "（LLM 合成失败, 下面是子 agent 原始结果）\n\n\(summary)"
            }
        }

        // 步骤 5: 标 conductor 父 task done (如果有)
        if let conductorTask = conductorTask {
            _ = try? await kanbanStore.transition(id: conductorTask.id, to: .done)
        }

        return (finalReply, totalTokens)
    }

    /// parseAgentList: 解析 LLM 输出的 JSON array (容错: 真值会有返 ["search"] 或 [search, outline] 或 ['search'])
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