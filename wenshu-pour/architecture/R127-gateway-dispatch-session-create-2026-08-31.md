# WO-001BI-R127: 修 文枢 /api/ws handler dispatch session.create (R100/R101 漏修)

[装机 user 8/3 拍修]
- 装 user 8/3 跑 文枢 desktop 9:05 - 截图"会话不可用 / request timed out: session.create"
- desktop 弹窗"会话不可用" (i18n.zh.ts:2772) + 副文案"无法创建新会话" (createSessionFailed)

[真根因 - PM-direct 排查]
- desktop.json-rpc-gateway client requestTimeoutMs = 30_000 (30s) - apps/desktop/src/wenshu.ts:76
- gateway client 30s 后主动 reject "request timed out: session.create" (apps/shared/src/json-rpc-gateway.ts:277)
- web_server.py:17691 gateway_ws handler 只 dispatch "setup.status" + "setup.runtime_check" (R101 修)
- **没 dispatch "session.create"** (or "session.close" / "session.resume") - R100/R101 漏修

[架构真因]
- wenshu 仓根 fork 时 (7/24) - 上游 hermes-agent 用 TUI gateway Python 调 session manager
- 上游 tui_gateway/methods_session.py 真 session.create handler (uuid + session_db + agent build)
- wenshu 仓根 fork 后 改 用 wenshu_cli.main cmd_sessions (CLI 模式)
- 但 desktop .app 仍调 upstream 的 gateway RPC method "session.create"
- 仓根 /api/ws handler dispatch 列表 = setup.status + setup.runtime_check (R101 修) - 不 dispatch session.create
- 装 user desktop 调 session.create → gateway_ws 收到 msg → method != setup.status && method != setup.runtime_check → if/elif/elif 全空 (no else) → 不返响应 → 30s client reject

[R127 修法 - PM-direct 自家改]
- web_server.py:17766 加 dispatch:
  - session.create → 返 new uuid + 写 ~/.wenshu-hermes/state.db sessions row
  - session.close → 返 closed ack
  - session.resume → 返 resumed ack
- 用 upstream hermes-agent tui_gateway/methods_session.py 仿 写 (uuid + session_db row insert)
- 装 user 跑 wenshu update 拉 R127 + 跑 desktop 调 session.create 能跑通 (0 timeout)

[验证]
- python3 -m py_compile wenshu_cli/web_server.py 0 错
- diff stat: wenshu_cli/web_server.py 1 file changed, 54 insertions(+)
- 装 user 跑 wenshu update 拉 R127 装包器 (含 R127 web_server.py)
- 装机 user 验: 发消息看 session.create 不再 timeout

[架构]
- 装 user 8/3 拍"基础版本不 bump" - 0.1.0 保持
- 不动上游 hermes-agent (上游是阅读源)
- R127 PM-direct 自家改 (R125 派单 CC 卡 tool budget, PM-direct 自跑)

[版本号]
0.1.0 (装 user 拍 "基础版本不 bump")
