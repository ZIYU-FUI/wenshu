# 14 — chat zone 模型选择器 Menu ICON 左边 14 PT

依赖: ticket 13 commit `75a9a882a` (Menu 整容器范式已装)

**What to build:**
ChatZoneView 模型选择器 Menu ICON 左边 14 PT (老板 2026-08-22 04:34 拍):
1. `.padding(.leading, 18)` → `.padding(.leading, 14)` (老板 A 路径: 14 + 内置 4 = 18 PT 视觉)
2. `.menuStyle(.borderlessButton)` 不动 (内置 inset 不可取消, Apple SwiftUI macOS 27 真值)
3. ChatView 输入框 HStack `.padding(.horizontal, 18)` 不动 (ticket 13 已对)
4. context usage HStack `.padding(.trailing, 18)` 不动 (ticket 13 已对)

**Why:**
ticket 13 commit `75a9a882a` 修真因后 Menu 整容器 `.padding(.leading, 18)` + borderlessButton 内置 4 PT inset = 视觉 22 PT. 老板拍视觉 = 18 PT.

**Acceptance:**
- 老板 macOS 真验: cpu ICON 左边视觉 = 18 PT (= 14 PT + 4 PT inset)
- swift build exit 0
- swift test exit 0
- 双轴 code-review 报告 verbatim 进 commit body