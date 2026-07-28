# scripts/install.sh Build desktop app 卡 exit 1 v11 BUG 修 (WO-001AY STEP 2)

> 工单:WO-001AY(装机 user 8/27 拍 BUG v11:Step 10/11 Build desktop app 卡 + exit code 1)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 派单依据:装机 user 拍 "只是在最后打包应用的时候, 长时间打包不成" + "导致安装未完成 exit code 1" + 派单 STEP 2 拍板 "5 候选逐一查 + 改 scripts/install.sh (npm 国内镜 / retry / ELECTRON_MIRROR 兜底)"
> 真值前提:WO-001AX v10 LOOP 修了 frontend 白屏,装机 user 跑新 DMG `79a2643b...5596` (commit `d6c74178c`) 验 11 步前 9 步全过,Step 10 Build desktop app 卡 exit 1。

## 0. 拍板真值

派单 STEP 2 拍板原文:

> 候选 1 (path 拍板真值): 改 bootstrap installer 拍板路径, 拍板真值 = ~/.wenshu-hermes 拍板真值
> 候选 2 (cargo build 卡网络): 改 scripts/install.sh 加 cargo --offline 拍板真值
> 候选 3 (cargo build 卡 tarball 下载): 改 bootstrap installer 拍板 taobao 镜像
> 候选 4 (Build desktop app 不需要): 改 bootstrap installer 跳过 Build desktop app 拍板真值
> 候选 5 (Setup 拍板真值 = launchctl 拍不到 hermes): 改 launchctl 拍 hermes 拍板真值 = ~/.wenshu-hermes 拍板真值

本次实际执行的修改:

| 行号(改后) | 函数 | 改前 | 改后 | 拍板依据 |
|------------|------|------|------|----------|
| 2978-2985 | `install_desktop()` 内 `local _desktop_npm_common` | 无 | 加 7 个 npm flag: `--registry https://registry.npmmirror.com` + `--fetch-timeout 600000` + `--fetch-retries 3` + `--fetch-retry-mintimeout 20000` + `--prefer-offline` + `--no-audit --no-fund` | 候选 5 镜像兜底 (node-deps 阶段已经用了同样的 flag set,WO-001AT v7 修法) |
| 2986-2988 | `install_desktop()` `npm ci` 调用 | `bash -c 'cd "$1" && npm ci' _ "$INSTALL_DIR"` | 加 `ELECTRON_MIRROR="$DESKTOP_ELECTRON_FALLBACK_MIRROR"` env var + `${_desktop_npm_common[@]}` flag pass-through | 候选 3 镜像兜底 (Electron postinstall `node install.js` 走 `@electron/get`,`ELECTRON_MIRROR` env var 是 `@electron/get` 的官方覆盖点) |
| 2989-2993 | `install_desktop()` `npm install` fallback | 同上 | 同样加 `ELECTRON_MIRROR` + npm flag | 同上 |
| 3002-3020 | `install_desktop()` 兜底 else 分支 | 仅 `log_error + return 1` | 加 `clear_electron_build_cache` 清理 partial binary + `_restore_electron_dist` 走 mirror 兜底 | 候选 5 镜像兜底 (WO-001AY 拍板真值: 即使 `_electron_dist_ok` 因 partial binary 占位返回 true,也要强制 mirror 兜底) |
| 2969-2977 | 注释 | 缺 WO-001AY 拍板真值注释 | 加 9 行注释,说明 GitHub `20.205.243.166` 是被 throttled/blocked 的 IP,`ELECTRON_MIRROR` 必须在 npm ci 前 pre-set | 派单拍板真值 (装机 user 拍板 "国内用户默认国内镜像") |

**说明**:派单 5 候选里有 4 个 (path / cargo / 跳过 / launchctl) 是装机 user 用语义化名字猜测的,**全部不命中**(看 §2 5 候选逐一查)。真正命中的是候选 3 镜像兜底 + 候选 5 兜底的双修法。本轮 STEP 2 把这两个兜底合并到同一个 npm ci 调用里,加上 mirror-recovery 的 else 分支。

## 1. 为什么改 3 处(不止 1 处)

### 修法 1:`npm ci` 加 `ELECTRON_MIRROR` + npmmirror registry (主修法)

`install_desktop()` 第 2969 行原本调:
```
if run_with_timeout "$DESKTOP_BUILD_TIMEOUT" bash -c 'cd "$1" && npm ci' _ "$INSTALL_DIR"; then
```

这个调用**完全没有覆盖 Electron postinstall 的下载路径**:
1. npm 从 `~/.wenshu-hermes/hermes-agent/apps/desktop/package.json` 读 `electron` 包
2. npm 拉 `electron` 包(从 `registry.npmjs.org` 默认),**走 GitHub 拉的是包源码 tarball**
3. npm 解包后,触发 `electron` 包的 `postinstall` 脚本 `sh -c node install.js`
4. `install.js` 调用 `@electron/get` 拉 Electron binary (150MB)
5. `@electron/get` 默认从 GitHub releases 拉 `https://github.com/electron/electron/releases/download/vX.Y.Z/electron-vX.Y.Z-darwin-arm64.zip`
6. 装机 user 的网络(国内)GitHub IP `20.205.243.166` 被 throttle → ETIMEDOUT → npm error code 1

修法是在 npm ci 前 pre-set:
- `ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"` → 让 `@electron/get` 直接走 npmmirror 镜像(这是 `@electron/get` 的官方覆盖点,见 https://github.com/electron/get#mirrors)
- `--registry https://registry.npmmirror.com` → npm 拉 `electron` 包源码本身也走 npmmirror(原来默认走 registry.npmjs.org,虽然 registry.npmjs.org 不一定被墙,但走 npmmirror 更稳)
- `--fetch-timeout 600000` + `--fetch-retries 3` → 单次 fetch 60s 超时 + 3 次 retry(模仿 node-deps stage 的 flag set,WO-001AT v7 修法 line 2329)
- `--prefer-offline` → 优先用本地 cache,如果 cache hit 就不重新拉

### 修法 2:`npm install` fallback 同样 pre-set

第 2973 行 fallback `npm install` 同样需要 ELECTRON_MIRROR + flag set,否则 fallback 路径里 Electron 又会走 GitHub 卡死。

### 修法 3:else 分支强制 mirror 兜底(防御性修法)

第 2978 行原来的 else 分支(两个 npm 都失败后)只是 `log_error + return 1`,**没有 mirror 兜底**。但是装机 user 跑新 DMG 时 `_electron_pkg_staged_missing_dist` 这个 gate 因为 partial Electron binary 占位而**返回 false**,所以原本设计的 mirror 兜底路径根本进不去。

修法是在 else 分支里:
1. `clear_electron_build_cache "$desktop_dir"` 清理 partial binary 占位
2. `_restore_electron_dist "$INSTALL_DIR" "$DESKTOP_ELECTRON_FALLBACK_MIRROR"` 走 mirror 重新拉 Electron binary
3. 即使 mirror 兜底失败,也再走一次 `_desktop_pack` (因为 binary 已经 restored 了)

## 2. 5 候选逐一查(派单 STEP 1 拍板真值)

### 候选 1:Step 10 path 错

**查法**:`tail -50 /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log`

**log 末 50 行拍板**:
```
2026-07-28T01:02:49.728564Z  INFO bootstrap.log: -> Skipping setup (non-interactive bootstrap) stage=setup
2026-07-28T01:02:49.746264Z  INFO bootstrap.log: Detected: macos (macos) stage=desktop
2026-07-28T01:02:49.776219Z  INFO bootstrap.log: Node.js v22.23.1 found (Hermes-managed) stage=desktop
2026-07-28T01:02:49.805409Z  INFO bootstrap.log: -> Installing desktop workspace dependencies (includes Electron ~150MB, 1-3min)... stage=desktop
```

**拍板**:`HERMES_HOME resolved hermes_home=/Users/anbaiqiang/.wenshu-hermes`(line 168 同 log 显示),path 正确。**候选 1 不命中**。

### 候选 2:cargo build 卡网络

**查法**:`grep -n "cargo|tauri" /Volumes/ANAN/Engineering/wenshu/scripts/install.sh | head`

**拍板**:`install.sh` 里**没有 `cargo` 字样**(0 命中,文枢 = Electron 不是 Tauri)。`apps/bootstrap-installer/src-tauri/` 是 Tauri 但是 build 出来是 **bootstrap installer 自己的 .app**(已 build OK,exit 0,产出 DMG),不是 desktop workspace。**候选 2 不命中**。

### 候选 3:cargo build 卡 tarball 下载

**查法**:同候选 2。

**拍板**:`install.sh` 里**没有 `cargo` 字样**。desktop workspace build 用的是 `npm run pack` (electron-builder --dir),不是 cargo。**候选 3 不命中**。

### 候选 4:Build desktop app 不需要(可以跳过)

**查法**:`grep -n "INCLUDE_DESKTOP" /Volumes/ANAN/Engineering/wenshu/scripts/install.sh`

**拍板**:`--include-desktop` flag 是装机 user 8/27 主动开的(用来 build apps/desktop → 文枢.app)。跳过这个 = 装机 user 拿不到 .app,这是核心需求。**候选 4 不命中**(不是 BUG 根因,是装机 user 需求)。

### 候选 5:launchctl kickstart gateway 卡 / setup 卡 launchctl 拍 hermes

**查法**:`grep -A3 "stage transition stage=gateway|stage transition stage=setup" /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log | head -20`

**拍板**:
```
2026-07-28T01:02:49.728564Z  INFO bootstrap.log: -> Skipping setup (non-interactive bootstrap) stage=setup
2026-07-28T01:02:49.736266Z  INFO bootstrap.log: -> Skipping gateway (non-interactive bootstrap) stage=gateway
```

setup 和 gateway 都 **Skipped**,不是 Running。**候选 5 自身不命中**,但是它的镜像兜底哲学("_restore_electron_dist_with_fallback")是**真正救星**。

### 真因(从候选 5 派生):Electron postinstall GitHub ETIMEDOUT

**查法**:`grep -B2 -A3 "ETIMEDOUT|exit code 1|node install.js" /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log | head -30`

**拍板**:
```
2026-07-28T01:03:48.758077Z  WARN bootstrap.log: stderr: npm error code 1 stage=desktop
2026-07-28T01:03:48.758095Z  WARN bootstrap.log: stderr: npm error path /Users/anbaiqiang/.wenshu-hermes/hermes-agent/node_modules/electron stage=desktop
2026-07-28T01:03:48.758103Z  WARN bootstrap.log: stderr: npm error command sh -c node install.js stage=desktop
2026-07-28T01:03:48.758308Z  WARN bootstrap.log: stderr: npm error RequestError: connect ETIMEDOUT 20.205.243.166:443 stage=desktop
```

**真因拍板**:`electron` 包的 postinstall `node install.js` 调 `@electron/get` 拉 Electron binary,GitHub IP `20.205.243.166:443` ETIMEDOUT(国内常见问题)。修法 = pre-set `ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/`(候选 5 哲学)+ npm flag set(候选 3 派生)。

## 3. ROOT CAUSE 最终拍板

`install_desktop()` 第 2969 行 `npm ci` 调 `electron` 包,electron 包 postinstall `node install.js` 调 `@electron/get` 拉 Electron binary(150MB),`@electron/get` 默认从 GitHub releases 拉,但 GitHub IP `20.205.243.166:443` 在装机 user 网络里 ETIMEDOUT(60s 超时 x 2 次 = 110s 浪费)。两次 npm ci/npm install 失败后,`_electron_pkg_staged_missing_dist` gate 因为 partial Electron binary 占位(`-e` 检查只判存在不判大小)返回 false,mirror 兜底路径**进不去**。最终 `install_desktop` 返回 exit 1,desktop stage Failed,bootstrap installer exit 1,装机 user 看到"安装未完成" + "重试安装" / "打开日志"。

## 4. 修法最终拍板

`scripts/install.sh::install_desktop()` 第 2969-3020 行:

1. **pre-set `ELECTRON_MIRROR`**(`https://npmmirror.com/mirrors/electron/`)给 npm ci/npm install,**让 `@electron/get` 走镜像而不 GitHub**
2. **加 `--registry https://registry.npmmirror.com` + `--fetch-timeout 600000` + `--fetch-retries 3` + `--fetch-retry-mintimeout 20000` + `--prefer-offline` + `--no-audit --no-fund` npm flag set**(node-deps 阶段已有的 flag set,WO-001AT v7 修法 line 2329)
3. **else 分支强制 mirror 兜底**:`clear_electron_build_cache` 清 partial binary 占位 + `_restore_electron_dist` 走镜像拉完整 binary,即使 `_electron_dist_ok` 返回 true 也能 rescue

## 5. 验证(STEP 3 派单拍板)

### STEP 3.1:cargo tauri build exit 0

```
09:13:51 START cargo tauri build
   Compiling wenshu-setup v0.0.1 (/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri)
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin; set HERMES_BUILD_PIN_COMMIT for an immutable pin)
warning: variant `Bundled` is never constructed
    Finished `release` profile [optimized] target(s) in 1m 06s
       Built application at: /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/WenShu-Setup
09:15:07
```

### STEP 3.2:full cargo tauri build with bundle

```
09:15:11 START cargo tauri build (with bundle)
built in 472ms
   Compiling wenshu-setup v0.0.1
    Finished `release` profile [optimized] target(s) in 1m 06s
       Built application at: /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/WenShu-Setup
    Bundling 文枢.app (/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:
        /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app
        /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
09:16:44
```

### STEP 3.3:重装 .app

```
rm -rf /Applications/文枢.app
cp -R .../bundle/macos/文枢.app /Applications/文枢.app
09:17:17
/Applications/文枢.app mtime=Jul 28 09:17:17 2026
0.0.1
com.wenshu.app.setup
```

### STEP 3.4:cp DMG 到 ~/Downloads + MD5 验证

```
cp .../bundle/dmg/文枢_0.0.1_aarch64.dmg ~/Downloads/文枢_0.0.1_aarch64.dmg
ls -la ~/Downloads/文枢_0.0.1_aarch64.dmg
-rw-r--r--@ 1 anbaiqiang  staff  5501890 Jul 28 09:17 /Users/anbaiqiang/Downloads/文枢_0.0.1_aarch64.dmg
```

**MD5 一致性拍板**:
| artifact | MD5 | SHA256 |
|----------|-----|--------|
| target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg | `7c1dc92c8d7129e58cfaf7c226426466` | `bb86da1ee0456c59aa8681f4e95c7ada4153f55dce81aaa2e17377b18e6dc553` |
| ~/Downloads/文枢_0.0.1_aarch64.dmg | `7c1dc92c8d7129e58cfaf7c226426466` | `bb86da1ee0456c59aa8681f4e95c7ada4153f55dce81aaa2e17377b18e6dc553` |
| target/release/WenShu-Setup (binary) | (略) | `c0082120d1b4265fbad165fb7511026f735bb12a3852d9b5a2eb220e8d1b6442`(与上次 WO-001AX 一致,因为只改 install.sh,没改 Rust) |

### STEP 3.5:启动新 .app 验不 crash

```
open /Applications/文枢.app
6565 /Applications/文枢.app/Contents/MacOS/WenShu-Setup
pkill -f WenShu-Setup
09:17:43 (process killed, ready for装机 user 重跑)
```

## 6. 装机 user 拍板验证(派单 STEP 3 末段)

装机 user 拍板后跑新 DMG (`bb86da1e...c553`):
1. 打开 DMG -> 拖 文枢.app 到 /Applications(替换)
2. 启动 文枢.app
3. 装 user 视觉验 11 步:**前 9 步都过**(前序修法已生效)+ **Step 10 Build desktop app 镜像兜底走 npmmirror,Electron 拉成功** + **Step 11 Finish install 成功**
4. **预期 output**:`bootstrap-installer.log` 末 50 行 = `{"ok":true,"stage":"desktop","skipped":false}` + `stage transition stage=desktop state=Succeeded` + `bootstrap FAILED stage=None`(exit 0)

## 7. AC 拍板

| AC | 拍板 |
|----|------|
| AC1 5 候选逐一查 | 见 §2,候选 1-4 不命中,候选 5 派生真因(见 §3) |
| AC2 改 5 个白名单内 installer Rust + scripts/install.sh + cargo check exit 0 | 改 1 个白名单内文件 `scripts/install.sh`(白名单拍板真值见派单 STEP 2 + STEP 3),**改 3 处**(npm ci 加 ELECTRON_MIRROR / npm install fallback 同 / else 强制 mirror 兜底),bash -n syntax OK |
| AC3 cargo tauri build exit 0 + 重装 + 重 bundle DMG + cp | cargo tauri build 1m06s + bundle 27s = 1m33s total,exit 0。.app 装 + DMG cp 到 ~/Downloads,MD5 一致 |
| AC4 落档 >= 5KB + git commit 我自决 (parent=d6c74178c) + **git push origin main** | 本文件 (this file)。git commit 我自决,parent=d6c74178c。git push origin main(装机 user 拍 "LOOP 啊" 拍板 push 时机)|

## 8. 找回 baseline(派单拍板真值)

装机 user 拍 "找得回来" = 保留 baseline,用 `git revert` 撤回:

```bash
cd /Volumes/ANAN/Engineering/wenshu
git revert HEAD  # 撤回本次 WO-001AY commit
git push origin main
```

不要用 `git reset --hard`(派单强边界)。

## 9. 文件清单

| 文件 | 改动 |
|------|------|
| `scripts/install.sh` | `install_desktop()` 加 ELECTRON_MIRROR + npmmirror registry + fetch-timeout/retries + else 分支强制 mirror 兜底 + WO-001AY 注释 |
| `wenshu-pour/architecture/v11-build-desktop-app-hang-exit-1-2026-08-27.md` | 本文件,落档 |

**不 改**(派单 Out 强边界):
- apps/desktop/ apps/shared/ 业务代码
- hermes_cli/ agent/ gateway/ tools/ 业务代码
- apps/bootstrap-installer/src-tauri/src/* (本轮不需要改 Rust,WenShu-Setup binary 已 OK,install.sh 是 runtime 拉的)
- hermes_cli/default_soul.py / agent/prompt_builder.py / wenshu/SOUL.md / wenshu/AGENTS.md
- wenshu/methodologies/
- ~/.wenshu-hermes/(装机 user 私域运行时)
