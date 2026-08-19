# 15 — Templates 模板系统 + date tokens (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 4 件: Templates 模板系统 (date tokens + 变量插入)。

**改完:**
- `Sources/WenshuApp/Core/Templates/TemplateEngine.swift` (模板文件 + date tokens: `{{date}}` / `{{time}}` / `{{title}}` / `{{author}}`)
- `Sources/WenshuApp/Core/Templates/TemplatePicker.swift` (SwiftUI View 选择模板创建新 note)

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/Templates/TemplateEngine.swift date tokens 替换
- [ ] Sources/WenshuApp/Core/Templates/TemplatePicker.swift SwiftUI View
- [ ] swift build exit 0
- [ ] 单元测试: TemplateEngineTests (tokens 替换 + 嵌套变量)
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView

## 业务语言描述 (老板懂)
- 写作 app 强需求: 大纲模板 / 人物模板 / 章节模板
- 创建新章节时自动填模板

## 真值引用
- Obsidian Templates: https://help.obsidian.md/Plugins/Templates
- Apple HIG DateFormatter
