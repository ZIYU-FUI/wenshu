# 01 — Hermes 核心能力盘查报告 (限定复刻范围 = mem0 + skills)

**What to build:**
老板 2026-08-19 拍 "盘一下 hermes 代码, 评估那些要复刻". 工程管理授权 (老板 8/19 19:55) + 不需要验收 (老板 8/19 19:57).

改完:
- 读 hermes 真值源码 (read-only, 不动 hermes)
- 拼盘查报告 (范围 = mem0 + skills)
- 拍复刻优先级 + 建议下一步

**Blocked by:** None

**Status:** done — spec 在 .scratch/2026-08-19-hermes-audit/spec.md

## 真值 (Hermes 源码 read-only)

- /Volumes/ANAN/.hermes/hermes_cli/memory_providers.py 149 lines
- /Volumes/ANAN/.hermes/hermes_cli/memory_setup.py 501 lines
- /Volumes/ANAN/.hermes/hermes_cli/skills_config.py 183 lines
- /Volumes/ANAN/.hermes/hermes_cli/skills_hub.py 1997 lines (35 do_* 函数)

## 复刻评估 (推荐)

| 优先级 | 模块 | 状态 |
|---|---|---|
| ✅ done | MemoryStore (mem0) | ticket 01 commit 047b43cfa |
| ⏭ next | SkillRegistry (skills_hub 简化版) | ticket 02 待拍 |
| skip | mem0 CLI / skills CLI / skills Hub browse-install | SwiftUI app 不需要 CLI |
| future | Kanban / Cron / Profile | 后续 ticket 排期 |

## wenshu 当前 vs hermes 真值 对照

- MemoryStore.swift (wenshu) vs MemoryProvider (hermes): 命名顺序差异 + backend (SQLite vs mem0 SDK) + 缺 delete_all / count 聚合
- SkillRegistry: 未实现, plan 模仿 hermes skills_hub.py 真值

## 业务语言描述 (老板懂)

- hermes 核心能力按模块盘完
- 复刻优先级: mem0 + skills 是高价值, kanban / cron / profile 是 future
- wenshu MemoryStore 已 done, SkillRegistry 待 ticket 02

## 不动 hermes (老板 8/11 拍)

- read-only 读源码
- 不修改 /Volumes/ANAN/.hermes/