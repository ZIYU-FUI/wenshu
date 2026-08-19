# Backlog — 拖拽线/分割线/菜单栏 (老板 2026-08-19 拍)

> 此文件记录老板拍过但当前 ticket 不动 / 等排期的需求.

## Backlog 01 — 取消"圆头"设计 (Rectangle .clipShape(.capsule))

**Status**: ✅ done — commit c047afc9 (v0.17 ticket 08)

## Backlog 02 — cursor 不变

**Status**: ✅ done — commit f65bb329 (v0.17 ticket 03 cursor 退回 .pointerStyle)
- 真因报告: cursor-investigation-report-v2.md (552 行, 39 KB)
- 真因: NSHostingView 不 override resetCursorRects + override hitTest, 屏蔽 AppKit cursor rects 范式
- 修法: 退回 SwiftUI .pointerStyle(.columnResize / .rowResize) 挂到 ZStack 最外层 (Apple HIG macOS 15+ 标准)
- 删 WenshuCursorController NSResponder + WenshuAppDelegate.cursorController + SplitterHitArea.resetCursorRects (之前错误范式)
- 拖拽线视觉 / hover 蓝光 / 拖动响应 / hit area / 1 PT fill 全保持
- 待老板验 cursor 切 ↕ / ↔

## Backlog 03 — 拖拽线静态色 Color.black → Color(nsColor: .separatorColor)

**Status**: ✅ done — commit c047afc9 (v0.17 ticket 08)

## Backlog 04 — 其他 wenshu 静态 Color 走 NSColor semantic 审计

**Status**: ✅ done — commit c047afc9 (v0.17 ticket 08, DesignColor.accentBlue / splitterLine 已改)

## Backlog 05 — 拖拽线没顶到头 (差 1 像素)

**Status**: ✅ done — commit e359e27 (v0.17 ticket 02 顶到头)
- NativeSplitter lineThickness 2 → 1
- NativeSplitter hoveredThickness 4 → 3
- NativeSplitter hitAreaThickness 6 → 1

## Backlog 06 — 分割线没顶到头 (差 1 像素)

**Status**: ✅ done — commit e359e27
- StaticDividerHorizontal Rectangle frame(height: 2) → frame(height: 1)
- StaticDividerVertical Rectangle frame(width: 2) → frame(width: 1)

## Backlog 05 (旧) — 拖拽线没顶到头 (差 1 像素)

**来源**: 老板 2026-08-19 19:00 拍

**当前实现**:
- NativeSplitter body Rectangle L155 `.fill(...) .frame(width: lineFrame.width, height: lineFrame.height)`
- outerWidth = hitAreaThickness (6 PT) for vertical, length for horizontal
- Rectangle frame = 2 PT (static) / 4 PT (hover)
- 视觉: 拖拽线 2 PT 居中, 两边各 (6 - 2) / 2 = 2 PT 空白

**真因猜测**:
- Rectangle frame 是 lineFrame.width (2 PT 居中), hit area 是 6 PT
- hit area 是透明 NSView overlay, 视觉 Rectangle 在 hit area 内部居中
- 老板看 "差 1 像素" = 视觉 Rectangle 没有 100% 占 hit area 宽度, 上下/左右各有 1-2 PT 留白
- 可能: Rectangle frame 应该是 hitAreaThickness (6 PT) 视觉占满 hit area, 上下留白给 hit area 透明区域

**真值源 (Sketch AF7B1C87)**:
- D_h 真值: x:0, y:517, w:1920, h:2 (横跨整 window 宽, 1920 PT 1:1)
- D_v 真值: x:200 / 720 / 1244, y:52, w:2, h:465 (整 band 高, 2 PT 宽, 占满 hit area)

**目标修法 (待拍)**:
- 选项 A: Rectangle frame 改成 hitAreaThickness (6 PT) 视觉占满 hit area, 让 Rectangle "看起来" 顶到头
- 选项 B: Rectangle frame 保持 2 PT 但 NSTrackingArea bounds 精确等于 Rectangle 视觉区域
- 选项 C: 1 PT 调整 (e.g. Rectangle frame +1 PT = 3 PT 视觉) 解决差 1 像素

**Acceptance criteria**:
- 拖拽线视觉顶到头 (差 0 像素)
- D_h 横跨整 window 宽
- D_v 占满 zone 高度
- 不破已实现的拖拽交互 + hover 蓝光
- 1:1 落 Sketch AF7B1C87
- swift build exit 0

**优先级**: 中 (视觉细节, 已 commit 验证, 但差 1 像素影响 1:1 Sketch 真值)

**Blocked by**: 老板拍选项

**Status**: backlog

## Backlog 06 — 分割线没顶到头 (差 1 像素)

**来源**: 老板 2026-08-19 19:00 拍 ("分割线也是一样, 一并处理")

**当前实现**:
- StaticDividerHorizontal: Rectangle frame(width: w, height: 2)
- StaticDividerVertical: Rectangle frame(width: 2, height: height)
- 跟 D_h / D_v 同问题 (Rectangle frame 居中, hit area 不居中)

**目标修法**:
- 跟 backlog 05 一起修, Rectangle frame 占满整个 split region

**Acceptance criteria**:
- 分割线视觉顶到头 (差 0 像素)
- 不破已实现的视觉
- swift build exit 0

**优先级**: 中 (跟 backlog 05 一起排)

**Blocked by**: backlog 05 选项拍

**Status**: backlog (合并 backlog 05 一起修)

## Backlog 07 — 菜单栏不可见真因 (deleg_a9c4fde9 查文档完)

**Status**: ✅ 真因 + 修法 — commit 待 (deleg_a9c4fde9 47 分钟 跑完 120 tool calls)

**真因 (P0)**:
- vdhamer/Photo-Club-Hub-HTML#248 (open since 2026-08-13) 公开记录: `CommandGroup(replacing: X) { }` 不删除 group — 它替换为空 group,每个空 group 仍然贡献一个 separator, SwiftUI 层 API 不能清理自己留下的东西
- 确认机制: WenshuAppDelegate 在 SwiftUI 完成 main menu 之前动了 NSWindow, + macOS 27 beta lazy menu populate = 整个顶部菜单栏根本没安装

**URL 真值引用**:
- https://github.com/vdhamer/Photo-Club-Hub-HTML/issues/248
- https://developer.apple.com/documentation/swiftui/app/commands (sosumi.ai 镜像)
- https://developer.apple.com/documentation/swiftui/commandmenu
- https://developer.apple.com/documentation/swiftui/commandgroup
- https://developer.apple.com/documentation/swiftui/commandgroupplacement

**目标修法 (待老板拍)**:
- 选项 A: 注释 WenshuAppDelegate (让 SwiftUI 自己装 menu, 不在 NSWindow 之前动)
- 选项 B: 加 `NSApp.mainMenu?.items.forEach { $0.submenu?.update() }` 在 applicationDidFinishLaunching 末尾强制 install
- 选项 C: 用 `.commandsReplaced` 强制 install
- 选项 D: 退 AppKit (`NSApplicationMain` + 手动 NSMenu)

**Acceptance criteria**:
- macOS 顶部菜单栏可见
- "文枢" 顶级下能看到 "设置..." (跟 Pages / Numbers / Xcode 一样)
- 快捷键 ⌘, work
- 点击弹设置弹窗
- 不破坏其他功能 (cursor 切 / 拖拽 / hover)

**优先级**: 高 (基本 UI)

**Blocked by**: 老板拍选项 + cursor ticket 03 验证通过

**Status**: 待 cursor 03 验过 + 老板拍修法选项