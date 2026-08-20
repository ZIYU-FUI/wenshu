# Spec — 35 po 大神方法论真值 (老板 2026-08-20 拍 '加载大神的开发全链路')

> Date: 2026-08-20
> 老板 2026-08-20 拍 "加载大神的开发全链路, 加载方法论"
> 真值源: `~/.hermes/profiles/pocock/skills/mattpocock/` (35 SKILL.md)

## Problem Statement

老板拍: wenshu 复刻工作应该加载 35 po 大神 skill, 全链路开发方法论.

## 35 po 大神 skill 全表 (4 桶)

### engineering/ (18 promoted skills, 主流程)

| # | Skill | 方法论摘要 |
|---|---|---|
| 1 | **ask-matt** | 路由 skill — 问哪个 skill / 哪个 flow 适合当前情况 |
| 2 | **code-review** | 两轴 review: Standards (代码符合 repo 标准) + Spec (代码符合 issue/spec). 跑 2 个并行 sub-agent 报告 |
| 3 | **codebase-design** | 深度模块 shared vocabulary — 设计 / 改进模块接口 + 找 deepening 机会 + 找 seam + 让代码更可测 / AI-navigable |
| 4 | **diagnosing-bugs** | 难 bug / 性能 regression 诊断 loop — 用户说"诊断/调试"或"broken/throw/failing/slow" |
| 5 | **domain-modeling** | 构建 / 锐化项目 domain model — pin down domain terminology + 记录 ADR |
| 6 | **grill-with-docs** | 严格 interview 锐化 plan / design, 同步创建 docs (ADR + glossary) |
| 7 | **implement** | 按 spec / ticket 实施工作 |
| 8 | **improve-codebase-architecture** | scan 找 deepening 机会, 视觉化 HTML 报告, grill 选 1 个 |
| 9 | **prototype** | 一次性 prototype 验证设计问题 (state model / UI) |
| 10 | **research** | 调查问题, 抓高信任一手资料, 写 markdown |
| 11 | **resolving-merge-conflicts** | 解决进行中的 git merge / rebase 冲突 |
| 12 | **setup-matt-pocock-skills** | 配 repo 配 35 skill — 首次跑 (设 issue tracker + triage 词 + domain doc layout) |
| 13 | **tdd** | TDD — 用户说"test-first" / "red-green-refactor" / 想要 integration test |
| 14 | **to-spec** | 把当前对话转 spec + 发布到 project issue tracker — 不 interview, 只合成已讨论的 |
| 15 | **to-tickets** | 拆 plan / spec / 对话成 tracer-bullet tickets — 每个 ticket 声明 blocking edges |
| 16 | **triage** | issue / external PR 走 triage state machine — categorize + verify + grill if needed + 写 agent-ready brief |
| 17 | **wayfinder** | 规划大块工作 (>1 session 容量) — shared map of decision tickets, 一次解 1 个 |
| 18 | **wizard** | 交互式 bash wizard 引导人完成 agent 不能做的步骤 (provision infra / 设 credentials / 走陌生 dashboard / one-off 迁移) |

### productivity/ (7 promoted skills, 通用)

| # | Skill | 方法论摘要 |
|---|---|---|
| 1 | **grill-me** | 严格 interview 锐化 plan / design |
| 2 | **grilling** | 用户说"grill" 触发时严格 grill |
| 3 | **handoff** | 把当前对话压成 handoff doc 给另一个 agent |
| 4 | **teach** | 在 workspace 内教用户 1 个新 skill / 概念 |
| 5 | **to-questionnaire** | 把答不全的决策转 questionnaire 给别人填 |
| 6 | **wait-what** | 停止. 上次消息没 land — 重发 |
| 7 | **writing-for-agents** | 给 agent 写文档 — 创建 / 编辑 skill, 改 AGENTS.md / CLAUDE.md |

### misc/ (4 skills, 留档)

| # | Skill | 方法论摘要 |
|---|---|---|
| 1 | **git-guardrails-claude-code** | 设 Claude Code hooks 阻挡危险 git 命令 (push / reset --hard / clean / branch -D 等) |
| 2 | **migrate-to-shoehorn** | 测文件 `as` 改 `@total-typescript/shoehorn` |
| 3 | **scaffold-exercises** | 创建 exercise 目录结构 (sections / problems / solutions / explainers) |
| 4 | **setup-pre-commit** | 设 Husky pre-commit + lint-staged (Prettier) + type check + test |

### in-progress/ (6 skills, beta)

| # | Skill | 方法论摘要 |
|---|---|---|
| 1 | **claude-handoff** | 把当前对话交给新的 background agent 立即接 |
| 2 | **loop-me** | grill me 关于想 build 的 workflow spec (在 workspace 内) |
| 3 | **setup-ts-deep-modules** | 给 TypeScript repo 接 dependency-cruiser — 每个 package 是 deep module |
| 4 | **writing-beats** | 写作 exploit — 把 raw material 拼成 journey of beats |
| 5 | **writing-fragments** | 写作 explore — 挖 raw fragments, 无结构 |
| 6 | **writing-shape** | 写作 exploit — 把 raw material 形成为 article |

## po main flow 6 步 (核心)

老板 8/19 拍"必须 verbatim 保留"+ "code-review 不可跳":

1. **grill-with-docs** (或 grill-me) — 锐化 plan
2. **to-spec** — 写 spec
3. **to-tickets** — 拆 ticket
4. **implement** — 实施
5. **tdd** (或 code-review 两轴) — 验证
6. **domain-modeling** — 记录 domain word

## wenshu 复刻全链路映射 (35 skill × 复刻工作流)

| wenshu 复刻工作 | 跑哪个 skill |
|---|---|
| 1. 复刻范围明确 | ask-matt + grill-with-docs |
| 2. 盘 hermes 真值 | research (deleg subagent) |
| 3. 写复刻 spec | to-spec |
| 4. 拆 ticket | to-tickets |
| 5. 实施每模块 | implement + tdd |
| 6. code review | code-review 两轴 (Standards + Spec) |
| 7. 记录 domain word | domain-modeling + CONTEXT.md |
| 8. 修 bug | diagnosing-bugs + deleg subagent |
| 9. 大块工作 (>1 session) | wayfinder (先拆 decision tickets) |
| 10. UI 端到端 | prototype + implement + 老板验 |
| 11. 跳步 / 上下文迷失 | wait-what |
| 12. agent 之间 handoff | handoff + claude-handoff |
| 13. 难设计决策 | improve-codebase-architecture |
| 14. 模块设计 | codebase-design |
| 15. 教用户 | teach |
| 16. 用户给不完全决策 | to-questionnaire |
| 17. 严格 grill 老板 | grill-me / grilling |
| 18. 给 agent 写文档 | writing-for-agents |
| 19. pre-commit 配 | setup-pre-commit |
| 20. TS deep module | setup-ts-deep-modules |
| 21. git 危险命令 | git-guardrails-claude-code |
| 22. 一次性 prototype | prototype |
| 23. 写文档 | writing-beats / writing-fragments / writing-shape |
| 24. 一次性迁移 | migrate-to-shoehorn |
| 25. 创建 exercise | scaffold-exercises |
| 26. wizard 引导 | wizard |
| 27. triage issue | triage |
| 28. 解决 merge conflict | resolving-merge-conflicts |
| 29. setup 35 skill | setup-matt-pocock-skills |
| 30. loop me | loop-me |

## wenshu 复刻已跑过的 skill (历史 ticket 01-31 + ChatView)

| ticket | 跑过哪些 skill |
|---|---|
| 01 MemoryStore | ask-matt → to-spec → to-tickets → implement → tdd (4/4 tests) → domain-modeling |
| 02 SkillRegistry | 同上 (6/6 tests) |
| 03 AgentProtocol (A2A) | 同上 (6/6 tests) |
| 04 AgentRuntime | 同上 (7/7 tests) |
| 05 KanbanStore | 同上 (6/6 tests) |
| 06 TodoStore | 同上 (6/6 tests) |
| 07 FileTools | 同上 (5/5 tests) |
| 08 ProcessTools | cc-runner 跑 (4/4 tests) |
| 09 WebTools | 同上 (5/5 tests) |
| 10 VisionTools | 同上 (3/3 tests) |
| 11 AVMediaTools | 同上 (5/5 tests) |
| 21 Cronjob | 同上 (7/7 tests) |
| 26 Backup | 同上 (4/4 tests) |
| 29 IntegrationTests | research + to-spec (3/3 tests) |
| 30 DomainModeling | domain-modeling + CONTEXT.md 14 词 |
| 31 MiniMaxVerifier | research + to-spec + implement + tdd + **Q22 真验证** (curl HTTP 200) |
| 32 ChatView (v0.20 ticket01) | prototype + implement + tdd (4/4 tests) + Q22 真值 |

## 全链路开发方法论真值

按老板 8/19 evening "持续继续" + "复刻" + 35 skill 真值 + 4 原则 1 伪 Apple 官方 = **wenshu 复刻必须用 35 skill 全链路**。

老板拍下一步:
1. 继续推进 19 UI 需求 (用 prototype + implement + tdd)
2. SlashCommand 复刻 (v0.21 ticket 01)
3. 收工 / 拍其他需求

## 老板拍的下一步

按 po main flow 跑 35 skill 全链路:
- 19 UI 需求 → prototype + implement + tdd + code-review + domain-modeling
- SlashCommand → grill-with-docs + to-spec + to-tickets + implement + tdd + code-review + domain-modeling