# Spec — Hermes 核心能力复刻 (扩展: 多 agent + A2A 协议 + 全模块, 老板 2026-08-19 拍)

> Date: 2026-08-19
> 老板 2026-08-19 拍 "文枢需要多 agent 需要 a2a 协议, 除了 hermes 前端, 服务端默认接入一些国外不适用的平台和工具以外, 都要复刻"
> 老板 2026-08-19 19:55 拍 "工程管理你自行决策" + 19:57 拍 "不需要验收"
> 真值源: /Volumes/ANAN/.hermes/ (read-only, 不动 hermes)

## Problem Statement

老板 2026-08-19 19:55+ 拍 wenshu 扩展需求:
1. **多 agent** = wenshu 之前是单 agent 桌面 app, 现在要支持多个 agent 协作
2. **a2a 协议** = Agent-to-Agent 通信协议, 让多个 agent 互相发消息 (Google A2A spec 真值: json-rpc over http)
3. **全模块复刻** = 除了 hermes 前端 + 服务端默认接入的国外不适用的平台/工具 (GitHub / Slack / Telegram / Discord / iMessage / WhatsApp / DingTalk / WeWorkMac 等), 都要复刻

## Solution (老板 8/19 拍 + 我拍技术路径)

按 "全模块复刻" + "a2a + 多 agent" 拍:
1. **A2A 协议** (新): wenshu 内置 A2A 协议 (JSON-RPC over HTTP), agent 之间互相发消息
2. **多 agent runtime** (新): wenshu 支持多 agent 进程 (类似 hermes gateway spawn worker)
3. **本地 MemoryStore** (ticket 01 ✅ done): mem0 复刻
4. **SkillRegistry** (ticket 02 待): skills_hub 简化版
5. **Kanban** (ticket 03+ 待): kanban.py + kanban_db.py + kanban_decompose.py 复刻
6. **Cron** (ticket 04+ 待): cron.py 复刻 (macOS LaunchAgent 已替代, 但 wenshu 内需要)
7. **Profile** (ticket 05+ 待): profiles.py + profile_distribution.py 复刻
8. **Todo / goals** (ticket 06+ 待): todos.py + goals.py 复刻
9. **Auth** (ticket 07+ 待): auth.py + auth_commands.py 复刻 (本地 keychain, 不依赖 hermes keychain)
10. **Backup / migration** (ticket 08+ 待): backup.py + migrate.py 复刻
11. **Session export** (ticket 09+ 待): session_export*.py 复刻 (markdown / html)
12. **Fallback / auth rotation** (ticket 10+ 待): fallback_cmd.py + fallback_config.py 复刻 (本地优先级表)

### 跳过 (老板 8/19 拍)

按 "国外不适用的平台和工具":
- ⏭ github (gateway_enroll.py + pairing.py)
- ⏭ slack (slack_cli.py)
- ⏭ telegram (telegram_managed_bot.py)
- ⏭ wework_mac (wework_mac / tencent_wework)
- ⏭ dingtalk (dingtalk_auth.py)
- ⏭ whatsapp (setup_whatsapp_cloud.py)
- ⏭ imessage (imessage 在 apple native)
- ⏭ onepassword_secrets_cli (1password integration)
- ⏭ hermes_link (Hermes Link iOS app — 老板 8/11 拍 'Hermes Link 不值得')
- ⏭ hermes_pilot (老板 8/11 拍)

## User Stories

1. As 老板, I want wenshu 支持多 agent 协作 (主 agent + sub-agent)
2. As 老板, I want wenshu agent 之间用 A2A 协议通信 (JSON-RPC over HTTP, Google A2A spec 真值对齐)
3. As 老板, I want hermes 核心能力本地复刻 (除了前端 + 国外平台)
4. As 老板, I want wenshu 不依赖 hermes (本地 SQLite + 本地 skills + 本地 kanban + 本地 cron + etc.)

## Implementation Decisions (老板 8/19 拍 + 我拍技术)

按 4 原则 1 伪 Apple 官方 + Apple HIG 真值 + 大神方法论 35 skill workflow + 工作量大但稳:

### A2A 协议真值 (Google A2A spec 真值)

- JSON-RPC 2.0 over HTTP(S) (Apple Network 真值: URLSession)
- Agent Card: agent metadata (skills / capabilities / endpoint)
- Task: 长期异步任务 (agent 发给另一个 agent, 等回复)
- Message: agent 之间即时消息
- Artifacts: agent 输出物 (file / data)

### 多 Agent Runtime 真值

- Agent process: 1 个 Swift process 内多 actor (actor isolation 保证 thread safety)
- Agent registry: 1 个全局 registry 注册 / 找 agent
- Message broker: A2A protocol over local HTTP (127.0.0.1:port) 或 in-process actor message passing
- Lifecycle: spawn / message / wait / kill

### Skills Hub 真值 (复刻 hermes skills_hub.py 35 do_*)

按 "工作量中等 + 复刻价值高" 拍 — 简化版:
- ✅ scan: 扫本地 SKILL.md
- ✅ load: 拿 SKILL.md 内容 + parse frontmatter
- ⏭ browse / install / update / uninstall: future (跟 hermes hub 同接口, 但本地实现)

### Kanban 真值 (复刻 hermes kanban*.py)

按 "工作量中等 + 复刻价值高" 拍:
- ✅ SQLite-backed cards / lists / relations
- ✅ State machine: new → triage → ready → running → blocked → review → done
- ⏭ workflow DSL: future (当前 ticket 不实现 workflow YAML)

## User Stories 拍

按上面"全模块复刻"清单:

| 编号 | ticket | 复刻什么 | 优先级 |
|---|---|---|---|
| 01 | 本地 SQLite 记忆 | MemoryStore.swift (mem0 接口) | ✅ done |
| 02 | 本地 Skills 加载 | SkillRegistry.swift (skills_hub 简化版) | 🔥 next |
| 03 | A2A 协议 | AgentProtocol.swift (JSON-RPC over HTTP, A2A spec 真值) | 🔥 next |
| 04 | 多 Agent Runtime | AgentRuntime.swift (actor + registry + message broker) | 🔥 next |
| 05 | 本地 Kanban | KanbanStore.swift (kanban_db.py 复刻) | 🟡 medium |
| 06 | 本地 Todo / Goals | TodoStore.swift + GoalsStore.swift | 🟡 medium |
| 07 | 本地 Profile | ProfileRegistry.swift (profiles.py 简化版) | 🟡 medium |
| 08 | 本地 Auth (keychain) | AuthStore.swift (auth.py 简化版, 本地 keychain) | 🟡 medium |
| 09 | 本地 Cron (LaunchAgent) | CronStore.swift (cron.py 简化版, macOS LaunchAgent 集成) | 🟡 medium |
| 10 | 本地 Backup / Migration | BackupManager.swift (backup.py 复刻) | 🟢 low |
| 11 | 本地 Session Export (markdown / html) | SessionExporter.swift | 🟢 low |
| 12 | 本地 Fallback (auth rotation) | FallbackManager.swift | 🟢 low |
| 13 | Integration Tests | WenshuCoreIntegrationTests.swift | 🟢 low |
| 14 | Domain Modeling | CONTEXT.md 加 A2A + Agent runtime + Kanban + etc domain words | 🟢 low |

## Testing Decisions

- 每个 ticket 跑 swift build clean + 单元测试
- 老板 8/19 19:57 拍 "不需要验收" — 不提交截图证据
- 跑完一次性 commit + push (老板 8/19 19:55 工程管理授权)

## Out of Scope

- 不动 hermes app / /Volumes/ANAN/.hermes/ 任何文件 (老板 8/11 拍 'hermes 不动')
- 不复刻 hermes 前端 (TUI / Web UI / GUI)
- 不复刻国外不适用的平台 / 工具 (github / slack / telegram / wework_mac / dingtalk / whatsapp / onepassword / hermes_link / hermes_pilot)
- 不实现 A2A 协议的 server-side discovery / federation (跟 Google A2A 完整 spec 不对齐, wenshu 本地足够)

## Further Notes

- 老板 8/19 19:55+ 拍 "a2a + 多 agent + 全模块" 是 "扩展 ticket 01 MemoryStore" 的方向
- 老板 8/19 19:55 拍 "工程管理你自行决策" — 我自己拍 ticket 列表 + 实施
- 老板 8/19 19:57 拍 "不需要验收" — 不提交截图证据, 跑 po main flow 完整 + commit + push
- 按 4 原则 3 工作量大但稳 — 14 ticket 串行实施, 每个 ticket 走完整 po main flow 6 步
- 真正值参考:
  - Google A2A spec: https://github.com/google/A2A
  - Apple Network 真值: https://developer.apple.com/documentation/foundation/urlsession
  - Apple Actor 真值: https://developer.apple.com/documentation/swift/actor
  - SQLite 真值: https://developer.apple.com/documentation/sqlite
  - hermes 真值: /Volumes/ANAN/.hermes/hermes_cli/ (read-only)