# R59: desktop node-pty prebuilds 排除 asar

日期：2026-08-30  
工单：WO-001BI-R59

## 问题

打包后的 Electron 应用尝试对 `app.asar/dist/node_modules/node-pty/prebuilds/darwin-arm64/spawn-helper` 执行 chmod，因 ASAR 路径不是普通目录而报 ENOTDIR。

## 决策

采用修法 A：在 Electron Builder 的 `build.asarUnpack` 数组中加入 `**/node_modules/node-pty/**`。该规则让 node-pty 的 prebuild 与 spawn-helper 保留为 app.asar.unpacked 下的实际文件，避免运行时把 ASAR 内路径当作可 chmod 的普通文件。现有 `**/prebuilds/**` 规则保留，并补充 node-pty 专用匹配。

## 改动

- `apps/desktop/package.json`：`build.asarUnpack` 新增 `**/node_modules/node-pty/**`。

## 官方依据

- Electron Builder configuration: https://www.electron.build/configuration/configuration#asarUnpack
- Electron Builder ASAR archives: https://www.electron.build/asar-archives

## 验证

待执行：`pnpm build`、`pnpm dist:mac`。
