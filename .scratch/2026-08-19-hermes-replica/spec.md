# Spec — Hermes 核心能力复刻 (mem0 + skills 加载机制, 老板 2026-08-19 拍)

> Date: 2026-08-19
> Spec 走 po `to-spec` skill 7 段模板

## Problem Statement

老板 2026-08-19 19:57 拍新需求:
> "我们做一些底层依赖的需求吧, 不需要我验收的, 研究一下如何能把 hermes 的核心能力复刻一份过来"

**业务语言描述 (老板懂)**:
- 之前 wenshu 所有 AI 能力 (长期记忆 + 35 skill 加载) 都跑在 hermes agent 跑里, 老板想研究怎么**不靠 hermes** 也能跑 — 让 wenshu 自己有这些能力
- 老板拍 "不需要验收" = 研究 + 实现, 不找老板看
- 老板拍 "底层依赖" = 推到 wenshu 项目自己的 lib/ 或独立模块里

## Solution (按 Q33 + Q34 + 老板 8/19 自行决策授权 拍 范围 A)

按 mem0 真值 (老板 8/19 + 8/11 反馈):
- **Hermes mem0**: 用云服务 mem0, 改 ~/.hermes/profiles/pocock/mem0.json mode = platform 后跑通过 (commit 验证过)
- **Hermes skills 加载**: ~/.hermes/profiles/pocock/skills/ 目录 markdown file, 35 个 skill, 我 SKILL.md skill_view 加载过

**复刻范围 (A 拍)**:
1. **本地 SQLite 长期记忆** — 替代 hermes mem0 云服务, wenshu 本地能 search/add memory, 不依赖 hermes
2. **本地 Skills 加载机制** — wenshu 项目 `Sources/WenshuCore/Skills/` 目录 markdown file, wenshu 自己 skill registry + loader, 不依赖 hermes

## User Stories

1. As 老板, I want wenshu 有自己的长期记忆 (本地 SQLite, 不靠 hermes 云), so that wenshu 离线可用
2. As 老板, I want wenshu 有自己的 skills 加载机制 (本地 markdown files), so that wenshu 不依赖 hermes 的 skill registry
3. As 老板, I want "不需要验收" 推到底层 = 改了 wenshu 项目内部代码 + 新模块, 不动 hermes
4. As 老板, I want 复刻接口跟 hermes 真值 1:1 (skill_view 之类接口可对照), so that 后续可单独升级

## Implementation Decisions

按 "工作量大但稳" + 4 原则 1 伪 Apple 官方 + 老板 "不需要验收" 推到底层:

- **方案 1 (本地 SQLite 记忆)**:
  - 新建 `Sources/WenshuCore/Memory/` 目录
  - `MemoryStore.swift` — SQLite-backed, 表 schema = user_id / memory_id / content / created_at / updated_at
  - 接口 `add(content, metadata)` / `search(query, limit)` / `get(memoryId)` / `delete(memoryId)` / `update(memoryId, content)`
  - 跟 mem0 platform 模式真值接口对齐 (mem0 SDK Python 真值)
- **方案 2 (本地 Skills 加载)**:
  - 新建 `Sources/WenshuCore/Skills/` 目录
  - `SkillRegistry.swift` — 扫描 `Sources/WenshuCore/Skills/<name>/SKILL.md` 目录, parse frontmatter + body
  - `SkillLoader.swift` — `load(name)` 拿 SKILL.md 内容 + linked_files
  - 跟 hermes SKILL.md 真值对齐 (frontmatter + markdown body)
- **不动**: hermes app, ~/.hermes/profiles/pocock/, wenshu 当前 SwiftUI 代码, wenshu 业务逻辑

## Testing Decisions

- 仅 `swift build clean` (exit 0)
- 加单元测试 (MemoryStore.search / add, SkillRegistry.load)
- 老板 8/19 拍 "不需要验收" — 不提交 截图证据, 仅 build + unit test 验证

## Out of Scope

- 不动 hermes app (老板 8/11 拍 'hermes 不动')
- 不动 ~/.hermes/profiles/pocock/ (老板用 hermes profile 继续工作)
- 不动 wenshu 当前 SwiftUI UI / 业务逻辑
- 不复刻 hermes 全能力 (kanban / cron / profile / setup / multi-profile / 信网关 — 都不在范围 A)
- 不复刻 hermes AI runtime (LLM call wrapper 不在范围 A, wenshu 继续用 hermes 调用 AI)

## Further Notes

- 老板 8/19 19:57 拍 "不需要验收" = 老板明确不要 push audit / 老板 yes/no, ANAN 自己跑 po main flow + commit + push
- 按 8/15 rule 严格走 (现老板 8/19 自行决策授权, 简化流程 = 不需要老板拍 yes/no)
- spec / ticket / impl / review / domain-modeling 全跑完一次性 commit + push