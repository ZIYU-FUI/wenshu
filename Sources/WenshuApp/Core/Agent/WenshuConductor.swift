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
    private let verifier: WenshuVerifier
    private let kanbanStore: KanbanStore
    private let sessionStore: ChatSessionStore?
    /// Long-term memory persistence for agent. Optional — bootstrap failure degrades gracefully (memory disabled).
    /// Bootstrap is lazy on first `handle()` call (Swift actors cannot await in init).
    /// See .scratch/2026-08-22-frontend-integration/issues/h01-memorystore-frontend.md.
    private var memoryStore: MemoryStore?
    private var memoryStoreBootstrapped: Bool = false
    /// Local Skills registry (replica of hermes skills_hub). Skills loaded at startup, agent invokes.
    /// Lazy bootstrap for the same actor isolation reason as MemoryStore.
    /// See .scratch/2026-08-22-frontend-integration/issues/h02-skill-registry-frontend.md.
    private var skillRegistry: SkillRegistry?
    private var skillRegistryBootstrapped: Bool = false
    /// h10: agent toolkit dispatch (FileTools + ProcessTools + WebTools + VisionTools).
    /// Tools are stateless structs, no bootstrap needed.
    /// See .scratch/2026-08-22-frontend-integration/issues/h10-tools-frontend.md.
    private let fileTools: FileTools = FileTools()
    private let processTools: ProcessTools = ProcessTools()
    private let webTools: WebTools = WebTools()
    private let visionTools: VisionTools = VisionTools()
    /// h14: AVMediaTools — agent toolkit dispatch + chat UI read-aloud button.
    /// See .scratch/2026-08-22-frontend-integration/issues/h14-avmedia-tools-frontend.md.
    private let avMediaTools: AVMediaTools = AVMediaTools()

    public init(
        runtime: AgentRuntime,
        verifier: WenshuVerifier,
        kanbanStore: KanbanStore,
        sessionStore: ChatSessionStore? = nil,
        memoryStore: MemoryStore? = nil,
        skillRegistry: SkillRegistry? = nil
    ) {
        self.runtime = runtime
        self.verifier = verifier
        self.kanbanStore = kanbanStore
        self.sessionStore = sessionStore
        self.memoryStore = memoryStore
        self.skillRegistry = skillRegistry
        // Bootstrap deferred to first handle() call (Swift actor init cannot await).
    }

    /// h01: lazy bootstrap of MemoryStore. Idempotent.
    private func ensureMemoryStoreBootstrapped() async {
        guard !memoryStoreBootstrapped else { return }
        memoryStoreBootstrapped = true
        guard let store = memoryStore else { return }
        do {
            try await store.bootstrap()
        } catch {
            // Failure → memory disabled (graceful degradation per v0.21 ticket 04 S4).
            memoryStore = nil
        }
    }

    /// h02: lazy bootstrap of SkillRegistry. Lists available skills.
    private func ensureSkillRegistryBootstrapped() async {
        guard !skillRegistryBootstrapped else { return }
        skillRegistryBootstrapped = true
        guard let registry = skillRegistry else { return }
        do {
            _ = try await registry.list()
        } catch {
            // Failure → skills disabled (graceful degradation).
            skillRegistry = nil
        }
    }

    /// h02: invoke a wenshu local skill. Returns "" if registry unavailable or skill not found.
    public func invokeSkill(name: String, input: String = "") async -> String {
        await ensureSkillRegistryBootstrapped()
        guard let registry = skillRegistry else { return "" }
        return (try? await registry.invoke(name: name, input: input)) ?? ""
    }

    /// h02: list available skills (for agent context). Returns [] if registry unavailable.
    public func availableSkills() async -> [String] {
        await ensureSkillRegistryBootstrapped()
        guard let registry = skillRegistry else { return [] }
        return (try? await registry.list()) ?? []
    }

    /// h10: dispatch an agent tool call. Returns "" on unknown tool / failure.
    /// - file: input = file path → returns file content
    /// - process: input = shell command → returns stdout
    /// - web: input = URL → returns extracted markdown
    /// - vision: input = image path → returns recognized text
    /// - av: input = text → speaks aloud (fire-and-forget)
    public func invokeTool(name: String, input: String) async -> String {
        switch name {
        case "file":
            return (try? fileTools.read(path: input)) ?? ""
        case "process":
            return (try? processTools.runShell(input))?.stdout ?? ""
        case "web":
            return (try? await webTools.extract(url: input)) ?? ""
        case "vision":
            let results = (try? await visionTools.recognizeText(imagePath: input)) ?? []
            return results.map(\.text).joined(separator: "\n")
        case "av":
            avMediaTools.speak(text: input)
            return "[spoken]"
        default:
            return ""
        }
    }

    /// h01: persist a memory for the current user. No-op if MemoryStore unavailable.
    public func addMemory(content: String) async {
        await ensureMemoryStoreBootstrapped()
        guard let store = memoryStore else { return }
        _ = try? await store.add(userId: "wenshu-user", content: content)
    }

    /// h01: search memories for context. Returns [] if MemoryStore unavailable.
    public func searchMemory(query: String, limit: Int = 5) async -> [Memory] {
        await ensureMemoryStoreBootstrapped()
        guard let store = memoryStore else { return [] }
        return (try? await store.search(userId: "wenshu-user", query: query, limit: limit)) ?? []
    }

    /// handle: 收 user message, 派子 agent, 合成最终回复
    /// 真值: user 看不到多 agent 调度痕迹, ChatView 永远只看到 .wenshu 1 个回复
    /// code-review S4 graceful degradation: LLM fail 不抛, fallback synthesis 仍返 reply (老板 macOS 不见 Error 系统消息)
    /// v0.21 ticket 34: 返回 (reply, totalTokens) — totalTokens = intent + sub-agent + synthesis 真实 LLM API usage 累加
    /// v0.21 ticket 38: handle 增加 model 参数 (boss 反馈 "切换了 AI 没有真的换" = 原 handle 用 verifier.init 的 hardcoded model)
    /// v0.21 ticket 39: 加 thinking 字段 (WenshuLLMBlock.thinking footnote UI, Apple HIG footnote 范式)
    public func handle(userMessage: String, sessionId: String, model: String) async -> (reply: String, totalTokens: Int, thinking: String?) {
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
        // v0.22 ticket 001: prepend 文枢 agent identity (WenshuConductorIdentity.systemPrompt)
        // as system prompt. The send() method already injects the pollution-defense
        // systemPromptEnglishOnly as the first system segment; our identity follows.
        // v0.23 ticket 002: 5 sub-agent names instead of 5 module names.
        let intentPrompt = """
        \(WenshuConductorIdentity.systemPrompt)

        ---

        你是 wenshu 文枢调度器. 收到 user 消息: "\(userMessage)"

        可派子 agent (5 专职领域专家):
        - researcher: 找资料 (search / web / linkgraph 工具)
        - writer: 写 / 改 (composer / template / wordcount 工具)
        - analyst: 分析结构 (outline / bases / graph 工具)
        - archivist: 管记忆 (memory / bookmark / backup 工具)
        - auditor: 质量门控 (read-only memory), 自动跑如果 writer / analyst 在选

        派 1-3 个子 agent (JSON array, 仅 agent name, 不要解释):
        ["researcher", "writer"]
        """
        if let intentResponse = try? await verifier.chat(intentPrompt, system: WenshuConductorIdentity.systemPrompt, model: model) {
            // v0.21 ticket 39: union decode WenshuLLMBlock (text / thinking / tool_use)
            let intentRaw = intentResponse.content.map(\.displayText).joined()
            if !intentRaw.isEmpty {
                selectedAgents = parseAgentList(intentRaw).filter { name in
                    SubAgentIdentity.Name(rawValue: name) != nil
                }
            }
            // v0.21 ticket 34: 累加 intent classify real token usage
            totalTokens += intentResponse.usage?.total_tokens ?? 0
        }
        // intent classify fail → selectedAgents 仍空 [] → S4 graceful degradation
        // v0.23 ticket 002: filter unknown agent names to prevent invalid dispatch

        // 步骤 3: 派 0-N 个子 agent 并行 (TaskGroup) + 收集结果 (v0.23 ticket 002)
        // v0.23 ticket 002: TaskGroup parallel dispatch replaces serial for-loop.
        // Each sub-agent has independent system prompt (SubAgentIdentity.systemPrompt).
        var subResults: [(String, String)] = []
        if !selectedAgents.isEmpty {
            // Build tasks (add to KanbanStore first, before TaskGroup, so all parallel tasks see the same state)
            var tasks: [(name: String, kanbanTaskId: String?)] = []
            for agentName in selectedAgents {
                let kTask = try? await kanbanStore.add(title: "\(agentName): \(userMessage.prefix(30))", status: .running)
                tasks.append((name: agentName, kanbanTaskId: kTask?.id))
            }
            // Run sub-agents in parallel
            subResults = await withTaskGroup(of: (String, String).self) { group in
                for (name, _) in tasks {
                    group.addTask { [self] in
                        // Each sub-agent gets its own system prompt + tools (v0.23 ticket 001)
                        let agentPrompt = """
                        \(SubAgentIdentity.systemPrompt(name: SubAgentIdentity.Name(rawValue: name)!))

                        ---

                        User task: \(userMessage)

                        (Run your tools per your role; return JSON per your output format)
                        """
                        guard let response = try? await self.verifier.chat(
                            agentPrompt,
                            system: SubAgentIdentity.systemPrompt(name: SubAgentIdentity.Name(rawValue: name)!),
                            model: model
                        ) else {
                            return (name, "(subagent unreachable)")
                        }
                        return (name, response.content.map(\.displayText).joined())
                    }
                }
                var collected: [(String, String)] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }
            // Mark kanban tasks done (after collection)
            for (name, kanbanId) in tasks {
                if let id = kanbanId {
                    _ = try? await kanbanStore.transition(id: id, to: .done)
                }
            }
            // v0.23 ticket 002: Auditor runs if Writer or Analyst in selection.
            let needsAudit = selectedAgents.contains("writer") || selectedAgents.contains("analyst")
            if needsAudit {
                let auditorPrompt = """
                \(SubAgentIdentity.systemPrompt(name: .auditor))

                ---

                Sub-agent outputs to verify:
                \(subResults.map { "• \($0.0): \($0.1.prefix(300))" }.joined(separator: "\n\n"))

                Return your verdict as JSON per your output format.
                """
                if let auditorResponse = try? await verifier.chat(
                    auditorPrompt,
                    system: SubAgentIdentity.systemPrompt(name: .auditor),
                    model: model
                ) {
                    let verdict = auditorResponse.content.map(\.displayText).joined()
                    subResults.append(("auditor", verdict))
                    totalTokens += auditorResponse.usage?.total_tokens ?? 0
                }
            }
        }

        // 步骤 4: 调 LLM 合成最终回复 (S4 fallback: synthesis fail → 返原文 + 默认合成语)
        // v0.23 ticket 002: synthesis now includes auditor verdict if any.
        let synthesisPrompt = buildSynthesisPrompt(userMessage: userMessage, subResults: subResults)
        var finalThinking: String?    // v0.21 ticket 39: WenshuLLMBlock.thinking
        let finalReply: String
        // v0.22 ticket 001: prepend 文枢 agent identity for synthesis call.
        if let response = try? await verifier.chat(synthesisPrompt, system: WenshuConductorIdentity.systemPrompt, model: model) {
            // v0.21 ticket 39: union decode concat all text blocks (M2.7 有 thinking block 前置)
            let text = response.content.map(\.displayText).joined()
            if !text.isEmpty {
                finalReply = text
                finalThinking = response.content.compactMap(\.thinkingText).first
            } else if subResults.isEmpty {
                finalReply = "（文枢暂时无法回复, 请稍后再试）"
            } else {
                let summary = subResults.map { "• \($0.0): \($0.1.prefix(80))" }.joined(separator: "\n")
                finalReply = "（LLM 合成失败, 下面是子 agent 原始结果）\n\n\(summary)"
            }
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

        return (finalReply, totalTokens, finalThinking)
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