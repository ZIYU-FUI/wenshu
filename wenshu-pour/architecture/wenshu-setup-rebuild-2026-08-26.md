# 文枢 Setup 重建与装机 trace

> WO-001AJ STEP 2；实际执行日期：2026-07-27（机器当前日期），任务要求文件名保留 2026-08-26。

## 执行器与目录

- 仓库：`/Volumes/ANAN/Engineering/wenshu`
- 构建目录：`apps/bootstrap-installer/src-tauri`
- 构建命令：`cargo tauri build`
- Cargo：终端实测由 Cargo 完成，构建目标为 Tauri 2 installer
- 产物：`apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app`
- 安装目标：`/Applications/文枢.app`

本次没有使用 `claude --bare` 作为文枢/hermes 派单器；构建命令由真实 Claude Code 工具会话直接执行，命令 stdout/stderr 被保留在后台任务输出中。

## 构建过程真值

启动命令：

```text
cd apps/bootstrap-installer/src-tauri && cargo tauri build
```

构建实际经过：

1. Tauri 检查已安装 package；
2. `npm run build`；
3. TypeScript/Vite 生产构建，Vite 报 1 个 CSS 优化 warning，但成功完成：`1881 modules transformed`、`✓ built in 18.84s`；
4. Rust release 编译 `wenshu-setup v0.0.1`；
5. Rust release 编译总时长：`Finished release profile [optimized] ... in 1m 58s`；
6. Tauri bundle 成功生成 app 与 DMG。

最终构建输出原文摘要：

```text
Built application at: .../target/release/WenShu-Setup
Finished 2 bundles at:
.../target/release/bundle/macos/文枢.app
.../target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

仅有 warning：CSS 中 `-moz-tab-size` 优化提示；Rust `ScriptSource::Bundled` 未构造 warning；没有 build error，退出码为 0。

## 安装操作

按派单白名单执行：

```bash
pkill -f WenShu-Setup || true
rm -rf /Applications/文枢.app/
cp -R apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app /Applications/文枢.app
```

没有使用 `git reset --hard`，没有操作 `~/.wenshu-hermes/`、`~/.hermes/` 或其他客户数据目录。

## 安装后验收

构建产物 binary：

```text
7673776 bytes
Jul 27 09:54:20 2026
apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app/Contents/MacOS/WenShu-Setup
```

安装目标 binary：

```text
7673776 bytes
Jul 27 09:55:00 2026
/Applications/文枢.app/Contents/MacOS/WenShu-Setup
```

两者 size 相同；安装目标 mtime 明显晚于旧值 `Jul 24 16:29:36 2026`，满足“新 binary 已复制到 /Applications”的 mtime 验收。

## 关联状态

- `cargo tauri build`：通过，exit code 0。
- 新 `.app`：已生成。
- `/Applications/文枢.app`：已替换安装。
- Git：构建 target 受 `apps/bootstrap-installer/.gitignore` 忽略；本次 trace 与其他落档文件待 STEP 4 一并 commit。
- Push：未执行，遵守装机 user 周末拍 push 时机约束。
