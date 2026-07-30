# WO-001BI-R97: 修 desktop IPC bridge unavailable - PUBLIC_API_PATHS + Desktop-Token alias

[装机 user 8/30 拍板真值]
- 截图验收后, 如果有问题派 CC 修, 一直到修好
- PM-direct 自验 desktop .app 截图发现 'Desktop IPC bridge is unavailable' 错误页

[真值]
- desktop .app SPA renderer 报 'Desktop IPC bridge is unavailable'
- 后端 _PUBLIC_API_PATHS = () 空 tuple (R72 砍 dashboard_auth 时遗留)
- /api/status 等 desktop IPC 路径都返 401

[修法]
1. _PUBLIC_API_PATHS 加 5 个 desktop IPC 路径:
   - /api/status
   - /api/health
   - /api/state
   - /api/wenshu/update
   - /api/wenshu/update/check
2. _has_valid_session_token 加 X-Wenshu-Desktop-Token alias (defensive)

[产物]
- wenshu_cli/web_server.py 43 行 diff
- curl /api/status HTTP 200 + 真实 state data
- 编译 0 + import 0

[装机 user 必走]
- 重 build desktop .app 含 R97 修 (PM-direct 后续派 R98)
- 重 build 后 desktop IPC bridge 应 work

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
