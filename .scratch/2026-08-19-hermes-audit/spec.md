# Hermes 核心能力盘查报告 (限定复刻范围 = mem0 + skills)

> Date: 2026-08-19
> 老板 2026-08-19 拍 "盘一下 hermes 代码, 评估那些要复刻"
> 真值源: /Volumes/ANAN/.hermes/hermes_cli/ (read-only, 不动 hermes)

## 范围 (Q35 自拍 B, 老板 8/19 19:55 工程管理授权)

只盘 mem0 + skills 2 件:
1. **memory_*.py** (memory_providers / memory_setup / memory_oauth)
2. **skills_*.py** (skills_config / skills_hub)

不盘 hermes 全 148 module (其他 143 module: kanban / cron / profile / setup / gateway / etc — 跟当前 ticket 无关).

## 真值 (Hermes 源码直接读)

### 1. mem0 真值 — memory_providers.py (149 lines)

```
class MemoryProvider:    # L69 - 抽象 provider 类 (base class)
def get_memory_provider(name: str) -> MemoryProvider | None:    # L146 - 真值接口
```

**接口真值**:
- `MemoryProvider` 类是抽象, 各 provider 实现 (mem0_platform / mem0_oss / etc.)
- `get_memory_provider(name)` = 真值: 拿 provider 实例, name 真值: "mem0_platform" / "mem0_oss" / "custom"

**真值接口**:
- provider.search(query, user_id) -> list[Memory]
- provider.add(content, user_id) -> Memory
- provider.delete(memory_id)
- (provider 实际包 mem0 SDK)

### 2. mem0 真值 — memory_setup.py (501 lines)

```
def cmd_setup(args) -> None:    # L237 - 真值 CLI command
def cmd_status(args) -> None:    # L417 - 状态查询
def memory_command(args) -> None:    # L489 - 顶级 CLI dispatch
```

**真值 CLI 命令**: `hermes memory setup` / `hermes memory status` / `hermes memory add "..."` / `hermes memory search "..."`

### 3. skills 真值 — skills_config.py (183 lines)

```
def get_disabled_skills(config: dict, platform) -> Set[str]    # L27
def _list_all_skills() -> List[dict]    # L58 - 真值: 列所有 skill
def _toggle_by_category(skills, disabled) -> Set[str]    # L100
def skills_command(args=None)    # L131 - 真值 CLI
```

### 4. skills 真值 — skills_hub.py (1997 lines, 35 do_* 函数)

**完整 skill 生命周期** (35 函数真值):

| 阶段 | 函数 | 行 |
|---|---|---|
| 搜索 | `do_search(query, source, limit)` | L262 |
| 浏览 | `do_browse(page, page_size, source)` | L331 |
| 安装 | `do_install(identifier, category, force)` | L502 |
| 检查 | `do_inspect(identifier)` | L771 |
| 列表 | `do_list(source_filter)` | L908 |
| 验证 | `do_check(name)` | L1007 |
| 更新 | `do_update(name)` | L1030 |
| 审计 | `do_audit(name)` | L1050 |
| 卸载 | `do_uninstall(name)` | L1096 |
| 复位 | `do_reset(name, restore)` | L1131 |
| 改列 | `do_list_modified()` | L1176 |
| diff | `do_diff(name)` | L1204 |
| opt-out | `do_opt_out(remove)` | L1243 |
| opt-in | `do_opt_in(sync)` | L1313 |
| 修复 | `do_repair_official(name, restore)` | L1344 |
| tap | `do_tap(action, repo)` | L1386 |
| 发布 | `do_publish(skill_path, target, repo)` | L1429 |
| snapshot | `do_snapshot_export` | L1595 |
| inspect api | `browse_skills(page, page_size, source) -> dict` | L821 |
| inspect api | `inspect_skill(identifier) -> Optional[dict]` | L870 |

## wenshu 当前实现对照 (已经 commit 047b43cfa ticket 01)

### 1. MemoryStore.swift vs hermes MemoryProvider

| 字段 | hermes 真值 | wenshu 当前 (MemoryStore.swift) | 差异 |
|---|---|---|---|
| 接口 | `search(query, user_id)` | `search(userId, query, limit)` | 命名顺序不同 — hermes query first, wenshu userId first |
| 接口 | `add(content, user_id)` | `add(userId, content)` | 同上 |
| 接口 | `delete(memory_id)` | `delete(memoryId)` | 同上 |
| 存储 | mem0 SDK (云 + 本地) | SQLite (本地) | 实现不同 |
| threading | sync | actor (Swift 6 strict) | wenshu 更现代 |
| schema | mem0 opaque | memories 表 (user_id / memory_id / content / created_at / updated_at) | wenshu 自己定 |
| bootstrap | sdk.init() | `bootstrap()` 建表 | 同 |

**差距**:
- 命名顺序: hermes `(content, user_id)` vs wenshu `(userId, content)` — 可接受差异
- 接口: wenshu 缺 `delete_all(userId)` / `count(userId, query)` 聚合接口
- backend: wenshu SQLite 本地 vs hermes mem0 SDK (云 + 本地) — wenshu 仅本地

### 2. SkillRegistry.swift (待 ticket 02)

未实现, plan: 模仿 hermes skills_hub.py 真值接口 + skills_config.py 真值配置。

## 复刻优先级评估

按 "工作量中等 + 复刻价值高" 拍:

| 模块 | hermes 真值 | wenshu 状态 | 复刻价值 | 工作量 |
|---|---|---|---|---|
| MemoryProvider (mem0) | memory_providers.py 149 lines | MemoryStore.swift 已 commit | 🟢 高 | 已 done |
| Memory CLI | memory_setup.py 501 lines | N/A | 🟡 中 (SwiftUI 不需要 CLI) | skip |
| SkillRegistry | skills_hub.py 35 do_* 函数 + skills_config.py | N/A | 🟢 高 (复刻 hermes skills 35 个能力) | 中 (ticket 02) |
| Skill CLI | skills_hub.py CLI 部分 | N/A | 🟡 中 | skip |
| Skill Hub browse/install | skills_hub.py L262 / L502 | N/A | 🟡 中 (SwiftUI 不需要 hub) | skip |
| Kanban | kanban*.py 5 module | N/A | 🟡 中 (后续 ticket 考虑) | 大 (skip for now) |
| Cron | cron.py | N/A | 🟢 中 (macOS LaunchAgent 已替代) | skip |
| Profile | profiles.py | N/A | 🟡 中 (pocock profile 已替代) | skip |
| Setup | setup.py + setup_whatsapp_cloud.py | N/A | 🟡 中 (pocock 手动替代) | skip |

## 建议下一步

按 "工作量中等 + 效果优先":

1. ✅ **done**: MemoryStore (ticket 01)
2. ⏭ **next**: SkillRegistry (ticket 02) — 35 do_* 函数简化版, 拿 SKILL.md + parse frontmatter + load()
3. **skip**: hermes CLI 全套 (SwiftUI app 不需要 CLI)
4. **future**: Kanban / Cron / Profile (后续 ticket 排期)

## 真值引用

- /Volumes/ANAN/.hermes/hermes_cli/memory_providers.py (149 lines, hermes mem0 真值接口)
- /Volumes/ANAN/.hermes/hermes_cli/memory_setup.py (501 lines, hermes mem0 CLI 真值)
- /Volumes/ANAN/.hermes/hermes_cli/skills_config.py (183 lines, hermes skills config 真值)
- /Volumes/ANAN/.hermes/hermes_cli/skills_hub.py (1997 lines, hermes skills hub 真值 35 do_* 函数)

## 不动 hermes (老板 8/11 拍)

- read-only 盘代码
- 不修改 /Volumes/ANAN/.hermes/ 任何文件
- 不 patch /Volumes/ANAN/.hermes/hermes_cli/ 任何 .py