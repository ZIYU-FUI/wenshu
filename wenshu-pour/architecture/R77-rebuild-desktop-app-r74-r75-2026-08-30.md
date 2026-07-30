# WO-001BI-R77: 重 build desktop .app (R74/R75 修烤进)

[装机 user 8/30 拍板真值]
- '我去验收安装, 是不是所有修改应用上去'
- '我装的时候就是我们刀过后的版本'

[真值]
22 commit 已 push origin/main (f03365b88 R75 最新). 仓根只 build 装包器 DMG (R76), 不 build desktop .app. 桌面 APP 启动 R74/R75 web_server.py 修需要新 .app binary.

[PM-direct 8/30 兜底]
1. cd apps/desktop + pnpm build (32ms) + pnpm dist:mac (DMG exit 0)
2. cp /Applications/文枢.app + cp /Users/anbaiqiang/Downloads/文枢-0.1.0-arm64.dmg
3. 验 app.asar 含 R74/R75 修 (web_server.py lazy import inline stub 化)

[产物 MD5]
- app.asar: 277be39a4e9a4b61c76dbbef280902c1 (8,494,523 bytes)
- 文枢-0.1.0-arm64.dmg: b368f6b35b3b864a45e0512e2324e62a (135,633,935 bytes)
- WenShu-Setup.dmg: c40b821f1a6ff3c39b104b6aab5e3089 (5,642,276 bytes, R76 build)

[装机 user 必走]
1. 关运行文枢
2. /Applications/文枢.app 拖废纸篓 (已经是新 binary 了, 不需要重装)
3. 双击 ~/Downloads/WenShu-Setup.dmg (R76 build, 含 R55/R57/R71 bundled) → 拖 文枢.app 到 /Applications/
4. 双击启动 → bootstrap 走 bundled install.sh (R53/R55/R57 修)
5. 验 5 件 + du -sh ~/.wenshu-hermes ≤ 1.5GB

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
