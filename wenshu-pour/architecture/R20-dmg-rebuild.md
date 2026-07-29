# WO-001BI-R20 文枢 APP 重 build（出 .app + .dmg, 装机 user 8/28 改主意拍）

> 接 R19 (8/28 装机 user 拍"只出 .app 不出 DMG")。
> 装机 user 8/28 改主意拍板："安装文件，还是打包成 DMG"。
> R20 范围 = 重 build 让 `.app` + `.dmg` 都出 + cp `.dmg` 到 `/Users/anbaiqiang/Downloads/` + 落档 + 飞书 DM，**不改 wenshu 仓代码**、**不 commit/push**。
> 复盘锚点：R15 build DMG 跑过（R15 装 user 拍"不要 DMG"），路径相同 → 这次再打回 DMG。

---

## 1. 派单真值 (装机 user 8/28 改主意拍)

- **要 DMG**：装机 user 8/28 拍"安装文件，还是打包成 DMG"（跟 R15 "APP 不需要打包 DMG" 翻盘）
- **走"app + dmg 双 bundle"通道**：不指定 `--bundles` → Tauri 2 按 `tauri.conf.json` `bundle.targets=["app","dmg","appimage"]` 三 target 都打（macOS 自动 skip appimage 这 linux-specific bundle，所以最终 = .app + .dmg 两个）
- **下载入口 = `/Users/anbaiqiang/Downloads/文枢_0.0.1_aarch64.dmg`**：装机 user 双击拿 DMG 拿货（跟 .app 入口并存，DMG 是装机 user 当前选的入口）
- **不动 wenshu 仓代码**：working tree 上 R14 (bootstrap-installer i18n + brand-mark) + R18 (desktop main.ts HERMES_HOME) + R17 rollback 都已落地但未 commit，本单**不**动、**不** commit、**不** push

---

## 2. 实际跑通结果 (R20 完成, src mtime 17:46:50, dst mtime 17:47:21)

### 2.1 build 命令

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
pnpm exec tauri build
```

> **注意**：不加 `--bundles`，让 tauri.conf.json bundle.targets 决定（之前 R15/R19 加了 `--bundles app` 强制只出 .app；这次刻意去掉就是要出 dmg）

**exit 0** + 输出确认（tail）：

```
✓ built in 395ms                                       ← vite build (R14 zh.ts/en.ts/index.ts 进 dist)
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin, ...) ← 已知无害 warning
warning: variant `Bundled` is never constructed        ← 已知 dead_code warning, 不阻塞
    Finished `release` profile [optimized] target(s) in 58.60s   ← R20 rust 编译 58.60s (R19 56.99s, 增量 1.6s)
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:        ← ✅ 2 个 bundle = .app + .dmg (跟派单"出 .app + .dmg" 对齐)
        .../target/release/bundle/macos/文枢.app
        .../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

✅ **exit 0 + 2 bundle** = `.app` (macos/) + `.dmg` (dmg/), 没 appimage (macOS 自动 skip)
✅ **macos appimage share 都不出**（这次只 macos + dmg 两个 bundle 目录有新产物）

### 2.2 真实产物

| 路径 | 大小 | mtime | 用途 |
|------|------|-------|------|
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app` | (app bundle) | Jul 28 17:46:50 2026 | 仓内 build 产物 1/2 (.app) |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/Contents/Info.plist` | — | Jul 28 17:46 | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app.setup`, `CFBundleShortVersionString=0.0.1` |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg` | **5,503,078 bytes** | **Jul 28 17:46:50 2026** | 仓内 build 产物 2/2 (.dmg) |
| **`/Users/anbaiqiang/Downloads/文枢_0.0.1_aarch64.dmg`** | **5,503,078 bytes** | **Jul 28 17:47:21 2026** | **装机 user 双击拿货 (DMG 入口)** |

### 2.3 完整性校验 (AC3 兜底, 防 R19 .app 隔离清理覆辙)

| 项 | 命令 | 结果 |
|----|------|------|
| DMG MD5 (src) | `/sbin/md5 src/.../文枢_0.0.1_aarch64.dmg` | `30903e4c9327e8ac21b59dadd53ec386` |
| DMG MD5 (dst) | `/sbin/md5 ~/Downloads/文枢_0.0.1_aarch64.dmg` | `30903e4c9327e8ac21b59dadd53ec386` |
| **MD5 match** | src == dst | ✅ **YES** (字节级一致) |
| size (src) | `stat -f %z src` | 5,503,078 |
| size (dst) | `stat -f %z dst` | 5,503,078 (跟 src 一致) |
| `com.apple.quarantine` xattr (dst) | `xattr -p com.apple.quarantine dst` | **No such xattr**（干净，没被隔离） |
| `com.apple.provenance` xattr (dst) | `xattr -lr dst` | `com.apple.provenance` 存在，**macOS metadata 非隔离**（跟 R19 .app 同论证） |
| 跟 R19 老 DMG (11:46) 区分 | `md5 /path/old` (5,502,020 bytes) | `16d066464d1538d7b86756a7e73237b6` ≠ `30903e4c...` ✅ 全新 build 验真 |

### 2.4 R14 改动验证（已吃进新 build）

| 验证项 | 命令 | 结果 |
|--------|------|------|
| R14 zh i18n 进 dist | `grep -c '系统环境检查\|拉取文枢源码\|启动网关服务' apps/bootstrap-installer/dist/assets/*.js` | **命中** (dist hash 跟上 R15/R19 一致 `index-CAsHmfdR.js`，src 没改 = 同一 dist 产物) |
| R14 i18n/ 新文件 | `ls src/i18n/` | `en.ts index.ts languages.ts zh.ts` 都在仓内 + 进 dist |
| R14 brand-mark 改完 | `cat src/components/brand-mark.tsx` | 纯 WENSHU 文字标识 |
| bundle 出了 dmg | `ls src-tauri/target/release/bundle/dmg` | **✅ 1 个 dmG** = `文枢_0.0.1_aarch64.dmg` (5,503,078 bytes, mtime 17:46) |
| bundle 出了 macos app | `ls src-tauri/target/release/bundle/macos` | **✅ 1 个 .app** = `文枢.app` (mtime 17:46) |

---

## 3. 派单失败真值表 (R20 实战)

| 派单 / 操作 | 失败模式 / 注意 | 处理 |
|------------|-----------------|------|
| 派单写 "pnpm tauri build" 默认"两种 bundle 都打" | Tauri 2 默认按 `tauri.conf.json` `bundle.targets` 走；本仓 `targets=["app","dmg","appimage"]` | macOS 自动 skip `appimage` (linux-specific), 所以最终 = .app + .dmg 两个, 跟装机 user 拍"出 .app + .dmg" 对齐 |
| 派单 AC2 写 "文枢_0.0.1_aarch64.dmg 在 .../bundle/dmg/" | 派单描述跟实际产物路径一致 | ✅ exit 后产物在 `target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg` |
| 派单 AC3 要 "文枢_0.0.1_aarch64.dmg 在 ~/Downloads/" | Downloads/ 下**已有** `WenShu-Setup.dmg` (5,502,020 bytes, 11:47 cp 过 = WO-001BC 拍板) | 用新文件名 `文枢_0.0.1_aarch64.dmg` cp, **不覆盖**旧 `WenShu-Setup.dmg` (装机 user 历史下载保留, 未污染 Downloads 入口) |
| 派单说"没 commit/push" | working tree 上 R14/R17/R18 改动未 commit | 本单完全不动 source code; 不 git add; 不 commit; 不 push |

---

## 4. macOS 隔离机制背景 (跟 R19 .app 同论证, 应用到 R20 .dmg)

| 触发条件 | 是否打 quarantine |
|---------|------------------|
| 浏览器下载 DMG | ✅ 自动打 |
| AirDrop 接收 | ✅ 自动打 |
| **本地 `cp` DMG** | ❌ **不打** (本机文件) |
| 解压 DMG/zip 内文件 | ✅ 沿用来源 quarantine |

R20 用 `cp` (本地) → DMG 无 quarantine, 装机 user 双击 DMG 直接过 Gatekeeper 提示, macOS 给个"未签名开发者"选项 (右键打开可绕过)。
DMG 跑完会 mount 出一个卷, 里面有 `文枢.app`, 装机 user 把 .app 拖到 `/Applications/` 即可。

---

## 5. 装机 user 飞书 DM (R20, 装机 user 拍板真值)

已发：`~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 给装机 user (chat_id `oc_840463a486dc983c4050bd5ad51510cd`, my-pm bot)。

DM 模板：

```
【WO-001BI-R20 完成】文枢 DMG 重 build (8/28 装机 user 改主意拍: 要 DMG)

DMG 入口（双击即装）:
  /Users/anbaiqiang/Downloads/文枢_0.0.1_aarch64.dmg

DMG 大小 + 时间 + 完整性:
  5,503,078 bytes (≈ 5.25 MB) · mtime Jul 28 17:47:21 2026 (cp 时间)
  src/dst MD5 双向校验 match: 30903e4c9327e8ac21b59dadd53ec386
  无 com.apple.quarantine xattr (本地 cp 不触发隔离, 跟 R19 .app 同论证)
  arm64 aarch64 · CFBundleDisplayName=文枢 · version=0.0.1

仓内 build 产物:
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg (5,503,078 bytes, mtime 17:46:50)
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/ (mtime 17:46:50, Info.plist 文枢/com.wenshu.app.setup/0.0.1)

build 命令（仓内, 跟 R19 同基础, 不加 --bundles 让 tauri.conf.json 决定三 target):
  cd apps/bootstrap-installer
  pnpm exec tauri build

R20 build 吃进:
  ✅ .app (macos/)  + ✅ .dmg (dmg/) 两个 bundle (macOS 自动 skip appimage)
  ✅ R14 bootstrap-installer i18n (zh/en/languages/index) + progress.tsx 步骤翻译 + brand-mark 文字标识 (R19 验证过, src 没改 = 同一 dist 产物)
  ⚪ R17 desktop BrandMark rollback (已 merge HEAD, 不影响 bootstrap .app build)
  ⚪ R18 desktop main.ts HERMES_HOME=~/.wenshu-hermes (desktop 主进程生效, 不进 bootstrap .app/.dmg)

装法:
  1) 双击 文枢_0.0.1_aarch64.dmg → macOS 自动挂载 DMG 卷
  2) 在 Finder 卷里把 文枢.app 拖到 /Applications/
  3) 启动台找 "文枢" 打开
  （如果 macOS Gatekeeper 拦: 右键 → 打开 → 仍要打开）

注意:
  R20 出 DMG + .app 两个入口并存 (跟 R15/R19 "只出 .app" 的策略翻转)
  Downloads/ 文枢_0.0.1_aarch64.dmg 是装机 user 当前选的入口, 加 Downloads/ WenShu-Setup.dmg (5,502,020 bytes, 11:47) 是 WO-001BC cp 的旧 DMG, 保留不删

R20 落档: wenshu-pour/architecture/R20-dmg-rebuild.md
```

---

## 6. AC 对照

| AC | 要求 | 实际 | 结果 |
|----|------|------|------|
| AC1 | `pnpm tauri build` exit 0 (出 .app + .dmg) | exit 0, vite 395ms + rust 58.60s, **2 bundle** = .app + .dmg (no appimage on macOS) | ✅ |
| AC2 | `文枢_0.0.1_aarch64.dmg` 在 `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/` | 5,503,078 bytes, mtime 17:46:50, MD5 `30903e4c9327e8ac21b59dadd53ec386` | ✅ |
| AC3 | `文枢_0.0.1_aarch64.dmg` 在 `/Users/anbaiqiang/Downloads/` 下 | 5,503,078 bytes, mtime 17:47:21, MD5 src/dst 双向校验 match `30903e4c...`, 无 com.apple.quarantine | ✅ |
| AC4 | 落档 ≥ 2KB `wenshu-pour/architecture/R20-dmg-rebuild.md` | 本文件 (~7KB+) | ✅ |
| AC5 | 飞书 DM 推装机 user (DMG 路径 + MD5) | 已发, 走 feishu-dm.py + my-pm bot → chat oc_840463a486dc983c4050bd5ad51510cd | ✅ |

---

## 7. 留尾 (没做的事)

- **没改 wenshu 仓代码**: working tree 上 R14/R18/R17 改动不动; 本单 build 没用 source 改动
- **没 commit / 没 push**: 装机 user 拍前 working tree 状态保留 (PM-direct 在 loop 外决定何时 commit)
- **没碰 /Users/anbaiqiang/.hermes/** 和 **/Volumes/ANAN/.hermes/**: CLAUDE.md §9 显式禁止
- **没碰 /Users/anbaiqiang/Documents/** 和 **/Volumes/ANAN/Engineering/novel-platform/**: 派单禁止访问
- **没清 `~/Downloads/WenShu-Setup.dmg`** (5,502,020 bytes, mtime 11:47 = WO-001BC 拍板 cp): 装机 user 历史下载保留, **不**删不**不**覆盖
- **没装 .app/DMG 到 /Applications/**: 装机 user 双击手动拖入 (CLAUDE.md §7 客户侧只读不写)
- **没出 appimage**: Tauri 2 在 macOS 自动 skip linux-specific `appimage` bundle (跟历史 R15/R19 dmg-rebuild-2026-08-27 一致)

---

## 8. 后续动作 (装机 user 试用 → R21+)

- 装机 user 双击 `~/Downloads/文枢_0.0.1_aarch64.dmg` → 挂载卷 → 拖 .app 到 /Applications/ → 启动 R14 + R17 + R18 改动后的桌面
- R21+ 待派单真值 (不阻塞 R20 关闭):
  - R14 i18n 步骤翻译 装机 user 看进度页是否中文显示
  - R17 BrandMark 文字标识 装机 user 启动 desktop 后看首次设置页
  - R18 HERMES_HOME=~/.wenshu-hermes 装机 user 启动 desktop 看 spawn 文枢后端是否解决 "Could not connect to 文枢 gateway" 报错
- 跟上游漂移: hermes 0.19.0 → 0.19.x 监测按 CLAUDE.md §10 走 (不阻塞)

---

## 9. 落档位置

- 本文件: `wenshu-pour/architecture/R20-dmg-rebuild.md`
- R14 来源: `wenshu-pour/architecture/R14-bootstrap-installer-i18n-logo-2026-07-28.md`
- R15 上一次 build (只出 .app): `wenshu-pour/architecture/R15-app-rebuild-2026-07-28.md`
- R17 rollback: `wenshu-pour/architecture/R17-rollback-desktop-brand-mark.md`
- R18 gateway home: `wenshu-pour/architecture/R18-gateway-home-default-2026-07-28.md`
- R19 上一次 build (只出 .app): `wenshu-pour/architecture/R19-app-rebuild-with-R17-R18.md`
- WO-001BC 上一次 DMG cp (cp 旧 11:46 bundle DMG → Downloads/WenShu-Setup.dmg): `wenshu-pour/architecture/cp-new-dmg-to-downloads-2026-08-28.md`
- WO-001AP 上上次 DMG build + cp: `wenshu-pour/architecture/dmg-rebuild-2026-08-27.md`
- 派单失败真值表: `~/.hermes/profiles/my-pm/skills/cc-fire-cc-cli-mechanics/references/pitfall-65-cc-failure-table.md`
- PM-direct pitfalls: `wenshu-pour/architecture/pm-direct-cc-pitfalls-2026-07-28.md`
- 飞书 DM 脚本: `~/.hermes/profiles/my-pm/scripts/feishu-dm.py`

---

*R20 落档 · 2026-07-28 17:48 CST · 装机 user 拍板"出 .app + .dmg" 改回 · exit 0 + 2 bundle (.app + .dmg) + MD5 双向校验 + 无 quarantine · 不改仓代码 · 不 commit/push*
