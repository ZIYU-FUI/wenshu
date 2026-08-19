# Spec — v0.17 Dark / Light Mode 整体支持 (老板 2026-08-19 拍)

> Branch: `v0.17-dark-light-mode`
> 真值源: Apple HIG Color (developer.apple.com/design/human-interface-guidelines/color)
> 走 po `to-spec` 7 段模板

## Problem Statement

wenshu 当前在 `App.swift` 用 `.preferredColorScheme(.dark)` 强制 dark mode, 老板 2026-08-19 拍: **整体实现黑夜白昼色**。意思:
1. 默认尊重 macOS 系统设置(跟系统 dark / light 自动切)
2. 老板能在 App 内手动 override(强制 dark / 强制 light / 跟系统)
3. override 选项持久化(下次启动恢复)

老板视角: 不管 macOS 系统是 dark 还是 light, wenshu 都能正确渲染, 不破 Apple HIG 颜色语义, 不写硬编码 RGB。

## Solution

- **删** `.preferredColorScheme(.dark)` 强制 dark
- **新增** Settings 弹窗 (cmd+,) 菜单项 — 老板可在 "跟随系统 / 深色 / 浅色" 三态切
- **持久化** — 写到 UserDefaults, 启动读回
- **颜色** — 全部维持现有 Apple Semantic Color (Color(nsColor: .windowBackgroundColor / .controlBackgroundColor / .separatorColor / .controlAccentColor) 等), dark / light 自动适配, 不引入新硬编码
- **WenshuLibrary / LayoutShellViewModel** — 不动 (跟外观无关)

## User Stories

1. As 老板, I want wenshu 默认跟 macOS 系统 dark/light 设置走, so that 我切系统就能切 wenshu
2. As 老板, I want wenshu 不强制 dark mode (现在 .preferredColorScheme(.dark)), so that 系统在 light mode 时 wenshu 也是 light
3. As 老板, I want Settings 弹窗 (cmd+,) 有外观选项 (跟随系统 / 深色 / 浅色 三态), so that 我能在 App 内 override 系统
4. As 老板, I want 我的外观选项持久化 (UserDefaults), so that 重启 wenshu 恢复我选的
5. As 老板, I want dark/light 切换不影响 6 区 layout / 拖拽线 / 区域模块 / 顶底栏 toolbar 的功能, so that 切外观不破坏 layout
6. As 老板, I want 所有颜色仍是 Apple Semantic (Color(nsColor: ...) 桥), so that dark/light 自动适配, 不需要写两套 design token
7. As 老板, I want `swift build` clean (exit 0), so that 我可以自己启 app 验

## Implementation Decisions

- **外观状态机**: 3 态 (`system` / `dark` / `light`), 用 SwiftUI `@AppStorage` 持久化 (Apple 推荐 UserDefaults 包装, 自动 dark/light 同步)
- **Settings 弹窗**: 用 SwiftUI `Settings` Scene (Apple HIG standard, 自动绑 cmd+,), 内含 `Picker("外观", selection: ...)` 三选一
- **App 顶层**: 不再用 `.preferredColorScheme(.dark)`, 改用 `.preferredColorScheme(vm.colorScheme)` 让 @AppStorage 决定
- **颜色**: 全部 `Color(nsColor: .systemFoo)`, 现状已合规, 不动
- **测试**: 仅 `swift build` clean + 老板自己启 app 验 (Q5 老板拍不跑 Q22)
- **不引入新组件**: 优先用 SwiftUI 内置 `Settings` scene + `@AppStorage` + `Picker`

## Testing Decisions

- **测试范围**: 仅 build clean (exit 0), 不写 unit test (本任务 UI / system integration 层)
- **真值验证**: 老板自己启 app + 切系统 dark/light + Settings 弹窗切 "跟随系统 / 深色 / 浅色" 验
- **Acceptance 标准**:
  - `swift build` exit 0
  - 删 .preferredColorScheme(.dark), 改用 .preferredColorScheme(vm.colorScheme)
  - Settings 弹窗 cmd+, 能开
  - Picker 三态可切 + 重启恢复

## Out of Scope

- **不**改 6 区 layout / 拖拽线 / toolbar / WenshuLibrary / Domain 模型 (本 ticket 只动外观 state + App 顶层)
- **不**改 v0.16 ticket 01 (toolbar 宽度) + 02 (拖拽线圆头) — 它们在 main branch, 本 branch 独立
- **不**新增 design token 文件 (不写两套色, 全部走 Apple Semantic)
- **不**加外观切换动画 (Apple HIG 默认瞬切, 不需要动画)
- **不**跑 Q22 screencapture -l (无 Screen Recording TCC 授权)

## Further Notes

- **Branch**: `v0.17-dark-light-mode` 跟 main 上 v0.16 toolbar / splitter 修复 独立
- **状态机**: 3 态 `system` / `dark` / `light`, 默认 `system`
- **依赖**: macOS 13+ (Ventura) 的 `Settings` Scene (Apple HIG)
- **持久化**: SwiftUI `@AppStorage("appearanceMode")` 自动 UserDefaults
- 老板已 Q9-Q13 答完, frontier 清空, 可直接走 to-tickets → implement