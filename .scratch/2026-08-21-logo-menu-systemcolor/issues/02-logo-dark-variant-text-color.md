# 02 — LOGO dark variant 字色改浅 (跟系统色真值)

**What to build:**
老板 2026-08-21 验 LOGO 4 模式截图: Light OK, Dark 看不见 (深底 + 深字), Tinted OK. AppKit 自动选 dark/light icns, 但 dark variant 字色没改 (跟 light 一样深字), 跟系统色不完整.

**Blocked by:** 老板改 Sketch master (进行中).

**Status:** draft (跟 ticket 01 合并到 ticket 04)

## 修法真值 (2 步)

1. 老板去 Sketch master 把 dark variant 主图的 "文枢" 字色改浅 (= 跟深底对比, 类似 #F5F5F5 或 Apple system label color light)
2. 重导 `wenshu-icon-master-1024-dark.png`, 我跑 ticket 01 流程重导 icns
3. 1 ticket 1 commit + 老板 macOS Dock 切 Dark Mode 验

## 不动

- light / mono variant (当前 OK)
- App.swift / Package.swift / Info.plist

## 关联

- 依赖: 老板改 Sketch master
- **被合并**: ticket 04 (Logo Composer 替换 icns) — 老板 LOGO.icon 提供 1 份 PNG + icon.json, 改1 处全局生效, ticket 02 自动过