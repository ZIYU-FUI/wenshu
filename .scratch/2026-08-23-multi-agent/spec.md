# Spec — 文枢 Multi-Agent 调度 (5 子 Agent)

> 老板 2026-08-23 拍: "多 agent 调度能实现吗? 我现在有时间了, 有完整流程, 从需求澄清走全流程".
> Boss feedback during grill-with-docs: "一个类别的工作, 交给一个专职人员" + "约束归谁管理? 是主 agent 管理吗".
> Spec v0.1 — domain expert pattern (5 sub-agents) + 主调度 governance.

## Business language (老板 understands)

文枢 (wenshu main agent) 跟老板对话时, **不直接干活** — 把活派给 5 个**专职子 agent**:

1. **Researcher** — 找资料 (search / web / internal link)
2. **Writer** — 写 (composer / template / word count)
3. **Analyst** — 分析结构 (outline / bases / graph)
4. **Archivist** — 管记忆 (memory / bookmark / backup)
5. **Auditor** — 质量门控 (一致性 / 阶段门 / 边界)

老板 = CEO. 文枢 = COO. 5 子 agent = 5 总监.

每 query 流程:
1. 老板说一句话
2. 文枢 (COO) 接收
3. 文枢判断: 这活归哪几个总监? (1-3 个)
4. 文枢派 sub-agent 任务 (并行, TaskGroup)
5. 子 agent 跑完返回结果
6. (可选) Auditor 跑一轮 verification
7. 文枢 (COO) 合成最终回复给老板 (CEO)

## Architecture

```
[User (老板 = CEO)]
        ↓ chat
[WenshuApp / ChatView]
        ↓
[WenshuConductor (文枢 = COO)]
        ├── Intent classify (LLM call 1) → pick 1-3 sub-agents
        ├── TaskGroup dispatch:
        │   ├── Researcher   (LLM call 2a, 独立 system prompt)
        │   ├── Writer       (LLM call 2b, 独立 system prompt)
        │   ├── Analyst      (LLM call 2c, 独立 system prompt)
        │   ├── Archivist    (LLM call 2d, 独立 system prompt)
        │   └── Auditor      (LLM call 2e, verification)
        ├── Synthesis (LLM call 3) → final reply
        └── (Optional) Memory store via Archivist
```

## Sub-agent design (5 agents, all use WenshuVerifier + WenshuConductorIdentity)

### 1. Researcher (检索专家)

- **system prompt role**: "你是 Researcher. 你的工作是找资料. 收到 query → 调 search / web / linkgraph 工具 → 返回 [{source, quote}]."
- **tools**: `search` (FullTextSearch.search) + `web` (WebTools.extract) + `linkgraph` (InternalLinkParser)
- **trigger keywords** (for intent classify): 找, 搜, 查, 网上, 哪个章节, 在哪
- **output format**: `[{source: "search:chapter 2", quote: "..."}]` JSON array
- **example**: 老板问"捕快性格" → Researcher → search + linkgraph → [{source: "ch 2", quote: "..."}]

### 2. Writer (写作专家)

- **system prompt role**: "你是 Writer. 你的工作是写. 收到 task → 调 composer / template / wordcount 工具 → 返回新文字."
- **tools**: `composer` (NoteComposer.merge / split / rename) + `template` (TemplateEngine) + `wordcount` (WordCounter)
- **trigger keywords**: 写, 续, 扩, 改, 风格, 重写, 润色
- **output format**: `{content: "...", wordCount: 1234, style: "wuxia"}` JSON
- **example**: 老板"续写捕快抓贼" → Writer → template (wuxia) + composer → 新章节

### 3. Analyst (结构分析师)

- **system prompt role**: "你是 Analyst. 你的工作是分析结构. 收到 task → 调 outline / bases / graph 工具 → 返回结构化数据."
- **tools**: `outline` (OutlineExtractor) + `bases` (BaseParser) + `graph` (GraphBuilder)
- **trigger keywords**: 大纲, 关系, 图, 汇总, 统计, 表
- **output format**: `{type: "outline|graph|table", data: ...}` JSON
- **example**: 老板"画捕快仵作关系" → Analyst → graph → {type: "graph", data: {nodes, edges}}

### 4. Archivist (记忆管理员)

- **system prompt role**: "你是 Archivist. 你管长期记忆. 收到 task → 调 memory / bookmark / backup 工具 → 返回存储结果."
- **tools**: `memory` (MemoryStore) + `bookmark` (BookmarkStore) + `backup` (BackupTools)
- **trigger keywords**: 记住, 保存, 书签, 收藏, 备份, 别忘
- **output format**: `{stored: 5, recalled: [...]}` JSON
- **example**: 老板"记住捕快性格" → Archivist → memory.add → {stored: 1}

### 5. Auditor (质量审计)

- **system prompt role**: "你是 Auditor. 你审稿. 收到 (Writer output, Researcher output) → 对比一致性 + 调 memory 查基础设定 → 返 verdict (pass/warn/fail) + 改进建议."
- **tools**: `memory` (read-only for canonical settings) + (read-only access to other sub-agents' outputs)
- **trigger keywords**: 不需要 trigger — Auditor 在 synthesis 前**自动跑** (always-on verifier pattern, Anthropic 2024-12 best practice)
- **output format**: `{verdict: "pass|warn|fail", issues: [{type, severity, fix}], confidence: 0-1}`
- **example**: Writer 写"捕快是仵作" + Archivist 记"捕快是捕快出身" → Auditor → {verdict: "fail", issues: ["character inconsistency: 捕快 vs 仵作"]}

## Workflow

Per query:
1. **Conductor L1 (intent classify)**: prompt includes文枢 identity + 5 agent names. Returns `["researcher", "writer"]` (JSON array).
2. **Conductor TaskGroup dispatch** (parallel): for each selected agent, spawn async Task with:
   - sub-agent system prompt (from `WenshuConductorIdentity.subAgentSystemPrompt(name:)`)
   - sub-agent user content = original user message + LLM task description
3. **Conductor collect**: wait for all Tasks. Each returns `JSON output` per agent format.
4. **Auditor pass (if Writer or Analyst ran)**: parallel auditor Task with Writer + Analyst outputs + Archivist (memory) read. Returns verdict.
5. **Conductor L3 (synthesis)**: prompt includes文枢 identity + all sub-agent outputs + Auditor verdict (if any) + user message. Returns final Chinese reply.
6. **Optional Archivist memory store**: if user message contained important info, store to memory (async, fire-and-forget).

## Token cost analysis (per query)

Current: 2 LLM calls (intent + synthesis). Cost: ~2x baseline.
New: 2 + N + 1 (intent + N sub-agents + 1 auditor + synthesis). Cost: ~3-6x baseline (N=1-3).
Tradeoff: better answer quality, slower (~2-4s), more expensive (3-6x tokens).

For minimax cn: M3 model, 1M context, 60 TPS (M2.7) — token cost low priority; latency matters.

## Files to touch (leaf only)

1. **New** `Sources/WenshuApp/Core/Agent/SubAgentIdentity.swift` — 5 sub-agent system prompts (struct with static let dict).
2. **Modify** `Sources/WenshuApp/Core/Agent/WenshuConductorIdentity.swift` — add `subAgentSystemPrompt(name: String) -> String?` method.
3. **Modify** `Sources/WenshuApp/Core/Agent/WenshuConductor.swift`:
   - Replace intent classify prompt (5 agents instead of 5 module names).
   - Replace for-loop with TaskGroup (parallel dispatch).
   - Add Auditor pass after sub-agents (conditional on Writer or Analyst running).
   - Pass sub-agent outputs + auditor verdict to synthesis prompt.
4. **Modify** `Sources/WenshuApp/Core/Agent/AgentRuntime.swift`:
   - Add `delegateTask(to:agentName:content:fromAgent:tools:)` overload that takes tools array (sub-agents need specific tools).
5. **New** `Tests/WenshuAppTests/Core/Agent/MultiAgentDispatchTests.swift` — verify:
   - Intent classify returns 1-3 sub-agents
   - TaskGroup parallel dispatch (timing test)
   - Sub-agent system prompts differ per agent
   - Auditor verdict format
6. **Modify** `Sources/WenshuApp/Core/Agent/WenshuAgentIdentity.swift` — add `subAgentSystemPrompt(name:) -> String?` returning per-agent system prompt (or nil if name unknown).

## Acceptance criteria

- [ ] 5 sub-agent system prompts defined in `SubAgentIdentity.swift` (one per agent)
- [ ] Conductor intent classify returns 1-3 sub-agent names from `["researcher", "writer", "analyst", "archivist", "auditor"]`
- [ ] Sub-agent dispatch via TaskGroup (parallel, not sequential)
- [ ] Auditor auto-runs after Writer or Analyst (not after Researcher alone)
- [ ] Synthesis prompt includes all sub-agent outputs + auditor verdict + original user message
- [ ] swift build exit 0
- [ ] swift test: 348 + new tests pass (target 358-360)
- [ ] Code-review 2 axes (Standards + Spec)

## Out of scope (deferred to v0.23+)

- Sub-agent ↔ sub-agent direct communication (currently all via conductor)
- Per-query budget token cap
- Sub-agent memory (each sub-agent has own scratch memory)
- Sub-agent user override (boss 手动 disable某个 sub-agent)

## Risks

- 3-6x LLM cost per query. Mitigation: optional sub-agent cap (default max 2).
- Latency 2-4s. Mitigation: streaming partial results.
- Intent classify wrong (派错 agent). Mitigation: 1-3 agent dispatch (small set, low cost on retry).

---

*Spec v0.1 · 2026-08-23 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/`*