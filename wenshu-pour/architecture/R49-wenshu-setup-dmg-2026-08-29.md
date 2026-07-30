# WO-001BI-R49: 重 build WenShu-Setup.dmg 装包器 (8/29)

[装机 user 8/29 拍]
"我希望从 wenshu-setup 安装测试"

[R49 真值]
- bootstrap-installer 装包器 重 build
- 含 R30 install.sh (hermes-agent → wenshu-agent 改名)
- 含 R35 pypi 清华源 + 阿里 fallback
- 含 R25 welcome.tsx 中文致谢 ("基于 Hermes 修改而来")
- 含 R23 LOGO 文枢毛笔字
- 含 R14 装包阶段 10 步骤中文

[build 状态]
- pnpm tauri build exit 0 (1m 05s)
- warning: dead code ScriptSource::Bundled (pre-existing, 无关)

[产物]
- src-tauri/target/release/bundle/macos/文枢.app
- src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
- /Users/anbaiqiang/Downloads/WenShu-Setup.dmg (已 cp)

[装机 user 必走]
1. 关运行文枢 + 拖 /Applications/文枢.app 废纸篓
2. 双击 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
3. 拖 文枢.app 到 /Applications/
4. 双击 文枢.app 启动
5. 验 4 件: Nous Portal 不见 + 9 条中文化 + KEY 装入不卡 + 在线更新 stall emit
