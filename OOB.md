# OOB Index (= canonical log of 老板 out-of-band directives)

Per 老板 2026-09-24 OOB: OOB does not belong in source / AGENTS.md / .swift comments.
All OOB mentions in code/comments reference this file by date.

This file is dev-time only (= wenshu repo root = not in .app bundle = not in release).

Generated: 2026-09-24 16:53
Total unique OOB entries: 48
Unique dates: 14

---

## v1.67 (date unknown)

- `Sources/WenshuApp/App/AppRootScene.swift:L325`: "= matches the v1.67 boss OOB"

## v0.30 (date unknown)

- `Sources/WenshuApp/State/BookStore.swift:L190`: ",, show"
- `Sources/WenshuApp/State/WenshuLibrary.swift:L241`: ",, show"
- `Sources/WenshuApp/Storage/LibraryMigrator.swift:L680`: "the feature modules too, split one feature module per doc"
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:L371`: "carddefaultyes"
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:L1468`: "card,"

## v0.28 (date unknown)

- `AGENTS.md:L51`: "v1 → v2 breaking-change risk 由 ticket 评估"
- `AGENTS.md:L59`: "Highlighter"
- `AGENTS.md:L59`: "HighlighterSwift"

## v0.27 (date unknown)

- `AGENTS.md:L18`: "从今天开始，任何功能，先查有没有三方库可以用。不重复造轮子是对的。我之前说不引入三方给自己挖坑了"

## date unknown

- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:L1570`: "directory,"
- `Sources/WenshuApp/Views/Settings/SettingsOps.swift:L91`: "right column MVVM split"
- `Sources/WenshuApp/Views/Settings/SettingsOps.swift:L91`: "按MVVM UI 业务 数据"
- `Sources/WenshuApp/Views/Library/SidebarService.swift:L660`: "Reference Library cannot be deleted"
- `Sources/WenshuApp/Views/Library/SidebarContextMenu.swift:L63`: "reference library cannot be deleted"
- `Sources/WenshuApp/Views/Layout/PaneNSController.swift:L155`: "completely transparent"
- `Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift:L43`: "we don"
- `Sources/WenshuApp/UI/Layout/InspectorCatalog.swift:L80`: "three per page, split into four pages, show them all"
- `Sources/WenshuApp/State/AppState.swift:L161`: "在新框架下, 哪些没有同成组件, 要抽好"
- `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTracker.swift:L35`: "engineering"

## 2026-09-22

- `Sources/WenshuApp/DesignTokens.swift:L168`: "距底 30PT"
- `Sources/WenshuApp/Core/Agent/Goals/HermesGoals.swift:L90`: "业务层不许摸基础设施"

## 2026-09-21

- `AGENTS.md:L632`: "数据库不要在用sqlite3 了"

## 2026-09-20

- `AGENTS.md:L27`: "SQLite 全部弃用，只用 SwiftData"
- `AGENTS.md:L27`: "Apple-default-first = Core Spotlight"
- `AGENTS.md:L27`: "数据库不要在用sqlite3 了"
- `AGENTS.md:L54`: "No SQLite"
- `AGENTS.md:L54`: "SQLite 全部弃用，只用 SwiftData"
- `AGENTS.md:L54`: "Core Spotlight 替代 FTS5"

## 2026-09-16

- `Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift:L5`: "按优先级推"
- `Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift:L5`: "自己一口气推完"
- `Sources/WenshuApp/UI/Layout/ShellContentColumn.swift:L5`: "按优先级推"
- `Sources/WenshuApp/UI/Layout/ShellContentColumn.swift:L5`: "拆了一半"
- `Sources/WenshuApp/UI/Layout/ShellDetailColumn.swift:L5`: "按优先级推"
- `Sources/WenshuApp/UI/Layout/ShellDetailColumn.swift:L5`: "自己一口气推完"

## 2026-09-15

- `AGENTS.md:L49`: "use SF Symbols 6 (3rd gen) with palette rendering"

## 2026-09-14

- `AGENTS.md:L449`: "按优先级推"
- `AGENTS.md:L513`: "清完所有待办"
- `Sources/WenshuApp/UI/Layout/ShellPlaceholder.swift:L5`: "要修，继续"
- `Sources/WenshuApp/Views/Workspace/EditorPlaceholder.swift:L5`: "我想把这些修掉"
- `Sources/WenshuApp/Views/Workspace/ZoneModuleView.swift:L9`: "我想把这些修掉"

## 2026-09-04

- `AGENTS.md:L100`: "继续把工作树干完"
- `AGENTS.md:L139`: "先不验收, 先继续把工作树干完"
- `AGENTS.md:L160`: "继续把工作树干完"
- `Sources/WenshuApp/Core/I18n/WenshuI18n.swift:L9`: "api, defaultyesin progress, hermes UI autoissue"

## 2026-09-03

- `AGENTS.md:L91`: "hermes 整体翻译成 swift, 整个工作树都完成了?"
- `AGENTS.md:L91`: "先不验收, 先继续把工作树干完"

## 2026-08-30

- `Sources/WenshuApp/UI/PaneTabBar.swift:L3`: "[Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame`; the cleanup commit replaced it with this placeholder because translation was inco..."

## 2026-10-02

- OOB directive (= 来源 = AGENTS commit `724a6c2de`): "AGENTS / CLAUDE 两个大文件，需要治理吗"
- OOB directive (= 来源 = AGENTS commit `724a6c2de`): "你说的继续，是继续什么"
- OOB directive (= 来源 = AGENTS commit `724a6c2de` + later commit body): "C" (= option C selection, = 3-tier split AGENTS.md / AGENTS-§11-rules.md / AGENTS-§11-history.md)
- OOB directive (= 来源 = .hermes.md commit `8bc8b2193`): "颜色已经做完了的话。把今天做的 HIG 直接使用这个规则，还有中央工厂，都需要让之后你写代码的时候自动遵守"
- OOB directive (= 来源 = .hermes.md commit `8bc8b2193`): "这几个规范性的技能，你在写代码之前能自动加载吗？还有 apple 规范，通用规范。我们不能过一段时间就排查一次，一定要在每次写代码前就知道应该怎么写"
- OOB directive (= 来源 = color sweep commit `03cfebdff`): "颜色也盘一下"
- OOB directive (= 来源 = color sweep round 73 commit `d01556698`): "继续" (= continue, = context: color sweep arc continues from previous session)
- OOB directive (= 来源 = AGENTS.md split commit `719b25848`): "等我自己加什么？你不能操作吗"
- OOB directive (= 来源 = AGENTS.md split commit `719b25848`): "本会话做一个两轴"
- OOB directive (= 来源 = sweep round 73 commit `d01556698`): "继续" (= continue, = context: keep pushing sweep arc)
- OOB directive (= 来源 = sweep round 74 commit `33b5786d8`): "继续" (= continue, = context: keep pushing sweep arc)
- OOB directive (= 来源 = design-system-rule skill authoring, = derived from session work): "Apple-default-first" (= 颜色 sweep round 73 tokenize .tint.opacity(0.18) to DesignTokens.accentTintOpacityHero, = Apple HIG canonical pattern, = per §11.7 sqlite3-zero + §11.16 facet model precedent)
- OOB directive (= 来源 = sweep round 74 TodoListView chipStyle AnyShapeStyle, = derived from session work): "颜色已经做完了的话" (= when color sweep closes, = apply to the rest of the codebase)
