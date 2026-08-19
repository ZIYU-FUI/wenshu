# Spec — 文枢菜单下加 "设置..." 菜单项 (Apple HIG macOS 真值)

> Date: 2026-08-19
> Spec 走 po `to-spec` skill 7 段模板

## Problem Statement

老板 2026-08-19 反馈: wenshu 启 app 后菜单栏**没有"设置"菜单**,但代码已经写了 `Settings` scene(L208-219) — 老板找不到入口。

从老板视角,macOS app 标准做法 = "文枢" 顶级菜单下挂 "设置..." 项(Apple HIG,跟 Pages / Numbers / Xcode 一致),快捷键 `⌘,`。

## Solution

在 `.commands` 里加 `CommandGroup(replacing: .appSettings)` 把 "设置..." 菜单项手动注入 "文枢" 顶级下。SwiftUI `Settings` scene 保留(用户通过菜单点击或 `⌘,` 打开)。

### 业务语言描述 (老板懂)

- 菜单栏 "文枢" 顶级下加 "设置..." 项(跟 Pages / Numbers / Xcode 一样)
- 快捷键 `⌘,` (Apple 标准)
- 点击 → 弹现有设置弹窗(外观 dark / light / 跟随系统)

## User Stories

1. As 老板, I want 菜单栏 "文枢" 顶级下能看到 "设置..." 菜单项, so that 能开设置弹窗
2. As 老板, I want "设置..." 快捷键 `⌘,`, so that 跟 Pages / Numbers / Xcode 一样
3. As 老板, I want 点击 "设置..." 弹出现有设置弹窗 (外观 dark / light / 跟随系统)
4. As 老板, I want 设置保持菜单栏其他项不变 (文枢 / 文件 / 编辑 / 显示 / 视图 / 窗口 / 帮助)
5. As 老板, I want `swift build` exit 0

## Implementation Decisions

- **在 WenshuApp.body .commands {} 加 `CommandGroup(replacing: .appSettings)`**:
  ```swift
  CommandGroup(replacing: .appSettings) {
      SettingsLink {
          Text("设置…")
      }
      .keyboardShortcut(",", modifiers: .command)
  }
  ```
- **`SettingsLink` 是 SwiftUI 4+ (macOS 14+) API**, 跟 Settings scene 配合自动打开
- 现有 `Settings { Form { Picker("外观") } }` scene 保留,作 macOS HIG standard
- 不动现有菜单 (文件 / 视图 / 恢复默认布局)

## Testing Decisions

- 仅 `swift build clean` (exit 0), 老板自己启 app 验
- 验证: 菜单栏 "文枢" 顶级下能看到 "设置..." 项, 快捷键 `⌘,` work, 点击弹设置弹窗

## Out of Scope

- 不动 macOS chrome 52 PT
- 不动 LayoutTokens / bandH / toolbar 宽度
- 不动 D_h / D_v 5 竖拖拽线
- 不动 cursor (backlog 02 待办)
- 不实现 设置持久化 (已有 @AppStorage("appearanceMode") 持久化)
- 不加其他设置项 (外观已实现, 等 backlog 排期再加)

## Further Notes

- 这是菜单栏视觉细节修法, 跟之前 v0.16 ticket 01-06 独立
- Apple HIG 真值: macOS app 在 "文枢" 顶级菜单下必有 "设置..." (跟 Pages / Numbers / Xcode 一样)
- SettingsLink SwiftUI 4+ API 真值: https://developer.apple.com/documentation/swiftui/settingslink