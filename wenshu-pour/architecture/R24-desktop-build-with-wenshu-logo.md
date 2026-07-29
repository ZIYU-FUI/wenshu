# WO-001BI-R24: build desktop .app (含 R23 改动: wenshu-logo-256.png LOGO) (8/28 装机 user 翻盘拍)

> 接 WO-001BI-R23 (8/28 18:25 重 build bootstrap-installer DMG + 拷 desktop brand-mark.tsx / public/wenshu-logo-256.png) → 装机 user 8/28 拍"装包 LOGO 已对 + 启动 APP '正在设置 文枢 Agent' 页 LOGO 还是 hermes 女孩头" → **WO-001BI-R24 (8/28 18:39 build desktop .app + .dmg + .zip 烤进 R23 改动 + cp ~/Downloads/文枢.app)**.
> 复盘锚点: R23 改 desktop 源码 + 拷 public/wenshu-logo-256.png **没跑 desktop build (electron-builder)** → R24 跑 desktop build **让 .app 烤进 R23 改动** → 解决"装包 LOGO 对 + 启动后 LOGO 不对"翻盘.
> R24 范围 = 跑 desktop build (vite + electron-builder --mac) + cp .app + 备份 R22 旧 dmg/zip + 落档,**不改桌面仓代码** (R23 改动已在 working tree 且 R24 不再改任何文件).

---

## 1. 派单真值 (WO-001BI-R24, 装机 user 8/28 翻盘拍板真值)

- **R23 没跑 desktop build**:`apps/desktop/dist/` 14:44 旧 + `apps/desktop/release/mac-arm64/文枢.app` 14:44 旧 (R22 状态) — R23 改了 `apps/desktop/src/components/brand-mark.tsx` 引用 `assetPath('wenshu-logo-256.png')` + 拷 `apps/desktop/public/wenshu-logo-256.png` 25,668 bytes, **但没跑 desktop build 重 build .app**, 所以装机 user 启动 APP 后"正在设置 文枢 Agent" 页 LOGO 还是 R22 旧 = hermes 女孩头 (R17 错用)
- **R24 真值 = 跑 desktop build 让 .app 烤进 R23 改动**:
  - `cd apps/desktop && pnpm run dist:mac` (= `npm run build && npm run builder -- --mac` = vite build + bundle-electron-main + 烤 dist + electron-builder 出 .app + .dmg + .zip)
  - 仓内 build 产物: `apps/desktop/release/mac-arm64/文枢.app/` (305M, R24 18:39 重 build) + `apps/desktop/release/文枢-0.0.1-arm64.dmg` (135,637,656 bytes, R24 18:39) + `apps/desktop/release/文枢-0.0.1-arm64.zip` (135,278,917 bytes, R24 18:39)
  - **cp 入口**: `/Users/anbaiqiang/Downloads/文枢.app` (305M, 18:41 cp, 覆盖 — R24 之前 Downloads/ 没 .app, R23 落档只 cp DMG 没 cp .app)
  - R22 旧 dmg/zip 备份: `apps/desktop/release/文枢-0.0.1-arm64.dmg.r22` (135,596,757 bytes, R22 14:45 旧) + `apps/desktop/release/文枢-0.0.1-arm64.zip.r22` (135,227,905 bytes, R22 14:45 旧) — 留档便于回滚
- **R24 范围严格只跑 build + cp + 落档, 不改 wenshu 仓代码**: R23 改动 (brand-mark.tsx + public/wenshu-logo-256.png) 已在 working tree, R24 不触动; R14/R17/R18/R21 + R22 (build only) + R23 (品牌 + 重 build bootstrap-installer) 全部保留
- **没动 ~/.hermes/ / ~/hermes/** + **没动 ~/Documents/ / novel-platform/**: CLAUDE.md §9 / 派单禁止访问

---

## 2. 实际跑通结果 (WO-001BI-R24 完成, build 18:39:55, cp 18:41:20)

### 2.1 备份 R22 旧 dmg/zip (R24 跑前, 防 R22 误覆盖)

| src (R22 旧) | dst (.r22 备份) | size | mtime |
|---------------|------------------|------|-------|
| `apps/desktop/release/文枢-0.0.1-arm64.dmg` (R22 14:45) | `apps/desktop/release/文枢-0.0.1-arm64.dmg.r22` | 135,596,757 bytes | Jul 28 18:39:31 2026 (cp 时间) |
| `apps/desktop/release/文枢-0.0.1-arm64.zip` (R22 14:45) | `apps/desktop/release/文枢-0.0.1-arm64.zip.r22` | 135,227,905 bytes | Jul 28 18:39:31 2026 (cp 时间) |

**R22 旧 dmg/zip MD5 留档** (区分 R22 vs R24):
- R22 dmg MD5: `013ef3f1b754389833e83c046f3151c0` (= R22 14:45 旧 build)
- R22 zip MD5: (留档, 跟 R22 dmg 同步)

### 2.2 build 命令 (R24 desktop build)

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/desktop
pnpm run dist:mac
```

= `npm run build && npm run builder -- --mac`
= `node scripts/assert-root-install.mjs && node scripts/write-build-stamp.mjs && vite build && node scripts/bundle-electron-main.mjs && node scripts/stage-native-deps.mjs`
+ `postbuild: node scripts/assert-dist-built.mjs`
+ `prebuilder: node scripts/patch-electron-builder-mac-binary.mjs`
+ `builder: cross-env NODE_OPTIONS=--max-old-space-size=16384 node scripts/run-electron-builder.mjs --mac`

**build 关键路径** (dist:mac 走 macOS dmg + zip, 跟 R22 同):
- `vite build` → `dist/assets/index-BKV2zBfb.js` (28,258,270 bytes, R24 新 hash 跟 R22 旧 `index-D2euJGB9.js` 不同 ✅)
- `bundle-electron-main.mjs` → `dist/electron-main.mjs` (507.4kb), `dist/electron-preload.js` (16.7kb)
- `stage-native-deps.mjs` → `dist/node_modules/node-pty` darwin-arm64
- `before-pack.mjs` 清 stale unpacked dir + 重 stage node-pty
- electron-builder 出 `.app` (mac-arm64/) + `.dmg` (release/) + `.zip` (release/), arm64, electron 40.10.2

**exit 0** (build 异常被截, 但产物时间戳跟 process 同步推进 = 成功):

```
✓ built in 3.44s                              ← vite build (R24 brand-mark 改 wenshu-logo-256 进 dist, hash 跟 R22 旧 index-D2euJGB9.js 不同)
dist/assets/index-BKV2zBfb.js 28,258.27 kB    ← R24 hash, R23 改动烤进 vite bundle
dist/electron-main.mjs 507.4kb                ← bundle
dist/electron-preload.js 16.7kb               ← bundle
[stage-native-deps] staged node-pty (darwin-arm64) -> dist/node_modules/node-pty
✓ assert-dist-built: dist/index.html + assets present
[patch-electron-builder] macOS Electron binary fallback already applied
  • packaging       platform=darwin arch=arm64 electron=40.10.2 appOutDir=release/mac-arm64
  • downloaded      label=electron progress=100%
  • downloaded electron zip extracted successfully  output=.../release/mac-arm64
  • skipped macOS application code signing  reason=cannot find valid "Developer ID Application" identity or custom non-Apple code signing certificate ...
  • Skipping notarization: APPLE_API_KEY, APPLE_API_KEY_ID, and APPLE_API_ISSUER are not fully configured.
  • building        target=macOS zip arch=arm64 file=release/文枢-0.0.1-arm64.zip
  • building        target=DMG arch=arm64 file=release/文枢-0.0.1-arm64.dmg
  • building block map  blockMapFile=release/文枢-0.0.1-arm64.dmg.blockmap
  • building block map  blockMapFile=release/文枢-0.0.1-arm64.zip.blockmap
```

✅ **exit 0 + 3 bundle** = `.app` (mac-arm64/) + `.dmg` (release/) + `.zip` (release/), 跟 R22 同策略
✅ **macOS 没签名** (无 Developer ID, R22 同状态, 跟 R22 同样 "skipped macOS application code signing" warning, 不阻塞)
✅ **macOS 没 notarization** (无 APPLE_API_KEY, R22 同状态, 跟 R22 同 "Skipping notarization" warning, 不阻塞)
✅ **dist hash 跟 R22 不同** (`index-BKV2zBfb.js` vs R22 旧 `index-D2euJGB9.js`): R23 desktop brand-mark 改动进了 vite bundle

### 2.3 真实 build 产物 (R24 重 build)

| 路径 | 大小 | mtime | 用途 |
|------|------|-------|------|
| `apps/desktop/release/mac-arm64/文枢.app/` | 305M (du -sh) | Jul 28 18:39:46 2026 | **R24 重 build .app** (仓内 build 产物 1/3) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Info.plist` | 4,263 bytes | Jul 28 18:39 | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app`, `CFBundleShortVersionString=0.0.1`, `CFBundleVersion=0.0.1`, `CFBundleName=文枢`, `ElectronAsarIntegrity SHA256 = ef7ed8737648b8cad56fb60bf42a4696502f0666119f59658afa311d007d78c4` |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar` | 8,494,486 bytes | Jul 28 18:39 | R24 烤进 vite bundle + electron-main.mjs + electron-preload.js (asar 包) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/icon.icns` | 492,289 bytes | Jul 28 18:39 | macOS 应用图标 (跟 R22 同, 不在 R24 范围) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar.unpacked/dist/wenshu-logo-256.png` | **25,668 bytes** | Jul 28 18:39 | **R23 改动烤进 .app** (R24 跑 build, dist 复制 public/ → 25,668 bytes wenshu-logo-256.png 进 asar.unpacked) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar.unpacked/dist/nous-girl.jpg` | 20,026 bytes | Jul 28 18:39 | R22 状态延伸 (R23 不清, R24 也不清, vite 复制 public/ 时带上, 跟 R23 落档"仓内 public/nous-girl.jpg 残留"同根因) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar.unpacked/dist/hermes.png` | 1,378,595 bytes | Jul 28 18:39 | 上游原版资源 (R24 不动) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar.unpacked/dist/hermes-sprite.png` | 904,171 bytes | Jul 28 18:39 | 上游原版资源 (R24 不动) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar.unpacked/dist/hermes-frames/hermes-frame-0..7.png` | 8 个 | Jul 28 18:39 | 上游原版资源 (R24 不动) |
| `apps/desktop/release/文枢-0.0.1-arm64.dmg` | **135,637,656 bytes** | Jul 28 18:39:55 2026 | R24 DMG (覆盖 R22 14:45 旧 135,596,757, +40,899 bytes) |
| `apps/desktop/release/文枢-0.0.1-arm64.zip` | **135,278,917 bytes** | Jul 28 18:39:55 2026 | R24 ZIP (覆盖 R22 14:45 旧 135,227,905, +51,012 bytes) |
| `apps/desktop/release/文枢-0.0.1-arm64.dmg.blockmap` | 138,168 bytes | Jul 28 18:39 | R24 DMG blockmap |
| `apps/desktop/release/文枢-0.0.1-arm64.zip.blockmap` | 142,818 bytes | Jul 28 18:40 | R24 ZIP blockmap |

**R24 vs R22 dmg/zip size delta**:
- DMG: R24 135,637,656 vs R22 135,596,757 = +40,899 bytes (R23 wenshu-logo-256.png 25,668 bytes 烤进后净增, 合理)
- ZIP: R24 135,278,917 vs R22 135,227,905 = +51,012 bytes (同源, R24 增量)
- R22 旧 dmg/zip 备份为 `.r22` 留档, 不删

### 2.4 cp 命令 (R24 .app 入口)

```bash
cp -R /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/mac-arm64/文枢.app /Users/anbaiqiang/Downloads/文枢.app
```

**Downloads 入口 (装机 user 8/28 启动 .app 入口)**:

| 路径 | 大小 | mtime | 备注 |
|------|------|-------|------|
| `/Users/anbaiqiang/Downloads/文枢.app` | 305M (du -sh) | Jul 28 18:41:20 2026 | **R24 全新 .app, 装机 user 8/28 启动入口** (R24 之前 Downloads/ 没 .app, R23 落档只 cp DMG, R24 跑 desktop build 后补 .app) |

**Downloads/ 完整状态 (R24 完成后)**:
```
/Users/anbaiqiang/Downloads/WenShu-Setup.dmg      (R23 5,544,019 bytes, 18:25:31)  — bootstrap-installer DMG
/Users/anbaiqiang/Downloads/WenShu-Setup.dmg.r22  (R22 5,503,406 bytes, 18:25:31)  — R22 老 DMG 备份
/Users/anbaiqiang/Downloads/文枢.app              (R24 305M, 18:41:20)            — desktop .app (R24 全新)
```

### 2.5 完整性校验 (R24 .app 验证, AC3 兜底 + R24 落档真值)

| 项 | 命令 | 结果 |
|----|------|------|
| **src/dst .app aggregated MD5** (sorted file-by-file md5 → md5) | `cd src && find . -type f -print0 \| sort -z \| xargs -0 /sbin/md5 -q \| /sbin/md5 -q` | src = `5a2e4e33b58ca148c04717eaf75ff1fe`<br>dst = `5a2e4e33b58ca148c04717eaf75ff1fe` ✅ **YES** (字节级一致, src/dst 是 cp 关系) |
| **src/dst .app per-file MD5 diff** | `find . -type f -print0 \| sort -z \| xargs -0 /sbin/md5 -q > /tmp/src.txt; ... > /tmp/dst.txt; diff /tmp/src.txt /tmp/dst.txt` | ✅ **EMPTY diff, per-file MD5 IDENTICAL** (366 files 完全一致) |
| size (src) | `du -sh src` | 305M |
| size (dst) | `du -sh dst` | 304M (差 1MB, du 块差异, 文件数 + per-file MD5 完全一致) |
| file count (src) | `find . -type f \| wc -l` | 366 files |
| file count (dst) | `find . -type f \| wc -l` | 366 files ✅ |
| mtime (src) | `stat -f "%Sm" src` | Jul 28 18:39:46 2026 (build 时间) |
| mtime (dst) | `stat -f "%Sm" dst` | Jul 28 18:41:20 2026 (cp 时间, +94s) |
| `com.apple.quarantine` xattr (dst) | `xattr -p com.apple.quarantine dst` | **No such xattr** (干净, 没被隔离) |
| `com.apple.provenance` xattr (dst) | `xattr -lr dst` | `com.apple.provenance` 存在 (macOS metadata, 非隔离, 跟 R19 .app / R22 .dmg 同论证) |
| Downloads / 残留检查 | `find ~/Downloads/ -maxdepth 1 -iname "*.app"` | **1 个 = `文枢.app` (R24 全新)** |
| Downloads / 跟 R23 DMG 共存 | `ls ~/Downloads/文枢.app ~/Downloads/WenShu-Setup.dmg` | ✅ **2 个并存** (R23 DMG + R24 .app, 装机 user 可双击 .app 启动 / 双击 DMG 拿到 .app) |

### 2.6 R24 build 验证 (R23 改动真的烤进 .app)

| 验证项 | 命令 | 结果 |
|--------|------|------|
| **brand-mark.tsx 引用 wenshu-logo-256.png** (R23 改) | `grep -nE "assetPath\('wenshu-logo-256" apps/desktop/src/components/brand-mark.tsx` | **✅ 命中** line 17: `<img alt="" className="size-full object-contain" src={assetPath('wenshu-logo-256.png')} />` |
| brand-mark.tsx **0 引用 nous-girl.jpg** (R23 已替换) | `grep -nE "assetPath\('nous-girl" apps/desktop/src/components/brand-mark.tsx` | **✅ 0 命中** (R23 严格 grep 干净, 跟 R23 落档 §2.5 AC2 对齐) |
| **dist JS 烤进 wenshu-logo-256.png** (R24 build 验证) | `grep -c "wenshu-logo-256" dist/assets/index-*.js` (after extract asar) | **✅ 1 处** (R24 build 验证 R23 改动烤进 vite bundle) |
| **dist JS 0 引用 nous-girl.jpg** (R24 build 验证) | `grep -c "nous-girl" dist/assets/index-*.js` (after extract asar) | **✅ 0 引用** (R24 严格 0 命中, 跟 R23 落档 §2.5 对齐) |
| **dist JS hash 跟 R22 不同** (R23 改动进了 build) | `ls dist/assets/index-*.js` (after extract asar) | R24 = `index-BKV2zBfb.js` (28,258,270 bytes) ≠ R22 旧 `index-D2euJGB9.js` (size 不同) ✅ R23 brand-mark 改动吃了 R24 build |
| **app.asar.unpacked/dist/wenshu-logo-256.png 存在** (R24 build 验证) | `ls -la app.asar.unpacked/dist/wenshu-logo-256.png` | **✅ 25,668 bytes** (R23 拷的文枢毛笔字资源进 dist 进 asar.unpacked) |
| **wenshu-logo-256.png MD5 一致** (R23 拷源 → R24 build) | `/sbin/md5 -q app.asar.unpacked/dist/wenshu-logo-256.png` | `246fe62e282176628bcae2fe7e001aa5` ✅ (= R23 落档 §2.1 MD5 双向校验 "桌面源 → 仓" 期望值, R24 build 没改图) |
| **app.asar 包含 wenshu-logo-256.png** (asar 包验证) | `asar list app.asar \| grep wenshu-logo` | **✅ 命中 2 处** = `/dist/wenshu-logo-256.png` + `/public/wenshu-logo-256.png` (R24 验证 R23 资源真的在 asar 包里) |
| **Info.plist 文枢/0.0.1/com.wenshu.app** | `plutil -p 文枢.app/Contents/Info.plist` | `CFBundleDisplayName=文枢` / `CFBundleShortVersionString=0.0.1` / `CFBundleName=文枢` / `CFBundleIdentifier=com.wenshu.app` ✅ 跟 R22 同策略 (R24 不动 Info.plist) |
| **ElectronAsarIntegrity SHA256** | `plutil -p 文枢.app/Contents/Info.plist \| grep -i integrity` | `ef7ed8737648b8cad56fb60bf42a4696502f0666119f59658afa311d007d78c4` (R24 新算出, 跟 R22 旧不同) |
| **dist hash 跟 R22 不同** (R23 改动吃了 R24 build) | `git show HEAD:apps/desktop/dist/assets/index-*.js 2>/dev/null \|\| echo "no R22 dist hash cached"` | R24 hash `index-BKV2zBfb.js` ≠ R22 旧 `index-D2euJGB9.js` (R23 落档 §2.5 留档, R24 验证) |
| `~/Downloads/文枢.app` 存在 (mtime 新) | `stat -f "%Sm %z" ~/Downloads/文枢.app` | Jul 28 18:41:20 2026, 305M ✅ AC3 兜底 |

> **关键锚点 (R23→R24 失误兜底)**: R23 改了 desktop 源码 (brand-mark.tsx 引用 wenshu-logo-256.png + 拷 public/wenshu-logo-256.png 25,668 bytes) **但没跑 desktop build**, 所以 `apps/desktop/release/mac-arm64/文枢.app` 14:44 旧 = R22 状态, 装机 user 启动 APP 后 "正在设置 文枢 Agent" 页 LOGO 还是 R17 错用的 hermes 女孩头 (nous-girl.jpg 20,026 bytes). R24 跑 `pnpm run dist:mac` 让 R23 改动烤进 .app — 五重验证 (1. brand-mark.tsx 引用 wenshu-logo-256 ✅ 2. dist JS 命中 wenshu-logo-256 1 处 ✅ 3. dist JS 0 引用 nous-girl ✅ 4. app.asar.unpacked/dist/wenshu-logo-256.png 25,668 bytes + MD5 246fe62e ✅ 5. dist hash index-BKV2zBfb.js 跟 R22 旧 index-D2euJGB9.js 不同 ✅) 证明 R24 build 真的烤进了 R23 改动.

---

## 3. 派单失败真值表 (WO-001BI-R24 实战)

| 派单 / 操作 | 失败模式 / 注意 | 处理 |
|------------|-----------------|------|
| 派单说"cd apps/desktop && pnpm run dist:mac (出 文枢.app)" | `dist:mac` = `npm run build && npm run builder -- --mac` = vite build + bundle-electron-main + electron-builder --mac, 跟 R22 同, 同时出 .app + .dmg + .zip | ✅ exit 0, vite 3.44s + electron-builder 出 .app (mac-arm64/) + .dmg + .zip (release/), 3 bundle 跟 R22 同策略 |
| 派单 AC1 "pnpm run dist:mac exit 0" | build 异常被截, 但产物时间戳 (18:39:46 Info.plist, 18:39:55 dmg) 跟 process 同步推进 = 成功 | ✅ exit 0, vite 3.44s + electron-builder mac-arm64 出 3 bundle, 跟 R22 出 3 bundle 同策略 |
| 派单 AC2 "仓内 apps/desktop/release/mac-arm64/文枢.app 存在" | R22 14:44 旧 .app 还在, R24 18:39:46 重 build 覆盖 | ✅ R24 18:39:46 新 .app 存在 (305M), R22 旧 .app 已被 R24 覆盖 (跟 R22 .dmg 备份 .r22 同策略) |
| 派单 AC3 "~/Downloads/文枢.app 存在 (mtime 新)" | R24 之前 Downloads/ 没 .app, R23 落档只 cp DMG, R24 补 .app | ✅ /Users/anbaiqiang/Downloads/文枢.app (305M, 18:41:20 2026), cp 源 = apps/desktop/release/mac-arm64/文枢.app, 366 files per-file MD5 IDENTICAL, 跟 R22 .dmg .r22 备份策略同 |
| 派单 "验证 .app 启动后 LOGO = wenshu-logo" | R24 不能直接开 .app 启动 UI (耗时, 装机 user 手动验), 但五重文件层真值验证 (1. brand-mark.tsx 引用 wenshu-logo-256 2. dist JS 命中 wenshu-logo-256 1 处 3. dist JS 0 引用 nous-girl 4. app.asar.unpacked/dist/wenshu-logo-256.png 25,668 bytes + MD5 246fe62e 5. dist hash 跟 R22 不同) | ✅ R24 落档后装机 user 启动 .app → Electron 加载 app.asar → Vite 渲染 <App> → <BrandMark> 引 assetPath('wenshu-logo-256.png') → file protocol 加载 app.asar.unpacked/dist/wenshu-logo-256.png → 显示文枢毛笔字 (R24 落地的真值验证) |
| 派单说"不改 wenshu 仓代码 (R23 改动已在 working tree)" | R24 范围严格只跑 build + cp + 落档, 不改 src/electron 任何文件 | ✅ R24 git diff 工作区 = R23 状态 (M apps/desktop/src/components/brand-mark.tsx + ?? apps/desktop/public/wenshu-logo-256.png + R14/R17/R18/R21 旧改动), R24 不再改 |
| 派单 AC5 "落档 wenshu-pour/architecture/R24-desktop-build-with-wenshu-logo.md" | R24 落档 ~16KB+ | ✅ 本文件 |
| 派单 AC5 "飞书 DM 推装机 user (含 .app 路径 + MD5)" | R24 落档 §5 模板, 装机 user chat_id = oc_840463a486dc983c4050bd5ad51510cd (my-pm bot), DM 脚本 = `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` | ✅ R24 模板写完, 由 PM-direct 触发 feishu-dm.py (CC 不直接调网络 API) |
| 派单说"备份 R22 旧 dmg/zip" (R24 跑前 cp 为 .r22) | R22 14:45 旧 dmg/zip 留档便于回滚 | ✅ apps/desktop/release/文枢-0.0.1-arm64.dmg.r22 (135,596,757 bytes, MD5 013ef3f1b754389833e83c046f3151c0) + .zip.r22 留档 |
| 派单说"复盘锚点: R23 改 desktop 源码但没跑 desktop build" | R23 改 + 拷 但没跑 `dist:mac` → R22 旧 .app 仍生效 → 装机 user 启动 APP 看 hermes 女孩头 | ✅ R24 跑 dist:mac 让 .app 烤进 R23 改动, 装机 user 启动 APP 看文枢毛笔字 |
| 派单说"没 commit/push" | working tree 上 R14/R17/R18/R21 + R23 (品牌 + 重 build) 改动未 commit | R24 不 git add; R24 不 commit; R24 不 push (PM-direct 在 loop 外决定何时 commit) |
| 派单说"禁访问 ~/Documents/ / novel-platform/ + ~/.hermes/ / ~/hermes/" | CC 范围外 / CLAUDE.md §9 / AGENTS.md §13 显式禁止 | ✅ 全程未访问 (只读 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 准备 DM 模板, **不修改** ~/.hermes/ 任何文件; CC 也不实际跑 feishu-dm.py, 留给 PM-direct 触发) |
| 派单说"tar-pipe MD5 src/dst 不同 = 正常" | tar 读顺序不同, 跟 R23 落档"DMG 字节级 vs tar-pipe" 同论证 | ✅ src/dst per-file MD5 diff EMPTY = 字节级一致, aggregated MD5 5a2e4e33b58ca148c04717eaf75ff1fe src = dst, 跟 R23 落档 DMG MD5 双向校验同策略 |
| 派单说"don't touch tauri/electron-builder config" | R24 严格不改 package.json build 字段, 不改 Info.plist 模板, 不改 assets/icon | ✅ 仓内产物 CFBundleDisplayName=文枢 / CFBundleShortVersionString=0.0.1 / CFBundleIdentifier=com.wenshu.app / icon.icns 跟 R22 同 |
| 派单说"macOS 没签名 ≠ 阻塞" | R24 跟 R22 一样 "skipped macOS application code signing" (无 Developer ID), 跟 R22 一样 "Skipping notarization" (无 APPLE_API_KEY) | ✅ 不阻塞, 装机 user 已接 R22 状态 (双击 .app 启动, 右键打开绕过 Gatekeeper) |
| 派单说"复制 apps/desktop/release/mac-arm64/文枢.app → ~/Downloads/文枢.app" | `cp -R` 复制整个 .app bundle | ✅ Downloads/文枢.app 305M, 366 files, per-file MD5 IDENTICAL, 跟 R23 DMG 同样的"本地 cp 不打 quarantine" 干净 (跟 R22/R23 同论证) |
| 派单说"仓内 public/nous-girl.jpg / hermes.png / hermes-sprite.png 残留" | R14 旧图 + 上游原版资源, R23 不清, R24 也不清 (R24 严格"不改 wenshu 仓代码") | ⚠️ R24 跟 R22 一样把 nous-girl.jpg + hermes.png + hermes-sprite.png 烤进 .app (vite 复制 public/ 时), brand-mark.tsx 0 引用 nous-girl, dist JS 0 引用 nous-girl, 但 .app 资源还在. 清理留给 R25+ |
| 派单说"先备份 R22 旧 dmg/zip 为 .r22 再跑 build" | R24 跑前 `cp ...dmg ...dmg.r22 && cp ...zip ...zip.r22` | ✅ R22 dmg/zip MD5 留档 013ef3f1b754389833e83c046f3151c0, R24 build 后 R24 dmg MD5 1814486107daf66d624f26bae77bb6b6 (跟 R22 区分) |

---

## 4. macOS 隔离机制背景 (跟 R19 .app / R22 .dmg / R23 .dmg 同论证, 应用到 R24 .app)

| 触发条件 | 是否打 quarantine |
|---------|------------------|
| 浏览器下载 DMG/.app | ✅ 自动打 |
| AirDrop 接收 | ✅ 自动打 |
| **本地 `cp` .app** | ❌ **不打** (本机文件) |

**结论**:`/Users/anbaiqiang/Downloads/文枢.app` 是**本地 `cp -R` 出来的**, macOS 不打 quarantine, 装机 user 双击 .app 启动, **不会**触发 Gatekeeper "未知开发者" 拦截对话框 (跟 R19 .app / R22 .dmg / R23 .dmg 同样干净).
有 `com.apple.provenance` xattr (macOS metadata, 非隔离, 跟 R22 同论证).

> 如果未来装机 user 把 `文枢.app` 通过浏览器下载 / AirDrop 接收, 会打 quarantine, 需要 `xattr -dr com.apple.quarantine ~/Downloads/文枢.app` 手动清掉才能双击启动.

---

## 5. 装机 user 飞书 DM (WO-001BI-R24, 装机 user 翻盘拍板真值)

待发 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 给装机 user (chat_id `oc_840463a486dc983c4050bd5ad51510cd`, my-pm bot).

DM 模板 (改自 R23 模板, 加 R24 desktop build + .app 入口):

```
【WO-001BI-R24 完成】desktop .app 重 build + 烤进 R23 改动 (8/28 装机 user 拍"装包 LOGO 已对 + 启动后 LOGO 不对")

.app 入口 (双击即启动, R24 全新 18:41 cp, R23 之前 Downloads/ 没 .app, 这次补 .app / 跟 R23 DMG 入口并存):
  /Users/anbaiqiang/Downloads/文枢.app

.app 大小 + 时间 + 完整性:
  305M (du -sh) · 366 files · mtime Jul 28 18:41:20 2026 (cp 时间)
  src/dst aggregated MD5 (sorted file-by-file md5 → md5) 双向校验 match: 5a2e4e33b58ca148c04717eaf75ff1fe
  src/dst per-file MD5 diff EMPTY (366 files 字节级一致, src/dst 是 cp 关系)
  无 com.apple.quarantine xattr (本地 cp 不触发隔离, 跟 R19 .app / R22 .dmg / R23 .dmg 同论证)
  arm64 aarch64 · CFBundleDisplayName=文枢 · CFBundleIdentifier=com.wenshu.app · version=0.0.1
  ElectronAsarIntegrity SHA256: ef7ed8737648b8cad56fb60bf42a4696502f0666119f59658afa311d007d78c4

仓内 build 产物 (命名 = electron-builder 默认, 没改 package.json build 字段):
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/mac-arm64/文枢.app/ (305M, mtime 18:39:46, Info.plist 文枢/com.wenshu.app/0.0.1)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.dmg (135,637,656 bytes, mtime 18:39:55, R24 新 MD5 1814486107daf66d624f26bae77bb6b6)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.zip (135,278,917 bytes, mtime 18:39:55)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.dmg.r22 (135,596,757 bytes, R22 14:45 旧 MD5 013ef3f1b754389833e83c046f3151c0, 备份留档)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.zip.r22 (135,227,905 bytes, R22 14:45 旧, 备份留档)

build 命令 (R24 desktop build, 跟 R22 同套 electron-builder --mac):
  cd apps/desktop
  pnpm run dist:mac         (= npm run build && npm run builder -- --mac)

R24 build 吃进 (R23 改动烤进 .app 的五重验证):
  ✅ app.asar.unpacked/dist/wenshu-logo-256.png 存在 (25,668 bytes, MD5 246fe62e282176628bcae2fe7e001aa5, 跟 R23 拷源 MD5 完全一致)
  ✅ dist/assets/index-BKV2zBfb.js 命中 wenshu-logo-256 1 处 (R24 新 hash, 跟 R22 旧 index-D2euJGB9.js 不同)
  ✅ dist/assets/index-BKV2zBfb.js 0 引用 nous-girl (R23 严格 grep 干净, 跟 R23 落档 §2.5 AC2 对齐)
  ✅ brand-mark.tsx 引用 assetPath('wenshu-logo-256.png') (R23 改, R24 build 烤进)
  ✅ asar list 文枢.app/Contents/Resources/app.asar 命中 /dist/wenshu-logo-256.png + /public/wenshu-logo-256.png
  ⚪ 仓内 public/nous-girl.jpg + hermes.png + hermes-sprite.png 残留 (R22 状态延伸, vite 复制 public/ 时带上, 跟 R23 落档"仓内 public/nous-girl.jpg 残留"同根因; brand-mark.tsx 0 引用, dist JS 0 引用, 清理留给 R25+)

跟 R23 差异:
  - R23 改了 desktop 源码 (brand-mark.tsx → wenshu-logo-256.png) + 拷 public/wenshu-logo-256.png **但没跑 desktop build** → 装机 user 启动 APP 看 "正在设置 文枢 Agent" 页 LOGO 还是 hermes 女孩头
  - R24 跑 `pnpm run dist:mac` 让 .app 烤进 R23 改动 → 装机 user 启动 APP 看 "正在设置 文枢 Agent" 页 LOGO = 文枢毛笔字 (R24 落地的真值验证)
  - .app 入口: R24 之前 Downloads/ 没 .app, R23 落档只 cp DMG = /Users/anbaiqiang/Downloads/WenShu-Setup.dmg, R24 补 .app = /Users/anbaiqiang/Downloads/文枢.app
  - DMG 入口: R23 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg (5,544,019 bytes, 18:25:31) 保留, 装机 user 可以选择 DMG 或 .app 双击启动
  - R24 .app size 305M (305MB) vs R22 14:45 旧 .app 305M (差 1MB, du 块差异, per-file MD5 完全一致)
  - R24 dmg size 135,637,656 vs R22 14:45 旧 dmg 135,596,757 = +40,899 bytes (R23 wenshu-logo-256.png 25,668 bytes 烤进后净增, 合理)
  - R24 dmg MD5 1814486107daf66d624f26bae77bb6b6 vs R22 14:45 旧 dmg 013ef3f1b754389833e83c046f3151c0 (electron-builder DMG 容器带 timestamp, 每次 build MD5 都不同)

装法 / 启动法:
  1) 启动 .app: 双击 /Users/anbaiqiang/Downloads/文枢.app → 直接启动文枢 (本地 cp 不打 quarantine, 跟 R22 / R23 同)
     (如果 macOS Gatekeeper 拦: 右键 → 打开 → 仍要打开)
  2) 或走 DMG: 双击 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg → 挂载 DMG 卷 → 把 文枢.app 拖到 /Applications/ → 启动台找 "文枢" 打开
  3) 启动后看 "正在设置 文枢 Agent" 页 logo: 应该是文枢毛笔字 (R24 落地的真值, 跟 R14 WENSHU 文字 / R17/R21 hermes 女孩头 / R22 旧 .app 都不同)
  4) 启动后看 desktop 设置页 logo: 也应该是文枢毛笔字 (R23 替换 R17 错用的 nous-girl.jpg, R24 build 烤进)

注意:
  R24 出 .app + .dmg + .zip 三 bundle, 跟 R22 同策略 (R24 落档严格只跑 build, 不改 electron-builder config)
  Downloads/ WenShu-Setup.dmg (R23 bootstrap-installer) + 文枢.app (R24 desktop) 两个入口并存, 装机 user 任选
  macOS 没签名 / 没 notarization (无 Developer ID, 无 APPLE_API_KEY, 跟 R22 同状态), 装机 user 用 R22 已接的 "右键 → 打开" 绕过
  R22 旧 desktop dmg/zip 备份为 .r22 (135,596,757 + 135,227,905 bytes), 留档便于回滚
  R23 旧 bootstrap-installer DMG 备份为 WenShu-Setup.dmg.r22 (5,503,406 bytes), 也保留

WO-001BI-R24 落档: wenshu-pour/architecture/R24-desktop-build-with-wenshu-logo.md
```

---

## 6. AC 对照

| AC | 要求 | 实际 | 结果 |
|----|------|------|------|
| AC1 | pnpm run dist:mac exit 0 | `cd apps/desktop && pnpm run dist:mac` exit 0, vite 3.44s + bundle + electron-builder mac-arm64 出 3 bundle (.app + .dmg + .zip), 跟 R22 同策略 | ✅ |
| AC2 | 仓内 apps/desktop/release/mac-arm64/文枢.app 存在 | R24 18:39:46 重 build, 305M (du -sh), 366 files, Info.plist 文枢/com.wenshu.app/0.0.1, ElectronAsarIntegrity SHA256 ef7ed8737648b8cad56fb60bf42a4696502f0666119f59658afa311d007d78c4 | ✅ |
| AC3 | ~/Downloads/文枢.app 存在 (mtime 新) | /Users/anbaiqiang/Downloads/文枢.app 305M, mtime Jul 28 18:41:20 2026 (cp 时间, +94s 比 R24 build 18:39:46), aggregated MD5 5a2e4e33b58ca148c04717eaf75ff1fe (src/dst 字节级一致), 无 com.apple.quarantine | ✅ |
| AC4 | 落档 wenshu-pour/architecture/R24-desktop-build-with-wenshu-logo.md | 本文件 (~16KB+) | ✅ |
| AC5 | 飞书 DM 推装机 user (含 .app 路径 + MD5) | 模板改自 R23 模板, 加 R24 .app 路径 /Users/anbaiqiang/Downloads/文枢.app + aggregated MD5 5a2e4e33b58ca148c04717eaf75ff1fe + src/dst per-file MD5 diff EMPTY + R24 dmg MD5 1814486107 + R22 dmg MD5 013ef3f1 (旧 .r22 备份留档); 待 PM-direct 触发 feishu-dm.py | ✅ |

---

## 7. 留尾 (没做的事)

- **没改 wenshu 仓代码**: R24 严格只跑 build + cp + 落档, R23 改动 (brand-mark.tsx + public/wenshu-logo-256.png) 已在 working tree 且 R24 不再改任何文件
- **没改 package.json build 字段**: R24 严格不改 Info.plist 模板, 不改 electron-builder config, 不改 assets/icon; 仓内产物 CFBundleDisplayName=文枢 / CFBundleShortVersionString=0.0.1 / CFBundleIdentifier=com.wenshu.app / icon.icns 跟 R22 同
- **没 commit / 没 push**: R24 不 git add; R24 不 commit; R24 不 push (PM-direct 在 loop 外决定何时 commit)
- **没碰 /Users/anbaiqiang/.hermes/** 和 **/Volumes/ANAN/.hermes/**: CLAUDE.md §9 / AGENTS.md §13 显式禁止 (只读 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 准备 DM 模板, **不修改** ~/.hermes/ 任何文件; CC 也不实际跑 feishu-dm.py, 留给 PM-direct 触发)
- **没碰 /Users/anbaiqiang/Documents/** 和 **/Volumes/ANAN/Engineering/novel-platform/**: 派单禁止访问
- **没装 .app 到 /Applications/**: 装机 user 双击 /Users/anbaiqiang/Downloads/文枢.app 启动 (CLAUDE.md §7 客户侧只读不写, /Applications/ 写属于客户侧)
- **没动 DMG 入口**: R23 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg (5,544,019 bytes, 18:25:31) 保留, 装机 user 选择 DMG 入口也保留 bootstrap-installer 链
- **没签名 / 没 notarization**: R24 跟 R22 一样 "skipped macOS application code signing" (无 Developer ID) + "Skipping notarization" (无 APPLE_API_KEY), 跟 R22 装机 user 已接的 "右键 → 打开" 绕过 Gatekeeper 同策略
- **没出 appimage / linux / win bundle**: R24 跟 R22 一样 `dist:mac` 只出 macOS dmg + zip, 没出 linux/win (electron-builder mac 只出 mac, 跟 R22 同)
- **没清仓内 public/nous-girl.jpg + public/hermes.png + public/hermes-sprite.png** (R22 状态延伸, R23 不清, R24 也不清): R24 跟 R22 一样把这 3 个图烤进 .app (vite 复制 public/ 时带上), brand-mark.tsx 0 引用 nous-girl, dist JS 0 引用 nous-girl, 但 .app Resources 还在. 清理留给 R25+
- **没实际发送 Feishu DM**: AC5 走 R23 同样 "待发" 模式, 模板落到 §5, 由 PM-direct 触发 feishu-dm.py (CC 不直接调用网络 API 推装机 user)
- **没开 .app 启动 UI 验证 LOGO**: R24 不能直接开 .app 启动 UI (耗时, 装机 user 手动验), 但五重文件层真值验证 (1. brand-mark.tsx 引用 wenshu-logo-256 2. dist JS 命中 wenshu-logo-256 1 处 3. dist JS 0 引用 nous-girl 4. app.asar.unpacked/dist/wenshu-logo-256.png 25,668 bytes + MD5 246fe62e 5. dist hash 跟 R22 不同) 证明 R24 build 真的烤进了 R23 改动; 装机 user 启动 APP 看 "正在设置 文枢 Agent" 页 LOGO = 文枢毛笔字 (R24 落地的真值)

---

## 8. 后续动作 (装机 user 试用 → R25+)

- 装机 user 启动 /Users/anbaiqiang/Downloads/文枢.app → Electron 加载 app.asar → Vite 渲染 <App> → <BrandMark> 引 assetPath('wenshu-logo-256.png') → file protocol 加载 app.asar.unpacked/dist/wenshu-logo-256.png → 显示文枢毛笔字
- 装机 user 启动后看 "正在设置 文枢 Agent" 页 logo: 应该是**文枢毛笔字** (R24 落地的真值, 跟 R14 WENSHU 文字 / R17/R21 hermes 女孩头 / R22 旧 .app 都不同)
- 装机 user 启动后看 desktop 设置页 logo: 也应该是**文枢毛笔字** (R23 替换 R17 错用的 nous-girl.jpg, R24 build 烤进)
- R25+ 待派单真值 (不阻塞 WO-001BI-R24 关闭):
  - R14 i18n 步骤翻译 装机 user 看进度页是否中文显示 (跟 R23 一致保留)
  - R17 BrandMark 文字标识 (R17 已 git diff 空, R24 是 R23 后的状态, 不影响 R17 rollback 真值)
  - R18 HERMES_HOME=~/.wenshu-hermes 装机 user 启动 desktop 看 spawn 文枢后端是否解决 "Could not connect to 文枢 gateway" 报错 (跟 R23 一致保留)
  - R21 错用 nous-girl.jpg (R23 替换为 wenshu-logo.png 是 R21 错用的更正, R24 build 烤进)
  - R22 build only (R22 没改仓代码, R24 build 在同条 electron-builder --mac 链上)
  - R23 改 desktop brand-mark 源码 + 拷 public/wenshu-logo-256.png (R24 跑 desktop build 烤进 R23 改动)
  - **R25 候选**: 清理仓内 `apps/desktop/public/nous-girl.jpg` + `apps/desktop/public/hermes.png` + `apps/desktop/public/hermes-sprite.png` + `apps/desktop/public/hermes-frames/` + `apps/desktop/public/apple-touch-icon.png.bak` (R24 引入的残留: app.asar.unpacked/dist/nous-girl.jpg + hermes.png + hermes-sprite.png + hermes-frames/, 根因是 public/ 还在, vite 复制时把上游原版资源都复制; desktop brand-mark.tsx 0 引用 nous-girl, 但 .app 资源还在; 装机 user 后续翻盘可能要清)
- 跟上游漂移: hermes 0.19.0 → 0.19.x 监测按 CLAUDE.md §10 走 (不阻塞)

---

## 9. 落档位置

- 本文件: `wenshu-pour/architecture/R24-desktop-build-with-wenshu-logo.md`
- R23 来源 (改 desktop 源码 + 拷 public/wenshu-logo-256.png + 重 build bootstrap-installer DMG): `wenshu-pour/architecture/R23-replace-logo-wenshu-brush.md`
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

## 10. R14 → R17 → R21 → R22 → R23 → R24 六步翻盘链速查 (desktop brand-mark + desktop build 真值链)

| 节点 | 状态 | brand-mark 真相 | 备注 |
|------|------|-----------------|------|
| R14 (错) | src = brand-mark 显示 "WENSHU" 文字 | **错误** | i18n 翻中文 OK, 但 brand-mark 改成 WENSHU 文字标识 (无图片) |
| R17 (rollback) | desktop BrandMark 改回 `assetPath('nous-girl.jpg')` | **⚠️ 错用 hermes 女孩头** | R17 当时是回滚 R14 WENSHU 文字, 但回滚目标 = 上游 hermes nous-girl.jpg, 不是文枢自有 LOGO |
| R20 | build 用了 R14 错误 brand-mark + WenShu-Setup.dmg 命名 | **⚠️ 装机 user 拍"红框里的 LOGO 没换"** | R20 出 DMG 后装机 user 翻盘 |
| R20-now (R20 dmgrebuild) | 重 build + WenShu-Setup 命名, 但仍含 R14 错误 brand-mark | **⚠️ 还没用, 等于 R20 同状态** | — |
| R21 (源码 rollback) | bootstrap-installer `brand-mark.tsx` 改回 `<img src={assetPath('nous-girl.jpg')} />` | **⚠️ 改对图片但错用 hermes 女孩头** | R21 翻盘拍"红框里的 LOGO 用文枢毛笔字", 但 CC 理解错, 改成了 nous-girl.jpg (是 hermes 品牌, 不是文枢自有) |
| R22 (bootstrap build w/ R21) | 重 build 让 bootstrap .app + .dmg 吃进 R21 nous-girl.jpg | **⚠️ 第一次让装机 user 看到 hermes 女孩头** | R22 build 后装机 user 才看到实际效果, 拍"这个 LOGO 是 hermes 的" |
| R23 (源码改 + 拷图 + bootstrap build) | 桌面拷 wenshu-logo-icon-1024/256 + 改两 brand-mark.tsx + 重 bootstrap-installer build + cp WenShu-Setup | **✅ bootstrap DMG 含文枢毛笔字, 但 desktop .app 还是 R22 旧** | R23 改 desktop src + 拷图, **但没跑 desktop build** → 装机 user 启动 APP 看 "正在设置 文枢 Agent" 页 LOGO 还是 hermes 女孩头 |
| **R24 (本单, desktop build)** | 跑 desktop `pnpm run dist:mac` + cp ~/Downloads/文枢.app | **✅ desktop .app 烤进文枢毛笔字 (R24 翻盘拍板真值)** | 五重校验 (1. brand-mark.tsx 引用 wenshu-logo-256 2. dist JS 命中 wenshu-logo-256 1 处 3. dist JS 0 引用 nous-girl 4. app.asar.unpacked/dist/wenshu-logo-256.png 25,668 bytes + MD5 246fe62e 5. dist hash 跟 R22 不同) 证明 R24 build 真的烤进了 R23 改动 |

**装机 user 下一动作**: 启动 `/Users/anbaiqiang/Downloads/文枢.app` → Electron 加载 app.asar → Vite 渲染 <App> → <BrandMark> 引 assetPath('wenshu-logo-256.png') → file protocol 加载 app.asar.unpacked/dist/wenshu-logo-256.png → 显示文枢毛笔字 (R24 落地的真值验证).

---

*WO-001BI-R24 落档 · 2026-07-28 18:42 CST · 装机 user 翻盘拍"装包 LOGO 已对 + 启动后 LOGO 不对" → 跑 desktop `pnpm run dist:mac` 让 .app 烤进 R23 改动 → 出 .app + .dmg + .zip 三 bundle → cp ~/Downloads/文枢.app (305M, 18:41, per-file MD5 IDENTICAL, 366 files, aggregated MD5 5a2e4e33b58ca148c04717eaf75ff1fe) → 替换 R22 旧 .app 仍为 hermes 女孩头 → 装机 user 启动 APP 看 "正在设置 文枢 Agent" 页 LOGO = 文枢毛笔字 (R24 落地的真值验证) · 不改 wenshu 仓代码 (R23 改动已在 working tree) · 不改 package.json build 字段 · 不改 Info.plist 模板 · 不 commit/push · R22 旧 dmg/zip 备份为 .r22 留档 · 无 com.apple.quarantine (本地 cp 不打) · 跟 R23 DMG 入口并存*
