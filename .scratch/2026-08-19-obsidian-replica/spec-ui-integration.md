# v0.19 Obsidian 复刻模块 → 前端接入需求清单

> 老板 2026-08-19 evening 拍: '梳理现在实现的模块, 整理出一个需求清单, 计划用在前端哪里'
> Date: 2026-08-19 evening
> 真值源: v0.19 ticket 12-23 后端模块 + standalone SwiftUI View 实现

## 总览 (12 模块 + 19 UI 接入需求)

| # | 模块 | ticket | 后端真值 | Standalone View 已实现 | 待接入前端位置 |
|---|---|---|---|---|---|
| 1 | Internal Link + Backlinks | 12 | LinkIndex (SQLite) + InternalLinkParser + BacklinkResolver | BacklinksPanel | 上 band 编辑器右栏 (跟随当前 doc) |
| 2 | Canvas + JSON Canvas | 13 | JSONCanvasCodec (Codable 1:1) | CanvasView | 上 band 新独立区域 (白板大纲 / 人物关系图) |
| 3 | Graph view | 14 | GraphBuilder (build + layout + local) | GraphView | 新独立 tab 或独立窗口 (全 vault 关系图) |
| 4 | Templates | 15 | TemplateEngine (date/time/title/author/custom tokens) | TemplatePicker | 文件菜单 → 新建 note (选模板) |
| 5 | Note Composer | 16 | NoteComposer (rename/merge/split) | ComposerPanel | 文件菜单 → 合并 / 拆分 / 重命名 note |
| 6 | Full Text Search | 17 | FullTextSearch (SQLite FTS5 trigram) | SearchPanel | 编辑器右上 �F (搜索框 + 高亮) |
| 7 | Bases 数据库视图 | 18 | BaseParser (.base YAML) | BaseView | 上 band 新独立区域 (人物表 / 章节进度表) |
| 8 | Quick Switcher | 19 | QuickSwitcherIndex (fuzzy match) | QuickSwitcherWindow | ⌘O 弹出窗口 (跨书架快速跳转) |
| 9 | Word count | 20 | WordCounter (中英混合) | WordCountBadge | 顶栏右侧 (跟 macOS 标准字数统计一致) |
| 10 | Outline | 21 | OutlineExtractor (H1-H6 + tree) | OutlinePanel | 编辑器右栏 (跟随当前 note H1-H6 跳转) |
| 11 | Bookmarks | 22 | BookmarkStore (actor SQLite) | BookmarkPanel | 上 band 编辑器右栏 + ⌘⇧B 弹窗 |
| 12 | 集成 + 跨工具兼容 | 23 | ObsidianFixturesTests (round-trip) | — | (无前端, 集成测试) |

## 详细接入需求 (按 wenshu 6 区 layout 分布)

### 顶栏 (titleBar) — 1 需求

| # | 需求 | 来源 | 接入位置 | 老板 8/18 拍板 |
|---|---|---|---|---|
| 1 | 顶栏右显示当前 note 字数 + 章节切换下拉 | ticket 20 Word count + ticket 8 Outline | 顶栏右 (跟 macOS Pages / Numbers 一致) | "整体黑夜白昼色实现" 已有顶栏布局, 加字数 + 章节切换 |

### 上 band (4 区域, 200/520/794/400 PT) — 6 需求

| # | 需求 | 来源 | 接入位置 | 备注 |
|---|---|---|---|---|
| 2 | 编辑器右栏: Outline (H1-H6 跳转) | ticket 21 Outline | 上 band 第 3 列 (794 PT 编辑器) 右侧新增右栏 (400 PT 减少) | 跟前 3 个 Backlinks / Canvas / Bases / Search 共享右栏逻辑 |
| 3 | 编辑器右栏: Backlinks panel (反向链接) | ticket 12 Internal Link | 上 band 编辑器右栏 (跟 Outline tab 切换) | 写当前章节时显示所有引用它的设定 / 章节 |
| 4 | 编辑器右栏: Quick Switcher 触发按钮 (或 ⌘O 全局) | ticket 19 Quick Switcher | 顶栏右图标 + ⌘O 全局快捷键 | Apple Spotlight 同范式 |
| 5 | 编辑器右上: Search 触发图标 (或 ⌘F) | ticket 17 Full Text Search | 编辑器右栏顶部 + ⌘F 全局快捷键 | 跨书架搜章节内容 |
| 6 | Canvas / 白板大纲独立区 (新 1 区) | ticket 13 Canvas + JSON Canvas | 上 band 新增第 5 区 (独立 Canvas tab) | wenshu 6 区 layout 调整: 上 4 + 下 2 → 上 5 + 下 2 (新增 Canvas 区) |
| 7 | Bases 数据库视图独立区 (新 1 区) | ticket 18 Bases | 上 band 新增第 6 区 (独立 Bases tab) | wenshu 6 区 layout 调整: 上 5 + 下 2 → 上 6 + 下 2 (新增 Bases 区) |

### 下 band (2 区域, AI聊天 1518 / AI 动态 400 PT) — 0 需求

(AI 聊天 / AI 动态跟 Obsidian 复刻无关, 保持现有实现)

### 编辑器主区 — 5 需求

| # | 需求 | 来源 | 接入位置 | 备注 |
|---|---|---|---|---|
| 8 | Markdown 编辑器解析 [[name]] 显示为内部链接 (蓝色下划线, ⌘+click 跳转) | ticket 12 Internal Link Parser | 编辑器主区 文本渲染层 | 跟 Obsidian wikilink 渲染一致 |
| 9 | 编辑器自动重写 [[old_name]] → [[new_name]] (重命名 note 时) | ticket 16 Note Composer.rename | 编辑器主区 + BacklinkResolver 联动 | Note Composer 重命名触发自动扫描所有 content |
| 10 | 编辑器自动合并多个 note 内容 (合并时) | ticket 16 Note Composer.merge | 编辑器主区 + Note Composer 联动 | merge 简化: 拼接内容, 中间空行 |
| 11 | 编辑器插入模板 (新建 note 时) | ticket 15 Templates | 文件菜单 → 新建 → 选模板 → 自动插入 {{date}} 等 tokens | 跟 Obsidian Templates 行为一致 |
| 12 | 编辑器实时字数统计 (右上 badge) | ticket 20 Word count | 编辑器主区 右上角 badge | 实时更新, 作家每日字数 |

### 全局命令 / 菜单 — 5 需求

| # | 需求 | 来源 | 接入位置 | 备注 |
|---|---|---|---|---|
| 13 | 文件菜单: 新建 note (选模板) | ticket 15 Templates | 菜单 "文件" → "新建" → 弹模板选择 (ticket 15 TemplatePicker) | Apple HIG 标准 "新建项目" |
| 14 | 文件菜单: 重命名 / 合并 / 拆分 note | ticket 16 Note Composer | 菜单 "文件" → "Composer" submenu | 跟 ticket 13 ticket 11 已有菜单布局一致 |
| 15 | 视图菜单: Outline / Backlinks / Search / Canvas / Bases panel 切换 | ticket 12/13/17/18/21 | 菜单 "视图" → 已有 "恢复默认布局", 新增 5 个 panel 切换 | 跟 ticket 14 ticket 09 "视图" 顶级菜单范式一致 |
| 16 | ⌘O 全局: Quick Switcher 弹窗 | ticket 19 Quick Switcher | 顶栏菜单 / 全局快捷键 | Apple Spotlight 同范式 (⌘+Space) |
| 17 | ⌘⇧B 全局: Bookmarks 弹窗 | ticket 22 Bookmarks | 顶栏菜单 / 全局快捷键 | 跨 note 收藏夹 |

### Bookmarks / Quick Actions — 2 需求

| # | 需求 | 来源 | 接入位置 | 备注 |
|---|---|---|---|---|
| 18 | 右栏 Bookmarks tab (跟 Outline / Backlinks 共存) | ticket 22 Bookmarks | 编辑器右栏 新增 Bookmarks tab | 跟 ticket 12 / 21 panel tab 切换 |
| 19 | 编辑器右上 Bookmark 按钮 (添加当前 note 到收藏) | ticket 22 Bookmarks | 编辑器主区 右上角 + 顶栏右 | ⌘+D 快捷键 |

## 优先级矩阵

| 优先级 | 需求 | 来源 | 工期估 |
|---|---|---|---|
| 🟢 P0 (写作 app 强需求) | 2 Outline 右栏, 3 Backlinks 右栏, 5 Search 全文, 9 重命名自动重写链接, 12 字数统计 badge, 8 wikilink 渲染, 16 ⌘O Quick Switcher | ticket 12/17/19/20/21 | 2-3 周 |
| 🟡 P1 (核心增强) | 6 Canvas 独立区, 13 新建模板, 15 视图菜单, 18 Bookmarks tab | ticket 13/15/22 | 2-3 周 |
| 🟢 P2 (写作体验增强) | 1 顶栏章节切换, 10 合并 note, 11 拆分 note, 14 Composer submenu, 4 Quick Switcher 按钮, 17 �⇧B Bookmarks, 19 Bookmark 添加按钮, 7 Bases 独立区 | ticket 12/13/15/16/18/19/20/22 | 3-4 周 |

## UI 改动对 LayoutTokens 的影响

| 需求 | 改动 | 跟 ticket 14 死原则冲突? |
|---|---|---|
| 2/3/5/18 右栏 panel tabs | 上 band 编辑器右栏宽度比例 (794 PT → 减少) + 新增 panel tab 切换 | ❌ 不冲突 (内部 sub-tabs) |
| 6 Canvas 独立区 | 上 band 4 区 → 5 区 (新增 1 区, 比例重分) | ❌ 冲突 (LayoutTokens 是死原则, 比例已 1:1 PT 锁定) — 需老板 拍 |
| 7 Bases 独立区 | 同上 | ❌ 同上 |

**关键决策点:** 需求 6/7 Canvas + Bases 独立区 跟 ticket 14 LayoutTokens 死原则冲突 (1920×984 PT 1:1 锁定, 6 区布局), 需老板 拍才能动. 或者用 **panel tabs 切换** (右栏多 tab 切换) 避开 layout 改动.

## 接入顺序建议 (按工作量大但稳 + 依赖关系)

**Phase 1 (P0 强需求, 1-2 周)**
1. ticket 12 Backlinks 右栏 (后端已完整, 前端 standalone View 直接接入)
2. ticket 21 Outline 右栏 (跟 Backlinks 共用右栏 tab 切换)
3. ticket 17 Search ⌘F (跟 Backlinks 共用右栏 tab 切换)
4. ticket 20 Word count 顶栏 badge (独立小 widget, 改动最小)
5. ticket 19 Quick Switcher ⌘O (独立弹窗, 不影响 layout)

**Phase 2 (P1 核心增强, 2-3 周)**
6. ticket 13 Canvas (用 panel tabs 切换避开 layout 改动)
7. ticket 18 Bases (同上)
8. ticket 15 Templates 菜单集成
9. ticket 22 Bookmarks 右栏

**Phase 3 (P2 写作体验增强, 3-4 周)**
10. ticket 16 Note Composer 菜单 + 自动重写
11. ticket 12 wikilink 编辑器渲染 (蓝色下划线 + ⌘+click 跳转)
12. 顶栏章节切换下拉

## 不接入清单 (按 wenshu 定位判断)

| 模块 | 不接入原因 |
|---|---|
| 跟 Obsidian 同步 (Obsidian Sync) | 闭源付费, wenshu 本地自管 |
| 跟 Obsidian Publish | 闭源付费, wenshu 写作不需要公开发布 |
| Plugin API (动态加载) | wenshu 单 app 编译, 不需要扩展机制 |
| Mobile (iOS/Android) | wenshu macOS-only (老板 8/18 拍) |
| Web viewer (iframe) | 写作 app 不需要 |
| Daily Notes (日历自动创建) | 写作 app 不需要 |
| Command Palette (⌘⇧P) | wenshu `.commands` 顶级菜单已够 |
| Slash commands (编辑器内 /) | 写作 app 不需要 |

## 后续 ticket (按 wenshu 定位)

- 整合 UI 接入 ticket: ticket 24 (右栏 panel tabs 框架) + ticket 25 (Quick Switcher ⌘O) + ticket 26 (顶栏字数 badge) + ...
- 接入顺序: Phase 1 → Phase 2 → Phase 3, 每 ticket 1 commit
- 老板 macOS 验后开始接入前端 (现阶段 12 个 standalone SwiftUI View 等老板验)
