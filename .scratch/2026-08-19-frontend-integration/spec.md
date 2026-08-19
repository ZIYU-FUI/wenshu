# Spec — WenshuCore 复刻模块接入前端需求清单 (老板 2026-08-19 evening 拍)

> Date: 2026-08-19
> 老板 2026-08-19 evening 拍 "这些模块前端怎么调用, 我们现在还没有接入到前端, 你是不是梳理一个需求清单, 把这些复刻需要接入到前端的功能, 罗列个需求清单"
> 真值源: wenshu repo Sources/WenshuApp/Core/ (14 真值模块, 老板 8/19 + cc-runner 22:27+ 跑完) + Sources/WenshuApp/Views/ (Layout + Library 已有)

## Problem Statement

老板 2026-08-19 evening 拍: wenshu 后端 (Sources/WenshuApp/Core/) 有 14 真值模块 (Memory / Skill / Agent / Kanban / Todo / Tools / Cron / Backup / MiniMax 验证 + cc-runner 加 Canvas/LinkGraph/Outline/Search/Templates/WordCount) 但**前端没接入**。要梳理需求清单。

业务语言描述 (老板懂):
- 后端跑完, 前端没接
- 老板需要 1 张需求清单 = 哪些模块接前端 + 怎么接 + 工作量
- wenshu 定位 = SwiftUI 桌面写作 app (跟 Pages / Scrivener 一样)
- 接前端按 Apple HIG 真值 (Apple native UI, SwiftUI)

## 现状 (Q22 真验证)

后端真值模块 (Sources/WenshuApp/Core/, 14 真值):
- Memory (MemoryStore.swift) — 本地 SQLite 长期记忆
- Skill (SkillRegistry.swift) — 本地 SKILL.md 加载
- Agent (AgentProtocol.swift + AgentRuntime.swift + MiniMaxVerifier.swift) — A2A 协议 + 多 agent + MiniMax 验证
- Kanban (KanbanStore.swift) — 本地 Kanban + 7 状态
- Todo (TodoStore.swift) — 本地 Todo + 4 状态 + 4 优先级
- Tools (FileTools / ProcessTools / WebTools / VisionTools / AVMediaTools) — 5 工具
- Cron (Cronjob.swift) — 本地 cron 任务
- Backup (Backup.swift) — 本地项目备份
- cc-runner 22:27+ 加后端: Canvas / LinkGraph / Outline / Search / Templates / WordCount

前端现状 (Sources/WenshuApp/Views/):
- Layout/ — LayoutShellView (6 区 layout)
- Library/ — LibraryOutlineView (项目侧栏真实内容)

未接入前端的模块 = **全部 14 真值模块** (除 Layout / Library 已有)

## 需求清单 (按 wenshu 定位 + 工作量 + 优先级)

| # | 需求 | 模块 | 接入方式 (Apple HIG) | 工作量 | 优先级 | 验收 |
|---|---|---|---|---|---|---|
| 01 | **Memory UI** | MemoryStore | SwiftUI .onAppear 注入, Toolbar "记忆" 按钮 + Popover 显示 add / search 列表 | 中 | 🔥 高 | 老板可查"wenshu 写过什么" |
| 02 | **Skill UI** | SkillRegistry | 设置菜单 (cmd+,) 加 "Skills" 列表, 显示已加载 skill + invoke input | 中 | 🔥 高 | 老板可手动 invoke skill |
| 03 | **MiniMax Agent UI** | AgentProtocol + MiniMaxVerifier | 工具栏加 "Agent" 按钮, 弹 chat sheet (用户发消息 → agent 回复) | 大 | 🔥 高 | 老板能直接跟 MiniMax 聊天 |
| 04 | **Kanban UI** | KanbanStore | 侧栏加 "项目" 标签, 显示 wenshu 项目 kanban (backlog / in-progress / done) | 中 | 🟡 中 | 老板看 wenshu 自己的项目进度 |
| 05 | **Todo UI** | TodoStore | 侧栏加 "今日" 标签, 显示 due / priority todo, 简版 GTD | 中 | 🟡 中 | 老板有 wenshu 内部 todo |
| 06 | **File Tools UI** | FileTools | 编辑器右键菜单 + Toolbar "打开/保存" 按钮 (Apple NSOpenPanel + NSSavePanel) | 小 | 🟡 中 | 老板在 wenshu 内 import/export 文本 |
| 07 | **Process UI** | ProcessTools | 工具栏加 "运行" 按钮, 弹 NSTextField 输入 shell command, 输出在 sheet | 中 | 🟢 低 | 老板在 wenshu 内跑脚本 |
| 08 | **Web Fetch UI** | WebTools | 编辑器右键 "Insert URL" → fetch + extract + insert markdown | 中 | 🟡 中 | 老板抓网页内容到 wenshu |
| 09 | **Vision UI** | VisionTools | 编辑器右键 "OCR 图片" → recognizeText → insert text | 中 | 🟡 中 | 老板 OCR 截图插文字 |
| 10 | **TTS UI** | AVMediaTools | 工具栏加 "朗读" 按钮 → speak 选中文本 (AVSpeechSynthesizer) | 小 | 🟢 低 | 老板能听 wenshu 朗读 |
| 11 | **Cron UI** | Cronjob | 设置菜单加 "定时任务" 列表, 显示 cron 任务 + 启停 | 中 | 🟢 低 | 老板能设定时任务 |
| 12 | **Backup UI** | Backup | 工具栏加 "备份" 按钮 → 弹 sheet 显示 backup 列表 + restore | 中 | 🟢 低 | 老板能备份 wenshu 项目 |
| 13 | **Multi-Agent UI** | AgentRuntime | Settings "代理" 标签, 显示已注册 agent + delegate 按钮 | 大 | 🟡 中 | 老板能手动派任务给 agent |
| 14 | **Canvas UI** | Canvas 后端 | 工具栏加 "Canvas" 按钮 → 弹 JSON Canvas 视图 (跟 Obsidian 兼容) | 大 | 🟡 中 | 老板能画思维导图 |
| 15 | **LinkGraph UI** | LinkGraph 后端 | 编辑器 [[wikilink]] 自动补全 + Backlinks 面板 | 中 | 🟡 中 | 老板 wiki-link 互联 |
| 16 | **Outline UI** | Outline 后端 | 侧栏加 "大纲" 标签, 显示文档 heading 树 (点击跳转) | 小 | 🟡 中 | 老板看章节结构 |
| 17 | **Search UI** | Search 后端 | Toolbar "搜索" 按钮 (cmd+shift+f) → 弹 full-text search sheet | 中 | 🟡 中 | 老板全文搜 |
| 18 | **Templates UI** | Templates 后端 | "新建" 按钮 → 模板选择 sheet (空白 / 章节 / 短篇 / 笔记) | 中 | 🟢 低 | 老板用模板开新项目 |
| 19 | **Word Count UI** | WordCount 后端 | 状态栏加字数 / 段落数 (选中区域) | 小 | 🔥 高 | 老板看实时字数 |

## 优先级拍

按"wenshu 写作 app 核心需求" + 老板 8/19 evening 真验过 MiniMax:
- 🔥 **高 (3)**: Memory + Skill + MiniMax Agent + Word Count
- 🟡 **中 (8)**: Kanban + Todo + File Tools + Web Fetch + Vision + Multi-Agent + Canvas + LinkGraph + Outline + Search
- 🟢 **低 (5)**: Process + TTS + Cron + Backup + Templates

## 接入方式真值 (Apple HIG)

按 4 原则 1 伪 Apple 官方:
- 工具栏: SwiftUI `.toolbar { Button { } }` (Apple HIG 真值)
- 弹窗: SwiftUI `.sheet { }` (Apple HIG 真值)
- 设置: SwiftUI `Settings { }` (Apple 官方真值, 已用 in commit 4c42fa79)
- 侧栏: SwiftUI `NavigationSplitView` 或 `HSplitView` (Apple HIG 真值)
- 状态栏: SwiftUI `.safeAreaInset(edge: .bottom)` (Apple 真值)
- 文件选择: NSOpenPanel / NSSavePanel (AppKit 真值)
- 快捷键: `.keyboardShortcut("k", modifiers: .command)` (Apple HIG 真值)

## 业务语言描述 (老板懂)

- 14 模块前端接入 = 19 个 UI 需求 (含 cc-runner 加的 6 个后端)
- 按"wenshu 写作 app 核心"拍优先级 (3 高 / 8 中 / 5 低)
- 用 Apple HIG 真值 (SwiftUI + AppKit, 不引第三方 SDK)
- 工程管理老板授权 (老板 8/19 拍 "你自行决策") + 不需要验收

## Implementation Decisions

按 po main flow 拍 19 ticket 串行:
- 每个 ticket 1 commit + push (老板 8/19 工程管理授权)
- 每个 ticket 跑完整 po main flow 6 步 (grill + spec + ticket + impl + code-review + domain-modeling)
- 高优先级 3 ticket 优先 (Memory + Skill + MiniMax Agent + Word Count)
- 跳过不属于 wenshu 写作 app 的需求 (e.g. 智能家居, 通讯, 浏览器自动化)
- 不动 hermes (read-only)
- 不破坏 macOS chrome 52 PT / LayoutTokens / bandH / 拖拽线 (cursor / hover / drag / 1 PT / 颜色 / 圆头)

## 业务语言描述 (老板懂)

- wenshu 14 模块前端接入 = 19 UI 需求 (3 高 / 8 中 / 5 低)
- 按"wenshu 写作 app 核心"拍
- Apple HIG 真值 (SwiftUI + AppKit, 不引第三方 SDK)
- 工程管理老板授权 (8/19 evening 拍 "你自行决策") + 不需要验收

## Out of Scope

- 不动 hermes
- 不实现 AppleHome / AppleMessages / Mail / Contacts / Calendar / Reminders / Notes / Photos (wenshu 写作 app 不集成)
- 不复刻 hermes 全能力 (前面已拍跳过 9 个)
- 不重写 WenshuApp SwiftUI UI 整体架构 (增量加 toolbar / sheet / settings)
- 不实现 35 个 po 大神 skill 的前端 UI (复刻核心就够)

## 进一步信息

- 现有前端: Sources/WenshuApp/Views/Layout/ (LayoutShellView) + Library/ (LibraryOutlineView)
- 现有设置: Settings scene (commit 4c42fa79) — 扩展加 Memory / Skill / Agent / Cron / Backup / Kanban 等标签
- 现有 Toolbar: 顶/底 30 PT (LayoutTokens.toolbarHeight) — 增量加按钮
- 现有 Notifications: NotificationCenter.default (命令菜单 "恢复默认布局" 用) — 扩展加 cross-module 通知

## 真值引用 (Apple HIG)

- 工具栏: https://developer.apple.com/documentation/swiftui/view/toolbar
- 弹窗: https://developer.apple.com/documentation/swiftui/view/sheet
- Settings scene: https://developer.apple.com/documentation/swiftui/scene/settings
- NavigationSplitView: https://developer.apple.com/documentation/swiftui/navigationsplitview
- safeAreaInset: https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)
- keyboardShortcut: https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:localization:)
- NSOpenPanel: https://developer.apple.com/documentation/appkit/nsopenpanel
- NSSavePanel: https://developer.apple.com/documentation/appkit/nssavepanel
- AVSpeechSynthesizer: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer

## 老板拍的下一步

按 po main flow 串行 19 ticket, 每个 ticket 1 commit + push:
1. 19 ticket 全跑 (5+ 周工作量, 分批)
2. 按"wenshu 写作 app 核心"优先级 (3 高先)
3. 老板随时可打断拍新方向

## 任务清单简表 (1 张给老板看)

```
🔥 高 (3):
  01 Memory UI     — 老板可查"wenshu 写过什么"
  02 Skill UI      — 老板可手动 invoke skill
  03 MiniMax Agent UI — 老板能直接跟 MiniMax 聊天
  19 Word Count UI — 老板看实时字数

🟡 中 (8):
  04 Kanban UI     — 老板看 wenshu 自己的项目进度
  05 Todo UI       — 老板有 wenshu 内部 todo
  06 File Tools UI — 老板 import/export 文本
  08 Web Fetch UI  — 老板抓网页内容到 wenshu
  09 Vision UI     — 老板 OCR 截图插文字
  13 Multi-Agent UI — 老板手动派任务
  14 Canvas UI     — 老板画思维导图
  15 LinkGraph UI  — 老板 wiki-link
  16 Outline UI    — 老板看章节结构
  17 Search UI     — 老板全文搜

🟢 低 (5):
  07 Process UI    — 老板跑脚本
  10 TTS UI        — 老板听 wenshu 朗读
  11 Cron UI       — 老板设定时任务
  12 Backup UI     — 老板备份 wenshu 项目
  18 Templates UI  — 老板用模板开新项目
```

## 不动 hermes (老板 8/11 拍)

- read-only 盘代码
- 不修改 /Volumes/ANAN/.hermes/ 任何文件
- 不 patch /Volumes/ANAN/.hermes/hermes_cli/ 任何 .py