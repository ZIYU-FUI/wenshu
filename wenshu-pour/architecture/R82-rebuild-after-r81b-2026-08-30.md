# WO-001BI-R82: 重 build 装包器 DMG 含 R81b URL (gitcode.com/ZIYU1983/wenshu)

[装机 user 8/30 拍板真值]
- '全搞定了吗? 我可以跑安装体验了吗'
- 装机 user 已加 SSH key 到 atomgit.com (实际 gitcode.com 同家公司)
- R81b commit 31e1eb19e push 完成

[真值]
- ~/Downloads/WenShu-Setup.dmg 旧 MD5 60e7fc60748d843a2abc96d4a3f8c912 (R80 build, 含 R81 但 URL 仍 atomgit.com/ziyu-fui/wenshu)
- R81b 改了 URL 但 DMG 没重 build
- 装机 user 跑会 fallback 失败 (找不到 atomgit.com/ziyu-fui/wenshu)

[R82 实战真值 - PM-direct 兜底]
1. pnpm tauri build (57s rust) exit 0
2. 修复 install_script.rs R81 编译错 (R81 format! 3 placeholder 但 6 args + 死字符串)
3. 装包器 bundled install.sh 内含 R81b URL (gitcode.com/ZIYU1983/wenshu, 3 hits)
4. install.ps1 含 2 hits
5. tauri 自动重生全套 icons (placeholder 83B → 86KB 真 LOGO)
6. cp /Users/anbaiqiang/Downloads/WenShu-Setup.dmg

[产物]
- /Users/anbaiqiang/Downloads/WenShu-Setup.dmg MD5 bd34d2136fc10568f395a97532b0ce75 (5,644,628 bytes, 18:38:22)
- bundled install.sh 含 gitcode.com fallback URL

[装机 user 必走]
1. 双击 ~/Downloads/WenShu-Setup.dmg (MD5 bd34d2136...)
2. 拖 文枢.app 到 /Applications/
3. 双击启动 → bootstrap 走 bundled install.sh
4. 装 ~/.wenshu-hermes (拉 gitcode.com/ZIYU1983/wenshu, 装机 user 镜像仓)

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
