# 01 — 删 .preferredColorScheme(.dark) + 加 Settings 弹窗 + @AppStorage 三态持久化

**What to build:**
v0.17 整体黑夜白昼色实现. 改完应该是:
1. 删 `App.swift` 里 `.preferredColorScheme(.dark)`
2. 加 SwiftUI `Settings` Scene (绑 cmd+,), 内含 `Picker("外观", selection: $appearanceMode)` 三态 (system / dark / light)
3. 用 `@AppStorage("appearanceMode")` 持久化 (Apple UserDefaults 包装)
4. App 顶层 WindowGroup 改 `.preferredColorScheme(vm.colorScheme)`, vm 从 @AppStorage 读

全部颜色维持现有 Apple Semantic (Color(nsColor: .systemFoo)), 不写硬编码 RGB. 改完 `swift build` clean (exit 0), 让老板自己启 app + 切系统 + 切 Settings 验.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Acceptance criteria

- [ ] 删 `.preferredColorScheme(.dark)` 强制 dark
- [ ] 加 SwiftUI `Settings { ... }` Scene (Apple HIG 标准, 绑 cmd+,)
- [ ] Settings 内 `Picker("外观", selection: $appearanceMode)` 三态: 跟随系统 / 深色 / 浅色
- [ ] 用 `@AppStorage("appearanceMode")` 持久化 (Apple UserDefaults 包装)
- [ ] App 顶层 WindowGroup 改 `.preferredColorScheme(vm.colorScheme)` 让 @AppStorage 决定
- [ ] 默认 "跟随系统" (system), 不强制 dark
- [ ] 全部颜色仍是 Apple Semantic Color (Color(nsColor: ...)), 不写硬编码 RGB
- [ ] 不引入新 design token 文件 (不写两套色)
- [ ] `swift build` clean (exit 0)
- [ ] 不动 6 区 layout / 拖拽线 / toolbar / WenshuLibrary / Domain 模型
- [ ] agent 不跑 Q22 screencapture -l (无 Screen Recording TCC 授权)