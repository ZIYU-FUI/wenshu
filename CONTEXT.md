# CONTEXT · Wenshu (文枢)

> Domain glossary for wenshu. Every agent reads this before working on the project. Update when a new domain word enters the codebase.

## Identity

- **wenshu / 文枢** = Apple 全家桶专属的长篇虚构小说 AI 创作平台
- 老板拍板 2026-08-06: 自建轻量 AI 内核, 不调任何外部 AI 平台
- 第一版 LLM provider: **minimax cn** (Anthropic 兼容协议)
- Apple 全家桶专属 (macOS / iPad / iPhone), 老板 8/18 拍 macOS-only 单 target
- 项目根: `/Volumes/ANAN/Engineering/wenshu/`

## Architecture

- **Stack**: Swift / SwiftUI + CoreData + 单进程协程 + 自建轻量 AI 内核
- **Storage**: `.ws` 单文件 = CoreData + 附件, 本地自管, 路径 `~/Documents/wenshu/<id>/`
- **Build**: SwiftPM, `.macOS(.v27)` 单 platform, `Package.swift` 唯一入口
- **LSP / LLM**: 不调任何外部 AI 平台任何代码文件
- **Not used**: UIKit, Tauri, Rust, SQLite, Vue 3, sparse clone, novel-platform / novel-craft / Hermes-Slate-Desk 旧 V0.5.x 协议
- **Not used**: iOS / iPadOS / Catalyst 适配

## Domain words

| Term | Definition | ADR |
|------|------------|-----|
| **Zone** | 6 区 layout 顶层 (Z-TITLE 标题栏 / Z-NOVEL 小说管理区 / Z-CHAT 聊天管理区) | ADR-0001 |
| **Band** | 上/下两个管理区 (Y 段 39~511, 512~984) | ADR-0001 |
| **Master** | Sketch SymbolMaster 组件 (6 个真值: 标题栏 / 区域顶部工具栏 / 区域底部工具栏 / 区域模块 / 拖拽线-竖 / 拖拽线-横) | ADR-0002 |
| **Instance** | 13 个 SymbolInstance 1:1 落 SwiftUI 子组件 | ADR-0002 |
| **Drag Splitter** | 5 竖 + 1 横拖拽线, NSView + NSEvent.delta 增量拖拽 | ADR-0003 |
| **Static Divider** | 不可拖拽分割线, SwiftUI Divider / Color.frame (1 PT, NSColor.separatorColor) | ADR-0003 |
| **Library** | `WenshuLibrary` Observable + `LibraryStoring` 协议 + `FileSystemLibraryStore` 真值 | ADR-0004 |
| **Book** | `Book` 数据类 (含 length / idea 字段, 8/18 答 Q2 拍) | ADR-0004 |
| **Bookshelf** | `Bookshelf` 数据类, 书架为父级, 可点击折叠展开 | ADR-0004 |
| **Document** | `Document` 数据类, 3-class MD 文档模型 (章节/设定/资料库) | ADR-0005 |
| **PT** | Apple 排版单位, macOS 27 1x 下 1 PT = 1 PX (老板 8/18 拍 1:1 落) | — |

## Project conventions (硬约束)

- 修真词 (修真/渡劫/筑基/返虚/结丹/金丹/元婴/飞升/天劫/雷劫/心魔/魔障) 全部禁用, 改用 修 / 改 / fix / 替换 / 调整
- 对老板唯一称谓 = 老板, 不混用旧称谓 (boss 已在 v0.07 净化)
- 不用装饰 emoji / 起手结尾式 / 大字号标题
- 第一行是事实, 末行就是事实
- 禁中性词 (可/应当/或许/可能/应该/建议/考虑/试图/尽量/大概/也许/或/任意/大概率/通常/一般来说), 用确词 (是/否/行/不行/可以/不可以/不变/变)
- Apple 全家桶专属 → 任何通用预留点 / iOS / iPadOS / Catalyst 适配 = 死代码 = 删

## See also

- `AGENTS.md` — 项目基线 §11 + 跨角色称谓硬约束 §12
- `CLAUDE.md` — CC 启动时读的上下文
- `docs/agents/issue-tracker.md` — 本地 markdown issue tracker 配置
- `docs/agents/triage-labels.md` — 5 canonical triage roles
- `docs/agents/domain.md` — single-context 规则
- `docs/adr/` — 架构决策记录
- `.hermes/SPECS/v0-scaffold-from-sketch.md` — 6 区 layout 真值 spec
