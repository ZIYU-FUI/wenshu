# WO-001BI-R87: desktop .app LOGO 统一到装包器白底黑字文枢毛笔字

[装机 user 8/30 out-of-band 拍板真值]
- 'WenShu-Setup 里的 APPlogo 是对的 (白底黑字文枢毛笔字)'
- '文枢-0.1.0-arm64 里的 APPlogo 是错的 (深色背景 + 白字)'
- '统一到 WenShu-Setup 里的 applogo (去掉深色背景)'

[PM-direct 8/30 兜底]
1. 从装包器 bundled icon.icns 反编译取 1024x1024 PNG (apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/icon.icns -> /tmp/setup-source.png)
2. cp /tmp/setup-source.png -> apps/desktop/assets/icon.png (MD5 96a0d5ac76fcf71cc14f6f85ecb940a4)
3. 用 sips 生成 11 块 (16/32/64/128/256/512/1024 + @2x variants) -> /tmp/wenshu.iconset
4. iconutil 合成 icon.icns (MD5 0a800d1df21fe3c787b69a429684519a, ~590KB)
5. pnpm build + pnpm dist:mac (130MB DMG)
6. python3 shutil.rmtree 旧 /Applications/文枢.app + copytree 新
7. cp DMG -> /Users/anbaiqiang/Downloads/文枢-0.1.0-arm64.dmg

[产物]
- /Users/anbaiqiang/Downloads/文枢-0.1.0-arm64.dmg MD5 84f2da1f4d5704e0ec460d5d3b533ebe (136MB)
- /Applications/文枢.app/Contents/Resources/icon.icns MD5 4690e60d174fac1c9db36ffd872c7fbe
- /Applications/文枢.app/Contents/Resources/app.asar MD5 ebcc1983b70b5269fd7ab941497837e0
- 视觉确认: LOGO = 白底黑字文枢毛笔字 (跟装包器完全一致)

[装机 user 必走 - 终态验收]
1. 双击 ~/Downloads/WenShu-Setup.dmg (装包器) → 装包器 LOGO = 白底黑字文枢
2. 拖 文枢.app 到 /Applications/
3. 双击启动 → bootstrap 走 bundled install.sh → 装 ~/.wenshu-hermes
4. /Applications/文枢.app LOGO = 同装包器 (白底黑字文枢毛笔字)
5. 验 5 件: 中文 tool/plugin/skill 描述 + setup 全中文 + du -sh ~/.wenshu-hermes ≤ 1.5GB + fallback 到 gitcode.com

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
