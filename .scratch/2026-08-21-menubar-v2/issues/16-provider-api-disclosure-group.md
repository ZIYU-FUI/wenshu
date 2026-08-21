# 16 — 提供方 API 编辑面板 inline 展开 (DisclosureGroup)

依赖: ticket 15 commit `f0b71d098`

**What to build:**
providerApiTab 子组件修真因 (老板 2026-08-22 06:00 拍 "应该在 minimax cn 那一条处展开"):
1. 撤独立 Section 块 (`if let editing = apiEditingProvider { Section("填 X API Key") {...} }`)
2. ForEach 内 provider 渲染 = `DisclosureGroup(isExpanded:) { SecureField + 按钮 } label: { providerApiRow(p) }`
3. @State expandedProviders: Set<String> 控制每个 provider 的展开状态

**Why:**
ticket 15 commit `f0b71d098` 修真因 = 编辑面板在 Form 底部独立 Section 渲染. 老板要 inline 展开在对应 provider 行下面. Q26 5 原则判定 DisclosureGroup 唯一通过 (Apple 官方范式 + 伪 Apple 样式 + 效果优先 + 业务语言 + po main flow).

**Acceptance:**
- 老板 macOS 真验: 点 MiniMax (China) 行 → 整行展开 inline 编辑面板 → SecureField + 保存 → 状态变 "已设 key"
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass 不回归)
- 双轴 code-review 报告 verbatim 进 commit body