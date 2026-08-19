# 02 — hover 蓝光稳定 (取消 mouseMoved) + 透明度 0.25 (老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 实测 D_h 拖拽线蓝光 2 个问题:
1. 鼠标移开蓝光偶尔不消失 (mouseMoved 在 macOS 27 鼠标快速移动时事件丢失)
2. 蓝光太实, 想加透明度 (老板拍从 0.5 → 0.25, 更透明看见背后)

**改完**:
- 取消 mouseMoved override (Apple AppKit 真值: mouseEntered/mouseExited 才是标准)
- 加 mouseDragged 强制设 isHovered = true (拖拽期间 100% 蓝光保持)
- 加 mouseUp 设 isHovered = false (松手立刻清, 不依赖 mouseExited)
- mouseEntered / mouseExited 保留 (正常 hover in/out)
- 透明度 opacity 0.5 → 0.25 (老板 8/19 16:50 拍)

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent → impl done → 等老板验

## Acceptance criteria

- [ ] 取消 mouseMoved override (Apple AppKit 真值: mouseEntered/mouseExited 才是标准)
- [ ] 加 mouseDragged: 设 onHoverChange(true) (拖拽期间强制保持蓝光)
- [ ] 加 mouseUp: 设 onHoverChange(false) (松手立刻清, 不依赖 mouseExited)
- [ ] mouseEntered / mouseExited 保留 (正常 hover in/out)
- [ ] 透明度: accent 0.5 → 0.25, shadow 0.3 → 0.15 (或保持 0.3 — 老板 8/19 16:50 拍)
- [ ] 静态线 2 PT 黑不变
- [ ] 6 PT hit area 不变
- [ ] 鼠标移开拖拽线 → 蓝光稳定消失 (走 mouseExited 优先, mouseUp fallback)
- [ ] D_h / D_v 5 竖拖拽线都生效
- [ ] 拖拽期间 → 蓝光保持 (走 mouseDragged 强制设 true)
- [ ] 松手 → 蓝光立刻消失 (走 mouseUp 强制设 false)
- [ ] macOS chrome / LayoutTokens / bandH / toolbar 宽度 全不动
- [ ] swift build exit 0
- [ ] 不引入新依赖 (SwiftUI + AppKit 内置)

## 业务语言描述 (老板懂)

- 蓝光持续亮: 改用 macOS 系统标准的 mouseEntered/mouseExited (取消之前试的 mouseMoved, 不稳定). 拖拽期间强制保持蓝光, 松手立刻清
- 透明度: 0.25 (老板 8/19 16:50 拍, 更透明看见背后)

## 不动

- macOS chrome 52 PT
- D_h 视觉 2 PT 静态 + 4 PT hover 不变
- 6 PT hit area
- 拖拽线 NSView + NSEvent 范式 (v0.16 ticket 03 已拍板, ticket 06 再处理 cursor)