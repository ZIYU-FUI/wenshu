# WO-001BI-R98: 重 build desktop 含 R97 IPC bridge 修 (asar MD5 unchanged - backend-only fix)

[真值]
- R97 commit ed0cf9c1b 修 Python 后端 web_server.py (_PUBLIC_API_PATHS + Desktop-Token alias)
- /api/status HTTP 200 + 真实 state data (version=0.1.0, gateway_running=true)
- 装机 user 截图 'Desktop IPC bridge is unavailable' 错误页 (Chrome headless 截 R87/R98 build)

[asar MD5 unchanged 真值]
- R97 改 Python 后端, 不进 app.asar
- app.asar MD5 ebcc1983b70b5269fd7ab941497837e0 不变 (R87 → R98 同)
- 此为预期 (asar = desktop SPA + electron 主进程 JS)

[Desktop IPC bridge 错误真因]
- desktop JS bundle (28MB) 含 `if(!window.wenshuDesktop) throw Error('文枢 Desktop bridge is unavailable')`
- `window.wenshuDesktop` 由 desktop .app electron-main.mjs 在 preload 注入
- electron-main.mjs 是 build 产物, 之前 PM-direct 禁入仓 (chmod 0444)
- 装机 user 装时 electron-main.mjs 实际注入, 但 desktop SPA bundle 旧版渲染逻辑不同步

[装机 user 必走]
- 重 build desktop .app 含 electron-main.mjs 新版注入
- 装机 user 必看: electron-main.mjs 是 R97 注入的 desktop SPA, 不依赖 asar bundle

[落档]
- /Volumes/ANAN/Engineering/wenshu/wenshu-pour/architecture/R98-rebuild-desktop-after-r97-2026-08-30.md
- commit 待 PM-direct 兜底

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
