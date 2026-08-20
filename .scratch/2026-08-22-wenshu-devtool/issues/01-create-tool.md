# 01 — Tools/wenshu-devtool 创建 (Hermes tui_gateway 范式)

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (3 步, Hermes tui_gateway 范式)

1. `Tools/wenshu-devtool/wenshu_devtool.py` (Python 3.9+, 零依赖, 7 个 subcommand)
2. `Tools/wenshu-devtool/README.md` (用法 + 警告 + 老板 8/19 真值)
3. `Tools/wenshu-devtool/.gitignore` (临时文件不入 git)

## 验收

- [ ] 7 subcommand 全部 work (list_windows / screenshot / ui_dump / menu_dump / settings_dump / keychain_list / keychain_get)
- [ ] README.md 写清楚用法
- [ ] Package.swift 不动 (= 不 import Tools/)
- [ ] build/Wenshu.app 不含 devtool (= build script 不 cp)
- [ ] swift build / test exit 0
- [ ] 老板 macOS 真验: list_windows 返 wenshu NSWindow 真值

## 不动 (Q20)

- Package.swift (不动)
- Sources/WenshuApp/ (不动)
- Scripts/build-app.sh (不动)
- AppIcon.icon/ (不动)
