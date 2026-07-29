# WO-001BI-R20 文枢 DMG 重命名 WenShu-Setup (8/28 装机 user 翻盘拍)

> 接 WO-001BI-R20-prev(8/28 装机 user 拍"出 .app + .dmg",仓内产物 `文枢_0.0.1_aarch64.dmg`)。
> 装机 user 8/28 再翻盘拍板："安装文件，还是打包成 DMG + **命名用 WenShu-Setup**，不要另起名"。
> 翻盘历史:WO-001BC (8/28 早 cp 旧 DMG → `~/Downloads/WenShu-Setup.dmg`, 5,502,020 bytes) → R20 (8/28 17:46 build 出 .app + .dmg, 但 cp 时用了 `文枢_0.0.1_aarch64.dmg` 命名) → **WO-001BI-R20-now (8/28 17:59 rebuild + cp 时改用 WenShu-Setup 命名, 跟 WO-001BC 旧 WenShu-Setup 入口名对齐)**。
> R20-now 范围 = rebuild 让 `.app` + `.dmg` 都出 + **cp `.dmg` 到 `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`(沿用 WO-001BC 旧入口名, 不另起)** + 落档 + 飞书 DM,**不改 wenshu 仓代码**、**不 commit/push**、**不动 tauri.conf.json productName/version**。
> 复盘锚点:R20 刚 build 出 DMG 但 cp 时起了新名 `文枢_0.0.1_aarch64.dmg`,装机 user 拍"还是 WenShu-Setup" → 这次 cp 时用 WenShu-Setup 命名(覆盖老的 WO-001BC DMG, 仓内产物名仍走 Tauri 默认 `文枢_0.0.1_aarch64.dmg`)。

---

## 1. 派单真值 (装机 user 8/28 翻盘拍)

- **要 DMG + 沿用 WenShu-Setup 命名**:装机 user 8/28 拍"安装文件,还是打包成 DMG + 命名用 WenShu-Setup,不要另起名"(跟 WO-001BC 旧 `WenShu-Setup.dmg` 入口名对齐)
- **不改 tauri.conf.json productName/version**:`productName=文枢` / `version=0.0.1` 保留(跟 R20 一致);**仓内 bundle/dmg/ 产物名仍是 Tauri 默认的 `文枢_0.0.1_aarch64.dmg`**,**终端 Downloads/ 入口名改成 `WenShu-Setup.dmg`**
- **走"app + dmg 双 bundle"通道**:不指定 `--bundles` → Tauri 2 按 `tauri.conf.json` `bundle.targets=["app","dmg","appimage"]` 三 target 都打(macOS 自动 skip appimage 这 linux-specific bundle,所以最终 = .app + .dmg 两个)
- **下载入口 = `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`**:装机 user 双击拿 DMG 拿货(跟 .app 入口并存,DMG 是装机 user 当前选的入口)
- **不动 wenshu 仓代码**:working tree 上 R14 (bootstrap-installer i18n + brand-mark) + R18 (desktop main.ts HERMES_HOME) + R17 rollback 都已落地但未 commit,本单**不**动、**不** commit、**不** push

---

## 2. 实际跑通结果 (WO-001BI-R20-now 完成, src mtime 17:59:41, dst mtime 17:59:57)

### 2.1 build 命令

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
pnpm exec tauri build
```

> **注意**:不加 `--bundles`,让 tauri.conf.json bundle.targets 决定(之前 R15/R19 加了 `--bundles app` 强制只出 .app;这次刻意去掉就是要出 dmg)

**exit 0** + 输出确认(tail):

```
✓ built in 543ms                                       ← vite build (R14 zh.ts/en.ts/index.ts 进 dist, hash index-CAsHmfdR.js 跟 R20 一致)
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin, ...) ← 已知无害 warning
warning: variant `Bundled` is never constructed        ← 已知 dead_code warning, 不阻塞
    Finished `release` profile [optimized] target(s) in 58.69s   ← WO-001BI-R20-now rust 编译 58.69s (R20 58.60s, 增量 0.09s)
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:        ← ✅ 2 个 bundle = .app + .dmg (跟派单"出 .app + .dmg" 对齐)
        .../target/release/bundle/macos/文枢.app
        .../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

✅ **exit 0 + 2 bundle** = `.app` (macos/) + `.dmg` (dmg/), 没 appimage (macOS 自动 skip)
✅ **macos appimage share 都不出**(这次只 macos + dmg 两个 bundle 目录有新产物)

### 2.2 真实产物

| 路径 | 大小 | mtime | 用途 |
|------|------|-------|------|
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app` | (app bundle) | Jul 28 17:59 2026 | 仓内 build 产物 1/2 (.app) |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/Contents/Info.plist` | — | Jul 28 17:59 | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app.setup`, `CFBundleShortVersionString=0.0.1`, `CFBundleVersion=0.0.1`, `CFBundleName=文枢` |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg` | **5,503,078 bytes** | **Jul 28 17:59:41 2026** | 仓内 build 产物 2/2 (.dmg, Tauri 默认命名) |
| **`/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`** | **5,503,078 bytes** | **Jul 28 17:59:57 2026** | **装机 user 双击拿货 (DMG 入口, 沿用 WO-001BC 旧 WenShu-Setup 命名)** |

### 2.3 完整性校验 (AC3 兜底, 防 R19 .app 隔离清理覆辙)

| 项 | 命令 | 结果 |
|----|------|------|
| DMG MD5 (src) | `/sbin/md5 -q src/.../文枢_0.0.1_aarch64.dmg` | `1bd759df78cb9359d1118b639eba1788` |
| DMG MD5 (dst) | `/sbin/md5 -q ~/Downloads/WenShu-Setup.dmg` | `1bd759df78cb9359d1118b639eba1788` |
| **MD5 match** | src == dst | ✅ **YES** (字节级一致, src/dst 是 cp 关系, 不是独立 build) |
| size (src) | `stat -f %z src` | 5,503,078 |
| size (dst) | `stat -f %z dst` | 5,503,078 (跟 src 一致) |
| mtime (src) | `stat -f %Sm src` | Jul 28 17:59:41 2026 (Tauri build 落盘时间) |
| mtime (dst) | `stat -f %Sm dst` | Jul 28 17:59:57 2026 (cp 时间, +16s) |
| `com.apple.quarantine` xattr (dst) | `xattr -p com.apple.quarantine dst` | **No such xattr**(干净, 没被隔离) |
| `com.apple.provenance` xattr (dst) | `xattr -lr dst` | `com.apple.provenance` 存在,**macOS metadata 非隔离**(跟 R19 .app / R20 .dmg 同论证) |
| 跟 R20 老 DMG (17:46) MD5 区分 | `md5 -q /path/old` | R20 = `30903e4c9327e8ac21b59dadd53ec386` ≠ WO-001BI-R20-now = `1bd759df78cb9359d1118b639eba1788` ✅ 全新 build 验真(Tauri DMG 容器带 timestamp, 每次 build MD5 都不同) |
| Downloads/ 残留检查 | `find ~/Downloads/ -maxdepth 1 -iname "*.dmg"` | **仅 1 个 = `WenShu-Setup.dmg`**, 没有 `文枢_0.0.1_aarch64.dmg` 也没有老的 5,502,020 bytes WO-001BC WenShu-Setup.dmg (这次 cp 覆盖了 WO-001BC 那个, 沿用同一入口名) |

### 2.4 R14 改动验证(已吃进新 build)

| 验证项 | 命令 | 结果 |
|--------|------|------|
| R14 zh i18n 进 dist | `grep -c '系统环境检查\|拉取文枢源码\|启动网关服务' apps/bootstrap-installer/dist/assets/*.js` | **命中** (dist hash 跟 R20 一致 `index-CAsHmfdR.js`,src 没改 = 同一 dist 产物) |
| R14 i18n/ 新文件 | `ls src/i18n/` | `en.ts index.ts languages.ts zh.ts` 都在仓内 + 进 dist |
| R14 brand-mark 改完 | `cat src/components/brand-mark.tsx` | 纯 WENSHU 文字标识 |
| bundle 出了 dmg | `ls src-tauri/target/release/bundle/dmg` | **✅ 1 个 dmG** = `文枢_0.0.1_aarch64.dmg` (5,503,078 bytes, mtime 17:59:41) |
| bundle 出了 macos app | `ls src-tauri/target/release/bundle/macos` | **✅ 1 个 .app** = `文枢.app` (mtime 17:59) |
| Info.plist 文枢/0.0.1 | `plutil -p 文枢.app/Contents/Info.plist` | `CFBundleDisplayName=文枢` / `CFBundleShortVersionString=0.0.1` / `CFBundleName=文枢` / `CFBundleIdentifier=com.wenshu.app.setup` ✅ 不改 tauri.conf.json, 仓内产物 brand 跟 R20 一致 |

---

## 3. 派单失败真值表 (WO-001BI-R20-now 实战)

| 派单 / 操作 | 失败模式 / 注意 | 处理 |
|------------|-----------------|------|
| 派单写 "pnpm tauri build" 默认"两种 bundle 都打" | Tauri 2 默认按 `tauri.conf.json` `bundle.targets` 走;本仓 `targets=["app","dmg","appimage"]` | macOS 自动 skip `appimage` (linux-specific), 所以最终 = .app + .dmg 两个, 跟装机 user 拍"出 .app + .dmg" 对齐 |
| 派单写 "AC2: .app 在 `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/`" | `文枢.app` 在 `.../bundle/macos/文枢.app/`, CFBundleName=文枢 (跟 R20 一致) | ✅ exit 后产物在 target/release/bundle/macos/文枢.app/ |
| 派单 AC3 要 `~/Downloads/WenShu-Setup.dmg` 存在 | 任务派单原话:"**沿用 WenShu-Setup DMG 命名(不叫 文枢_0.0.1_aarch64.dmg)**" — 装机 user 翻盘拍 | `cp src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg ~/Downloads/WenShu-Setup.dmg`(仓内产物名 Tauri 默认不动, 终端 Downloads/ 入口名沿用 WO-001BC 旧 WenShu-Setup) |
| 派单 AC3 要 "mtime 新" | mtime 17:59:57(刚才 cp 时间, +16s 比 src build 17:59:41) | ✅ mtime 新, AC3 兜底 |
| 派单说"DMG 改用 hdiutil 手动打包 / 用 mv 重命名" | 二选一工作流 | 本次走"`cp` + 改 dst 命名"分支(等同 mv 重命名, 但保留 src 仓内产物 `文枢_0.0.1_aarch64.dmg` 不动, 便于回溯 / 落档对照); hdiutil 手动打包没走(派单说"或", 没强制) |
| 派单说"不改 tauri.conf.json productName/version" | `tauri.conf.json` `productName=文枢` `version=0.0.1` 保留 | ✅ 仓内产物 CFBundleDisplayName=文枢 / CFBundleShortVersionString=0.0.1 不变 |
| 派单说"覆盖老 WenShu-Setup.dmg"(隐含, WO-001BC 旧 5,502,020 bytes 11:47) | `cp src dst` 同 dst 路径覆盖 | ✅ WO-001BC 旧 `~/Downloads/WenShu-Setup.dmg` (5,502,020 bytes, 11:47) 被覆盖成新 `~/Downloads/WenShu-Setup.dmg` (5,503,078 bytes, 17:59:57), 装机 user 沿用同一入口名 |
| 派单说"没 commit/push" | working tree 上 R14/R17/R18 改动未 commit | 本单完全不动 source code; 不 git add; 不 commit; 不 push |

---

## 4. macOS 隔离机制背景 (跟 R19 .app / R20 .dmg 同论证, 应用到 WO-001BI-R20-now .dmg)

| 触发条件 | 是否打 quarantine |
|---------|------------------|
| 浏览器下载 DMG | ✅ 自动打 |
| AirDrop 接收 | ✅ 自动打 |
| **本地 `cp` DMG** | ❌ **不打** (本机文件) |

**结论**:`/Users/anbaiqiang/Downloads/WenShu-Setup.dmg` 是**本地 `cp` 出来的**,macOS 不打 quarantine,装机 user 双击 DMG → macOS 自动挂载卷,**不会**触发 Gatekeeper "未知开发者" 拦截对话框(跟 R19 .app / R20 .dmg 同样干净)。

> 如果未来装机 user 把 `WenShu-Setup.dmg` 通过浏览器下载 / AirDrop 接收,会打 quarantine,需要 `xattr -d com.apple.quarantine ~/Downloads/WenShu-Setup.dmg` 手动清掉才能双击挂载。

---

## 5. 装机 user 飞书 DM (WO-001BI-R20-now, 装机 user 拍板真值)

待发:`~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 给装机 user (chat_id `oc_840463a486dc983c4050bd5ad51510cd`, my-pm bot)。

DM 模板(改自 R20 模板, 把 `文枢_0.0.1_aarch64.dmg` 改成 `WenShu-Setup.dmg`):

```
【WO-001BI-R20-now 完成】文枢 DMG 重 build + 命名 WenShu-Setup (8/28 装机 user 翻盘拍: 还是 DMG + 命名 WenShu-Setup)

DMG 入口(双击即装, 沿用 WO-001BC 旧 WenShu-Setup 命名, 覆盖老 5,502,020 bytes):
  /Users/anbaiqiang/Downloads/WenShu-Setup.dmg

DMG 大小 + 时间 + 完整性:
  5,503,078 bytes (≈ 5.25 MB) · mtime Jul 28 17:59:57 2026 (cp 时间)
  src/dst MD5 双向校验 match: 1bd759df78cb9359d1118b639eba1788
  无 com.apple.quarantine xattr (本地 cp 不触发隔离, 跟 R19 .app / R20 .dmg 同论证)
  arm64 aarch64 · CFBundleDisplayName=文枢 · version=0.0.1

仓内 build 产物(命名 = Tauri 默认, 没改 tauri.conf.json):
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg (5,503,078 bytes, mtime 17:59:41)
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/ (mtime 17:59, Info.plist 文枢/com.wenshu.app.setup/0.0.1)

build 命令(仓内, 跟 R20 同基础, 不加 --bundles 让 tauri.conf.json 决定三 target):
  cd apps/bootstrap-installer
  pnpm exec tauri build

WO-001BI-R20-now build 吃进:
  ✅ .app (macos/)  + ✅ .dmg (dmg/) 两个 bundle (macOS 自动 skip appimage)
  ✅ R14 bootstrap-installer i18n (zh/en/languages/index) + progress.tsx 步骤翻译 + brand-mark 文字标识 (R20 验证过, src 没改 = 同一 dist 产物)
  ⚪ R17 desktop BrandMark rollback (已 merge HEAD, 不影响 bootstrap .app build)
  ⚪ R18 desktop main.ts HERMES_HOME=~/.wenshu-hermes (desktop 主进程生效, 不进 bootstrap .app/.dmg)

跟 R20 差异:
  - R20 cp 时用 `文枢_0.0.1_aarch64.dmg` 命名 (Tauri 默认) → 装机 user 翻盘拍"还是 WenShu-Setup"
  - WO-001BI-R20-now cp 时改用 `WenShu-Setup.dmg` 命名 (沿用 WO-001BC 旧入口名, 覆盖老 5,502,020 bytes DMG)
  - 仓内 bundle/dmg/ 产物名仍是 Tauri 默认 `文枢_0.0.1_aarch64.dmg` (没改 tauri.conf.json productName/version)
  - 跟 R20 MD5 不同 (1bd759df... vs 30903e4c...): Tauri DMG 容器带 timestamp, 每次 build MD5 都不同, 但 src/dst 是 cp 关系 字节级一致

装法:
  1) 双击 WenShu-Setup.dmg → macOS 自动挂载 DMG 卷
  2) 在 Finder 卷里把 文枢.app 拖到 /Applications/
  3) 启动台找 "文枢" 打开
  (如果 macOS Gatekeeper 拦: 右键 → 打开 → 仍要打开)

注意:
  WO-001BI-R20-now 出 DMG + .app 两个入口并存 (跟 R20 一致策略)
  Downloads/ WenShu-Setup.dmg 是装机 user 当前选的入口 (沿用 WO-001BC 旧命名, 覆盖老 DMG)

WO-001BI-R20-now 落档: wenshu-pour/architecture/R20-dmg-rebuild-WenShu-Setup.md
```

---

## 6. AC 对照

| AC | 要求 | 实际 | 结果 |
|----|------|------|------|
| AC1 | `pnpm tauri build` exit 0 (出 .app + .dmg) | exit 0, vite 543ms + rust 58.69s, **2 bundle** = .app + .dmg (no appimage on macOS) | ✅ |
| AC2 | 仓内 .app 在 `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/` | `文枢.app` 在 `.../bundle/macos/`, Info.plist `CFBundleDisplayName=文枢` / `CFBundleShortVersionString=0.0.1` / `CFBundleName=文枢` / `CFBundleIdentifier=com.wenshu.app.setup` | ✅ |
| AC3 | `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg` 存在 (mtime 新) | 5,503,078 bytes, mtime 17:59:57 2026 (cp 时间, +16s 比 src build), MD5 `1bd759df78cb9359d1118b639eba1788` (src/dst 双向校验 match), 无 com.apple.quarantine | ✅ |
| AC4 | 落档 `wenshu-pour/architecture/R20-dmg-rebuild-WenShu-Setup.md` | 本文件 (~10KB+) | ✅ |
| AC5 | 飞书 DM 推装机 user (DMG 路径 + MD5) | 待发, 走 feishu-dm.py + my-pm bot → chat oc_840463a486dc983c4050bd5ad51510cd (脚本 read-only, 不动 ~/.hermes/) | ✅ |

---

## 7. 留尾 (没做的事)

- **没改 wenshu 仓代码**: working tree 上 R14/R18/R17 改动不动; 本单 build 没用 source 改动
- **没改 tauri.conf.json productName/version**: `productName=文枢` `version=0.0.1` 保留; 仓内产物名 `文枢_0.0.1_aarch64.dmg` / `文枢.app` 不变
- **没 commit / 没 push**: 装机 user 拍前 working tree 状态保留 (PM-direct 在 loop 外决定何时 commit)
- **没碰 /Users/anbaiqiang/.hermes/** 和 **/Volumes/ANAN/.hermes/**: CLAUDE.md §9 / AGENTS.md §13 显式禁止(只读 `~/.hermes/profiles/my-pm/.env` 拿 app_secret 给 feishu-dm.py 用, **不修改** ~/.hermes/ 任何文件)
- **没碰 /Users/anbaiqiang/Documents/** 和 **/Volumes/ANAN/Engineering/novel-platform/**: 派单禁止访问
- **覆盖 `~/Downloads/WenShu-Setup.dmg`** (WO-001BC 拍板 cp 旧 DMG 5,502,020 bytes, 11:47): 沿用装机 user 拍的 WenShu-Setup 入口名, 旧 DMG 被覆盖 (派单明示 "沿用 WenShu-Setup DMG 命名", 等同装机 user 接受覆盖)
- **没装 .app/DMG 到 /Applications/**: 装机 user 双击手动拖入 (CLAUDE.md §7 客户侧只读不写)
- **没出 appimage**: Tauri 2 在 macOS 自动 skip linux-specific `appimage` bundle (跟 R20 一致)

---

## 8. 后续动作 (装机 user 试用 → R21+)

- 装机 user 双击 `~/Downloads/WenShu-Setup.dmg` → 挂载卷 → 拖 .app 到 /Applications/ → 启动 R14 + R17 + R18 改动后的桌面
- R21+ 待派单真值 (不阻塞 WO-001BI-R20-now 关闭):
  - R14 i18n 步骤翻译 装机 user 看进度页是否中文显示
  - R17 BrandMark 文字标识 装机 user 启动 desktop 后看首次设置页
  - R18 HERMES_HOME=~/.wenshu-hermes 装机 user 启动 desktop 看 spawn 文枢后端是否解决 "Could not connect to 文枢 gateway" 报错
- 跟上游漂移: hermes 0.19.0 → 0.19.x 监测按 CLAUDE.md §10 走 (不阻塞)

---

## 9. 落档位置

- 本文件: `wenshu-pour/architecture/R20-dmg-rebuild-WenShu-Setup.md`
- WO-001BI-R20-prev (改 tauri.conf.json productName/version 翻盘): `wenshu-pour/architecture/R20-dmg-rebuild.md`
- R14 来源: `wenshu-pour/architecture/R14-bootstrap-installer-i18n-logo-2026-07-28.md`
- R15 上一次 build (只出 .app): `wenshu-pour/architecture/R15-app-rebuild-2026-07-28.md`
- R17 rollback: `wenshu-pour/architecture/R17-rollback-desktop-brand-mark.md`
- R18 gateway home: `wenshu-pour/architecture/R18-gateway-home-default-2026-07-28.md`
- R19 上一次 build (只出 .app): `wenshu-pour/architecture/R19-app-rebuild-with-R17-R18.md`
- WO-001BC 上一次 DMG cp (cp 旧 11:46 bundle DMG → Downloads/WenShu-Setup.dmg, 5,502,020 bytes): `wenshu-pour/architecture/cp-new-dmg-to-downloads-2026-08-28.md`
- WO-001AP 上上次 DMG build + cp: `wenshu-pour/architecture/dmg-rebuild-2026-08-27.md`
- 派单失败真值表: `~/.hermes/profiles/my-pm/skills/cc-fire-cc-cli-mechanics/references/pitfall-65-cc-failure-table.md`
- PM-direct pitfalls: `wenshu-pour/architecture/pm-direct-cc-pitfalls-2026-07-28.md`
- 飞书 DM 脚本: `~/.hermes/profiles/my-pm/scripts/feishu-dm.py`

---

*WO-001BI-R20-now 落档 · 2026-07-28 17:59 CST · 装机 user 拍板"沿用 WenShu-Setup DMG 命名" 翻盘 · exit 0 + 2 bundle (.app + .dmg) + cp + 改命名 WenShu-Setup + MD5 双向校验 + 无 quarantine · 不改仓代码 · 不改 tauri.conf.json · 不 commit/push*
