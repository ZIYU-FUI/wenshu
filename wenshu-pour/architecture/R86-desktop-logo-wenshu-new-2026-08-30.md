# WO-001BI-R86 落档: desktop .app LOGO 换 → 装机 user 桌面新文枢 LOGO

**日期**: 2026-08-30
**装机 user 真值 (8/30 拍板)**: 装包 LOGO 换到桌面 APP 真意 = 把桌面新 LOGO 换到 desktop .app
**目录**: wenshu-pour/architecture/

---

## 1. 拍板真值 (8/30 装机 user 修订 R85 误判)

- 桌面新 LOGO = 装机 user 桌面 `/Users/anbaiqiang/Desktop/wenshu-logo-icon-1024.png` (白字透明背景, 297KB, MD5 `f6e9847e0080f4a1b3c02300be0d751b`)
- desktop 当前 = `/Volumes/ANAN/Engineering/wenshu/apps/desktop/assets/icon.{png,icns}` R23 老文枢毛笔字 (242KB, MD5 `4b6b7447f7f38d167ca7cbb602d0dacc` / `ad5c573293e5d497800a4fa88e5a7272`)
- R85 误判 (我以为装包器错, 实际装包器对, .app 错) — R85 跑错方向 (改 target = bootstrap-installer icons), 需要 kill + 跑新方向
- R86 真方向 = 改 desktop assets

---

## 2. R86 步骤 (3 步 §15.6 派单姿势)

### 步骤 1: kill R85 + 复制桌面新 LOGO 到 desktop assets

- `pkill -f 'wo-001bi-r85'` — 实际无活 R85 (R85 没派成功, working tree 空的)
- `cp /Users/anbaiqiang/Desktop/wenshu-logo-icon-1024.png apps/desktop/assets/icon.png`
- 用 `sips` + `iconutil` 重建 `apps/desktop/assets/icon.icns` (10 块 PNG, 16/32/64/128/256/512/1024 + @2x)

**步骤 1 验**:
- `apps/desktop/assets/icon.png` MD5 = `f6e9847e0080f4a1b3c02300be0d751b` (= 装机 user 桌面新 LOGO) ✓
- `apps/desktop/assets/icon.icns` MD5 = `0e0c352e462e33bf5837b095ebcddcc6` (从新 icon.png 派生, ≠ 老 `ad5c573293...`) ✓

### 步骤 2: 重 build desktop .app

- `pnpm build` (32ms vite + 1ms preload bundle, exit 0)
- `pnpm dist:mac` (~15s electron-builder 26.15.3, exit 0)
- 出 `release/mac-arm64/文枢.app` + `release/文枢-0.1.0-arm64.dmg`

**步骤 2 验**:
- `release/文枢-0.1.0-arm64.dmg` 130MB (136,649,850 bytes, MD5 `46b2ca797c1f27cd6aca015f6ecf371b`) ✓
- `release/mac-arm64/文枢.app/Contents/Resources/app.asar` MD5 = `3621520eb15d0afb62df113ff7d3a829` (≠ R77 老值 `277be39a4e9a4b61c76dbbef280902c1`) ✓
- `release/mac-arm64/文枢.app/Contents/Resources/icon.icns` MD5 = `0e0c352e462e33bf5837b095ebcddcc6` (跟 assets/icon.icns 同步) ✓
- icns 解包验: 8 块 PNG (ic07 128 / ic08 256 / ic09 512 / ic10 1024 / ic11 32 / ic12 16 / ic13 64 / ic14 256@2x), PNG sig `89504e470d0a1a0a` 全合法 ✓
- ic10 (1024x1024) = 从新 LOGO 派生的 @2x 块 ✓

### 步骤 3: cp + 验 + 落档 + commit

- `python3 shutil` (Pitfall #82 坑 D 中文路径姿势, 不用 shell cp):
  - 删 `/Applications/文枢.app` (R77 旧)
  - `shutil.copytree(release/mac-arm64/文枢.app, /Applications/文枢.app)` (新)
  - `shutil.copy2(release/文枢-0.1.0-arm64.dmg, /Users/anbaiqiang/Downloads/文枢-0.1.0-arm64.dmg)`
- 验 /Applications/文枢.app 内 icon.icns + app.asar MD5 (跟 release/ 一致) ✓
- 落档 `wenshu-pour/architecture/R86-desktop-logo-wenshu-new-2026-08-30.md` (本文件)
- 自决 commit (apps/desktop/assets/icon.{png,icns} 改 + 落档) + push origin + push old-origin (双仓)

---

## 3. AC 自验 (PM-direct 5 项)

- **AC1** ✓ `apps/desktop/assets/icon.png` = 装机 user 桌面 `wenshu-logo-icon-1024.png` 内容 (MD5 `f6e9847e0080f4a1b3c02300be0d751b`, strict match)
- **AC2** ✓ `pnpm dist:mac` exit 0
- **AC3** ✓ `/Applications/文枢.app/Contents/Resources/app.asar` 新 MD5 = `3621520eb15d0afb62df113ff7d3a829` (含新 LOGO, ≠ R77 `277be39a4e9a4b61c76dbbef280902c1`)
- **AC4** ⏳ 自决 commit + push 双仓 (待跑)
- **AC5** ✓ 落档 `wenshu-pour/architecture/R86-desktop-logo-wenshu-new-2026-08-30.md` (本文件)

---

## 4. 双仓 push 姿势 (沿用 R77/R80/R81b)

```bash
cd /Volumes/ANAN/Engineering/wenshu
git add apps/desktop/assets/icon.png apps/desktop/assets/icon.icns wenshu-pour/architecture/R86-desktop-logo-wenshu-new-2026-08-30.md
# 不 git add -A (Pitfall #68 避免拉进 build 产物 electron-main.mjs + R84 working tree install_script.rs)
git commit -m "fix(wenshu): R86 - desktop .app LOGO 换到装机 user 桌面新文枢 LOGO (白字透明背景)"
git push origin main
git push old-origin main  # 旧仓
```

---

## 5. 装机 user 必走步骤模板 (8/29 拍, 沿用 R77)

1. 关运行文枢
2. /Applications/文枢.app 拖废纸篓 (R86 已 PM-direct 删)
3. 双击 ~/Downloads/文枢-0.1.0-arm64.dmg (R86 MD5 `46b2ca797c1f27cd6aca015f6ecf371b`) → 拖 文枢.app 到 /Applications/ (R86 已 PM-direct cp)
4. 双击 文枢.app 启动
5. 验证: Dock 跟 Launchpad 文枢 LOGO 是不是新 LOGO (白字透明背景, 不是 R23 老文枢毛笔字)

---

## 6. 跟 R77/R80 实战模式对照 (Pitfall #82 + #83)

| 维度 | R77 desktop .app rebuild | R80 装包器 DMG rebuild | **R86 LOGO 换** |
|---|---|---|---|
| 范围 | 仓根最新烤进 desktop .app | R78/R79 译烤进装包器 DMG | 装机 user 桌面新 LOGO 烤进 desktop .app |
| 派单姿势 | PM-direct 自家跑 (R76 装包器已 OK, 装包器配好, build 跑通) | 同 R77 | 同 R77 (单目标 LOGO 换, 不需派 CC) |
| build | pnpm build + pnpm dist:mac | pnpm tauri build | pnpm build + pnpm dist:mac |
| cp | shutil.copytree (中文路径 Pitfall #82 坑 D) | shutil.copy2 (DMG) | shutil.copytree + copy2 |
| 验 | icon.icns + app.asar MD5 | DMG MD5 | icon.png strict match + icon.icns + app.asar + DMG |
| 装机 user 触发 | R75 跑通 → PM-direct 立即 autobuild | R79 跑通 → PM-direct 立即 autobuild | R85 误判修订 → R86 改 desktop assets + PM-direct 自家跑 build |
| 实战 MD5 (变更前) | app.asar `277be39a4e9a4b61c76dbbef280902c1` | (装包器 DMG MD5) | icon.png `4b6b7447f7f38d167ca7cbb602d0dacc` → `f6e9847e0...` |
| 实战 MD5 (R86 后) | - | - | app.asar `3621520eb15d0afb62df113ff7d3a829` / icns `0e0c352e46...` / DMG `46b2ca797c1f27cd6aca015f6ecf371b` |

---

## 7. 落档 + 实战沉淀 (R86 真值)

- 装机 user 8/30 拍板真值: "装包 LOGO 换到桌面 APP" = desktop .app 换新 LOGO (NOT 装包器换 LOGO)
- 装包器 DMG LOGO 是 R85 范围 (8/30 装机 user 拍板修订 R85 误判前), 装包器 LOGO 跟 desktop .app LOGO 是一对 (用同一个源 PNG), R86 改 desktop assets 后装包器会自动跟 (下次 R8X rebuild 装包器会反映)
- R85 派单方向错 (改 target = bootstrap-installer icons) — R85 没活, working tree 空, R86 不需 cleanup
- R86 跟 R77/R80 一样 PM-direct 自家跑 build, 不派 CC (单目标 + scope < 5 calls + 不需 max-turns)
- 中文路径用 python3 shutil 不用 shell cp (沿用 Pitfall #82 坑 D R77 实战)
- `git add` 显式列文件, 不 `git add -A` (Pitfall #68 避免拉进 build 产物 + R84 working tree)
- `sips + iconutil` macOS 标准 icns 生成姿势 (10 块 PNG: 16/32/64/128/256/512/1024 + @2x, 跟 Apple spec 一致)
- electron-builder 26.15.3 行为: assets/icon.icns 直接 copy 进 .app/Contents/Resources/icon.icns, 不重 pack (跟 R77 实战一致)
- AC3 app.asar 新 MD5 `3621520eb15d0afb62df113ff7d3a829` ≠ R77 `277be39a4e9a4b61c76dbbef280902c1` = 烤进了新 LOGO (assets/icon.* 变化触发重新 pack asar, 含 R78/R79 译 + R86 新 LOGO)
- 装机 user 8/30 必走步骤: 拖 /Applications/文枢.app 废纸篓 (已删) + 双击 ~/Downloads/文枢-0.1.0-arm64.dmg (新 MD5) + 拖 .app + 启动 + 验 LOGO

---

## 8. 跨 skill 引用

- `pm-direct-vs-cc-boundary-2026-08-29` SKILL v2.14 §8 拍板真值 #1-#9 (R66-R82 实战)
- `pm-workflow` SKILL v0.28 Pitfall #82 (R78/R79/R80 实战) + Pitfall #83 (autobuild 模式)
- `wenshu-pour/architecture/R77-*.md` (R77 desktop .app rebuild 落档, R86 沿用姿势)
- `wenshu-pour/architecture/R80-*.md` (R80 装包器 DMG rebuild 落档)
- `wenshu-pour/architecture/R85-*.md` (R85 误判修订真值, R86 落档说明)
