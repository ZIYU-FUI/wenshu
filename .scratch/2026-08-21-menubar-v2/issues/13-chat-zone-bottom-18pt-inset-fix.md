# 13 — chat zone 底栏 18PT 横 inset 修真因

依赖: 无

**What to build:**
chat zone 底栏 18PT 横 inset 修真因 (老板 2026-08-22 04:29 拍):
1. ChatZoneView 模型选择器 Menu 整容器 `.padding(.leading, 18)`, label 内不另 padding (= cpu ICON 起算 18 PT)
2. ChatView 输入框 HStack `.padding(.horizontal, 18)` (= 发送按钮右边 18 PT)
3. context usage `.padding(.trailing, 18)` 不动 (老板拍 "如果是对的")

**Why:**
commit `f1fe8e64c` (ticket 10) 修真因时写错 inset 位置:
- Menu label 内 `.padding(.leading, 18)` 被 Menu 自带 inset 吃, 视觉 ≠ 18 PT
- ChatView 输入框 `.padding(.horizontal, 8)` 太小, 发送按钮右边 < 18 PT

**Acceptance:**
- 老板 macOS 真验: cpu ICON 左边 = 18 PT + paperplane 右边 = 18 PT
- swift build exit 0
- swift test exit 0
- 双轴 code-review 报告 verbatim 进 commit body