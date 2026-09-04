# Wenshu Integration Plan — wayfinder map (boss 2026-09-04 OOB '用 po 全链路方法论, 梳理整合 gap 分析建议的优先级的工作计划')

## Destination

Wenshu 的 6 capability area (Library / Editor / SpecializedTools / Agent / OpenBox / LongForm) 都从 ⚠️ partial / ❌ placeholder 升级到 ✅ wired — 用户能真正用起来所有今日复刻的 hermes 模块。

## Notes

- 整合 gap analysis: `.scratch/2026-09-04-wenshu-integration-gap-analysis.md` (570 行, ~45 KB) — 全清单
- 6 大块 cap area per boss 8/27 final OOB
- Wayfinder = 大块规划 (= ticket 拆解,不做实现本身)
- boss OOB: '我们不能只复刻一些核心能力的模块代码, 那没有意义, 我们要用起来, 接进文枢系统里'
- 单次 auto-pilot = 每个 ticket 一 commit
- Priority 排序 = 高影响 + 低 effort + cross-cutting

## Decisions so far

- 用本地 markdown tracker (= `.scratch/2026-09-04-wenshu-integration-plan.md`, 因为 wenshu 没 issue tracker wired)
- 按 priority 排序: P0 = wire Agent core 到 ChatView(影响最大,工作量最小)/ P1 = wire LongForm / P2 = wire SpecializedTools / P3 = wire Editor paragraph AI / P4 = wire Library LLM-facing API / P5 = OpenBox data flow
- 每个 ticket = 1 commit push 两边
- 不动 out-of-scope 模块 (= hermes SaaS / Codex / browser / MCP / TTS / STT / image-gen / video-gen / CLI / web / dashboard 等 280K LOC)

## Frontier (= open, unblocked, takeable tickets in priority order)

### P0 — wire Agent core(5 tickets,~5 天)

1. **wire ConversationLoop 到 WenshuConductor.handle()**(让 LLM 调用真正走完整 loop + tool dispatch)
2. **wire ToolExecutor 进 ChatView(段落级 AI 触发需要)**
3. **wire HermesGoals 进 ChatView(= long-running goal button + Ralph loop 触发)**
4. **wire HermesTodoTool → TodoStore(= LLM 可写 Todo)**
5. **wire KanbanTools → KanbanStore(= LLM 可写 Kanban)**

### P1 — wire LongForm surface(1 ticket,~5 天)

6. **port `agent/specialized/long_form_guardrails.py` (= constraint / continuity / self-proof / persona / character arc / world consistency)+ SpecializedTools tab**

### P2 — wire SpecializedTools(8 tickets,~3 周)

7. **port `foreshadowing_tracker.py` + wire ForeshadowingView**
8. **port `placeholder_scanner.py` + wire PlaceholderView**
9. **port `emotion_curve.py` + new EmotionCurveView + specializedTools tab**
10. **port `character_relationships.py` + new CharacterRelationshipsView + specializedTools tab**
11. **port `character_lifecycle.py` + new CharacterLifecycleView + specializedTools tab**
12. **port `tag_manager.py` + new TagManagerView + specializedTools tab**
13. **port `idea_library.py` + new IdeaLibraryView + specializedTools tab**
14. **port `book_setting_constraints.py` + new SettingConstraintsView + specializedTools tab**

### P3 — wire Editor paragraph AI(1 ticket,~3 天)

15. **port `agent/editing/paragraph_ai.py` + ParagraphAITool(= editor toolbar 3 buttons: expand / shorten / rewrite)+ keyboard shortcuts**

### P4 — wire Library LLM-facing API(1 ticket,~2 天)

16. **port `agent/librarian/book_manager.py` + BookManagerTool(= LLM 可 create/rename/delete books)+ BookManagerUI in LibraryRootView**

### P5 — wire OpenBox data flow(2 tickets,~3 天)

17. **wire real-time progress from agent loop → SubAgentProgressView**
18. **wire Todo writes from ConversationLoop → TodoListView**

## Not yet specified

- v0.40 架构 refactor (Q1-Q8 boss decisions per .scratch/2026-09-04-apple-methodology/apple-self-check.md)
- macOS 27 Liquid Glass polish (= AGENTS.md §11 老板拍 chrome 优化)
- 真正的 plugin system (= 不是 EventBus, 而是 hermes 的 lazy_deps + plugin_llm 那层)
- 编辑器的 autocomplete popup (hermes `autocomplete.py`)
- ChatBox 的 voice input (= per §11 不做 TTS, skip)
- ChatBox 的 image attachment (= per §11 不做 vision, skip)

## Out of scope (= 这张 map 之外的 future effort)

- hermes SaaS / Codex / Bedrock / Azure / Nous / MOA / Browser / MCP / TTS / STT / image-gen / video-gen / voice-mode / hermes CLI / hermes web / hermes dashboard / hermes proxy / hermes plugin (= per §2.3+§2.4+§11 不做)
- iOS / iPad (= 老板 8/18 拍 macOS-only)
- 真实 Apple Keychain 写入 (= 等 Apple Dev Program paid → B-10 phase B activation)
- B-07 剩 7 ticket(028-001/002/011 + 015-014/015/019/020/073)(= 等老板拍下一条)

## 优先级排序原则

按**高影响 × 低 effort × cross-cutting**:

| Rank | Ticket | 影响 | Effort | Cross-cutting |
|---|---|---|---|---|
| 1 | wire ConversationLoop | **极高**(= LLM 调真循环)| M | cross Agent + Editor |
| 2 | wire ToolExecutor | **极高**(= paragraph AI 触发)| M | cross Agent + Editor |
| 3 | wire HermesGoals | 高(Ralph loop 触发)| S | Agent only |
| 4 | wire HermesTodoTool → TodoStore | 高(LLM 写 Todo)| S | cross Agent + OpenBox |
| 5 | wire KanbanTools → KanbanStore | 高(LLM 写 Kanban)| S | cross Agent + OpenBox |
| 6 | port long_form_guardrails | **极高**(= 核心 wenshu 竞争力)| L | SpecializedTools + LongForm |
| 7-14 | port 8 specialized tools | 中-高 | L each | SpecializedTools only |
| 15 | port paragraph_ai | 高(段落级 AI)| M | Editor + Agent |
| 16 | port book_manager | 高(LLM 创书)| M | Library + Agent |
| 17 | wire progress | 中 | S | OpenBox + Agent |
| 18 | wire Todo writes | 中 | S | OpenBox + Agent |

## 推荐 take 顺序

- 今天(= 2026-09-04 收盘)**没剩余 auto-pilot ticket** — 所有 5 ticket 等老板拍哪条先推
- 老板派哪条,我立即派 1 子代理 ship (= 1 commit)
- 如果老板不派,**默认进入等老板拍** 状态

## 注意

- Wayfinder 是 planning, 不是 implementing
- 子代理 per ticket 实现(= /implement skill)
- 1 commit per ticket + push 两边
- Boss OOB '工程推进问题不用找我确认 GO' = auto-pilot = 我可以单方派子代理
- 但**用户拍哪条先推** = **等老板拍**

## Total estimate

| Bucket | Tickets | Days |
|---|---|---|
| P0 wire Agent core | 5 | ~5 |
| P1 wire LongForm | 1 | ~5 |
| P2 wire SpecializedTools | 8 | ~15-20 |
| P3 wire paragraph AI | 1 | ~3 |
| P4 wire Library API | 1 | ~2 |
| P5 wire OpenBox | 2 | ~3 |
| **总** | **18 ticket** | **~30-40 天** |

## Acceptance (= "user can use it" 的最终标准)

- 所有 18 ticket ship + push 两边
- Build clean + test green
- wenshu.app 启动后,**6 大块 area 都能用**:
  - Library = sidebar / 章节 / 书 / 全可以 LLM 创建
  - Editor = Markdown + 段落 expand/shorten/rewrite
  - SpecializedTools = 8+ tabs 全部有数据
  - Agent = LLM 走完整 ConversationLoop + Tool dispatch + HermesGoals
  - OpenBox = real-time progress + Todo/Kanban LLM 写入
  - LongForm = constraint / continuity / self-proof / persona / character-arc / world-consistency 全 enforce

*First line = fact. Last line = fact.*
