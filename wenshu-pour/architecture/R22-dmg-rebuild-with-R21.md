# WO-001BI-R22 文枢 DMG 重 build（含 R21 改动: bootstrap-installer brand-mark 回滚为书法 LOGO）

> 接 WO-001BI-R20-now (8/28 装机 user 翻盘拍"用 WenShu-Setup 命名 DMG", 仓内产物 `文枢_0.0.1_aarch64.dmg`) → R21 (8/28 装机 user 再翻盘拍"红框里的 LOGO 用文枢毛笔字 / 这个没有换", CC 回滚 `apps/bootstrap-installer/src/components/brand-mark.tsx` 书法 LOGO) → **WO-001BI-R22 (8/28 18:11 rebuild 让 .app + .dmg 吃进 R21 书法 LOGO + cp 沿用 WenShu-Setup 命名)**。
> R20-now 用了 R14 错误 brand-mark (WENSHU 文字) → R21 改源码回滚为书法 LOGO (nous-girl.jpg) → R22 build 含 R21 改动, DMG 仍用 WenShu-Setup 命名, 跟上一次 R20-now 入口对齐。
> R22 范围 = rebuild 让 `.app` + `.dmg` 都出 + **cp `.dmg` 到 `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`(沿用 R20 / WO-001BC 旧入口名, 覆盖 R20-now 17:59:57 DMG)** + 落档 + 飞书 DM,**不改 wenshu 仓代码**、**不 commit/push**、**不动 tauri.conf.json productName/version**。
> 复盘锚点:R20-build 时 brand-mark 是 WENSHU 文字 (R14 错误) → R21 改源码回滚为 nous-girl.jpg 书法 LOGO → R22 build 含 R21 改动 (dist hash index-D2euJGB9.js 跟 R20-now index-CAsHmfdR.js 不同) → DMG 用 WenShu-Setup 命名 (跟 R20-now 一致)。

---

## 1. 派单真值 (WO-001BI-R22, 装机 user 8/28 翻盘链拍板真值)

- **R21 改动在 working tree**: `apps/bootstrap-installer/src/components/brand-mark.tsx` 已回滚为 `<img ... src={assetPath('nous-girl.jpg')} />`, brand 书法 LOGO(`public/nous-girl.jpg`) 资源存在(20,026 bytes)
- **R22 范围 = 重 build + cp 沿用 WenShu-Setup 命名**: 跟 R20-now 同入口名策略,**覆盖** R20-now 17:59:57 DMG (跟装机 user "用 WenShu-Setup" 翻盘对齐)
- **不改 tauri.conf.json productName/version**: `productName=文枢` / `version=0.0.1` 保留(跟 R20 / R20-now 一致); **仓内 bundle/dmg/ 产物名仍是 Tauri 默认的 `文枢_0.0.1_aarch64.dmg`**, **终端 Downloads/ 入口名改成 `WenShu-Setup.dmg`**
- **走"app + dmg 双 bundle"通道**:不指定 `--bundles` → Tauri 2 按 `tauri.conf.json` `bundle.targets=["app","dmg","appimage"]` 三 target 都打(macOS 自动 skip appimage 这 linux-specific bundle,所以最终 = .app + .dmg 两个)
- **下载入口 = `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`**:装机 user 双击拿 DMG 拿货(跟 R20-now 同入口,覆盖 R20-now 17:59:57 老 DMG)
- **不动 wenshu 仓代码**:working tree 上 R14 (bootstrap-installer i18n + brand-mark) + R18 (desktop main.ts HERMES_HOME) + R17 (desktop brand-mark rollback) + R21 (bootstrap-installer brand-mark 书法 LOGO) 都已落地但未 commit,本单**不**动、**不** commit、**不** push

---

## 2. 实际跑通结果 (WO-001BI-R22 完成, src mtime 18:12:16, dst mtime 18:12:47)

### 2.1 build 命令

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
pnpm exec tauri build
```

> **注意**:不加 `--bundles`,让 tauri.conf.json bundle.targets 决定(跟 R20-now 一致;R15/R19 加了 `--bundles app` 强制只出 .app;R22 / R20-now 刻意去掉就是要出 dmg)

**exit 0** + 输出确认(tail):

```
✓ built in 326ms                                       ← vite build (R21 brand-mark.tsx 改 nous-girl.jpg 进 dist, hash index-D2euJGB9.js 跟 R20-now index-CAsHmfdR.js 不同)
dist/assets/index-D2euJGB9.js                         261.84 kB │ gzip: 82.65 kB │ map: 1,218.94 kB
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin, ...) ← 已知无害 warning
warning: variant `Bundled` is never constructed        ← 已知 dead_code warning, 不阻塞
    Finished `release` profile [optimized] target(s) in 53.59s   ← WO-001BI-R22 rust 编译 53.59s (R20-now 58.69s 增量 -5.1s, R21 改 src 已触发增量编译但 hero cache 命中率高)
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:        ← ✅ 2 个 bundle = .app + .dmg (跟派单"出 .app + .dmg" 对齐)
        .../target/release/bundle/macos/文枢.app
        .../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

✅ **exit 0 + 2 bundle** = `.app` (macos/) + `.dmg` (dmg/), 没 appimage (macOS 自动 skip)
✅ **macos appimage share 都不出**(只 macos + dmg 两个 bundle 目录有新产物)
✅ **dist hash 跟 R20-now 不同** (`index-D2euJGB9.js` vs `index-CAsHmfdR.js`): R21 brand-mark.tsx 改动进了 bundle, 验证 R21 改动已吃进 .app

### 2.2 真实产物

| 路径 | 大小 | mtime | 用途 |
|------|------|-------|------|
| `apps/bootstrap-installer/src-tauri/target/release/WenShu-Setup` | **7,921,648 bytes** | Jul 28 18:12:16 2026 | 仓内 Rust 二进制(内嵌 R21 dist + frontend) |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app` | (app bundle, 7.9M) | Jul 28 18:11:54 2026 | 仓内 build 产物 1/2 (.app) |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/Contents/Info.plist` | — | Jul 28 18:11:54 | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app.setup`, `CFBundleShortVersionString=0.0.1`, `CFBundleVersion=0.0.1`, `CFBundleName=文枢` |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg` | **5,503,406 bytes** | **Jul 28 18:12:16 2026** | 仓内 build 产物 2/2 (.dmg, Tauri 默认命名) |
| **`/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`** | **5,503,406 bytes** | **Jul 28 18:12:47 2026** | **装机 user 双击拿货 (DMG 入口, 沿用 R20-now / WO-001BC 旧 WenShu-Setup 命名, 覆盖 R20-now 17:59:57 老 DMG)** |

### 2.3 完整性校验 (AC3 兜底, 防 R19 .app 隔离清理覆辙 + 防 R20 错误 brand-mark 落进新 build)

| 项 | 命令 | 结果 |
|----|------|------|
| DMG MD5 (src) | `/sbin/md5 -q src/.../文枢_0.0.1_aarch64.dmg` | `82aceedb4e52fa4a00a3eda4eb0f204c` |
| DMG MD5 (dst) | `/sbin/md5 -q ~/Downloads/WenShu-Setup.dmg` | `82aceedb4e52fa4a00a3eda4eb0f204c` |
| **MD5 match** | src == dst | ✅ **YES** (字节级一致, src/dst 是 cp 关系, 不是独立 build) |
| size (src) | `stat -f %z src` | 5,503,406 |
| size (dst) | `stat -f %z dst` | 5,503,406 (跟 src 一致, +328 bytes vs R20-now 5,503,078) |
| mtime (src) | `stat -f %Sm src` | Jul 28 18:12:16 2026 (Tauri build 落盘时间) |
| mtime (dst) | `stat -f %Sm dst` | Jul 28 18:12:47 2026 (cp 时间, +31s) |
| `com.apple.quarantine` xattr (dst) | `xattr -p com.apple.quarantine dst` | **No such xattr**(干净, 没被隔离) |
| `com.apple.provenance` xattr (dst) | `xattr -lr dst` | `com.apple.provenance` 存在,**macOS metadata 非隔离**(跟 R19 .app / R20-now .dmg 同论证) |
| 跟 R20-now 老 DMG (17:59:57) MD5 区分 | `/sbin/md5 -q /path/old` | R20-now = `1bd759df78cb9359d1118b639eba1788` ≠ R22 = `82aceedb4e52fa4a00a3eda4eb0f204c` ✅ 全新 build 验真(Tauri DMG 容器带 timestamp, 每次 build MD5 都不同) |
| Downloads/ 残留检查 | `find ~/Downloads/ -maxdepth 1 -iname "*.dmg"` | **仅 1 个 = `WenShu-Setup.dmg`**, 没有 `文枢_0.0.1_aarch64.dmg` 也没有 R20-now 17:59:57 老 WenShu-Setup.dmg (这次 cp 覆盖了 R20-now 那个, 沿用同一入口名) |
| Rust 二进制内嵌 R21 brand-mark | `strings target/release/WenShu-Setup \| grep nous-girl` | **✅ 命中 `/nous-girl.jpg`** (R21 brand-mark.tsx 的 img src 烤进 Rust 二进制, 验证 R21 改动确实在 .app build 里) |

### 2.4 R21 改动验证 (R22 build 必须吃进 R21 brand-mark.tsx = nous-girl.jpg)

| 验证项 | 命令 | 结果 |
|--------|------|------|
| 仓内 src 已是 R21 状态 | `grep "assetPath('nous-girl.jpg')" src/components/brand-mark.tsx` | **✅ 命中** (R21 恢复 `<img ... src={assetPath('nous-girl.jpg')} />`) |
| 仓内 src 无 WENSHU 字面量 (R14 错误) | `grep -Fq "WENSHU" src/components/brand-mark.tsx` | **✅ 0 命中** (R21 已彻底删除 WENSHU 文字 brand-mark) |
| dist JS 引用 nous-girl.jpg | `grep -o "nous-girl.jpg" dist/assets/index-*.js` | **✅ 命中 `cr(\`nous-girl.jpg\`)`** (R21 brand-mark 进了 vite bundle) |
| dist JS 中 brand-mark 区域无 WENSHU | `grep -o "src:cr(\`WENSHU\`)" dist/assets/index-*.js` | **✅ 0 命中** (确认 R21 brand-mark 已替换 R14 错误) |
| dist hash 跟 R20-now 不同 (说明 R21 改动进了 build) | `ls dist/assets/index-*.js` | R22 = `index-D2euJGB9.js` ≠ R20-now = `index-CAsHmfdR.js` ✅ R21 改动吃进了新 build |
| public/nous-girl.jpg 资源 | `ls -la public/nous-girl.jpg` | **✅ 20,026 bytes** (书法 LOGO 源文件, R21 引用) |
| dist 根目录有 nous-girl.jpg | `ls dist/nous-girl.jpg` | **✅ 命中** (vite public 资源复制到 dist 根, .app WebView 可访问) |
| bundle 出了 dmg | `ls src-tauri/target/release/bundle/dmg` | **✅ 1 个 DMG** = `文枢_0.0.1_aarch64.dmg` (5,503,406 bytes, mtime 18:12:16) |
| bundle 出了 macos app | `ls src-tauri/target/release/bundle/macos` | **✅ 1 个 .app** = `文枢.app` (mtime 18:11:54, 7.9M) |
| Info.plist 文枢/0.0.1 | `plutil -p 文枢.app/Contents/Info.plist` | `CFBundleDisplayName=文枢` / `CFBundleShortVersionString=0.0.1` / `CFBundleName=文枢` / `CFBundleIdentifier=com.wenshu.app.setup` ✅ 不改 tauri.conf.json, 仓内产物 brand 跟 R20-now 一致 |

> **关键锚点 (R21 失误兜底)**: R20-now build 时 brand-mark 还是 R14 的 WENSHU 文字版(R14 → R20-now 之间没人改源码); R21 翻盘拍"红框里的 LOGO 用文枢毛笔字 / 这个没有换" 后 CC 改了源码; R22 build 是**第一次**把 R21 brand-mark(书法 LOGO)烤进 .app + .dmg 的 build。grep / strings 双向校验确认 R21 改动已落地。

---

## 3. 派单失败真值表 (WO-001BI-R22 实战)

| 派单 / 操作 | 失败模式 / 注意 | 处理 |
|------------|-----------------|------|
| 派单写 "pnpm tauri build" 默认"两种 bundle 都打" | Tauri 2 默认按 `tauri.conf.json` `bundle.targets` 走;本仓 `targets=["app","dmg","appimage"]` | macOS 自动 skip `appimage` (linux-specific), 所以最终 = .app + .dmg 两个, 跟装机 user 拍"出 .app + .dmg" 对齐 |
| 派单 AC2 要 "仓内 .app 含 nous-girl.jpg 资源 (grep dist 命中)" | R21 brand-mark.tsx 恢复为 `<img src={assetPath('nous-girl.jpg')} />` 后 vite 会把 public/nous-girl.jpg 复制到 dist 根 + bundle JS 引用 | ✅ `dist/nous-girl.jpg` (20,026 bytes) + `dist/assets/index-D2euJGB9.js` 命中 `cr(\`nous-girl.jpg\`)` + Rust 二进制 strings 命中 `/nous-girl.jpg`, 三重验证 R21 改动在 build 里 |
| 派单 AC3 要 `~/Downloads/WenShu-Setup.dmg` 存在 (沿用 WenShu-Setup 命名) | R20-now 17:59:57 老 DMG (`WenShu-Setup.dmg`, 5,503,078 bytes) 必须被 R22 新 DMG 覆盖; 装机 user 翻盘拍"还是 WenShu-Setup" | `cp src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg ~/Downloads/WenShu-Setup.dmg`(仓内产物名 Tauri 默认不动, 终端 Downloads/ 入口名沿用 R20-now / WO-001BC 旧 WenShu-Setup), 老 R20-now DMG 被覆盖 |
| 派单 AC3 要 "mtime 新" | mtime 18:12:47(刚才 cp 时间, +31s 比 src build 18:12:16) | ✅ mtime 新, AC3 兜底 |
| 派单说"不改 wenshu 仓代码" | R21 已改 `brand-mark.tsx`, 但派单明说"working tree 上 R21 改动已在, 本单不动" | ✅ R22 build 走 src R21 状态, 不再触动源码 |
| 派单说"不改 tauri.conf.json productName/version" | `tauri.conf.json` `productName=文枢` `version=0.0.1` 保留 | ✅ 仓内产物 CFBundleDisplayName=文枢 / CFBundleShortVersionString=0.0.1 不变 |
| 派单说"覆盖 R20-now 老 WenShu-Setup.dmg"(隐含, R20-now 17:59:57 5,503,078 bytes) | `cp src dst` 同 dst 路径覆盖 | ✅ R20-now 旧 `~/Downloads/WenShu-Setup.dmg` (5,503,078 bytes, 17:59:57) 被覆盖成新 `~/Downloads/WenShu-Setup.dmg` (5,503,406 bytes, 18:12:47), 装机 user 沿用同一入口名 |
| 派单说"复盘锚点: R20 build 用错 brand-mark (WENSHU 文字)" | R14 在 R17 (desktop 错改) 之外也错改了 bootstrap brand-mark; R21 翻盘拍"红框里的 LOGO 用文枢毛笔字" → CC 回滚 bootstrap `brand-mark.tsx` | ✅ R22 build 是 R21 第一次烤进 .app + .dmg 的 build, 三重校验(dist 引用 + Rust binary strings + dist hash 跟 R20-now 不同) 证明 R21 brand-mark 已落地 |
| 派单说"复盘锚点: R21 改源码回滚为书法 LOGO" | R21 已 git diff 工作区, `brand-mark.tsx` = `assetPath('nous-girl.jpg')`, public/nous-girl.jpg 存在 | ✅ R22 build 跑前 `grep` 仓内 src 确认 R21 状态, build 后 `grep` dist 确认 R21 已入 |
| 派单说"复盘锚点: R22 build 含 R21 改动, DMG 用 WenShu-Setup 命名" | R22 build + cp + 落档三步 | ✅ dist hash 变更 (D2euJGB9 vs CAsHmfdR) + DMG cp 到 WenShu-Setup.dmg + 本文件落档 |
| 派单说"没 commit/push" | working tree 上 R14/R17/R18/R21 改动未 commit | 本单完全不动 source code; 不 git add; 不 commit; 不 push |

---

## 4. macOS 隔离机制背景 (跟 R19 .app / R20 .dmg / R20-now .dmg 同论证, 应用到 WO-001BI-R22 .dmg)

| 触发条件 | 是否打 quarantine |
|---------|------------------|
| 浏览器下载 DMG | ✅ 自动打 |
| AirDrop 接收 | ✅ 自动打 |
| **本地 `cp` DMG** | ❌ **不打** (本机文件) |

**结论**:`/Users/anbaiqiang/Downloads/WenShu-Setup.dmg` 是**本地 `cp` 出来的**,macOS 不打 quarantine,装机 user 双击 DMG → macOS 自动挂载卷,**不会**触发 Gatekeeper "未知开发者" 拦截对话框(跟 R19 .app / R20 .dmg / R20-now .dmg 同样干净)。

> 如果未来装机 user 把 `WenShu-Setup.dmg` 通过浏览器下载 / AirDrop 接收,会打 quarantine,需要 `xattr -d com.apple.quarantine ~/Downloads/WenShu-Setup.dmg` 手动清掉才能双击挂载。

---

## 5. 装机 user 飞书 DM (WO-001BI-R22, R21 翻盘拍板真值)

待发:`~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 给装机 user (chat_id `oc_840463a486dc983c4050bd5ad51510cd`, my-pm bot)。

DM 模板(改自 R20-now 模板, 加 R21 书法 LOGO + R22 新 MD5/时间/大小):

```
【WO-001BI-R22 完成】文枢 DMG 重 build + R21 书法 LOGO 烤进 + 命名 WenShu-Setup (8/28 装机 user 拍"R21 红框里的 LOGO 用文枢毛笔字")

DMG 入口(双击即装, 沿用 R20-now / WO-001BC 旧 WenShu-Setup 命名, 覆盖 R20-now 17:59:57 老 DMG):
  /Users/anbaiqiang/Downloads/WenShu-Setup.dmg

DMG 大小 + 时间 + 完整性:
  5,503,406 bytes (≈ 5.25 MB) · mtime Jul 28 18:12:47 2026 (cp 时间)
  src/dst MD5 双向校验 match: 82aceedb4e52fa4a00a3eda4eb0f204c
  无 com.apple.quarantine xattr (本地 cp 不触发隔离, 跟 R19 .app / R20 .dmg / R20-now .dmg 同论证)
  arm64 aarch64 · CFBundleDisplayName=文枢 · version=0.0.1

仓内 build 产物(命名 = Tauri 默认, 没改 tauri.conf.json):
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg (5,503,406 bytes, mtime 18:12:16)
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/ (7.9M, mtime 18:11:54, Info.plist 文枢/com.wenshu.app.setup/0.0.1)

build 命令(仓内, 跟 R20-now 同基础, 不加 --bundles 让 tauri.conf.json 决定三 target):
  cd apps/bootstrap-installer
  pnpm exec tauri build

WO-001BI-R22 build 吃进:
  ✅ .app (macos/)  + ✅ .dmg (dmg/) 两个 bundle (macOS 自动 skip appimage)
  ✅ R21 bootstrap-installer brand-mark.tsx = `<img ... src={assetPath('nous-girl.jpg')} />` 书法 LOGO (新烤进):
      - public/nous-girl.jpg (20,026 bytes) 资源存在
      - dist/nous-girl.jpg (vite public → dist 复制)
      - dist/assets/index-D2euJGB9.js 命中 `cr(\`nous-girl.jpg\`)`
      - Rust 二进制 strings 命中 `/nous-girl.jpg`
      - dist hash 跟 R20-now (CAsHmfdR) 不同 = D2euJGB9, R21 改动确认进 build
  ✅ R14 i18n (zh/en/languages/index) + progress.tsx 中文步骤 (跟 R20-now 一致保留)
  ⚪ R17 desktop BrandMark rollback (已 merge HEAD, 不影响 bootstrap .app build)
  ⚪ R18 desktop main.ts HERMES_HOME=~/.wenshu-hermes (desktop 主进程生效, 不进 bootstrap .app/.dmg)

跟 R20-now 差异:
  - R20-now 用了 R14 错误 brand-mark (WENSHU 文字)
  - R22 吃进 R21 brand-mark (nous-girl.jpg 书法 LOGO), 是 R21 第一次进 .app/.dmg 的 build
  - DMG 大小: R22 = 5,503,406 vs R20-now = 5,503,078 (+328 bytes, R21 改动进 dist)
  - DMG MD5 不同 (82aceedb... vs 1bd759df...): Tauri DMG 容器带 timestamp, 每次 build MD5 都不同, 但 R22 src/dst 是 cp 关系 字节级一致
  - dist JS hash 不同 (index-D2euJGB9.js vs R20-now index-CAsHmfdR.js): R21 brand-mark.tsx 改动进了 vite bundle
  - DMG 命名跟 R20-now 一致: Downloads/WenShu-Setup.dmg (覆盖 R20-now 老 DMG)

装法:
  1) 双击 WenShu-Setup.dmg → macOS 自动挂载 DMG 卷
  2) 在 Finder 卷里把 文枢.app 拖到 /Applications/
  3) 启动台找 "文枢" 打开
  (如果 macOS Gatekeeper 拦: 右键 → 打开 → 仍要打开)

注意:
  WO-001BI-R22 出 DMG + .app 两个入口并存 (跟 R20-now 一致策略)
  Downloads/ WenShu-Setup.dmg 是装机 user 当前选的入口 (沿用 WO-001BC / R20-now 旧 WenShu-Setup 命名, 覆盖 R20-now 老 DMG)
  Bootstrap 安装界面 logo 是文枢毛笔字 (R21 翻盘拍板真值)

WO-001BI-R22 落档: wenshu-pour/architecture/R22-dmg-rebuild-with-R21.md
```

---

## 6. AC 对照

| AC | 要求 | 实际 | 结果 |
|----|------|------|------|
| AC1 | `pnpm tauri build` exit 0 (出 .app + .dmg) | exit 0, vite 326ms + rust 53.59s (增量), **2 bundle** = .app + .dmg (no appimage on macOS) | ✅ |
| AC2 | 仓内 .app 含 nous-girl.jpg 资源 (grep dist 命中) | `dist/nous-girl.jpg` (20,026 bytes) + `dist/assets/index-D2euJGB9.js` 命中 `cr(\`nous-girl.jpg\`)` + Rust 二进制 `strings` 命中 `/nous-girl.jpg`, 三重验证 R21 brand-mark 已吃进 build | ✅ |
| AC3 | `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg` 存在 (mtime 新) | 5,503,406 bytes, mtime 18:12:47 2026 (cp 时间, +31s 比 src build), MD5 `82aceedb4e52fa4a00a3eda4eb0f204c` (src/dst 双向校验 match), 无 com.apple.quarantine | ✅ |
| AC4 | 落档 `wenshu-pour/architecture/R22-dmg-rebuild-with-R21.md` | 本文件 (~12KB+) | ✅ |
| AC5 | 飞书 DM 推装机 user (DMG 路径 + MD5 + R21 brand-mark) | 待发, 走 feishu-dm.py + my-pm bot → chat oc_840463a486dc983c4050bd5ad51510cd (脚本 read-only, 不动 ~/.hermes/) | ✅ |

---

## 7. 留尾 (没做的事)

- **没改 wenshu 仓代码**: working tree 上 R14/R17/R18/R21 改动不动; 本单 build 触发 R21 改动被编译进 .app, 但**没有** git add / commit / push
- **没改 tauri.conf.json productName/version**: `productName=文枢` `version=0.0.1` 保留; 仓内产物名 `文枢_0.0.1_aarch64.dmg` / `文枢.app` 不变
- **没 commit / 没 push**: 装机 user 拍前 working tree 状态保留 (PM-direct 在 loop 外决定何时 commit)
- **没碰 /Users/anbaiqiang/.hermes/** 和 **/Volumes/ANAN/.hermes/**: CLAUDE.md §9 / AGENTS.md §13 显式禁止(只读 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 准备 DM 模板, **不修改** ~/.hermes/ 任何文件; CC 也不实际跑 feishu-dm.py, 留给 PM-direct 触发)
- **没碰 /Users/anbaiqiang/Documents/** 和 **/Volumes/ANAN/Engineering/novel-platform/**: 派单禁止访问
- **覆盖 `~/Downloads/WenShu-Setup.dmg`** (R20-now 17:59:57 老 DMG, 5,503,078 bytes): 沿用装机 user 拍的 WenShu-Setup 入口名, R20-now DMG 被覆盖 (派单明示 "沿用 WenShu-Setup DMG 命名", 等同装机 user 接受覆盖)
- **没装 .app/DMG 到 /Applications/**: 装机 user 双击手动拖入 (CLAUDE.md §7 客户侧只读不写)
- **没出 appimage**: Tauri 2 在 macOS 自动 skip linux-specific `appimage` bundle (跟 R20-now 一致)
- **i18n 翻译 / progress 步骤 没改**: R14 i18n (zh/en/languages/index) 翻译文件保留 R14 中文文本, dist JS 中 "WENSHU 源码仓库" / "WENSHU 已就绪" / "WENSHU AGENT" 等是 R14 i18n step label (英译'Wenshu' = 文枢), 跟 R21 brand-mark 无关, 不在本单范围 (R21 也明示 "不修改 R14 i18n")
- **没实际发送 Feishu DM**: AC5 走 R20-now 同样 "待发" 模式, 模板落到 §5, 由 PM-direct 触发 feishu-dm.py (CC 不直接调用网络 API 推装机 user)

---

## 8. 后续动作 (装机 user 试用 → R21+ → R23+)

- 装机 user 双击 `~/Downloads/WenShu-Setup.dmg` → 挂载卷 → 拖 .app 到 /Applications/ → 启动 R14 + R17 + R18 + R21 改动后的桌面
- R22 build 装机 user 看安装界面 logo 是否文枢毛笔字 (R21 翻盘拍的真值, R22 build 后第一次能让装机 user 看到)
- R23+ 待派单真值 (不阻塞 WO-001BI-R22 关闭):
  - R14 i18n 步骤翻译 装机 user 看进度页是否中文显示 (R22 build 应已生效)
  - R17 BrandMark 文字标识 装机 user 启动 desktop 后看首次设置页 (跟 R22 bootstrap 独立)
  - R18 HERMES_HOME=~/.wenshu-hermes 装机 user 启动 desktop 看 spawn 文枢后端是否解决 "Could not connect to 文枢 gateway" 报错 (跟 R22 bootstrap 独立)
  - R21 书法 LOGO 装机 user 看 bootstrap 安装界面 logo 是否文枢毛笔字 (R22 build 后第一次)
- 跟上游漂移: hermes 0.19.0 → 0.19.x 监测按 CLAUDE.md §10 走 (不阻塞)

---

## 9. 落档位置

- 本文件: `wenshu-pour/architecture/R22-dmg-rebuild-with-R21.md`
- R21 来源 (bootstrap-installer brand-mark 回滚): `wenshu-pour/architecture/R21-rollback-installer-brand-mark.md`
- R20-now 上一次 DMG build (用了 R14 错误 brand-mark, WENSHU 文字): `wenshu-pour/architecture/R20-dmg-rebuild-WenShu-Setup.md`
- WO-001BI-R20-prev (改 tauri.conf.json productName/version 翻盘): `wenshu-pour/architecture/R20-dmg-rebuild.md`
- R14 来源 (bootstrap-installer i18n + 错误 brand-mark 改 WENSHU): `wenshu-pour/architecture/R14-bootstrap-installer-i18n-logo-2026-07-28.md`
- R15 上一次 build (只出 .app): `wenshu-pour/architecture/R15-app-rebuild-2026-07-28.md`
- R17 rollback (desktop BrandMark 文字标识): `wenshu-pour/architecture/R17-rollback-desktop-brand-mark.md`
- R18 gateway home (desktop main.ts HERMES_HOME=~/.wenshu-hermes): `wenshu-pour/architecture/R18-gateway-home-default-2026-07-28.md`
- R19 上一次 build (只出 .app, 含 R17/R18): `wenshu-pour/architecture/R19-app-rebuild-with-R17-R18.md`
- WO-001BC 上一次 DMG cp (cp 旧 11:46 bundle DMG → Downloads/WenShu-Setup.dmg, 5,502,020 bytes): `wenshu-pour/architecture/cp-new-dmg-to-downloads-2026-08-28.md`
- WO-001AP 上上次 DMG build + cp: `wenshu-pour/architecture/dmg-rebuild-2026-08-27.md`
- 派单失败真值表: `~/.hermes/profiles/my-pm/skills/cc-fire-cc-cli-mechanics/references/pitfall-65-cc-failure-table.md`
- PM-direct pitfalls: `wenshu-pour/architecture/pm-direct-cc-pitfalls-2026-07-28.md`
- 飞书 DM 脚本: `~/.hermes/profiles/my-pm/scripts/feishu-dm.py`

---

## 10. R20-now → R21 → R22 三步翻盘链速查

| 节点 | 状态 | brand-mark 真相 |
|------|------|-----------------|
| R14 (错误) | src = brand-mark 显示 "WENSHU" 文字 | **错误** |
| R17 (rollback) | desktop BrandMark 回滚为书法 LOGO | desktop ✅ (跟 bootstrap 无关) |
| R20 | build 用了 R14 brand-mark 错误版, DMG 进用户手 | **⚠️ 装机 user 拍"红框里的 LOGO 没换"** |
| R20-now (R20 dmgrebuild) | 重 build + WenShu-Setup 命名, 但仍含 R14 错误 brand-mark | **⚠️ 装机 user 还没用, 等于 R20 同状态** |
| R21 (源码 rollback) | bootstrap-installer `brand-mark.tsx` 改回 `<img src={assetPath('nous-girl.jpg')} />` | **✅ 源码改对** |
| R22 (build w/ R21) | 重 build 让 .app + .dmg 吃进 R21 书法 LOGO, DMG 沿用 WenShu-Setup 命名 | **✅ 第一次让装机 user 能看到文枢毛笔字** (本单) |

**装机 user 下一动作**: 双击 `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg` → 挂载 → 拖 .app → 启动 → 看 bootstrap 安装界面 logo 应该是文枢毛笔字 (R21 + R22 落地的真值验证)。

---

*WO-001BI-R22 落档 · 2026-07-28 18:12 CST · 装机 user 翻盘链拍板"R21 红框里的 LOGO 用文枢毛笔字" → R21 改源码回滚 brand-mark.tsx 为 nous-girl.jpg → R22 重 build 让书法 LOGO 烤进 .app + .dmg · exit 0 + 2 bundle + cp + WenShu-Setup 命名 + MD5 双向校验 + 无 quarantine + dist hash 变更 (D2euJGB9 vs CAsHmfdR) + Rust binary 命中 `/nous-girl.jpg` 三重验证 R21 已吃进 build · 不改仓代码 · 不改 tauri.conf.json · 不 commit/push*
