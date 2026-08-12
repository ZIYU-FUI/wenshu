# WO-LT-01-fix15: 修 3 个 NativeSplitter 拖拽后 BUG

[老板 8/7 实机拍]
1. **BUG1**: 抓住拖拽后 释放鼠标 分割线还是高亮
2. **BUG2**: 拖拽松开后 鼠标变形没恢复 (还是 resize 形式两向箭头)
3. **优化1**: 细线两边预留的一点点区块间距不需要

[真根因 - PM-direct 自纠]
- BUG1 + BUG2 同源: 鼠标仍在 hit area 内 → mouseExited 不 fire → isHovered / push 的 cursor 都残留
- 拖拽场景: 用户在 hit area 内按下 → 在 hit area 内拖 → 在 hit area 内松手, mouseExited 从不 fire
- 优化1: lineRect 在 hit area 内居中, 1pt 线浮在中间 3.5pt + 3.5pt, 不贴 panel 边界

[修法 - 1 处文件 NativeSplitter.swift]
- mouseUp 末尾无条件清 isHovered (BUG1) + 双保险 reset cursor (BUG2)
  - cursorPushed flag 跟踪配对 push/pop
  - NSCursor.arrow.set() 兜底
- draw() 走新 lineRect 静态 helper, x=0 / y=0 (优化1 贴 hit area 边缘)
- mouseEntered/mouseExited 用 cursorPushed flag 守 push/pop 配对
  - 取代 fix10 无条件 NSCursor.pop() (边界条件下 pop 错栈风险)

[验证 - 全过]
- swift build exit 0 (0.96s)
- 3 个新 unit test 过 (LT01Fix15Tests):
  - testNativeSplitterDrag_mouseUp_clearsHover
  - testNativeSplitterDrag_mouseUp_resetsCursor
  - testNativeSplitterDraw_noInsetPadding
- 14 case 全过 (fix9 + fix10 + fix14 + fix15 回归)
- baseline 验证 4 fragile failures 非本 fix15 回归 (派单边界已知)

[worktree]
- .worktrees/t_5063da4d-LT-01-fix15 (branch wenshu/v0.02.0/LT-01-fix15)
- commit 11e2c1390 (未 push, 派单硬规则)
- BASE = fix14 commit 93e25d5c4 (从 fix14 切)

[边界保留]
- 只改 Sources/WenshuApp/Views/Layout/NativeSplitter.swift
- 不动 LayoutShellView / WenshuStoreActor / Package.swift / Info.plist
- 全量 swift test 4 fragile failures 留给 LT-01-fix16 派单 (已知派单边界)

[装 user 必走 3 件事]
1. 启动 App → 拖水平 splitter → 松手 → 分割线立即不高亮 (无 lag)
2. 拖水平 splitter → 松手 → 鼠标 cursor 立即恢复 .arrow (无 resize 残留)
3. 分割线 edge-to-edge 视觉贴 panel 边界 (无预留 spacing)

[版本号]
v0.02.0 (8/6 拍板) — LT-01 fix 序列都完成

[Stop 钩子验证]
- Stop 钩子 = /Users/anbaiqiang/.claude/hooks/cc-stop-notify.sh (861 bytes)
- settings.json 已配 Stop hook command
- 老板 8/28 拍 "用 CC 通知机制, 不要 PM-direct 巡检"
- 验证: fix15 CC 跑完 fire.log CC_EXIT=0 立即有反馈 (无需 PM-direct 30s 等)
