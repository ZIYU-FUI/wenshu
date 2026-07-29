# WO-001BI-R26-v2 文枢 APP gateway 隔离启动链路修复

> 日期：2026-07-29  
> 真值：装机 user 8/28 拍——文枢启动 `~/.wenshu-hermes` 下的隔离 Hermes runtime，不连接、不启动 `~/.hermes` 下的本机 Hermes。

## 1. 根因

R18 只把默认目录改成了 `~/.wenshu-hermes`，但启动链仍有两处会回到本机 Hermes：

1. packaged APP 会信任父进程继承的任意 `HERMES_HOME`；实测从当前调试会话直接启动 APP 时继承到了 `~/.hermes/profiles/my-pm`。
2. packaged backend resolver 在 marker 不可用时仍会尝试 PATH 上的 `hermes` 和 system Python；这些候选可能来自 `~/.hermes`。

同时，原桌面启动只 spawn `hermes serve`。`serve` 是桌面 HTTP/WebSocket backend，不等同于工单要求的 messaging/cron `hermes gateway run`。

## 2. 实际改动

### `apps/desktop/electron/main.ts`

- packaged macOS/Linux 启动时强制把 `HERMES_HOME` 固定为 `~/.wenshu-hermes`，拒绝继承 `~/.hermes` 或其 profile。
- ACTIVE runtime 命令固定为 `~/.wenshu-hermes/hermes-agent/venv/bin/python`，不再回退 system Python。
- packaged resolver 禁用 PATH `hermes` 和 system Python 两个外部候选；marker 不成立时只走 bootstrap 修复。
- packaged APP 额外 spawn 并管理以下隔离子进程：

  ```text
  ~/.wenshu-hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run
  ```

- gateway child 和 APP 生命周期绑定，APP quit 时一并 SIGTERM。
- 保留 `hermes serve --host 127.0.0.1 --port 0` 子进程供桌面 renderer 使用。`gateway run` 负责 messaging + cron；`serve` 负责桌面 HTTP/WebSocket API 和动态监听端口，两者不能互相替代。

### `apps/desktop/electron/backend-command.ts`

- 新增 `gatewayBackendArgs()`，唯一生成 `['gateway', 'run']`。
- 保留 `serveBackendArgs()` / dashboard 兼容逻辑。

### `apps/desktop/electron/backend-probes.ts`

- 新增 `canLaunchHermesGateway()`。
- 用 `python -m hermes_cli.main gateway run --help` 验证完整 CLI dispatch 链；`--help` 在进入长驻运行前退出，不产生探测残留进程。

### `apps/desktop/electron/bootstrap-runner.ts`

- 十步 installer manifest 全部跑完后、写 marker 前，强校验：
  - isolated venv Python 存在；
  - isolated `venv/bin/hermes` wrapper 存在；
  - exact gateway CLI probe exit 0；
  - probe env 的 `HERMES_HOME=~/.wenshu-hermes`。
- 任一校验失败则 bootstrap 失败，不写“完成” marker。

## 3. 实机验证

### 3.1 隔离 runtime 与 marker

```text
~/.wenshu-hermes/hermes-agent/venv/bin/python      存在
~/.wenshu-hermes/hermes-agent/venv/bin/hermes      存在
~/.wenshu-hermes/hermes-agent/.hermes-bootstrap-complete 存在
```

最终 marker：

```json
{
  "schemaVersion": 1,
  "pinnedCommit": "1033c3fcca803eb71348efcb955f58eeedc15bcd",
  "pinnedBranch": "main",
  "completedAt": "2026-07-29T01:59:40.929Z",
  "desktopVersion": "0.0.1"
}
```

bootstrap log 命中：

```text
[bootstrap] isolated gateway runtime ready: /Users/anbaiqiang/.wenshu-hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run (wrapper=/Users/anbaiqiang/.wenshu-hermes/hermes-agent/venv/bin/hermes, HERMES_HOME=/Users/anbaiqiang/.wenshu-hermes)
```

### 3.2 packaged APP 进程

从最终 ZIP 解出 `.app` 后启动，`pgrep -fl` 实测：

```text
10528 /Users/anbaiqiang/.wenshu-hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run
10529 /Users/anbaiqiang/.wenshu-hermes/hermes-agent/venv/bin/python -m hermes_cli.main serve --host 127.0.0.1 --port 0
```

两个 child 的实际进程环境均为：

```text
HERMES_HOME=/Users/anbaiqiang/.wenshu-hermes
```

未 spawn `/Users/anbaiqiang/.hermes/hermes-agent/venv/bin/python`。

### 3.3 动态端口和可访问性

`/usr/sbin/lsof -nP -a -p 10529 -iTCP -sTCP:LISTEN` 实测：

```text
python3.1 10529 ... TCP 127.0.0.1:56972 (LISTEN)
```

访问动态端口：

```text
GET http://127.0.0.1:56972/api/status
api_status=ok
```

说明：当前隔离配置未启用 messaging platform，`gateway run` 本身不创建 TCP listener；桌面可访问端口由同一 isolated runtime 的 `serve` child 动态监听。这与上游 CLI 职责一致。

### 3.4 工程门禁与产物

```text
pnpm exec tsc -p tsconfig.electron.json --noEmit       exit 0
pnpm exec vitest run --project electron ...            3 files / 26 tests passed
pnpm exec eslint electron/main.ts ...                   exit 0
pnpm run dist:mac                                       exit 0
```

最终产物：

```text
apps/desktop/release/文枢-0.0.1-arm64.dmg  129 MB
apps/desktop/release/文枢-0.0.1-arm64.zip  129 MB
```

打包有既有非阻断提示：working tree dirty、无有效 Developer ID 因而跳过签名/公证、Vite CSS/chunk size warning；命令整体 exit 0。

## 4. AC 对照

| AC | 结果 |
|---|---|
| AC1 exact `~/.wenshu-hermes/.../python -m hermes_cli.main gateway run` | ✅ PID 10528 实测命中 |
| AC2 gateway/桌面 backend 动态端口可访问 | ✅ isolated `serve` PID 10529 监听 127.0.0.1:56972，`/api/status` 成功 |
| AC3 `HERMES_HOME=~/.wenshu-hermes` + marker 存在 | ✅ 两个 child env 实测；marker 已重写并存在 |
| AC4 `pnpm run dist:mac` exit 0 | ✅ DMG + ZIP 已生成 |
| AC5 R26 落档 | ✅ 本文件 |

## 5. 留尾

- 未 commit、未 push，按工单由 PM-direct 在装机 user 验收后自决。
- 未复制到 `/Applications`，该动作归 PM。
- 未访问或修改禁止目录，也未修改 `~/.hermes`。
- messaging gateway 因当前 `~/.wenshu-hermes` 配置未启用平台而记录 `No messaging platforms enabled` warning；进程保持运行，不影响桌面 `serve` API。

## 6. 交付时并发冲突（阻断当前源码验收）

> 2026-07-29 10:02 后检测到另一并发任务改写了同一批目标文件及全仓命名。该改写不是 R26 操作，R26 未回滚或覆盖它。

R26 最终 DMG/ZIP 构建并完成上文实机验证之后，当前 working tree 被并发改为：

- `HERMES_HOME` → `WENSHU_HOME`
- `hermes_cli` → `wenshu_cli`
- `~/.wenshu-hermes/hermes-agent` → `~/.wenshu-hermes/wenshu-agent`
- `.hermes-bootstrap-complete` → `.wenshu-bootstrap-complete`

这与本工单 AC1/AC3 的字面真值（`hermes_cli.main`、`HERMES_HOME`、`hermes-agent/.hermes-bootstrap-complete`）直接冲突。上文 PID/端口/产物验证来自并发覆盖前成功构建的 R26 artifact；**当前源码不能按 R26 宣称验收通过**。需要 PM 先裁决保留哪套命名，再重放 R26 patch 并重新 `dist:mac`。
