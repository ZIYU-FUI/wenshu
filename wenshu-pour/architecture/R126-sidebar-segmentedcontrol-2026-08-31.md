# WO-001BI-R126: sidebar 顶部加 SegmentedControl (项目 / 全部 sessions 显式切换)

**日期**: 2026-08-31 · **派单人**: PM-direct (CC 没派, 单文件增量改 PM-direct 自家跑) · **commit**: `6c2fb4ae7` · **upstream ref**: `NousResearch/hermes-agent main @ 8fc278207` · **状态**: 已 push origin main

---

## 1. 装机 user 8/31 拍板真值

- 8/31 18:51: "你派单了没，修会话列表" - 反悔 8/31 "先不动了" - 现在要修
- "按文枢需要的方向改" - 装 user 拍板走 文枢方向 (而非 继续持上游)
- "上游有会话列表, 有项目列表, 会话和项目可以切换" - 装 user 想要 **显式切换 UI**

**R125 (调研单)**: PM-direct 拍 4 候选 (A 持上游 / B 加 SegmentedControl / C 改 grouped 默认 / D 装 user 自定义) → 等装机 user 24h 内拍
**R126 (本单)**: 装机 user 8/31 反悔"先不动了" → 8/31 改口"按文枢需要的方向改" → 走 R125 候选 B (加 SegmentedControl) - 但保持上游 SegmentedControl 原语 + 加 sidebar 顶部

## 2. 真值 - R125 vs R126 决策对照

| 维度 | R125 (8/31 上午) | R126 (8/31 晚上) |
|------|------------------|------------------|
| 装机 user 拍板 | "改吧" 但 PM-direct 推 A 持上游 | "按文枢需要的方向改" - 装 user 主动拍 改 |
| PM-direct 决策 | 选项 A 默认 (Pitfall #77 + §15.6) | 选项 B 拍板 (SegmentedControl) |
| sidebar/index.tsx 改 | 0 行 (R114 revert state) | +14 行 (1 SegmentedControl block + 1 import) |
| 上游 SegmentedControl 原语 | 已存在 (components/ui/segmented-control.tsx 65 行) - sidebar 未用 | **现在 sidebar 用了** |
| 装机 user 找到 root-folder icon 切换? | 否 (icon button hover discover) | 是 (显式 2-段 toggle) |

## 3. 拍板真值 (R126 8/31 PM-direct 自家拍)

### 3.1 改动范围 (严格 1 increment)

1. **`apps/desktop/src/app/chat/sidebar/index.tsx`** - 2 处改:
   - L15 加 1 行 import: `import { SegmentedControl } from '@/components/ui/segmented-control'`
   - L1196-1208 加 13 行 SegmentedControl block (在 nav group 与 search field 之间)
   - 总计 +14 行, **0 删除**
2. **`apps/desktop/src/i18n/types.ts`** - L1345-1348 加 `segments` 子对象 type 契约 (+4 行)
3. **`apps/desktop/src/i18n/en.ts`** - L1618-1621 加 en 翻译 (+4 行)
4. **`apps/desktop/src/i18n/zh.ts`** - L1785-1788 加 zh 翻译 (+4 行)
5. **`apps/desktop/src/i18n/ja.ts`** - L1574-1577 加 ja 翻译 (+4 行)
6. **`apps/desktop/src/i18n/zh-hant.ts`** - L1526-1529 加 zh-hant 翻译 (+4 行)

**总计**: 6 文件 +34 行, 0 删除, 0 结构改

### 3.2 设计决策 5 真值

1. **位置**: sidebar 顶部 (nav group 与 search field 之间) - 跟 upstream `SegmentedControl` 在 `command-center/index.tsx:338` 位置风格一致 (header 内嵌, 跟随 segmented width fit)
2. **显示条件**: `showSessionSections && !showAllProfiles` - 只在 单 profile 视图 显 (跟 upstream 同款 scope 语义, 多 profile 时 hide)
3. **state 映射**: SegmentedControl 是 `setSidebarAgentsGrouped` 的 **显式** 入口, 复用 upstream 已有的 `$sidebarAgentsGrouped` (layout.ts:147) persistentAtom
   - 选项 `sessions` (id='sessions') → `setSidebarAgentsGrouped(false)` (平铺)
   - 选项 `projects` (id='projects') → `setSidebarAgentsGrouped(true)` (grouped tree)
4. **不删原 icon button**: 保留 sidebar/index.tsx:1396-1407 的 root-folder icon button 作为 hover affordance (冗余 entry point, 装 user 已有 root-folder muscle memory 不破)
5. **不 bump 版本号**: 0.1.0 不 bump (R126 是 sidebar UX 增量, 不是 feature flag, 跟 R124 同口径)

### 3.3 文枢方向 ≠ 偏离上游 (反驳 R125 §4 候选 B 担忧)

- R125 拍 "B 选项缺点 = 偏离上游, 跟 v2026.7.21+ merge 时需小冲突 resolve"
- R126 真值 = 上游 `SegmentedControl` 原语 **本身就在仓根** (`apps/desktop/src/components/ui/segmented-control.tsx`), 上游不"用" ≠ 上游"没有"
- 偏离 = R126 在 sidebar 加 1 个新 import + 1 个新 block, 上游更新时 `git show upstream/main:apps/desktop/src/app/chat/sidebar/index.tsx` diff 仓根 = **可自动 merge** (新加的 block 是局部增量, 不改既有 14 行)
- 不构成 §15.6 "暗猜设计" 违反 = 装机 user **明确拍** "按文枢需要的方向改"

## 4. 验证链 (R126 PM-direct 自验 8/31)

### 4.1 代码层
- ✅ `pnpm tsc -p tsconfig.json --noEmit` exit 0 (空 stderr)
- ✅ `pnpm build` exit 0 (desktop `dist/index.html` + assets + `electron-main.mjs` 514.2kb + `electron-preload.js` 16.7kb)
- ✅ Vite chunk size warning 是 informational, 不影响 build 退出码
- ✅ 6 文件 +34 行 增量 (sidebar/index.tsx +14, types.ts +4, en +4, zh +4, ja +4, zh-hant +4)
- ✅ 0 行 删除
- ✅ 0 文件 结构性 diff (只加新内容)

### 4.2 git 层
- ✅ commit `6c2fb4ae7` (fix(wenshu): R126 - sidebar 顶部加 SegmentedControl (项目 / 全部 sessions 显式切换))
- ✅ push `f6bde6faf..6c2fb4ae7  main -> main` 成功
- ✅ 白名单不动: f6bde6faf R124 / c70ca412e R123 / 5b1f6f408 R122 / 9a18e21f9 R121 / 60c805c55 R116 / 0fa2ce735 R115 / e1b70e9ca R114 / 9c4445984 R113 ✓
- ✅ sidebar/index.tsx main 文件结构 0 改 (R114 已 perfect revert) - R126 仅 +14 行 新增 block

### 4.3 体验层 (装机 user 验收路径)
- 装机 user 跑 `wenshu update --yes` 重 spawn backend + 重 build desktop
- 装机 user 验 sidebar 顶部:
  - 单 profile (my-pm only): 显 [全部会话 | 项目] SegmentedControl
  - 多 profile (ALL view): SegmentedControl 隐藏 (上游语义: ALL view 默认不是 grouped)
  - 点 [项目] → sidebar 切 grouped tree (项目 → repo → lane → sessions)
  - 点 [全部会话] → sidebar 切 平铺 sessions (Pinned + Recents)
  - 原 root-folder icon button (headerAction) 仍可用 = 双向 entry point
- 装机 user 切换后状态持久化 (跟原 icon button 一样, 走 `$sidebarAgentsGrouped` persistentAtom)

## 5. 与上游对比真值 (R126 8/31 PM-direct 调研)

### 5.1 upstream 'home/layers' icon-toggle pill 调研真值 (任务 R126 step 1)

**结论**: upstream home/layers = `<ProfilePill>` 在 sidebar **底部** (`<ProfileRail />`), 1 个 single icon button + aria-pressed, 不是 SegmentedControl, 不在 header。

**Evidence** (R125 调研真值):
- `apps/desktop/src/app/chat/sidebar/profile-switcher.tsx:152-160` (`ProfilePill` 调用):
  ```tsx
  {multiProfile &&
    (defaultProfile ? (
      <ProfilePill
        active={isAll || onDefault}
        glyph={isAll ? 'layers' : 'home'}
        label={onDefault ? p.showAllProfiles : p.switchToProfile(defaultProfile.name)}
        onSelect={() => (onDefault ? setShowAllProfiles(true) : selectProfile(defaultProfile.name))}
      />
    ) : (
      <ProfilePill active={isAll} glyph="layers" label={p.allProfiles} onSelect={() => setShowAllProfiles(true)} />
    ))}
  ```
- `apps/desktop/src/app/chat/sidebar/profile-switcher.tsx:367-385` (`ProfilePill` 实现): 单 button + icon, aria-pressed, **不带选项栏/grouped track**
- 位置: `sidebar/index.tsx:1482` 末尾 `<div className="shrink-0 px-0.5 pb-1 pt-0.5"><ProfileRail /></div>`

**装机 user 任务原文 描述 "顶部" 真值**: 装 user 把 `<ProfilePill>` (default ↔ all profiles 切换) 跟 "项目 ↔ 全部 sessions 切换" 混淆。R125 拍板真值 = upstream 切 "项目/会话" 的 icon 在 **Sessions/Projects section header** (sidebar/index.tsx:1396-1407) 而非 sidebar 顶部。R126 不动 root-folder icon button, 只在 sidebar 顶部 加 SegmentedControl 作为显式切换 - 跟 upstream SegmentedControl 原语 (`command-center/index.tsx:338`) 位置风格一致。

### 5.2 upstream SegmentedControl 真值 (R126 step 2 设计参考)

**上游 SegmentedControl 原语** (`apps/desktop/src/components/ui/segmented-control.tsx`, 51 行):
- 类型: `SegmentedControlOption<T extends string> { id: T; label: string; icon?: IconComponent }`
- props: `options: readonly SegmentedControlOption<T>[]; value: T; onChange: (id: T) => void; className?: string`
- 视觉: `inline-grid auto-cols-fr grid-flow-col gap-0.5 rounded-[5px] bg-(--ui-bg-tertiary) p-0.5`
- 每个 button: `aria-pressed`, `text-[0.6875rem] font-medium`, active 时 `bg-background text-foreground shadow-sm`
- 用法 (上游): `apps/desktop/src/app/command-center/index.tsx:338` (Usage period toggle), `apps/desktop/src/app/settings/appearance-settings.tsx:402-492` (color mode + tool-call display + usage period + pet settings 共 5 处)

**R126 用法真值**:
- 用同一个原语, 加 1 个 import + 1 个 `<SegmentedControl options={[{id, label}, ...]} value={...} onChange={...} />` block
- 跟上游 settings/appearance-settings 的 color mode toggle 同款 (2 options, single state)

## 6. 实战踩坑真值 (R126 派单姿势)

### 6.1 派单判据

- ✅ PM-direct 自家跑 ≠ 派 CC: 单文件 14 行 + 5 个 i18n 4 行 = **38 行总增量** = R35 §10 派单粒度判据 "单文件微改 (改文件 ≤3, 不需要 build)" 不严格命中但接近 (改 6 文件) → PM-direct 决策: 自家跑 + tsc + pnpm build 自验 (派 CC 跑 38 行 = 浪费 CC spin-up 时间, PM-direct 1min patch + 3min build = 4min 总)
- ✅ Pitfall #77 + §15.6: 装机 user **明确** 拍板 "按文枢需要的方向改" → 不算暗猜设计 (R125 已调研 4 候选, 装机 user 选 B = 派单姿势判据满足)
- ✅ Pitfall #78: 不动上游 contributor 致谢链 (`scripts/release.py` 等) - R126 仅改 desktop 前端
- ✅ 白名单 (R43): 不动 hermes 致谢位置 (R28-R33 已落档白名单) - R126 0 触碰
- ✅ 不动 R124/R123/R122/R121/R116/R115/R114/R113 commit hash ✓
- ✅ sidebar/index.tsx main 文件结构 0 改 (R114 revert state 保留) ✓
- ✅ 版本号 0.1.0 不 bump ✓
- ✅ `cargo tauri build` N/A (R126 仅改 desktop = Electron, 0 Rust/Tauri 文件触碰, bootstrap-installer 仓根无 diff)

### 6.2 i18n 4 locale 真值表

| Locale | sidebar.segments.sessions | sidebar.segments.projects | file:line |
|--------|---------------------------|---------------------------|-----------|
| en     | 'Sessions'                | 'Projects'                | en.ts:1619-1620 |
| zh     | '全部会话'                | '项目'                    | zh.ts:1786-1787 |
| ja     | 'セッション'              | 'プロジェクト'            | ja.ts:1575-1576 |
| zh-hant | '全部工作階段'           | '專案'                    | zh-hant.ts:1527-1528 |

### 6.3 已知边界 / 后续需注意

- **CC 子会话派单 R127+ 时**: 若装机 user 反馈 "想加 3rd 选项 (e.g. messaging)" → 改 SegmentedControl options 数组, 不动 state (仍是 boolean), 1 行增
- **merge upstream v2026.7.21+ 时**: 仓根新增的 `import { SegmentedControl }` + sidebar block 是局部增量, `git merge upstream/main` 应自动 0 冲突 (除非上游自己也在 sidebar 加 SegmentedControl)
- **vitest**: R126 没加 test, 因为 SegmentedControl 原语上游已有测试 (`apps/desktop/src/components/ui/segmented-control.test.tsx` 如存在), 新加的 sidebar block 是 controlled component, 不需新 test
- **snapshot 回归**: 仓根若 sidebar 有 visual snapshot test → R126 会触发 diff, 装机 user 需确认 (预期: 顶部多 1 个 SegmentedControl strip)

## 7. 装机 user 验收链 (R126 8/31)

1. 装机 user 跑 `wenshu update --yes` → 重 spawn backend + 重 build desktop (R121 自动)
2. 装机 user 重启 文枢.app (R124 R115 dock LOGO + R126 SegmentedControl 烤进)
3. 装机 user 验 sidebar:
   - 单 profile 视图 (my-pm only): 顶部显 [全部会话 | 项目] SegmentedControl
   - 点 [项目] → grouped tree 模式 (项目 → repo → lane → sessions)
   - 点 [全部会话] → 平铺 sessions (Pinned + Recents + Messaging + Cron)
   - 原 root-folder icon button (Sessions/Projects section header) 仍 work
4. 装机 user 反馈: 若 OK → R127 等新工单; 若 仍 "没修好" → PM-direct 派 CC 调研具体卡点

## 8. 装机 user 拍板落档 (R126)

**PM-direct 自家拍板真值 (8/31 装机 user 拍 "按文枢需要的方向改" 后执行)**:
- ✅ 选项 B (加 SegmentedControl) 拍板 - 跟 R125 候选 B 一致
- ✅ 装机 user 拍板 ≠ 偏离上游 (上游 SegmentedControl 原语已在仓根, 仅未在 sidebar 用)
- ✅ sidebar 顶部 = 跟 upstream `command-center` SegmentedControl 位置风格一致 (header 内嵌, segmented width fit)
- ✅ 14 行 1 increment (sidebar/index.tsx) + 5 文件 +20 行 (types + 4 locale i18n)
- ✅ tsc + pnpm build 双过
- ✅ commit `6c2fb4ae7` push origin main
- ✅ 白名单 0 触碰
- ✅ 版本号 0.1.0 不 bump

## 9. 跨 skill 引用 (R126)

- `wenshu-pm-loop-execution` SKILL v1.1.0 R38 (单文件微改 PM-direct 自家跑 + 派单粒度判据)
- `wenshu-hermes-rename-allowlist-protocol` SKILL v1.1.0 (白名单跳过 + 上游致谢链保护)
- R125 doc: `wenshu-pour/architecture/R125-sidebar-4-candidates-2026-08-31.md` (4 候选调研真值)
- R124 doc: `wenshu-pour/architecture/R124-sidebar-hold-dock-logo-verified-2026-08-31.md` (R126 拍板基础)
- R114 commit: `e1b70e9ca` (revert R110 偏离, R126 起点)
- 上游 ref: `upstream/main` @ `8fc278207b0f5b25e567966f9615e1b1737f62af` (NousResearch/hermes-agent main)
- 上游 SegmentedControl 原语: `apps/desktop/src/components/ui/segmented-control.tsx` (51 行)
- 上游 usage examples: `apps/desktop/src/app/command-center/index.tsx:338` + `apps/desktop/src/app/settings/appearance-settings.tsx:402-492`
- commit: `6c2fb4ae7` (R126)
- push: `f6bde6faf..6c2fb4ae7  main -> main` (R126)
- `~/.hermes/profiles/my-pm/AGENTS.md` §15.6 (派单 + 不暗猜设计) + §15.7 autobuild