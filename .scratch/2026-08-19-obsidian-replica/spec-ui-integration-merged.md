# v0.19 前端接入需求合并清单 (老板 2026-08-19 evening)

> Date: 2026-08-19 evening
> 真值源:
> 1. 老板 2026-08-19 evening 拍的另一会话清单 (18 项 UI 需求, 含 4 高 + 10 中 + 5 低, hermes 复刻 18 模块前端接入)
> 2. 我自己的 v0.19 spec-ui-integration.md (19 项 UI 需求, Obsidian 复刻 12 模块前端接入)
> 3. v0.18 ticket 09-31 commit 真值 (本地后端模块已全部 push)
> 4. v0.19 ticket 12-23 commit 真值 (Obsidian 复刻后端 + standalone SwiftUI View)

## 合并原则

1. **同模块不重复** (e.g. hermes Memory + Obsidian 没交叉)
2. **联动点单独标 "🔗 联动"** — 老板后续接入时要一起做
3. **优先级保留两清单的** — 老板自己拍的优先级, 不擅自改
4. **冲突点单独标 "⚠️ 冲突"** — 跟 LayoutTokens 死原则冲突 / 模块边界重叠

## 总览 (老板另一会话 18 项 + 我自己 19 项 = 36 项, 合并去重 = 32 项)

| 优先级 | 数量 | 来源 |
|---|---|---|
| 🔥 高 | 7 (含 1 我加的) | 老板 4 项 + 我 3 项 |
| 🟡 中 | 14 (含 1 老板新增的) | 老板 10 项 + 我 4 项 |
| 🟢 低 | 5 | 老板 5 项 |
| 不接入 | 8+ | 两清单交集 + 按 wenshu 定位排除 |

## 🔥 高 (7 项)

| # | 需求 | 来源 | 模块 / ticket | 联动 / 备注 |
|---|---|---|---|---|
| 1 | **Memory UI** | 老板 4-01 | MemoryStore (v0.18 ticket 01, commit `047b43cfa`) | SwiftUI `.onAppear` 注入 + Toolbar "记忆" 按钮 + Popover |
| 2 | **Skill UI** | 老板 4-02 | SkillRegistry (v0.18 ticket 02, commit `b5c219f3b`) | Settings scene (Settings commit `4c42fa79` 已有) + Skills 列表 |
| 3 | **MiniMax Agent UI** | 老板 4-03 | AgentProtocol + MiniMaxVerifier (v0.18 ticket 03 + 31) | Toolbar "Agent" 按钮 + chat sheet (跟 LayoutShellView 顶栏整合) |
| 4 | **Word Count UI** | 老板 4-19 + 我清单 #1 + #12 | WordCounter (v0.19 ticket 20, commit `2d3ede1b3`) | 老板清单: 状态栏字数; 我清单: 顶栏 badge + 编辑器右上; **🔗 合并: 顶栏右 widget + 实时选中区域字数** |
| 5 | **Backlinks UI** | 我清单 #3 | BacklinksPanel (v0.19 ticket 12, commit `bc4cfd76b`) | 老板清单 #15 LinkGraph UI 包含 Backlinks, 跟 wikilink 自动补全一起做 |
| 6 | **Outline UI** | 我清单 #2 | OutlinePanel (v0.19 ticket 21, commit `fd4708264`) | 老板清单 #16 Outline 包含, 跟侧栏 "大纲" 标签整合 |
| 7 | **Quick Switcher UI** | 我清单 #5 + #16 | QuickSwitcherWindow (v0.19 ticket 19, commit `62f788ed4`) | ⌘O 全局快捷键 (Apple Spotlight 同范式) |

## 🟡 中 (14 项)

| # | 需求 | 来源 | 模块 / ticket | 联动 / 备注 |
|---|---|---|---|---|
| 8 | **Kanban UI** | 老板 4-04 | KanbanStore (v0.18 ticket 05, commit `2172c421c`) | 侧栏 NavigationSplitView "项目" 标签 |
| 9 | **Todo UI** | 老板 4-05 | TodoStore (v0.18 ticket 06, commit `4551ce0af`) | 侧栏 "今日" 标签 (简版 GTD) |
| 10 | **File Tools UI** | 老板 4-06 | FileTools (v0.18 ticket 07, commit `a48a0904d`) | 编辑器右键菜单 + Toolbar 打开/保存按钮 (NSOpenPanel + NSSavePanel) |
| 11 | **Web Fetch UI** | 老板 4-08 | WebTools (v0.18 ticket 09, commit `c082e5c07`) | 编辑器右键 "Insert URL" → fetch + extract + insert markdown |
| 12 | **Vision UI** | 老板 4-09 | VisionTools (v0.18 ticket 10, commit `c231d9d21`) | 编辑器右键 "OCR 图片" → recognizeText → insert text |
| 13 | **Multi-Agent UI** | 老板 4-13 | AgentRuntime (v0.18 ticket 04, commit `a1b12d810`) | Settings "代理" 标签 + delegate 按钮 |
| 14 | **Canvas UI** | 老板 4-14 + 我清单 #6 | JSONCanvasCodec + CanvasView (v0.19 ticket 13, commit `265f68ec0`) | **⚠️ 冲突: 上 band 4 区 → 5 区, 跟 LayoutTokens 死原则冲突, 需老板拍** 或用 panel tabs 避开 |
| 15 | **LinkGraph UI** | 老板 4-15 | BacklinksPanel + QuickSwitcher (v0.19 ticket 12) | **🔗 联动: 跟 #5 Backlinks UI 合并, 编辑器 [[wikilink]] 自动补全 + Backlinks 面板** |
| 16 | **Outline UI (侧栏)** | 老板 4-16 | OutlinePanel (v0.19 ticket 21) | **🔗 联动: 跟 #6 合并, 同一模块同一接入位置** |
| 17 | **Search UI** | 老板 4-17 + 我清单 #5 | SearchPanel (v0.19 ticket 17, commit `211bfc960`) | ⌘⇧F (老板版) / ⌘F (我版) — **🔗 合并: �F 全局 (跟 Obsidian 一致), ⌘⇧F 进 advanced** |
| 18 | **Bases UI** | 我清单 #7 | BaseView (v0.19 ticket 18, commit `3119ef559`) | **⚠️ 冲突: 同 Canvas, layout 冲突, 用 panel tabs 避开** |
| 19 | **Note Composer UI** | 我清单 #9 / #10 / #14 | ComposerPanel (v0.19 ticket 16, commit `a2932eeb7`) | 文件菜单 → Composer submenu (rename / merge / split) |
| 20 | **Templates UI (文件菜单)** | 老板 4-18 + 我清单 #11 | TemplatePicker (v0.19 ticket 15, commit `1edc9a7b8`) | 老板清单: "新建" 按钮 → 模板选择 sheet; 我清单: 文件菜单 → 选模板 — **🔗 合并: Toolbar "新建" + 文件菜单** |
| 21 | **Wikilink 编辑器渲染** | 我清单 #8 / #9 | InternalLinkParser + BacklinkResolver (v0.19 ticket 12) | **🔗 联动: 跟 #5 / #15 LinkGraph UI 一起做** |

## � 低 (5 项)

| # | 需求 | 来源 | 模块 / ticket | 联动 / 备注 |
|---|---|---|---|---|
| 22 | **Process UI** | 老板 4-07 | ProcessTools (v0.18 ticket 08, commit `a4f251692`) | Toolbar "运行" 按钮 + NSTextField 输入 |
| 23 | **TTS UI** | 老板 4-10 | AVMediaTools (v0.18 ticket 11, commit `9fb1d5257`) | Toolbar "朗读" 按钮 (AVSpeechSynthesizer) |
| 24 | **Cron UI** | 老板 4-11 | Cronjob (v0.18 ticket 21, commit `ce851abda`) | Settings "定时任务" 列表 |
| 25 | **Backup UI** | 老板 4-12 | Backup (v0.18 ticket 26, commit `e6b970b03`) | Toolbar "备份" 按钮 + sheet |
| 26 | **Bookmarks UI** | 我清单 #17 / #18 / #19 | BookmarkPanel (v0.19 ticket 22, commit `569ebe1d6`) | ⌘⇧B (老板版) / 编辑器右栏 + Toolbar (我版) — **🔗 合并: Toolbar + ⌘⇧B 弹窗 + 编辑器右栏 tab** |

## � 联动组 (老板接入时要一起做)

| 联动组 | 包含需求 | 原因 |
|---|---|---|
| **LinkGraph 联动** | #5 Backlinks + #15 LinkGraph + #21 Wikilink | 同一模块 (LinkIndex) 三种接入: 编辑器渲染 / Backlinks 面板 / [[wikilink]] 自动补全 |
| **Outline 联动** | #6 + #16 | 同一模块 (OutlineExtractor), 我做右栏 / 老板做侧栏 — **🔗 合并: 同一接入位置 (右栏 / 侧栏二选一, 老板拍)** |
| **Search 联动** | #17 (两个快捷键) | 同一模块 (FullTextSearch), ⌘F 主 / ⌘�F advanced — **🔗 合并: 同一 sheet, ⌘F 进基础, ⌘⇧F 进 advanced** |
| **Templates 联动** | #20 (两个接入点) | 同一模块 (TemplatePicker), Toolbar + 文件菜单 — **🔗 合并: Toolbar 入口 + 文件菜单 submenu 入口** |
| **Bookmarks 联动** | #26 (三个接入点) | 同一模块 (BookmarkPanel), Toolbar + ⌘⇧B 弹窗 + 编辑器右栏 — **🔗 合并: Toolbar 添加 + ⌘�B 弹窗列表 + 编辑器右栏** |
| **Composer 联动** | #19 (rename / merge / split) | 同一模块 (NoteComposer), 文件菜单 submenu — 跟 #5 Backlinks 联动 (rename 触发自动重写) |

## ⚠️ 冲突点 (老板拍才能动)

| 冲突 | 影响 | 备选方案 |
|---|---|---|
| **Canvas 独立区** (#14) | 上 band 4 区 → 5 区, 跟 ticket 14 LayoutTokens 死原则冲突 (1920×984 PT 1:1 锁定) | 用 panel tabs 切换 (右栏多 tab, Canvas 跟 Outline / Backlinks 共享) — 不动 layout |
| **Bases 独立区** (#18) | 同 Canvas | 同上, panel tabs 切换 |

## 不接入清单 (两清单交集 + 按 wenshu 定位排除)

| 模块 | 不接入原因 | 来源 |
|---|---|---|
| Obsidian Sync | 闭源付费, wenshu 本地自管 | 我清单 |
| Obsidian Publish | 闭源付费 | 我清单 |
| Plugin API (动态加载) | wenshu 单 app 编译 | 我清单 |
| Mobile (iOS/Android) | wenshu macOS-only (老板 8/18 拍) | 我清单 |
| Web viewer (iframe) | 写作 app 不需要 | 我清单 |
| Daily Notes | 写作 app 不需要 | 我清单 |
| Command Palette (⌘⇧P) | wenshu `.commands` 顶级菜单已够 | 我清单 |
| Slash commands | 写作 app 不需要 | 我清单 |
| A2A 协议 (v0.18 ticket 03) | 后端复刻已完成, 前端不需要单独 UI, 通过 MiniMax Agent UI 接入 | 隐含 |

## 接入顺序建议 (按工作量大但稳 + 依赖关系)

### Phase 1 P0 强需求 (1-2 周)

1. **#1 Memory UI** (后端已完整, Toolbar 简单 widget)
2. **#2 Skill UI** (Settings 列表, 跟现有 Settings scene 整合)
3. **#3 MiniMax Agent UI** (Toolbar + chat sheet, 跟顶栏整合)
4. **#4 Word Count UI** (顶栏右 badge, 改动最小)
5. **#5 Backlinks UI** (编辑器右栏 panel tabs 框架先建)
6. **#6 Outline UI** (跟 #5 同右栏 tab 切换)
7. **#7 Quick Switcher UI** (⌘O 弹窗, 独立不冲突)

### Phase 2 P1 核心增强 (2-3 周)

8. **#8 Kanban UI** (侧栏 NavigationSplitView, 改动较大)
9. **#9 Todo UI** (侧栏)
10. **#10 File Tools UI** (右键菜单 + NSOpenPanel)
11. **#17 Search UI** (⌘F + ⌘⇧F sheet)
12. **#11 Web Fetch UI** (右键菜单)
13. **#12 Vision UI** (右键菜单 OCR)
14. **#19 Note Composer UI** (文件菜单 submenu, 跟 #5 联动)
15. **#20 Templates UI** (Toolbar + 文件菜单)

### Phase 3 P2 写作体验增强 (3-4 周)

16. **#21 Wikilink 编辑器渲染** (编辑器文本渲染层)
17. **#13 Multi-Agent UI** (Settings)
18. **#14 Canvas UI** (用 panel tabs 避开 layout)
19. **#18 Bases UI** (用 panel tabs 避开 layout)
20. **#26 Bookmarks UI** (Toolbar + ⌘⇧B + 右栏 tab)
21. **#15 LinkGraph UI** (跟 #5 一起做)
22. **#16 Outline 侧栏** (跟 #6 二选一)
23. **#22 Process UI** (Toolbar "运行" 按钮)
24. **#23 TTS UI** (Toolbar "朗读" 按钮)
25. **#24 Cron UI** (Settings 定时任务列表)
26. **#25 Backup UI** (Toolbar "备份" 按钮)

## LayoutTokens 死原则决策点

| 项 | 跟 LayoutTokens 关系 | 需老板拍? |
|---|---|---|
| #5/#6/#15/#16/#26 编辑器右栏 panel tabs | 共享右栏宽度, 不动 layout 比例 | ❌ 不冲突 |
| #7/#17 Quick Switcher / Search 弹窗 | 独立弹窗, 不影响 layout | ❌ 不冲突 |
| #8/#9 侧栏 NavigationSplitView | 上 band 不动, 加左侧 sidebar | ❌ 不冲突 (左 sidebar 跟 LayoutTokens 上 band 是不同层) |
| #14 Canvas 独立区 | 上 band 4 → 5 区, 改 LayoutTokens | ⚠️ 需老板拍 |
| #18 Bases 独立区 | 同 Canvas | �️ 需老板拍 |
| #1/#2/#3/#4/#13/#22/#23/#24/#25 Toolbar 按钮 | 顶栏 / 工具栏, 不影响上 band | ❌ 不冲突 |

## 待办 (老板拍下一步)

- 确认 Phase 1 开工 (7 项 P0)
- 确认 Canvas / Bases 走 panel tabs 避开 layout (或坚持独立区, 改 LayoutTokens)
- 确认合并清单覆盖完整性
- 后续 ticket 排期: ticket 24 (panel tabs 框架) + ticket 25+ (按顺序接入)
