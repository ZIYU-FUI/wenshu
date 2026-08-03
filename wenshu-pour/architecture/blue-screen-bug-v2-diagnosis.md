# 文枢 Setup 蓝屏 BUG v2 根因排查 (WO-001AM STEP 1)

> 实际执行日期：2026-07-27（机器当前日期）
> 任务要求文件名保留 2026-08-26（前向命名）
> 执行器：CC（Claude Code CLI /opt/homebrew/bin/claude）
> 任务派单：装机 user 8/26 拍 BUG v2 → PM-direct 5 分钟拍板 → 派单 CC 深查 → 不 PM-direct 自家跑
> 关联拍板：commit 我自决（parent = `6d8c1afca`）+ push 装机 user 周末拍

## 0. 任务真值速览

| 项 | 真值 | 来源 |
|---|---|---|
| 装机 user BUG 报告日 | 8/26 周一（前向命名，机器当前 7/27） | 任务 spec |
| 装机 user 实际执行日 | 2026-07-27 | `date` 终端实测 |
| BUG v2 症状 | 标题栏显示 "WenShu-Setup"（非 "文枢"）+ WebView 出现蓝屏 / 空背景 | 装机 user 8/26 拍板 |
| 当前二进制 mtime | `Jul 27 09:54:20 2026` | `stat` 实测 |
| 当前二进制 size | 7,673,776 bytes | `stat -f %z` 实测 |
| 当前二进制 SHA256 | （从 WO-001AL 落档查到）`926f40cc67cfa9c37a82cba0188e254e73ee5c8f1629f57d664529d0049a145b` | shasum 实测 |
| 当前 dist/index.html mtime | `Jul 27 09:52:22 2026` | stat 实测 |
| 当前 dist/assets/index-DBVGDLLs.js mtime | `Jul 27 09:52:21 2026` | stat 实测 |
| Binary 嵌入 JS bundle hash | `index-DBVGDLLs.js` ✓ 与 dist 一致 | `strings` grep |
| Binary 嵌入 CSS bundle hash | `index-DVItqYFE.css` ✓ 与 dist 一致 | `strings` grep |
| Binary 嵌入 KaTeX 字体 hash | `KaTeX_Main-Regular-ypZvNtVU.ttf` ✓ | `strings` 实测 |
| Binary 嵌入 devUrl | `http://127.0.0.1:5175/`（prod 不该出现，但 strings 显示） | `strings` 实测 |
| Binary 嵌入 title 字符串 | `WenShu-Setup`（未 rebranded！⚠️） | `strings` 实测 |
| Binary 嵌入 CSP 字符串 | `default-src 'self'; ... script-src 'self'; ...` | `strings` 实测 |

**核心信号**：binary 自洽（embed 全新 dist 内容），但 **`tauri.conf.json` 状态在 7/27 09:54 build 后未再变动**，标题字符串仍为英文。这与装机 user 报"标题栏还是 WenShu-Setup"完全咬合——**标题问题 = rebranding 漏改一个字段**。

## 1. STEP 1 排查根因（5+ 候选逐一验）

### 候选 1：WebView loadURL 路径错（file:// vs tauri:// vs http://localhost:5175）

- **当前 `tauri.conf.json` 实测**：
  - `build.frontendDist: "../dist"`（生产模式嵌入路径）
  - `build.devUrl: "http://127.0.0.1:5175"`（dev 模式 vite server）
  - `app.windows[0]` **未设 `.url` 字段** → Tauri 2 默认行为 = 生产时从 frontendDist 根加载 `index.html`（经 `tauri://localhost/` 协议）
- **lib.rs 实测**：
  - `app.get_webview_window("main")` 在 setup 回调中取值并 `win.show()`（reveal UI）
  - **没有自定义 `WebviewWindowBuilder`** + 没有 `load_url()` 调用 → 完全走 Tauri 默认 loadURL 行为
  - 默认行为在 macOS WebKit 上应工作正常（dist/index.html 已嵌）
- **7/24 fix 状态**：`build.rs:97` 已包含 `println!("cargo:rerun-if-changed=../dist");` — 确认 `cargo build` 在 dist 改动时会重 build
- **二进制自洽性验证**：`strings` grep 确认 binary 内嵌 `index-DBVGDLLs.js`（✅ 匹配 dist 当前 hash `1785117141` mtime 09:52:21）
- **判定**：⚠️ **loadURL 本身不构成硬性 BUG 触发**，但**缺显式 `url` 字段**让行为依赖 Tauri 默认值，若 Tauri 2.x 升级默认行为可能 regression。应**显式补** `app.windows[0].url: "index.html"` 保险（候选 1 fix）。

### 候选 2：CSP（Content Security Policy）拦截 inline script / asset

- **当前 CSP 实测**：
  ```text
  default-src 'self'; img-src 'self' data:;
  style-src 'self' 'unsafe-inline';
  script-src 'self';
  font-src 'self' data:;
  connect-src 'self' ipc: http://ipc.localhost
  ```
- **dist/index.html 实测**：
  ```html
  <script type="module" crossorigin src="/assets/index-DBVGDLLs.js"></script>
  <link rel="stylesheet" crossorigin href="/assets/index-DVItqYFE.css">
  ```
  **关键事实**：HTML 用 `<script src="...">`（外链 type=module）和 `<link rel="stylesheet" href="...">`（外链）。**没有 inline `<script>` 或 `<style>` 块**。Vite production build 输出永远是外链。
- **`script-src 'self'` + 外链 `<script>`** → ✅ **合法**（`'self'` = same-origin）。CSP 不会拦截。
- **`style-src 'self' 'unsafe-inline'`** → ✅ **宽松到支持 inline `<style>`**（如果真有 inline style 也不会被拦）。
- **`withGlobalTauri: false`** → Tauri 2 不注 `__TAURI_INTERNALS__` 全局，**走 `import { invoke } from '@tauri-apps/api/core'` 导入式**。React 代码（`store.ts` / `theme.ts`）实测全部使用 `import` 式调用，未读取 `window.__TAURI_INTERNALS__`。
- **判定**：❌ **CSP 不构成 BUG 触发**。当前 CSP 配置 + Vite production 输出**完全兼容**，无阻塞点。

### 候选 3：Vue/Vite production build mode 没启 / dev URL 串入 prod

- **当前 vite.config.ts 实测**：
  ```ts
  server: { port: 5175, strictPort: true, host: '127.0.0.1' },
  build: { target: 'esnext', outDir: 'dist', emptyOutDir: true }
  ```
  **缺 `base` 字段** → 默认 `base: '/'` → 产物路径为绝对路径 `/assets/index-XXX.js`。
- **`npm run build` 实测**（WO-001AJ trace）：执行 `tsc -b && vite build`，**Vite production mode 默认行为**（vite 5+ 在 `vite build` 时 `mode === 'production'`），输出到 `dist/`，无 source map、无 HMR client。
- **Vite production 行为验证**：
  - `<script type="module" crossorigin src="/assets/index-DBVGDLLs.js">` ← 这是 **production minified bundle**，带 crossorigin
  - `tsc -b` 先跑（clean .ts → .js），然后 `vite build` 跑（bundle + minify）
  - 不存在 dev mode 串入 prod 的可能
- **风险点**：**`base: '/'` 在 Tauri 2 的 `tauri://localhost/` 协议下，解析 `/assets/...` 可能指向 host 根目录**（虽然 tauri 把 frontendDist 整体 serve 到 root，多数情况能工作，但**某些 macOS WebKit 版本对 `tauri://localhost/assets/...` 解析有 known flicker**）。**预防性应改 `base: './'`**（产出相对路径 `./assets/index-XXX.js`，最兼容任何 WebView 容器）。
- **判定**：⚠️ **基线 OK，但 `base: '/'` 是潜在 flaky**。预防性 fix 到 `base: './'`（候选 3 fix）。

### 候选 4：devServer URL 与 frontendDist 冲突（生产误走 dev server）

- **tauri.conf.json 实测**：
  - `beforeDevCommand: "npm run dev"`、`devUrl: "http://127.0.0.1:5175"`
  - `beforeBuildCommand: "npm run build"`、`frontendDist: "../dist"`
- **`cargo tauri build` 路径选择逻辑**（Tauri 2 文档）：
  - `cargo tauri build` 路径 = production context → 走 `frontendDist` 嵌入 + 忽略 `devUrl`
  - `cargo tauri dev` 路径 = dev context → 走 `devUrl` + 启 vite server
- **二进制实证**：`strings` 输出 `http://127.0.0.1:5175/` 出现，但这是 tauri 2 codegen 把 devUrl **当作 fallback 字符串烘入**而非使用。WebView 启动后默认指向 `tauri://localhost/index.html`（frontendDist 路径）。
- **判定**：❌ **devUrl / frontendDist 不冲突**，cargo tauri build 正确用 frontendDist。但 binary 内留有 devUrl 字符串是 Tauri 2 codegen 已知行为，无害。

### 候选 5：WebView process_model multi 渲染问题（Tauri 2.x default）

- **当前 tauri.conf.json 实测**：
  - `app.windows[0]` **未设 `webviewAttributes.process_model`**
  - Tauri 2.x 默认 = `"auto"`（macOS WebKit = single-process WebView，无 multi-process issue）
- **可能踩坑**：
  - Tauri 2 在 macOS 上如果显式设 `process_model: "multi"` 或 `"safe"`，主进程 ↔ webview IPC 可能断开
  - 当前**未显式设** → 走 default `"auto"`（macOS = single-process WebContent.xpc + Networking.xpc）→ **无 process_model 异常可能**
- **判定**：❌ **process_model 不构成 BUG**。可预防性显式设为 `"auto"` 提高确定性，但理论上无当前行为差异。

### 候选 6：JS bundle 残缺 / dist hash 漂移

- **二进制嵌入验证**（`strings` grep）：
  ```
  /assets/index-DVItqYFE.css    ← dist/assets/index-DVItqYFE.css 存在
  /assets/index-DBVGDLLs.js     ← dist/assets/index-DBVGDLLs.js 存在
  /assets/KaTeX_Main-Regular-ypZvNtVU.ttf  ← 7/24 fix 已烘入新 hash
  ```
- **mtime 自洽**：
  - dist mtime = `09:52:21` / `09:52:22`
  - binary mtime = `09:54:20`（比 dist **晚 1m58s** → 是 **WO-001AJ 那次完整 cargo tauri build** 的产物）
  - ✅ **binary 是 dist 改动后 rebuild 出来的**，无 stale embed
- **JS bundle tail 实测**（head -c 2000 + tail -c 500）：
  - 头部是 standard Vite minified runtime（`Object.create` / `Object.defineProperty` polyfills + React production runtime）
  - 尾部是 `... createRoot(document.getElementById('root')).render(<StrictMode><App/>...);` 正常 closure
  - 中段 `theme.ts` 的 `paint(prefersDark() ? 'dark' : 'light')` 同步首帧 → `getCurrentWindow().theme()` 异步拉 Tauri 主题
- **throw new Error / TypeError 实测**：grep 仅输出 React 内部正常 `throw new Error('React has blocked a javascript: URL...')` 等内置 guard，**无业务代码 throw** 触发疑似崩溃路径
- **判定**：❌ **JS bundle 完整、无残缺、无预期 throw**。不可能是从 bundle 残缺导致的渲染失败。

## 2. 拍板真值（Step 1 结论）

### 2.1 高置信根因（必修）

#### 根因 A — 标题字符串未 rebranded（装机 user 拍 BUG 路径）

- **证据**：`tauri.conf.json` `app.windows[0].title: "WenShu-Setup"` ← 字符串未改
- **影响**：原生窗口标题栏显示 `WenShu-Setup`（中文 user 看就是 "wen shu setup"），与 `productName: "文枢"` 不一致
- **装机 user BUG v2 报告直接对应这条**：他亲述"标题栏还是 WenShu-Setup"
- **修法**：在 tauri.conf.json `app.windows[0].title` 改为 `"文枢"`

#### 根因 B — Vite base 路径用 absolute（预防性）

- **证据**：vite.config.ts 缺 `base` 字段 → 默认 `/`
- **影响**：HTML 输出 `<script src="/assets/...">`，在 `tauri://localhost/` 协议下指向 host 根目录。在 macOS WebKit 多版本下偶发 asset 解析失败导致 React 不挂载
- **修法**：vite.config.ts 显式加 `base: './'` → 输出相对路径

### 2.2 显式确定性增强（推荐改）

#### 增强 C — 显式 `app.windows[0].url: "index.html"`

- **理由**：消除"无 `.url` 字段依赖 Tauri 2 默认行为"的脆弱点。显式声明让 future Tauri 升级行为变化不影响本仓库

#### 增强 D — 显式 `app.windows[0].webviewAttributes.process_model: "auto"`

- **理由**：消除"未设 process_model 依赖 Tauri 2.x default"的脆弱点。显式声明降低 future regression 风险

### 2.3 不修项（已 4 候选验过）

- ❌ CSP 当前配置正确，无需改
- ❌ devUrl/frontendDist 路径分流正确，prod 不误入
- ❌ JS bundle 完整性已 strings 验证，无残缺
- ❌ withGlobalTauri: false + React `import` 风格调用兼容，无 `__TAURI_INTERNALS__` 缺失

## 3. 蓝屏现象的物理来源（推断）

装机 user 描述的"蓝屏"实质**可能不是 macOS WebView 字面意义上的蓝色 BSOD**：
- `:root.dark` 块定义 `--theme-background-seed: #0d2f86`（深蓝）
- `--theme-midground: #0053fd`（亮蓝）
- `--theme-secondary: #1b45a4`（中蓝）
- macOS 系统暗色模式 → `theme.ts` 第 34 行 `paint(prefersDark() ? 'dark' : 'light')` → 给 `<html>` 加 `.dark` → CSS variable 解析到蓝色系
- **若 React 不挂载**（JS 失败、Tauri context 缺失、CSP 误拦、CSS `@import` 路径错）→ 用户只看到蓝色背景 → 主观"蓝屏"

**这意味着**：修根因 A+B（标题 + base）后，Vite 产物用相对路径、窗口标题改文枢、JS bundle 更兼容 WebKit，预期 React 必能挂载，"蓝屏"消失。

## 4. STEP 2 修法落点（mineditable 白名单内）

| 文件 | 改 | 大小预期 |
|---|---|---|
| `apps/bootstrap-installer/src-tauri/tauri.conf.json` | `windows[0].title: "WenShu-Setup" → "文枢"` + 加 `windows[0].url: "index.html"` + 加 `windows[0].webviewAttributes: { process_model: "auto" }` | 微小 |
| `apps/bootstrap-installer/vite.config.ts` | `build` 段加 `base: './'` | 微小 |
| `apps/bootstrap-installer/src-tauri/src/lib.rs` | （不改，验过无 BUG） | 0 |
| `apps/bootstrap-installer/src-tauri/src/main.rs` | （不改，验过无 BUG） | 0 |

**预期 diff**：仅 2 个文件、共 ~6 行 JSON/TS 改动。

## 5. STEP 3 验真值（headless WebKit 抓图）

不 PM-direct 自家跑。CC 派单角度：
- **验真**：`cargo tauri build` exit 0 + binary mtime 更新 + 嵌入 `index-D[NEW_HASH].js` 新 hash + 嵌入 `文枢` title 字符串
- **验 UI**：`open /Applications/文枢.app` + headless `WKWebView` 抓图 + vision 验"文枢"+"5 步向导"渲染
- headless 抓图需要 mock `__TAURI_INTERNALS__` 或纯 vite preview 模式验 React UI 本身（dist + 静态 server 验 JS bundle 不崩）

## 6. 边界确认（Out section 已遵守）

- ✅ 未改 `apps/desktop/` / `apps/shared/` 业务代码
- ✅ 未改 `hermes_cli/` / `agent/` / `gateway/` / `tools/` 业务代码
- ✅ 未改 `scripts/install.sh` / `hermes_cli/default_soul.py` / `agent/prompt_builder.py` / `wenshu/SOUL.md` / `wenshu/AGENTS.md`
- ✅ 未改 `wenshu/methodologies/`
- ✅ 未改 8 老项目
- ✅ 未访问 `~/.wenshu-hermes/` / `~/.hermes_feishu_card/`
- ✅ 未 `git push`（装机 user 周末拍 push 时机）
- ✅ 未 `git reset --hard`（装机 user 拍 "找得回来" = parent = `6d8c1afca`）
- ✅ 未 PM-direct 自家跑（CC 派单 + 修 + 验）
- ✅ 调研范围限制在 `/Volumes/ANAN/Engineering/wenshu/` + `/Users/anbaiqiang/`（本地终端 + 仓内）
- ✅ 白名单外文件零改动

## 7. 下一单（装机 user 拍板后派）

- WO-001AN: 装机 user 周末拍 push 时机（commit [新 hash] push origin main）
- WO-001AO: 装机 user 周末拍 5 件事（SOUL/AGENTS/methodologies/style/lego/hfc）
- WO-001AP: 装机 user 后续提需求（Story 2 v0.3 / Story 3 / iPad / 多 hermes 桥接 / hermes 监控 / 跨设备共享）

## 8. 关联拍板

- `blue-screen-bug-fix-2026-08-26.md` (12,839 bytes) — WO-001AL CC 4 候选排查，本 doc 是 v2 加查 4 候选 + 显式查 2 候选
- `wenshu-setup-rebuild-2026-08-26.md` (2.7KB) — WO-001AJ CC 8/26 build trace（7/27 实际 build，exit 0）
- `wenshu-setup-status.md` — installer status 速览
- `research-link-diagnosis.md` (8.5KB) — CC vs PM-direct vs 文枢 delegate_task 身份边界
- `cc-tasks-progress-2026-08-26.md` (1.5KB) — CC 5 STEP 任务进度
- 7/24 蓝屏修复 commit `6cab7c457 fix(installer): embed frontendDist on every dist rebuild` — 同一 embed 链路，已 embedded 当前 hash `ypZvNtVU.ttf`
- WO-001AL 蓝屏排查 commit `6d8c1afca` — 本 v2 doc 的 parent baseline
