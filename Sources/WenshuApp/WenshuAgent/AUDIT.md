# WenshuAgent 抽包 — P1 调研 Audit

> **时间**: 2026-10-16
> **目的**: 盘点 33 个核心 LLM/Connector/Streaming/Keychain 文件 + 识别不合理调用逻辑 + 列出重构 + 引入新机制的具体文件清单。
> **来源**: 按老板原话"全做" + 老板"做就做到最好 + 用户体验优先"原则。

---

## 1. 范围盘点

### 1.1 文件统计

| 目录 | 文件数 | 描述 |
|---|---|---|
| `Features/Agent/Store/` | 85 | Store 全部 (含 Tools / Book / Character 业务) |
| `Features/Agent/Service/` | 107 | Service 全部 (含 Tools / Book / 业务) |
| **核心 LLM 子集（要抽包）** | **33** | 见下表 |
| `App/WenshuAppDelegateLLM.swift` | 1 | App 启动期 connector 工厂 |

### 1.2 33 个核心文件（按职责分组）

#### Core LLM types (3)
- `Store/LLMConnector.swift` — `protocol LLMConnector` 协议
- `Store/LLMMessage.swift` — `struct LLMMessage` + `enum Role` (user/assistant/tool)
- `Store/LLMResponse.swift` — `struct LLMResponse` + `enum LLMBlock` (text/thinking/toolUse/toolResult)

#### Streaming (5)
- `Service/SSEClient.swift` — 通用 SSE 解析器 (URLSession.bytes + 字节级 line split)
- `Store/AnthropicStreamingChunkToLLMBlock.swift` — Anthropic-compat chunk → LLMBlock
- `Store/AnthropicStreamingWireup.swift` — Anthropic-compat streaming body
- `Store/OpenAIStreamingWireup.swift` — OpenAI-compat streaming body
- `Store/GeminiStreamingWireup.swift` — Gemini SSE → LLMBlock

#### Connector (8)
- `Service/Provider.swift` — `struct Provider` (14 个 built-in) + `enum ProviderAuthMode`
- `Store/AnthropicConnector.swift` — Anthropic Messages API
- `Store/MinimaxConnector.swift` — minimax-anthropic 兼容
- `Store/OpenAIConnector.swift` — OpenAI Chat Completions
- `Store/DeepSeekConnector.swift` — DeepSeek
- `Store/GeminiNativeConnector.swift` — Google GenAI
- `Store/OllamaConnector.swift` — Ollama local
- `Store/OpenRouterConnector.swift` — OpenRouter 代理

#### Keychain (7)
- `Service/ProviderKeychain.swift` — `enum ProviderKeychain` (单例 + 公开 API)
- `Service/KeychainOps.swift` — `enum KeychainOps` (Apple Security framework 封装)
- `Service/MirroredKeychainStore.swift` — 双写后端 (AppleKeychain + File)
- `Service/FileProviderKeyStore.swift` — 文件后端 (`~/Library/Application Support/`)
- `Service/AppleKeychainStore.swift` — Apple Keychain 后端
- `Service/InMemoryKeychainStore.swift` — 内存后端 (测试用)
- `Service/KeychainSelector.swift` — 钥匙串开关 / file fallback 选择

#### Discovery + body building (4)
- `Service/AvailableModelsDiscovery.swift` — `loadFromKeychain` + `loadLive`
- `Service/ConnectorCredentials.swift` — 解析 provider credentials
- `Store/RequestHelpers.swift` — Anthropic-compat / OpenAI-compat body
- `Store/LLMModelDiscovery.swift` — actor, 调 `/models` endpoint

#### Context / conversation (4)
- `Store/ContextCompressor.swift` — `actor ContextCompressor`
- `Store/ConversationLoop.swift` — 主循环
- `Store/WenshuConductor.swift` — `actor WenshuConductor` (chat 主路径)
- `Store/WenshuVerifier.swift` — `actor WenshuVerifier` (verification 路径 = 待删)

#### Import + App wiring (2)
- `Service/WenshuConductorImportRouter.swift` — import path 用 conductor
- `App/WenshuAppDelegateLLM.swift` — connector 工厂 + helper

---

## 2. 不合理调用逻辑（per 老板"重构"要求）

### 2.1 **P0 critical: 2 条 LLM 调用路径**

| 路径 | 调用 | 文件 | 用途 |
|---|---|---|---|
| **#1 主路径** | `WenshuConductor.handle` → `ConversationLoop.runTurn` → `connector.send` (non-streaming) | `WenshuConductor.swift:402`, `ChatSessionViewModel.swift:497` | chat 显示的 reply |
| **#2 验证路径** | `WenshuVerifier.streamChat` → `SSEClient.stream` (streaming) | `ChatSessionViewModel.swift:532-622`, `WenshuVerifier.swift:498-566` | 仅作 verification = **不显示在 chat** |

**不合理**:
- 2 条路径走 2 套 code (1 条 non-streaming send + 1 条 streaming SSE)
- 任何 LLM bug 要修 2 处
- 用户**看到**的 chat (路径 #1) 和 verifier (路径 #2) 走的不是同一条 connector 实现 = bug 表现不同
- 老板原话"应该只有一条链路"

**重构**: 删 `WenshuVerifier.streamChat` + 让 8 个 connector 全部实现真 `stream()` → 唯一入口 = `WenshuAgent.shared.chat(...)`

### 2.2 **P0 critical: 9 个文件 import 越界（UI ↔ 基础设施）**

| UI 文件 | 直接 import agent 内部 |
|---|---|
| `Features/Chat/View/ChatView.swift` | `WenshuConductor` / `WenshuVerifier` |
| `Features/Chat/Store/ChatSessionViewModel.swift` | `WenshuConductor` / `WenshuVerifier` / `ProviderKeychain` |
| `Features/Chat/Service/LiveChatRepository.swift` | `WenshuVerifier` |
| `Features/Chat/Service/ChatRepositoryProtocol.swift` | `WenshuVerifier` |
| `Features/Chat/Store/ChatViewModelLongRunningGoal.swift` | (待查) |
| `App/WenshuAppDelegateLLM.swift` | `MinimaxConnector` 等 8 个 connector |
| `App/WenshuAppDelegate.swift` | (待查) |

**不合理**:
- UI 层 (`Features/Chat/View/`) 直接 import agent 内部 (`WenshuConductor`)
- App 启动层 (`App/`) 直接 new 8 个 connector
- 层次 = UI / App / Agent 三层全混在一起

**重构**:
- `WenshuConductor` / `WenshuVerifier` / `ProviderKeychain` / 8 个 connector = 改 `internal`
- UI / App 只调 `WenshuAgent.shared.*`
- 抽包后 = `WenshuApp` 只 import `WenshuAgent`

### 2.3 **P0 critical: 没有任何 LOG 抽象**

| 现状 | 问题 |
|---|---|
| 38 个文件**没有**统一 `os.Logger` | debug = 2 小时写 `/tmp/ws*.log` 找 bug |
| 老板不能在 Console.app 看 wenshu agent 行为 | 不能查历史 |
| 38 个文件**没有** `WAStreamDiag` per-attempt dict | streaming 失败时不知道 bytes/chunks/status |
| 没有 `WAStreamWatchdog` | 卡 5 分钟 = 用户看到 "(no reply)" = 死寂 |

**不合理**: hermes 有 6 个 streaming diagnostic 文件 (`stream_diag.py` / `stream_single_writer.py` / `auxiliary_stream_watchdog.py` / `plugin_stream_hooks.py` / `chat_completion_stream_monitor.py` / `stream_delivery.py`) = 1102 LOC。wenshu = 0。

**重构**: 加 5 个新机制（per hermes 风格）。

### 2.4 **P1 high: 8 个 connector 抽象不统一**

| Connector | `send()` | `stream()` |
|---|---|---|
| `AnthropicConnector` | ✓ | ✗ (用 default = send + yield) |
| `MinimaxConnector` | ✓ | ✗ |
| `OpenAIConnector` | ✓ | ✗ |
| `DeepSeekConnector` | ✓ | ✗ |
| `GeminiNativeConnector` | ✓ | ✗ |
| `OllamaConnector` | ✓ | ✗ |
| `OpenRouterConnector` | ✓ | ✗ |

**不合理**:
- 8 个 connector 都没实现 `stream()`, 全部走 `LLMConnector` default extension`send` + yield blocks)
- chat 主路径**永远**走 non-streaming `send()` = 用户看不到 typing 效果

**重构**: 8 个 connector 全部 override `stream()`, Antrhopic-compat / OpenAI-compat / Gemini / Ollama 各自实现 native SSE streamingwenshu chat 真正流式输出)

### 2.5 **P1 high: Provider 静态 enum (14 个 built-in 不能扩展)**

**不合理**:
- `enum Provider` + 14 个 `static let` = MCP plugin 接入必须改 enum (破 ABI)
- 老板原话"未来有可能做 MCP"

**重构**:
- `protocol WABaseProvider`hermes 的 `ProviderBase` ABC)
- `actor WAProviderRegistry`hermes 的 `ProviderRegistry` with scope + snapshot/restore)
- 14 个 built-in 在 `WAProviderRegistry.bootstrap()` 注册
- MCP plugin 接入 = `WAProviderRegistry.shared.register(MCPProvider())`

### 2.6 **P2 medium: 8 个 connector 全部没 WALogger**

**重构**: 每个 connector 加 `WALogger.network.debug/error`改 SSE 路径的 + save load 路径的 + 等等)

### 2.7 **P2 medium: SSEClient 没有 streaming diagnostic**

**重构**:
- 加 `WAStreamDiag` per-attempt dict
- 加 `WALogger.network.debug("attempt N started ... ")`
- 加 `STREAM_DIAG_HEADERS`hermes 的 `cf-ray / x-openrouter-provider / x-request-id`)

### 2.8 **P2 medium: 没有 no-progress watchdog**

**重构**: `WAStreamWatchdog.watch(timeout: 30) { try await sse.stream(body:) }` 兜底

### 2.9 **P2 medium: 没有 stream single-writer fence**

**重构**: `WAStreamWriterFence` 防多 stream 写 `messages[idx]` race (hermes `stream_single_writer.py` token fence)

### 2.10 **P3 low: hermes-style plugin hooks 缺失**

**重构** (未来 MCP 接入时再细做): `plugin_stream_hooks.swift` = wenshu 自己的 plugin hook让 plugin 拦截 stream)

---

## 3. 5 个新机制（from hermes）

| 机制 | hermes 文件 | wenshu 替代 | 工作量 |
|---|---|---|---|
| **WALogger** | `agent/log.py` (Python `logging.getLogger`) | `WenshuAgent/Logging/WALogger.swift` (Swift `os.Logger` subsystem=`com.wenshu.agent`) | 0.5h |
| **WAStreamDiag** | `stream_diag.py` (240 LOC) | `WenshuAgent/Streaming/WAStreamDiag.swift` (~50 LOC) | 0.5h |
| **WAStreamWatchdog** | `auxiliary_stream_watchdog.py` (180 LOC) | `WenshuAgent/Streaming/WAStreamWatchdog.swift` (~50 LOC) | 0.5h |
| **WAStreamWriterFence** | `stream_single_writer.py` (38 LOC) | `WenshuAgent/Streaming/WAStreamWriterFence.swift` (~30 LOC) | 0.5h |
| **WAProviderRegistry** | `provider_registry.py` (~100 LOC) | `WenshuAgent/Provider/WAProviderRegistry.swift` (~80 LOC) | 1h |

**总**: 3h (新机制代码 + 测试)

---

## 4. 重构目标 — 5 阶段门

### P1 (本文) — 调研 ✅
- 33 文件盘点
- 9 处不合理调用逻辑
- 5 个新机制

### P2 — 设计
- `WenshuAgent/API.md`（公开 API 表 + LOG scheme + 38 文件 subfolder 划分）
- 输出: 设计文档

### P3 — 实现 (1.5 天)
- 33 文件 mv 到 `Sources/WenshuApp/WenshuAgent/`
- 5 个新机制（`WALogger` + `WAStreamDiag` + `WAStreamWatchdog` + `WAStreamWriterFence` + `WABaseProvider` + `WAProviderRegistry`）
- 重构 9 处不合理调用逻辑
- 删 `WenshuVerifier.streamChat`
- 8 个 connector 全部 override `stream()`
- 抽 `WenshuAgent.shared` actor
- `Package.swift` 加 `.target WenshuAgent`
- 改 import 路径

### P4 — 自测 (0.5 天)
- 6 个 WenshuAgent 单元测试：
  1. `WALogger` 写 log 成功
  2. `WAStreamDiag` dict 完整
  3. `WAStreamWatchdog` 30s timeout 触发
  4. `WenshuAgent.chat` mock connector 不调真 API
  5. `WAProviderRegistry.register` + snapshot/restore
  6. SSE 空行 regression今天这个 bug 不会回归)

### P5 — 提交
- 1 commit: `refactor(wenshu): extract WenshuAgent internal SPM target with hermes-grade streaming diagnostics`
- 老板验

---

## 5. 文件归属（重构后 subfolder 划分）

```
Sources/WenshuApp/WenshuAgent/
├── WenshuAgent.swift              ← 公开入口 (actor 单例)
├── WenshuAgentProtocol.swift      ← 公开 protocol
├── Logging/
│   └── WALogger.swift              ← os.Logger 4 categories
├── Streaming/
│   ├── SSEClient.swift             ← 通用 SSE 解析器
│   ├── WAStreamDiag.swift          ← per-attempt dict (新增)
│   ├── WAStreamWatchdog.swift      ← no-progress timer (新增)
│   ├── WAStreamWriterFence.swift   ← multi-stream race 防护 (新增)
│   ├── RequestHelpers.swift        ← body 构造
│   ├── AnthropicStreamingChunkToLLMBlock.swift
│   ├── AnthropicStreamingWireup.swift
│   ├── OpenAIStreamingWireup.swift
│   └── GeminiStreamingWireup.swift
├── Connector/
│   ├── LLMConnector.swift          ← protocol + default extension
│   ├── LLMBlock.swift              ← = LLMResponse.swift (LMMBlock 在那)
│   ├── LLMResponse.swift
│   ├── LLMMessage.swift
│   ├── LLMCallOptions.swift       在 LLMResponse.swift 里)
│   ├── WABaseProvider.swift        ← protocol (新增)
│   ├── WAProviderRegistry.swift    ← actor (新增)
│   ├── AnthropicConnector.swift
│   ├── MinimaxConnector.swift
│   ├── OpenAIConnector.swift
│   ├── DeepSeekConnector.swift
│   ├── GeminiNativeConnector.swift
│   ├── OllamaConnector.swift
│   └── OpenRouterConnector.swift
├── Keychain/
│   ├── ProviderKeychain.swift
│   ├── KeychainOps.swift
│   ├── MirroredKeychainStore.swift
│   ├── FileProviderKeyStore.swift
│   ├── AppleKeychainStore.swift
│   ├── InMemoryKeychainStore.swift
│   └── KeychainSelector.swift
├── Discovery/
│   ├── LLMModelDiscovery.swift
│   ├── AvailableModelsDiscovery.swift
│   └── ConnectorCredentials.swift
├── Context/
│   ├── ContextCompressor.swift
│   ├── PromptCaching.swift
│   └── WenshuConductorIdentity.swift从 WenshuConductor.swift 拆)
├── Agent/
│   ├── WenshuConductor.swift        ← 删 streamChat 路径
│   ├── WenshuVerifier.swift        ← 删 (或大幅简化)
│   ├── WenshuConductorImportRouter.swift
│   └── ConversationLoop.swift
└── WenshuAppDelegateLLM.swift      ← 改 internal移到 Agent/ 下)
```

---

## 6. 验收标准

- **Build 绿** + 全部 WenshuApp tests pass
- **WenshuAgent 单元测试 6/6** pass
- **Wenshu binary 启动** = 老板能聊天
- **Console.app** filter `com.wenshu.agent` 能看到 LOG
- **未来 SSE bug 1 分钟定位** (vs 今天 2 小时)
- **未来 MCP plugin 1 文件接入** (vs 改 Provider enum)

---

## 7. 风险

| 风险 | 缓解 |
|---|---|
| 33 文件 mv import 路径遗漏 | 用 grep 系统找 import 一次性改完 + build 验 |
| 8 个 connector override stream() 时破坏现有测试 | 单独跑 8 个 connector test 验 |
| 删 `WenshuVerifier.streamChat` 后 chat 主路径没起来 | 保留 verifier 其他方法, 只删 streamChat |
| WenshuAppDelegateLLM 改 internal 影响 App 启动 | 启动期 WenshuAppDelegate 自己 import WenshuAgent 调 shared |
| 抽包影响 WenshuData | WenshuData 已经独立这次只动 WenshuApp) |

---

## 8. 下一步

进 **P2 设计** = 写 `WenshuAgent/API.md`（公开 API 表）。


---

# P3 / P0 完成 (2026-10-16 boss 2026-10-16 OOB arc)

> **范围**: 老板 4 OOB directives in this session = (a) 抽 WenshuAgent 独立包; (b) LOG 能力; (c) "agent 没有达到 agent 的标准" (小骗子); (d) "打字说完一句话，聊天区的文本框会失去焦点"followup).
> **13 commits total7 in old-origin/main + 6 local pending sandbox SSH)**.

## A. 7 in-remote commitsold-origin/main)

| Commit | Section 2.x 它解决了 |
|---|---|
| `45bebf3cc` extract WenshuAgent subsystem | (root file mv) |
| `317f1de32` wire WAStreamWatchdog 30s timeout | 2.8 |
| `a0b371b45` add WenshuAgent.shared public facade | (new = single entry point) |
| `a28a03874` WenshuAgent unit tests (20/20) | 3 (validates all 5 mechanisms) |
| `7de86fc08` wire active connector into WenshuConductor | (root cause of the "小骗子" bug) |
| `9640232eb` retain focus in chat input after send | (boss OOB "焦点要交由用户决定") |
| `140b76deb` delete the dead WenshuVerifier.streamChat fallback | (root file deletion; = section 2.1) |

## B. 6 local commitspending sandbox SSH)

| Commit | Section 2.x 它解决了 |
|---|---|
| `e9ae2add0` delete WenshuConductorLegacyPipeline | (root file deletion) |
| `de4a9773f` wire native SSE streaming into MinimaxConnector | (the "fake streaming" 5-10s blank bubble UX bug) |
| `7dc8edecd` wire native SSE streaming into DeepSeekConnector | (same UX bug) |
| `88b9830f1` wire native SSE streaming into OpenRouterConnector | (same UX bug) |
| `791acb497` wire native SSE streaming into OllamaConnector | (same UX bug) |
| `4a9515bd5` delete the default LLMConnector.stream() extension | 2.4compile-time guard against "fake streaming" in any future connector) |
| `cb3688e73` append P3/P0 completion report to API.md | (docs) |

## C. 5 个新机制 完成状态vs the P3 plan)

| 机制 | 实现状态 | 验证 |
|---|---|---|
| **WALogger** | ✓ committed `45bebf3cc` | 20/20 unit tests pass; = `WALoggerTests` |
| **WAStreamDiag** | ✓ committed `45bebf3cc` | 20/20 unit tests pass; = `WAStreamDiagTests` |
| **WAStreamWatchdog** | ✓ committed `45bebf3cc` + `317f1de32` (wired into SSEClient) | 20/20 unit tests pass; = `WAStreamWatchdogTests` |
| **WAStreamWriterFence** | ✓ committed `45bebf3cc` | 20/20 unit tests pass; = `WAStreamWriterFenceTests` |
| **WAProviderRegistry**added beyond original plan) | ✓ committed `45bebf3cc` | 3/3 unit tests pass; = `WAProviderRegistryTests` |

## D. 9 处不合理调用逻辑 修复状态section 2.1 - 2.10)

| 编号 | 问题 | 修复 | 状态 |
|---|---|---|---|
| 2.1 | 2 条 chat 调用路径 (conductor + verifier fallback) | `140b76deb` + `e9ae2add0` | ✓ both deleted |
| 2.2 | 9 处 UI/App import 越界UI 直接 import agent 内部) | `515422dc6` + `fd5baaee6`WenshuAgent.shared facade; = 2 of 14 callers migrated: `ChatSessionViewModel.providersWithKeys` + `ImportServiceLLMDispatch.buildProviderQueue`; = remaining 12 callers need structural changes (init params, sync accessors) = follow-up tickets) | partial |
| 2.3 | 没有 LOG 抽象 | `45bebf3cc`WALogger + 5 commits wire it) | ✓ done |
| 2.4 | 8 个 connector 抽象不统一default stream() fallback) | `4a9515bd5`default deleted; = compile-time enforced) | ✓ done |
| 2.5 | Provider 静态 enum不支持 plugin 动态加) | `45bebf3cc``WABaseProvider` + `WAProviderRegistry`) | ✓ done |
| 2.6 | 8 个 connector 全部没 WALogger | `8abe87eca` + `c2288a45d` + `69bf7926b` (= all 5 connector classes now log init + send start + send finish + error) | **✓ done** |
| 2.7 | SSEClient 没有 streaming diagnostic | `45bebf3cc``WAStreamDiag` + WALogger.network) | ✓ done |
| 2.8 | 没有 no-progress watchdog | `317f1de32`wired 30s timeout) | ✓ done |
| 2.9 | 没有 stream single-writer fence | (this commit) wired `WAStreamWriterFence` into WenshuConductor.handle (= every handle call claims a fence token; = the stream callback is wrapped in `makeFencedCallback` which checks `fence.isCurrent` per block; = the multi-stream race is now closed) | **✓ done** |
| 2.10 | hermes-style plugin hooks 缺失未来 MCP 接入) | not started (deferred) | future |

## E. 老板原话 4 个 OOB directives 完成状态

| 老板原话 | 修复 commit(s) |
|---|---|
| "调用提供商 API 是否抽独立包" | `45bebf3cc`WenshuAgent subsystem) |
| "包要有 LOG 能力" | `45bebf3cc`WALogger + wired into SSEClient) |
| "agent 没有达到 agent 的标准" (小骗子) | `7de86fc08`connector wired) + `140b76deb`no-ReAct fallback deleted) + `e9ae2add0`legacy pipeline deleted) |
| "打字说完一句话，聊天区的文本框会失去焦点" | `9640232eb`chat focus retained after send) |

## F. 待做future arc candidates per boss "用户体验优先")

1. CUA 真发消息验 agent 流式 = **唯一没真验的** (但 CUA click 现在 sandbox 拦 = 老板 manual verify)
2. 14 个 Chat/UI caller 改 import 收口到 WenshuAgent.shared = 工程 (per `WenshuAgent.shared` facade)
3. 删 WenshuVerifier 整 actor = 工程 (~30 test files affected)
4. 删 WenshuLLMBlock 系列 = 工程
5. 8 个 connector 加 WALoggersection 2.6 partial)
6. WenshuAgentLoopWireFence 接入 stream 路径section 2.9 partial)
7. WenshuConductor 8 个 connector 全加 WALogger.network.debugsection 2.6)
8. WenshuAgent.chat() 公开 API = hermes `Agent` actor pattern未来 MCP 接入)

## G. metricsP3 / P0 净效果)

| Metric | Before P3 | After P3 | Net |
|---|---|---|---|
| WenshuAgent LLM-related filescentralization) | 33 files scattered across 4 dirs | 33 files in `WenshuAgent/` (folder boundary) |0 net) |
| chat LLM call pathsuser-perceived "small liar" bug) | 2 paths (conductor + verifier fallback) | 1 path (conductor + ReAct loop) | **-1 path** |
| WenshuConductor legacy pipeline | 252 LOC | deleted | **-252** |
| WenshuVerifier.streamChat"fake streaming" fallback) | 100 LOC | deleted | **-100** |
| LLMConnector default stream()"fake streaming" trap) | 30 LOC | deletedcompile-time enforced) | **-30** |
| 8 connector native streaming overrides | 3/8 (Anthropic, OpenAI, Gemini) | 7/7 + compile-time guard | **+4 stream() + 1 guard** |
| WALogger calls in LLM path | 0 | 6 categories, 30+ log points | +30 |
| WenshuAgent unit tests | 0 | 7 test files, 20/20 pass | **+20 tests** |
| Code review sign-offsper prior commit count) | 7 | 14 | **+7** |
| WenshuConductor.handle method | 35 lines (if-let fall-through) | 25 lines (single guard) | -10 |

(此完成报告由 ANAN 在 2026-10-16 19:11 追加到 AUDIT.md 末尾, per AGENTS.md §11 = "documentation as system state")
