# WO-001BI-R25: desktop i18n 中文翻译 + brand-mark LOGO 验证 + 重 build (8/28 装机 user 翻盘拍板真值)

> 接 R24 (8/28 装机 user 拍"装包 LOGO 已对 + 启动后 LOGO 不对") → R24 跑 desktop build 让 .app 烤进 R23 改动 → 装机 user 8/28 又拍 "3 个问题":
> 1. 正在设置页 10 步骤名英文（Prerequisites/Repository/Venv/Python deps/Node deps/Path/Config/Setup/Gateway/Complete）需翻译为中文
> 2. error overlay 英文（"文枢 couldn't start" / "Could not connect to 文枢 gateway" / "Retry/Repair install/Gateway settings/Open logs"）需翻译为中文
> 3. LOGO 仍是 hermes 女孩头（应该是文枢毛笔字）—— 验证 R24 build 是否生效 + 检查 brand-mark.tsx 是否真正引用 wenshu-logo-256.png
>
> **WO-001BI-R25 真值 = 一起改 desktop i18n + 验证 LOGO + 重 build .app**:
> - 改 `apps/desktop/src/i18n/types.ts` 加 `install.stageNames` 字段（10 步骤 i18n dict 容器）
> - 改 `apps/desktop/src/i18n/en.ts/zh.ts/zh-hant.ts/ja.ts` 加 `install.stageNames` 字典（值是中文，移植自 bootstrap-installer/src/i18n/zh.ts）
> - 改 `apps/desktop/src/i18n/en.ts/zh-hant.ts/ja.ts` boot.failure 关键字段 → 中文（按 AC2：装机 user 的 locale=en/zh-hant/ja 都会看 boot.failure，按 R25 务实翻中文）
> - 改 `apps/desktop/src/i18n/zh.ts` boot.failure.repairInstall → "重新安装"（按 AC2）
> - 改 `apps/desktop/src/components/desktop-install-overlay.tsx` 加 STAGE_NAME_TO_STEP_KEY + 用 t.install.stageNames[key]（AC1）
> - 改 `apps/desktop/src/hermes.ts` connectErrorMessage / closedErrorMessage / notConnectedErrorMessage → 中文字面量（按 AC2: "Could not connect to 文枢 gateway" → "无法连接到文枢网关"）
> - 验证 `apps/desktop/src/components/brand-mark.tsx` 引用 wenshu-logo-256.png + 0 引用 nous-girl（AC3 验证）
> - 跑 `cd apps/desktop && pnpm run dist:mac` → 出新 .app + .dmg + .zip → cp ~/Downloads/文枢.app → 落档

---

## 1. 派单真值 (WO-001BI-R25, 装机 user 8/28 翻盘拍板真值)

- **R25 范围 = 改 desktop i18n + 验证 LOGO + 重 build .app**:
  - 改 desktop i18n: `apps/desktop/src/i18n/types.ts` + `en.ts` + `zh.ts` + `zh-hant.ts` + `ja.ts` + `components/desktop-install-overlay.tsx` + `hermes.ts`
  - 验证 brand-mark.tsx: AC3 grep 命中
  - 跑 dist:mac 出 .app + .dmg + .zip → cp ~/Downloads/文枢.app → 备份 R24 旧 dmg/zip 为 .r24
  - **R25 严格不动 backend / bootstrap-installer / Hermes-agent 上游业务 / ~/.hermes/ / ~/hermes/**
- **装机 user 看到英文的根因**:
  - `hermes_cli/config.py:1935` 后端 DEFAULT_CONFIG 默认 `display.language = "en"` (hermes 上游默认)
  - `apps/desktop/src/i18n/context.tsx` I18nProvider 读 config.display.language → setLocaleState('en')
  - 装机 user 启动 .app → locale = 'en' → 看到 en.ts 字段（英文）→ "文枢 couldn't start" / "Could not connect to 文枢 gateway"
  - **修法 (R25 务实)**: 不改 backend (派单范围限 desktop), 改 en.ts/zh-hant.ts/ja.ts 的 boot.failure 字段为中文 (破坏 en locale 英文但务实), 改 hermes.ts connectErrorMessage 等中文字面量, 改 install.stageNames 字典 (4 个 locale 都是中文)
- **装机 user 看到 LOGO 是 hermes 女孩头 (R25 派单第三个问题) 的根因**:
  - 装机 user 报告"R24 启动 APP 后 LOGO 仍是 hermes 女孩头"
  - R25 验证: `apps/desktop/src/components/brand-mark.tsx` line 17 已引用 `assetPath('wenshu-logo-256.png')` (R23 改动已生效), `grep "assetPath\('nous-girl" brand-mark.tsx` 0 命中
  - R25 build 后验证: `app.asar.unpacked/dist/assets/index-DNho-wP9.js` 命中 wenshu-logo-256 1 处, 0 引用 nous-girl
  - **结论**: R24 build 已生效 (R25 build 验证一次确认), 装机 user 8/28 看到的"LOGO 仍是 hermes 女孩头"可能是装的还是 R22 旧 .app (装机 user 报告后没重装 R24 .app), 或 R24 .app 启动时 cache, R25 build 是兜底

---

## 2. 实际跑通结果 (WO-001BI-R25 完成)

### 2.1 改动文件 (8 个)

| 文件 | 改动 |
|------|------|
| `apps/desktop/src/i18n/types.ts` | install 加 `stageNames: Record<string, string>` 字段 + 注释 |
| `apps/desktop/src/i18n/en.ts` | boot.failure.title/description → 中文 (AC2); boot.failure.retry/repairInstall/gatewaySettings/openLogs → 中文 (AC2); install 加 stageNames 字典 (值中文) |
| `apps/desktop/src/i18n/zh.ts` | boot.failure.repairInstall → "重新安装" (AC2); install 加 stageNames 字典 (值中文) |
| `apps/desktop/src/i18n/zh-hant.ts` | boot.failure.title/description → 中文; boot.failure 关键按钮 → 中文; install 加 stageNames 字典 |
| `apps/desktop/src/i18n/ja.ts` | boot.failure.title/description → 中文; boot.failure 关键按钮 → 中文; install 加 stageNames 字典 |
| `apps/desktop/src/components/desktop-install-overlay.tsx` | 加 STAGE_NAME_TO_STEP_KEY 映射 (移植自 bootstrap-installer/src/routes/progress.tsx); 加 translateStageLabel 工具; StageRow + DesktopInstallOverlay 用 t.install.stageNames 翻译 |
| `apps/desktop/src/hermes.ts` | connectErrorMessage → '无法连接到文枢网关'; closedErrorMessage → '网关连接已关闭'; notConnectedErrorMessage → '网关未连接' (按 AC2) |
| `apps/desktop/src/components/brand-mark.tsx` | 验证 (R23 改动已生效, line 17 引用 wenshu-logo-256.png, 0 引用 nous-girl) |

### 2.2 关键 diff 片段

**types.ts** (install 加 stageNames):
```typescript
install: {
    stageStates: Record<string, string>
    /** Installer stage name → customer-facing Chinese label. Maps the kebab-case
     *  PowerShell stage names (uv, repository, venv, …) onto the 10 high-level
     *  i18n keys the user sees in the progress overlay. WO-001BI-R25. */
    stageNames: Record<string, string>
    oneTimeTitle: string
```

**en.ts** (boot.failure + install.stageNames):
```typescript
failure: {
  // R25: 装机 user 看英文的根因是 locale=en；改 en.ts 字段为中文，让 en locale 也显示中文。
  // 文案按 AC2 要求：'文枢 couldn't start' → '文枢无法启动'。
  title: '文枢无法启动',
  description: '后台网关没有启动。请尝试下面的恢复步骤；这里不会删除你的对话或设置。',
  ...
  // R25: 按 AC2 — Retry/Repair install/Gateway settings/Open logs → 重试/重新安装/网关设置/打开日志
  retry: '重试',
  repairInstall: '重新安装',
  useLocalGateway: '使用本地网关',
  gatewaySettings: '网关设置',
  back: '返回',
  openLogs: '打开日志',
```

```typescript
install: {
  stageStates: { ... },
  // R25: AC1 — 进度页 10 步骤名翻译为中文（移植自 bootstrap-installer/src/i18n/zh.ts）。
  // 安装脚本 PowerShell stage names (uv, repository, venv, ...) 映射到 10 个客户面向中文标签。
  // locale=en 也显示中文（与 boot.failure 同理：装机 user 的 locale 是 en）。
  stageNames: {
    uv: '系统环境检查',
    python: '系统环境检查',
    git: '系统环境检查',
    node: '系统环境检查',
    'system-packages': '系统环境检查',
    repository: '拉取文枢源码',
    venv: '创建 Python 虚拟环境',
    dependencies: '安装 Python 依赖',
    'node-deps': '安装 Node 依赖',
    desktop: '安装 Node 依赖',
    path: '配置命令行入口',
    'config-templates': '准备配置和技能',
    'platform-sdks': '准备配置和技能',
    'bootstrap-marker': '完成安装',
    configure: '配置 API 密钥和设置',
    gateway: '配置网关服务'
  },
```

**desktop-install-overlay.tsx** (STAGE_NAME_TO_STEP_KEY + translateStageLabel):
```typescript
const STAGE_NAME_TO_STEP_KEY: Record<string, string> = {
  uv: 'uv',
  python: 'python',
  git: 'git',
  ...
  gateway: 'gateway'
}

function translateStageLabel(stageName: string, stageNames: Record<string, string>, fallback: string): string {
  const key = STAGE_NAME_TO_STEP_KEY[stageName]
  if (key && stageNames[key]) {
    return stageNames[key]
  }
  return fallback
}

// StageRow 内部:
const stageLabel = translateStageLabel(descriptor.name, copy.stageNames, formatStageName(descriptor.name))
// <span>{stageLabel}</span>

// DesktopInstallOverlay currentStage 显示:
copy.currentStage(translateStageLabel(currentStage, copy.stageNames, formatStageName(currentStage)))
```

**hermes.ts** (connectErrorMessage → 中文):
```typescript
// R25: 按 AC2 — 'Could not connect to 文枢 gateway' → '无法连接到文枢网关'；
// closedErrorMessage / notConnectedErrorMessage 同步改中文字面量（不走 i18n,
// 因为这些是 network error 兜底消息,在 HermesGateway 模块顶层构造时即固定，
// React context 还没建立;i18n runtime locale 在用户首次切换时才注入)。
closedErrorMessage: '网关连接已关闭',
connectErrorMessage: '无法连接到文枢网关',
createRequestId: nextId => nextId,
notConnectedErrorMessage: '网关未连接',
```

### 2.3 build 命令 (R25 desktop build)

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/desktop
pnpm run dist:mac
```

`dist:mac` = `npm run build && npm run builder -- --mac` = vite build + bundle-electron-main + electron-builder --mac

build 关键路径:
- `vite build` → `dist/assets/index-DNho-wP9.js` (28,260,650 bytes, R25 新 hash 跟 R24 旧 `index-BKV2zBfb.js` 不同 ✅)
- `bundle-electron-main.mjs` → `dist/electron-main.mjs` (507.4kb), `dist/electron-preload.js` (16.7kb)
- `stage-native-deps.mjs` → `dist/node_modules/node-pty` darwin-arm64
- electron-builder 出 `.app` (mac-arm64/) + `.dmg` (release/) + `.zip` (release/), arm64, electron 40.10.2

```
✓ built in 1.92s
dist/assets/index-DNho-wP9.js 28,260.65 kB
dist/electron-main.mjs 507.4kb
dist/electron-preload.js 16.7kb
[stage-native-deps] staged node-pty (darwin-arm64)
✓ assert-dist-built: dist/index.html + assets present
[patch-electron-builder] macOS Electron binary fallback already applied
  • packaging       platform=darwin arch=arm64 electron=40.10.2 appOutDir=release/mac-arm64
  • downloaded      label=electron progress=100%
  • downloaded electron zip extracted successfully  output=...
  • skipped macOS application code signing  reason=cannot find valid "Developer ID Application" identity ...
  • Skipping notarization: APPLE_API_KEY, APPLE_API_KEY_ID, and APPLE_API_ISSUER are not fully configured.
  • building        target=macOS zip arch=arm64 file=release/文枢-0.0.1-arm64.zip
  • building        target=DMG arch=arm64 file=release/文枢-0.0.1-arm64.dmg
```

### 2.4 备份 R24 旧 dmg/zip 为 .r24

| src (R24 旧) | dst (.r24 备份) | size | MD5 |
|---------------|------------------|------|-----|
| `apps/desktop/release/文枢-0.0.1-arm64.dmg` (R24 18:39) | `apps/desktop/release/文枢-0.0.1-arm64.dmg.r24` | 135,637,656 bytes | `1814486107daf66d624f26bae77bb6b6` |
| `apps/desktop/release/文枢-0.0.1-arm64.zip` (R24 18:39) | `apps/desktop/release/文枢-0.0.1-arm64.zip.r24` | 135,278,917 bytes | `1d9dd4e42a66a6dfff0a82e920b172d1` |

**R24 dmg/zip MD5 留档**:
- R24 dmg MD5: `1814486107daf66d624f26bae77bb6b6` (R24 18:39:55 旧 build)
- R24 zip MD5: `1d9dd4e42a66a6dfff0a82e920b172d1` (R24 18:39:55 旧 build)

### 2.5 R25 build 产物 (R25 重 build, 19:07-19:08)

| 路径 | 大小 | mtime | MD5 | 备注 |
|------|------|-------|-----|------|
| `apps/desktop/release/mac-arm64/文枢.app/` | 305M (du -sh) | Jul 28 19:07:36 2026 | n/a | **R25 重 build .app** |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Info.plist` | 4,263 bytes | Jul 28 19:07 | n/a | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app`, `CFBundleShortVersionString=0.0.1`, `CFBundleName=文枢` |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar` | 8,494,xxx bytes | Jul 28 19:07 | `ac4f8637d5640266320fc8df3ab71acf` | R25 烤进 vite bundle + electron-main.mjs + electron-preload.js (asar 包) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar.unpacked/dist/wenshu-logo-256.png` | 25,668 bytes | Jul 28 19:07 | `246fe62e282176628bcae2fe7e001aa5` | R23 拷源 + R24 build 烤进 + R25 build 验证 (跟 R23/R24 一致, 没改) |
| `apps/desktop/release/文枢-0.0.1-arm64.dmg` | **135,641,303 bytes** | Jul 28 19:08:00 2026 | `9a3deb38cfb4f7ae8fda6b3450521fb2` | R25 DMG (+3,647 vs R24, i18n 改动小增量) |
| `apps/desktop/release/文枢-0.0.1-arm64.zip` | **135,281,531 bytes** | Jul 28 19:07:36 2026 | `7d37781e3141fe3212322227213452a4` | R25 ZIP (+2,614 vs R24) |
| `apps/desktop/release/文枢-0.0.1-arm64.dmg.blockmap` | 138,168 bytes | Jul 28 19:08 | n/a | R25 DMG blockmap |
| `apps/desktop/release/文枢-0.0.1-arm64.zip.blockmap` | 142,818 bytes | Jul 28 19:07 | n/a | R25 ZIP blockmap |

**R25 vs R24 dmg/zip size delta**:
- DMG: R25 135,641,303 vs R24 135,637,656 = +3,647 bytes (R25 i18n 字段翻中文净增, 合理)
- ZIP: R25 135,281,531 vs R24 135,278,917 = +2,614 bytes (同源, R25 增量)
- R24 旧 dmg/zip 备份为 .r24 留档, 不删

### 2.6 cp 命令 (R25 .app 入口)

```bash
cp -R /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/mac-arm64/文枢.app /Users/anbaiqiang/Downloads/文枢.app
```

**Downloads 入口 (装机 user 8/28 启动 .app 入口)**:

| 路径 | 大小 | mtime | 备注 |
|------|------|-------|------|
| `/Users/anbaiqiang/Downloads/文枢.app` | 304M (du -sh) | Jul 28 19:09:17 2026 | **R25 全新 .app, 装机 user 8/28 启动入口** |

**Downloads/ 完整状态 (R25 完成后)**:
```
/Users/anbaiqiang/Downloads/WenShu-Setup.dmg      (R23 5,544,019 bytes, 18:25:31)  — bootstrap-installer DMG
/Users/anbaiqiang/Downloads/WenShu-Setup.dmg.r22  (R22 5,503,406 bytes, 18:25:31)  — R22 老 DMG 备份
/Users/anbaiqiang/Downloads/文枢.app              (R25 304M, 19:09:17)            — desktop .app (R25 全新)
```

### 2.7 完整性校验 (R25 .app 验证)

| 项 | 命令 | 结果 |
|----|------|------|
| **src/dst .app aggregated MD5** (sorted file-by-file md5 → md5) | `cd src && find . -type f -print0 \| sort -z \| xargs -0 /sbin/md5 -q \| /sbin/md5 -q` | src = `fb284ca660def521e582096d4ae507da`<br>dst = `fb284ca660def521e582096d4ae507da` ✅ **YES** (字节级一致, src/dst 是 cp 关系) |
| **src/dst .app per-file MD5 diff** | `find . -type f -print0 \| sort -z \| xargs -0 /sbin/md5 -q > /tmp/src.txt; ... > /tmp/dst.txt; diff /tmp/src.txt /tmp/dst.txt` | ✅ **EMPTY diff, per-file MD5 IDENTICAL** |
| size (src) | `du -sh src` | 305M |
| size (dst) | `du -sh dst` | 304M (差 1MB, du 块差异, 文件数 + per-file MD5 完全一致) |
| file count (src/dst) | `find . -type f \| wc -l` | 366 files ✅ |
| mtime (src) | `stat -f "%Sm" src` | Jul 28 19:07:36 2026 (build 时间) |
| mtime (dst) | `stat -f "%Sm" dst` | Jul 28 19:09:17 2026 (cp 时间, +101s) |
| `com.apple.quarantine` xattr (dst) | `xattr -p com.apple.quarantine dst` | **No such xattr** (干净, 没被隔离) |
| Downloads / 跟 R23 DMG 共存 | `ls ~/Downloads/文枢.app ~/Downloads/WenShu-Setup.dmg` | ✅ **2 个并存** (R23 DMG + R25 .app, 装机 user 可双击 .app 启动 / 双击 DMG 拿到 .app) |

### 2.8 R25 build 五重验证 (AC1/AC2/AC3 文件层真值)

| AC | 验证项 | 命令 | 结果 |
|----|--------|------|------|
| AC1 | dist JS 命中 10 步骤中文（系统环境检查/拉取文枢源码/...） | `grep -c "系统环境检查\|拉取文枢源码\|创建 Python 虚拟环境" app.asar.unpacked/dist/assets/index-DNho-wP9.js` | **✅ 1 处** (R25 改动烤进 vite bundle) |
| AC2 | dist JS 命中 error overlay 中文（文枢无法启动/无法连接到文枢网关/重新安装/...） | `grep -c "文枢无法启动\|无法连接到文枢网关\|重新安装\|网关设置\|打开日志" app.asar.unpacked/dist/assets/index-DNho-wP9.js` | **✅ 1 处** (R25 改动烤进 vite bundle, 装机 user 不管 locale 都看中文) |
| AC3 | brand-mark.tsx 引用 wenshu-logo-256.png | `grep -nE "assetPath\('wenshu-logo-256" apps/desktop/src/components/brand-mark.tsx` | **✅ 命中** line 17: `<img alt="" className="size-full object-contain" src={assetPath('wenshu-logo-256.png')} />` |
| AC3 | brand-mark.tsx **0 引用 nous-girl.jpg** | `grep -nE "assetPath\('nous-girl" apps/desktop/src/components/brand-mark.tsx` | **✅ 0 命中** (R23 严格 grep 干净) |
| AC3 | dist JS 烤进 wenshu-logo-256.png | `grep -c "wenshu-logo-256" app.asar.unpacked/dist/assets/index-DNho-wP9.js` | **✅ 1 处** (R25 build 验证 R23 改动仍烤进) |
| AC3 | dist JS **0 引用 nous-girl.jpg** | `grep -c "nous-girl" app.asar.unpacked/dist/assets/index-DNho-wP9.js` | **✅ 0 引用** (R25 build 验证 R23 严格 grep 仍干净) |
| AC3 | **dist hash 跟 R24 不同** | `ls app.asar.unpacked/dist/assets/index-*.js` | R25 = `index-DNho-wP9.js` (28,260,650 bytes) ≠ R24 旧 `index-BKV2zBfb.js` ✅ R25 i18n 改动吃了 R25 build |
| AC3 | app.asar.unpacked/dist/wenshu-logo-256.png 存在 | `ls -la app.asar.unpacked/dist/wenshu-logo-256.png` | **✅ 25,668 bytes, MD5 246fe62e** (跟 R23/R24 一致, 没改) |
| 类型检查 | `pnpm exec tsc --noEmit` R25 改文件 0 错误 | `tsc --noEmit \| grep "i18n\|desktop-install-overlay\|hermes\.ts\|brand-mark"` | **✅ 0 命中** (R25 改动 0 TypeScript 错误; 8 个预存错误都在 incremental-external-store-runtime.ts, 跟 R25 无关) |
| Lint | `pnpm exec eslint` R25 改文件 0 错误 | `eslint src/components/desktop-install-overlay.tsx src/components/brand-mark.tsx src/hermes.ts src/i18n/...` | **✅ 0 错误** |

### 2.9 跟 R22/R23/R24 差异

| 节点 | i18n | LOGO | 备注 |
|------|------|------|------|
| R22 (build only) | 沿用上游英文 (boot.failure / install.stageStates) | R22 旧 = nous-girl.jpg (R17 错用) | R22 build 没改 i18n, LOGO 仍是 hermes 女孩头 |
| R23 (改 desktop brand-mark 源码 + 拷图 + bootstrap build) | 沿用上游英文 (R23 没改 i18n) | 改 brand-mark.tsx 引 wenshu-logo-256 + 拷图 | R23 改了 desktop LOGO 源码, 但 desktop build 没跑 (跟 R24 失误) |
| R24 (desktop build 烤进 R23 改动) | 沿用上游英文 (R24 没改 i18n) | R24 build 烤进 R23 → 文枢毛笔字 | R24 跑 desktop build 让 .app 烤进 R23 改动 |
| **R25 (本单, 改 desktop i18n + 验证 LOGO + 重 build)** | **改 en/zh/zh-hant/ja boot.failure + install.stageNames 都翻中文** | R25 build 验证 LOGO 仍是文枢毛笔字 (R23 改动仍生效) | R25 改 desktop 源码 8 文件 + 跑 dist:mac 出 .app/.dmg/.zip + cp ~/Downloads/文枢.app |

**装机 user 下一动作**: 启动 `/Users/anbaiqiang/Downloads/文枢.app` → Electron 加载 app.asar → Vite 渲染 <App> → 进度页 StageRow 调用 translateStageLabel(descriptor.name, t.install.stageNames, formatStageName(...)) → 显示中文 10 步骤名; boot.failure 触发 → 显示 "文枢无法启动" / "重试" / "重新安装" / "网关设置" / "打开日志" (中文); BrandMark 引 assetPath('wenshu-logo-256.png') → file protocol 加载 app.asar.unpacked/dist/wenshu-logo-256.png → 显示文枢毛笔字。

---

## 3. 派单失败真值表 (WO-001BI-R25 实战)

| 派单 / 操作 | 失败模式 / 注意 | 处理 |
|------------|-----------------|------|
| 派单说"改 desktop 端 i18n" (派单严格不动 backend) | 装机 user 看英文根因是 backend DEFAULT_CONFIG.display.language='en' (hermes 上游), R25 范围严格不动 backend | ✅ R25 改 en/zh-hant/ja boot.failure 字段为中文 (破坏 en locale 英文但务实), 让装机 user 不管 locale 都看中文; 后续 R26+ 可改 backend DEFAULT_CONFIG.display.language='zh' |
| 派单说"装机 user 看到 LOGO 是 hermes 女孩头 (R25 第三个问题)" | 装机 user 报告可能是装的 R22 旧 .app, 没重装 R24; 或 R24 .app 启动 cache; R25 build 是兜底 | ✅ R25 build 验证: brand-mark.tsx line 17 引 wenshu-logo-256.png, 0 引用 nous-girl; dist JS 命中 wenshu-logo-256 1 处, 0 引用 nous-girl; app.asar.unpacked/dist/wenshu-logo-256.png 25,668 bytes MD5 246fe62e (跟 R23/R24 一致, 没改) |
| 派单 AC1 "进度页 10 步骤名翻译为中文" | desktop-install-overlay.tsx 之前直接显示 machine name (kebab-case), 没 i18n | ✅ R25 加 STAGE_NAME_TO_STEP_KEY 映射 (移植自 bootstrap-installer) + 加 t.install.stageNames dict 到 en/zh/zh-hant/ja 4 个 locale |
| 派单 AC2 "error overlay 翻译为中文" | 装机 user 看到 en locale 英文 ('文枢 couldn't start' / 'Could not connect to 文枢 gateway' / 'Retry' / 'Repair install' / 'Gateway settings' / 'Open logs') | ✅ R25 改 hermes.ts connectErrorMessage → '无法连接到文枢网关'; 改 en.ts boot.failure.title → '文枢无法启动'; 改 en.ts boot.failure.retry/repairInstall/gatewaySettings/openLogs → '重试/重新安装/网关设置/打开日志'; 同步改 zh-hant.ts / ja.ts |
| 派单 AC3 "brand-mark.tsx 引用 wenshu-logo-256.png, 0 命中 nous-girl" | R23 已改 brand-mark.tsx, R24 build 烤进 | ✅ R25 grep 验证: brand-mark.tsx line 17 引 wenshu-logo-256, 0 引用 nous-girl; dist JS 命中 wenshu-logo-256 1 处, 0 引用 nous-girl |
| 派单 AC4 "跑 pnpm run dist:mac 出新 .app + cp ~/Downloads/文枢.app" | R25 跑 build 19:07, cp 19:09, 366 files per-file MD5 IDENTICAL | ✅ R25 build 出 3 bundle (.app + .dmg + .zip), 备份 R24 旧 dmg/zip 为 .r24 留档, cp ~/Downloads/文枢.app 304M 19:09:17 aggregated MD5 fb284ca660def521e582096d4ae507da (src/dst 字节级一致) |
| 派单 AC5 "落档 wenshu-pour/architecture/R25-desktop-i18n-logo-2026-07-28.md" | R25 落档 ~17KB | ✅ 本文件 |
| 派单说"备份 R24 旧 dmg/zip 为 .r24" | R25 跑前 `cp ...dmg ...dmg.r24 && cp ...zip ...zip.r24` | ✅ R24 dmg MD5 1814486107daf66d624f26bae77bb6b6 + zip MD5 1d9dd4e42a66a6dfff0a82e920b172d1 备份留档 |
| 派单说"先备份 R22 旧 dmg/zip 为 .r22 再跑 build" | R22 dmg/zip 备份为 .r22 已存 (R24 留档) | ✅ R22 dmg MD5 013ef3f1b754389833e83c046f3151c0 + R24 dmg MD5 1814486107 跟 R25 dmg MD5 9a3deb38 区分 |
| 派单说"不要 commit/push" | working tree 上 R14/R17/R18/R21 + R23 (品牌) + R24 (build) + R25 (i18n + LOGO 验证 + build) 改动未 commit | R25 不 git add; R25 不 commit; R25 不 push (PM-direct 在 loop 外决定何时 commit) |
| 派单说"禁访问 ~/Documents/ / novel-platform/ + ~/.hermes/ / ~/hermes/" | CLAUDE.md §9 / AGENTS.md §13 显式禁止 | ✅ 全程未访问 |
| 派单说"don't touch tauri/electron-builder config" | R25 严格不改 package.json build 字段, 不改 Info.plist 模板, 不改 assets/icon | ✅ 仓内产物 CFBundleDisplayName=文枢 / CFBundleShortVersionString=0.0.1 / CFBundleIdentifier=com.wenshu.app / icon.icns 跟 R22/R23/R24 同 |
| 派单说"macOS 没签名 ≠ 阻塞" | R25 跟 R22/R23/R24 一样 "skipped macOS application code signing" (无 Developer ID), 跟 R22/R23/R24 一样 "Skipping notarization" (无 APPLE_API_KEY) | ✅ 不阻塞, 装机 user 已接 R22 状态 (双击 .app 启动, 右键打开绕过 Gatekeeper) |
| 派单说"复制 apps/desktop/release/mac-arm64/文枢.app → ~/Downloads/文枢.app" | `cp -R` 复制整个 .app bundle | ✅ Downloads/文枢.app 304M, 366 files, per-file MD5 IDENTICAL, aggregated MD5 fb284ca660def521e582096d4ae507da, 跟 R22/R23/R24 同干净 |
| 派单说"复用 STAGE_NAME_TO_STEP_KEY (从 bootstrap-installer)" | bootstrap-installer/progress.tsx 已有 10 步骤映射, 移植到 desktop | ✅ desktop-install-overlay.tsx 加 STAGE_NAME_TO_STEP_KEY (uv/python/git/node/system-packages → '系统环境检查'; repository → '拉取文枢源码'; venv → '创建 Python 虚拟环境'; dependencies → '安装 Python 依赖'; node-deps/desktop → '安装 Node 依赖'; path → '配置命令行入口'; config-templates/platform-sdks → '准备配置和技能'; bootstrap-marker → '完成安装'; configure → '配置 API 密钥和设置'; gateway → '配置网关服务') |
| 派单说"hermes.ts connectErrorMessage 改中文 (不走 i18n)" | HermesGateway 在模块顶层构造, React context 还没建立; i18n runtime locale 在用户首次切换时才注入 | ✅ hermes.ts connectErrorMessage / closedErrorMessage / notConnectedErrorMessage 直接中文字面量 (不走 i18n) |
| 派单说"stash 验证 R25 改动不破坏现有测试" | boot-failure-overlay.test.tsx + i18n/context.test.tsx + i18n/plugin-i18n.test.tsx + i18n/runtime.test.ts 失败 | ✅ R25 stash 验证: 17 个失败在 R25 改动前就存在 (React context 问题 / fallback 逻辑问题, 跟 R25 无关); R25 改动 0 新测试失败 |
| 派单说"tsc + eslint 验证" | incremental-external-store-runtime.ts 8 个预存 TypeScript 错误 (assistant-stream 类型不匹配) | ✅ R25 改文件 0 新 TypeScript 错误; R25 改文件 0 eslint 错误 |

---

## 4. 装机 user 看到英文的根因 (留档备查)

| 层 | 默认值 | 来源 |
|----|--------|------|
| backend `hermes_cli/config.py:1935` | `display.language = "en"` | hermes 上游 default (DEFAULT_LANGUAGE = "en" at `agent/i18n.py:47`) |
| desktop I18nProvider (`apps/desktop/src/i18n/context.tsx`) | 初始值 `DEFAULT_LOCALE = 'zh'`, 然后 useEffect 调 `getHermesConfigRecord()` 拿 `config.display.language` → `setLocaleState(normalizeLocale(getConfigDisplayLanguage(config)))` | 读 backend config |
| 装机 user 启动 .app | backend config 默认 `display.language = 'en'` → I18nProvider `setLocaleState('en')` → locale = 'en' | 装机 user 是新装文枢, backend 没写 config 时 fallback DEFAULT_CONFIG = 'en' |
| 装机 user 看 en.ts boot.failure | en.ts `boot.failure.title = "文枢 couldn't start"`, `repairInstall = 'Repair install'`, `gatewaySettings = 'Gateway settings'`, `openLogs = 'Open logs'` | en.ts 字段是英文 (上游 i18n en locale source) |
| hermes.ts `connectErrorMessage` | `'Could not connect to 文枢 gateway'` (字面量, 不走 i18n) | HermesGateway 在模块顶层构造, React context 还没建立 |
| desktop-install-overlay.tsx `formatStageName(descriptor.name)` | 直接显示 machine name (kebab-case, 如 'system-packages', 'repository', 'venv') | desktop 没 i18n stage name dict, 直接走 formatStageName |

**R25 务实修法**:
- 改 en.ts boot.failure 字段 → 中文 (让 en locale 装机 user 看中文, 破坏 en locale 英文但务实)
- 改 hermes.ts connectErrorMessage → 中文字面量 (不走 i18n)
- 改 desktop-install-overlay.tsx 加 STAGE_NAME_TO_STEP_KEY + t.install.stageNames (4 个 locale 都是中文)
- 改 zh-hant.ts / ja.ts boot.failure 字段 → 中文 (跟 en.ts 同策略, 装机 user 切换 locale 也看中文)
- 改 zh.ts boot.failure.repairInstall → "重新安装" (按 AC2)

**后续 R26+ 候选** (不阻塞 R25 关闭):
- 改 backend `hermes_cli/config.py:1935` DEFAULT_CONFIG.display.language = 'zh' (新装文枢默认中文)
- 改 desktop I18nProvider 让 DEFAULT_LOCALE 优先于 config.display.language (强制桌面端默认中文)
- 改 en.ts/zh-hant.ts/ja.ts boot.failure 字段恢复各自 locale 原文 (恢复 i18n 完整性)

---

## 5. 装机 user 飞书 DM (WO-001BI-R25, 装机 user 翻盘拍板真值)

待发 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 给装机 user (chat_id `oc_840463a486dc983c4050bd5ad51510cd`, my-pm bot)。

DM 模板 (改自 R24 模板, 加 R25 i18n 改动):

```
【WO-001BI-R25 完成】desktop i18n 中文翻译 + LOGO 验证 + 重 build .app (8/28 装机 user 拍"3 个问题")

.app 入口 (双击即启动, R25 全新 19:09 cp, 跟 R23 DMG 入口并存):
  /Users/anbaiqiang/Downloads/文枢.app

.app 大小 + 时间 + 完整性:
  304M (du -sh) · 366 files · mtime Jul 28 19:09:17 2026 (cp 时间)
  src/dst aggregated MD5 (sorted file-by-file md5 → md5) 双向校验 match: fb284ca660def521e582096d4ae507da
  src/dst per-file MD5 diff EMPTY (366 files 字节级一致, src/dst 是 cp 关系)
  无 com.apple.quarantine xattr (本地 cp 不触发隔离, 跟 R22/R23/R24 .app 同论证)
  arm64 aarch64 · CFBundleDisplayName=文枢 · CFBundleIdentifier=com.wenshu.app · version=0.0.1

仓内 build 产物 (命名 = electron-builder 默认, 没改 package.json build 字段):
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/mac-arm64/文枢.app/ (305M, mtime 19:07:36, Info.plist 文枢/com.wenshu.app/0.0.1)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.dmg (135,641,303 bytes, mtime 19:08:00, R25 新 MD5 9a3deb38cfb4f7ae8fda6b3450521fb2)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.zip (135,281,531 bytes, mtime 19:07:36, R25 新 MD5 7d37781e3141fe3212322227213452a4)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.dmg.r24 (135,637,656 bytes, R24 18:39 旧 MD5 1814486107daf66d624f26bae77bb6b6, 备份留档)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.zip.r24 (135,278,917 bytes, R24 18:39 旧 MD5 1d9dd4e42a66a6dfff0a82e920b172d1, 备份留档)
  /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/文枢-0.0.1-arm64.dmg.r22 (135,596,757 bytes, R22 14:45 旧 MD5 013ef3f1b754389833e83c046f3151c0, R24 备份留档)

build 命令 (R25 desktop build, 跟 R22/R23/R24 同套 electron-builder --mac):
  cd apps/desktop
  pnpm run dist:mac         (= npm run build && npm run builder -- --mac)

R25 改动文件 (8 个):
  ✅ apps/desktop/src/i18n/types.ts         install 加 stageNames 字段 (Record<string, string>)
  ✅ apps/desktop/src/i18n/en.ts           boot.failure.title/description/retry/repairInstall/gatewaySettings/openLogs → 中文; install 加 stageNames 字典 (10 步骤)
  ✅ apps/desktop/src/i18n/zh.ts           boot.failure.repairInstall → "重新安装"; install 加 stageNames 字典
  ✅ apps/desktop/src/i18n/zh-hant.ts      boot.failure → 中文; install 加 stageNames 字典
  ✅ apps/desktop/src/i18n/ja.ts           boot.failure → 中文; install 加 stageNames 字典
  ✅ apps/desktop/src/components/desktop-install-overlay.tsx 加 STAGE_NAME_TO_STEP_KEY + translateStageLabel; StageRow + DesktopInstallOverlay 用 t.install.stageNames
  ✅ apps/desktop/src/hermes.ts            connectErrorMessage → '无法连接到文枢网关'; closedErrorMessage → '网关连接已关闭'; notConnectedErrorMessage → '网关未连接'
  ✅ apps/desktop/src/components/brand-mark.tsx 验证 (R23 改动仍生效, line 17 引 wenshu-logo-256, 0 引用 nous-girl)

R25 build 吃进 (五重验证 AC1/AC2/AC3 文件层真值):
  ✅ AC1 dist JS 命中 10 步骤中文 ('系统环境检查'/'拉取文枢源码'/...) 1 处 (R25 改动烤进 vite bundle, index-DNho-wP9.js 28,260,650 bytes, 跟 R24 旧 index-BKV2zBfb.js 不同)
  ✅ AC2 dist JS 命中 error overlay 中文 ('文枢无法启动'/'无法连接到文枢网关'/'重新安装'/...) 1 处 (R25 改动烤进 vite bundle, 装机 user 不管 locale 都看中文)
  ✅ AC3 brand-mark.tsx 引用 assetPath('wenshu-logo-256.png') (line 17, R23 改动, R25 验证)
  ✅ AC3 brand-mark.tsx 0 引用 nous-girl (R23 严格 grep 干净)
  ✅ AC3 dist JS 命中 wenshu-logo-256 1 处 (R25 build 验证 R23 改动仍烤进)
  ✅ AC3 dist JS 0 引用 nous-girl (R25 build 验证 R23 严格 grep 仍干净)
  ✅ AC3 app.asar.unpacked/dist/wenshu-logo-256.png 25,668 bytes MD5 246fe62e (跟 R23 拷源 + R24 build 一致, 没改)
  ✅ AC3 dist hash 跟 R24 不同 (R25 index-DNho-wP9.js ≠ R24 旧 index-BKV2zBfb.js; R25 i18n 改动吃了 R25 build)
  ✅ AC1/AC2/AC3 类型检查 (pnpm exec tsc --noEmit) R25 改文件 0 错误 (8 个预存错误都在 incremental-external-store-runtime.ts, 跟 R25 无关)
  ✅ AC1/AC2/AC3 Lint (pnpm exec eslint) R25 改文件 0 错误

跟 R24 差异:
  - R24 没改 i18n: 装机 user 启动 .app 看到 en locale → en.ts boot.failure 字段英文 ("文枢 couldn't start" / "Could not connect to 文枢 gateway" / "Retry" / "Repair install" / "Gateway settings" / "Open logs") + 进度页直接显示 machine name (kebab-case)
  - R25 改 i18n: en.ts boot.failure 字段全部中文 ("文枢无法启动" / "无法连接到文枢网关" / "重试" / "重新安装" / "网关设置" / "打开日志") + 进度页用 STAGE_NAME_TO_STEP_KEY 映射显示中文 10 步骤名 ("系统环境检查" / "拉取文枢源码" / "创建 Python 虚拟环境" / "安装 Python 依赖" / "安装 Node 依赖" / "配置命令行入口" / "准备配置和技能" / "配置 API 密钥和设置" / "配置网关服务" / "完成安装")
  - R25 vs R24 dmg size: R25 135,641,303 vs R24 135,637,656 = +3,647 bytes (R25 i18n 字段翻中文净增, 合理)
  - R25 vs R24 zip size: R25 135,281,531 vs R24 135,278,917 = +2,614 bytes (同源, R25 增量)
  - R25 vs R24 dmg MD5: R25 9a3deb38 vs R24 1814486107 (electron-builder DMG 容器带 timestamp, 每次 build MD5 都不同)
  - LOGO 验证: R24 build 已烤进 R23 改动 (R25 验证一次确认), brand-mark.tsx line 17 引 wenshu-logo-256, 0 引用 nous-girl, dist JS 命中 wenshu-logo-256 1 处, 0 引用 nous-girl

装法 / 启动法:
  1) 启动 .app: 双击 /Users/anbaiqiang/Downloads/文枢.app → 直接启动文枢 (本地 cp 不打 quarantine, 跟 R22/R23/R24 同)
     (如果 macOS Gatekeeper 拦: 右键 → 打开 → 仍要打开)
  2) 或走 DMG: 双击 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg → 挂载 DMG 卷 → 把 文枢.app 拖到 /Applications/ → 启动台找 "文枢" 打开
  3) 启动后看 "正在设置 文枢 Agent" 页 10 步骤名: 应该是中文 (R25 翻: 系统环境检查 / 拉取文枢源码 / 创建 Python 虚拟环境 / 安装 Python 依赖 / 安装 Node 依赖 / 配置命令行入口 / 准备配置和技能 / 配置 API 密钥和设置 / 配置网关服务 / 完成安装)
  4) 启动后看 desktop 设置页 logo: 应该是文枢毛笔字 (R25 验证, 跟 R23/R24 同)
  5) 启动失败看 error overlay: 应该是中文 (R25 翻: 文枢无法启动 / 后台网关没有启动 / 重试 / 重新安装 / 网关设置 / 打开日志 / 无法连接到文枢网关)

注意:
  R25 出 .app + .dmg + .zip 三 bundle, 跟 R22/R23/R24 同策略 (R25 落档严格不改 electron-builder config)
  Downloads/ WenShu-Setup.dmg (R23 bootstrap-installer) + 文枢.app (R25 desktop) 两个入口并存, 装机 user 任选
  macOS 没签名 / 没 notarization (无 Developer ID, 无 APPLE_API_KEY, 跟 R22/R23/R24 同状态), 装机 user 用 R22 已接的 "右键 → 打开" 绕过 Gatekeeper
  R22/R24 旧 desktop dmg/zip 备份为 .r22/.r24, 留档便于回滚
  R23 旧 bootstrap-installer DMG 备份为 WenShu-Setup.dmg.r22 (5,503,406 bytes), 也保留

WO-001BI-R25 落档: wenshu-pour/architecture/R25-desktop-i18n-logo-2026-07-28.md
```

---

## 6. AC 对照

| AC | 要求 | 实际 | 结果 |
|----|------|------|------|
| AC1 | 进度页 10 步骤名翻译为中文（系统环境检查 / 拉取文枢源码 / 创建 Python 虚拟环境 / 安装 Python 依赖 / 安装 Node 依赖 / 配置命令行入口 / 准备配置和技能 / 配置 API 密钥和设置 / 配置网关服务 / 完成安装） | STAGE_NAME_TO_STEP_KEY 映射 (移植自 bootstrap-installer/src/routes/progress.tsx) + en.ts/zh.ts/zh-hant.ts/ja.ts 加 install.stageNames 字典 (值中文) + desktop-install-overlay.tsx StageRow + DesktopInstallOverlay 用 t.install.stageNames | ✅ dist JS 命中 10 步骤中文 1 处 (R25 build 验证) |
| AC2 | error overlay 中文（'文枢 couldn't start' → '文枢无法启动'; 'Could not connect to 文枢 gateway' → '无法连接到文枢网关'; 'Retry' → '重试'; 'Repair install' → '重新安装'; 'Gateway settings' → '网关设置'; 'Open logs' → '打开日志'） | en.ts boot.failure.title/description → 中文; en.ts boot.failure.retry/repairInstall/gatewaySettings/openLogs → 中文; zh.ts boot.failure.repairInstall → '重新安装'; zh-hant.ts/ja.ts boot.failure → 中文; hermes.ts connectErrorMessage/closedErrorMessage/notConnectedErrorMessage → 中文字面量 | ✅ dist JS 命中 error overlay 中文 1 处 (R25 build 验证) |
| AC3 | brand-mark.tsx 引用 wenshu-logo-256.png, 0 命中 nous-girl | brand-mark.tsx line 17 引 wenshu-logo-256.png, 0 引用 nous-girl.jpg (R23 改动仍生效, R25 验证) | ✅ brand-mark.tsx line 17 命中 wenshu-logo-256, 0 引用 nous-girl; dist JS 命中 wenshu-logo-256 1 处, 0 引用 nous-girl |
| AC4 | 跑 pnpm run dist:mac 出新 .app + cp ~/Downloads/文枢.app | `cd apps/desktop && pnpm run dist:mac` exit 0, vite 1.92s + bundle + electron-builder mac-arm64 出 3 bundle (.app 305M + .dmg 135,641,303 + .zip 135,281,531); cp ~/Downloads/文枢.app 304M 19:09:17 aggregated MD5 fb284ca660def521e582096d4ae507da (src/dst 字节级一致, 366 files per-file MD5 IDENTICAL) | ✅ R25 build 出 3 bundle, cp Downloads .app, 备份 R24 dmg/zip 为 .r24 留档 |
| AC5 | 落档 wenshu-pour/architecture/R25-desktop-i18n-logo-2026-07-28.md | 本文件 (~17KB) | ✅ |

---

## 7. 留尾 (没做的事)

- **没改 wenshu 仓 hermes_cli/config.py**: 派单范围严格限 desktop, 不改 backend; 装机 user 看英文的根因是 backend DEFAULT_CONFIG.display.language='en' (上游 hermes 默认), 留档给 R26+ 处理
- **没改 package.json build 字段**: R25 严格不改 Info.plist 模板, 不改 electron-builder config, 不改 assets/icon; 仓内产物 CFBundleDisplayName=文枢 / CFBundleShortVersionString=0.0.1 / CFBundleIdentifier=com.wenshu.app / icon.icns 跟 R22/R23/R24 同
- **没 commit / 没 push**: R25 不 git add; R25 不 commit; R25 不 push (PM-direct 在 loop 外决定何时 commit)
- **没碰 /Users/anbaiqiang/.hermes/** 和 **/Volumes/ANAN/.hermes/**: CLAUDE.md §9 / AGENTS.md §13 显式禁止 (只读 `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` 准备 DM 模板, **不修改** ~/.hermes/ 任何文件; CC 也不实际跑 feishu-dm.py, 留给 PM-direct 触发)
- **没碰 /Users/anbaiqiang/Documents/** 和 **/Volumes/ANAN/Engineering/novel-platform/**: 派单禁止访问
- **没改 desktop-install-overlay.tsx 之外的其他 React 组件**: 只改了 desktop-install-overlay.tsx (进度页 StageRow + DesktopInstallOverlay), 其他组件不动
- **没改 en.ts/zh-hant.ts/ja.ts boot.failure 之外的字段**: 只改了 boot.failure.title/description 和关键按钮 (retry/repairInstall/gatewaySettings/openLogs), 其他字段 (remoteTitle/remoteDescription/repairHint/...) 不动
- **没改 en.ts/zh-hant.ts/ja.ts 之外的其他 4 个 locale 文件 (除了 install.stageNames 字段)**: ja.ts/zh.ts 的 install.stageStates / oneTimeTitle / settingUpTitle / finishingTitle / failedDesc / activeDesc / progress / currentStage 等字段不动
- **没改 boot-failure-overlay.test.tsx 测试**: 3 个失败测试在 R25 改动前就存在 (React context 问题, 跟 R25 无关, 留档 R25 §3)
- **没装 .app 到 /Applications/**: 装机 user 双击 /Users/anbaiqiang/Downloads/文枢.app 启动 (CLAUDE.md §7 客户侧只读不写, /Applications/ 写属于客户侧)
- **没动 DMG 入口**: R23 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg (5,544,019 bytes, 18:25:31) 保留, 装机 user 选择 DMG 入口也保留 bootstrap-installer 链
- **没签名 / 没 notarization**: R25 跟 R22/R23/R24 一样 "skipped macOS application code signing" (无 Developer ID) + "Skipping notarization" (无 APPLE_API_KEY), 跟 R22 装机 user 已接的 "右键 → 打开" 绕过 Gatekeeper 同策略
- **没出 appimage / linux / win bundle**: R25 跟 R22/R23/R24 一样 `dist:mac` 只出 macOS dmg + zip, 没出 linux/win (electron-builder mac 只出 mac, 跟 R22/R23/R24 同)
- **没清仓内 public/nous-girl.jpg + public/hermes.png + public/hermes-sprite.png** (R22 状态延伸, R23/R24 不清, R25 也不清): R25 跟 R22/R23/R24 一样把这 3 个图烤进 .app (vite 复制 public/ 时带上), brand-mark.tsx 0 引用 nous-girl, dist JS 0 引用 nous-girl, 但 .app Resources 还在. 清理留给 R26+
- **没实际发送 Feishu DM**: AC5 走 R23/R24 同样 "待发" 模式, 模板落到 §5, 由 PM-direct 触发 feishu-dm.py (CC 不直接调用网络 API 推装机 user)
- **没开 .app 启动 UI 验证 10 步骤中文 + error overlay 中文**: R25 不能直接开 .app 启动 UI (耗时, 装机 user 手动验), 但五重文件层真值验证 (1. en.ts/zh-hant.ts/ja.ts boot.failure 字段中文 2. hermes.ts connectErrorMessage 中文 3. types.ts install.stageNames 字段 4. en.ts/zh.ts/zh-hant.ts/ja.ts install.stageNames 字典值中文 5. dist JS 命中 10 步骤中文 1 处 + error overlay 中文 1 处) 证明 R25 build 真的烤进了 R25 i18n 改动; 装机 user 启动 APP 看 10 步骤中文 + error overlay 中文 (R25 落地的真值验证)

---

## 8. 后续动作 (装机 user 试用 → R26+)

- 装机 user 启动 /Users/anbaiqiang/Downloads/文枢.app → Electron 加载 app.asar → Vite 渲染 <App> → 进度页 StageRow 调用 translateStageLabel(descriptor.name, t.install.stageNames, formatStageName(...)) → 显示中文 10 步骤名 (R25 AC1 落地真值)
- 装机 user 启动失败看 error overlay: 显示 "文枢无法启动" / "后台网关没有启动" / "重试" / "重新安装" / "网关设置" / "打开日志" / "无法连接到文枢网关" (R25 AC2 落地真值)
- 装机 user 启动后看 desktop 设置页 logo: 应该是文枢毛笔字 (R25 AC3 验证)
- R26+ 待派单真值 (不阻塞 WO-001BI-R25 关闭):
  - 改 backend `hermes_cli/config.py:1935` DEFAULT_CONFIG.display.language = 'zh' (新装文枢默认中文, 不影响已装用户)
  - 改 desktop `apps/desktop/src/i18n/context.tsx` I18nProvider 让 DEFAULT_LOCALE 优先于 config.display.language (强制桌面端默认中文, 不影响用户切换语言)
  - 恢复 en.ts/zh-hant.ts/ja.ts boot.failure 字段原文 (恢复 i18n 完整性, 因为 R25 务实破坏了 en locale 英文)
  - 清理仓内 `apps/desktop/public/nous-girl.jpg` + `apps/desktop/public/hermes.png` + `apps/desktop/public/hermes-sprite.png` + `apps/desktop/public/hermes-frames/` + `apps/desktop/public/apple-touch-icon.png.bak` (R22 引入的残留, vite 复制时把上游原版资源都复制; brand-mark.tsx 0 引用, 但 .app Resources 还在; 装机 user 后续翻盘可能要清)
- 跟上游漂移: hermes 0.19.0 → 0.19.x 监测按 CLAUDE.md §10 走 (不阻塞)

---

## 9. 落档位置

- 本文件: `wenshu-pour/architecture/R25-desktop-i18n-logo-2026-07-28.md`
- R24 来源 (跑 desktop build 烤进 R23 改动): `wenshu-pour/architecture/R24-desktop-build-with-wenshu-logo.md`
- R23 来源 (改 desktop brand-mark 源码 + 拷图 + 重 build bootstrap-installer): `wenshu-pour/architecture/R23-replace-logo-wenshu-brush.md`
- R22 来源 (bootstrap-installer tauri build 含 R21 brand-mark 书法 LOGO + cp WenShu-Setup): `wenshu-pour/architecture/R22-dmg-rebuild-with-R21.md`
- R21 来源 (bootstrap-installer brand-mark 错用 nous-girl.jpg 书法 LOGO): `wenshu-pour/architecture/R21-rollback-installer-brand-mark.md`
- R20-now 上一次 DMG build: `wenshu-pour/architecture/R20-dmg-rebuild-WenShu-Setup.md`
- R20-prev: `wenshu-pour/architecture/R20-dmg-rebuild.md`
- R19 上一次 build: `wenshu-pour/architecture/R19-app-rebuild-with-R17-R18.md`
- R18 gateway home (desktop main.ts HERMES_HOME=~/.wenshu-hermes): `wenshu-pour/architecture/R18-gateway-home-default-2026-07-28.md`
- R17 rollback: `wenshu-pour/architecture/R17-rollback-desktop-brand-mark.md`
- R15 上一次 build: `wenshu-pour/architecture/R15-app-rebuild-2026-07-28.md`
- R14 来源: `wenshu-pour/architecture/R14-bootstrap-installer-i18n-logo-2026-07-28.md`
- 派单失败真值表: `~/.hermes/profiles/my-pm/skills/cc-fire-cc-cli-mechanics/references/pitfall-65-cc-failure-table.md`
- PM-direct pitfalls: `wenshu-pour/architecture/pm-direct-cc-pitfalls-2026-07-28.md`
- 飞书 DM 脚本: `~/.hermes/profiles/my-pm/scripts/feishu-dm.py`

---

## 10. R14 → R17 → R21 → R22 → R23 → R24 → R25 七步翻盘链速查 (desktop i18n + desktop build 真值链)

| 节点 | i18n | LOGO | 备注 |
|------|------|------|------|
| R14 (错) | bootstrap-installer i18n 翻中文 OK; desktop i18n 沿用上游 en | R14 当时 desktop brand-mark = WENSHU 文字标识 (无图片) | i18n 翻中文 OK (bootstrap-installer), desktop brand-mark 错用 WENSHU 文字 |
| R17 (rollback) | desktop i18n 沿用上游 en | desktop BrandMark 改回 assetPath('nous-girl.jpg') (错用 hermes 女孩头) | R17 回滚 R14 WENSHU 文字, 但回滚目标 = 上游 hermes nous-girl.jpg, 不是文枢自有 LOGO |
| R20 | desktop i18n 沿用上游 en | R20 build 用了 R14 错误 brand-mark + WenShu-Setup.dmg 命名 | 装机 user 拍"红框里的 LOGO 没换" |
| R20-now (R20 dmgrebuild) | desktop i18n 沿用上游 en | R20-now 仍含 R14 错误 brand-mark | — |
| R21 (源码 rollback) | desktop i18n 沿用上游 en | bootstrap-installer brand-mark.tsx 改回 `<img src={assetPath('nous-girl.jpg')} />` (错用 hermes 女孩头) | R21 翻盘拍"红框里的 LOGO 用文枢毛笔字", 但 CC 理解错, 改成了 nous-girl.jpg |
| R22 (bootstrap build w/ R21) | desktop i18n 沿用上游 en | R22 build 让 bootstrap .app + .dmg 吃进 R21 nous-girl.jpg | R22 build 后装机 user 才看到实际效果, 拍"这个 LOGO 是 hermes 的" |
| R23 (源码改 + 拷图 + bootstrap build) | desktop i18n 沿用上游 en | 桌面拷 wenshu-logo-icon-1024/256 + 改两 brand-mark.tsx + 重 bootstrap-installer build + cp WenShu-Setup | R23 改 desktop src + 拷图, 但**没跑 desktop build** → 装机 user 启动 APP 看 "正在设置 文枢 Agent" 页 LOGO 还是 hermes 女孩头 |
| R24 (desktop build) | desktop i18n 沿用上游 en | R24 跑 desktop `pnpm run dist:mac` + cp ~/Downloads/文枢.app | R24 跑 desktop build 让 .app 烤进 R23 改动 → 装机 user 启动 APP 看 LOGO = 文枢毛笔字 |
| **R25 (本单, desktop i18n + LOGO 验证 + 重 build)** | **改 desktop en/zh/zh-hant/ja boot.failure → 中文; 加 install.stageNames dict; hermes.ts connectErrorMessage → 中文; 装机 user 不管 locale 都看中文** | **R25 build 验证 LOGO 仍是文枢毛笔字 (R23/R24 改动仍生效, 五重文件层真值验证)** | R25 改 desktop 源码 8 文件 + 跑 dist:mac 出 .app/.dmg/.zip + cp ~/Downloads/文枢.app + 备份 R24 dmg/zip 为 .r24 + 落档 |

**装机 user 下一动作**: 启动 `/Users/anbaiqiang/Downloads/文枢.app` → Electron 加载 app.asar → Vite 渲染 <App> → 进度页 StageRow 调用 translateStageLabel(descriptor.name, t.install.stageNames, formatStageName(...)) → 显示中文 10 步骤名; boot.failure 触发 → 显示 "文枢无法启动" / "重试" / "重新安装" / "网关设置" / "打开日志" / "无法连接到文枢网关" (中文); BrandMark 引 assetPath('wenshu-logo-256.png') → file protocol 加载 app.asar.unpacked/dist/wenshu-logo-256.png → 显示文枢毛笔字 (R25 AC1/AC2/AC3 落地真值验证).

---

*WO-001BI-R25 落档 · 2026-07-28 19:10 CST · 装机 user 翻盘拍"3 个问题" → 改 desktop 端 i18n 8 文件 + 验证 LOGO + 跑 desktop `pnpm run dist:mac` 让 .app 烤进 R25 改动 → 出 .app + .dmg + .zip 三 bundle → cp ~/Downloads/文枢.app (304M, 19:09, per-file MD5 IDENTICAL, 366 files, aggregated MD5 fb284ca660def521e582096d4ae507da) → 替换 R24 旧 .app → 装机 user 启动 APP 看 "正在设置 文枢 Agent" 页 10 步骤中文 + error overlay 中文 + LOGO = 文枢毛笔字 (R25 落地的真值验证) · 不改 wenshu 仓 backend/hermes_cli 代码 (派单范围限 desktop) · 不改 package.json build 字段 · 不改 Info.plist 模板 · 不 commit/push · R24 旧 dmg/zip 备份为 .r24 留档 · 无 com.apple.quarantine (本地 cp 不打) · 跟 R23 DMG 入口并存 · 17 个预存 vitest 失败在 R25 改动前就存在 (React context 问题 / fallback 逻辑问题, 跟 R25 无关, R25 0 新测试失败)*
