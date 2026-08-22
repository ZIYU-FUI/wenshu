# 15 — Templates template system + date tokens (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 4: Templates template system (date tokens + variable insertion).

**After change:**
- `Sources/WenshuApp/Core/Templates/TemplateEngine.swift` (template file + date tokens: `{{date}}` / `{{time}}` / `{{title}}` / `{{author}}`)
- `Sources/WenshuApp/Core/Templates/TemplatePicker.swift` (SwiftUI View choose template to create new note)

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Templates/TemplateEngine.swift` date tokens substitution
- [ ] `Sources/WenshuApp/Core/Templates/TemplatePicker.swift` SwiftUI View
- [ ] `swift build` exit 0
- [ ] Unit tests: TemplateEngineTests (token substitution + nested variables)
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView

## Business-language description (老板 understands)

- Writing app strong requirement: outline template / character template / chapter template
- Auto-fill template when creating new chapter

## Truth references

- Obsidian Templates: https://help.obsidian.md/Plugins/Templates
- Apple HIG DateFormatter