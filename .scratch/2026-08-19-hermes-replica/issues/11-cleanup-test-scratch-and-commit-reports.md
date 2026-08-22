# 11 — B2 cleanup: gitignore add .test-* + commit layout-refactor + dh-fixes-3 missing report

**What to build:**
Tidy wenshu repo working tree dirty data:
1. **102 `.test-*` test temp files** untracked: `.test-kanban-*.db` (30) / `.test-skills-*/` (36) / `.test-todo-*.db` (36) — swift test ran v0.18 ticket 02/05/06 left sandbox temp files, not real data, add gitignore exclusion
2. **2 `.scratch/` untracked files**:
   - `.scratch/2026-08-19-dh-fixes-3/cursor-investigation-report.md` (v1, in same dir as already-tracked v2, should commit alongside v2)
   - `.scratch/2026-08-19-layout-refactor/` entire directory (spec.md + issues, same paradigm as other 12 `.scratch/<feature>/`, should commit)

**After change:**
- `.gitignore` add `.test-*/` rule (exclude 102 temp files + future subagent running swift test won't pollute working tree anymore)
- `git add .scratch/2026-08-19-dh-fixes-3/cursor-investigation-report.md` (commit alongside v2)
- `git add .scratch/2026-08-19-layout-refactor/` (commit entire directory, same paradigm as other 12 `.scratch/<feature>/`)
- Working tree clean: `git status` 0 untracked (except `.test-*` all excluded by gitignore)

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit (老板 8/19 self-decision authorization + no verification needed)

## Acceptance criteria

- [ ] `.gitignore` add `.test-*/` rule
- [ ] `git status --ignored` shows `.test-*` all ignored
- [ ] `git add .scratch/2026-08-19-dh-fixes-3/cursor-investigation-report.md`
- [ ] `git add .scratch/2026-08-19-layout-refactor/` entire directory
- [ ] `git status` 0 untracked (except `.test-*` excluded by gitignore)
- [ ] `swift build` exit 0 (gitignore changes don't affect build)
- [ ] `swift test` exit 0 (137/137 pass, doesn't affect test)
- [ ] Do not touch hermes app / `~/.hermes/profiles/pocock/`
- [ ] Do not touch wenshu current SwiftUI UI / business logic

## Business-language description (老板 understands)

- Working tree clean: 102 swift test temp files auto-ignored, 2 research reports committed
- Future subagent running swift test won't pollute wenshu project root anymore

## Truth references

- `.test-kanban-*.db` SQLite schema truth: kanban_tasks (id / title / status / created_at / updated_at) — v0.18 ticket 05 KanbanStoreTests temp sandbox db
- `.test-todo-*.db` same ticket 06 TodoStore
- `.test-skills-*/` ticket 02 SkillRegistryTests temp directory
- v0.18 ticket 05 commit `2172c421c` (KanbanStore) + 06 commit `4551ce0af` (TodoStore) + 02 commit `b5c219f3b` (SkillRegistry) left temp files when running tests