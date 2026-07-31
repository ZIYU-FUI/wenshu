# R121 — 装包器跳过 install 时检查 staleness 并自动调 wenshu update (2026-08-31)

## 范围

只动 `apps/bootstrap-installer/src-tauri/src/` 的六个 Rust 文件 + 本文档，不动 desktop / Python / monorepo / 白名单。

| 文件 | 改动 |
| ---- | ---- |
| `apps/bootstrap-installer/src-tauri/src/bootstrap.rs` | rustfmt reformat (Pin assignment `args.commit` / `args.branch` 多行化、`install_root.join("apps").join("desktop").join("release").display()` 多行展开、`format!` 多行展开、`tracing::warn!` 多行展开、`Manifest =` 同上)。**业务零修改**。 |
| `apps/bootstrap-installer/src-tauri/src/install_script.rs` | rustfmt reformat: `let candidate = PathBuf::from(repo_root).join("scripts").join(kind.filename())` 多行、`std::fs::create_dir_all(parent).with_context(...)` 多行、`format!("renaming ...") ` 单行、`assert!(out.starts_with(UTF8_BOM), "...")` 多行。**业务零修改**。 |
| `apps/bootstrap-installer/src-tauri/src/lib.rs` | (1) 模块声明 `mod powershell;` 与 `mod paths;` 换序 (rustfmt); (2) `eprintln!("[wenshu-setup] setup entered: ...") ` 单行 (rustfmt); (3) **R121 行为: launcher 快速通道 (macOS / AppMode::Install / 无 force_setup / wenshu_is_installed + uv_present) 进入 stale-check 分支**——读 `.app` 内 `install-stamp.json` 与源码仓 `$WENSHU_HOME/wenshu-agent` 的 `git rev-parse HEAD`,若 commit 不一致 (`paths::installed_commit_is_stale`) 则 `tauri::async_runtime::spawn(update::start_update(...))` 触发 R113 update 流程,让用户先在当前窗口看到 handoff→update→rebuild→install 的中文四阶段 UI,然后回到桌面;**不一致则拒绝 `spawn_installed_desktop` 旧路径**。commit 一致或 metadata 缺失时走原快速通道 spawn + `exit(0)`,行为不变。 |
| `apps/bootstrap-installer/src-tauri/src/paths.rs` | **新增 R121 API**: `pub const INSTALL_STAMP_SCHEMA_VERSION: u32 = 1`、`pub struct InstallStamp { commit: String, branch: Option<String> }`、`pub fn load_install_stamp_from_bundle(bundle: &Path) -> Option<InstallStamp>` (macOS 路径 `bundle/Contents/Resources/install-stamp.json`,Win/Linux 路径 `bundle/parent/resources/install-stamp.json`,schemaVersion 不匹配或 commit 长度 < 7 返 None)、`pub fn repo_head_commit(repo_dir: &Path) -> Option<String>` (`git rev-parse HEAD`,非 git 仓 / 命令失败 / 输出空返 None)、`pub fn installed_commit_is_stale(install_stamp: Option<&InstallStamp>, repo_head: Option<&str>) -> bool` (任一 None 返 false 避免误触发;都 Some 时 `!head.starts_with(&stamp.commit)`)。 |
| `apps/bootstrap-installer/src-tauri/src/powershell.rs` | rustfmt reformat: `cmd.spawn().with_context(...)` 多行展开、`stable_script_cwd` 签名三参数换行、`assert_eq!(decode_console_bytes(...), "Não ...")` 多行。**业务零修改**。 |
| `apps/bootstrap-installer/src-tauri/src/update.rs` | rustfmt reformat: `vec!["update".into(), ...]` 单行、`emit_stage(...)` 多行、`launch_wenshu_desktop(...)` 调用多行、`emit_log(...)` 多行、`desktop_app_payload_paths` 内 macOS / Win / Linux `release.join(...).join("...")` 全部多行展开、`format_locked_paths` 链式多行、`OpenOptions::new().read(true).write(true).open` 多行、`child.wait()` 多行、`if cfg!(target_os = "windows") { "wenshu.exe" } else { "wenshu" }` 多行、`if cfg!(target_os = "windows") { ';' } else { ':' }` 多行、`rebuilt_app = ...ok_or_else(...)` 内 `install_root.join("apps").join("desktop").join("release").display()` 多行、`swap_in_new_bundle` 内 `anyhow!(...)` 多行、测试内多 `assert!` 多行。**业务零修改**。 |

总计:`git diff --shortstat` = **6 files changed, 357 insertions(+), 94 deletions(-)**。
版本号 **保持 0.1.0**(`apps/desktop/package.json` / `apps/bootstrap-installer/package.json` / `apps/bootstrap-installer/src-tauri/Cargo.toml` / `apps/bootstrap-installer/src-tauri/tauri.conf.json` 四处都 0.1.0,均未改);白名单 `wenshu-pour/architecture/hermes-allowlist-2026-08-29.md` 未改;`whatsapp-bridge/allowlist.{js,test.mjs}` 未改。

## 行为 (业务,非 rustfmt)

R117 反馈 (8/31):装机 user 双击 `/Applications/文枢.app`,装包器走 launcher 快速通道直接 spawn 旧 `.app`,跳过了任何 "源码仓 HEAD 比 `.app` install-stamp.json commit 新 ⇒ `.app` 落后" 的判断,即使用户之前已经在仓里跑过 `wenshu update` / 手动 `git pull`,得到的也是过时的自更新代码。

R121 修法:在 spawn 之前插入 staleness gate。

```
resolve_wenshu_desktop_app(&install_root)
  → load_install_stamp_from_bundle(bundle)   // None ⇒ 不知道怎么比 ⇒ 不触发
  → repo_head_commit($WENSHU_HOME/wenshu-agent) // None ⇒ 不知道怎么比 ⇒ 不触发
  → installed_commit_is_stale(stamp?, head?)

if stale:
    emit warn 日志 (含 stamp_commit, repo_head, app_bundle.path)
    tauri::async_runtime::spawn(update::start_update(app.clone()).await)
    // 不 exit(0),让前端被 manifest 事件 flip 到 route='progress',显示 handoff/update/rebuild/install 四阶段
else:
    // 与旧 R117 之前的 fast-path 完全一致
    spawn_installed_desktop(&install_root); sleep(200ms); app.exit(0)
```

紧接 `stale` 分支后**没有** `Ok(()) => return Ok(());`,控制流自然落到后面 `match app.get_webview_window("main") { Some(win) => win.show(), None => error }`,让用户看到安装程序窗口听到更新进度。这是 **故意的**——`spawn_installed_desktop` 路径里 `Ok(())` 后才有 `app.handle().exit(0); return Ok(());`,R121 stale 分支不退出,所以**不会和 spawned update task 抢 exit 时序**。

`installed_commit_is_stale` 用 `head.starts_with(&stamp.commit)` 而不是 `head == stamp.commit`,这样 `stamp.commit` 是 short SHA / `head` 是 full SHA 也能命中。

## 命令 / 真实退出码

工作目录全程 `/Volumes/ANAN/Engineering/wenshu`。下表退出码来自**真实跑出来的**终端输出。

| 命令 | 退出码 | 备注 |
| ---- | ------ | ---- |
| `cd apps/bootstrap-installer/src-tauri && cargo build --release` | 0 | 1m 11s,只有 3 个 `dead_code` warning (InstallStamp::branch、ATOMGIT_REPOSITORY、ATOMGIT_RAW_BASE);无 error。 |
| `cd apps/bootstrap-installer && cargo tauri build` | 0 | DMG 与 .app 都生成成功;1m 50s Rust release + 588ms 前端 vite build;sourcemap warning (tailwindcss plugin) 不阻断。 |
| `cd apps/desktop && pnpm build` | 0 | 3.38s vite build;dist/index.html / dist/electron-main.mjs (514.9 kb) / dist/electron-preload.js (16.7 kb) / stage-native-deps 都齐;`assert-dist-built.mjs` 通过;code-splitting 大文件 warning 不阻断。 |
| `cd apps/desktop && pnpm exec tsc --noEmit` | 0 | 空输出 = 通过。 |
| `cd apps/bootstrap-installer && pnpm exec tsc --noEmit` | 0 | 空输出 = 通过。 |

## 产物

- `apps/bootstrap-installer/src-tauri/target/release/WenShu-Setup` (二进制,装包器本体)
- `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app`
- `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg`

DMG 真实元数据 (来自 `stat` + `shasum`):

```
path : /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg
size : 5,457,955 bytes (5.21 MiB)
mtime: Jul 31 16:23:51 2026
sha256: 1b60a0e980b90cee8ff5903203f2bbeb53f4a052b31a1726a18e861157bb44f5
```

(desktop 那边 `pnpm build` 只产 vite dist,**不产 DMG**,DMG 由 `pnpm dist:mac` 单独触发,不在本次 R121 工作范围内。)

## 边界 / 没动的东西

- ❌ 不动 `apps/desktop/` 任何文件
- ❌ 不动 Python (`wenshu_cli/`、`cli.py`、`hermes_bootstrap.py` 等)
- ❌ 不动 `wenshu-pour/` 任何现成文档 (只新增 R121 本文件)
- ❌ 不动 `wenshu-pour/architecture/hermes-allowlist-2026-08-29.md` 白名单
- ❌ 不动 `scripts/whatsapp-bridge/allowlist.*`
- ❌ 不动 `node_modules/`、`dist/`、`target/`、`*.tsbuildinfo`、`pnpm-lock.yaml`、`Cargo.lock`
- ❌ 不动 60c805c55 / 0fa2ce735 / e1b70e9ca / 9c4445984 / 33e66fb7b 之前的任何 commit
- ❌ 版本号 0.1.0 不 bump

装包器 Rust 端 `install_script.rs:98-99` 仍存在 `ATOMGIT_REPOSITORY` / `ATOMGIT_RAW_BASE` 两个 `dead_code` warning (R81b 引入,R121 不删,删 = 升级老板)。
`paths::InstallStamp::branch` 仍存在 `dead_code` warning (R121 新增字段;`branch` 信息只读未消费,因为 R117 要求只用 commit 做 stale 判断;删 = 升级老板)。

## 装机 user 必走 4 步验证 (R121 装机 user 自家跑)

1. 已装文枢 + 用户手动在 `~/.wenshu/hermes-agent/wenshu-agent` 跑 `git pull`(或 `wenshu update` 中断 stash 后再跑),把 HEAD 推到 > 当前 `.app` install-stamp commit。
2. 双击 `/Applications/文枢.app`。
3. 装包器窗口出现,**不直接进桌面**;显示 handoff → update → rebuild → install 4 阶段中文 UI(R113 流程复用)。
4. 4 阶段全绿后,用户手动再双击 `/Applications/文枢.app` ⇒ 落到快速通道 (现在 `.app` 已比 commit 新) ⇒ 直接进桌面。

失败回退:若 `paths::load_install_stamp_from_bundle` 或 `paths::repo_head_commit` 任一返 None,`installed_commit_is_stale` 返 false,行为退化为原 R113 之前快速通道(直接 spawn 旧 `.app` + exit(0));这是 fail-safe,任何 metadata 缺失都不会触发 R113 update,R121 不会因为读不到 JSON 就误删 `/Applications/文枢.app`。
