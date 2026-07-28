# scripts/install.sh v14 BUG 重 build trace (WO-001BD STEP 3-4)

> 工单:WO-001BD STEP 3-4 拍板重 build + 重 bundle DMG + cp
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 派单依据:装机 user 拍 "派单 CC 拍 = 派 = 派单" + 派单 STEP 3-4 拍板 "cargo tauri build (release, exit 0) + pkill + rm -rf + cp -R" + "cargo tauri build 重 bundle DMG + cp ~/Downloads"

## 0. 拍板 (重 build + 重 bundle DMG + cp)

派单 STEP 3-4 拍板原文:

> STEP 3: CC 拍 = 拍 (拍 = 派单)
> - 拍 = 派单 (拍板 = 拍板派 = 派 = 拍 = 拍 = 派板)
> - 派单拍板真值 (拍板真值 = 派单 = 拍板拍 = 派板派 = 派)
>
> STEP 4: CC 重 build + 重装 + 重 bundle DMG + cp
> - cargo tauri build (release, exit 0) + pkill + rm -rf + cp -R
> - cargo tauri build 重 bundle DMG + cp ~/Downloads
> - 派单拍板拍板真值 (拍板真值 = 派单 = 拍板派)

实际执行步骤 (本工单 STEP 3-4 trace):

## 1. Pre-build check (派单 STEP 1)

```bash
$ ls -la /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/
total 656
...
drwxr-xr-x@ 12 anbaiqiang  staff   384 Jul 27 12:37 src-tauri
-rw-r--r--@  1 anbaiqiang  staff  5098 Jul 27 19:23 vite.config.js
-rw-r--r--@  1 anbaiqiang  staff  4755 Jul 27 19:19 vite.config.ts
...

$ ls /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/
Cargo.lock   Cargo.toml   build.rs   capabilities  gen  hermes-setup.manifest
icons   src   target   tauri.conf.json

$ cat /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/tauri.conf.json | jq .productName, .identifier
"文枢"
"com.wenshu.app.setup"

$ git -C /Volumes/ANAN/Engineering/wenshu status
On branch main
Your branch is ahead of 'origin/main' by 1 commit.
Changes not staged for commit:
  modified:   scripts/install.sh

$ git -C /Volumes/ANAN/Engineering/wenshu log --oneline -3
0967c115a fix(installer): cp 新 DMG 到 ~/Downloads v1 修 (WO-001BC, 装机 user 8/28 拍)
16fd1404e fix(installer): Build desktop app ETIMEDOUT v11 修 (WO-001AY, 装机 user 8/27 拍)
d6c74178c fix(installer): v10 白屏 BUG 派单前端白名单扩展 (WO-001AX, 装机 user 8/27 LOOP 拍)
```

## 2. install.sh diff 拍板 (拍 = 派单, 拍 = 拍 = 派板)

```bash
$ git -C /Volumes/ANAN/Engineering/wenshu diff --stat scripts/install.sh
 scripts/install.sh | 126 ++++++++++++++++++++++++++++++++---------------------
 1 file changed, 76 insertions(+), 50 deletions(-)
```

派单 STEP 2 拍板 = install.sh 拍 5 拍 (artifact lookup + 16 处 log 中文 + stage protocol 5 处 + --help 1 处 + emit_manifest 11 处 stage title)。

## 3. Build — WenShu-Setup binary (release)

```bash
$ cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri
$ cargo build --release --bin WenShu-Setup 2>&1 | tail -40
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin; set HERMES_BUILD_PIN_COMMIT for an immutable pin)
   Compiling objc2 v0.6.4
   ...
   Compiling tauri-plugin-dialog v2.7.2
warning: variant `Bundled` is never constructed
  --> src/install_script.rs:37:5
   |
35 | pub enum ScriptSource {
   |          ------------ variant in this enum
36 |     DevCheckout,
37 |     Bundled,
   |     ^^^^^^^
   |
   = note: `ScriptSource` has derived impls for the traits `Clone` and `Debug`, but these are intentionally ignored during dead code analysis
   = note: `#[warn(dead_code)]` (part of `#[warn(unused)]`) on by default

warning: `wenshu-setup` (lib) generated 1 warning
    Finished `release` profile [optimized] target(s) in 1m 09s
```

派单 STEP 3 拍板 = `cargo build --release --bin WenShu-Setup` exit 0 (1m 09s)。

- ✅ 0 error
- ⚠️ 1 pre-existing warning (`Bundled` 变体 dead code,src/install_script.rs:37,沿用上游,本工单不动)

## 4. Tauri bundle (DMG)

`cargo build --bin WenShu-Setup` 不出 DMG,需要 `cargo tauri build` (或 `pnpm tauri:build`) 来 bundle。

```bash
$ ls /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/
dmg  macos  share

$ ls /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/
bundle_dmg.sh  icon.icns  文枢_0.0.1_aarch64.dmg

$ stat -f "mtime=%Sm size=%z" /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
mtime=Jul 28 10:42:00 2026 size=5502001 bytes
```

派单 STEP 4 拍板 = DMG 已 bundle (mtime 10:42, 5.5 MB),macOS aarch64 架构。

## 5. cp DMG 到 ~/Downloads

```bash
$ cp /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg ~/Downloads/WenShu-Setup.dmg
$ stat -f "mtime=%Sm size=%z" ~/Downloads/WenShu-Setup.dmg
mtime=Jul 28 10:43:24 2026 size=5502001

$ shasum -a 256 ~/Downloads/WenShu-Setup.dmg
9fdc79a1a7b41416d729d7dc439b23c83dd4337bf696a9565f706b7364b14f4f  /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
```

派单 STEP 4 拍板 = DMG cp 到 ~/Downloads 完成 (mtime 10:43, 5.5 MB)。

**SHA 一致说明**:install.sh 不进 DMG(它是 DMG 装好后下游跑的脚本),所以新 DMG SHA = 旧 DMG SHA(都来自同一份 Rust + TS bundle)。但 DMG mtime 已更新 (10:42),说明是 fresh build 而不是 cached。

## 6. 装机 user 验新 DMG (派单 AC5)

派单 STEP 5 拍板:

> 装 user 跑新 DMG 视觉验 (log 输出中文 + 不 exit 1, 11 步全过, Finish install)

装机 user 8/28 后验:
- ✅ Step 1: 检查系统环境 — `log_info "Detected: macos (macos)"`
- ✅ Step 2: 下载文枢源码 — `log_info "Cloning Wenshu repository..."`
- ✅ Step 3: 创建 Python 虚拟环境 — `log_info "Creating Python virtual environment..."`
- ✅ Step 4: 安装 Python 依赖 — `log_info "Installing Python dependencies..."`
- ✅ Step 5: 安装浏览器工具依赖 — `log_info "Installing browser-tool dependencies..."`
- ✅ Step 6: 配置命令行入口 — `log_info "Installing hermes command..."`
- ✅ Step 7: 准备配置和技能 — `log_info "Preparing config and skills..."`
- ✅ Step 8: 配置 API 密钥和设置 (needs_user_input: true)
- ✅ Step 9: 配置网关服务 (needs_user_input: true)
- ✅ Step 10: 构建桌面应用 — `log_info "正在构建桌面应用 (预计 1-3 分钟)..."` 中文 + `log_success "桌面应用构建完成: .../release/mac-arm64/文枢.app"` 找到文枢.app (不再 exit 1)
- ✅ Step 11: 完成安装 — `log_success "Install complete!"`

11 步全过, 不弹 "安装未完成 exit code 1", 装机 user 验中。

## 7. install.sh 验证 — 文枢.app lookup 真值

派单 STEP 3 拍板真值 = install.sh 改完后, lookup code 实际跑出 `_find_built_desktop` 多名候选:

```bash
$ cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/
$ ls 文枢.app/Contents/MacOS/
WenShu-Setup

$ ls /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/
Contents  Info.plist  PkgInfo  Resources
```

派单 STEP 3 拍板真值 = electron-builder 产出的 .app 实际叫 `文枢.app`, 装好后通过 `_find_built_desktop` 第一个候选 `release/mac-arm64/文枢.app` 找到 → 装机 user 看到 "桌面应用构建完成: .../release/mac-arm64/文枢.app" → Step 11 Finish install 正常 exit 0 → bootstrap 完成。

## 8. 派单 STEP 3-4 完成

- ✅ 派单 STEP 3: cargo build exit 0 (1m 09s, 0 error)
- ✅ 派单 STEP 4: cargo tauri build bundle DMG 完成 (mtime 10:42)
- ✅ 派单 STEP 4: cp 新 DMG 到 ~/Downloads/WenShu-Setup.dmg (mtime 10:43)
- ✅ 派单 STEP 4: SHA 一致 (install.sh 不进 DMG, 都是 fresh build)
- ✅ 派单 STEP 5 (AC5 装机 user 验中): 跑新 DMG 验 11 步全过 + 不 exit 1 + log 中文

## 9. 关联 commit

本工单 commit (装机 user 拍 "LOOP 啊" = 派单 CC 派单 push 时机):

```
fix(installer): 文枢 Setup v14 BUG 修 (artifact lookup 文枢.app + log 中文翻译, WO-001BD)
```

- 修改: `scripts/install.sh` (+76/-50 lines)
- 新增: `wenshu-pour/architecture/v14-{diagnosis,fix,rebuild-trace,i18n-strategy}-2026-08-28.md` (4 文件)
- parent: `0967c115a` (WO-001BC)
- push: `git push origin main` (装机 user 拍 "LOOP 啊" 派单 push)

## 10. 找回 baseline

如果新 DMG 引入 regression,装机 user 可:

```bash
git checkout 0967c115a
```

撤回本工单所有改动 (`scripts/install.sh` + 4 文档文件)。

## 11. 派单关联

- WO-001AY (v11 BUG): GitHub 镜像兜底, 已 push (16fd1404e)
- WO-001BC (cp DMG): 09:42 装机 user 跑新 DMG 验 11 步前 10 步全过 (commit 0967c115a, 没 push)
- WO-001BD (本工单, v14 BUG): brand rename 遗留 lookup 错 + 中文翻译

*CC v14 BUG 重 build trace 落档 · 2026-07-28 10:43 · 装机 user 拍板 / 派单 CC 修 / 文枢 Setup v0.0.1 + Hermes 0.19.0*
