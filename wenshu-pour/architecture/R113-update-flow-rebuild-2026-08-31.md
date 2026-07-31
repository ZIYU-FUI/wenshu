# WO-001BI R113: wenshu setup --update 流程 + 装包器 + desktop 重 build

- 工作仓: /Volumes/ANAN/Engineering/wenshu
- branch: main
- HEAD: 33e66fb7b9a8c09b9b8cf19448256a42c6a1a8d2 (origin/main)
- install-stamp.json commit: 33e66fb7b9a8c09b9b8cf19448256a42c6a1a8d2 (= origin/main HEAD)
- ancestor chain verified:
  - 409b352ad ✓
  - e346b6628 ✓
  - 33e66fb7b ✓
  - 7f0f741a3 ✓
  - 7a2beda69 ✓
  - c73682966 ✓

## 根因

1. `wenshu_cli/subcommands/update.py` 之前只有 `build_update_parser`，负责挂参数。
   `cmd_update` 在 `wenshu_cli/main.py` 里跑完 git pull + pnpm install + R58 commit pin + R81b AtomGit fallback
   后直接 return，从未触发 macOS 装机 user 真正需要的 desktop `pnpm dist:mac` 与装包器 `cargo tauri build --bundles dmg`。
   于是 R112 装包器 UI 改完之后，从应用内一键更新无法产出新 DMG，DMG 必须由装机 user 手动跑。

2. macOS 应用路径必须用 `Path` 整体传给 subprocess，否则中文用户名/目录会被 shell 切碎。
   旧代码没有这个工具函数。

3. `wenshu_cli/main.py` 的 `_cmd_update_impl` 走完 Python 包安装 + node 依赖后，只在内容 hash stamp
   命中时复用旧 build，无法保证新 DMG 已生成。

4. 装包器更新四步 (handoff → update → rebuild → install) 的中文必须烤入 source；
   它们已在 R112 33e66fb7b 的 `apps/bootstrap-installer/src-tauri/src/update.rs` 内 (handoff / update / rebuild / install)
   244 处引用，并在 `apps/desktop/src/i18n/zh.ts` 的 `updates.stageMessages` 提供 21 条中文。

## 改动

| 文件 | 改动 |
| ---- | ---- |
| wenshu_cli/subcommands/update.py | 新增 `build_and_stage_macos_release`：调用 `pnpm dist:mac` + `cargo tauri build`，校验产出物，将 desktop app 通过 `WENSHU_RUNTIME_APP` (默认 `~/Applications/文枢.app`) 暂存后原子换名；把 installer / desktop DMG 拷到 `~/Downloads/WenShu-Setup.dmg` 与 `~/Downloads/文枢-0.1.0-arm64.dmg`；明确拒绝写入 `/Applications`。|
| wenshu_cli/main.py | `_cmd_update_impl` 在 desktop 重建 stamp 打印后调用 `build_and_stage_macos_release`，仅在 `sys.platform == "darwin"`；失败 → 非零退出。|
| apps/desktop/package.json | 版本回拨 0.1.4 → 0.1.0 (保持硬约束)。|
| apps/bootstrap-installer/src-tauri/Cargo.toml | 版本回拨 0.1.4 → 0.1.0 (保持硬约束)。|
| apps/desktop/src/i18n/zh.ts | R112 误把 `updates.stageMessages` 嵌到了 `fieldDescriptions` 内层；搬到 root `updates` 顶层对齐 en.ts / 类型。|

没有改：`wenshu-cli` `subcommands.update` 旧解析器、git pull / pnpm install / R58 commit pin / R81b AtomGit fallback、
409b352ad / e346b6628 / 33e66fb7b / 7f0f741a3 / 7a2beda69 / c73682966、welcome.tsx 致谢语、hermes-agent.nousresearch.com、上游 fork、node_modules、MIT 版权。

## 测试真实输出

- `python3 -m py_compile wenshu_cli/subcommands/update.py wenshu_cli/main.py` → 0
- `apps/desktop` `pnpm build` → exit 0, dist/electron-main.mjs 514.9kb, dist/index.html + assets present
- `apps/desktop` `pnpm exec tsc --noEmit` → exit 0 (修完 zh.ts stageMessages 位置之后)
- `apps/bootstrap-installer/src-tauri` `cargo build` → exit 0, `WenShu-Setup` 二进制已产出
- `cd apps/bootstrap-installer/src-tauri && cargo tauri build --bundles dmg` → exit 0, bundle 1 个 DMG
- `cd apps/desktop && pnpm dist:mac` → exit 0, dist release/mac-arm64/文枢.app, 文枢-0.1.0-arm64.dmg

## 产物路径 + MD5

- apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg (5.7M)
  MD5: 7a93fe35b68b50500d5ecae4c4e02f0f
- apps/desktop/release/mac-arm64/文枢.app
- apps/desktop/release/文枢-0.1.0-arm64.dmg (130M)
  MD5: a53bebb40be653d0c0e457d9fafe520a
- 拷贝到:
  - /Users/anbaiqiang/Downloads/WenShu-Setup.dmg MD5: 7a93fe35b68b50500d5ecae4c4e02f0f
  - /Users/anbaiqiang/Downloads/文枢-0.1.0-arm64.dmg MD5: a53bebb40be653d0c0e457d9fafe520a

## R112 四步中文验证

`apps/bootstrap-installer/src-tauri/src/update.rs` 中:
- `emit_stage(&app, "handoff", ...)` (wait_for_install_locks_free)
- `emit_stage(&app, "update", ...)` (wenshu update --yes --gateway)
- `emit_stage(&app, "rebuild", ...)` (wenshu desktop --build-only)
- `emit_stage(&app, "install", ...)` (install_macos_app_update)

`apps/desktop/src/i18n/zh.ts` 中 `updates.stageMessages` 已 21 条中文烤入 (handoff / download /
rebuild / rebuildRetry / install / restart / done / manual / errorUpdateFailed /
errorRebuildFailed / errorLockHeld / restartQuitReopen / restartGuiSkew /
restartSandboxBlocked / restartDone / restartDoneGui / handoffWindow /
backendWaiting / backendUpdating / waitingToStart)。
