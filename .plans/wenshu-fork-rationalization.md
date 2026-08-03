# 文枢 fork 范围清理 + 上游 sync 路线图

> 拍板日期: 2026-08-31
> 拍板真值: 装机 user 拍 "走薄 fork + 重插件(路 B)"
> 起草人: PM-direct
> 状态: 立项,待装机 user 拍板具体动作

---

## 0. 背景

### 0.1 上游漂移现状 (8/31 17:05 实测)

- 文枢 fork HEAD = `c6aacf605` (R135), 基线 = `3ef6bbd20` (v2026.7.20 / hermes 0.19.0)
- vs `upstream/main` = **领先 167 commit / 落后 3865 commit** (共 4032 差距)
- 上游最新 tag = `v2026.7.30` (7/30 发布,文枢落后 10 天 / 1 个上游 release)
- `wenshu-patches/` 目录 **不存在** (AGENTS.md §10 写的"关键设计决策"是纸面策略)
- 装机 user 跑 `wenshu update` 走 `_sync_with_upstream_if_needed` (`wenshu_cli/main.py:7063`),检查 `origin_ahead > 0` 永远 SKIP → **永远拿不到上游**

### 0.2 第一次三方 merge 撞墙 (实测)

PM-direct 在 `wt/sync-v2026.7.30` worktree 跑 `git merge -X theirs upstream/main`:
- **5189 个文件级冲突**
- **411 个 rename 冲突** (上游新文件在 `hermes_cli/`,文枢 0.0.0 把父目录 rename `wenshu_cli/`)
- 2770 个 hunk 级 content 冲突
- **结论**: 3865 commit × 一次性三方 merge = PM-direct 单线 1-2 周死磕,且易错

### 0.3 根因

文枢 fork 在 core 层(全 monorepo 字符串 / 目录 rename / 砍 ladder rung 1-4)改得太重,跟 upstream 共享面只剩 ~10%,其余 90% 全是 fork 独有的 merge 负担。**不先做"fork 范围清理",sync 不可能跑通**。

---

## 1. 路 B 拍板真意 (装机 user 8/31)

文枢 = **薄 fork + 重插件** 架构:
- **fork 只留** 5 类不可拆的层 (品牌/appId/v 隔离/ladder 砍/build/update)
- **新功能 / 重 UI 改造** → 走 plugin (`apps/desktop/src/plugins/<name>/plugin.tsx` bundled + `$WENSHU_HOME/desktop-plugins/<name>/plugin.js` runtime)
- 跟上游漂移速度 = "fast-forward 上游 minor + 修 fork 那 5 个文件"

---

## 2. 拆 fork 范围清单 (PM-direct 自验,装机 user 拍板)

**核心问题**: 当前 fork 在哪些文件动过? 哪些能扔回 plugin? 哪些必须留在 fork?

### 2.1 必须留在 fork (装机 user 8/31 拍板"5 类不可拆")

1. **品牌字符串 + appId + displayName** — 全 monorepo "Hermes" → "文枢" (零冲突但面积大)
2. **venv 隔离** — `~/.wenshu-hermes/` 取代 `~/.hermes/` (R0/R5 era 改)
3. **砍 ladder rung 1-4** — electron main.ts 改 startup detection (0.0.3 工单,装机 user 拍)
4. **build / installer / update 链条** — bootstrap-installer / wenshu_cli/subcommands/update.py / scripts/install.{sh,ps1,cmd}
5. **中文版/装机版 LOGO + icon + locale 资源** — 纯资源文件

### 2.2 应该扔去 plugin (待装机 user 拍板)

- **sidebar 内部改造** (R99/R124/R126/R135) — dock LOGO / SegmentedControl / skeleton / 空状态 → 全部走 plugin
- **新建项目对话框 R135** — 走 plugin
- **任何 chat composer 扩展 / 新页 / 重 UI 改造** — 走 plugin

### 2.3 不动 (本来就该跟 upstream 一致)

- 核心 session / chat / gateway / agent loop / MCP / skills
- electron main 的 IPC / dialog / Menu / Tray (不动)
- wenshu_cli 大部分 (除了 update / subcommands 中文化部分)

---

## 3. 行动序列 (PM-direct 派单, 拆 ≤ 3 并发)

### 阶段 1: fork 范围自检 (本周)

- **WO-R137** [PM-direct] 跑三方 merge 撞墙实证 → 写进本 plan (§ 0.2 已完成)
- **WO-R138** [PM-direct] `git diff --stat 3ef6bbd20..HEAD` + `git diff --name-only --diff-filter=R 3ef6bbd20..HEAD` → 输出"文枢 fork 改了什么文件清单" (期望 ≤ 200 文件真正 fork-only,其余是 rename / 字符串替换)
- **WO-R139** [PM-direct] 把 fork 改动按 §2.1 / §2.2 / §2.3 分类,产出 `docs/fork-baseline.md` (装机 user 拍板真值)
- **WO-R140** [PM-direct] AGENTS.md / CLAUDE.md / README.md 三处 "wenshu-patches" 落档 (装机 user 拍"改不动 + 不动 + 不动")

### 阶段 2: 把 §2.2 拆成 plugin (下周末)

- **WO-R141** [CC 子会话, ≤ 3 并发] 建 `apps/desktop/src/plugins/wenshu-sidebar/` bundled plugin,搬 sidebar 改造 (R99/R124/R126/R135) 进 plugin,验证关掉 plugin 时 sidebar = 上游一致
- **WO-R142** [CC 子会话] `apps/desktop/src/plugins/wenshu-projects/` bundled plugin,搬新建项目对话框 R135
- **WO-R143** [PM-direct] 编译 + 装机 user 跑 `wenshu update` 验插件热加载

### 阶段 3: 三方 merge 真正跑 (阶段 2 完成后)

- **WO-R150** [PM-direct + CC 子会话] `git format-patch -o wenshu-patches/ <fork-base>..HEAD` 把当前 fork 改动存档
- **WO-R151** [PM-direct] 在新 worktree `wt/sync-v2026.7.30-v2`,先 cherry-pick fork 自己的 167 commit 到 upstream HEAD,手解冲突 (期望冲突数 ≤ 50 因为插件已拆)
- **WO-R152** [PM-direct] merge commit → origin main + gitcode mirror + 装机 user 跑 `wenshu update` 验

### 阶段 4: 装机 user 试装 (阶段 3 完成后)

- **WO-R160** [PM-direct] 出 `WenShu-Setup.dmg` 拷给装机 user
- **WO-R161** [PM-direct + 装机 user] 装机 user 装机 + 跑 `wenshu update` → 验 0.19.1 (上游新功能) 真能用上

---

## 4. 风险

| 风险 | 缓解 |
|------|------|
| 阶段 2 拆 plugin 时发现 sidebar 改造跟 core 强耦合 | 退回到 fork 改,接受"这个改动不漂移",PM-direct 在 docs/fork-baseline.md 标注 "must-fork" |
| 三方 merge 冲突还是太多 (> 200 文件) | 走阶段 1.5: 上游先 cherry-pick 不冲突的 minor patch,跟 upstream 渐进合 |
| 装机 user 拒绝把 sidebar 改造拆去 plugin (嫌麻烦) | 走原路 A: 死磕三方 merge,接受滞后 1-2 周节奏 |
| wenshu-patches 落档后下一次 sync 仍然冲突多 | 用 `rerere` 缓存冲突解法 (`git config rerere.enabled true`) |

---

## 5. 装机 user 拍板项 (待回复)

1. **§2.2 拆 plugin 范围** 拍板:R99/R124/R126/R135 sidebar 改造 → plugin? (yes/no)
2. **§2.2 拆 plugin 范围** 拍板:R135 新建项目对话框 → plugin? (yes/no)
3. **WO-R141 首批 plugin 仓地址** 拍板:`apps/desktop/src/plugins/wenshu-sidebar/` 还是独立 repo? (bundled / runtime / 双轨)
4. **三方 merge 节奏** 拍板:阶段 3 一次冲到 v2026.7.30,还是分批 cherry-pick? (一次 / 分批)

---

*plan v0.1 · 2026-08-31 · PM-direct · 装机 user 待拍板*