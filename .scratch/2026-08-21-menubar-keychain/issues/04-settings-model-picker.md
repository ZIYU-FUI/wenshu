# 04 — Settings 加模型配置 Picker (配完省略显示)

**What to build:**
老板 2026-08-21 macOS 真验反馈: "在设置里加一个 模型配置的功能。配完省略显示". 当前 App.swift `Settings { ... }` Scene 只有"外观" Picker, 没模型配置. 当前 `MiniMaxVerifier` model hardcoded `"MiniMax-M3"`, 老板验完改不动.

修法: Settings Scene 加 `Picker("模型", selection: $model)` 列出 3 个 default MiniMax model (`MiniMax-M3` / `MiniMax-M2` / `MiniMax-Reasoning`), 选完存 `@AppStorage("wenshu.llm.model")`, **不显示当前 model 名字** (老板原话 "配完省略显示"). MiniMaxVerifier.init 读 `@AppStorage` 优先 env.

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (4 步)

1. App.swift `Settings { ... }` Scene 加:
   - `@AppStorage("wenshu.llm.model") private var llmModel: String = "MiniMax-M3"`
   - `Picker("模型", selection: $llmModel) { ForEach(MiniMaxModel.allCases) { Text($0.label).tag($0.rawValue) } }` (不显当前值 label)
2. 新增 `Sources/WenshuApp/Core/Agent/MiniMaxModel.swift` (enum 真值):
   - `case m3 = "MiniMax-M3"`
   - `case m2 = "MiniMax-M2"`
   - `case reasoning = "MiniMax-Reasoning"`
   - `var label: String { switch self { case .m3: "MiniMax-M3" ... } }`
3. `MiniMaxVerifier.init` 加 `model` 参数 (默认 `MiniMax-M3`), `applicationDidFinishLaunching` 注入 `@AppStorage("wenshu.llm.model")` 读
4. 老板 macOS 真验: 打开 cmd+, → 看到"模型" Picker → 选一个 → 关 → 重开 Settings → 不再显示当前 model (省略)

## Acceptance

- [ ] MiniMaxModel enum 3 case
- [ ] App.swift Settings Scene 加 Picker (无当前值 label)
- [ ] @AppStorage("wenshu.llm.model") 持久化
- [ ] MiniMaxVerifier.init 接受 model 参数 (默认 MiniMax-M3)
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 配完不显示 model 名字 (省略)

## 不动 (Q20 硬约束)

- v0.20 ticket 04 + 05 (LOGO 不动)
- v0.21 chat streak ticket 02-06 (已 commit, 不动)
- App.swift L188 Settings Scene 已有的"外观" Picker (保留)
- AppIcon.icon/ (老板拍先放着)

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/picker
- https://developer.apple.com/documentation/swiftui/settings (Settings Scene 真值)
- https://developer.apple.com/documentation/swiftui/appstorage
- CLAUDE.md L42 "LLM key 存 macOS Keychain, 不入文件、不入 log、不入 commit"

## 关联

- 依赖: 无
- 被依赖: ticket 02 (LLM Keychain) — MiniMaxVerifier 改 model 字段配套 ticket 02 Keychain 集成