# ACCEPTANCE-v0.02.0-LT-04

## 范围
- 下左聊天区新增 4 子 tab：聊天（实装）、时间线、关系图、大纲（均为 disabled 占位）。
- 聊天 tab 无项目上下文时显示“先在项目里开始一次创作”；有项目时以 `NavigationStack` 承载原 v0.01.0 `ChatView`。
- `LayoutShellView` 仅在 bottomLeft 非折叠 panel slot 注入 `ChatPanelView`，几何、折叠和 splitter 逻辑保持原有路径。

## 自动验证
- `swift build`: exit 0。
- `swift test --filter LT04ChatPanelTests`: exit 0，5/5 passed。
- 完整 `swift test`: 在当前 macOS 资源受限环境中被系统 SIGKILL（exit 137，OOM）；不是 Swift 编译错误。此前全量测试编译阶段暴露了基线 `NativeSplitterView.onDrag` 签名与已有 LT-01 测试不一致，已统一为 Bool 返回并修复受影响的 LT-01Fix14/16 测试闭包。

## Smoke
- 已执行 worktree 内 `swift run WenshuApp`；进程未能在当前并发 macOS 环境稳定保持，日志无应用错误输出。建议 PM-direct 清理其它 worktree 的 Swift/xctest/CC 进程后，在本 worktree 重跑。

## 边界
- 未修改 `.ws` schema、LLM provider、`ChatView` 内部、`App.swift`、`Package.swift`。
- 未 push。
