# 01 — LOGO 圆角加大 (重导 master + iconutil 重生 icns)

**What to build:**
老板 2026-08-21 验 LOGO 后反馈 "LOGO 没有圆角". 当前 LOGO 主图是老板 8/11 Sketch master 设计的, 带圆角但半径 < Apple HIG 标准 22% (= 1024×1024 下 ≈ 225 半径). macOS Dock 显的是 LOGO master 圆角, 不是 Apple 标准圆角.

修法 = 老板去 Sketch master 把圆角矩形路径加大到 22%, 重导主图 PNG, 我跑 iconutil 重生 icns.

**Blocked by:** 老板改 Sketch master (进行中).

**Status:** draft (等老板改完)

## 修法真值 (4 步)

1. 老板去 Sketch master 改主图圆角矩形路径, 1024×1024 下半径加大到 22% (≈ 225 半径)
2. 老板重导 3 个主图 PNG:
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-dark.png`
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-light.png`
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-mono.png`
3. 我用 iconutil 重生 3 份 icns:
   - 建 `wenshu-icon.iconset/` 目录, 跑 `sips -z <size> <png>` 生 11 个 retina 标准 reps (16/32/64/128/256/512/1024 + @2x), 重命名成 iconutil 标准 (`icon_16x16.png` + `icon_16x16@2x.png` 等)
   - 跑 `iconutil -c icns wenshu-icon.iconset/ -o AppIcon.dark.icns` (3 份各跑一次)
4. cp 3 份进 `Sources/WenshuApp/Resources/`, 改 `Scripts/build-app.sh` 加 cp mono. icns
5. 1 ticket 1 commit + Q33 icns 真值校验脚本 + 老板 macOS Dock 验圆角

## 不动

- AppIcon.icns (fallback 通用版保留)
- App.swift / Package.swift / Info.plist
- v0.21 chat ticket 01 (无关)

## 关联

- 依赖: 老板改 Sketch master
- **被合并**: ticket 04 (Logo Composer 替换 icns) — 老板用 LOGO.icon 后 ticket 01 自动过, 不需要跑

## 老板新决策 (8/21 16:00)

老板提供 `/Users/anbaiqiang/Desktop/LOGO.icon/` (= Apple Icon Composer 格式, 1 份真值源). macOS 27 自动派生 dark/light/tinted + platform mask, 不需要 icns 11 reps. ticket 01 + 02 + 04 合并成新 ticket 04 "用 Logo Composer 替换 icns 3 份".

ticket 01 当前状态 = **draft, 老板改 LOGO.icon 完成后跑 ticket 04, ticket 01 跳过**.