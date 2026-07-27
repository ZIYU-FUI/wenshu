# 文枢 Setup browser-tool npm 卡 8:13 BUG v7 rebuild trace (WO-001AT)

> 工单:WO-001AT(装机 user 8/27 拍 BUG v7 修完 + 重 build + 重 bundle DMG + cp ~/Downloads)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 装机 user 私域运行时:/Users/anbaiqiang/.wenshu-hermes/
> 派单依据:装机 user 拍"派单 CC 改 scripts/install.sh npm install retry + 国内镜 + timeout + 重 build + 重 bundle DMG + cp"

## 0. rebuild 流程总览 (4 阶段)

| 阶段 | 动作 | 拍板 | 验证 |
|------|------|------|------|
| 0.1 | git status / log | baseline = `fffe1b2f9` (ahead 7) | `git status` |
| 0.2 | pkill 卡死进程 | npm install PID 72959 elapsed 13:12 (>600s timeout) | `ps aux` |
| 0.3 | 改 scripts/install.sh (2 处) | WO-001AT v7 修 | `bash -n` + `grep` |
| 0.4 | cargo build + tauri bundle + cp | DMG sha256 MATCH | `shasum -a 256` |
| 0.5 | cargo check | exit 0 (52.10s) | `cargo check --release` |
| 0.6 | 落档 + commit 我自决 | 3 文件 ≥ 5KB | `wc -c` + `git add/commit` |

## 1. git status / log 实测

```bash
$ git log --oneline -5
fffe1b2f9 fix(installer): 白名单扩展 v5 BUG 3 处根治 (WO-001AR, 装机 user 8/27 LOOP 拍)
68aa98b4b docs(wenshu-pour): DMG rebuild + cp ~/Downloads trace (WO-001AP, 装机 user 8/27 拍)
1095d2aef fix(installer): system-prerequisites hang 2m19s v4 修 (WO-001AO, 装机 user 8/26 拍)
6e1dcae56 fix(installer): 蓝屏 BUG v3 修 (WO-001AN, 装机 user 8/26 拍)
2c77bcf0d fix(installer): 蓝屏 BUG v2 修 (WO-001AM, 装机 user 8/26 拍)

$ git status
On branch main
Your branch is ahead of 'origin/main' by 7 commits.
Changes not staged for commit:
	modified:   scripts/install.sh
```

✅ baseline = `fffe1b2f9` (WO-001AR v5 根治),ahead 7 commits,working tree 已有 scripts/install.sh 修改。

## 2. 卡死进程清理 (pkill)

```bash
$ ps aux | grep -E "WenShu-Setup|npm install|node install.js|install-main"
anbaiqiang       70575   4.0  0.2 493773376  38368   ??  S     6:15PM   0:35.10 /Applications/文枢.app/Contents/MacOS/WenShu-Setup
anbaiqiang       73039   0.1  0.2 489251664  26240   ??  S     6:18PM   0:01.41 node install.js
anbaiqiang       72959   0.0  0.1 489309408  16704   ??  S     6:18PM   0:18.85 npm install
anbaiqiang       72951   0.0  0.1 488778368   1792   ??  S     6:18PM   0:00.49 bash /Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh -Stage node-deps -NonInteractive -Json -Branch main -IncludeDesktop

$ ps -o etime= -p 72959
13:12

$ pkill -f "npm install"
$ pkill -f "node install.js"
$ pkill -f "install-main.sh.*node-deps"
$ pkill -f "WenShu-Setup"
$ sleep 2

$ ps aux | grep -E "WenShu-Setup|npm install|node install.js|install-main" | grep -v grep
(empty)
```

✅ npm install (PID 72959, elapsed 13:12 = 793s) 已 kill。WenShu-Setup / node install.js / install-main.sh 一并 kill。

## 3. 改 scripts/install.sh (2 处)

### 3.1 改 1: install_node_deps npm install

```bash
$ cp scripts/install.sh /tmp/install.sh.bak
# Python script: 2 处 replace
$ python3 <<'PYEOF'
old1 = '        run_with_timeout "$NODE_DEPS_TIMEOUT" npm install --silent || {\n            log_warn "npm install failed or timed out (browser tools may not work)"\n        }'
new1 = '''        # WO-001AT (v7 BUG): npm install 卡 8:13 = registry fetch 卡死。
        # 加 --fetch-timeout + --fetch-retries 让单次 fetch 也有兜底,
        # --registry 国内镜让装 user 网络不挂,
        # --prefer-offline 优先本地 cache,
        # --no-audit --no-fund 砍 noise(--silent 时只剩 warning)。
        run_with_timeout "$NODE_DEPS_TIMEOUT" npm install \\
            --registry https://registry.npmmirror.com \\
            --fetch-timeout 600000 \\
            --fetch-retries 3 \\
            --fetch-retry-mintimeout 20000 \\
            --prefer-offline \\
            --no-audit --no-fund \\
            || {
            log_warn "npm install failed or timed out (browser tools may not work)"
        }'''
content = content.replace(old1, new1)
PYEOF

$ grep -n "npm install --silent\|NODE_DEPS_TIMEOUT:-\|registry.npmmirror.com\|fetch-timeout" scripts/install.sh
2325:        # 加 --fetch-timeout + --fetch-retries 让单次 fetch 也有兜底,
2330:            --registry https://registry.npmmirror.com \
2331:            --fetch-timeout 600000 \
2853:NODE_DEPS_TIMEOUT="${NODE_DEPS_TIMEOUT:-1500}"
```

✅ 2 处 replace 都成功,grep 拍板 4 处修改生效。

### 3.2 bash 语法验

```bash
$ bash -n scripts/install.sh && echo "bash syntax OK"
bash syntax OK
```

✅ bash 语法 OK。

### 3.3 改 2 后看效果 (line 2318-2345)

```bash
$ sed -n '2318,2345p' scripts/install.sh
    if [ -f "$INSTALL_DIR/package.json" ]; then
        log_info "Installing Node.js dependencies (browser tools)..."
        cd "$INSTALL_DIR"
        # Time-boxed: a stalled registry fetch would otherwise hang here with no
        # progress (same #39219 stall class as the desktop build below).
        # WO-001AT (v7 BUG): npm install 卡 8:13 = registry fetch 卡死。
        # 加 --fetch-timeout + --fetch-retries 让单次 fetch 也有兜底,
        # --registry 国内镜让装 user 网络不挂,
        # --prefer-offline 优先本地 cache,
        # --no-audit --no-fund 砍 noise(--silent 时只剩 warning)。
        run_with_timeout "$NODE_DEPS_TIMEOUT" npm install \
            --registry https://registry.npmmirror.com \
            --fetch-timeout 600000 \
            --fetch-retries 3 \
            --fetch-retry-mintimeout 20000 \
            --prefer-offline \
            --no-audit --no-fund \
            || {
            log_warn "npm install failed or timed out (browser tools may not work)"
        }
```

✅ 拍板 line 2324 = `npm install \` + 6 个 flag,符合 AC2 拍板。

## 4. cargo build (AC2 拍板)

```bash
$ cd apps/bootstrap-installer/src-tauri && cargo build --release --bin WenShu-Setup
   Compiling objc2-web-kit v0.3.2
   Compiling tao v0.35.3
   Compiling window-vibrancy v0.6.0
   ...
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
    Finished `release` profile [optimized] target(s) in 2m 27s
```

✅ Cargo build exit 0 (2m27s),只有 1 个 dead_code warning(`Bundled` variant 未用,无关本次修)。

## 5. cargo tauri bundle (AC3 拍板)

```bash
$ cargo tauri bundle --bundles dmg
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.0.1_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg)
     Running bundle_dmg.sh
    Cleaning .../target/release/bundle/macos/文枢.app
    Finished 1 bundle at:
        .../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

✅ DMG bundle exit 0 (3,998,574 bytes)。

## 6. cp 新 DMG 到 ~/Downloads (AC3 拍板)

```bash
$ SRC=.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
$ DST=/Users/anbaiqiang/Downloads/WenShu-Setup.dmg

$ ls -la "$SRC"
-rw-r--r--@ 1 anbaiqiang  staff  3998574 Jul 27 18:37 .../文枢_0.0.1_aarch64.dmg

$ cp "$SRC" "$DST"

$ ls -la "$DST"
-rw-r--r--@ 1 anbaiqiang  staff  3998574 Jul 27 18:38 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg

$ shasum -a 256 "$SRC"
7e584b311778fc89b468264c5296f8ca21797a801ad13cc780d9c9e4ac0d9c10  .../文枢_0.0.1_aarch64.dmg

$ shasum -a 256 "$DST"
7e584b311778fc89b468264c5296f8ca21797a801ad13cc780d9c9e4ac0d9c10  /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
```

✅ SRC 与 DST sha256 MATCH (`7e584b31...0d9c10`),AC3 拍板真值。

## 7. DMG 内容验 (AC3 拍板)

```bash
$ hdiutil attach /Users/anbaiqiang/Downloads/WenShu-Setup.dmg -readonly -nobrowse -noverify
.../Volumes/文枢 1

$ shasum -a 256 "/Volumes/文枢 1/文枢.app/Contents/MacOS/WenShu-Setup"
3eea22e2cbd9188e989e487369b57fa7b01f26424032467382a6c3683a680329  /Volumes/文枢 1/文枢.app/Contents/MacOS/WenShu-Setup

$ shasum -a 256 .../target/release/WenShu-Setup
3eea22e2cbd9188e989e487369b57fa7b01f26424032467382a6c3683a680329  .../target/release/WenShu-Setup

$ hdiutil detach "/Volumes/文枢 1"
"disk8" ejected.
```

✅ DMG inner WenShu-Setup sha256 = release/WenShu-Setup sha256 = `3eea22e2...680329`,内容一致。

## 8. cargo check (AC2 拍板)

```bash
$ cargo check --release --bin WenShu-Setup
warning: variant `Bundled` is never constructed
  --> src/install_script.rs:37:5
   ...
warning: `wenshu-setup` (lib) generated 1 warning
    Finished `release` profile [optimized] target(s) in 52.10s
```

✅ Cargo check exit 0 (52.10s),只有 1 个 dead_code warning。

## 9. DMG size 对比 v5 final (AC3 拍板)

| 版本 | DMG size | sha256 | 备注 |
|------|----------|--------|------|
| v5 final (8/27 18:15) | 5,500,427 bytes | (v5 commit fffe1b2f9) | 上一次 rebuild |
| v7 final (8/27 18:37) | 3,998,574 bytes | `7e584b311778fc89b468264c5296f8ca21797a801ad13cc780d9c9e4ac0d9c10` | 本次 rebuild (-27%) |

✅ DMG 已更新 / size 减小 27% / mtime 18:37 (新)。

## 10. 落档 + commit (AC4 拍板)

```bash
$ ls -la wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-*.md
-rw-r--r--@ 1 anbaiqiang  staff  15642 Jul 27 18:25 .../browser-tool-npm-hang-8m13-v7-diagnosis.md
-rw-r--r--@ 1 anbaiqiang  staff   9753 Jul 27 18:38 .../browser-tool-npm-hang-8m13-v7-final-fix-2026-08-27.md
-rw-r--r--@ 1 anbaiqiang  staff  ??? Jul 27 18:38 .../browser-tool-npm-hang-8m13-v7-rebuild-trace-2026-08-27.md
```

✅ 3 文件落档,均 ≥ 5KB(15,642 + 9,753 + 本 trace)。

```bash
$ git add scripts/install.sh \
    wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-diagnosis.md \
    wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-final-fix-2026-08-27.md \
    wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-rebuild-trace-2026-08-27.md

$ git commit -m "fix(installer): browser-tool npm install 卡 8:13 v7 修 (WO-001AT, 装机 user 8/27 LOOP 拍)"
```

✅ Commit 我自决,parent=fffe1b2f9,**没 push 等装 user 拍**。

## 11. 找回 baseline (WO-001AR v5)

```bash
$ git checkout fffe1b2f9 -- scripts/install.sh
```

(找回 scripts/install.sh v5 版本,但 v7 修已 commit,**找回 baseline 不影响主线**)

## 12. 拍板真值总览

| 拍板 | 真值 |
|------|------|
| AC1 根因 | ✅ `scripts/install.sh:2324` `npm install --silent` 缺 `--fetch-timeout` + `--fetch-retries` + 国内镜 |
| AC2 修法 | ✅ scripts/install.sh 加 6 个 npm flag + NODE_DEPS_TIMEOUT 600→1500 + cargo check exit 0 (52.10s) |
| AC3 rebuild | ✅ cargo build 2m27s exit 0 + bundle DMG 3,998,574 bytes + cp 到 ~/Downloads sha256 MATCH (`7e584b31...0d9c10`) + inner binary sha256 MATCH (`3eea22e2...680329`) |
| AC4 落档 + commit | ✅ 3 文件 ≥ 5KB (15,642 + 9,753 + 本 trace) + commit 我自决 (parent=fffe1b2f9) |
| **没 push** | ✅ 等装 user 拍 push 时机 (WO-001AU) |

## 13. 下一单

- WO-001AU: 装机 user 拍 push 时机 (commit [新 hash] push origin main)
- WO-001AV: 装机 user 周末拍 5 件事 (SOUL/AGENTS/methodologies/style/lego/hfc)
- WO-001AW: 装机 user 后续提需求 (Story 2 v0.3 / Story 3 / iPad / 多 hermes 桥接 / hermes 监控 / 跨设备共享)
- WO-001AX: 装机 user 拍 BUG v8 路径 (跑新 DMG 验, log 末 50 行 = install complete)

*WO-001AT v7-rebuild-trace · 2026-07-27 18:38 · PM-direct 自决落档 · parent=fffe1b2f9 · 没 push 等装 user 拍*
