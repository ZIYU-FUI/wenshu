<!--
DESIGN-SYSTEM-INIT.md · 文枢 (Wenshu) · v0.03.0 设计系统初版

1 句总结: 文枢 macOS 端 SwiftUI UI 的"FCP 范式"设计系统初版,9 条原则 + token 系统 + 8 组件 API + SF Symbol 映射 + 5 角色共同遵守,后续所有 UI 卡必引用本文件

2 句拍板理由:
  - 装机 user 8/10 15:50 OOB 拍:"给设计师,让他抽象出设计系统,原则不能边做边说,最好有一个初版。让他理解什么是真正的 FCP 范式" + FCP 截图 = v0-fix-1 commit 1512a68d3 落 main 后仍 4 处漏修 + 2 处误删 = 4 次修改都失败,真根因 = designer 缺 FCP 范式设计系统初版
  - AGENTS §8.1 + §13 + wenshu-editor-fcp-viewer-pattern.md §0 总原则已落"FCP 结构 + 文枢功能,全套范式照抄",本卡落地系统化,非功能创新

3 句边界:
  - ✅ 出 SwiftUI 设计意图 + token + 组件 API + SF Symbol 映射(design doc,markdown 文件)
  - ❌ 不写任何 .swift 代码(CC 翻译),不动 v0.02.0 main 业务/schema/5 区几何/.ws
  - ❌ 0 阻塞字段(不写"等装机 user 验"/"review-required"/"用飞书"等阻塞语),design system 初版是 5 角色共同遵守的"原则"基线,装机 user 头尾在看板外

派生:
  - 装机 user 6 处需求: 抬头 ICON-only / 5 区 0 文案按钮 / panel 自识别(无 H1) / 多 tab .iconOnly Picker / 新建=+ / sheet 540×480 modal / 0 阻塞
  - FCP 截图 composer_2026-08-10_07-47-03-040_10dd58.png 是范式真理源,本系统是它抽出来的"文枢专属"映射
  - v0-fix-1 commit 1512a68d3 BUG 1-6 + v0-fix-2 待修 BUG 7-9 是本系统的"反向验证用例"

下游:
  - CC 实现所有 UI 时引用本文件原则号(P1-P9 + designer 加的 P10-P12)
  - reviewer 审查时核对本文件 §7 组件 API
  - PM-direct 派单时 body 必显式引用本文件相关 P 号,designer 出 design doc 时 §0 第一行必重复 1+2+3 格式
-->

# DESIGN-SYSTEM-INIT · 文枢 macOS 端 SwiftUI UI 设计系统初版 (FCP 范式)

> **版本**: v0.03.0-INIT · **拍板**: 装机 user 8/10 15:50 OOB
> **作者**: designer (笔录) · **范围**: 文枢 macOS 端 UI (SwiftUI / macOS 14+)
> **真理源**: 本文件 + wenshu-editor-fcp-viewer-pattern.md §0 + AGENTS §8.1
> **关联**:
>   - v0-fix-1 commit `1512a68d3` (BUG 1-6 落 main,4 处漏修 + 2 处误删)
>   - v0-fix-2 t_29d24bd7 (被 AIF 主动关卡,推迟,等本系统初版落)
>   - FCP 截图 `composer_2026-08-10_07-47-03-040_10dd58.png` (范式真理源)

---

## §0 · 阅读顺序 (CC / reviewer / PM-direct / AIF 必读)

1. **读 §1 原则** (P1-P9 + designer 加的 P10-P12,文枢 UI 第一性约束)
2. **读 §2 Token** (color/typography/space/radius/shadow,所有数值)
3. **读 §3 组件库** (8 组件 API,designer 出稿 + CC 实现 + reviewer 审查都用同一套)
4. **读 §4 SF Symbol 映射** (文枢 5 区 → FCP 6 区 ICON 对照)
5. **读 §5 状态层** (5 态视觉规则)
6. **读 §6 文案规范** (中文 ≤ 10 字 + 英文 + tooltip 长描述)
7. **读 §7 5 角色协作** (designer/CC/reviewer/PM-direct/AIF 如何共同遵守本系统)
8. **读 §8 装机 user 验收 AC 清单** (6 步 AC,任何 UI 卡完成前自检)

---

## §1 · 原则 (P1-P12,文枢 UI 的 12 条铁律)

> **层级**: P1-P5 = 视觉第一性(必守);P6-P9 = 交互第一性(必守);P10-P12 = 协作第一性(designer 加的扩展,5 角色共同遵守)
> **引用范式**: FCP for Mac 截图 + 装机 user 8/10 三轮 OOB 讨论

### P1 · 标题栏 ICON-only (0 文字)

- **规则**: 文枢窗口标题栏 = **38pt 固定高度**,**0 文字**(无 H1 / 无项目名 / 无章节名),**仅 ICON 按钮**(SF Symbol + `.help()` tooltip)
- **FCP 范式**: 顶部 5 个 ICON 按钮(`+` 导入 / `↓` 导出 / `⤢` 放大 / `○` 检视 / `📋` 发布)+ 右侧 3 个 ICON(`?` 帮助 / `grid` 视图 / `share`)全部 ICON-only
- **不允许**:
  - ❌ 标题栏 H1 文字("文枢"/"项目名"/"v0.02.0"等)
  - ❌ 项目名居中显("第一章 重逢")
  - ❌ 任何"标题"+ 文字组合
- **仅允许**:
  - ✅ macOS 系统交通灯(红黄绿三圆点,系统自带)
  - ✅ ICON 按钮 + `.help("完整中文描述 ≤ 20字")` tooltip
- **代码示例** (SwiftUI,送给 CC):
  ```swift
  HStack(spacing: 4) {
      Button { /* action */ } label: {
          Image(systemName: "plus.circle.fill")
      }
      .help("新建项目")
      .buttonStyle(.plain)
      .frame(width: 32, height: 32)
  }
  .frame(height: 38)  // 固定高度,不让 macOS 自动撑
  .background(.regularMaterial)
  ```

### P2 · 任何功能按钮 = SF Symbol ICON-only (绝无文字)

- **规则**: 文枢内**任何触发功能的按钮**(新建/保存/导出/Inspector toggle/Sidebar toggle/聊天 tab/状态区 toggle/任何 toolbar 按钮) = **SF Symbol ICON-only**
- **FCP 范式**: 底部 toolbar 7 个功能 ICON(⬇⬆🖨⊟↕📁ⓧ ) + 4 个 inspector toggle ICON(⊜〰🎧🎬⊟)全部纯图标,无任何文字标签
- **a11y 例外**: SwiftUI `Label("新建项目", systemImage: "plus")` 会自动 fallback 到显示 "新建项目" 文字 — **必须去掉 Label 文字部分**,只用 `Image(systemName:)` + `.help("新建项目")` tooltip,**视觉上仍 ICON-only**
- **不允许**:
  - ❌ 按钮显示"新建项目"文字
  - ❌ 按钮显示"保存"文字 + SF Symbol 组合
  - ❌ `Label("...文字...", systemImage: "...")` 用在功能按钮上
  - ❌ `.buttonStyle(.borderedProminent)` 带标题
- **仅允许**:
  - ✅ `Image(systemName: "plus.circle.fill").help("新建项目")`
  - ✅ `.contextMenu` 文字菜单(右键菜单,popup 形式,跟 ICON-only 按钮不矛盾)
- **反例** (v0-fix-1 误删案例): "新建项目" 文字按钮被误删 → 用户找不到新建入口 → v0-fix-2 用 `+` ICON 替代,本系统 P1+P2+P6 完整定义

### P3 · 5 区 panel 内功能不超 panel 边界 (自适应宽度)

- **规则**: **5 区 panel** (左上 / 中上 / 右上 / 下左 / 下右)**内部**所有功能/按钮/标签/列表项 — **必须不超 panel 实际宽度**,**自适应 panel 缩窄**
- **FCP 范式**: 左侧 sidebar (250px 左右) 项目列表 — 当用户拖窄到 50px collapsed gutter,文字自动隐藏变 ICON-only
- **具体动作**:
  - 用 panel `geometryReader` 拿实际宽度
  - 宽度 < 100pt → 文字隐藏变 ICON-only (`@Environment(\.horizontalSizeClass)` 类似机制)
  - 文字宽度 > panel 宽 → 截断 + `.help()` tooltip 显示完整
- **不允许**:
  - ❌ 长文字 "12,345 字" 横排超出 panel 宽
  - ❌ 固定 "240pt sidebar" hard-code 宽度(必须从 LayoutMetrics 取)
  - ❌ "聊天区视图" H1 标签占 80pt 标题栏空间
- **仅允许**:
  - ✅ panel 内容用 `LazyVStack` 自适应
  - ✅ 截断文字 + tooltip
  - ✅ 横排元素 = ICON + tooltip + 短词 (≤ 10 中文字,见 P11)

### P4 · Panel 自识别 (无 panel 名 H1 前缀)

- **规则**: 文枢 **5 区 panel** 自身**自带 chrome-free 视觉识别**(icon + 折叠状态 + tab),**绝不显 panel 名 H1 前缀**("项目管理视图"/"聊天区视图"/"检视"/"文档浏览器"等)
- **FCP 范式**: 左侧 sidebar 不显 "Sidebar" 标签,顶部 toolbar 不显 "Toolbar" 标签 — 用户**靠位置 + 折叠状态 + tab ICON**识别 panel
- **反例** (v0-fix-1 已修但又漏): "项目管理视图" / "聊天区视图" / "检视" H1 文字 → v0-fix-1 commit 写过删但实际项目里**(t_ace37484 + v0-fix-3 待修)**漏,H1 还在
- **不允许**:
  - ❌ panel 顶部 "项目管理视图" H1 (`Text("项目管理视图").font(.title)`)
  - ❌ 任何 `.navigationTitle(...)` 用在文枢内 5 区
  - ❌ "检视" / "聊天" / "状态" / "看板" 等 panel 名 H1
- **仅允许**:
  - ✅ 折叠后的 panel 显示 ICON 单图标 (`Image(systemName: "sidebar.left")`)
  - ✅ 展开后的 panel 用 tab ICON(看 P5)
  - ✅ 面板 chrome 完全留给 toolbar + tab,无 H1

### P5 · 多 tab Picker 强 `.iconOnly` (避免 .segmented fallback)

- **规则**: 文枢**多 tab 选择**(聊天区 4 子 tab / 左上项目管理 5 tab / 右上 inspector 2 tab / 任何 Picker tab)**必须用 `.iconOnly` 修饰**,**禁用裸 `.segmented`** 避免 macOS 13 自动 fallback 显示 SF Symbol + 文字
- **FCP 范式**: 多 tab ICON-only,无任何文字标签
- **反例** (v0-fix-1 漏修): `.pickerStyle(.segmented)` 在 macOS 13 上 auto-fallback 显示 "聊天 / 时间线 / 关系图 / 大纲" 文字 → v0-fix-1 commit 写改但实际项目里漏 (t_d33b2058),v0-fix-2 用 `.iconOnly` 修
- **不允许**:
  - ❌ `Picker("聊天", selection: $tab) { ... }.pickerStyle(.segmented)` — 会 fallback 文字
  - ❌ 任何不带 `.iconOnly` 的 Picker tab
- **仅允许**:
  - ✅ `.pickerStyle(.segmented)` + 后续 `.iconOnly()` modifier(macOS 14+)
  - ✅ 自己写 HStack 自定义 ICON + selected 状态 visual
- **代码示例** (送给 CC):
  ```swift
  Picker("聊天模式", selection: $chatMode) {
      Image(systemName: "bubble.left.and.bubble.right").tag(0)
      Image(systemName: "clock").tag(1)
      Image(systemName: "person.2").tag(2)
      Image(systemName: "list.bullet.rectangle").tag(3)
  }
  .pickerStyle(.segmented)
  .iconOnly()  // 关键:.iconOnly() 必须
  .frame(height: 28)
  ```

### P6 · "新建项目" = + 按钮 (SF Symbol plus.circle.fill)

- **规则**: 文枢**任何"新建"操作**(新建项目 / 新建章节 / 新建设定 / 新建资料 / 新建看板列) = **`+` ICON-only 按钮** (SF Symbol `plus.circle.fill` 或 `plus`),**绝无"新建项目"文字**
- **FCP 范式**: 标题栏最左 `+` ICON 单击弹 modal,FCP 弹窗 540×480 居中 modal
- **反例** (v0-fix-1 误删): "新建项目" 按钮 + 整个新建入口被 v0-fix-1 commit 误删 → 用户功能全消失 → v0-fix-2 改 + ICON + 重建入口
- **不允许**:
  - ❌ "新建项目" 文字按钮(任何位置)
  - ❌ Button("新建项目") 无 SF Symbol
- **仅允许**:
  - ✅ `Image(systemName: "plus.circle.fill").help("新建项目")`
  - ✅ 点击弹 modal sheet(见 P8)
- **位置约定**:
  - 标题栏最左 = 全局 "新建项目" (FCP 同位)
  - 各 panel 内部 = 该 panel 专属新建(章节/卡片/设定项)
  - 全部 `+` ICON,**禁用文字**

### P7 · 空态 = ICON + 短词 + .help() tooltip (不用大段说明文字)

- **规则**: 文枢**任何空态**(空项目列表 / 空章节 / 空聊天 / 空资料 / 空看板 / "无对象选中") = **1 个 SF Symbol ICON + 短词 ≤ 10 字 + `.help()` 装长描述**,**禁用大段说明文字**
- **FCP 范式**: 中央 Viewer "不检查任何对象" = 灰色淡文字 1 短句 + 大空白,**绝无"请先选择..."教程段落**
- **反例** (v0-fix-1 漏修): "请先创建项目,然后..." 长说明 → v0-fix-1 commit 写过删但实际项目里漏
- **空态 3 件套**(标准):
  ```swift
  VStack(spacing: 12) {
      Image(systemName: "tray")
          .font(.system(size: 48, weight: .light))
          .foregroundStyle(.secondary)
      Text("暂无项目")
          .font(.title3)
          .foregroundStyle(.secondary)
  }
  .help("新建项目快捷键:⌘N · 项目存于 .ws 文件")
  ```
- **不允许**:
  - ❌ 空态下方加 3-5 行说明文字("请先点击...按钮...然后...这样...")
  - ❌ 大 "?" 图标 + 求助链接
- **仅允许**:
  - ✅ ICON + 短词 + tooltip 装长描述
  - ✅ 短词写将来时 ("暂无项目" + tooltip "新建项目快捷键:⌘N")

### P8 · 弹窗 (sheet) = .frame(width: 540, height: 480) modal 居中

- **规则**: 文枢**任何 modal sheet**(新建项目 / 新建章节 / 设置 / 资料导入) = **`.frame(width: 540, height: 480)` 居中 modal**,**禁用全屏 sheet**,**不挡主窗口顶 toolbar**
- **FCP 范式**: Inspector / 导入弹窗 = 中型居中 modal,540×480 是经过校准的 sweet spot
- **反例** (v0-fix-1 误改): "新建项目" sheet 撑满全屏 → 装载机 user 拍"不直观,不像 FCP"
- **不允许**:
  - ❌ `.frame(maxWidth: .infinity, maxHeight: .infinity)` 全屏 sheet
  - ❌ `.presentationDetents([.large])` 全屏 detent
- **仅允许**:
  - ✅ `.frame(width: 540, height: 480)` + 默认 `.medium` detent
  - ✅ sheet 居中 + 主窗口 toolbar 始终可见
- **代码示例** (送给 CC):
  ```swift
  .sheet(isPresented: $showNewProject) {
      NewProjectSheet()
          .frame(width: 540, height: 480)
  }
  ```

### P9 · 卡 body 0 阻塞字段 (5 角色共同遵守)

- **规则**: 文枢派单 (kanban) **body 字段 / 评论 / 设计稿 / sign-off** 全部 **0 阻塞字段**
- **阻塞字段反面教材** (禁用):
  - ❌ "等装机 user 验" — 装机 user 在看板外,不在 loop 内
  - ❌ "review-required: 装机 user" / "review-required: 飞书" — 跨平台错位
  - ❌ "用飞书" — 文枢流程走 kanban,飞书只用于 OOB 用户需求沟通
  - ❌ "等 PM-direct 派" — PM-direct 就是派单方,不应回环
  - ❌ "需要拍板" / "待定" (无 owner) — 必须有具体 owner
- **0 阻塞的卡 = 5 角色共同遵守**:
  - AIF 派单时:1+2+3 格式(body 已含 owner + 边界)
  - PM-direct 派子卡时:继承父卡 owner + 边界,自驱 loop
  - designer 出稿时:1+2+3 在 doc §0 第一行
  - CC 实现时:按 designer 稿写,不在卡里阻塞
  - reviewer 审查时:核对 §7 组件 API,有问题写 comment,**不阻塞卡前进**
- **目的**: 卡必须 = 自驱可完成,装机 user 头尾在看板外,不被 5 角色拉回

### P10 · 设计系统 0 视觉创新 (FCP 范式真理源为本) — designer 加

- **规则**: 文枢所有 UI 改动起点 = **"这是什么 FCP 范式 / 哪个编辑器有类似结构 / 该抄什么"** (见 wenshu-editor-fcp-viewer-pattern.md §0)
- **不允许**:
  - ❌ 凭"我觉得"设计自定义 toolbar 结构
  - ❌ 抄 web 设计 (Stripe / Linear / Vercel) 套到 macOS native app — 平台错配
  - ❌ 抄 Pages / Numbers / Word 通用办公范式 — 太通用,不够专业
  - ❌ 任何"非 FCP 范式"的结构创新 — 必须由装机 user OOB 拍板才能突破
- **查询资源**:
  - FCP for Mac 截图真理源(本卡 `composer_2026-08-10_07-47-03-040_10dd58.png`)
  - `popular-web-designs` skill(54 个真实设计系统,辅助参考 web paradigm)
  - Logic Pro / Pixelmator Pro / Sketch 等 macOS native app
- **派生规则**: 范式选定后,design doc §X 引用 FCP 范式截图 + 文枢映射表

### P11 · 文案 = 中文 ≤ 10 字 + 英文 (代码/identifier) + tooltip 装长描述 — designer 加

- **规则**: 文枢 UI **所有可见文字**必须满足:
  - **中文短词** ≤ 10 字 (UI 显示,"暂无项目"/"新建章节"/"未选中"),超 10 字用截断 + tooltip
  - **英文** 用在 代码 / identifier / 错误码 / API 名 (`LayoutShellView` / `WenshuStoreActor` / `modelLoadFailed`)
  - **tooltip (`.help()`)** 装长描述(完整中文短句 ≤ 20 字,如 "新建项目快捷键:⌘N")
- **反例** (v0-fix-1 漏修): 长标题 "第一章 重逢 · 点击编辑" / 长按钮 "新建项目并导入资料" — 全 > 10 字
- **不允许**:
  - ❌ UI 显示 > 10 字中文
  - ❌ 大段说明文字(看 P7 空态规则联动)
- **仅允许**:
  - ✅ "暂无项目" + tooltip "新建项目快捷键:⌘N · 项目存于 .ws 文件"
  - ✅ "v0.04.0 实现" + tooltip "长篇工具章节卡片在 v0.04.0 实装"

### P12 · 暗色优先 (FCP 范式 + 夜读) — designer 加

- **规则**: 文枢 macOS 端**默认深色模式** (dark mode),`@Environment(\.colorScheme)` 默认 `.dark`
- **FCP 范式**: 深黑背景 + 极淡文字 + SF Symbol 浅色 — 投到"夜读"写作场景天然契合
- **不允许**:
  - ❌ 强制 `.light` colorScheme
  - ❌ 亮色面板有亮灰背景(对比不足)
- **仅允许**:
  - ✅ `.preferredColorScheme(.dark)` 全局
  - ✅ 亮色模式留给用户系统切换偏好(`Settings` 接管,非 app 强制)
- **配色**: 详见 §2 Token

---

## §2 · Token 系统 (color / typography / space / radius / shadow)

> **使用规则**: 文枢所有 UI **必须引用本 Token**,禁用 hex / pt / shadow 数字字面值(裸值)
> **命名**: `wenshu.{category}.{name}` — 三段语义路径

### 2.1 颜色 (Color)

| Token | Light Mode | Dark Mode (默认) | 用途 |
|---|---|---|---|
| `wenshu.brand.primary` | `#2D7AE0` | `#5BA9F5` | 主按钮 / 强调 / selected state |
| `wenshu.brand.secondary` | `#6C757D` | `#8E8E93` | 次按钮 / disabled 文字 |
| `wenshu.surface.background` | `#FAFAFA` | `#1C1C1E` | 主背景 (FCP 同位深黑) |
| `wenshu.surface.elevated` | `#FFFFFF` | `#2C2C2E` | 卡片 / 弹窗 / panel 凸起 |
| `wenshu.surface.toolbar` | `#F2F2F7` | `#0A0A0A` | toolbar 背景 (FCP 同位最黑) |
| `wenshu.divider` | `#C6C6C8` | `#38383A` | 分隔线 / 1pt splitter |
| `wenshu.text.primary` | `#000000` | `#FFFFFF` | 主文字 |
| `wenshu.text.secondary` | `#3C3C43` | `#EBEBF5` | 次文字 / 空态短词 |
| `wenshu.text.tertiary` | `#3C3C4399` | `#EBEBF599` | 三级文字 / toolbar 暗底上 |
| `wenshu.status.error` | `#FF3B30` | `#FF453A` | 错误 / 删除 |
| `wenshu.status.warning` | `#FF9500` | `#FF9F0A` | 警告 / ※ 待定 |
| `wenshu.status.success` | `#34C759` | `#30D158` | 成功 / 已保存 |
| `wenshu.status.info` | `#007AFF` | `#0A84FF` | 信息 / 状态区 TODO |

### 2.2 字号 (Typography)

| Token | size / weight | 用途 |
|---|---|---|
| `wenshu.text.largeTitle` | 34 / bold | (保留 macOS HIG 标准,文枢目前不用) |
| `wenshu.text.title1` | 22 / bold | 主标题 (项目名 placeholder 等极少用) |
| `wenshu.text.title2` | 17 / semibold | 项目列表主标题 |
| `wenshu.text.body` | 13 / regular | toolbar 主文字 / panel 列表项 (FCP 同位) |
| `wenshu.text.callout` | 12 / medium | toolbar 短词 / 按钮 tooltip 默认 |
| `wenshu.text.subhead` | 11 / regular | 副标题 / 时间戳 |
| `wenshu.text.footnote` | 10 / regular | 注释 / 状态栏 |
| `wenshu.text.caption` | 9 / medium | 辅助说明 / 缩略图角标 |
| `wenshu.text.mono` | 13 / monospaced | 时间码 / 数据标识 |

**字号规则**:
- 文枢 toolbar ICON 默认 **14pt** (`Image(systemName:)` 不指定 size = 默认 ~17pt,需 `.font(.system(size: 14))`)
- panel 列表文字 13pt (FCP 同位)
- 状态栏/工具栏短词 11pt (FCP 同位)
- 章节正文 TextEditor 由 OS 提供,不在本 token 范围

### 2.3 间距 (Spacing,4 / 8 baseline)

| Token | 值 | 用途 |
|---|---|---|
| `wenshu.space.xxs` | 4 | 紧凑间距 (ICON 之间的 padding) |
| `wenshu.space.xs` | 8 | 小间距 (toolbar 元素之间) |
| `wenshu.space.s` | 12 | 次间距 (panel 内部 padding) |
| `wenshu.space.m` | 16 | 标准间距 (panel 之间) |
| `wenshu.space.l` | 24 | 大间距 (空态元素之间) |
| `wenshu.space.xl` | 32 | 超大间距 (sheet 内 sections) |
| `wenshu.space.xxl` | 48 | section 间距 (空态 ICON + 文字) |

### 2.4 圆角 (Radius)

| Token | 值 | 用途 |
|---|---|---|
| `wenshu.radius.s` | 4 | 按钮 / 输入框 |
| `wenshu.radius.m` | 6 | 卡片 (FCP 范式偏小圆角) |
| `wenshu.radius.l` | 8 | 大卡片 / 弹窗 |
| `wenshu.radius.xl` | 12 | 大弹窗 / sheet |

**圆角规则**:
- toolbar / panel chrome 几乎不圆角 (FCP 同位)
- sheet / modal 用 `wenshu.radius.l` (8pt)
- 卡片/按钮用 `wenshu.radius.s` (4pt)

### 2.5 阴影 (Shadow) — 文枢极简,深色模式少阴影

| Token | 值 | 用途 |
|---|---|---|
| `wenshu.shadow.subtle` | 0 1 2 rgba(0,0,0,0.05) | 轻微阴影 (按钮 hover) |
| `wenshu.shadow.moderate` | 0 2 8 rgba(0,0,0,0.30) | 弹窗阴影 (深色模式加强) |
| `wenshu.shadow.none` | (无) | toolbar / panel chrome 不要阴影 |

**阴影规则**:
- 暗色优先 → 大部分 UI **无阴影** (深色背景 + 凸起 surface 颜色差已足够)
- 仅弹窗 / sheet 用 `wenshu.shadow.moderate`
- toolbar / panel 绝不用阴影 (FCP 同位)

### 2.6 Token 实现 (送给 CC)

```swift
// 设计文件路径: Sources/WenshuApp/Resources/DesignTokens.swift (CC 实现,非本卡)
// 示例 token 引用:
Color("wenshu.brand.primary")  // Asset Catalog 引用
.font(.system(size: WenshuTokens.Text.body))  // 编译时常量
.padding(WenshuTokens.Space.s)
.cornerRadius(WenshuTokens.Radius.s)
```

---

## §3 · 组件库 (8 组件,designer 出稿 + CC 实现共用)

> **使用规则**: 文枢所有 UI 必须用本组件库,**禁用自定义 ad-hoc View**,有需要新组件时先扩本表(designer 拍板)
> **代码示例**: 本组件 API 是设计 contract,CC 按此实现

### 3.1 WenshuTitleBar · 顶部标题栏 (38pt, ICON-only)

```swift
struct WenshuTitleBar: View {
    let actions: [WenshuTitleBarAction]  // ICON + help + 回调
    var body: some View {
        HStack(spacing: WenshuTokens.Space.xxs) {
            ForEach(actions, id: \.id) { action in
                WenshuIconButton(icon: action.icon, tooltip: action.tooltip, action: action.action)
            }
        }
        .frame(height: 38)  // 固定高度,P1
        .background(Color("wenshu.surface.toolbar"))
        .overlay(Divider(), alignment: .bottom)  // 1pt 底分隔
    }
}
```

**约束**:
- 高度 38pt 固定
- 0 文字
- 仅 ICON 按钮 (P1 + P2)
- 背景 `wenshu.surface.toolbar` (最黑)

### 3.2 WenshuPanelContainer · 5 区 Panel 容器

```swift
struct WenshuPanelContainer<Content: View>: View {
    let position: PanelPosition  // .topLeft/.topCenter/.topRight/.bottomLeft/.bottomRight
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("wenshu.surface.background"))
            .overlay(
                // 1pt 边分隔(已折叠的不画)
                Rectangle().fill(Color("wenshu.divider")).frame(width: 1),
                alignment: position.borderEdge
            )
            // P4: 绝不显 H1 前缀,完全 chrome-free
    }
}
```

**约束**:
- panel 内容自适应宽度 (P3)
- 0 panel 名 H1 前缀 (P4)
- 1pt divider 边分隔

### 3.3 WenshuIconButton · SF Symbol ICON-only 按钮

```swift
struct WenshuIconButton: View {
    let icon: String         // SF Symbol name
    let tooltip: String      // 中文 ≤ 20 字
    let action: () -> Void
    var isSelected: Bool = false
    var size: CGFloat = 14   // FCP 同位
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(isSelected ? Color("wenshu.brand.primary") : Color("wenshu.text.primary"))
        }
        .buttonStyle(.plain)
        .help(tooltip)  // P2: tooltip 装长描述
        .frame(width: 32, height: 28)
    }
}
```

**约束**:
- 仅 SF Symbol,0 文字 (P2)
- `.help(tooltip)` 必带
- selected 用 `wenshu.brand.primary`,default 用 `wenshu.text.primary`

### 3.4 WenshuTabBar · 多 tab ICON-only Picker

```swift
struct WenshuTabBar: View {
    let tabs: [WenshuTab]
    @Binding var selection: WenshuTab.ID
    var body: some View {
        Picker("", selection: $selection) {
            ForEach(tabs) { tab in
                Image(systemName: tab.icon).tag(tab.id)
            }
        }
        .labelsHidden()              // 标签隐藏
        .pickerStyle(.segmented)     // .segmented
        .iconOnly()                  // 关键:.iconOnly() 修饰,P5
        .frame(height: 28)
    }
}
```

**约束**:
- 必须 `.iconOnly()` (P5)
- 高度 28pt
- ICON-only,0 文字

### 3.5 WenshuEmptyState · 空态 (ICON + 短词 + tooltip)

```swift
struct WenshuEmptyState: View {
    let icon: String           // SF Symbol
    let shortText: String      // 中文 ≤ 10 字
    let longTooltip: String    // 完整描述 (P11)
    var body: some View {
        VStack(spacing: WenshuTokens.Space.l) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color("wenshu.text.secondary"))
            Text(shortText)
                .font(.title3)
                .foregroundStyle(Color("wenshu.text.secondary"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help(longTooltip)  // P7 + P11: tooltip 装长描述
    }
}
```

**约束**:
- 仅 1 ICON + 1 短词 (P7)
- 短词 ≤ 10 字 (P11)
- 长描述在 tooltip
- 禁用大段说明文字

### 3.6 WenshuModalSheet · 弹窗 (540×480 居中 modal)

```swift
struct WenshuModalSheet<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content
    var body: some View {
        EmptyView()
            .sheet(isPresented: $isPresented) {
                content()
                    .frame(width: 540, height: 480)  // P8: 固定尺寸
                    .background(Color("wenshu.surface.elevated"))
            }
            .presentationDetents([.medium])  // 默认 medium,不大不小
    }
}
```

**约束**:
- 固定 540×480 (P8)
- 居中,不全屏
- 不挡主窗口 toolbar

### 3.7 WenshuCardList · 卡片列表 (FCP 缩略图风格)

```swift
struct WenshuCardList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let rowContent: (Item) -> Content
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(items) { item in
                    rowContent(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, WenshuTokens.Space.s)
                        .padding(.vertical, WenshuTokens.Space.xs)
                        .background(Color("wenshu.surface.background"))
                }
            }
        }
    }
}

// 单行卡片示例:
struct ProjectCard: View {
    let project: Project
    var body: some View {
        HStack(spacing: WenshuTokens.Space.xs) {
            RoundedRectangle(cornerRadius: WenshuTokens.Radius.s)
                .fill(Color("wenshu.brand.primary"))
                .frame(width: 4, height: 20)  // 左侧 accent 条
            Text(project.name)
                .font(.system(size: WenshuTokens.Text.body))
                .foregroundStyle(Color("wenshu.text.primary"))
            Spacer()
            Text(project.lastModified.shortDateFormat)
                .font(.system(size: WenshuTokens.Text.footnote))
                .foregroundStyle(Color("wenshu.text.secondary"))
        }
    }
}
```

**约束**:
- 1pt row spacing (FCP 同位)
- 左侧 4pt accent 条
- 文字 13pt (P11)
- 截断 + tooltip (P3)

### 3.8 WenshuTimelineBar · 时间线 / 多轨条带 (FCP 范式)

> 文枢 v0.04.0 长篇工具会用到,本卡先定义 API

```swift
struct WenshuTimelineBar<Track: Identifiable, TrackContent: View>: View {
    let tracks: [Track]
    @Binding var currentTime: TimeInterval
    @ViewBuilder let trackContent: (Track) -> TrackContent
    var body: some View {
        VStack(spacing: 1) {
            // ruler
            HStack { /* 时间刻度 */ }
                .frame(height: 20)
            ForEach(tracks) { track in
                trackContent(track)
                    .frame(height: 32)
                    .background(Color("wenshu.surface.background"))
                    .overlay(
                        RoundedRectangle(cornerRadius: WenshuTokens.Radius.s)
                            .fill(Color("wenshu.surface.elevated"))
                            .frame(width: /* clip 宽 */, height: 28)
                    )
                // FCP 范式:缩略图贴轴上(图层 clip 内贴小预览)
            }
        }
    }
}
```

**约束**:
- 1pt track spacing (FCP 同位)
- 缩略图贴轴上(FCP 标志,文枢章节正文段落卡片化)
- 24/28pt track 高度
- 0 装饰阴影

---

## §4 · SF Symbol 映射 (文枢 5 区 → FCP 6 区 ICON 对照)

> **核心规则**: 文枢 5 区(顶 toolbar + 左上 + 中上 + 右上 + 下左 + 下右)的每个功能按钮,必从本表选 SF Symbol,**禁用设计师即兴想名字**

### 4.1 顶部 toolbar (WenshuTitleBar) — 引用 §3.1

| FCP 功能 | FCP SF Symbol (近似) | 文枢功能 | 文枢 SF Symbol |
|---|---|---|---|
| 导入 | `square.and.arrow.down.fill` | 新建项目 | **`plus.circle.fill`** (P6) |
| 导出 | `square.and.arrow.up.fill` | 保存 | `square.and.arrow.down` |
| 放大 (Viewer) | `arrow.up.right.and.arrow.down.left` | 导入 | `square.and.arrow.down.fill` |
| 检视 (Inspector toggle) | `sidebar.right` | 检视 toggle | `sidebar.right` |
| 发布 | `square.and.arrow.up.on.square` | 发布 | `square.and.arrow.up.on.square` |
| 帮助 | `questionmark.circle` | 帮助 | `questionmark.circle` |
| 视图模式 | `square.grid.3x3` | 视图切换 | `square.grid.3x3` |
| 分享 | `square.and.arrow.up` | 分享 | `square.and.arrow.up` |

### 4.2 左上项目管理 (5 tab) — WenshuTabBar §3.4

| Tab | SF Symbol | 含义 |
|---|---|---|
| 项目 | `folder.fill` | 项目列表 |
| 章节 | `list.bullet.rectangle` | 章节树 |
| 设定 | `person.2.fill` | 人物 / 世界设定 |
| 资料 | `books.vertical.fill` | 资料库 |
| 看板 | `rectangle.split.3x1` | 看板 (OOB 8/7 拍) |

### 4.3 中上文档浏览器

无 tab,内容由章节正文 TextEditor 提供,顶部 WenshuIconButton:
- `square.and.pencil` (编辑器工具占位,留给 v0.04.0)
- `arrow.up.right.and.arrow.down.left` (放大 / 专注模式,FCP 范式右下放大同位)

### 4.4 右上 inspector (2 tab) — WenshuTabBar §3.4

| Tab | SF Symbol | 含义 |
|---|---|---|
| 伏笔 | `bookmark.fill` | 伏笔列表 |
| 修订 | `arrow.triangle.2.circlepath` | 修订候选 |

### 4.5 下左聊天区 (4 子 tab) — WenshuTabBar §3.4

| Tab | SF Symbol | 含义 | v0.02.0 状态 |
|---|---|---|---|
| 聊天 | `bubble.left.and.bubble.right.fill` | AI 对话 | ✅ 实装 |
| 时间线 | `clock.fill` | 故事时间线 | ❌ v0.04.0 disabled |
| 关系图 | `person.line.dotted.person` | 人物关系 | ❌ v0.04.0 disabled |
| 大纲 | `list.bullet.rectangle` | 大纲视图 | ❌ v0.04.0 disabled |

### 4.6 下右状态区 (明盒,v0.03.0 + 实现)

单流多视图切换:
- `list.bullet` (全部)
- `bubble.left` (对话)
- `arrow.triangle.2.circlepath` (状态)
- `checklist` (TODO)

### 4.7 功能按钮

| 功能 | SF Symbol | 备注 |
|---|---|---|
| 新建 (P6) | `plus.circle.fill` | 全局统一 |
| 删除 | `trash.fill` | 错误色,需确认 modal |
| 折叠 | `chevron.left` / `chevron.right` | panel 折叠按钮 |
| 编辑 | `pencil` | rename / 改 |
| 关闭 | `xmark` / `xmark.circle.fill` | 关闭 panel / sheet |
| 放大 | `arrow.up.right.and.arrow.down.left` | 专注模式 |
| 缩小 | `arrow.down.right.and.arrow.up.left` | 退出专注模式 |
| 搜索 | `magnifyingglass` | 搜索框 ICON |
| 设置 | `gearshape` | 偏好设置 |
| 复制 | `doc.on.doc` | 复制文本 / 对象 |
| 撤销 | `arrow.uturn.backward` | undo |
| 重做 | `arrow.uturn.forward` | redo |
| 全屏 | `arrow.up.left.and.arrow.down.right` | 全屏切换 |
| 帮助 | `questionmark.circle` | 帮助 |
| 视图 | `square.grid.3x3` | 视图切换 |
| 分享 | `square.and.arrow.up` | 分享 |

---

## §5 · 状态层 (5 态,所有交互元素通用)

> **5 态**: default / hover / active / focused / disabled — 全部交互组件必须实现

| 状态 | 视觉 | 触发 | Token |
|---|---|---|---|
| **default** | 标准前景色,无背景 | 鼠标未进入 | `text.primary` |
| **hover** | 半透明背景叠加 | 鼠标进入 | `.background(Color.primary.opacity(0.1))` |
| **active / pressed** | 背景更深或缩放 0.98 | 鼠标按下 | `.scaleEffect(0.98)` |
| **focused** | 系统 focus ring (蓝色 2pt 描边) | 键盘 tab 进入 | 系统自动 |
| **disabled** | 灰前景 + 50% 透明度 | 不满足启用条件 | `text.secondary` + `.opacity(0.5)` |
| **selected** | brand.primary 前景 (P3 用 selected 状态) | tab/选项选中 | `brand.primary` |

**代码示例** (送给 CC):

```swift
extension View {
    func wenshuInteractiveState(isSelected: Bool = false, isEnabled: Bool = true) -> some View {
        self
            .foregroundStyle(
                !isEnabled ? Color("wenshu.text.secondary").opacity(0.5) :
                isSelected ? Color("wenshu.brand.primary") :
                Color("wenshu.text.primary")
            )
    }
}
```

---

## §6 · 文案规范 (中文 ≤ 10 字 + 英文 + tooltip 长描述)

### 6.1 短词 (UI 显示文字)

| 场景 | 标准文案 | 字数 |
|---|---|---|
| 项目列表空态 | "暂无项目" | 4 |
| 章节空态 | "暂无章节" | 4 |
| 聊天空态 | "暂无对话" | 4 |
| 资料空态 | "暂无资料" | 4 |
| 看板空态 | "暂无看板" | 4 |
| 状态空态 | "暂无 TODO" | 5 |
| 不选中任何 | "未选中对象" | 5 |
| 等待 v0.04.0 | "v0.04.0 实现" | 7 |
| 等待 v0.05.0 | "v0.05.0 实现" | 7 |

### 6.2 Tooltip / 帮助文字 (.help())

| 元素 | Tooltip 内容 |
|---|---|
| + ICON | "新建项目" (≤ 4字) |
| ⤢ ICON | "专注模式" |
| ⓧ ICON | "隐藏状态区" |
| 📋 ICON | "复制文本" |
| ⏲ ICON | "时间线 (v0.04.0)" |
| 👥 ICON | "关系图 (v0.04.0)" |
| 📋 ICON | "大纲 (v0.04.0)" |

### 6.3 标识符 / 代码 (英文)

- Type: `LayoutShellView` / `WenshuStoreActor` / `LayoutShellViewModel`
- File: `LayoutShell.swift` / `WenshuTokens.swift`
- 错误码: `modelLoadFailed` / `wsFileCorrupted` / `llmKeyMissing`
- 项目元数据 key: `lastModifiedBy` / `schemaVersion`

### 6.4 反例 (禁用)

| ❌ 错误 | ✅ 修正 |
|---|---|
| "项目管理视图" H1 | panel 顶部不显 H1 (P4) |
| "请先创建项目" 长说明 | "暂无项目" + tooltip (P7) |
| "新建项目并导入资料" 长按钮 | + ICON + tooltip (P6 + P2) |
| "聊天区视图" H1 | 不显 (P4) |
| "检视" H1 | 不显 (P4) |

---

## §7 · 5 角色共同遵守 (designer / CC / reviewer / PM-direct / AIF)

> **协作流程**:
> 1. AIF 派单 (1+2+3 格式,引用本文件 P 号)
> 2. PM-direct 拆子卡 (1+2+3 继承父卡,引用本文件)
> 3. designer 出 design doc (1+2+3 在 doc §0 第一行,引用本文件 P 号 + 组件 API)
> 4. CC 实现 (.swift 代码,严格按组件 API,引用本文件 Token)
> 5. reviewer 审查 (核对 P 号 + Token + 组件 API,有违规则写 comment,卡不阻塞前进)
> 6. 装机 user 头尾在看板外验收

### 7.1 designer 出稿时 (出 design doc 必引)

**doc §0 第一行格式** (1+2+3):

```markdown
# DESIGN-XXX · <一句话总览>

**1 句总结**: <这张设计稿覆盖什么区 / 子能力>
**2 句拍板理由**: <为什么现在出 + 为什么这个边界,引 AGENTS §X + 本系统 P-Y>
**3 句边界**: <不写代码 / 不改 .ws / 不跨区 / 引用本系统 P-Z / 引用本组件 API §W>
```

**doc 正文必须显式**:

```markdown
## 引用本设计系统

- 原则: P1, P2, P3, P4, P5, P6, P7, P8 (列出本卡触发的 P 号)
- Token: 列出本卡引用的 Token 路径
- 组件 API: WenshuTitleBar / WenshuIconButton / WenshuTabBar / ...
- 反例修正: 列出本卡修复的 v0-fix-1 BUG 编号
```

**sign-off comment 5 行**:

```
DESIGN-XXX.md 落盘 (N 行, M 段)。
<1 句覆盖区>
<1 句关键技术决策:引用 P 号 + 组件 API>
<1 句调研依据:前序拍板 commit hash + 行号>
<1 句 1+2+3 边界声明:引用本系统 P-Z>
<1 句下游提示:CC 实现关键 + reviewer 审查重点>
```

### 7.2 CC 实现时

- 严格按 designer doc 引用的 **组件 API** 实现,不擅自改 API
- 严格按 **Token** 引用,不写裸 hex / pt / shadow 数字
- 遇到 doc 没覆盖的边缘 case,**先写 comment 升级**,不擅自决定

**comment 模板**:

```
[CC 实现 v0-fix-N]
完成: doc 引用的 N 个组件实现完毕。
引用原则: P1, P2, P5
引用 Token: wenshu.brand.primary, wenshu.surface.background
边界: 不动 panel chrome,不改 panel 名 H1(P4 严守)
下游 reviewer 请核对:
  - 顶部 toolbar 高度 38pt
  - 所有 ICON-only 按钮 0 文字
  - Picker 加了 .iconOnly()
未决:
  - (有什么问题升级,不阻塞)
```

### 7.3 reviewer 审查时

- 核对 designer doc 引用的 P 号是否真在代码里生效
- 核对 Token 引用是否一致(不出现裸 hex)
- 核对组件 API 是否符合设计 contract
- 不通过 → 写 comment,**不阻塞卡前进**(reviewer 应在卡 loop 内自决)

### 7.4 PM-direct 派单时

派单 body 必显式引用本系统:

```
本卡实现: <区名> UI
引用: DESIGN-SYSTEM-INIT.md §1 P-Y + §3 组件 API §Z
边界: 引用本系统的全部边界 (不动 .ws / 不动业务 schema / 0 阻塞)
```

### 7.5 AIF 派单时

派跨阶段 / 跨区 / 动 schema 的卡前,**同步本设计系统**:

- 任何 v0.x 阶段门升级前,confirm 本系统的 P / Token / 组件 API 是否需要扩
- 新组件 API 必 designer 拍板(P10)
- 新 P 必 designer 拍板(P10),不允许别角色擅加

---

## §8 · 装机 user 验收 AC 清单 (6 步,任何 UI 卡完成前自检)

> **目的**: 装机 user 头尾在看板外,任何 UI 卡完成前由 CC / designer / reviewer 自检,装机 user 重拍截图验证

### AC1 · 启动检查 (30 秒)

- [ ] App 启动,wenshu 图标正常显示
- [ ] 5 区 layout 全部可见(顶 toolbar / 左上 / 中上 / 右上 / 下左 / 下右)
- [ ] 暗色模式默认,无亮色穿透
- [ ] swift build exit 0,swift test exit 0

### AC2 · 标题栏检查 (P1,60 秒)

- [ ] 顶部 toolbar 高度 = 38pt,固定
- [ ] **0 文字**(无 H1,无项目名,无章节名,无 v0.02.0 等版本号)
- [ ] 所有按钮 = SF Symbol ICON-only
- [ ] 任何按钮鼠标悬停 = `.help()` tooltip 出现中文短词
- [ ] 至少 1 个 `+` (新建项目) ICON 在标题栏最左 (P6)

### AC3 · 5 区 panel 检查 (P3 + P4,90 秒)

- [ ] 左上项目管理 = 5 tab (项目/章节/设定/资料/看板),全部 ICON-only,无文字
- [ ] 中上文档 = 主内容区,无 H1
- [ ] 右上 inspector = 2 tab (伏笔/修订),全部 ICON-only,无文字
- [ ] 下左聊天 = 4 子 tab (聊天实装 + 时间线/关系图/大纲 disabled),全部 ICON-only
- [ ] 下右状态 = 多视图切换 ICON-only (v0.03.0 实现后)
- [ ] **任何 panel 顶部不显 "项目管理视图"/"聊天区"/"检视" 等 H1**(P4)
- [ ] 拖窄任何 panel 到 50px,内部功能应自适应不超界 (P3)

### AC4 · 弹窗检查 (P8,30 秒)

- [ ] 点击 + ICON (新建项目) 弹 modal
- [ ] modal 尺寸 = 540×480 居中
- [ ] **不全屏**
- [ ] 主窗口 toolbar 始终可见
- [ ] 关闭 modal 后,主窗口状态完整恢复

### AC5 · 看板检查 (90 秒)

- [ ] 左上点 "看板" tab 切换
- [ ] 看板区显示空态(若有项目则显示看板列)
- [ ] 空态符合 P7:1 ICON + 1 短词 + tooltip
- [ ] **不用大段说明文字**
- [ ] 看板列头 / 卡片 = ICON-only + tooltip + 截断文字 (P2 + P3)

### AC6 · 聊天 ICON 检查 (P2 + P5,30 秒)

- [ ] 下左 4 子 tab = 全部 ICON-only
- [ ] 选 "聊天" tab 可对话(LLM 真连)
- [ ] 选 "时间线"/"关系图"/"大纲" 显示 disabled 空态
- [ ] **任何按钮不显示 SF Symbol + 文字 fallback**(macOS 13 `.segmented` 漏修回归)

### 装机 user 重拍截图对照

```bash
# 真机拍图,对照 FCP 真理源
composer_2026-08-10_07-47-03-040_10dd58.png  # FCP 范式真理源(本卡)
```

装机 user 拍新截图后,3 个核心问题自问:
1. 顶部 toolbar 是否 ICON-only,无文字?(对应 P1)
2. 是否抄袭了 FCP 范式,但功能是文枢自己的?(对应 P10)
3. 是否 0 阻塞字段,装机 user 头尾在看板外?(对应 P9)

---

## §9 · 拍板历史 & 已知 BUG 反向验证

### 9.1 拍板历史

- ✅ 2026-08-10 装机 user OOB 15:50 拍: 设计师出 FCP 范式设计系统初版,5 角色共同遵守
- ✅ 2026-08-10 装机 user OOB 15:35 拍: "两次不符合规则" = designer 边做边说,缺原则基线
- ✅ 2026-08-10 装机 user OOB 15:30 拍: v0-fix-1 落 main 后仍 4 处 BUG,真根因 = 缺设计系统
- ✅ 2026-08-10 装机 user OOB 8/10 三轮讨论落档:wenshu-editor-fcp-viewer-pattern.md §0 总原则 (结构 = FCP,功能 = 文枢)
- ✅ 2026-08-06 AGENTS §3 派单原则 1+2+3 + §4 PM↔CC loop + §8.1 5 区 layout 拍板

### 9.2 已知 BUG 反向验证 (本系统必须修复的全部 BUG)

| BUG ID | 来源 | 本系统修复方案 | 相关 P / 组件 API |
|---|---|---|---|
| BUG 1 | v0-fix-1 commit 1512a68d3 | 顶部标题栏 38pt + ICON-only + 无 H1 + + ICON 在最左 | P1 + P2 + P6 + §3.1 WenshuTitleBar |
| BUG 2 | v0-fix-1 漏 | 左上 5 tab 列表 container 重写,5 tab ICON-only | P4 + P5 + §3.4 WenshuTabBar + §4.2 |
| BUG 3 | v0-fix-1 漏 | 底部"聊天区视图" H1 真删 | P4 |
| BUG 4 | v0-fix-1 漏 | 底部 4 chat tab Picker 改 `.iconOnly()` | P5 |
| BUG 5 | v0-fix-1 漏 | 右上"检视" H1 真删 | P4 |
| BUG 6 | v0-fix-1 漏 | 右上 2 tab Picker 改 `.iconOnly()` | P5 |
| BUG 7 | 8/10 15:30 真机拍 | 顶部标题栏 + button 误删 (v0-fix-1 整段没生成) | P1 + P2 + P6 强制覆盖 |
| BUG 8 | 8/10 15:35 真机拍 | + button 用 `+` ICON 重建 | P6 |
| BUG 9 | 8/10 15:35 真机拍 | 5 tab 列表容器重写 | P4 + P5 |

**v0-fix-3 派生规则**: 系统初版落档后,v0-fix-3 CC 卡实现 v0-fix-2 的 4 处漏修 + v0-fix-1 的 2 处误删,代码必引用本系统的 P 号 + Token + 组件 API,**不再自由发挥**

### 9.3 与 swiftui-design-patterns skill 的关系

本系统是 `swiftui-design-patterns` skill 的**文枢专属实例化**:
- token 系统 = skill §4 的 wenshu 命名版(具体值跟 skill 一致,但路径名 `wenshu.` 前缀统一)
- 组件 API = skill §2 + §3 的 SwiftUI API 在 FCP 范式下的具体组件抽象
- 5 区 layout 映射 = skill §5 + wenshu-editor-fcp-viewer-pattern.md §0 的细节展开

### 9.4 与 wenshu-designer-onboarding 的关系

- designer 接单前必读 onboarding §2 五步 + §3 矛盾点检查单
- 出稿时,在 onboarding §7 完成定义 + 本系统 §7.1 双重检查
- sign-off comment 合并 onboarding §7.5 模板 + 本系统 §7.1 sign-off 5 行模板

---

## §10 · 留给 PM-direct / AIF 拍板项 (designer 不拍)

| 拍板点 | designer 倾向 | 等拍 |
|---|---|---|
| toolbar 高度 38pt (vs macOS 标准 24pt) | 38pt 留 dropdown 空间 | PM |
| 字号 13pt 偏小? | FCP 同位,夜读舒适 | PM |
| Token wenshu.brand.primary `#2D7AE0` | 中等蓝,不刺眼 | PM |
| 组件 API 命名 `Wenshu*` | 跟 wenshu 前缀统一 | PM |
| 5 角色共同遵守流程 | 见 §7 | AIF 拍 AGENTS §3+§4 |
| 暗色强制 / 用户可切 | 用户可切,默认暗色 | PM |
| 新增组件 API (e.g. WenshuColorPicker) | 先扩本表再实现 | designer 拍 (P10) |

---

**初版落档**: 装机 user 8/10 15:50 OOB · designer 落档 v0.03.0-INIT
**下次 sync**: v0-fix-3 CC 完成后,补"实施证据"(实际代码 P 号对照表)
**真理源优先级**: 本文件 = P1-P12 原则真理源;wenshu-editor-fcp-viewer-pattern.md = 视觉灵感真理源;AGENTS.md = 流程 + layout 真理源

---

*DESIGN-SYSTEM-INIT v0.03.0-INIT · 2026-08-10 · 装机 user 15:50 OOB 拍"抽象出 FCP 范式设计系统" + 截图为真理源*
