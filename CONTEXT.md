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
| **LayoutTokens** | 18 个 ratio (0~1) 算子 + designW=1920 + designH=984 基准, GeometryReader × 比例 = 任何窗口大小 1:1 自适应 | ADR-0006 |
| **Toolbar 高度写死 + VStack stretch** | 顶/底栏 30 PT 硬编码 (LayoutTokens.toolbarHeight, v0.15 ticket 008), 宽度不显式传, 由 SwiftUI VStack 子 view 默认 stretch 全宽自动撑 zone 实际宽度 (Apple HIG layout 默认行为, v0.16 ticket 01). 不画穿 splitter. | — |
| **拖拽线 NSView + NSEvent 范式** | 6 根拖拽线 (D_v1/D_v2/D_v3/D_v5/D_h) 用同一 NativeSplitter 1 组件 (老板 8/18 拍 "拖拽线是 1 组件"), 内部 SplitterHitArea: NSView 子类接管 mouseDown / mouseDragged / mouseUp + NSTrackingArea hover + NSCursor.push/pop, SplitterHitAreaRepresentable: NSViewRepresentable 桥接 (Apple AppKit 真值, 跟 Xcode / Pages / Numbers 一样, v0.16 ticket 03). SwiftUI DragGesture + .pointerStyle 在 macOS 27 VStack parent gesture 系统下失灵. | ADR-0003 |
| **数对公式** | 老板 8/18 拍 "多出来的都进聊天区, 用数对" = 拖拽线 1 PT 视觉线摊给左右 zone, 上 band 4 zone 数对 (200, 558, 762, 400) = 1920 + 下 band 3 zone 数对 (200, 1320, 400) = 1920 + H 数对 (39, 472, 472, 1) = 984 | ADR-0006 |
| **Drag Splitter** | 5 竖拖拽线 (D_v1/D_v2/D_v3/D_v4/D_v5, 1 PT 视觉线, intrinsicContentSize 1 PT) + 1 横拖拽线 (D_h inert, 老板 8/18 拍 50/50 锁定) | ADR-0003 + ADR-0006 |
| **视图菜单** | CommandMenu("视图") 顶级菜单 + "恢复默认布局" ⌘⇧R + NotificationCenter.default 桥接 vm.reset() (Apple HIG 范式) | ADR-0006 |
| **Appearance Mode** | wenshu 外观三态 (system / dark / light) — 跟 macOS 系统设置默认, 老板可在 Settings 弹窗 (cmd+,) 内 Picker 覆盖, @AppStorage 持久化到 UserDefaults | v0.17 |
| **WenshuCore** | wenshu 自己的本地核心库 (Sources/WenshuApp/Core/) — 替代 hermes 全能力, 用 Apple 体系实现. 9 真值模块: Memory / Skill / Agent / Kanban / Todo / Tools (File / Web / Process / Vision / AV) / Cron / Backup | v0.18 |
| **MemoryStore** | wenshu 本地 SQLite 长期记忆 (复刻 hermes mem0 platform 模式). actor 线程安全, schema: user_id / memory_id / content / created_at / updated_at. 接口 add / search / get / update / delete / count | v0.18 ticket 01 |
| **SkillRegistry** | wenshu 本地 Skills 加载 (复刻 hermes skills_hub 简化版). actor 线程安全, 扫 SKILL.md 解析 frontmatter + body. 接口 list / load / invoke | v0.18 ticket 02 |
| **A2A Protocol (AgentProtocol)** | wenshu agent 之间通信协议 (Google A2A spec 真值). JSON-RPC 2.0 style: message/send / task/get / task/list. actor in-process 简化版 | v0.18 ticket 03 |
| **AgentRuntime** | wenshu 多 agent registry + delegateTask + broadcast (复刻 hermes delegation 简化版). main agent 默认指向第一个注册的 agent | v0.18 ticket 04 |
| **KanbanStore** | wenshu 本地 Kanban (复刻 hermes kanban_db 简化版, 单表 + 7 状态). state machine: new → triage → ready → running → blocked → review → done (+ failed) | v0.18 ticket 05 |
| **TodoStore** | wenshu 本地 Todo (复刻 hermes todo 简化版). 4 状态 (pending / inProgress / completed / cancelled) + 4 优先级 (low / medium / high / urgent) + dueDate | v0.18 ticket 06 |
| **FileTools** | wenshu 本地 file 工具 (read / write atomic / patch 1 处 / search 递归 / list). Apple FileManager + URL 真值 | v0.18 ticket 07 |
| **ProcessTools** | wenshu 本地 process 工具 (run / runShell / isRunning). Apple Foundation Process 真值 | v0.18 ticket 08 |
| **WebTools** | wenshu 本地 web 工具 (URLSession fetch + HTML → markdown 转换). Apple URLSession 真值 | v0.18 ticket 09 |
| **VisionTools** | wenshu 本地 vision 工具 (文字识别 + 图像分类). Apple Vision framework 真值 (VNRecognizeTextRequest / VNClassifyImageRequest) | v0.18 ticket 10 |
| **AVMediaTools** | wenshu 本地 AV media 工具 (AVSpeechSynthesizer 朗读 + duration 估算). Apple AVFoundation 真值 | v0.18 ticket 11 |
| **Cronjob** | wenshu 本地 cron 任务管理 (5 字段 cron expression + 简单 nextRun 估算). Apple LaunchAgent 路径真值 (后续可生成 plist) | v0.18 ticket 21 |
| **Backup** | wenshu 本地项目备份 (复制源目录 + ISO 8601 时间戳命名 + 恢复 + 删). Apple FileManager 真值 | v0.18 ticket 26 |
| **MenuBar (NSMenu install)** | wenshu macOS 顶部菜单栏手动 install (NSMenu 真值) — 6 项: 文枢 / 文件 / 编辑 / 显示 / 窗口 / 帮助. 老板 8/19 真值报告: .commands 在 macOS 27 lazy menu populate (macOS 27 beta bug, 真因 vdhamer/Photo-Club-Hub-HTML#248). 修法: WenshuAppDelegate.applicationWillFinishLaunching 装 NSMenu, SwiftUI .commands 接管 content | v0.20 ticket 01 |
|| **Dock Logo (applicationIconImage)** | wenshu Dock logo NSImage 真值 (Apple HIG NSApplication.applicationIconImage). 老板 8/20 拍 LOGO 路径 /Users/anbaiqiang/Desktop/LOGO/wenshu-icon.icns (12K-369K 字节 真值文件). 修法: WenshuAppDelegate.applicationWillFinishLaunching 设 NSApp.applicationIconImage + activationPolicy = .regular. fallback SF Symbol book.closed | v0.20 ticket 01 |
|| **macOS27AppIcon (.app bundle)** | wenshu App icon 真值 = Apple HIG 标准 Cocoa .app bundle 范式. Sources/WenshuApp/Resources/AppIcon.icns (473 KB, 11 representations ic04/05/07/08/09/10/11/12/13/14/info) + Info.plist `CFBundleIconFile="AppIcon"` + `CFBundleIconName="AppIcon"`. Scripts/build-app.sh 拼 build/Wenshu.app/Contents/{MacOS/WenshuApp, Info.plist, Resources/AppIcon.icns} → ad-hoc codesign → open. Package.swift 删 `-sectcreate __TEXT __info_plist` linker flag (.app bundle 走 Contents/Info.plist 不走 linker). 裸 swift run 仍 work (AppKit process-tile placeholder). v0.20 ticket 04 + 05 |
| **NativeSplitter SwiftUI 真值** | wenshu 拖拽线 SwiftUI 范式 (替代 v0.16/v0.17 NSView 范式). SwiftUI Color.clear + .contentShape + .onContinuousHover + .pointerStyle + DragGesture 全在 SwiftUI view tree. 视觉 1 PT Apple 系统 separator 色 / hover 3 PT Apple 系统 controlAccentColor.opacity(0.25) + shadow / hit area 6 PT | v0.20 ticket 02 |

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
