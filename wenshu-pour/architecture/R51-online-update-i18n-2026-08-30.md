# R51 在线更新 i18n 与实时输出中文化

- 工单：WO-001BI-R51
- 落档日期：2026-08-30
- 基线 HEAD（改动尚未 commit）：`25a747642b7bfbaf44d6aefcb177d70d5301197b`

## 改动文件

- `apps/desktop/src/i18n/zh.ts`：补齐在线更新阶段和用户提示的中文文案。
- `apps/desktop/src/i18n/en.ts`：镜像新增 key，保留英文原文语义。
- `apps/desktop/src/i18n/types.ts`：声明更新页顶层 `message` / `stallHint`。
- `apps/desktop/electron/main.ts`：`emitUpdateProgress` 输出 zh-CN 阶段提示及 en 原文。

## 新增 i18n key

zh/en 的 `updates.stages` 均新增：`download`、`install`、`complete`；同时新增顶层：`updates.message`、`updates.stallHint`。

阶段文案同步调整：`update`、`rebuild`。原有 `done` 保留。

## Electron zhMap

`update`、`download`、`rebuild`、`restart`、`install`、`complete`、`manual`、`error`。

每个已映射阶段打印：`[updates] zh-CN: 中文提示（en: 原始 message 或 stage）`。
