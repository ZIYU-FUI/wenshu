# 文枢产品功能需求清单 — 老板 2026-08-19 evening 拍

> Date: 2026-08-19 evening
> 视角: 业务语言 (老板懂的产品功能, 不是技术清单)
> 真值源:
> 1. hermes 复刻 14 模块 (v0.18 ticket 01-31, commit `047b43cfa`..`c3b8a035e`)
> 2. Obsidian 复刻 11 模块 (v0.19 ticket 12-23, commit `bc4cfd76b`..`a85226c66`)
> 3. wenshu 现有框架: 6 区 layout / Book+Bookshelf+Document 3 类 / Library / LibraryOutlineView
> 4. wenshu 目标: Apple 全家桶长篇虚构小说 AI 创作平台, macOS-only, 自建轻量 AI 内核

## 一、核心叙事 — 文枢能做什么

**文枢 = 给长篇小说作者用的"全能工作台", 把 hermes 的 AI 能力 + Obsidian 的笔记能力 + 苹果原生 macOS 体验, 全部融进写小说的工作流里.**

一句话定位: "在文枢里, 你不用切出去打开浏览器 / 备忘录 / 写作软件 — 写小说需要的所有事, 都在这一个窗口."

老板 (写小说的人) 在文枢里能做的事:
1. 写小说 (主战场: 编辑器 + 大纲 + 人物 + 章节)
2. 管设定 (人物关系 / 势力图 / 时间线 / 地点)
3. 查资料 (网页抓取 / OCR 截图 / 本地文件 / 历史素材)
4. 跟 AI 协作 (聊天 / 让 AI 改稿 / 让 AI 查历史 / 调度其他 AI agent)
5. 管进度 (字数 / 截止日期 / 章节看板 / 写作日历)
6. 备份 / 恢复 / 跨书架切换

## 二、用户旅程 — 老板的一天

| 阶段 | 老板做什么 | 文枢哪些模块帮忙 |
|---|---|---|
| 1. 早上开电脑 | 打开文枢, 看到昨晚写到哪 + 今日字数 + 截止日期 | WordCount (字数) + Todo (今日 todo) + MiniMax Agent (跟 AI 问早安 / 提醒) + Bookmarks (上次收藏) |
| 2. 列今日写作大纲 | 看 Outline 树 + 翻 Bases 人物表 | Outline (章节树) + Bases (人物表) + Graph (人物关系图) |
| 3. 开始写章节 | 编辑器主区, 边写边插 [[林黛玉]] 自动补全 | Wikilink 编辑器渲染 + Backlinks (反向链接, 看 [[林黛玉]] 在哪些章节出现过) + Search (搜"飞鸟集"等设定) |
| 4. 卡壳 | 跟 AI 聊天, 让 AI 帮续写 | MiniMax Agent (chat sheet) + Skill (调续写 skill) + Multi-Agent (派给改稿 agent) |
| 5. 查资料 | 搜资料, 抓网页, OCR 截图 | Web Fetch (右键 Insert URL) + Vision (右键 OCR 图片) + File Tools (本地文件 import) |
| 6. 写完一章 | 跑字数统计 + 标完成 | WordCount (顶栏右实时) + Bases (章节进度表) + Kanban (章节看板) |
| 7. 晚上存档 | 改章节名 / 合并章节 / 自动备份 | Note Composer (rename / merge / split, 自动重写链接) + Backup (Toolbar 备份按钮) |
| 8. 写作白板 | 画人物关系图 / 情节线 | Canvas (Toolbar Canvas 按钮, 弹 JSON Canvas 视图, 跟 Obsidian 兼容) |
| 9. 听章节 | TTS 朗读检查节奏 | TTS (Toolbar 朗读按钮) |
| 10. 定时任务 | 设定时自动保存 / 自动备份 | Cron (Settings 定时任务) |
| 11. 跨书架 | 写另一本书, 切换 | Quick Switcher (⌘O 弹窗, 跨书架 fuzzy 搜索) |
| 12. 写作历史 | 查"文枢写过什么" | Memory (Toolbar 记忆按钮 + Popover, 复刻 hermes mem0) |

## 三、需求清单 — 按模块分类 (业务语言)

### A. 写小说主战场 (P0, 必接)

| # | 业务需求 | 模块 | 来源 | 接入位置 |
|---|---|---|---|---|
| A1 | 打开文枢, 直接接着昨晚写 | 现有 Library + LibraryOutlineView | wenshu 现有 | 已实现, 不动 |
| A2 | 编辑器主区写章节, 跟 Pages 一样流畅 | 现有 BookEditorSheet | wenshu 现有 | 已实现, 不动 |
| A3 | 章节里写 [[林黛玉]] 自动变成蓝色下划线链接, ⌘+click 跳转 | InternalLink Parser + Wikilink 编辑器渲染 | v0.19 ticket 12 | 编辑器主区 文本渲染层 |
| A4 | 顶栏右实时显示当前章节字数 | WordCount | v0.19 ticket 20 | 顶栏右 widget |
| A5 | 编辑器右栏显示当前章节反向链接 (哪些其他章节引用了它) | BacklinksPanel | v0.19 ticket 12 | 编辑器右栏 panel tab |
| A6 | 编辑器右栏显示当前章节大纲 (H1-H6 跳转) | OutlinePanel | v0.19 ticket 21 | 编辑器右栏 panel tab (跟 Backlinks 共存) |
| A7 | 编辑器右栏全文搜章节内容 | SearchPanel | v0.19 ticket 17 | 编辑器右栏 panel tab |
| A8 | ⌘O 弹窗, fuzzy 搜所有书架的 note / 章节, 快速跳转 | QuickSwitcher | v0.19 ticket 19 | 全局快捷键 ⌘O (Apple Spotlight 同范式) |

### B. 管设定 (P0-P1, 强需求)

| # | 业务需求 | 模块 | 来源 | 接入位置 |
|---|---|---|---|---|
| B1 | 人物表: 显示所有人物 (姓名 / 年龄 / 关系 / 出场章节) | Bases 数据库视图 | v0.19 ticket 18 | 上 band 新 1 区 / 或右栏 panel tab |
| B2 | 人物关系图谱: 节点 = 人物, 边 = 关系 | Graph view | v0.19 ticket 14 | 上 band 新 1 区 / 或独立 tab |
| B3 | 势力 / 朝代 / 法宝 / 地点 表 | Bases (复用) | v0.19 ticket 18 | 同 B1 |
| B4 | 写作白板: 画情节线 / 关系图 (跟 Obsidian Canvas 兼容) | Canvas + JSON Canvas 1:1 | v0.19 ticket 13 | Toolbar Canvas 按钮 / 或独立 tab |
| B5 | 写章节大纲时, 自动应用模板 (章节 / 短篇 / 笔记) | Templates | v0.19 ticket 15 | Toolbar "新建" 按钮 → 模板选择 sheet |
| B6 | 时间线 / 章节进度表 | Bases (复用) | v0.19 ticket 18 | 同 B1 |

### C. AI 协作 (P0-P1, 强需求)

| # | 业务需求 | 模块 | 来源 | 接入位置 |
|---|---|---|---|---|
| C1 | 跟 AI 聊天, 让 AI 续写 / 改稿 | MiniMax Agent | v0.18 ticket 03+31 (MiniMaxVerifier) | Toolbar "Agent" 按钮 → chat sheet |
| C2 | 老板能手动 invoke 35 个 skill (续写 / 翻译 / 校对 / 风格转换) | Skill UI (复刻 hermes skills_hub) | v0.18 ticket 02 | Settings → Skills 列表 |
| C3 | 派任务给其他 agent (改稿 agent / 校对 agent / 翻译 agent) | Multi-Agent UI | v0.18 ticket 04 | Settings → 代理 列表 |
| C4 | 查"文枢之前写过什么" (长期记忆) | Memory UI | v0.18 ticket 01 | Toolbar "记忆" 按钮 + Popover |

### D. 查资料 / 处理文本 (P1)

| # | 业务需求 | 模块 | 来源 | 接入位置 |
|---|---|---|---|---|
| D1 | 抓网页内容到文枢 (查资料) | Web Fetch | v0.18 ticket 09 | 编辑器右键 "Insert URL" |
| D2 | OCR 截图, 把图里的文字插到章节里 | Vision | v0.18 ticket 10 | 编辑器右键 "OCR 图片" |
| D3 | 导入本地文本文件 / 导出章节为文件 | File Tools | v0.18 ticket 07 | 编辑器右键菜单 + Toolbar 打开/保存 |
| D4 | TTS 朗读当前章节 (听节奏) | TTS / AVMedia | v0.18 ticket 11 | Toolbar "朗读" 按钮 |
| D5 | 在文枢内跑 shell 脚本 (批量处理) | Process | v0.18 ticket 08 | Toolbar "运行" 按钮 + NSTextField 输入 |

### E. 管进度 / 管时间 (P1)

| # | 业务需求 | 模块 | 来源 | 接入位置 |
|---|---|---|---|---|
| E1 | 章节看板: backlog / in-progress / done | Kanban UI | v0.18 ticket 05 | 侧栏 "项目" 标签 |
| E2 | 今日 todo (简版 GTD) | Todo UI | v0.18 ticket 06 | 侧栏 "今日" 标签 |
| E3 | 定时任务 (自动保存 / 自动备份) | Cron UI | v0.18 ticket 21 | Settings "定时任务" 列表 |

### F. 管文档 / 编辑工具 (P1-P2)

| # | 业务需求 | 模块 | 来源 | 接入位置 |
|---|---|---|---|---|
| F1 | 重命名章节, 自动重写所有 [[旧名]] → [[新名]] | Note Composer (rename) | v0.19 ticket 16 | 文件菜单 → 重命名 (跟 #5 Backlinks 联动) |
| F2 | 合并两个章节 → 自动重写链接 | Note Composer (merge) | v0.19 ticket 16 | 文件菜单 → 合并 |
| F3 | 拆分一个章节 → 自动重写链接 | Note Composer (split) | v0.19 ticket 16 | 文件菜单 → 拆分 |
| F4 | 收藏重要章节 / 设定片段 (跨书架) | Bookmarks UI | v0.19 ticket 22 | Toolbar 添加按钮 + ⌘⇧B 弹窗 + 编辑器右栏 tab |

### G. 数据安全 / 自动化 (P2)

| # | 业务需求 | 模块 | 来源 | 接入位置 |
|---|---|---|---|---|
| G1 | 一键备份整个项目, 跨书架 | Backup UI | v0.18 ticket 26 | Toolbar "备份" 按钮 |
| G2 | 定时自动备份 | Cron + Backup 联动 | v0.18 ticket 21+26 | Settings 定时任务 |

## 四、模块关联关系 (模块依赖图)

```
[wenshu 现有框架]
  Library / LibraryOutlineView / Book / Bookshelf / Document / FileSystemLibraryStore
     ↑
     │
[Obsidian 复刻 (写小说)]
     │
     ├─ LinkGraph (LinkIndex + InternalLinkParser + BacklinkResolver)
     │   └─ 依赖: 现有 Document
     │
     ├─ Search (FullTextSearch SQLite FTS5)
     │   └─ 依赖: 现有 Document content
     │
     ├─ Outline (OutlineExtractor)
     │   └─ 依赖: 现有 Document content
     │
     ├─ WordCount (WordCounter)
     │   └─ 依赖: 现有 Document content
     │
     ├─ Canvas / Graph / Bases / Templates / Composer
     │   └─ 依赖: 现有 Document + LinkIndex (Composer 联动 Backlinks)
     │
     ├─ QuickSwitcher (fuzzy search)
     │   └─ 依赖: 现有 Library (跨书架)
     │
     └─ Bookmarks (BookmarkStore)
         └─ 依赖: 现有 Library / Document
     ↑
     │
[hermes 复刻 (AI + 工具)]
     │
     ├─ Memory (MemoryStore SQLite, 复刻 hermes mem0)
     │   └─ 独立, 跟现有 Document 关联 (Memory 内容可来自 Document)
     │
     ├─ Skill (SkillRegistry, 复刻 hermes skills_hub)
     │   └─ 独立, 通过 Skill UI invoke
     │
     ├─ Agent (AgentProtocol + AgentRuntime + MiniMaxVerifier)
     │   └─ 依赖: SkillRegistry (agent 调用 skill) + Memory (agent 查记忆)
     │
     ├─ Kanban / Todo (项目进度 + GTD)
     │   └─ 跟现有 Document 关联 (章节 = kanban task)
     │
     ├─ File / Process / Web / Vision / AV (工具集)
     │   └─ 独立, 通过编辑器官右键菜单 / Toolbar 接入
     │
     └─ Cron / Backup (自动化 + 备份)
         └─ 独立, 通过 Settings / Toolbar 接入
```

**关键联动 (老板接入时一起做):**

1. **LinkGraph 联动**: Wikilink 编辑器渲染 + Backlinks 面板 + [[wikilink]] 自动补全 — 同一 LinkIndex 三种接入
2. **Outline 联动**: 老板清单 (侧栏) + 我清单 (右栏) — 同一 OutlineExtractor 二选一接入
3. **Composer + Backlinks 联动**: rename 触发自动重写 → 必须接 Composer 同时接 Backlinks
4. **Memory + Document 联动**: Memory 内容从 Document 抽取, 老板查"写过什么"
5. **Agent + Skill 联动**: Agent 调用 Skill, chat sheet 选 skill
6. **Cron + Backup 联动**: 定时自动备份

## 五、优先级 + 接入顺序 (业务价值排序)

### � P0 必接 (1-2 周, 写小说的核心体验)

| # | 业务需求 | 接入后老板能立刻做什么 |
|---|---|---|
| A3 | Wikilink 编辑器渲染 | 章节里写 [[林黛玉]] 自动链接, 一跳就到 |
| A4 | 顶栏字数 badge | 实时知道今天写多少字 |
| A5 | Backlinks 面板 | 写当前章节时看到所有引用它的设定 |
| A6 | Outline 面板 | 编辑器右栏看大纲, 点击跳章节 |
| A7 | Search 全文搜索 | ⌘F 搜"飞鸟集"等设定片段 |
| A8 | Quick Switcher ⌘O | 跨书架快速跳 |
| C1 | MiniMax Agent chat | 跟 AI 聊续写 |
| C2 | Skill UI | 手动 invoke 35 skill |
| C4 | Memory UI | 查"文枢写过什么" |

### 🟡 P1 核心增强 (2-3 周, 让文枢比单纯编辑器更值)

| # | 业务需求 | 接入后老板能做什么 |
|---|---|---|
| B1-B6 | Bases / Graph / Canvas / Templates (B 系列) | 人物表 / 关系图 / 白板 / 模板, 写作工作流完整 |
| D1-D5 | 工具集 (D 系列, Web / Vision / File / TTS / Process) | 编辑器右键菜单 / Toolbar 一键查资料 |
| E1-E3 | Kanban / Todo / Cron (E 系列) | 进度管理 + 定时任务 |
| F1-F4 | Composer / Bookmarks (F 系列) | 重命名章节自动重写链接 + 收藏 |

### 🟢 P2 收尾 (3-4 周, 锦上添花)

| # | 业务需求 | 接入后老板能做什么 |
|---|---|---|
| C3 | Multi-Agent UI | 派任务给多个 AI agent |
| D5 | Process / TTS | 跑脚本 + 听章节 |
| G1-G2 | Backup + Cron 联动 | 定时自动备份 |

## 六、最终实现的功能 (老板 macOS 验后, 文枢能做的事)

### 老板写小说的一天 (接入全部后)

```
07:00  打开文枢 → 看到昨晚写到第几章 + 今日 todo + AI 提醒 (Memory / Todo / MiniMax)
07:10  看大纲, 翻人物表, 看人物关系图 (Outline / Bases / Graph)
07:30  开始写章节 → 边写边插 [[林黛玉]] 自动跳转 (Wikilink / Backlinks)
08:00  卡壳 → 跟 AI 聊天续写 / invoke skill (MiniMax Agent / Skill)
08:30  查资料 → 抓网页 / OCR 截图 (Web Fetch / Vision)
09:00  写完一章 → 跑字数 / 标完成 / 加入看板 (WordCount / Kanban)
12:00  中午休息 → 听昨晚写的章节 (TTS)
18:00  晚上写作 → 画情节白板 (Canvas)
19:00  改章节名 → 自动重写所有链接 (Composer + Backlinks 联动)
20:00  收藏重要片段 → ⌘⇧B 弹窗 (Bookmarks)
22:00  存档 → 一键备份 / 定时自动备份 (Backup / Cron)
23:00  跨书架写另一本 → ⌘O 快速跳 (Quick Switcher)
```

### 文枢最终能力 (26 项业务需求全部接入)

| 维度 | 能力 |
|---|---|
| 写作 | 编辑器主区 + 实时字数 + 反向链接 + 大纲跳转 + 全文搜索 + wikilink 渲染 |
| 设定 | 人物表 + 关系图 + 势力图 + 写作白板 (Obsidian Canvas 兼容) + 模板 |
| AI | 跟 AI 聊天 + invoke 35 skill + 派给其他 agent + 查长期记忆 |
| 资料 | 抓网页 + OCR 截图 + 导入本地文件 + 朗读 + 跑脚本 |
| 进度 | 章节看板 + 今日 todo + 定时任务 |
| 编辑 | 重命名章节 + 自动重写链接 + 合并 + 拆分 |
| 安全 | 一键备份 + 定时自动备份 |

**文枢 = Apple 全家桶长篇小说 AI 创作平台 = 写小说需要的所有事, 都在一个窗口.**

## 七、跟 LayoutTokens 死原则的冲突 (需老板拍)

| 需求 | 冲突 | 备选 |
|---|---|---|
| B1 Bases 独立区 | 上 band 4 → 5 区, 跟 ticket 14 死原则冲突 | 用 panel tabs 切换 (编辑器右栏多 tab, Bases 跟 Outline/Backlinks/Search 共享) |
| B2 Graph 独立区 | 同 Bases | 同上 |
| B4 Canvas 独立区 | 同 Bases | 同上 |

**建议**: Bases / Graph / Canvas 都用 panel tabs 接入, 不动 LayoutTokens 死原则.

## 八、跟现有 6 区 layout 的整合

```
顶栏 (titleBar)
├─ A4 字数 badge (右)
├─ A8 Quick Switcher 入口 (右图标)
├─ C1 Agent 入口 (右图标)
├─ C2 Skill 入口 (右图标)
├─ C4 Memory 入口 (右图标)
├─ D3 File 打开/保存 (右)
├─ D4 TTS 朗读 (右)
├─ D5 Process 运行 (右)
├─ F4 Bookmark 添加 (右)
└─ G1 Backup (右)

上 band (4 区)
├─ 1 区 (200 PT 项目侧栏): E1 Kanban / E2 Todo (NavigationSplitView 侧栏叠加)
├─ 2 区 (520 PT 项目预览): 现有
├─ 3 区 (794 PT 编辑器): A2 现有编辑器主区 + A3 wikilink 渲染
│   └─ 编辑器右栏 (panel tabs): A5 Backlinks / A6 Outline / A7 Search / F4 Bookmarks (4 tab 切换)
└─ 4 区 (400 PT 工具): 现有

下 band (2 区)
├─ 1 区 (1518 PT AI 聊天): 现有 + C1 MiniMax Agent chat (整合)
└─ 2 区 (400 PT AI 动态): 现有
```

**不动 LayoutTokens 死原则 (1920×984 PT 1:1 锁定)** — 所有新增 UI 通过顶栏 / 工具栏 / 侧栏 / 编辑器右栏 panel tabs 接入.

## 九、待办 (老板拍)

1. 拍 P0 开工 (9 项业务需求, 1-2 周)
2. 拍 Bases / Graph / Canvas 走 panel tabs (避开 LayoutTokens 死原则)
3. 拍 Outline 走右栏 or 侧栏 (老板另一会话的清单 + 我清单冲突)
4. 拍后续 ticket 排期: ticket 24 (panel tabs 框架) + ticket 25+ (按 Phase 顺序)
