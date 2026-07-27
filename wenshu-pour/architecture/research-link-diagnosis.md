# WO-001AJ 派单链路诊断：Claude Code 与文枢 delegate_task 的边界真值

日期：2026-07-27（本次终端实测）

## 结论先行

本仓库存在两套名称相近、但不是同一个执行器的链路：

1. **Claude Code CLI** 是 `/opt/homebrew/bin/claude`，终端实测版本为 `2.1.201 (Claude Code)`。`claude --help` 明确写明 `--bare` 是 Claude Code 的 minimal mode：跳过 hooks、LSP、插件同步、归因、自动记忆、后台预取和 keychain 读取，并且只使用 `ANTHROPIC_API_KEY` 或 `apiKeyHelper`。因此，`claude --bare` 本身仍是 Claude Code CLI；它不是文枢/hermes-agent 的派单命令，也不会因为参数名相似而自动进入文枢的 `delegate_task`。
2. **文枢/hermes-agent 内部派单** 是 Python 工具 `tools/delegate_tool.py` 注册的 `delegate_task`。它创建子 `AIAgent`，给子会话新鲜上下文、独立 task_id/terminal session，并继承父会话允许的 toolsets；叶子子会话默认不能继续派单。
3. **外部 Claude Code 子进程** 是另一条可选适配路径。仓库自己的 `hermes_cli/tips.py`（终端 grep 实测命中）写明：`delegate_task with acp_command: 'claude' spawns Claude Code as a child agent from any platform.` 这意味着只有在文枢派单参数明确走 `acp_command` 时，文枢才会把 Claude Code 当作外部 child agent；普通 `claude --bare -p` 是 PM/操作者直接启动 Claude Code，不等于通过 Hermes 的 `delegate_task` 派出子会话。

## 源码证据

### 1. `delegate_task` 的真实入口

`tools/delegate_tool.py` 的 `delegate_task(...)` 接收 `goal`、`context`、`tasks`、`role`、`background` 与 `parent_agent`。源码首先要求 `parent_agent` 非空；没有父 agent 时直接返回 `delegate_task requires a parent agent context.`。所以 shell 里单独运行 `claude --bare` 不可能凭空获得这个父 agent 上下文。

它随后将单任务规范化为 task list，调用 `_build_child_agent(...)` 构造子 agent。源码注释和实现都明确子 agent：

- fresh conversation，不带父历史；
- 自己的 task_id、terminal session 和 file-operation cache；
- 继承父 toolsets，不能由模型借 `toolsets` 参数扩大能力；
- 默认 `role='leaf'`，阻断 `delegate_task`、`clarify`、`memory`、`send_message`、`execute_code`、`cronjob`；
- 只有显式 `role='orchestrator'` 且配置允许足够 `delegation.max_spawn_depth` 时，才可再派孙 agent。

### 2. 背景执行不是“sleep 伪派单”

`delegate_tool.py` 的模型-facing registry handler 调用 `_model_background_value(...)`。该函数的源码语义是：顶层 agent 的 delegation 返回 `True`，让任务转入后台；orchestrator 子 agent 的 delegation 返回 `False`，以便在自己的回合内同步等待结果。随后顶层路径调用 `dispatch_async_delegation_batch(...)`。

后台批次是一个 async delegation unit：所有 child 由 daemon executor 执行，批次内部等待所有 child 完成，然后把一个带 per-task results 的 completion event 重新送回**拥有该派单的会话**。源码还明确：无 stateless response channel 时会降级为同步执行，而不是返回一个永远收不到的 handle；后台池满时也会同步 fallback。因此“后台有无进程”不能单独证明是否派单成功，必须同时查 dispatch 返回值、completion event、live transcript 和 child API/tool 调用。

`tools/delegation_live_log.py` 为每个任务预创建 append-only transcript，路径形如 `<hermes_home>/cache/delegation/live/<delegation_id>/task-<n>.log`。这是验证“真跑过”的直接证据链，比只看父进程 `ps` 可靠。

### 3. `hermes_cli/main.py` 的关系

读取到的 `hermes_cli/main.py` 不是 Claude Code 的启动器。它是文枢/hermes CLI 主入口，负责命令解析、one-shot 清理和调用 `tools.async_delegation.interrupt_all` 做进程级收尾。文件中出现 `claude` 的位置主要是 credentials/setup/文案兼容，不构成 `claude --bare` 的别名或代理。`hermes_cli/__init__.py` 只定义 CLI 版本与 UTF-8 初始化，也没有 Claude Code 派单实现。

### 4. `agent/agent_init.py` 的边界

`agent/agent_init.py` 是 `init_agent(agent, ...)` 的大段 AIAgent 初始化逻辑，包含 provider、API mode、context、memory、回调和 parent session 等状态设置。它不是外部 CLI dispatcher。派单的 parent/child 构造和深度隔离在 `tools/delegate_tool.py`，不是把一个 shell 命令包装成“子会话”的简单 fork。

## 官方文档证据

本仓库随附的官方文档 `website/docs/user-guide/features/delegation.md` 已读取：

- 开头说明 `delegate_task` 会 spawn isolated child AIAgent instances；每个 child fresh conversation、独立 terminal session，只有 final summary 进入 parent context。
- 单任务调用是 `delegate_task(goal=..., context=...)`，批量调用是 `delegate_task(tasks=[...])`。
- 文档警告 child 对父历史一无所知，必须在 `goal`/`context` 里传全路径、错误和约束。
- 顶层调用自动后台运行；后台 completion 可持久化到 profile state.db，重启后已完成但尚未交付的结果可恢复；正在运行的 child 不会在进程崩溃后续跑。
- `terminal(background=True, notify_on_complete=True)` 和 cronjob 才是需要独立于父会话、可持续执行的 durable execution 选项。

本仓库随附的开发者文档 `website/docs/developer-guide/adding-tools.md` 也已读取。它把 `delegate_task` 列为必须由 `run_agent.py` 拦截、需要 per-session agent state 的特殊工具；这进一步证明它不是普通 CLI 子命令，而是 agent loop 内的工具调用。

## `claude --bare` 真值与 WO-001AJ 根因

终端实际结果：

```text
$ command -v claude
/opt/homebrew/bin/claude
$ claude --version
2.1.201 (Claude Code)
$ claude --help
--bare  Minimal mode: ... Sets CLAUDE_CODE_SIMPLE=1 ...
```

因此，先前把 `claude --bare` 当成“调用文枢/hermes 的子会话派单器”是**执行器身份混淆**。它是直接启动 Claude Code 的简化模式；若由 PM-direct 的自身 profile/gateway 接收 prompt，实际就可能变成 PM-direct 自己消费 prompt，而不是另起一个可审计的 CC worker。`--bare` 只改变 Claude Code 自身初始化，不会把请求转发给文枢的 `delegate_task`，也不会凭空产生文枢 delegation completion。

## 正确操作协议

### 要让 CC 真跑一个研发任务

由控制面直接调用真实 Claude Code CLI：

```bash
/opt/homebrew/bin/claude --bare -p '<完整任务>' \
  --add-dir /Volumes/ANAN/Engineering/wenshu
```

此命令的身份是 CC worker；需要在 prompt 中明确“读取哪些文件、允许哪些命令、验收标准、落档路径和 sentinel”。不要写成 `claude --profile my-pm`，也不要把 profile 名当作 CC 身份证明。

### 要让文枢内部派出子 agent

必须在文枢 agent 回合中让模型调用注册工具 `delegate_task`，并传递完整 `goal`/`context`。若目标是让外部 Claude Code 执行，才使用仓库声明的 `acp_command: 'claude'` 适配路径，并分别验证 ACP 子进程的 stdout/exit code/trace；不能用裸 `claude --bare` 代替这层调用。

### 端到端验收证据

一次真实派单至少应留下：

1. dispatcher 返回的 delegation id/status；
2. `cache/delegation/live/<id>/task-*.log` 中的读取、命令、结果和 final marker；
3. 子任务产出的落档文件，能由 `wc`/`stat` 验证大小和 mtime；
4. build/测试真实 stdout 与 exit code；
5. git diff、commit hash 和（若获授权）push 返回值；
6. 若是安装任务，安装后 bundle 内 binary 的 mtime/size/hash 与 build artifact 对得上。

只看到 `sleep`、`ps`、`ls`，或只看到父进程空闲，不足以证明 child 真读了任务文件。反之，不能因为 `claude --bare` 退出成功，就推断文枢的 `delegate_task` 已发生。

## 本次结论

WO-001AJ 的派单机制问题不是 `agent_init.py` 缺一个 sleep/进程修复，而是控制面把 **Claude Code CLI 直接调用**、**Hermes `delegate_task` 内部子 agent**、以及**my-pm gateway profile** 三个身份混在了一起。修复研发链路的首要动作是固定执行器命名和证据协议：CC 任务用真实 `/opt/homebrew/bin/claude`；文枢派单必须由 agent tool invocation 产生 delegation id/live transcript；PM-direct 不能用自家 gateway 的 `claude --bare --profile my-pm` 冒充 CC。
