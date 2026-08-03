# WO-001BI-R112: 修 装包器 update UI 4 步 message 英文 (Rust + i18n + commit)

[装机 user 8/31 拍]
- "更新页面的步骤还是没有翻译, 感觉 CC 没有改对地方"
- 截图证明: 装包器 update 页面 4 步仍 3 步英文 (Preparing/Downloading/Rebuilding/Installing)

[真值 (R108 + R111 修但没修对地方)]
- R108 派单修了 apps/desktop/src/i18n/{en,zh,ja,zh-hant,types}.ts 的 "updates" 块 - 5 个 stage keys + message + stallHint
- R111 派单 CC 调研完了真因, 但只改了 en.ts + types.ts 2 个文件 (37 行) - 加 stageMessages 翻译键
- 但 4 步英文的真 source 没改:
  - apps/bootstrap-installer/src-tauri/src/update.rs:978-987 Rust 端硬编码 stage title
  - apps/desktop/electron/main.ts:3042/3066/3236 emitUpdateProgress 硬编码 message

[修法 (R112 PM-direct 收尾)]
1. apps/bootstrap-installer/src-tauri/src/update.rs:978-987 update_stages() 4 行 stage_info 改中文:
   - stage_info("handoff", "正在准备更新")
   - stage_info("update", "正在下载最新版本")
   - stage_info("rebuild", "正在重建桌面应用")
   - stage_info("install", "正在安装更新")
   - 保留 stage key 不变 (避免 breaking change)
2. apps/desktop/src/i18n/{zh,ja,zh-hant}.ts 加 "updates.stageMessages" 块 (20 keys, 跟 en.ts 一致)
3. apps/desktop/src/i18n/en.ts + types.ts R111 已加 stageMessages (key 一致)

[架构]
- 装包器 update UI 4 步 stage title 来源 = Rust update.rs stage_info() 第二参 (直接显示, 不走装包器 i18n)
- Rust 改成中文 = 装包器 UI 4 步自动显中文 (无需装包器 i18n 改)
- Desktop renderer 4 步 (更新通知) 走 desktop i18n stageMessages (R108 + R111 + R112 加)

[装机 user 验证]
- 跑 wenshu update --yes
- 装包器 update 页面 4 步全中文化:
  - 正在准备更新
  - 正在下载最新版本
  - 正在重建桌面应用
  - 正在安装更新

[版本号]
0.1.0 (装 user 拍 "基础版本不 bump")

[注意]
- R112 PM-direct 派 CC 跑 + 自家收尾 - 真因是 Rust 端改中文 (装 user 拍"基础版本不 bump, 中文 UI")
- 装包器 i18n 不动 (R65 已加 updates 块, 但装包器不走 i18n 翻译 stage title, 走 Rust 直接推)
- Desktop i18n stageMessages 翻译键完整 (en/zh/ja/zh-hant 4 语言 20 keys 一致)
