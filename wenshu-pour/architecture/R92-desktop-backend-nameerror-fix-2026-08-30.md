# WO-001BI-R92: 修 R74 PM-direct 自家留的 NameError (desktop backend 跑起失败)

[真值]
- 装机 user 8/30 跑 desktop .app, spawn wenshu serve, backend 报 NameError
- web_server.py line 19080: app.include_router(_dashboard_auth_router) - R74 删 _dashboard_auth_router 注册但保留 include
- line 573/610: gated_auth_middleware/token_auth_middleware - R74 删 import 但保留函数调用
- line 16560-16593: consume_internal_credential/consume_ticket - 同样 R74 死代码

[R74 PM-direct 自家错]
- 派单后 PM-direct 自家改 web_server.py, 但 'try/except ImportError' 只 catch ImportError 不 catch NameError
- 删了 import 但保留函数体调用, function body 找不到 name -> NameError runtime
- 编译测试没跑 (R91 已加派单必跑 py_compile 协议, 这次仍 R91 之前的修没补)

[R92 PM-direct 兜底]
1. web_server.py line 19080: 删 app.include_router(_dashboard_auth_router)
2. line 573: return gated_auth_middleware() -> return call_next() (auth gate disabled)
3. line 610: return token_auth_middleware() -> return call_next() (token auth disabled)
4. line 16560-16593: 简化为 return None 'ws_auth_disabled' (skip 全部 ticket/internal 处理)
5. 验 python3 -m py_compile exit 0

[产物]
- /Applications/文枢-Desktop.app 已 cp (从 DMG mount)
- venv HEAD 87ade3e1 R91 (PM-direct reset hard origin/main)
- desktop .app 启动后端 OK (试启动 1 次: PID 12499 alive + helper process)

[装机 user 必走]
1. 已 venv sync R91, 装好 desktop .app, desktop 跑通
2. 重启 desktop .app (双击 /Applications/文枢-Desktop.app 或 WenShu-Setup)
3. APP 启动后选 chat 模式试 (首次配置中文 UI)

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
