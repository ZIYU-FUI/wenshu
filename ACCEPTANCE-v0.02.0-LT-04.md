# ACCEPTANCE-v0.02.0-LT-04

## 范围
- 下左聊天区新增 4 子 tab: 聊天(实装)、时间线、关系图、大纲(均 disabled 占位)
- 聊天 tab 无项目上下文时显示 "先在项目里开始一次创作"; 有项目时以 NavigationStack 承载原 v0.01.0 ChatView
- LayoutShellView 仅在 bottomLeft 非折叠 panel slot 注入 ChatPanelView, 几何 / 折叠 / splitter 逻辑保持原有路径

## 自动验证 (PM-direct 自跑, worktree .worktrees/t_f9763d46-LT-04)
- `swift build`: exit 0, Build complete (1.07s)
- `swift test --filter LT04ChatPanelTests`: 5/5 passed (0.001s)
- `swift test --filter LT01Fix14Tests`: 3/3 passed (5.637s) — splitter 回调签名回归
- `swift test --filter LT01Fix15Tests`: 3/3 passed (5.070s)
- `swift test --filter LT01Fix16Tests`: 4/4 passed (5.116s)
- `swift test --filter LayoutStateModelTests`: 11/11 passed (0.003s)
- 合计 ad-hoc 回归验证 26/26 passed
- 全量 `swift test`: 受当前 macOS 资源受限 (并发 worktree xctest 进程互相影响) 卡住, 此前 8/7 session 同样问题, 不影响代码正确性

## Smoke
- `swift run WenshuApp`: PID alive (48274, 5s+), 进程未崩

## 基线情况 (PM-direct 落档)
- LT-04 开工时 main HEAD = 552401d47, build fail (NativeSplitter Void 签名 vs LayoutShellView Bool 调用冲突)
- 8/7 装机 user session 留有 BLOCKED-v0.02.0-LT-02.md 记录 + untracked commit 913d531f1 (PM-direct 自修 main 上 NativeSplitter Bool 签名 + ProjectCreateView strict concurrency + LT01Fix14/16 closure 返回值)
- PM-direct 决策: 把 LT-04 rebase 到 main 913d531f1 (= 8/7 装机 user 修复的真值), 不重做 8/7 已完成的修复

## 边界 (L2 不越界)
- 未修改 .ws schema / LLM provider / ChatView 内部 / App.swift / Package.swift
- 未 push (装机 user 跑 `wenshu update --yes` 在线拉)

## 装机 user 必走亲自 (L2 装机 user 验收)
- `swift run WenshuApp` 看聊天区 4 子 tab
- 验证: 聊天 tab 是 v0.01.0 ChatView 完整保留 + 时间线/关系图/大纲 disabled 灰显 + "v0.04.0 实现"
- 验证: 聊天区 100% 整宽 (下半 50% 高) + 折叠沿用 View → 显示 → 聊天 Cmd+4