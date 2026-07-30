# WO-001BI-R76: 重 build WenShu-Setup.dmg 装包器 DMG (R74/R75 修烤进)

[装机 user 8/30 拍板真值]
- '每次做完所有事情, 我没有新的需求, 你不用问我是不是要重 build 你直接 build 就好了'

[Build 输入]
- 工作区: /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
- 命令: pnpm tauri build
- 编译 profile: release (53.93s)
- 入口: src-tauri/target/release/WenShu-Setup
- DMG 输出: src-tauri/target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg
- AC1: pnpm tauri build exit 0 ✓

[DMG 内容验证]
- 文枢.app/Contents/Info.plist ✓
- 文枢.app/Contents/MacOS/文枢-Setup (binary) ✓
- 文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.sh ✓
  - R55 UV_CACHE_DIR fix 在 line 66-67 (在 line 64 之后) ✓
  - line 66: UV_CACHE_DIR_DEFAULT="$WENSHU_HOME/cache/uv"
  - line 67: export UV_CACHE_DIR="${UV_CACHE_DIR:-$UV_CACHE_DIR_DEFAULT}"
  - line 1533-1534 + 1584: mkdir -p "$UV_CACHE_DIR" ✓
- 文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.ps1 ✓
  - R71 Seed-FreshInstallLanguage function 在 line 355 ✓
  - 调用点在 line 2474 ✓
- i18n: src/i18n/index.ts import zh 第一, default zh ✓
- src/routes/welcome.tsx 致谢语 (白名单): "基于 Hermes 修改而来" ✓
- 装包器 driver 拉 GitHub raw: install_script.rs:230/404 ✓
- AC3: DMG mount 后含 install.sh (R55 UV_CACHE_DIR fix 在 line 64 之后) ✓

[DMG 产物]
- 源 DMG: /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg
- cp 目标: /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
- 大小: ~5.4MB
- mtime: 2026-08-30 16:02
- 新 MD5: c40b821f1a6ff3c39b104b6aab5e3089
- AC2: 新 MD5 ≠ R57 df3b32d6e0add48b8ec9fd7f25426d6d + ≠ R54 5a8c6888 ✓

[历史 MD5 对照]
| 版本 | MD5 | 备注 |
|------|-----|------|
| R54 | 5a8c6888... | 浅克隆基线 |
| R57 | df3b32d6e0add48b8ec9fd7f25426d6d | bundled install.sh + R55 fix |
| **R76** | **c40b821f1a6ff3c39b104b6aab5e3089** | **R72/R73/R74/R75 烤进** |

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语 (未动)
- hermes-agent.nousresearch.com URL (未动)
- 上游仓 fork / node_modules/ / MIT 版权 (未动)

[AC 自决]
- AC1 pnpm tauri build exit 0 ✓
- AC2 新 MD5 c40b821f1a6ff3c39b104b6aab5e3089 ✓
- AC3 DMG mount 后含 install.sh (R55 fix 在 line 66-67, 64 之后) ✓
- AC4 自决 commit + push origin (下一步)
- AC5 落档本文件 ✓

[下一步]
- 飞书 DM 推装机 user 必走路径
- 装机 user: 双击 WenShu-Setup.dmg → 拖 文枢.app 到 /Applications/ → 双击启动
- 验: 不报 /cache/uv 错 + 不报 GitHub raw 拉错 + 装 ~/.wenshu-hermes ≤ 1.5GB
- 进 desktop APP 验 5 件 (100% 不卡 / Nous Portal 不见 / 中文化 / KEY 不卡 / stall emit)
