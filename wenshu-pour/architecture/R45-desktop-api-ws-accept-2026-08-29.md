# WO-001BI-R45: /api/ws accept-before-send (装机 user 8/29 "卡 100%" 真根因)

## 装机 user 8/29 实拍
"感觉像是可以了呢, 但就是卡 100%"

## 真根因

R42 (`70fc58e76`) 把 `/api/ws` 从 close(1011) 改成接 accept 后 keep-alive + 发 `{ready}` hello, 但漏了 ASGI 一个硬性要求:

> `await ws.send_json(...)` 之前必须先 `await ws.accept()`

`/api/ws` handler 直接 send 没 accept, 触发 Starlette ASGI 实现:

```
WARNING wenshu_cli.web_server: Desktop /api/ws handler exited:
  Expected ASGI message "websocket.accept", "websocket.close" or
  "websocket.http.response.start", but got 'websocket.send'
```

Handler 立刻退出 → renderer 的 `WebSocket.onclose` 触发 → `JsonRpcGatewayClient.connect()` 的 Promise reject → `useGatewayBoot.boot()` catch block → `failDesktopBoot(message)` → `boot.error` 被 set → **BootFailureOverlay** 显示 → 装机 user 看见"卡 100%"以为是 loading → 点击 Repair → bootstrap 重跑 → 再 spawn backend → 同 bug → cycle → ~20003 行 log 后 Electron main 进程 SIGKILL 死。

## 实锤证据

`/Users/anbaiqiang/.wenshu-hermes/logs/errors.log` (最近的):

```
2026-07-29 18:33:06,510 WARNING wenshu_cli.web_server: Desktop /api/ws connected: peer=127.0.0.1:57022
2026-07-29 18:33:06,510 WARNING wenshu_cli.web_server: Desktop /api/ws handler exited:
  Expected ASGI message "websocket.accept", ..., but got 'websocket.send'
```

`/Users/anbaiqiang/.wenshu-hermes/logs/desktop.log` (装机 user 端):

```
[wenshu] [boot] finalize: served token adopted (matches=true)
[wenshu] [boot] 文枢 backend is ready. Finalizing desktop startup
[wenshu] [bootstrap] repair requested by renderer; clearing marker + latched failure
[wenshu] [boot] Restarting desktop connection
... (cycle 重复 38+ 次, 到 20003 行)
```

## 修

`wenshu_cli/web_server.py` `/api/ws` handler:

```diff
     _log.info("Desktop /api/ws connected: ...")
     try:
+        await ws.accept()                               # R45: ASGI 协议要求
         await ws.send_json({"type": "ready", ...})
         while True:
             try:
                 msg = await ws.receive_text()
```

跟 `/api/pub` (line 17765) 和 `/api/events` 的现有 pattern 对齐。

## 验证

### E2E (Python websockets client)

```
[1/4] Backend announced port 59461 (mimics: waitForDashboardPortAnnouncement)
[2/4] /api/status -> 200, version=0.19.0
      adopted served token (matches=True)
[3/4] WS connect state sequence: idle -> connecting -> open -> closed
      recv payload: {'type': 'ready', 'endpoint': '/api/ws', 'server': 'wenshu-isolated'}
[4/4] completeDesktopBoot() preconditions met

=== R45 SMOKE TEST PASS ===
```

### 回归测试

`tests/wenshu_cli/test_web_server.py::TestR45DesktopApiWsAccept`:

1. `test_accept_called_before_send_json` — 源码级 guard, 防止未来 refactor 静默回退
2. `test_endpoint_accepts_then_sends_ready` — 真 uvicorn bind + WebSocket connect + recv `{ready}` hello

### 其他套件

- `tests/wenshu_cli/test_web_server.py` — **465 passed** (含 R45 + token injection + ...)
- `tests/wenshu_cli/test_dashboard_unified_launch.py` + `test_dashboard_auth_ws_auth.py` — **59 passed**
- `apps/desktop/electron/main.ts` tsc --noEmit — exit 0

注: `pnpm test` 在 desktop renderer 端继续有 pre-existing 失败 (React 19.2.7 vs 19.2.8 双副本 + vite pre-transform) — R44 落档已知, 与本单无关。

## 装机 user 验证步骤

1. 关运行中的文枢
2. 已 patch 过 `~/.wenshu-hermes/wenshu-agent/wenshu_cli/web_server.py` + `__pycache__/web_server*` 已清
3. 重启 `/Applications/文枢.app`
4. 应直接进 main UI, 不再卡 100% / 不再触发 Repair

## 留尾

- 未 DM 装机 user (CC 无飞书 access, 由 PM-direct 推)
- working tree clean, 已 `git push origin main` (commit `da1025068`)
- 3 commit 在 R44 后: R45 修复, R43/R44 doc
- sync patch 到 `~/.wenshu-hermes/wenshu-agent/wenshu_cli/web_server.py` 已就地 (装机 user 不用重装 .app)
