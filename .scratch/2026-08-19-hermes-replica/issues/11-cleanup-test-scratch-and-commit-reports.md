# 11 — B2 整理: gitignore 加 .test-* + commit layout-refactor + dh-fixes-3 漏的 report

**What to build:**
整理 wenshu repo 工作树脏数据:
1. **102 个 .test-* 测试临时文件** untracked: `.test-kanban-*.db` (30) / `.test-skills-*/` (36) / `.test-todo-*.db` (36) — swift test 跑 v0.18 ticket 02/05/06 留下的 sandbox 临时文件, 不是真实数据, 加 gitignore 排除
2. **2 个 .scratch/ untracked 文件**:
   - `.scratch/2026-08-19-dh-fixes-3/cursor-investigation-report.md` (v1, 跟已 tracked 的 v2 同目录, 应该 commit 进去跟 v2 一起)
   - `.scratch/2026-08-19-layout-refactor/` 整个目录 (spec.md + issues, 跟其他 12 个 .scratch/<feature>/ 同范式, 应该 commit)

**改完:**
- `.gitignore` 加 `.test-*/` 规则 (排除 102 个临时文件 + 未来 subagent 跑 swift test 不会再污染工作树)
- `git add .scratch/2026-08-19-dh-fixes-3/cursor-investigation-report.md` (commit 进去跟 v2 配对)
- `git add .scratch/2026-08-19-layout-refactor/` (整个目录 commit 进去, 跟其他 12 个 .scratch/<feature>/ 同范式)
- 工作树干净: `git status` 0 untracked (除 .test-* 全部被 gitignore 排除)

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit (老板 8/19 自行决策授权 + 不需要验收)

## Acceptance criteria
- [ ] `.gitignore` 加 `.test-*/` 规则
- [ ] `git status --ignored` 显示 .test-* 全 ignored
- [ ] `git add .scratch/2026-08-19-dh-fixes-3/cursor-investigation-report.md`
- [ ] `git add .scratch/2026-08-19-layout-refactor/` 整个目录
- [ ] `git status` 0 untracked (除 .test-* 被 gitignore 排除)
- [ ] swift build exit 0 (gitignore 改动不影响 build)
- [ ] swift test exit 0 (137/137 pass, 不影响 test)
- [ ] 不动 hermes app / ~/.hermes/profiles/pocock/
- [ ] 不动 wenshu 当前 SwiftUI UI / 业务逻辑

## 业务语言描述 (老板懂)
- 工作树干净: 102 个 swift test 临时文件自动忽略, 2 个调研报告 commit 进去
- 以后 subagent 跑 swift test 不会再污染 wenshu 项目根

## 真值引用
- `.test-kanban-*.db` SQLite schema 真值: kanban_tasks (id / title / status / created_at / updated_at) — v0.18 ticket 05 KanbanStoreTests 临时 sandbox db
- `.test-todo-*.db` 同 ticket 06 TodoStore
- `.test-skills-*/` ticket 02 SkillRegistryTests 临时目录
- v0.18 ticket 05 commit `2172c421c` (KanbanStore) + 06 commit `4551ce0af` (TodoStore) + 02 commit `b5c219f3b` (SkillRegistry) 跑测试时留的临时文件
