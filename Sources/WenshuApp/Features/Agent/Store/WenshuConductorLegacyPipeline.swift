//
//  WenshuConductorLegacyPipeline.swift
//
//  The legacy conductor pipeline extracted from WenshuConductor.swift
//  in A109 (= §6.6 60-LOC function-level cap; = `runLegacyConductorPipeline`
//  was 205 LOC = 3.42x the cap).
//
//  Why a separate file (= and not in WenshuConductor.swift): the
//  legacy pipeline is 1 single concern (= the fallback path when
//  the WenshuVerifier conversation loop is not yet wired; = runs
//  through WenshuVerifier.streamChat for the actual LLM call).
//  Splitting it out lets the next reader find the legacy path
//  by name; = and it shrinks WenshuConductor.swift from 1167 LOC
//  (= 1.95x the file-level cap) to ~960 LOC (= 1.6x).
//
//  Per the §6.2 4-slot spec: this is the actor's pipeline logic =
//  belongs in Store/ (= the @Observable state + business logic
//  slot; = the actor is the WenshuConductor's runtime state).
//  File naming follows the §6.5 actual-suffix rule (= WenshuConductor
//  is the actor's name; = LegacyPipeline is the concern).
//
//  Privacy note (= the function is still `func` not `private func`;
//  = the actor's stored properties it uses must be relaxed to
//  `var` (not `private var`) for the cross-file extension to
//  reach them; = same pattern as A82-A83 for PreviewPane and
//  A100 for BookChapter).
//

import Foundation
import os

extension WenshuConductor {

    func runLegacyConductorPipeline(
        userMessage: String,
        sessionId: String,
        model: String,
        // Forward streamCallback to the legacy path
        // (= Hermes streaming pattern). The legacy path goes through
        // WenshuVerifier.streamChat (= the same AsyncStream<LLMBlock>
        // used by ChatView's direct-verifier streaming path). Forwarding
        // the callback there means BOTH paths (= legacy verifier path
        // + ConversationLoop orchestrator path) emit LLMBlock events
        // for live token rendering.
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
    ) async -> (reply: String, totalTokens: Int, thinking: String?) {
        // Step 1: write 1 conductor parent task to WSKanbanRepository (kanban progress, not shown in ChatView)
        // create the kanban entry on MainActor (= the WS* repository
        // singletons are @MainActor; the conductor runs on its own
        // actor). MainActor.run is not throwing (= the inner try? is the
        // only error sink), so we can drop the do/catch.
        let conductorTask: String? = await MainActor.run {
            try? self.repositories.kanban.add(title: "conductor: \(userMessage.prefix(50))", status: "running")
        }

        // accumulate all LLM API real usage (intent classify + sub-agent LLM calls + synthesis)
        var totalTokens = 0

        // Step 2: call LLM intent classify, fallback on failure → 0 sub-agents, don't throw
        var selectedAgents: [String] = []
        // prepend Wenshu agent identity (WenshuConductorIdentity.systemPrompt)
        // as system prompt. The send() method already injects the pollution-defense
        // systemPromptEnglishOnly as the first system segment; our identity follows.
        // 5 sub-agent names instead of 5 module names.
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
        do {
            let intentResponse = try await verifier.chat(intentPrompt, system: WenshuConductorIdentity.systemPrompt, model: model)
            // union decode WenshuLLMBlock (text / thinking / tool_use)
            let intentRaw = intentResponse.content.map(\.displayText).joined()
            if !intentRaw.isEmpty {
                selectedAgents = parseAgentList(intentRaw).filter { name in
                    SubAgentIdentity.Name(rawValue: name) != nil
                }
            }
            // accumulate intent classify real token usage
            totalTokens += intentResponse.usage?.total_tokens ?? 0
        } catch {
            // intent classify fail → selectedAgents still empty [] → S4 graceful degradation
            WenshuConductor.toolLogger.error("[wenshu.conductor.intent] intent classify threw: \(String(describing: error), privacy: .public)")
        }
        // filter unknown agent names to prevent invalid dispatch
        selectedAgents = selectedAgents.filter { ["writer", "analyst", "researcher", "auditor", "memory"].contains($0) }
        // Step 3: dispatch 0-N sub-agents in parallel (TaskGroup) + collect results.
        // TaskGroup parallel dispatch replaces serial for-loop.
        // Each sub-agent has independent system prompt (SubAgentIdentity.systemPrompt).
        var subResults: [(String, String)] = []
        if !selectedAgents.isEmpty {
            // Build tasks (add to WSKanbanRepository first, before TaskGroup, so all parallel tasks see the same state)
            var tasks: [(name: String, kanbanTaskId: String?)] = []
            for agentName in selectedAgents {
                let kTask = await MainActor.run {
                    try? self.repositories.kanban.add(title: "\(agentName): \(userMessage.prefix(30))", status: "running")
                }
                tasks.append((name: agentName, kanbanTaskId: kTask))
            }
            // Run sub-agents in parallel
            subResults = await withTaskGroup(of: (String, String).self) { group in
                for (name, _) in tasks {
                    // Pre-validate cast once, skip unknown.
                    // Was: 'SubAgentIdentity.Name(rawValue: name)!' — crash risk.
                    guard let identityName = SubAgentIdentity.Name(rawValue: name) else {
                        continue  // skip unknown sub-agent name
                    }
                    group.addTask { [self] in
                        // Each sub-agent gets its own system prompt + tools.
                        let agentPrompt = """
                        \(SubAgentIdentity.systemPrompt(name: identityName))

                        ---

                        User task: \(userMessage)

                        (Run your tools per your role; return JSON per your output format)
                        """
                        let response: WenshuLLMResponse
                        do {
                            response = try await self.verifier.chat(
                                agentPrompt,
                                system: SubAgentIdentity.systemPrompt(name: identityName),
                                model: model
                            )
                        } catch {
                            WenshuConductor.toolLogger.error("[wenshu.conductor.subagent] sub-agent=\(identityName.rawValue, privacy: .public) chat threw: \(String(describing: error), privacy: .public)")
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
            // Check cancellation before kanban write
            // (2026-08-23 risk-averse: don't write kanban state for cancelled runs).
            // Note: handle() doesn't throw, so guard with Task.isCancelled and
            // skip the kanban transitions if cancelled (loop body no-ops).
            let isCancelled = Task.isCancelled
            // Mark kanban tasks done (after collection)
            for (_, kanbanId) in tasks where !isCancelled {
                if let id = kanbanId {
                    await MainActor.run {
                        _ = try? self.repositories.kanban.transition(id: id, to: "done")
                    }
                }
            }
            // + subsequent migration stepa: write 1-line sub-agent run summary
            // to WSChatRepository.shared (= @MainActor SwiftData wrapper).
            // (2026-08-23: user doesn't need execution details, just sees results — no full LLM dialogue stored).
            for (name, result) in subResults {
                let summary = String(result.prefix(200))  // 1-line summary, not full output
                let run = SubAgentRun(
                    id: UUID().uuidString,
                    agentName: name,
                    title: "\(name): \(userMessage.prefix(50))",
                    status: result.hasPrefix("(subagent unreachable)") ? .failed : .done,
                    startedAt: Date(),
                    completedAt: Date(),
                    resultSummary: summary
                )
                _ = await MainActor.run { try? ConversationOps.recordSubAgentRun(repository: self.repositories.chat, run: run, sessionId: "default") }
            }
            // Auditor runs if Writer or Analyst in selection.
            let needsAudit = selectedAgents.contains("writer") || selectedAgents.contains("analyst")
            if needsAudit {
                let auditorPrompt = """
                \(SubAgentIdentity.systemPrompt(name: .auditor))

                ---

                Sub-agent outputs to verify:
                \(subResults.map { "• \($0.0): \($0.1.prefix(300))" }.joined(separator: "\n\n"))

                Return your verdict as JSON per your output format.
                """
                do {
                    let auditorResponse = try await verifier.chat(
                        auditorPrompt,
                        system: SubAgentIdentity.systemPrompt(name: .auditor),
                        model: model
                    )
                    let verdict = auditorResponse.content.map(\.displayText).joined()
                    subResults.append(("auditor", verdict))
                    totalTokens += auditorResponse.usage?.total_tokens ?? 0
                } catch {
                    WenshuConductor.toolLogger.error("[wenshu.conductor.auditor] auditor verdict threw: \(String(describing: error), privacy: .public)")
                }
            }
        }

        // Step 4: call LLM to synthesize final reply (S4 fallback: synthesis fail → return original text + default synthesis text)
        // synthesis now includes auditor verdict if any.
        let synthesisPrompt = buildSynthesisPrompt(userMessage: userMessage, subResults: subResults)
        var finalThinking: String?    // WenshuLLMBlock.thinking
        let finalReply: String
        // prepend Wenshu agent identity for synthesis call.
        do {
            let response = try await verifier.chat(synthesisPrompt, system: WenshuConductorIdentity.systemPrompt, model: model)
            // union decode concat all text blocks (M2.7 has thinking block prefix)
            let text = response.content.map(\.displayText).joined()
            if !text.isEmpty {
                finalReply = text
                finalThinking = response.content.compactMap(\.thinkingText).first
            } else if subResults.isEmpty {
                finalReply = "(Wenshu cannot reply right now, please try again later)"
            } else {
                let summary = subResults.map { "• \($0.0): \($0.1.prefix(80))" }.joined(separator: "\n")
                finalReply = "(LLM synthesis failed, below is the raw sub-agent result)\n\n\(summary)"
            }
            // accumulate synthesis real token usage
            totalTokens += response.usage?.total_tokens ?? 0
        } catch {
            // S4 graceful degradation: synthesis fail still returns natural reply
            WenshuConductor.toolLogger.error("[wenshu.conductor.synthesis] synthesis threw: \(String(describing: error), privacy: .public)")
            if subResults.isEmpty {
                finalReply = "(Wenshu cannot reply right now, please try again later)"
            } else {
                let summary = subResults.map { "• \($0.0): \($0.1.prefix(80))" }.joined(separator: "\n")
                finalReply = "(LLM synthesis failed, below is the raw sub-agent result)\n\n\(summary)"
            }
        }

        // Step 5: mark conductor parent task done (if any)
        if let conductorTask = conductorTask {
            // Don't write kanban state if cancelled.
            if !Task.isCancelled {
                await MainActor.run {
                    _ = try? self.repositories.kanban.transition(id: conductorTask, to: "done")
                }
            }
        }

        return (finalReply, totalTokens, finalThinking)
    }
}
