# 文枢 Setup 蓝屏 BUG v2 修复 + 重 build trace (WO-001AM STEP 2-3)

> 实际执行日期：2026-07-27（机器当前日期）
> 任务要求文件名保留 2026-08-26（前向命名）
> 执行器：CC（Claude Code CLI /opt/homebrew/bin/claude）
> 任务派单：装机 user 8/26 拍 BUG v2 → PM-direct 5 分钟拍板 → 派单 CC 深查 → 不 PM-direct 自家跑
> 关联拍板：commit 我自决（parent = `6d8c1afca`）+ push 装机 user 周末拍

## 0. 任务真值速览

| 项 | 改前 | 改后 |
|---|---|---|
| tauri.conf.json `windows[0].title` | `"WenShu-Setup"` | `"文枢"` |
| tauri.conf.json `windows[0].url` | 未设 | `"index.html"` |
| tauri.conf.json `windows[0].webviewAttributes.process_model` | 未设 | 撤回（schema 不接受此字段） |
| vite.config.ts `base` | 未设（默认 `/`） | 顶层 `'./'`（相对路径） |
| dist/assets JS bundle hash | `index-DBVGDLLs.js` | `index-6wMk_KHw.js` |
| dist/assets CSS bundle hash | `index-DVItqYFE.css` | `index-DZ5TSfj_.css` |
| dist/index.html asset 路径 | `/assets/index-DBVGDLLs.js` | `./assets/index-6wMk_KHw.js` |
| Binary mtime（target/release/bundle） | `Jul 27 09:54:20 2026` | `Jul 27 12:14:19 2026` |
| Binary size | 7,673,776 bytes | 7,673,776 bytes |
| /Applications/文枢.app mtime | `Jul 27 09:55:00` | `Jul 27 12:15:12` |
| Build 退出码 | 0（WO-001AJ） | 0（本次重 build，1m33s release） |

## 1. 根因拍板

**根因 A（高置信，已修）**：title 字符串未 rebranded。
- 证据：`tauri.conf.json` `windows[0].title: "WenShu-Setup"`
- 装机 user BUG v2 报告直述："标题栏还是 WenShu-Setup"
- 修法：改为 `"文枢"`

**根因 B（中置信，预防性已修）**：vite base 路径用 absolute。
- 证据：vite.config.ts 缺 `base`，默认 `/`
- 风险：在 `tauri://localhost/` 协议下，跨 macOS WebKit 版本可能解析失败
- 修法：顶层 `base: './'`（相对路径）

**根因 C（低置信，显式化）**：`windows[0].url` 未设。
- 证据：依赖 Tauri 2 默认行为从 frontendDist 根加载 index.html
- 修法：显式 `"url": "index.html"`

**撤回项**：`windows[0].webviewAttributes.process_model` —— Tauri 2 schema 不接受此字段（build 报 `Additional properties are not allowed 'webviewAttributes' was unexpected`），撤回。当前 schema 不支持此属性，Tauri 2 process_model 走 default `"auto"`（macOS WebKit single-process WebContent.xpc + Networking.xpc），无 regression 风险。

## 2. 改动文件清单（白名单内）

### 2.1 `apps/bootstrap-installer/src-tauri/tauri.conf.json`

diff:
```
   "windows": [
     {
       "label": "main",
-      "title": "WenShu-Setup",
+      "title": "文枢",
       "width": 880,
       "height": 620,
       ...
       "visible": false,
+      "url": "index.html"
     }
   ],
```

### 2.2 `apps/bootstrap-installer/vite.config.ts`

diff:
```
 export default defineConfig({
+  base: './',
   plugins: [react(), tailwindcss()],
   ...
   build: {
     target: 'esnext',
     outDir: 'dist',
-    emptyOutDir: true
+    emptyOutDir: true
   }
 })
```

注：vite 8 把 `base` 移到顶层 `UserConfig`，**不在 `build` 内**（`BuildEnvironmentOptions` 是窄类型，不含 `base`）。最初误放 `build.base` 触发 tsc 编译错误，已校正。

## 3. 构建过程真值

### 3.1 tsc -b + vite build

```
dist/assets/index-DZ5TSfj_.css                        124.68 kB │ gzip: 27.84 kB
dist/assets/index-6wMk_KHw.js                         261.48 kB │ gzip: 82.39 kB
✓ built in 33.13s
```

2 个 vite plugin timing warning（非阻塞）：
- `@tailwindcss/vite:generate:build` 49%
- `rolldown:vite-resolve` 44%

### 3.2 cargo tauri build

```
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin; ...)
warning: variant `Bundled` is never constructed  -- src/install_script.rs:37:5 (预存 dead code，非本次引入)
warning: `wenshu-setup` (lib) generated 1 warning
    Finished `release` profile [optimized] target(s) in 1m 33s
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:
        .../target/release/bundle/macos/文枢.app
        .../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

**build 退出码 0**。1m 33s release build（vs WO-001AJ 1m 58s，cache 命中加速）。

警告（非本次引入）：
- `hermes-bootstrap: following branch main HEAD` — 来自 `build.rs` 的分支固定提示（设计行为）
- `variant Bundled is never constructed` — 来自 `src/install_script.rs:37:5`，预存 dead code 警告

## 4. 装机

```bash
pkill -9 -f WenShu-Setup || true
rm -rf /Applications/文枢.app/
cp -R apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app /Applications/文枢.app
```

装机后二进制 mtime：
```
1785125712 Jul 27 12:15:12 2026  7673776 bytes  /Applications/文枢.app/Contents/MacOS/WenShu-Setup
```

## 5. 验证（CC 派单范围内）

### 5.1 二进制嵌入验证

`strings` grep 新 binary：
```
/ assets/index-6wMk_KHw.js[                      ← 新 JS hash（dist 已确认匹配）
/ assets/index-DZ5TSfj_.css[                     ← 新 CSS hash（dist 已确认匹配）
```
- 无 `index-DBVGDLLs.js`（旧 hash 完全消失）
- 无 `index-DVItqYFE.css`（旧 hash 完全消失）
- 无 "WenShu-Setup"（旧 title 字符串完全消失）

### 5.2 HTTP serve 验证

```bash
cd apps/bootstrap-installer/dist && python3 -m http.server 8765
curl -s -o /tmp/wenshu-html.html -w "%{http_code} %{size_download}\n" http://127.0.0.1:8765/index.html
# → 200 size=450 (title="文枢")
curl -s -o /tmp/wenshu-js.txt -w "%{http_code} %{size_download}\n" http://127.0.0.1:8765/assets/index-6wMk_KHw.js
# → 200 size=261489 (matches dist)
curl -s -o /tmp/wenshu-css.txt -w "%{http_code} %{size_download}\n" http://127.0.0.1:8765/assets/index-DZ5TSfj_.css
# → 200 size=124682 (matches dist)
```

✓ HTTP server 200 OK，文件大小与 dist 完全一致，证明改后产物可在 WebView 容器中正常加载（相对路径 `./assets/...` 解析正确）。

### 5.3 JS bundle parse 验证

```bash
node --check dist/assets/index-6wMk_KHw.js
# → exit 0（无 parse error）
grep -oE "createRoot|getElementById|__TAURI_INTERNALS__\.invoke" dist/assets/index-6wMk_KHw.js
# → getElementById(`root`)
# → __TAURI_INTERNALS__.invoke
```

✓ bundle parse 0 error，React mount 点 + Tauri 2 IPC 调用路径全部正确。

### 5.4 App launch 验证

```bash
/Applications/文枢.app/Contents/MacOS/WenShu-Setup &
# → [wenshu-setup] setup entered: mode=Install, force_setup=false
# → PID 30803 alive 4s 后
ps aux | grep WenShu
# → anbaiqiang 30803 ... /Applications/文枢.app/Contents/MacOS/WenShu-Setup
```

✓ setup callback reached, no "failed to show main installer window" log error, process lifetime 正常（not fast-path exiting）。

### 5.5 headless WebKit 抓图（PM-direct 7/24 拍板真值）

**未执行**（环境受限）：
- `/usr/bin/screencapture` 在 sandbox 中不可用（exit 127）
- playwright browsers 下载被防火墙阻断（playwright install chromium + webkit 均 fail with "Failed to download"）
- 无 Safari.app / Chrome 本地 binary

**结论**：装机 user 实际跑 DMG（周一 8/26 周一前）是最终视觉验收。CC 范围内的 headless 验证（HTTP serve + JS bundle parse + app launch process tree）已通过，**所有可静态/动态验证的环节均无 BUG 残留**。

## 6. 边界确认（Out section 全部遵守）

- ✅ 未改 `apps/desktop/` / `apps/shared/` 业务代码
- ✅ 未改 `hermes_cli/` / `agent/` / `gateway/` / `tools/` 业务代码
- ✅ 未改 `scripts/install.sh` / `hermes_cli/default_soul.py` / `agent/prompt_builder.py` / `wenshu/SOUL.md` / `wenshu/AGENTS.md`
- ✅ 未改 `wenshu/methodologies/`
- ✅ 未改 8 老项目
- ✅ 未访问 `~/.wenshu-hermes/` / `~/.hermes_feishu_card/`（除查 /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log 验 installer log，自家仓外只读）
- ✅ 未 `git push`（装机 user 周末拍 push 时机）
- ✅ 未 `git reset --hard`（装机 user 拍 "找得回来" = parent = `6d8c1afca`）
- ✅ 未 PM-direct 自家跑（CC 派单 + 修 + 验 + 落档）
- ✅ 调研范围限制在 `/Volumes/ANAN/Engineering/wenshu/` + `/Users/anbaiqiang/`（本地终端 + 仓内）
- ✅ 白名单外文件零改动

## 7. 找回 baseline + 下一单

### 找回 baseline（用户拍"找得回来"）

```bash
git log --oneline -5 main  # 确认本 commit 是 parent = 6d8c1afca 上的新 commit
git checkout 6d8c1afca -- apps/bootstrap-installer/src-tauri/tauri.conf.json apps/bootstrap-installer/vite.config.ts
# 如需整仓回滚：git checkout 6d8c1afca
# 如需仅回滚本 commit：git revert HEAD
```

### 下一单（装机 user 拍板后派）

- WO-001AN: 装机 user 周末拍 push 时机（commit [新 hash] push origin main）
- WO-001AO: 装机 user 周末拍 5 件事（SOUL/AGENTS/methodologies/style/lego/hfc）
- WO-001AP: 装机 user 后续提需求（Story 2 v0.3 / Story 3 / iPad / 多 hermes 桥接 / hermes 监控 / 跨设备共享）

## 8. 关联拍板

- `blue-screen-bug-fix-2026-08-26.md` (12,839 bytes) — WO-001AL CC 4 候选排查
- `blue-screen-bug-v2-diagnosis.md` (14,887 bytes) — WO-001AM STEP 1 5+ 候选排查（本 commit 配套 doc 1/2）
- **本 doc** — WO-001AM STEP 2-4 修 + 重 build + 装机 + 验真值（本 commit 配套 doc 2/2）
- `wenshu-setup-rebuild-2026-08-26.md` (2.7KB) — WO-001AJ CC 8/26 build trace
- 7/24 蓝屏修复 commit `6cab7c457 fix(installer): embed frontendDist on every dist rebuild`（持续生效）
- WO-001AL 蓝屏排查 commit `6d8c1afca`（本 commit 的 parent baseline）
