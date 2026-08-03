# 文枢 fork 改动基线清单

> 拍板日期: 2026-08-31
> 拍板真值: 装机 user 拍 "走薄 fork + 重插件(路 B)"
> 起草人: PM-direct
> 状态: 装机 user 拍板真值 + 实测 fork 改动清单

---

## 0. 装机 user 拍板真值 (8/31)

文枢 = **薄 fork + 重插件** 架构,5 类不可拆留在 fork,其余功能拆 plugin。

### 5 类不可拆 (留在 fork)

1. **品牌字符串 + appId + displayName** — 全 monorepo "Hermes" → "文枢"
2. **venv 隔离** — `~/.wenshu-hermes/` 取代 `~/.hermes/`
3. **砍 ladder rung 1-4** — electron main.ts 改 startup detection
4. **build / installer / update 链条** — bootstrap-installer / wenshu_cli/subcommands/update.py / scripts/install.{sh,ps1,cmd}
5. **中文版/装机版 LOGO + icon + locale 资源**

---

## 1. fork 真实改动清单 (8/31 17:05 实测)

基线 = `3ef6bbd20` (v2026.7.20 / hermes 0.19.0) → HEAD = `c6aacf605` (R135)
统计: 4665 文件差异 (3007M + 227A + 714D + 717R),其中绝大多数是 rename (`hermes_cli/` → `wenshu_cli/`)

### 1.1 T0 · 不可拆 (核心 fork 文件,装机 user 拍板)

| 文件 | 改动行数 | 类别 | 说明 |
|------|---------|------|------|
| `apps/desktop/electron/main.ts` | 914 | T0 | ladder 砍位 + venv 隔离 + 品牌 |
| `scripts/install.sh` | 806 | T0 | 全平台 installer |
| `scripts/install.ps1` | 330 | T0 | Windows installer |
| `apps/bootstrap-installer/src-tauri/src/paths.rs` | 296 | T0 | Tauri 路径 + venv |
| `apps/bootstrap-installer/src-tauri/src/update.rs` | 211 | T0 | update 流程 |
| `apps/bootstrap-installer/src-tauri/src/install_script.rs` | 175 | T0 | install script 调用 |
| `apps/desktop/electron/preload.ts` | 141 | T0 | preload bridge |
| `apps/bootstrap-installer/src-tauri/src/lib.rs` | 127 | T0 | Tauri 入口 |
| `apps/bootstrap-installer/src-tauri/src/bootstrap.rs` | 86 | T0 | bootstrap 流程 |
| `apps/desktop/electron/bootstrap-runner.ts` | 115 | T0 | bootstrap runner |
| `apps/bootstrap-installer/src-tauri/src/powershell.rs` | 108 | T0 | PowerShell 桥 |
| `apps/bootstrap-installer/vite.config.ts` | 65 | T0 | installer build |
| `apps/bootstrap-installer/src/main.tsx` | 41 | T0 | installer UI 入口 |
| `scripts/lib/node-bootstrap.sh` | 59 | T0 | Node bootstrap |
| `scripts/release.py` | 41 | T0 | release 脚本 |

合计 ≈ **3500 行 fork-only 改动,15 个核心文件**。三方 merge 真正手解冲突的面积 = 这 15 个文件 + lockfile + rename-aware 文件树。

### 1.2 T1 · i18n 翻译资源 (扔回 plugin 或接受 fork-only)

| 文件 | 改动行数 |
|------|---------|
| `apps/desktop/src/i18n/en.ts` | 200 |
| `apps/desktop/src/i18n/zh.ts` | 191 |
| `apps/desktop/src/i18n/ja.ts` | 175 |
| `apps/desktop/src/i18n/zh-hant.ts` | 173 |
| `apps/desktop/src/i18n/types.ts` | 37 |
| `apps/desktop/src/components/chat/intro-copy.jsonl` | 74 |

策略: **保留在 fork**(文枢有自己的 i18n 流程,4 套语言是装机版必备),但用文枢 i18n 体系而非 hermes 体系,三方 merge 时 i18n 冲突基本只改中文部分。

### 1.3 T2 · 应拆 plugin (待装机 user 拍板)

| 文件 | 改动行数 | R 系列 | 建议动作 |
|------|---------|--------|---------|
| `apps/desktop/src/app/chat/sidebar/project-dialog.tsx` | 54 | R135 新建项目对话框 | **拆去 plugin** |
| `apps/desktop/src/lib/commit-changelog.ts` | 55 | R108 changelog 中文化 | **拆去 plugin** |
| `apps/desktop/src/components/desktop-install-overlay.tsx` | 63 | 装机引导 | **拆去 plugin** |

(其他 R99/R124/R126/R135 sidebar 改造 = 18 文件 × 129 行,合计改动小,接受 fork-only 或拆 plugin 待装机 user 拍)

### 1.4 T3 · electron 自身代码 (R 系列相关,逐个验)

| 文件 | 改动行数 | 说明 |
|------|---------|------|
| `apps/desktop/electron/dashboard-token.ts` | 45 | dashboard token 校验 |
| `apps/desktop/electron/backend-probes.ts` | 55 | 后端探测 |
| `apps/desktop/electron/desktop-uninstall.test.ts` | 51 | 测试 |
| `apps/desktop/electron/update-relaunch.test.ts` | 32 | 测试 |
| `apps/desktop/electron/dashboard-token.test.ts` | 35 | 测试 |
| `apps/desktop/electron/connection-config.test.ts` | 30 | 测试 |
| `apps/desktop/package.json` | 41 | build metadata |

策略: **逐文件验**,如果是 R 系列桥接(我们没改的),扔回 fork-only;如果是真改逻辑,拆去 plugin。

---

## 2. 三方 merge 真实成本预估 (PM-direct 自验)

### 2.1 一次性三方 merge (撞墙实证)

PM-direct 在 `wt/sync-v2026.7.30` worktree 跑 `git merge -X theirs upstream/main`:
- **5189 文件级冲突**
- **411 rename 冲突** (上游新文件 `hermes_cli/xxx`,文枢 rename 父目录 `wenshu_cli/`)
- **2770 hunk 级 content 冲突**
- **PM-direct 单线预估 1-2 周**,易错,不可接受

### 2.2 拆 plugin 后三方 merge 成本预估

如果 §1.3 + §1.4 真拆去 plugin,期望冲突面积:
- T0 15 个核心文件 × 平均 100 行冲突 ≈ **1500 行手解**
- T1 i18n 4 文件 × 平均 50 行冲突 ≈ **200 行手解**
- rename-aware 文件树(文枢 `wenshu_cli/` vs upstream `hermes_cli/`) ≈ **rename 100 次,无内容冲突**
- **PM-direct 总成本预估 2-3 天**,可接受

---

## 3. 派单序列

- **WO-R137** [已完成] 三方 merge 撞墙实证 → 落档 .plans/wenshu-fork-rationalization.md
- **WO-R138** [本工单] fork 真实改动清单 → 落档 docs/fork-baseline.md (本文件)
- **WO-R139** [装机 user 拍板项] §1.3 + §1.4 拆 plugin 范围 (sidebar / commit-changelog / install-overlay / T3 electron 改造)
- **WO-R140** [CC 子会话, ≤ 3 并发] 拆 plugin: `apps/desktop/src/plugins/wenshu-sidebar/` + `apps/desktop/src/plugins/wenshu-projects/` + `apps/desktop/src/plugins/wenshu-install-overlay/`
- **WO-R141** [PM-direct] `git format-patch -o wenshu-patches/ <fork-base>..HEAD` 存档 fork 167 commit
- **WO-R142** [PM-direct] 在新 worktree `wt/sync-v2026.7.30-v2`,先 cherry-pick 关键 fork commit 到 upstream HEAD,手解冲突
- **WO-R143** [PM-direct] merge commit → origin main + gitcode mirror + 装机 user 跑 `wenshu update` 验

---

## 4. 装机 user 拍板项 (本工单内)

1. §1.3 拆 plugin 范围拍板:R135 sidebar/project-dialog → plugin? (yes/no)
2. §1.3 拆 plugin 范围拍板:R108 commit-changelog → plugin? (yes/no)
3. §1.3 拆 plugin 范围拍板:R 装机引导 desktop-install-overlay → plugin? (yes/no)
4. §1.4 T3 逐个验:由 PM-direct 自驱 / 装机 user 拍? (PM-direct / 装机 user)
5. plugin 仓地址拍板:`apps/desktop/src/plugins/` bundled 还是独立 repo? (bundled / runtime / 双轨)

---

*docs/fork-baseline.md v0.1 · 2026-08-31 · PM-direct · 装机 user 待拍板*