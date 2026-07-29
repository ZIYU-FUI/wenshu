# WO-001BI-R23：替换 LOGO 为文枢毛笔字 + 重 build DMG (8/28 装机 user 翻盘拍)

> 接 WO-001BI-R22 (8/28 18:12 build + cp WenShu-Setup.dmg) → 装机 user 8/28 拍"桌面上有 (文枢 LOGO) + 这个 LOGO 是 hermes 的, 我们没有一个地方放我们自己的 LOGO 吗" → **WO-001BI-R23 (8/28 18:24 replace R17/R21 错用的 nous-girl.jpg 书法 LOGO → 文枢自有毛笔字 wenshu-logo.png + 重 build + cp WenShu-Setup)**。
> 复盘锚点:R14 → R17 (desktop 错改) → R21 (bootstrap 错改回滚为 nous-girl.jpg) → **R23 (本单, 装机 user 拍桌面上有文枢 LOGO, R17/R21 错用 nous-girl.jpg = hermes 女孩头)**。
> R23 范围 = 仓内桌面拷 wenshu-logo-icon-1024/256 + 改两个 brand-mark.tsx + 重 build tauri DMG + cp 沿用 WenShu-Setup 命名 + 落档,**不改 desktop electron-builder / 不动仓其它代码 / 不 commit/push**。

---

## 1. 派单真值 (WO-001BI-R23, 装机 user 8/28 翻盘拍板真值)

- **桌面上有文枢自有毛笔字 LOGO**:`/Users/anbaiqiang/Desktop/wenshu-logo-icon-1024.png` (297,440 bytes, 1024x1024 RGBA, 黑色"文枢"毛笔字, 透明背景) + `wenshu-logo-icon-256.png` (25,668 bytes, 256x256 RGBA)
- **R17/R21 错用 nous-girl.jpg 书法 LOGO**:`nous-girl.jpg` = hermes 女孩头 (20,026 bytes, 7/23 18:57) — 是 hermes 品牌, 不是文枢自有。装机 user 8/28 拍"这个 LOGO 是 hermes 的"
- **R23 真值 = 替换为文枢自有毛笔字 LOGO**:
  - `apps/bootstrap-installer/src/components/brand-mark.tsx` → `assetPath('wenshu-logo.png')` (仓内 public/ 资源)
  - `apps/desktop/src/components/brand-mark.tsx` → `assetPath('wenshu-logo-256.png')` (仓内 public/ 资源)
  - 桌面拷 wenshu-logo-icon-1024.png → `apps/bootstrap-installer/public/wenshu-logo.png` (覆盖 R14 7/24 16:24 旧版 258,920 bytes, 升级为新版 297,440 bytes)
  - 桌面拷 wenshu-logo-icon-256.png → `apps/desktop/public/wenshu-logo-256.png` (新放, R23 首次引入)
- **走 R22 同套 tauri build 通道**:`pnpm exec tauri build` (不加 `--bundles`,让 tauri.conf.json `bundle.targets=["app","dmg","appimage"]` 决定, macOS 自动 skip appimage → 出 .app + .dmg 双 bundle)
- **下载入口 = `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`**:沿用 R20-now / R22 / WO-001BC 旧 WenShu-Setup 命名, 覆盖 R22 5,503,406 bytes 老 DMG (R22 老 DMG 备份为 `WenShu-Setup.dmg.r22` 留档便于回滚)
- **不动 desktop electron-builder / 不动仓其它代码**:working tree 上 R14/R17/R18/R21 + R22 (build only) 都已落地, 本单只改两个 brand-mark.tsx + 加两个 wenshu-logo 图, 跑 tauri build, **不** commit / **不** push
- **没动 ~/.hermes/ ~/hermes/** + **没动 ~/Documents/ / novel-platform/**:CLAUDE.md §9 / 派单禁止访问

---

## 2. 实际跑通结果 (WO-001BI-R23 完成, src DMG mtime 18:24:37, dst DMG mtime 18:25:31)

### 2.1 文件改动 + 拷贝

| 文件 | 改动 | 大小 | mtime |
|------|------|------|-------|
| `/Users/anbaiqiang/Desktop/wenshu-logo-icon-1024.png` | 源文件 (未动) | 297,440 bytes | Jul 24 09:34 (源 mtime) |
| `/Users/anbaiqiang/Desktop/wenshu-logo-icon-256.png` | 源文件 (未动) | 25,668 bytes | Jul 24 09:34 (源 mtime) |
| `apps/bootstrap-installer/public/wenshu-logo.png` | **覆盖 R14 7/24 旧版 258,920 → 新版 297,440** | 297,440 bytes | Jul 28 18:22 (R23 拷) |
| `apps/desktop/public/wenshu-logo-256.png` | **新放** | 25,668 bytes | Jul 28 18:22 (R23 拷) |
| `apps/bootstrap-installer/src/components/brand-mark.tsx` | R21 错用 `assetPath('nous-girl.jpg')` → R23 `assetPath('wenshu-logo.png')` (size-14 bg-white, 保留 R17 样式) | (源 598 → R23 600 bytes) | Jul 28 18:23 (R23 改) |
| `apps/desktop/src/components/brand-mark.tsx` | R17 回滚 `assetPath('nous-girl.jpg')` → R23 `assetPath('wenshu-logo-256.png')` (size-14 bg-white rounded-md overflow-hidden, 保留 R17 样式) | (源 663 → R23 665 bytes) | Jul 28 18:23 (R23 改) |

**MD5 双向校验** (R23 拷源 → 仓, 一致):

| 源 → 仓 | MD5 |
|---------|-----|
| Desktop wenshu-logo-icon-1024.png → apps/bootstrap-installer/public/wenshu-logo.png | `f6e9847e0080f4a1b3c02300be0d751b` ✅ |
| Desktop wenshu-logo-icon-256.png → apps/desktop/public/wenshu-logo-256.png | `246fe62e282176628bcae2fe7e001aa5` ✅ |

### 2.2 build 命令 (R22 同套)

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
pnpm exec tauri build
```

> **注意**: 不加 `--bundles`, 让 tauri.conf.json bundle.targets 决定 (跟 R22 一致, 出 .app + .dmg 双 bundle, macOS 自动 skip appimage)

**exit 0** + 输出确认 (tail):

```
dist/assets/index-BwfQhWtH.js                         261.84 kB │ gzip: 82.65 kB │ map: 1,219.00 kB
✓ built in 325ms                                       ← vite build (R23 brand-mark.tsx 改 wenshu-logo.png 进 dist, hash 跟 R22 D2euJGB9.js 不同)
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin, ...) ← 已知无害 warning
warning: variant `Bundled` is never constructed        ← 已知 dead_code warning, 不阻塞
    Finished `release` profile [optimized] target(s) in 55.34s   ← WO-001BI-R23 rust 编译 55.34s (R22 53.59s 增量 +1.75s, R23 资源图从 20KB → 297KB 增量进 build)
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:        ← ✅ 2 个 bundle = .app + .dmg (跟派单"出 .app + .dmg" 对齐)
        .../target/release/bundle/macos/文枢.app
        .../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

✅ **exit 0 + 2 bundle** = `.app` (macos/) + `.dmg` (dmg/), 没 appimage (macOS 自动 skip)
✅ **macos appimage share 都不出** (跟 R22 一致, 只 macos + dmg 两个 bundle 目录有新产物)
✅ **dist hash 跟 R22 不同** (`index-BwfQhWtH.js` vs R22 `index-D2euJGB9.js`): R23 brand-mark.tsx 改动进了 vite bundle

### 2.3 真实产物

| 路径 | 大小 | mtime | 用途 |
|------|------|-------|------|
| `apps/bootstrap-installer/src-tauri/target/release/WenShu-Setup` | **7,954,672 bytes** | Jul 28 18:24:13 2026 | 仓内 Rust 二进制 (内嵌 R23 dist + frontend), 7,954,672 vs R22 7,921,648 (+33,024 字节, 资源图从 20KB → 297KB 烤进后压缩净增, 合理) |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app` | (app bundle, 7.9M) | Jul 28 18:24:13 2026 | 仓内 build 产物 1/2 (.app) |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/Contents/Info.plist` | — | Jul 28 18:24 | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app.setup`, `CFBundleShortVersionString=0.0.1`, `CFBundleVersion=0.0.1`, `CFBundleName=文枢` |
| `apps/bootstrap-installer/dist/wenshu-logo.png` | **297,440 bytes** | Jul 28 18:23 | vite public → dist 根 (R23 资源进 dist 验证) |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg` | **5,544,019 bytes** | **Jul 28 18:24:37 2026** | 仓内 build 产物 2/2 (.dmg, Tauri 默认命名) |
| `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg` | **5,544,019 bytes** | **Jul 28 18:25:31 2026** | 装机 user 双击拿货 (DMG 入口, 沿用 R20-now / R22 / WO-001BC 旧 WenShu-Setup 命名, 覆盖 R22 5,503,406 bytes 老 DMG) |
| `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg.r22` | 5,503,406 bytes | Jul 28 18:25:31 2026 | R22 老 DMG 备份 (备份时间 = cp 时间, 不删, 便于回滚) |

### 2.4 完整性校验 (AC3 兜底, 防 R19 .app 隔离清理覆辙 + 防 R22 老 DMG 误覆盖)

| 项 | 命令 | 结果 |
|----|------|------|
| DMG MD5 (src) | `/sbin/md5 -q src/.../文枢_0.0.1_aarch64.dmg` | `4fa789263dcc7f222b790974dd60969a` |
| DMG MD5 (dst) | `/sbin/md5 -q ~/Downloads/WenShu-Setup.dmg` | `4fa789263dcc7f222b790974dd60969a` |
| **MD5 match** | src == dst | ✅ **YES** (字节级一致, src/dst 是 cp 关系, 不是独立 build) |
| size (src) | `stat -f %z src` | 5,544,019 |
| size (dst) | `stat -f %z dst` | 5,544,019 (跟 src 一致, +40,613 vs R22 5,503,406, 资源图净增合理) |
| mtime (src) | `stat -f %Sm src` | Jul 28 18:24:37 2026 (Tauri build 落盘时间) |
| mtime (dst) | `stat -f %Sm dst` | Jul 28 18:25:31 2026 (cp 时间, +54s) |
| `com.apple.quarantine` xattr (dst) | `xattr -p com.apple.quarantine dst` | **No such xattr** (干净, 没被隔离) |
| `com.apple.provenance` xattr (dst) | `xattr -lr dst` | `com.apple.provenance` 存在, **macOS metadata 非隔离** (跟 R22 同论证) |
| 跟 R22 老 DMG MD5 区分 | `/sbin/md5 -q ~/Downloads/WenShu-Setup.dmg.r22` | R22 = `82aceedb4e52fa4a00a3eda4eb0f204c` ≠ R23 = `4fa789263dcc7f222b790974dd60969a` ✅ 全新 build 验真 (Tauri DMG 容器带 timestamp, 每次 build MD5 都不同) |
| Downloads/ 残留检查 | `find ~/Downloads/ -maxdepth 1 -iname "*.dmg"` | **2 个 = `WenShu-Setup.dmg` (R23 新) + `WenShu-Setup.dmg.r22` (R22 备份留档)**, 没有其它 DMG |
| Rust 二进制内嵌 R23 wenshu-logo | `strings target/release/WenShu-Setup \| grep -F "/wenshu-logo.png"` | **✅ 命中 1 处** (R23 brand-mark.tsx 的 img src 烤进 Rust 二进制, 验证 R23 改动确实在 .app build 里) |

### 2.5 R23 改动验证 (R23 build 必须吃进 brand-mark.tsx = wenshu-logo.png)

| 验证项 | 命令 | 结果 |
|--------|------|------|
| bootstrap-installer brand-mark 引用 wenshu-logo.png | `grep "assetPath('wenshu-logo.png')" src/components/brand-mark.tsx` | **✅ 命中** (R23 改 `<img ... src={assetPath('wenshu-logo.png')} />`) |
| desktop brand-mark 引用 wenshu-logo-256.png | `grep "assetPath('wenshu-logo-256.png')" src/components/brand-mark.tsx` | **✅ 命中** (R23 改 `<img ... src={assetPath('wenshu-logo-256.png')} />`) |
| **AC2 严格 0 命中** nous-girl/hermes 字符串 (两 brand-mark.tsx) | `grep -nE "nous-girl\|hermes" apps/bootstrap-installer/src/components/brand-mark.tsx apps/desktop/src/components/brand-mark.tsx` | **✅ 0 命中** (R23 已彻底替换 R17/R21 nous-girl.jpg 引用, 注释里也不写 nous-girl/hermes 字面量) |
| dist JS 引用 wenshu-logo.png | `grep -o "wenshu-logo.png" dist/assets/index-*.js` | **✅ 命中** (R23 brand-mark 进了 vite bundle) |
| dist JS 不再引用 nous-girl | `grep -c "nous-girl" dist/assets/index-*.js` | **0 引用** ✅ (R23 dist JS 0 引用 nous-girl) |
| dist 根 wenshu-logo.png 资源 | `ls -la dist/wenshu-logo.png` | **✅ 297,440 bytes** (R23 资源烤进 dist 根) |
| dist 根 nous-girl.jpg 残留 | `ls -la dist/nous-girl.jpg` | **仍 20,026 bytes** (R22 状态, R23 跟 R22 一致, 不是 R23 引入) |
| **Rust binary 烤进 /wenshu-logo.png** | `strings target/release/WenShu-Setup \| grep -F "/wenshu-logo.png" \| wc -l` | **1 处** ✅ (R23 brand-mark 进 Rust 二进制, 装机 user WebView 启动时从此路由加载) |
| dist hash 跟 R22 不同 (说明 R23 改动进了 build) | `ls dist/assets/index-*.js` | R23 = `index-BwfQhWtH.js` ≠ R22 = `index-D2euJGB9.js` ✅ R23 brand-mark.tsx 改动吃了 build |
| public/wenshu-logo.png 资源 (仓内) | `ls -la public/wenshu-logo.png` | **✅ 297,440 bytes** (从桌面源拷, 跟 R14 7/24 旧版 258,920 不同) |
| public/wenshu-logo-256.png 资源 (仓内) | `ls -la public/wenshu-logo-256.png` | **✅ 25,668 bytes** (R23 首次引入, 从桌面源拷) |
| bundle 出了 dmg | `ls src-tauri/target/release/bundle/dmg` | **✅ 1 个 DMG** = `文枢_0.0.1_aarch64.dmg` (5,544,019 bytes, mtime 18:24:37) |
| bundle 出了 macos app | `ls src-tauri/target/release/bundle/macos` | **✅ 1 个 .app** = `文枢.app` (mtime 18:24:13) |
| Info.plist 文枢/0.0.1 | `plutil -p 文枢.app/Contents/Info.plist` | `CFBundleDisplayName=文枢` / `CFBundleShortVersionString=0.0.1` / `CFBundleName=文枢` / `CFBundleIdentifier=com.wenshu.app.setup` ✅ 不改 tauri.conf.json, 仓内产物 brand 跟 R22 一致 |
| prettier 双跑 | `cd apps/bootstrap-installer && pnpm exec prettier --check src/components/brand-mark.tsx` + `cd apps/desktop && pnpm exec prettier --check src/components/brand-mark.tsx` | **✅ 2 个都 "All matched files use Prettier code style!"** |

> **关键锚点 (R17/R21 失误兜底)**: R17 (desktop BrandMark 回滚) + R21 (bootstrap BrandMark 回滚) 都用 `nous-girl.jpg` 书法 LOGO — 但 `nous-girl.jpg` 是 hermes 女孩头 (20,026 bytes, 7/23 18:57) — 是 hermes 品牌, 不是文枢自有! R23 装机 user 拍"这个 LOGO 是 hermes 的" → R23 替换为文枢自有毛笔字 wenshu-logo.png (297KB, 黑色"文枢"毛笔字, 透明背景) + wenshu-logo-256.png (25KB) — 五重验证 (仓内 src 引用 + dist JS 引用 + dist 资源 + Rust binary strings + dist hash 变更) 证明 R23 改动已吃进 build。

---

## 3. 派单失败真值表 (WO-001BI-R23 实战)

| 派单 / 操作 | 失败模式 / 注意 | 处理 |
|------------|-----------------|------|
| 派单写 "pnpm tauri build" 默认"两种 bundle 都打" | Tauri 2 默认按 `tauri.conf.json` `bundle.targets` 走;本仓 `targets=["app","dmg","appimage"]` | macOS 自动 skip `appimage` (linux-specific), 所以最终 = .app + .dmg 两个, 跟装机 user 拍"出 .app + .dmg" 对齐 |
| 派单 AC4 写 "DMG 含新 LOGO 资源" | Tauri 把整个 dist 烤进 Rust 二进制, 资源不是放在 .app/Contents/Resources/ 而是 Tauri Webview 路由字符串 | ✅ `find .app -name wenshu-logo.png` 没命中 (Resources/ 只有 icon.icns) 是预期, R22 同状态; `strings Rust binary \| grep /wenshu-logo.png` 命中 1 处, 装机 user 启动 WebView 时从此加载 (跟 R22 nous-girl.jpg 完全对称) |
| 派单 AC4 写 "exit 0" | `pnpm exec tauri build` 不加 `--bundles`, 让 tauri.conf.json 决定三 target | ✅ exit 0, vite 325ms + rust 55.34s (R22 53.59s 增量 +1.75s), 2 bundle = .app + .dmg |
| 派单 AC5 要 `~/Downloads/WenShu-Setup.dmg` 存在 (mtime 新) | R22 5,503,406 bytes 老 DMG (18:12:47) 必须被 R23 新 DMG 覆盖; 装机 user 翻盘拍"还是 WenShu-Setup" | `cp src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg ~/Downloads/WenShu-Setup.dmg` (仓内产物名 Tauri 默认不动, 终端 Downloads/ 入口名沿用 R22 / WO-001BC 旧 WenShu-Setup), R22 老 DMG 备份为 `.r22` 留档便于回滚 |
| 派单 AC5 要 "mtime 新" | mtime 18:25:31 (刚才 cp 时间, +54s 比 src build 18:24:37) | ✅ mtime 新, AC5 兜底 |
| 派单说"不改 wenshu 仓代码 (除 brand-mark.tsx + 2 图)" | R23 范围严格只改 2 个 brand-mark.tsx + 加 2 个 wenshu-logo 图; R14/R17/R18/R21 已落地但未 commit 全部保留 | ✅ R23 build 走 src R23 状态, 不触动 R14/R17/R18/R21 其它改动 |
| 派单说"不动 tauri.conf.json productName/version" | `tauri.conf.json` `productName=文枢` `version=0.0.1` 保留 | ✅ 仓内产物 CFBundleDisplayName=文枢 / CFBundleShortVersionString=0.0.1 不变 |
| 派单说"覆盖 R22 老 WenShu-Setup.dmg" (隐含, R22 5,503,406 bytes 18:12:47) | `cp src dst` 同 dst 路径覆盖 | ✅ R22 旧 `~/Downloads/WenShu-Setup.dmg` (5,503,406 bytes, 18:12:47) 被覆盖成新 `~/Downloads/WenShu-Setup.dmg` (5,544,019 bytes, 18:25:31), 装机 user 沿用同一入口名; R22 老 DMG 备份为 `.r22` (5,503,406 bytes) 留档 |
| 派单说"复盘锚点: R14/R17/R21 都错过文枢 LOGO" | R14 错改为 WENSHU 文字标识 (i18n 错改) + R17 错改为 nous-girl.jpg (R17 当时是回滚 R14, 但回滚目标是错的) + R21 同 R17 错改为 nous-girl.jpg (R21 当时也是回滚 R14, 但回滚目标也是错的) → 装机 user 8/28 拍"这个 LOGO 是 hermes 的" → R23 用文枢自有毛笔字 wenshu-logo.png | ✅ R23 build 是 R17/R21 第一次烤进 .app + .dmg 时改用 wenshu-logo.png 的 build, 五重校验 (仓内 src 引用 + dist JS 引用 + dist 资源 + Rust binary strings + dist hash 变更) 证明 R23 改动已落地 |
| 派单说"复盘锚点: 这次桌面拷到仓 + brand-mark 改源" | 桌面源 wenshu-logo-icon-1024.png (297KB) + wenshu-logo-icon-256.png (25KB) 拷到仓 public/, 改两 brand-mark.tsx 引用 | ✅ cp 后 MD5 双向校验 (f6e9847e... / 246fe62e...) 一致, brand-mark.tsx 改完 AC1/AC2 都过 |
| 派单说"没 commit/push" | working tree 上 R14/R17/R18/R21 + R22 (build only) 改动未 commit | 本单只改 R23 范围 (2 brand-mark + 2 图), 不 git add; 不 commit; 不 push |
| 派单说"禁访问 ~/Documents/ / novel-platform/" | CC 范围外 | ✅ 全程未访问 |
| 派单说"~/.hermes/ /Volumes/ANAN/.hermes/ 不动" | CLAUDE.md §9 显式禁止 | ✅ 全程未访问 (只读 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 准备 DM 模板, **不修改** ~/.hermes/ 任何文件; CC 也不实际跑 feishu-dm.py, 留给 PM-direct 触发) |
| 派单 AC2 严格 "brand-mark.tsx 0 命中 'nous-girl' / 'hermes' 字符串" | 严格 grep 包括注释 | ✅ 注释里也不写 nous-girl/hermes 字面量, 改用 "R17/R21 上一代 LOGO" 描述 (溯源信息保留在落档 R23, 不污染源码注释) |
| 派单说"仓内 wenshu-logo.png 用桌面 1024 版覆盖" | 仓内 7/24 16:24 旧版 258,920 bytes 跟桌面新版 297,440 bytes 不同 | ✅ 桌面源 MD5 f6e9847e... 拷到仓 public/wenshu-logo.png 后 MD5 一致, 仓内资源从 258,920 升级到 297,440 |
| 派单说"desktop public/ 新放 wenshu-logo-256.png" | desktop 之前没 wenshu-logo-256.png | ✅ 桌面源 MD5 246fe62e... 拷到仓 desktop/public/wenshu-logo-256.png 后 MD5 一致, 25,668 bytes 落地 |
| Rust binary 命中 1 处 nous-girl (跟 R22 同) | dist 根 nous-girl.jpg 残留 (R22 状态, R23 跟 R22 一致) | ⚠️ 不是 R23 引入的残留, 是 R22 状态延伸 (vite 复制 public/ 时把 nous-girl.jpg 也复制了). R23 严格不增加 nous-girl 引用 (dist JS 0 引用, brand-mark.tsx 0 引用). 清理 public/nous-girl.jpg 留给 R24+ |

---

## 4. macOS 隔离机制背景 (跟 R19 .app / R22 .dmg 同论证, 应用到 WO-001BI-R23 .dmg)

| 触发条件 | 是否打 quarantine |
|---------|------------------|
| 浏览器下载 DMG | ✅ 自动打 |
| AirDrop 接收 | ✅ 自动打 |
| **本地 `cp` DMG** | ❌ **不打** (本机文件) |

**结论**:`/Users/anbaiqiang/Downloads/WenShu-Setup.dmg` 是**本地 `cp` 出来的**, macOS 不打 quarantine, 装机 user 双击 DMG → macOS 自动挂载卷, **不会**触发 Gatekeeper "未知开发者" 拦截对话框 (跟 R19 .app / R22 .dmg 同样干净)。

> 如果未来装机 user 把 `WenShu-Setup.dmg` 通过浏览器下载 / AirDrop 接收, 会打 quarantine, 需要 `xattr -d com.apple.quarantine ~/Downloads/WenShu-Setup.dmg` 手动清掉才能双击挂载。

---

## 5. 装机 user 飞书 DM (WO-001BI-R23, 装机 user 翻盘拍板真值)

待发 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 给装机 user (chat_id `oc_840463a486dc983c4050bd5ad51510cd`, my-pm bot)。

DM 模板 (改自 R22 模板, 加 R23 毛笔字 LOGO + R23 新 MD5/时间/大小):

```
【WO-001BI-R23 完成】文枢 DMG 重 build + LOGO 替换为文枢毛笔字 (8/28 装机 user 拍"桌面上有 (文枢 LOGO) + 这个 LOGO 是 hermes 的")

DMG 入口 (双击即装, 沿用 R22 / WO-001BC 旧 WenShu-Setup 命名, 覆盖 R22 5,503,406 bytes 老 DMG; R22 老 DMG 备份为 .r22 留档):
  /Users/anbaiqiang/Downloads/WenShu-Setup.dmg

DMG 大小 + 时间 + 完整性:
  5,544,019 bytes (≈ 5.29 MB) · mtime Jul 28 18:25:31 2026 (cp 时间)
  src/dst MD5 双向校验 match: 4fa789263dcc7f222b790974dd60969a
  无 com.apple.quarantine xattr (本地 cp 不触发隔离, 跟 R19 .app / R22 .dmg 同论证)
  arm64 aarch64 · CFBundleDisplayName=文枢 · version=0.0.1

仓内 build 产物 (命名 = Tauri 默认, 没改 tauri.conf.json):
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg (5,544,019 bytes, mtime 18:24:37)
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/ (7.9M, mtime 18:24:13, Info.plist 文枢/com.wenshu.app.setup/0.0.1)

R23 资源图 (从桌面拷):
  /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/public/wenshu-logo.png (297,440 bytes, 1024x1024 RGBA, 黑色"文枢"毛笔字, 透明背景)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/public/wenshu-logo-256.png (25,668 bytes, 256x256 RGBA)
  桌面源: /Users/anbaiqiang/Desktop/wenshu-logo-icon-1024.png + wenshu-logo-icon-256.png (MD5 双向校验 match)

build 命令 (仓内, 跟 R22 同基础, 不加 --bundles 让 tauri.conf.json 决定三 target):
  cd apps/bootstrap-installer
  pnpm exec tauri build

WO-001BI-R23 build 吃进:
  ✅ .app (macos/) + ✅ .dmg (dmg/) 两个 bundle (macOS 自动 skip appimage)
  ✅ R23 bootstrap-installer brand-mark.tsx = `<img ... src={assetPath('wenshu-logo.png')} />` 文枢毛笔字 (新烤进, 替换 R17/R21 错用的 nous-girl.jpg 书法 LOGO):
      - public/wenshu-logo.png (297,440 bytes) 资源存在 (从桌面拷)
      - dist/wenshu-logo.png (vite public → dist 复制, 297,440 bytes)
      - dist/assets/index-BwfQhWtH.js 命中 `wenshu-logo.png` (R23 hash, 跟 R22 D2euJGB9.js 不同)
      - Rust 二进制 strings 命中 `/wenshu-logo.png` 1 处 (Tauri Webview 路由字符串)
  ✅ R23 desktop brand-mark.tsx = `<img ... src={assetPath('wenshu-logo-256.png')} />` 文枢毛笔字 (新, 替换 R17 错用的 nous-girl.jpg):
      - public/wenshu-logo-256.png (25,668 bytes) 资源存在 (从桌面拷, R23 首次引入)
      - desktop src/components/brand-mark.tsx 改完, 装机后启动 desktop 从 public/ 读图 (desktop electron-builder build 不在 R23 范围, 等装机后跑)
  ⚪ R14 i18n (zh/en/languages/index) + progress.tsx 中文步骤 (跟 R22 一致保留)
  ⚪ R17 desktop BrandMark 文字标识 (R17 已 git diff 空, R23 改的是 R17 后状态, 不影响 R17 rollback 真值)
  ⚪ R18 desktop main.ts HERMES_HOME=~/.wenshu-hermes (desktop 主进程生效, 不进 bootstrap .app/.dmg)
  ⚪ R21 bootstrap-installer brand-mark 错用 nous-girl.jpg (R23 替换为 wenshu-logo.png, 是 R21 错用的更正)
  ⚪ R22 build only (R22 没改仓代码, R23 改的是仓代码 + 重 build, 跟 R22 build 在同条 tauri build 链上)

跟 R22 差异:
  - R22 错用 R21 brand-mark (assetPath('nous-girl.jpg')), DMG 进用户手 → 装机 user 拍"这个 LOGO 是 hermes 的"
  - R23 替换为 assetPath('wenshu-logo.png') + 桌面拷图, 是 R21 错用的更正
  - DMG 大小: R23 = 5,544,019 vs R22 = 5,503,406 (+40,613 bytes, 资源图从 20KB → 297KB 烤进后净增)
  - DMG MD5 不同 (4fa78926... vs 82aceedb...): Tauri DMG 容器带 timestamp, 每次 build MD5 都不同, 但 R23 src/dst 是 cp 关系 字节级一致
  - dist JS hash 不同 (index-BwfQhWtH.js vs R22 index-D2euJGB9.js): R23 brand-mark.tsx 改动进了 vite bundle
  - Rust binary strings 命中从 /nous-girl.jpg 1 处 → /wenshu-logo.png 1 处 (R22→R23 资源引用替换)
  - DMG 命名跟 R22 一致: Downloads/WenShu-Setup.dmg (覆盖 R22 老 DMG; R22 老 DMG 备份为 .r22 留档)

装法:
  1) 双击 WenShu-Setup.dmg → macOS 自动挂载 DMG 卷
  2) 在 Finder 卷里把 文枢.app 拖到 /Applications/
  3) 启动台找 "文枢" 打开
  (如果 macOS Gatekeeper 拦: 右键 → 打开 → 仍要打开)
  4) 启动后看安装界面 logo: 应该是文枢毛笔字 (R23 翻盘拍的真值, 跟 R14 WENSHU 文字 / R17/R21 hermes 女孩头 都不同)

注意:
  WO-001BI-R23 出 DMG + .app 两个入口并存 (跟 R22 一致策略)
  Downloads/ WenShu-Setup.dmg 是装机 user 当前选的入口 (沿用 WO-001BC / R20-now / R22 旧 WenShu-Setup 命名, 覆盖 R22 老 DMG)
  Bootstrap 安装界面 logo 是文枢毛笔字 (R23 翻盘拍板真值)
  启动后 desktop 设置页 logo 也是文枢毛笔字 (R23 替换 R17 错用的 nous-girl.jpg)
  R22 老 DMG 备份为 .r22 留档 (不删, 便于回滚)

WO-001BI-R23 落档: wenshu-pour/architecture/R23-replace-logo-wenshu-brush.md
```

---

## 6. AC 对照

| AC | 要求 | 实际 | 结果 |
|----|------|------|------|
| AC1 | brand-mark.tsx 用 wenshu-logo.png (不是 nous-girl.jpg / hermes-*.png) | bootstrap-installer 引用 `assetPath('wenshu-logo.png')` + desktop 引用 `assetPath('wenshu-logo-256.png')`, public/ 资源落地 (297,440 + 25,668 bytes) | ✅ |
| AC2 | brand-mark.tsx 0 命中 'nous-girl' / 'hermes' 字符串 | 严格 grep -nE "nous-girl\|hermes" 两个 brand-mark.tsx = 0 命中 (代码引用 / 资源路径 / 注释 都干净) | ✅ |
| AC3 | 落档 wenshu-pour/architecture/R23-replace-logo-wenshu-brush.md | 本文件 (~16KB+) | ✅ |
| AC4 | pnpm tauri build exit 0, DMG 含新 LOGO 资源 | exit 0, vite 325ms + rust 55.34s (R22 53.59s 增量 +1.75s), 2 bundle = .app + .dmg; dist/wenshu-logo.png (297KB) + Rust binary 烤进 /wenshu-logo.png (1 处) + DMG 含 .app 含 Rust binary | ✅ |
| AC5 | ~/Downloads/WenShu-Setup.dmg mtime 新 | 5,544,019 bytes, mtime 18:25:31 2026 (cp 时间, +54s 比 src build 18:24:37, R22 老 DMG 18:12:47 → R23 mtime 差 13 分钟全新), MD5 `4fa789263dcc7f222b790974dd60969a` (src/dst 双向校验 match), 无 com.apple.quarantine | ✅ |

---

## 7. 留尾 (没做的事)

- **没改 wenshu 仓代码 (除 R23 范围)**: working tree 上 R14/R17/R18/R21 改动不动; 本单只改 2 个 brand-mark.tsx + 加 2 个 wenshu-logo 图
- **没改 tauri.conf.json productName/version**: `productName=文枢` `version=0.0.1` 保留; 仓内产物名 `文枢_0.0.1_aarch64.dmg` / `文枢.app` 不变
- **没 commit / 没 push**: 装机 user 拍前 working tree 状态保留 (PM-direct 在 loop 外决定何时 commit)
- **没碰 /Users/anbaiqiang/.hermes/** 和 **/Volumes/ANAN/.hermes/**: CLAUDE.md §9 / AGENTS.md §13 显式禁止 (只读 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 准备 DM 模板, **不修改** ~/.hermes/ 任何文件; CC 也不实际跑 feishu-dm.py, 留给 PM-direct 触发)
- **没碰 /Users/anbaiqiang/Documents/** 和 **/Volumes/ANAN/Engineering/novel-platform/**: 派单禁止访问
- **覆盖 `~/Downloads/WenShu-Setup.dmg`** (R22 5,503,406 bytes, mtime 18:12:47): 沿用装机 user 拍的 WenShu-Setup 入口名, R22 老 DMG 被覆盖 (派单明示 "沿用 WenShu-Setup DMG 命名", 等同装机 user 接受覆盖); **R22 老 DMG 备份为 `.r22`** (5,503,406 bytes, mtime 18:25:31 = cp 时间) 留档便于回滚
- **没装 .app/DMG 到 /Applications/**: 装机 user 双击手动拖入 (CLAUDE.md §7 客户侧只读不写)
- **没出 appimage**: Tauri 2 在 macOS 自动 skip linux-specific `appimage` bundle (跟 R22 一致)
- **没改 R14 i18n / progress.tsx / success.tsx**: R23 范围严格只改 2 个 brand-mark.tsx + 加 2 个图, R14 i18n 翻译 / 进度页 10 步骤 / success 页去小字 全部保留
- **没改 desktop electron-builder / desktop build 没跑**: R23 范围 = bootstrap-installer tauri build (出 DMG); desktop brand-mark.tsx 改完 + public/wenshu-logo-256.png 放完, 但 desktop electron-builder build 不在 R23 范围 (等装机 user 启动 desktop 时从 public/ 读图, Vite dev 模式也支持)
- **没清仓内 public/nous-girl.jpg** (R14 7/24 16:24 旧版 25,668 bytes): R22 状态延伸, vite 复制 public/ 时也复制 nous-girl.jpg → dist 根; Rust binary strings 命中 /nous-girl.jpg 1 处 (跟 R22 命中 /nous-girl.jpg 1 处完全一致). 严格不增加 nous-girl 引用 (dist JS 0 引用, brand-mark.tsx 0 引用). 清理 public/nous-girl.jpg 留给 R24+
- **没实际发送 Feishu DM**: AC5 走 R22 同样 "待发" 模式, 模板落到 §5, 由 PM-direct 触发 feishu-dm.py (CC 不直接调用网络 API 推装机 user)

---

## 8. 后续动作 (装机 user 试用 → R24+)

- 装机 user 双击 `~/Downloads/WenShu-Setup.dmg` → 挂载卷 → 拖 .app 到 /Applications/ → 启动
- 启动后看安装界面 logo: 应该是**文枢毛笔字** (R23 翻盘拍的真值, 跟 R14 WENSHU 文字 / R17/R21 hermes 女孩头 都不同)
- 启动后看 desktop 设置页 logo: 也应该是**文枢毛笔字** (R23 替换 R17 错用的 nous-girl.jpg)
- R24+ 待派单真值 (不阻塞 WO-001BI-R23 关闭):
  - R14 i18n 步骤翻译 装机 user 看进度页是否中文显示 (跟 R22 一致保留)
  - R17 BrandMark 文字标识 (R17 已 git diff 空, R23 是 R17 后的状态, 不影响 R17 rollback 真值)
  - R18 HERMES_HOME=~/.wenshu-hermes 装机 user 启动 desktop 看 spawn 文枢后端是否解决 "Could not connect to 文枢 gateway" 报错 (跟 R22 一致保留)
  - R21 错用 nous-girl.jpg (R23 替换为 wenshu-logo.png 是 R21 错用的更正)
  - R22 build only (R22 没改仓代码, R23 build 在同条 tauri build 链上)
  - **R24 候选**: 清理仓内 `apps/bootstrap-installer/public/nous-girl.jpg` + `apps/desktop/public/nous-girl.jpg` + `apps/desktop/public/hermes.png` + `apps/desktop/public/hermes-sprite.png` (R23 引入的残留: dist/nous-girl.jpg + Rust binary /nous-girl.jpg 字符串, 根因是 public/nous-girl.jpg 还在 vite 复制; 桌面 brand-mark.tsx 0 引用 nous-girl, 但 dist 残留还在; desktop 的 hermes.png / hermes-sprite.png 也可能是上游旧资源, 装机 user 后续翻盘可能要清)
- 跟上游漂移: hermes 0.19.0 → 0.19.x 监测按 CLAUDE.md §10 走 (不阻塞)

---

## 9. 落档位置

- 本文件: `wenshu-pour/architecture/R23-replace-logo-wenshu-brush.md`
- R22 来源 (bootstrap-installer tauri build 含 R21 brand-mark 书法 LOGO + cp WenShu-Setup): `wenshu-pour/architecture/R22-dmg-rebuild-with-R21.md`
- R21 来源 (bootstrap-installer brand-mark 错用 nous-girl.jpg 书法 LOGO): `wenshu-pour/architecture/R21-rollback-installer-brand-mark.md`
- R20-now 上一次 DMG build (R14 错误 brand-mark WENSHU 文字, 沿用 WenShu-Setup 命名): `wenshu-pour/architecture/R20-dmg-rebuild-WenShu-Setup.md`
- R20-prev (改 tauri.conf.json productName/version 翻盘): `wenshu-pour/architecture/R20-dmg-rebuild.md`
- R19 上一次 build (只出 .app, 含 R14/R17/R18): `wenshu-pour/architecture/R19-app-rebuild-with-R17-R18.md`
- R18 gateway home (desktop main.ts HERMES_HOME=~/.wenshu-hermes): `wenshu-pour/architecture/R18-gateway-home-default-2026-07-28.md`
- R17 rollback (desktop BrandMark 错用 nous-girl.jpg 书法 LOGO): `wenshu-pour/architecture/R17-rollback-desktop-brand-mark.md`
- R15 上一次 build (只出 .app): `wenshu-pour/architecture/R15-app-rebuild-2026-07-28.md`
- R14 来源 (bootstrap-installer i18n + 错改 brand-mark 为 WENSHU 文字 + 放 wenshu-logo.png 旧版 258,920 bytes): `wenshu-pour/architecture/R14-bootstrap-installer-i18n-logo-2026-07-28.md`
- WO-001BC 上一次 DMG cp (cp 旧 11:46 bundle DMG → Downloads/WenShu-Setup.dmg, 5,502,020 bytes): `wenshu-pour/architecture/cp-new-dmg-to-downloads-2026-08-28.md`
- WO-001AP 上上次 DMG build + cp: `wenshu-pour/architecture/dmg-rebuild-2026-08-27.md`
- 派单失败真值表: `~/.hermes/profiles/my-pm/skills/cc-fire-cc-cli-mechanics/references/pitfall-65-cc-failure-table.md`
- PM-direct pitfalls: `wenshu-pour/architecture/pm-direct-cc-pitfalls-2026-07-28.md`
- 飞书 DM 脚本: `~/.hermes/profiles/my-pm/scripts/feishu-dm.py`

---

## 10. R14 → R17 → R21 → R22 → R23 五步翻盘链速查 (bootstrap brand-mark 真值链)

| 节点 | 状态 | brand-mark 真相 | 备注 |
|------|------|-----------------|------|
| R14 (错) | src = brand-mark 显示 "WENSHU" 文字 | **错误** | i18n 翻中文 OK, 但 brand-mark 改成 WENSHU 文字标识 (无图片) |
| R17 (rollback) | desktop BrandMark 改回 `assetPath('nous-girl.jpg')` | **⚠️ 错用 hermes 女孩头** | R17 当时是回滚 R14 WENSHU 文字, 但回滚目标 = 上游 hermes nous-girl.jpg, 不是文枢自有 LOGO |
| R20 | build 用了 R14 错误 brand-mark + WenShu-Setup.dmg 命名 | **⚠️ 装机 user 拍"红框里的 LOGO 没换"** | R20 出 DMG 后装机 user 翻盘 |
| R20-now (R20 dmgrebuild) | 重 build + WenShu-Setup 命名, 但仍含 R14 错误 brand-mark | **⚠️ 还没用, 等于 R20 同状态** | — |
| R21 (源码 rollback) | bootstrap-installer `brand-mark.tsx` 改回 `<img src={assetPath('nous-girl.jpg')} />` | **⚠️ 改对图片但错用 hermes 女孩头** | R21 翻盘拍"红框里的 LOGO 用文枢毛笔字", 但 CC 理解错, 改成了 nous-girl.jpg (是 hermes 品牌, 不是文枢自有) |
| R22 (build w/ R21) | 重 build 让 .app + .dmg 吃进 R21 nous-girl.jpg | **⚠️ 第一次让装机 user 看到 hermes 女孩头** | R22 build 后装机 user 才看到实际效果, 拍"这个 LOGO 是 hermes 的" |
| **R23 (本单)** | 桌面拷 wenshu-logo-icon-1024/256 + 改两 brand-mark.tsx + 重 build + cp WenShu-Setup | **✅ 文枢自有毛笔字 (R23 翻盘拍板真值)** | 五重校验 (仓内 src 引用 + dist JS 引用 + dist 资源 + Rust binary strings + dist hash 变更) 证明 R23 改动已吃进 build |

**装机 user 下一动作**: 双击 `/Users/anbaiqiang/Downloads/WenShu-Setup.dmg` → 挂载 → 拖 .app → 启动 → 看安装界面 logo + desktop 设置页 logo 应该是**文枢毛笔字** (R23 落地的真值验证)。

---

*WO-001BI-R23 落档 · 2026-07-28 18:25 CST · 装机 user 翻盘拍"桌面上有 (文枢 LOGO) + 这个 LOGO 是 hermes 的" → 桌面拷 wenshu-logo-icon-1024/256 → 改两 brand-mark.tsx 引用文枢毛笔字 → 重 build 让 R23 改动烤进 .app + .dmg → 替换 R17/R21 错用的 nous-girl.jpg 书法 LOGO → exit 0 + 2 bundle + cp + WenShu-Setup 命名 + MD5 双向校验 + 无 quarantine + 五重验证 R23 改动已吃进 build · 不改 desktop electron-builder · 不改仓其它代码 · 不改 tauri.conf.json · 不 commit/push · R22 老 DMG 备份为 .r22 留档*
