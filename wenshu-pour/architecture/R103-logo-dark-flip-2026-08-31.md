# WO-001BI-R103: 修 R102 LOGO 分配 - Electron + Tauri icons 全换 dark 套

[装机 user 8/31 拍]
- '效果不对，黑字配白底，白字配黑底'
- 截图: macOS dock 暗背景显示 文枢 .app 是黑字几乎看不见

[真值]
- R102 (commit b38560ef1) 把 LOGO 全替换成 light 套 (黑字透明背景)
- macOS dock 默认暗背景 -> 黑字 LOGO 几乎看不见
- 装包器 .app (WenShu-Setup) + desktop .app 都要用 DARK 套 (白字透明)
- Electron .icns / .ico / .png 是单一文件 - 必须全选 dark
- Tauri icon.png + 32/128/128@2x + icns + ico - 全选 dark
- brand-mark.tsx 内 light/dark 切换保留 (浅色模式下品牌卡白底, 显示黑字 LOGO)
- public/wenshu-logo-256.png = light (黑字)
- public/wenshu-logo-256-dark.png = dark (白字)
- public/apple-touch-icon.png = light (macOS Safari tab 用)

[修法]
- apps/desktop/assets/icon.png + icon.icns + icon.ico = dark (白字透明)
- apps/bootstrap-installer/src-tauri/icons/icon.png + 32x32 + 128x128 + 128x128@2x + icon.icns + icon.ico = dark
- apps/desktop/public/wenshu-logo-256.png = light
- apps/desktop/public/wenshu-logo-256-dark.png = dark
- apps/desktop/public/apple-touch-icon.png = light

[验]
- md5 apps/desktop/assets/icon.png = 4d7cd0354f1c7e94a6c56443f4e25c05 (dark)
- md5 apps/bootstrap-installer/src-tauri/icons/icon.png = 4d7cd0354f1c7e94a6c56443f4e25c05 (dark)
- vision: dock .app 显示白字 + 暗背景 = 看得清
