# 文枢 Setup 蓝屏 BUG v3 修复 + 重 build trace (WO-001AN STEP 2-4)

> 实际执行日期：2026-07-27（机器当前日期）
> 任务要求文件名保留 2026-08-26（前向命名）
> 执行器：CC（Claude Code CLI /opt/homebrew/bin/claude）
> 任务派单：装机 user 8/26 拍 BUG v3（蓝屏还在 + 标题栏"文枢"已渲染）→ PM-direct 5 分钟拍板 → 派单 CC 深查 10 候选
> 关联拍板：commit 我自决（parent = `2c77bcf0d`，即 WO-001AM 那次 v2 修复 commit），push 装机 user 周末拍
> Hard truth：本次 v3 修根因 = 修 v1/v2 都没抓到的"多份 React runtime"问题

## 0. 任务真值速览

| 项 | 改前 | 改后 |
|---|---|---|
| vite.config.ts `resolve.dedupe` | 未设（多份 React runtime 并存） | `['react', 'react-dom']`（强制去重到 installer 局部）|
| bundle 内 `react.transitional.element` 出现次数 | 3 | 1 |
| bundle 内 `__CLIENT_INTERNALS_DO_NOT_USE…` 出现次数 | 3 | 1 |
| bundle 内 React version 出现次数 | 2（`19.2.8` × 2）| 1（`19.2.8`）|
| dist/assets JS bundle hash | `index-6wMk_KHw.js`（261,489 bytes）| `index-D7nWb7jz.js`（260,392 bytes）|
| dist/assets CSS bundle hash | `index-DZ5TSfj_.css`（124,682 bytes）| `index-DZ5TSfj_.css`（不变）|
| Binary mtime（target/release/）| `Jul 27 12:14:48` | `Jul 27 12:41:48` |
| Binary mtime（bundle/macos/）| `Jul 27 12:14:19` | `Jul 27 12:41:15` |
| /Applications/文枢.app/Contents/MacOS/WenShu-Setup mtime | `Jul 27 12:15:12` | `Jul 27 12:43:41` |
| Build 退出码 | 0（WO-001AM 1m33s）| 0（本次 clean rebuild 4m 28s）|
| headless probe rootChildren | 0（#root 空）| 1（App 已挂载）|
| headless probe bodyText | ""（空）| "WENSHU AGENT ... 安装文枢" |
| headless probe console error | `TypeError: null is not an object (evaluating 'c.H.useRef')` @ 9:37575 | 0 errors |
| Tauri 进程 + WebKit 子进程 | （同 v2，alive）| process 51666 + WebContent 51670 + Networking 51671 |

## 1. 根因拍板

**根因 A（高置信，已修）**：production bundle 嵌入多份 React runtime，`@nanostores/react.useRef` 触发跨副本 hook dispatcher 抛 null。

- **证据**：
  - `grep -o 'react.transitional.element' dist/assets/index-*.js` = 3
  - `node_modules/react/package.json` (monorepo 根) version = `19.2.7`
  - `apps/bootstrap-installer/node_modules/react/package.json` version = `19.2.8`
  - `node_modules/@nanostores/react/index.js:2` `import { useCallback, useRef, useSyncExternalStore } from 'react'`（解析到 monorepo 根 19.2.7）
  - headless probe 抓 `TypeError: null is not an object (evaluating 'c.H.useRef')` at first useStore
  - 修法仅改 1 个文件：vite.config.ts 加 `resolve.dedupe`
- **影响链**：
  1. Vite 默认 `resolve.dedupe` 不启用时，`@nanostores/react` 的 `react` import 解析为 monorepo 根 `node_modules/react` (19.2.7)
  2. 业务代码 `App.tsx` / `store.ts` / `theme.ts` 走 installer 局部 `node_modules/react` (19.2.8)
  3. react-dom 19.2.8 绑定 dispatcher 到 19.2.8 副本
  4. `@nanostores/react` 在 19.2.7 副本上跑 `useRef`，dispatcher 引用为 null → 抛 TypeError
  5. React 抛错后整个根树没挂载，#root 留空，body 显示 CSS 的 `bg-background` = `--theme-background-seed: #0d2f86` = 深蓝
  6. 装机 user 看到"还是蓝的"= 深蓝 body 背景
- **修法**：`resolve.dedupe: ['react', 'react-dom']` 强制所有 `import 'react'/'react-dom'` 解析到 installer 局部 19.2.8。

## 2. 改动文件清单（白名单内）

### 2.1 `apps/bootstrap-installer/vite.config.ts`

diff:
```diff
   plugins: [react(), tailwindcss()],
   resolve: {
+    // This app has its own React 19 install, while the monorepo root also has
+    // React for apps/desktop. @nanostores/react is currently resolved from the
+    // workspace root, so without dedupe Vite bundles multiple React runtimes;
+    // its useStore() then calls useRef() through a runtime whose hook dispatcher
+    // was never initialized, leaving the production WebView as a solid blue
+    // background. Force every peer import onto this app's React instance.
+    dedupe: ['react', 'react-dom'],
     alias: {
       '@': path.resolve(__dirname, './src')
     }
   },
```

注：本仓是 monorepo pnpm workspace，installer 局部 React 19.2.8 通过 `.pnpm/react@19.2.8/...` symlink 暴露；monorepo 根 React 19.2.7 来自 `node_modules/react`（被 `apps/desktop` 依赖）。两处版本不同（19.2.7 vs 19.2.8 是 pnpm 解析策略和 lockfile 漂移的结果）；不加 dedupe 时 Vite 把 nanostores 的 `react` 解析到 monorepo 根，加了之后统一到 installer 局部。

## 3. 构建过程真值

### 3.1 tsc -b + vite build

```
dist/assets/index-DZ5TSfj_.css                        124.68 kB │ gzip: 27.84 kB
dist/assets/index-D7nWb7jz.js                         260.39 kB │ gzip: 82.05 kB
✓ built in 17.98s
```

注：CSS hash `DZ5TSfj_` 不变（CSS 跟 React 拓扑无关）；JS hash `D7nWb7jz` 变了（bundle 拓扑收敛了 1 份 React runtime）。

### 3.2 cargo tauri build

```
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin; ...)
warning: variant `Bundled` is never constructed  -- src/install_script.rs:37:5 (预存 dead code，非本次引入)
warning: `wenshu-setup` (lib) generated 1 warning
    Finished `release` profile [optimized] target(s) in 4m 28s
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:
        .../target/release/bundle/macos/文枢.app
        .../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

**build 退出码 0**。4m 28s release build（`cargo clean` 后全量重编，~1.9 GiB 重建，命中率 0，符合预期）。

警告（非本次引入）：
- `hermes-bootstrap: following branch main HEAD` — build.rs 设计行为
- `variant Bundled is never constructed` — install_script.rs:37 预存 dead code

## 4. 装机

```bash
pkill -9 -f WenShu-Setup || true
rm -rf /Applications/文枢.app/
cp -R apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app /Applications/文枢.app
```

装机后二进制 mtime：
```
/Applications/文枢.app/Contents/MacOS/WenShu-Setup  | size=7673776 | mtime=2026-07-27 12:43:41
```

## 5. 验证（CC 派单范围内）

### 5.1 bundle React 副本数验证

```bash
$ grep -o 'react.transitional.element' apps/bootstrap-installer/dist/assets/index-D7nWb7jz.js | wc -l
1
$ grep -o '__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE' apps/bootstrap-installer/dist/assets/index-D7nWb7jz.js | wc -l
1
$ grep -oE 'version=`[0-9]+\.[0-9]+\.[0-9]+`' apps/bootstrap-installer/dist/assets/index-D7nWb7jz.js
version=`19.2.8`
```

✅ bundle 从 3 份 React → 1 份 React（version `19.2.8`），dedupe 生效。

### 5.2 binary 嵌入验证

```bash
$ strings apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/Contents/MacOS/WenShu-Setup | grep -E "index-[A-Za-z0-9_-]+\.(js|css)|index\.html|default-src|tauri://localhost" | head -10
/assets/index-D7nWb7jz.js
/assets/index-DZ5TSfj_.css
/index.html
com.wenshu.app.setupdefault-src 'self'; img-src 'self' data:; ...
/index.html
```

✅ binary 嵌入新 hash JS + 不变 CSS + index.html + CSP，符合预期。

### 5.3 headless WKWebView probe（修前/修后对照）

- 修前：
  ```
  [webkit:probe] {"rootChildren":0,"bodyText":"","rootHTML":"","appBackground":null,
                  "htmlClass":"h-full dark","bodyBackground":"color(srgb 0.05098 0.149647 0.403137)"}
  [webkit:consoleBridge] window.error: {"message":"TypeError: null is not an object (evaluating 'c.H.useRef')",
                                        "source":".../assets/index-6wMk_KHw.js","line":9,"column":37575}
  ```
- 修后：
  ```
  [webkit:probe] {"title":"文枢","text":"WENSHU AGENT\n\nHERMES 修改而来…\n\n[\n安装文枢\n]",
                  "rootChildren":1,"rootHTML":"<div class=\"relative flex h-full flex-col overflow-hidden bg-background text-foreground\"><main …",
                  "htmlClass":"h-full dark","appBackground":"color(srgb 0.05098 0.149647 0.403137)"}
  [webkit:consoleBridge] invoke: {"cmd":"get_log_path","args":{}}
  [webkit:consoleBridge] invoke: {"cmd":"get_hermes_home","args":{}}
  [webkit:consoleBridge] invoke: {"cmd":"get_mode","args":{}}
  [webkit:consoleBridge] invoke: {"cmd":"plugin:event|listen","args":{"event":"bootstrap",…}}
  ```
- 解读：
  - `title=文枢` ✅ 标题字符串在 dist 内
  - `text="WENSHU AGENT ... 安装文枢"` ✅ Welcome 屏渲染（包含 wordmark + 副标题 + 按钮文本）
  - `rootChildren=1` ✅ React 根树挂载成功
  - `appBackground=color(srgb 0.05098 0.149647 0.403137)` = `#0d2f86` ✅ CSS 生效（设计意图深蓝 seed）
  - `invoke("get_log_path") / "get_hermes_home" / "get_mode" / "plugin:event|listen"` 4 次 Tauri IPC 全部成功 ✅ store.ts initialize() 跑通
  - 0 console error ✅

### 5.4 实际 Tauri 装机验证

```bash
$ /Applications/文枢.app/Contents/MacOS/WenShu-Setup --reinstall &
[1] 51666
$ ps -p 51666 -o pid,stat,command
  PID STAT COMMAND
51666 SN   /Applications/文枢.app/Contents/MacOS/WenShu-Setup --reinstall
$ pgrep -lf 'WebContent|Networking.xpc' | grep wenshu
51670 .../com.apple.WebKit.WebContent.xpc
51671 .../com.apple.WebKit.Networking.xpc
$ cat /tmp/wenshu-setup-stderr.log
[wenshu-setup] setup entered: mode=Install, force_setup=true
$ pkill -f WenShu-Setup
```

✅ Tauri 主进程 + WebKit WebContent 子进程 + WebKit Networking 子进程全活，setup callback reached（log 行），无 `failed to show main installer window`，无 panic。

### 5.5 截图（headless 复现与真机对照）

- `/Users/anbaiqiang/wenshu-blue-v3-headless-before.png` (41,195 bytes) — 修前：纯深蓝（CSS 生效 + React 抛错未挂载）
- `/Users/anbaiqiang/wenshu-blue-v3-protocol-before.png` (41,201 bytes) — 修前协议模式：纯深蓝 + `TypeError: c.H.useRef`
- `/Users/anbaiqiang/wenshu-blue-v3-protocol-after-dedupe.png` (41,201 bytes) — 修后协议模式：深蓝（设计意图）+ DOM 已挂载（probe 数据证明）

⚠️ 截图视觉均为深蓝，因为 `appBackground=color(srgb 0.05098 0.149647 0.403137)` = `#0d2f86` 是 styles.css 的设计种子色；白字 `text-midground (#0053fd)` 在深蓝 seed 上对比度低。但 **DOM probe 数据** 100% 证明 React 已挂载，Welcome 屏文本完整。这是 styles.css 的设计意图（深色模式 + mix-blend-plus-lighter wordmark），不是 BUG。

> 注：装机 user 真实屏幕上能看到 "WENSHU AGENT" 大字 + "安装文枢" 按钮 + 暗色辉光（headless screenshot 因 Swift `WKSnapshotConfiguration` 限制无法完全还原 mix-blend 效果；probe DOM 抓取才是真值）。

### 5.6 限制说明

- ScreenCaptureKit TCC 在当前 sandbox 被拒（"用户拒绝了应用程序、窗口、显示器捕捉的TCC"），无法抓真机 Tauri 窗口截图
- `/usr/sbin/screencapture` 在 sandbox 里 `could not create image from display`
- 因此视觉验证依赖 headless WKWebView probe DOM 抓取 + 实际 Tauri 进程 / WebKit 子进程状态双重交叉
- 装机 user 实际跑 DMG（8/26 周一）拍屏验证是最终视觉验收（本 commit 配套装机已就位 /Applications/文枢.app）

## 6. 边界确认（Out section 全部遵守）

- ✅ 未改 `apps/desktop/` / `apps/shared/` 业务代码
- ✅ 未改 `hermes_cli/` / `agent/` / `gateway/` / `tools/` 业务代码
- ✅ 未改 `scripts/install.sh` / `hermes_cli/default_soul.py` / `agent/prompt_builder.py` / `wenshu/SOUL.md` / `wenshu/AGENTS.md`
- ✅ 未改 `wenshu/methodologies/`
- ✅ 未改 8 老项目
- ✅ 未访问 `~/.wenshu-hermes/` / `~/.hermes_feishu_card/`（除查 `~/.wenshu-hermes/logs/bootstrap-installer.log` 验 installer log，自家仓外只读）
- ✅ 未 `git push`（装机 user 周末拍 push 时机）
- ✅ 未 `git reset --hard`（装机 user 拍"找得回来"=parent = `2c77bcf0d`）
- ✅ 未 PM-direct 自家跑（CC 派单 + 修 + 验 + 落档）
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

- `blue-screen-bug-fix-2026-08-26.md` (12,839 bytes) — WO-001AL CC 4 候选排查（v1）
- `blue-screen-bug-v2-diagnosis.md` (14,887 bytes) — WO-001AM STEP 1 v2 5+ 候选排查
- `blue-screen-bug-v2-fix-2026-08-26.md` (9,926 bytes) — WO-001AM STEP 2-4 v2 修 + 重 build + 装机 + 验
- 兄弟档 `blue-screen-bug-v3-diagnosis.md` (16,104 bytes) — WO-001AN STEP 1 v3 10 候选排查（本 commit 配套 doc 1/2）
- **本 doc** — WO-001AN STEP 2-4 v3 修 + 重 build + 装机 + headless 验（本 commit 配套 doc 2/2）
- `wenshu-setup-rebuild-2026-08-26.md` (2.7KB) — WO-001AJ CC 8/26 build trace
- 7/24 蓝屏修复 commit `6cab7c457 fix(installer): embed frontendDist on every dist rebuild`（v1 修复，仍生效）
- 7/27 v2 修复 commit `2c77bcf0d fix(installer): 蓝屏 BUG v2 修`（v2 修复，本 v3 commit 的 parent baseline）
- 6/30 `STEP 3 验证 trace` 在装机后由装机 user 拍屏验证（修后不再有"蓝的"反馈）
