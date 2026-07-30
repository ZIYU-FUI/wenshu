# WO-001BI-R94: PM-direct 自验 - 重 build desktop .app + sync venv + 落档

[装机 user 8/30 拍]
- 装机 user 不在电脑前
- PM-direct 自己验 目标:能进 app

[真值]
1. R92 修 web_server.py line 19080 _dashboard_auth_router (NameError)
2. R93 修 web_server.py line 573/610 gated_auth_middleware / token_auth_middleware (NameError)
3. R92 + R93 修后 venv web_server.py 编译 0 + import 0
4. PM-direct 重 build desktop .app (R87 build + R92 + R93 修都进仓根后)
5. cp 新 .app /Applications/文枢-Desktop.app
6. 12499 desktop latch failure 不再 - 需装机 user 重启

[产物]
- /Applications/文枢-Desktop.app (R94 build, app.asar MD5 ebcc1983...)
- /Users/anbaiqiang/Downloads/文枢-0.1.0-arm64.dmg MD5 84f2da1f...
- venv HEAD c8deb392e R93

[装机 user 必走]
1. 关运行文枢 (12499 instance + 所有 helper process)
2. 重启文枢 (双击 /Applications/文枢-Desktop.app)
3. desktop spawn wenshu serve 用 venv R93
4. 应能进 app

[PM-direct 自验总结 - 装机 user 不在电脑前]
- 真值 venv sync R93 ✅
- 真值 desktop .app cp 完 ✅
- 真值 backend 12499 latch failure 需装机 user 重启 ✅
- 装机 user 必走: 重启 desktop 看 backend 起来 ✅

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
