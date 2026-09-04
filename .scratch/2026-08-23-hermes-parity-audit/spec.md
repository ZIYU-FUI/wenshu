# Audit report — wenshu hermes-replica vs hermes-agent source

> Boss 2026-08-23 拍: '对比一下 hermes 的, 我们已经复刻的模块, hermes 怎么写的,
> 解决方案是什么样的, 看我们有没有什么没有考虑到的场景, 或者我们写值得借鉴的技术设计'.

## Method

1. Clone hermes source: `git clone --depth 1 https://github.com/NousResearch/hermes-agent` to `/tmp/hermes-agent`
2. Map each wenshu hermes-replica source file → hermes Python file
3. Read hermes Python file's class structure + key design decisions
4. Diff: what wenshu has, what wenshu misses, what wenshu does differently

## Files compared

| wenshu (Swift) | hermes (Python) | LOC |
|---|---|---|
| `MemoryStore.swift` | `tools/memory_tool.py` | 1394 |
| `SkillRegistry.swift` | `tools/skills_hub.py` | 4674 |
| `KanbanStore.swift` | `tools/kanban_tools.py` | 2480 |
| `TodoStore.swift` | `tools/todo_tool.py` | 365 |
| `Cronjob.swift` | `tools/cronjob_tools.py` | 1871 |
| `Backup.swift` | (find similar) | — |
| `FileTools.swift` | `tools/file_tools.py` | 2812 |
| `ProcessTools.swift` | `tools/terminal_tool.py` | 3942 |
| `WebTools.swift` | `tools/url_fetch*.py` | (find) |
| `VisionTools.swift` | `tools/vision*.py` | (find) |
| `AVMediaTools.swift` | `tools/audio*.py` | (find) |
| `WenshuConductor.swift` | `agent/agent_init.py` + `run_agent.py` | (find) |
| `AgentProtocol.swift` | `agent/agent_protocol.py` | (find) |
| `AgentRuntime.swift` | `tools/async_delegation.py` + `delegate_tool.py` | (find) |

---

## Gap analysis (10 distinct gaps found)

### Gap 1: Memory write has NO approval gate

**Hermes pattern** (`tools/memory_tool.py:949` `_apply_write_gate`):
```python
def _apply_write_gate(action, target, content, old_text):
    if action not in {"add", "replace", "remove"}:
        return None
    decision = wa.evaluate_gate(wa.MEMORY, inline_summary=..., inline_detail=...)
    if decision.allow: return None  # write
    if decision.blocked: return tool_error(...)  # blocked
    # else: stage for approval — write to pending queue, await user confirm
    return json.dumps({"success": True, "staged": True, "pending_id": ...})
```

**wenshu current**: `MemoryStore.add()` 直接写 SQLite, no gate. **Sub-agent / main agent 都能 add memory, 无 approval**.

**Boss scenario 老板想到的** (8/23 '去 hermes 扒'): memory write 是 sensitive 操作, 应该 user approve。

**Recommendation**: 加 `MemoryWriteGate` (analogous to hermes `_apply_write_gate`). Main agent 写 memory 也要过 gate (user sees pending memory before commit)。

**Priority**: HIGH (boss 8/23 security)

---

### Gap 2: Memory has no char budget / consolidation failure tracking

**Hermes pattern** (`tools/memory_tool.py`):
- `memory_char_limit = 2200` (general memory)
- `user_char_limit = 1375` (user profile)
- `_consolidation_failure` counter — `MAX_CONSOLIDATION_FAILURES_PER_TURN = 3` (防 memory call loop)
- `reset_consolidation_failures()` — called at turn start
- **`_system_prompt_snapshot` frozen at load** — keep prefix cache stable

**wenshu current**: `Memory` struct 没有 char limit. Memory 无限增长 (no cap). No consolidation. Snapshot 不冻结 (每次 send 都重新生成 system prompt + memory)。

**Boss scenario**: 老板用 wenshu 1 年 → memory 100k chars → 每个 LLM call 都把 memory 全塞 context → 慢 + 贵。

**Recommendation**: 
1. 加 `MemoryStore.maxChars: Int = 2200` (同 hermes)
2. 加 `consolidation` 逻辑: 当 memory 接近 limit, 自动 summarize / drop older
3. `_system_prompt_snapshot` 冻结 (cache-stable)

**Priority**: MEDIUM (perf 优化)

---

### Gap 3: Skill has no trust level / source / quarantine

**Hermes pattern** (`tools/skills_hub.py`):
```python
@dataclass
class SkillMeta:
    name: str
    source: str           # "official" | "github" | "clawhub" | "lobehub"
    trust_level: str      # "builtin" | "trusted" | "community"
    identifier: str       # source-specific ID
    ...
```

Plus: `quarantine/` dir, `audit_log`, `lock_file`, `taps_file`, `index_cache_dir`. 隔离 + 审计 + 锁。

**wenshu current**: `SkillRegistry` 只有 `list / load / invoke`, 没有 trust level, 没有 source, 没有 quarantine。

**Boss scenario**: 老板想装一个新 skill (e.g. 'wuxia-style-writer')。 wenshu 没机制评估 skill 来源, 直接加载所有 .md 文件 → 风险。

**Recommendation**: 加 `SkillMeta` struct (trust_level: builtin / trusted / community) + quarantine + audit log。

**Priority**: MEDIUM (future feature)

---

### Gap 4: Kanban missing priority / tenant / workspace / created_by metadata

**Hermes pattern** (`tools/kanban_tools.py:485` `_task_summary_dict`):
- `id / title / assignee / status / priority / tenant / workspace_kind / workspace_path / project_id / created_by / created_at / started_at / completed_at / current_run_id / model_override / provider_override / parents / children`

**wenshu current**: `KanbanTask` 只有 `id / title / status / updatedAt`。严重信息缺失。

**Boss scenario**: 老板周一 review 时问 "上周四 writer 任务跑了多久?用的什么 model?" — wenshu 答不出 (没 started_at / completed_at / model_override)。

**Recommendation**: 扩展 `KanbanTask` schema 加 priority / assignee / started_at / completed_at / model_override 等。 **DB migration** needed (sqlite ALTER TABLE)。

**Priority**: HIGH (boss 需要观测能力)

---

### Gap 5: Kanban missing orchestrator vs worker role distinction

**Hermes pattern** (`tools/kanban_tools.py:467`):
```python
def _require_orchestrator_tool(tool_name):
    """Belt-and-suspenders runtime guard for orchestrator-only handlers."""
    if os.environ.get("HERMES_KANBAN_TASK"):
        return tool_error(f"{tool_name} is orchestrator-only; dispatcher-spawned workers must use kanban_complete, kanban_block, kanban_heartbeat, or kanban_comment")
```

**Workers** (sub-agents): can only `kanban_complete / kanban_block / kanban_heartbeat / kanban_comment`
**Orchestrators** (main agent): can `kanban_create / kanban_request_review / etc.`

**wenshu current**: `WenshuConductor.handle()` step 1 创建 `conductor:` task, sub-agents 创建 sub-task。**没有 role check** — sub-agent 理论上能 update 任何 task。

**Boss scenario**: sub-agent bug → modify 主 agent 的 conductor task → 状态错乱。

**Recommendation**: 加 `WenshuConductor.currentRole: .main / .subAgent(name:)` state + guard at `KanbanStore.add` / `.transition` calls。

**Priority**: MEDIUM (defense in depth, 跟 Gap 6 一起做)

---

### Gap 6: File tools missing /dev/stdin, /proc, symlink hop protection

**Hermes pattern** (`tools/file_tools.py:520`):
```python
def _is_blocked_device_path(path):
    """Block /dev/stdin, /proc/*/environ, /proc/*/maps, /proc/*/mem"""
    if normalized in _BLOCKED_DEVICE_PATHS: return True
    if normalized.startswith("/proc/") and normalized.endswith(
        ("/fd/0", "/fd/1", "/fd/2", "/environ", "/cmdline", "/maps",
         "/smaps", "/auxv", "/pagemap", "/mem")):
        return True
```

Plus: **`_is_blocked_device`** follows symlink hops (defense in depth)。

**wenshu current**: `FileTools.pathDenied` 只查 prefix/suffix 列表 (Sources / Tests / .scratch / etc.)。**不**防:
- /dev/stdin (can hang reads)
- /proc/self/maps (memory layout leak — ASLR bypass)
- /proc/self/environ (env vars leak)
- Symlink 绕 (e.g. /tmp/foo → /etc/shadow)

**Boss scenario**: boss 在 chat 让 agent "读 /proc/self/environ 看 env" — wenshu 当前允许 (没 deny), leaks API keys 等 secrets。

**Recommendation**: 加 `FileTools.isBlockedDevice(path)` 检查 /dev/* + /proc/* paths + 跟踪 symlink hop。

**Priority**: HIGH (security gap)

---

### Gap 7: Process tools using approval gate vs deny-all

**Hermes pattern** (`tools/terminal_tool.py:288`):
```python
def set_approval_callback(cb):
    """Register a callback for dangerous command approval prompts."""
    _callback_tls.approval = cb
```

Sub-agents / workers 跑 dangerous commands (e.g. `rm -rf /`) 走 approval flow, **不是** deny-all。 Safe commands (`ls`, `cat file.txt`) 直接跑。

**wenshu current**: `ProcessTools.runShell` **完全 deny** (boss 8/23 拍 "禁止通过聊天改系统")。 优点: 安全。 缺点: 任何 shell 都不行 (连 `ls` 都不行), 限制 sub-agent 能力。

**Trade-off**:
- 当前 deny-all: 保守, 防 boss 担心
- Hermes selective: 灵活, 但需要 approval UI

**Recommendation**: 保持 deny-all, 但加 `runReadOnlyShell(command)` for read-only commands (whitelist: `ls / wc / cat / grep / head / tail / find / stat / file`)。

**Priority**: LOW (当前 deny-all 是合理选择, 留 v0.24+ 评估)

---

### Gap 8: Cron job missing prompt injection scan

**Hermes pattern** (`tools/cronjob_tools.py:260`):
```python
def _scan_cron_prompt(prompt: str) -> str:
    """Detect invisible unicode / emoji ZWJ sequences in cron prompts."""

def _check_invisible_unicode(prompt: str) -> str:
    """Block: ZWJ, RLO, RTL, zero-width chars (prompt injection vectors)"""

def _scan_cron_skill_assembled(assembled: str) -> tuple[str, str]:
    """Scan full assembled cron prompt + skill body for injection chars."""
```

**wenshu current**: `Cronjob` 没 prompt injection scan。 Sub-agent 可以 schedule cron job with invisible-unicode payload (e.g. ZWJ char that LLMs sometimes ignore)。

**Boss scenario**: 老板问 "每晚 10 点提醒我写 1000 字" → sub-agent 把 cron prompt 加 ZWJ chars 让 LLM 执行 hidden instruction。

**Recommendation**: 加 `Cronjob.validatePrompt(_:)` 调用 `_scan_cron_prompt` + `_check_invisible_unicode`。

**Priority**: MEDIUM (security, 不 urgent if no cron schedule UI yet)

---

### Gap 9: Memory manager missing pre-turn prefetch + post-turn sync pattern

**Hermes pattern** (`agent/memory_manager.py`):
```python
class MemoryManager:
    def __init__(self, *, external_prefetch_timeout=8.0):
        self._external_prefetch_threads = {}

    def prefetch_all(self, user_message) -> Dict[str, str]:
        """Pre-turn: load relevant memory into context."""
        ...

    def sync_all(self, user_msg, assistant_response) -> None:
        """Post-turn: persist new info to memory."""
        ...

    def queue_prefetch_all(self, user_msg) -> None:
        """Async background prefetch (next-turn optimization)."""
        ...
```

**wenshu current**: `WenshuConductor.handle()` 没 memory pre-turn prefetch / post-turn sync。 Memory 只是 1 line summary 写到 SQLite (`recordSubAgentRun`) — 不是真正的 memory。

**Boss scenario**: 老板说 "我之前说过主角是孤儿" → agent 不记得 → 需要 prompt 全 memory。 wenshu 现在每次 send 都 send 完整 messages 数组 (sqlite 加载), 没 relevance ranking。

**Recommendation**: 加 `MemoryManager.prefetch(userMessage)` 阶段 — 每次 send 前 pre-rank 相关 memories (用 keyword search or embedding), 只 feed top-N。 `sync_all(userMsg, assistantReply)` 阶段 — auto-detect 重要 info 存 memory (替代 manual `recordSubAgentRun`)。

**Priority**: HIGH (boss 真实痛点 — "我之前说过 X" 是高频场景)

---

### Gap 10: Agent loop missing async delegation / background

**Hermes pattern** (`tools/async_delegation.py`):
```python
_DEFAULT_MAX_ASYNC_CHILDREN = 3
_MAX_RETAINED_COMPLETED = 50
_DURABLE_RETENTION_SECONDS = 7 * 24 * 60 * 60
_MAX_DURABLE_PENDING = 1000
```

`delegate_task(background=true)` 立即返回 handle, sub-agent 在 daemon thread 跑, 完成时 push 到 completion queue。 Parent 继续接 user msg。

**wenshu current**: `WenshuConductor.handle()` 是同步 — `await withTaskGroup` 等所有 sub-agent 完才返。 User 不能中间插嘴。

**Boss scenario**: 老板说 "帮我查 1920-1940 年北京的物价" → 这可能要 5 分钟。 wenshu 当前会卡住 5 分钟。 hermes 用户可以中间继续聊, 5 分钟后结果自动注入。

**Recommendation**: 加 `WenshuConductor.handleAsync(...)` 返回 handle, sub-agent 在 background TaskGroup 跑, 完成时 post NotificationCenter, ChatView 监听 append。 **Priority**: MEDIUM (nice-to-have)。

---

## Inspiration (hermes patterns wenshu already adopted well)

✅ **DELEGATE_BLOCKED_TOOLS** (ticket 012 抄了) — sub-agent permission boundary。
✅ **tool allowlist / deny-list** (ticket 008 抄了) — path safety。
✅ **multi-agent TaskGroup parallel** (ticket 002 抄了) — 跟 hermes ThreadPoolExecutor 等价。
✅ **memory / skill / kanban 拆 module** (v0.18 抄了) — hermes modular layout。

## Recommendation priority order

| # | Gap | Priority | Effort | Why |
|---|---|---|---|---|
| 1 | Memory approval gate | **HIGH** | S (1 ticket) | boss 8/23 security concern |
| 2 | /proc + /dev + symlink hop | **HIGH** | S (1 ticket) | secrets leak risk |
| 3 | Kanban metadata schema | **HIGH** | M (DB migration) | boss 观测需求 |
| 4 | Memory char budget + consolidation | MED | M (2 tickets) | long-term perf |
| 5 | MemoryManager prefetch + sync | MED | M (refactor) | "我之前说过 X" 场景 |
| 6 | Cron prompt injection scan | MED | S (1 ticket) | cron UI 上线时必需 |
| 7 | Skill trust level + quarantine | MED | L (新功能) | boss skill 管理 UI |
| 8 | Kanban role distinction | MED | S (1 ticket) | defense in depth |
| 9 | Async delegation | LOW | L (大改动) | nice-to-have |
| 10 | Process shell selective | LOW | M (refactor) | 当前 deny-all OK |

## Boss decision

老板拍哪个先做。建议从 **Gap 1 + 2 + 3** 开始 (HIGH priority, security + observability):
- Gap 1 (memory approval): S effort, 1 ticket
- Gap 2 (file safety): S effort, 1 ticket
- Gap 3 (kanban schema): M effort, 1-2 tickets (DB migration + tests)

Total: 3-4 commits, ~50 lines of code changes + 1 DB migration。

---

*Spec v0.1 · 2026-08-23 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/`*