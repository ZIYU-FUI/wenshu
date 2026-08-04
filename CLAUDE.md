# CLAUDE.md · WENSHU scaffold(给 Claude Code 读)

> v0.2 · 2026-08-04
> **CC 接到 wenshu 工单前必读本文件**。本文件不重复真理,只把真理指向 `AGENTS.md` v0.2。

---

## 1. 真理源(必读,违反 = 越界)

`AGENTS.md` v0.2 = `/Volumes/ANAN/Engineering/wenshu/AGENTS.md`
(`cat` 一遍 ≤ 5 分钟;§1 角色边界 / §5 拍单边界 / §7 客户侧硬约束 / §12 红线 / §13 项目基线 必看)

**SDK 细节**:`~/.hermes/skills/autonomous-ai-agents/hermes-agent/references/desktop-plugins.md`
(模板在 `~/.hermes/.../templates/plugin.js`)

## 2. 项目根(唯一)

`~/wenshu-plugin/`(本仓库)—— 所有源码在这里,git 单一来源。
**不要** 在 `~/Documents/` / `~/.wenshu/` / `/Volumes/ANAN/Engineering/wenshu/`(旧 fork) 写文件。

## 3. CC 红线(违反 = 整条工单作废 + 越界)

| 红线 | 出处 |
|------|------|
| 不动 `~/.hermes/hermes-agent/` 下任何文件 | AGENTS §12 |
| 不动 `~/.hermes/desktop-plugins/` 已有 hermes 内置 plugin | AGENTS §12 |
| 不动 `~/.hermes/profiles/` 下任何非 wenshu profile | AGENTS §12 |
| 不写 `~/.wenshu/` 任何文件(目录已取消) | AGENTS §7 / §12 |
| 不自写 `wenshu` CLI(走 hermes 原生) | AGENTS §12 |
| 不参考 `/Volumes/ANAN/Engineering/.archive/novel-platform/` | AGENTS §9 / §12 |
| 不改 plugin manifest 的 `id` / `name` / `version` | AGENTS §5 / §12 |
| 不带 novel-platform Tauri / Rust / SQLite / Vue 3 痕迹 | AGENTS §13 |
| 不带 sparse clone 假设 / monorepo fork 假设 | AGENTS §13 |
| 不带 novel-craft / Hermes-Slate-Desk 旧 V0.5.x 协议 | AGENTS §13 |
| 不复用 hermes 上游 4-tier ladder rung 1-4 | AGENTS §13 |
| 不替 PM 验收 / 不派工单 / 不进 PM↔CC loop | AGENTS §1 |
| 跳质量门禁 / 改 plugin API 签名 / 跨阶段门 = 必须问装机 user | AGENTS §5 |

## 4. 写到本仓库的边界(CC 的工作面)

- ✅ `desktop-plugin/plugin.js`(单 ESM 文件,无 build)
- ✅ `plugins/wenshu/dashboard/plugin_api.py`
- ✅ `plugins/wenshu/dashboard/editors/*.py`(8 个 stub module)
- ✅ `plugins/wenshu/manifest.yaml`(改 `version` / `description` OK,改 `id`/`name` = 越界)
- ✅ `scripts/install.sh` / `scripts/verify.sh`
- ✅ `README.md` / `CLAUDE.md` / `.gitignore` / `CHANGELOG.md` / `loop-run-log.md`
- ❌ `AGENTS.md` / `WORKLOG.md` / Kanban 工单 / hermes 上游监测报告(归 PM)

## 5. SDK 行为合约(写 plugin.js 前必看)

- ONLY imports resolve: `@hermes/plugin-sdk`, `react`, `react/jsx-runtime`
- UI 是 `jsx('div', {...})`,**不**是 JSX 语法(文件 uncompiled 加载)
- 默认 export shape: `{ id, name, register(ctx) { ... } }`
- `id` 必须 = 文件夹名(本项目 `wenshu`)
- 主题色**只能**用 `var(--ui-*)`,不硬编码(`#000` / `black` / `rgb(...)` 都禁)
- `ctx.register({ id, area, data, render })` 关键 area:
  - `'panes'` + `data.placement: 'main'|'left'|'right'|'bottom'` + 可选 `data.dock: { pane, pos }`
  - `SIDEBAR_NAV_AREA` + `data: { path, label, codicon }`
  - `PALETTE_AREA` + `data: { id, label, tip?, keywords?, run }`
  - `ROUTES_AREA`(本项目 v0.1.0 不用,启动页走 panes area 模式)
- Backend 调用 = `ctx.rest('/path', { method, body })` → `/api/plugins/wenshu/path`

## 6. 本机自检(完工前必跑)

```bash
cd ~/wenshu-plugin
./scripts/verify.sh     # node --check + python import + 8 editor + profile 检查
```

verify.sh 是只读检查,不动 `~/.hermes/`。`scripts/install.sh` 才会 rsync 到
hermes runtime —— CC 跑 `verify.sh` 后让 PM 决定是否跑 `install.sh`。

## 7. 报越界决策(给装机 user 拍)

如果遇到 AGENTS.md 没明说的边界(SDK 没明文 / hermes 端 venv 坏掉 / SDK 行为
跟 reference 描述不符 / 需要建新 profile 但 CLI 挂了),**记录到工单 feedback**:
- 触发场景
- 候选方案
- 选了哪个 + 理由
- 装机 user 拍板后是否要回写 AGENTS.md

## 8. 阶段门控(本仓库当前在 0.1.0)

- 0.1.0 scaffold = 已完成
- 0.2.0 = 引导式对话小说主场景(8 编辑真逻辑)
- 0.3.0 = 多方法论融合 UI
- 0.4.0 = hermes 兼容性 + 跟版
- 0.5.0+ = 长尾

跨阶段(0.1.x → 0.2.x)= **问装机 user**(AGENTS §5)。

---
*CLAUDE.md v0.2 · 2026-08-04 · 真理源:AGENTS.md v0.2*
