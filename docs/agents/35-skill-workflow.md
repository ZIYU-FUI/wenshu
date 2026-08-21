# 35-skill 完整研发流程 (wenshu 落地版)

> 大神 (Matt Pocock) 35 个 SKILL.md 全部装载到 pocock profile. 这份文档 = wenshu 项目对 35 skill 的**完整研发流程图** (不跳任何一环).
> 落地点: wenshu repo `/Volumes/ANAN/Engineering/wenshu/`

## 0. 总览 — 35 skill 分层

| 层 | bucket | count | 触发方式 |
|---|---|---|---|
| 路由 (entry) | engineering | 1 | user-invoked `/ask-matt` |
| 主流程 (idea → ship) | engineering + productivity | 10 | 链式, 每环驱动下一环 |
| On-ramp (岔路) | engineering | 3 | 异常态进入 |
| Codebase health | engineering | 1 | 周期跑 |
| 词汇层 (underneath) | engineering | 2 | 自动 / 引用 |
| 边界 (phase boundary) | productivity | 3 | 阶段间触发 |
| Standalone (off-flow) | productivity | 7 | 老板显式调用 |
| In-progress (beta) | in-progress | 6 | 测试用, 不主推 |
| Misc (留档) | misc | 4 | 历史归档, 不主动用 |
| **合计** | | **35** | |

## 1. 主流程 10 步 (idea → ship, 强制顺序)

| # | skill | user-invoked | 触发时机 | 落地产物 |
|---|---|---|---|---|
| 1 | `ask-matt` | ✓ | 老板说要做 X | 路由选下面 1-N 步 |
| 2 | `grill-with-docs` | ✓ | 有 working directory (wenshu repo) | `CONTEXT.md` 新增 + ADR |
| 3 | `wayfinder` | ✓ | fog 太厚, 1 session 装不下 | decision tickets in `.scratch/` |
| 4 | `to-spec` | ✓ | grill/wayfinder 完, 思路清晰 | spec doc |
| 5 | `to-tickets` | ✓ | spec 完成 | `.scratch/<feature>/issues/NNN-*.md` |
| 6 | `triage` | ✓ | 仅外部 issue (非 to-tickets 产物) | issue state 切换 |
| 7 | `implement` | ✓ | 每个 ticket 自驱, 1 ticket 1 session | 代码 + 测试 + 截图 |
| 8 | `code-review` | ✓ | implement 完 | 两轴 (Standards + Spec) review |
| 9 | `domain-modeling` | 自动 | 新 domain word 入码 | `CONTEXT.md` 增 1 行 |
| 10 | `improve-codebase-architecture` | ✓ | 周期 (有 spare time) | HTML 报告 + deepening candidates |

**3 个 on-ramp** (异常态进入主流程):

| on-ramp | 触发 | 流转到主流程位置 |
|---|---|---|
| `triage` | issue / 外部 PR 堆积 | 状态机 → ready → `/implement` |
| `diagnosing-bugs` | hard bug, 间歇 flake, 回归 | 4-phase → fix → `/code-review` |
| `wayfinder` | greenfield / huge build | decision tickets → `/to-spec` |

**2 个 vocabulary 词汇层** (underneath, 自动 / 引用):

| skill | 作用 | 触发 |
|---|---|---|
| `codebase-design` | deep-module 词汇 (module / interface / depth / seam / adapter) | `tdd` / `improve-codebase-architecture` 内部用 |
| `domain-modeling` | domain 词汇 (fuzzy term / overload / ADR) | `grill-with-docs` 内部用 |

## 2. 阶段边界 3 步 (phase boundary)

| 工具 | 何时用 | 老板拍 |
|---|---|---|
| `clear` | phase 边界, 上下文全没用了 | 一句话 |
| `compact` | phase 边界, 上下文有用要保留 | 一句话 |
| `subagent` | phase 中切短任务 | 给子 agent |

## 3. Standalone 7 步 (off-flow, 老板显式调)

| skill | 作用 | 例子 |
|---|---|---|
| `grill-me` | 无 repo 状态 interview | 老板想 sharpen 一个想法不在 wenshu repo |
| `grilling` | interview 原语, 不带 wrapper | 其他 skill 内部用 |
| `prototype` | 一次性 throwaway 答 1 个设计问题 | "SwiftUI 6 区在 2K 屏缩放行为" |
| `research` | 后台调研, 写 cited markdown | "Apple HIG §3.4 Window Resize 行为" |
| `wizard` | 生成 interactive bash, 走 only-human 步骤 | Apple Developer Program 申请 |
| `wait-what` | 上一句没落地, 重说 | 老板说 "不是这个意思" |
| `teach` | 多 session 学 | 老板想学 SwiftUI 6 区 layout |
| `to-questionnaire` | 决策需别人补, 写问卷 | 跟外部设计师对齐 |
| `handoff` | 压缩对话给下个 agent | 当前 session 完, 切下一个 |
| `writing-for-agents` | 写 skill / AGENTS.md / spec 时的标准 | 我现在写这份文档 |

## 4. In-progress 6 (beta, 不主推)

| skill | 状态 | 用法 |
|---|---|---|
| `claude-handoff` | beta | hand to fresh background agent |
| `loop-me` | beta | grill workflows for build |
| `setup-ts-deep-modules` | beta | TypeScript dep-cruiser (wenshu Swift, 不直接用) |
| `writing-beats` | beta | writing exploit |
| `writing-fragments` | beta | writing explore |
| `writing-shape` | beta | writing exploit |

## 5. Misc 4 (历史归档)

| skill | 状态 | 用法 |
|---|---|---|
| `git-guardrails-claude-code` | 历史 | CC 钩子 block 危险 git (push / reset --hard / clean) |
| `migrate-to-shoehorn` | 历史 | 测试从 `as` 迁到 @total-typescript/shoehorn (TS only) |
| `scaffold-exercises` | 历史 | exercise 目录 sections/problems/solutions |
| `setup-pre-commit` | 历史 | husky + lint-staged pre-commit (wenshu 不用 husky) |

## 6. 强制环节 (大神流程, 写代码必跑)

| 强制环节 | 何时 | 老板接受标准 |
|---|---|---|
| `ask-matt` | 每次新任务 | 路由对了, 没跳关键 skill |
| `grill-with-docs` | 在 wenshu repo 工作时 | CONTEXT.md / ADR 有增量 |
| `to-spec` | grill 完 | spec 有, 老板可读 |
| `to-tickets` | spec 完 | tickets 写齐 .scratch/ |
| `triage` | 外部 issue | 状态机走通 |
| `implement` | 每个 ticket | 1 ticket 1 session, 上下文不混 |
| `tdd` | implement 内部 | RED-GREEN-REFACTOR (UI 走 form-test) |
| `code-review` | implement 完 | 两轴 (Standards + Spec) 通过 |
| `domain-modeling` | 新 domain word | CONTEXT.md 增 1 行 |
| `improve-codebase-architecture` | 周期 (1 周 1 次) | HTML 报告 + 1 个 deepening candidate |

## 7. 跳过决策 (老板有权跳任何一环, 但要被 po 知道)

| 决策 | 跳过的代价 | 老板拍板 |
|---|---|---|
| 跳过 `ask-matt` | 直接进某个 skill, 会有错 | 老板随时可拍 |
| 跳过 `grill-with-docs` | 没 CONTEXT.md 增量, 未来 onboarding 难 | 一次性小改可跳 |
| 跳过 `to-spec` | 想法不清, ticket 拆错 | 中大改不能跳 |
| 跳过 `to-tickets` | 没法并行, 没法 blame | 1 ticket 1 commit 可跳 |
| 跳过 `triage` | — | 内部 ticket 不需要 |
| 跳过 `implement` 自驱 `tdd` | 没测试 | UI 可跳 (form-test 走不了), backend 必走 |
| 跳过 `code-review` | bug / spec 偏离, 大 commit 后回滚 | **不能跳** (老板 8/18 拍) |
| 跳过 `domain-modeling` | vocabulary 漂移 | 1 周可跳 |
| 跳过 `improve-codebase-architecture` | 没候选 deepening, 项目停 | 1 周可跳 |

## 8. wenshu 项目当前 35 skill 落地状态

| 状态 | skill | 备注 |
|---|---|---|
| ✅ 已落地 | `ask-matt`, `code-review`, `setup-matt-pocock-skills` | setup 这次跑 |
| 🟡 跑过单次 | `implement`, `grill-with-docs` (隐式), `codebase-design` (隐式) | 历史 commit 8/18 跑过 implement + code-review |
| 🟡 路由层 | `codebase-design`, `domain-modeling` (词汇层) | 通过 CONTEXT.md 自动注入 |
| ⚪ 等触发 | `wayfinder`, `to-spec`, `to-tickets`, `triage`, `tdd`, `improve-codebase-architecture`, `diagnosing-bugs`, `resolving-merge-conflicts`, `prototype`, `research`, `wizard`, `wait-what`, `teach`, `to-questionnaire`, `handoff`, `writing-for-agents`, `grill-me`, `grilling` | 老板显式调用 |
| 🟡 beta | in-progress 6 + misc 4 | 不主推 |

## 9. 跑完 setup 后的预期变化

- `CONTEXT.md` 存在 → 任何 agent 进 wenshu repo 第一件事读
- `docs/agents/issue-tracker.md` → `to-tickets` / `triage` / `implement` 知道 issue 在 `.scratch/`
- `docs/agents/triage-labels.md` → `triage` 知道 5 canonical 状态
- `docs/agents/domain.md` → agent 知道 single-context, 何时写 ADR
- `docs/adr/0000-template.md` → 写 ADR 模板
- `docs/adr/0001-0005` → 已存 5 个真值决策 (6 区 / 组件化 / 拖拽线 / Library / Document)
- `CLAUDE.md` ## Agent skills 块 → CC 启动时一次性读入完整 35 skill 流程
