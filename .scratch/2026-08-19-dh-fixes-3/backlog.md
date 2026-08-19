# Backlog — 拖拽线/分割线/菜单栏 (老板 2026-08-19 拍)

> 此文件记录老板拍过但当前 ticket 不动 / 等排期的需求.

## Backlog 01 — 取消"圆头"设计 (Rectangle .clipShape(.capsule))

**Status**: ✅ done — commit c047afc9 (v0.17 ticket 08)

## Backlog 02 — cursor 不变

**Status**: ⚠️ 查文档中 (deleg_a9c4fde9 / deleg_cabed6c4 跑 Apple docs 真值, 待结果)

## Backlog 03 — 拖拽线静态色 Color.black → Color(nsColor: .separatorColor)

**Status**: ✅ done — commit c047afc9 (v0.17 ticket 08)

## Backlog 04 — 其他 wenshu 静态 Color 走 NSColor semantic 审计

**Status**: ✅ done — commit c047afc9 (v0.17 ticket 08, DesignColor.accentBlue / splitterLine 已改)

## Backlog 05 — 拖拽线没顶到头 (差 1 像素)

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

## Backlog 07 — 菜单栏不可见真因 (Q22 / deleg_67dec689 / deleg_a9c4fde9 查文档)

**来源**: 老板 2026-08-19 18:15 + 19:00 反馈

**当前实现** (commit 4c42fa79):
- WenshuApp.body .commands { CommandGroup(replacing: .newItem) { ... } + CommandGroup(replacing: .appSettings) { SettingsLink { Text("设置…") } } + CommandMenu("视图") { ... } }
- .windowStyle(.titleBar) + .defaultSize + .windowResizability(.contentSize) + @NSApplicationDelegateAdaptor

**subagent deleg_67dec689 已查真值** (375 秒, 39 tool calls, 实际 Apple SDK swiftinterface 34953 行):
- App protocol 真值 (sdk:11210-11215): `@SceneBuilder @MainActor var body: Self.Body { get }` + `init()` — .commands 写在 WindowGroup 末尾合法 Scene 修饰符链
- Scene.commands 真值 (sdk:18212-18218): `@available(iOS 14.0, macOS 11.0, *)` — macOS 11+ work, macOS 27 没回归
- 老板实测: 菜单栏**新 binary 仍未显示**

**当前真因猜测 (deleg_67dec689 报告)**:
- App.body .commands { } 真值在 macOS 27 应该 work
- 唯一差异: @NSApplicationDelegateAdaptor(WenshuAppDelegate.self) — subagent 沙箱内没拿到 bug 报告 (anti-bot 拦截)
- 可能性: WenshuAppDelegate.applicationDidFinishLaunching 设 window.center() / setContentSize() 跟 SwiftUI scene 生命周期冲突, 导致 menu 不显示

**目标修法 (待拍)**:
- 选项 A: WenshuAppDelegate.applicationDidFinishLaunching 移除 setContentSize / center, 改用 NSWindowController 包装
- 选项 B: @NSApplicationDelegateAdaptor 移走, 改在 WenshuApp.body 内 onAppear 调 setupMenu (NSMenu 手动建)
- 选项 C: 用 NSApplicationDelegate 完全 AppKit 模式 (NSApplicationMain) 不走 SwiftUI App lifecycle
- 选项 D: 其他 (待老板查文档 + 拍)

**Acceptance criteria**:
- macOS 顶部菜单栏可见
- "文枢" 顶级下能看到 "设置..." (跟 Pages / Numbers / Xcode 一样)
- 快捷键 ⌘, work
- 点击弹设置弹窗
- 不破坏其他功能

**优先级**: 高 (基本 UI)

**Blocked by**: deleg_a9c4fde9 真值报告 + 老板拍

**Status**: 等真因 + 拍修法