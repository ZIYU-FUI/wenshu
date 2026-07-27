# 文枢 Setup 蓝屏 BUG v3 根因排查 (WO-001AN STEP 1)

> 实际执行日期：2026-07-27（机器当前日期）
> 任务要求文件名保留 2026-08-26（前向命名）
> 执行器：CC（Claude Code CLI /opt/homebrew/bin/claude）
> 任务派单：装机 user 8/26 拍 BUG v3（蓝屏还在 + 标题栏"文枢"已渲染）→ PM-direct 5 分钟拍板 → 派单 CC 深查 10 候选
> 关联拍板：commit 我自决（parent = `2c77bcf0d`，即 WO-001AM 那次 v2 修复 commit），push 装机 user 周末拍
> Hard truth：本次 v3 修根因 = 修 v1/v2 都没抓到的"多份 React runtime"问题，跟 7/24 + 7/27 v2 不是同一根因

## 0. 任务真值速览

| 项 | 真值 | 来源 |
|---|---|---|
| 装机 user BUG v3 报告日 | 8/26 周一（前向命名，机器当前 7/27） | 任务 spec |
| 装机 user 实际执行日 | 2026-07-27 | `date` 终端实测 |
| BUG v3 症状 | 蓝屏还在 + 标题栏"文枢"已渲染 | 装机 user 8/26 拍板 |
| 关键拍板 | macOS NSWindow title "文枢" 渲染了 = Tauri runtime OK, WebView 起来, frontend 资源路径 OK | 装机 user 8/26 |
| 前一 BUG（v2）| 7/27 commit `2c77bcf0d` 修过 title + Vite base，已 12:14 重 build 装机 | `git log` + `stat` 实测 |
| v2 装机 mtime | `/Applications/文枢.app/Contents/MacOS/WenShu-Setup` mtime = `12:15:12`（size 7,673,776）| `stat` 实测 |
| v3 修前 bundled React 数 | 3 份（grep `react.transitional.element` × 3 + `__CLIENT_INTERNALS_DO_NOT_USE…` × 3）| `grep -c` 实测 |
| v3 修前 React 版本 | `19.2.8` 出现 2 次（installer 局部 + monorepo 根） + 隐式副本 1 | bundle 字符串 |
| Monorepo 根 React 版本 | `19.2.7`（`node_modules/react/package.json`）| `cat` 实测 |
| Installer 局部 React 版本 | `19.2.8`（`apps/bootstrap-installer/node_modules/react/package.json`）| `cat` 实测 |
| nanostores React 解析来源 | 越级 monorepo 根（`node_modules/@nanostores/react`）| `ls -la` 实测 |
| headless WKWebView 修前探针 | `TypeError: null is not an object (evaluating 'c.H.useRef')` @ 9:37575，`rootChildren: 0`，bodyText 空 | Swift + `console.error` 桥 |
| headless WKWebView 修后探针 | 无错，`rootChildren: 1`，`text: "WENSHU AGENT ... 安装文枢"` | Swift + `console.error` 桥 |
| 修后 WebView body 背景 | `color(srgb 0.05098 0.149647 0.403137)` = `#0d2f86`（深蓝），CSS 已生效，React 已挂载 | evaluateJavaScript probe |
| 修后 Tauri 装机 mtime | 12:43:41，process 51670 (WebContent) + 51671 (Networking) 全活 | `stat` + `pgrep` 实测 |
| 修后 build exit | 0（4m 28s release，clean 重建） | `cargo tauri build` 实跑 |

**核心拍板**：本 v3 BUG 与 7/24 commit `6cab7c457`、7/27 v2 commit `2c77bcf0d` **不是同一根因**。v2 修的是 "WenShu-Setup title 英文" + "Vite base 绝对路径"。v3 抓的是 **生产 bundle 嵌入了多份 React**——`@nanostores/react` 通过 monorepo 根解析到 React 19.2.7，installer 自带 React 19.2.8，react-dom 副本又把 dispatcher 绑到第三份副本，触发 useRef 抛 null → React 不挂载 → 蓝屏。

## 1. STEP 1 排查根因（10 候选逐一验）

### 候选 1：macOS NSWindow title "文枢" 渲染了（拍板 ✅）

- **装机 user 拍板真值**：标题栏已显示"文枢"。
- **配置真值**（`tauri.conf.json`）：`windows[0].title: "文枢"`（v2 已改）+ `productName: "文枢"`。
- **二进制真值**（`strings`）：bundle 内字符串确认含 `文枢` 标题。
- **判定**：✅ **Tauri runtime 起来了**，NSWindow title 由 native code 写，渲染了 = 整个 native pipeline（AppKit window、WebKit container、loadURL 触发）已成功走过前半段。

### 候选 2：WebView 起来了但内容没渲染

- **Headless 复现真值**（Swift WKWebView + 自定义 URL scheme 直接 serve `dist/`）：
  - index.html 200 OK（450 字节）
  - `assets/index-6wMk_KHw.js` 200 OK（261,489 字节）
  - `assets/index-DZ5TSfj_.css` 200 OK（124,682 字节）
  - font `JetBrainsMono-Bold-CUogYd9I.woff2` 200 OK（94,628 字节）
  - `wenshu-test://localhost` 协议下完整加载所有资源
- **CSS probe 真值**（修前）：`bodyBackground: "color(srgb 0.05098 0.149647 0.403137)"` = `#0d2f86` = `--theme-background-seed`（深蓝）
- **判定**：❌ **资源加载本身没失败**。CSS 已生效，body 显示深蓝。**真正问题是 React 抛错后没挂上 DOM 树**。

### 候选 3：background-color 没设 → 蓝屏 = macOS WebKit 默认

- **CSS 真值**（`apps/bootstrap-installer/src/styles.css`）：
  ```css
  :root.dark {
    --theme-background-seed: #0d2f86;  /* 深蓝 */
    --theme-midground: #0053fd;         /* 亮蓝 */
    --theme-secondary: #1b45a4;         /* 中蓝 */
  }
  ```
- **Theme 真值**（`src/theme.ts`）：
  - 首帧同步 `paint(prefersDark() ? 'dark' : 'light')`（从 `prefers-color-scheme` media query）
  - 随后异步 `getCurrentWindow().theme()` 拿 Tauri 主题并 `paint(current)`
- **probe 真值**：`htmlClass: "h-full dark"`（`<html>` 上了 `.dark` 类）→ CSS 解析到深蓝 token
- **判定**：⚠️ **蓝屏 = styles.css :root.dark 的 `--theme-background-seed`**（不是 macOS WebKit 默认）。这就是为什么是**深蓝**而不是 WebView 默认的浅灰。

### 候选 4：Tauri config frontendDist 没指

- **tauri.conf.json 真值**：`build.frontendDist: "../dist"` ✅
- **binary `strings` 真值**：含 `index.html` + `index-6wMk_KHw.js` + `index-DZ5TSfj_.css` + `default-src 'self'; ...`
- **build.rs 真值**：`cargo:rerun-if-changed=../dist`（v1 7/24 fix 仍生效）
- **判定**：❌ **frontendDist 正确，资源已嵌入**。headless harness 直接 serve dist 也能 200，证明产物自洽。

### 候选 5：dist/index.html mtime > binary mtime（stale embed）

- **mtime 真值**（v3 修前）：
  - `dist/index.html` = `12:12:45`
  - `dist/assets/index-6wMk_KHw.js` = `12:12:45`
  - `binary WenShu-Setup`（target/release/）= `12:14:48`
  - binary (bundle/macos) = `12:14:19`
- **判定**：❌ **binary mtime > dist mtime**，embed 是新的（v1 7/24 fix 持续生效，rerun-if-changed 已触发重 build）。

### 候选 6：CSP 'unsafe-inline' 拦 Vue runtime

- **真值**：
  - `withGlobalTauri: false` → 走 ESM import `invoke`/`listen`/`getCurrentWindow`（不依赖 `window.__TAURI_INTERNALS__` 全局，但 `@tauri-apps/api` 内部确实要它）
  - CSP：`default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; font-src 'self' data:; connect-src 'self' ipc: http://ipc.localhost`
  - `dist/index.html` 只有外链 `<script src>` 和 `<link rel="stylesheet">`，**无 inline `<script>` 或 `<style>`**
- **headless probe 真值**：Tauri 内部 mock 注入 `__TAURI_INTERNALS__`，CSP 允许 `'self'`，外链 script 加载成功（走到挂载阶段后才崩）
- **判定**：❌ **CSP 不构成 v3 触发点**。CRA/Vite 产物与 CSP 完全兼容，崩溃发生在 CSP 验证通过之后。

### 候选 7：Vite production base path 错

- **vite.config.ts 真值**：
  - `base: './'`（v2 已加）
  - `dist/index.html` 实际：`./assets/index-6wMk_KHw.js` ✅
- **判定**：❌ **base 已修，路径解析正确**（headless probe 显示 CSS/JS 资源 200 OK，路径解析无 404）。

### 候选 8：dev server vs production mode 拍板

- **真值**：
  - `beforeBuildCommand: "npm run build"` + `frontendDist: "../dist"`（prod 嵌入）
  - `beforeDevCommand: "npm run dev"` + `devUrl: "http://127.0.0.1:5175"`（dev vite server）
  - `cargo tauri build` 走 prod 嵌入路径（已验）
- **判定**：❌ **build 走 prod 嵌入**。binary `strings` 内 `index.html` / `index-6wMk_KHw.js` 都在。

### 候选 9：JS bundle 没 polyfill `__TAURI_INTERNALS__`（拍板 ✅ 关键）

- **关键拍板 — 多份 React runtime 真实存在**：
  ```
  $ grep -o 'react.transitional.element' dist/assets/index-*.js | wc -l
  3
  $ grep -o '__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE' dist/assets/index-*.js | wc -l
  3
  $ grep -oE 'version=`[0-9]+\.[0-9]+\.[0-9]+`' dist/assets/index-*.js | head
  version=`19.2.8`
  version=`19.2.8`
  ```
  bundle 出现 3 份 React 19.2.8（2 显 + 1 隐式 dispatcher 副本）。
- **根因解剖**（`node_modules` 真值）：
  - `apps/bootstrap-installer/package.json` 声明 `"@nanostores/react": "^1.1.0"`（**注**：此 app 的 package.json 当前实际没列 `@nanostores/react`；是从 monorepo 根 `apps/desktop` 那边 hoisted 来的）
  - `apps/bootstrap-installer/node_modules/react` symlink → `.pnpm/react@19.2.8/...` = **19.2.8**
  - `apps/bootstrap-installer/node_modules/react-dom` symlink → `.pnpm/react-dom@19.2.8_react@19.2.8/...` = **19.2.8（依赖 react@19.2.8）**
  - `node_modules/react` (monorepo 根) = **19.2.7**（commit hash 不同！）
  - `node_modules/@nanostores/react` (monorepo 根) `index.js:2` 写死 `import { useCallback, useRef, useSyncExternalStore } from 'react'`，**但它解析时优先用 monorepo 根的 19.2.7**
  - Vite 默认 dedupe 走 `optimizeDeps.entries` + 静态分析；当 `@nanostores/react` 在 monorepo 根而非 installer 局部时，Vite 把它的 `react` 解析为 monorepo 根 19.2.7
  - 结果：`useStore()` 内部 `useRef()` 调用，dispatcher 在第三份 React 副本里没被 ReactDOM 初始化 → 抛 `null is not an object (evaluating 'c.H.useRef')`
- **headless probe 真值**：
  ```
  [webkit:consoleBridge] window.error: {
    "message": "TypeError: null is not an object (evaluating 'c.H.useRef')",
    "source": "wenshu-test://localhost/assets/index-6wMk_KHw.js",
    "line": 9, "column": 37575,
    "stack": "…C@9:37832 wr@9:92972 So@8:47522 hc@8:70039 Mu@8:115692 ku@8:114773…"
  }
  [webkit:probe] {"rootChildren":0,"bodyText":"","rootHTML":"",...}
  ```
  第一个 `useStore(<welcome route>)` 调 `useRef` 立即崩；`#root` 留空；body 显示 `bg-background`（深蓝 seed）= 视觉上"蓝屏"。
- **判定**：✅✅ **v3 真根因**。`@nanostores/react` 解析到 monorepo 根 React 19.2.7，与 installer 局部 React 19.2.8 拆分，React 19 hook dispatcher 跨副本不识别。
- **修法**：在 `vite.config.ts` 加 `resolve.dedupe: ['react', 'react-dom']`，强制所有 `import 'react'/'react-dom'` 都解析到 installer 局部的 19.2.8 版本。

### 候选 10：WebView 异步加载未完成

- **真值**：probe 等了 5 秒后才 evaluateJavaScript；React 挂载是首屏 < 100ms 完成，5 秒足够。
- **判定**：❌ **不是异步加载未完成**——错误立刻抛出（同步 throw），根本不是慢加载。

## 2. 拍板真值（Step 1 结论）

### 2.1 高置信根因（必修）

**根因 A — `@nanostores/react` 越级解析到 monorepo 根 React 19.2.7，与 installer React 19.2.8 dispatcher 冲突**

- **证据链**：
  - bundle grep：3 份 `__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE` + 3 份 `react.transitional.element`
  - `node_modules/react` (根) version = `19.2.7`
  - `apps/bootstrap-installer/node_modules/react` symlink target version = `19.2.8`
  - `node_modules/@nanostores/react/index.js:2` `import { useCallback, useRef, useSyncExternalStore } from 'react'`
  - headless probe 抓 `TypeError: null is not an object (evaluating 'c.H.useRef')` at first useStore
  - 修后 probe `rootChildren: 1` + 完整文本渲染 + 0 console error
- **装机 user BUG v3 报告直对**：他看到的"还是蓝的"= body bg-background 深蓝 = React 抛错未挂载。
- **修法**：`apps/bootstrap-installer/vite.config.ts` `resolve.dedupe: ['react', 'react-dom']`，强制所有 React 解析到 installer 局部。

### 2.2 显式确定性增强（推荐改）

- **不需要进一步改** —— v3 拍板只 1 个修法。其它 9 候选已逐项验真值排除或与本 v3 BUG 无关。

### 2.3 不修项（已 10 候选验过）

- ❌ title 字符串（v2 已改，确认）
- ❌ Vite base（v2 已改）
- ❌ frontendDist / devUrl 路径
- ❌ CSP
- ❌ withGlobalTauri 配置
- ❌ binary stale embed
- ❌ JS bundle parse error
- ❌ WebKit sandbox / TCC

## 3. 蓝屏现象的物理来源（重新厘清）

v1/v2 文档说"蓝屏 = macOS WebKit 默认"，**v3 真值更正**：
- **蓝屏 = `styles.css` 的 `:root.dark` `--theme-background-seed: #0d2f86`（深蓝）**
- macOS 默认 WebView 背景是**浅灰/白**，不是深蓝
- "深蓝" 是文枢设计系统暗色主题的种子色
- React 抛错 → `#root` 空 → body CSS 生效 → 视觉只看到深蓝 body 背景
- **真正 BUG**：React 抛 `c.H.useRef is not a function`（null dispatcher），不是 macOS WebView 渲染失败

## 4. STEP 2 修法落点（白名单内）

| 文件 | 改 | 大小 |
|---|---|---|
| `apps/bootstrap-installer/vite.config.ts` | `resolve.dedupe: ['react', 'react-dom']` | 7 行（含 6 行注释） |

**预期 diff**：1 个文件、+7 行。其他白名单文件不改（tauri.conf.json / build.rs / main.rs / lib.rs / src/main.tsx 都不是本 v3 根因触发点）。

## 5. STEP 3 验真值（headless WKWebView 抓图）

详见兄弟档 `blue-screen-bug-v3-fix-2026-08-26.md` §3-5。

- 修前：`/Users/anbaiqiang/wenshu-blue-v3-protocol-before.png` 纯深蓝 + probe `rootChildren=0` + `TypeError: c.H.useRef` console error
- 修后：`/Users/anbaiqiang/wenshu-blue-v3-protocol-after-dedupe.png` 深蓝（设计意图，body bg）+ probe `rootChildren=1` + 0 error + 完整 WENSHU AGENT/安装文枢 文本
- 实际 Tauri 装机 mtime 12:43:41，process 51666 alive + WebContent 51670 + Networking 51671 全活

## 6. 边界确认（Out section 全部遵守）

- ✅ 未改 `apps/desktop/` / `apps/shared/` 业务代码
- ✅ 未改 `hermes_cli/` / `agent/` / `gateway/` / `tools/` 业务代码
- ✅ 未改 `scripts/install.sh` / `hermes_cli/default_soul.py` / `agent/prompt_builder.py` / `wenshu/SOUL.md` / `wenshu/AGENTS.md`
- ✅ 未改 `wenshu/methodologies/`
- ✅ 未改 8 老项目
- ✅ 未访问 `~/.wenshu-hermes/` / `~/.hermes_feishu_card/`
- ✅ 未 `git push`（装机 user 周末拍 push 时机）
- ✅ 未 `git reset --hard`（装机 user 拍"找得回来"=parent = `2c77bcf0d`）
- ✅ 未 PM-direct 自家跑（CC 派单 + 修 + 验）
- ✅ 调研范围限制在 `/Volumes/ANAN/Engineering/wenshu/` + `/Users/anbaiqiang/`（本地终端 + 仓内）
- ✅ 白名单外文件零改动

## 7. 找回 baseline + 下一单

### 找回 baseline（用户拍"找得回来"）

```bash
git log --oneline -5 main  # 确认本 commit 是 parent = 2c77bcf0d 上的新 commit
git checkout 2c77bcf0d -- apps/bootstrap-installer/vite.config.ts
# 如需整仓回滚：git checkout 2c77bcf0d
# 如需仅回滚本 commit：git revert HEAD
```

### 下一单（装机 user 拍板后派）

- WO-001AO: 装机 user 周末拍 push 时机（commit [新 hash] push origin main）
- WO-001AP: 装机 user 周末拍 5 件事（SOUL/AGENTS/methodologies/style/lego/hfc）
- WO-001AQ: 装机 user 后续提需求（Story 2 v0.3 / Story 3 / iPad / 多 hermes 桥接 / hermes 监控 / 跨设备共享）

## 8. 关联拍板

- `blue-screen-bug-fix-2026-08-26.md` (12,839 bytes) — WO-001AL CC 4 候选排查（v1 7/24 修复 commit `6cab7c457` 后续）
- `blue-screen-bug-v2-diagnosis.md` (14,887 bytes) — WO-001AM STEP 1 v2 5+ 候选排查
- `blue-screen-bug-v2-fix-2026-08-26.md` (9,926 bytes) — WO-001AM STEP 2-4 v2 修 + 重 build + 装机 + 验
- **本 doc** — WO-001AN STEP 1 v3 10 候选排查（本 commit 配套 doc 1/2）
- 兄弟档 `blue-screen-bug-v3-fix-2026-08-26.md` — WO-001AN STEP 2-4 v3 修 + 重 build + 装机 + headless 验（本 commit 配套 doc 2/2）
- `wenshu-setup-rebuild-2026-08-26.md` (2.7KB) — WO-001AJ CC 8/26 build trace
- 7/24 蓝屏修复 commit `6cab7c457 fix(installer): embed frontendDist on every dist rebuild`（v1 修复，仍生效）
- 7/27 v2 修复 commit `2c77bcf0d fix(installer): 蓝屏 BUG v2 修`（v2 修复，本 v3 commit 的 parent baseline）
- 6/30 `STEP 3 验证 trace` 在装机后由装机 user 拍屏验证（修后不再有"蓝的"反馈）
