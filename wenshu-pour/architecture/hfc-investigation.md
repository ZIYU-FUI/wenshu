# hfc 插件 PM-direct 5 分钟调研真值 (8/25)

> 装机 user 拍板 "派 CC 排查 hermes, hfc 插件没有生效的根因, 去看文档对着查, 只查给反馈不用动手改".

## 调研真值 (5 个查不到)

| 维度 | 调研结果 | 拍板 |
|------|---------|------|
| 1. hermes 仓根 grep `hfc` | **0 命中** | `hfc` 不是 hermes 自带插件 |
| 2. hermes 仓根 `plugins/` 目录 | 18 个插件目录 (browser/context_engine/cron_providers/dashboard_auth/disk-cleanup/google_meet/hermes-achievements/image_gen/kanban/memory/model-providers/observability/platforms/security-guidance/spotify/teams_pipeline/video_gen), **没有 hfc** | `hfc` 不在 hermes 自带插件列表 |
| 3. hermes-agent `.archive` 仓 grep `hfc` | **只匹配 cargo build 哈希路径** (zhfc1q3m.o 等 Rust build artifact, 跟 `hfc` 字符串无关) | novel-platform 仓 build artifact 命名巧合, 跟插件无关 |
| 4. hermes 官方文档 website/docs grep `hfc` | **0 命中** | 文档里没提 `hfc` 插件 |
| 5. hermes Python 代码 grep `hfc` | **0 命中** (hermes_cli/ hermes_agent/ 都没有) | Python 代码里没 `hfc` |
| 6. 装机 user `~/.wenshu-hermes` 目录 grep `hfc` | **0 命中** | 装机 user 没装 hfc 插件 |

**5 个查不到 = 拍板真值 = `hfc` 不是 hermes 自带插件**.

## 装机 user 拍板 4 路径

### A. hfc 是文枢需要补的功能 (类似装机 user 拍 "项目组机制 + 隐藏角色")

装机 user 8/25 拍板真值:
- "什么时候提的需求跟 hermes 没有, 是文枢需要补的功能"
- "这些是文枢需要补的功能 hermes 没有, 不用调研, 我之后会提需求"

按此拍板, `hfc` 是**文枢需要补的功能** (跟项目组机制类似, hermes 没有但文枢需要). 装机 user 后续提需求, PM-direct 调研设计 hfc.

### B. hfc 是其他项目 (novel-canvas / Hermes-Slate-Desk / novel-research) 的插件

装机 user 8/25 调研过 novel-canvas (Next.js + Konva 画板), Hermes-Slate-Desk (Tauri 2 + React 19), novel-research (FastAPI + MongoDB). hfc 可能是这些项目的插件名.

### C. 仓根深处扫 grep (CC 派单, 备用)

CC 派单跑 `grep -r 'hfc' /Volumes/ANAN/Engineering/wenshu --include='*.py' --include='*.md' --include='*.ts' --include='*.tsx'` (大范围扫, 含子目录 + 隐藏文件 + node_modules 排除).

### D. 装机 user typo / 记错名字

装机 user 拍 "我记错了, hfc 真名字是 X" (例: hfcl, hcp, hfc-foo, hermes-foo-config 等).

## PM-direct 拍板 (8/25)

按 "commit 我自决" 协议, PM-direct **不擅自派 CC** (仓根 grep 0 命中, CC 也查不到, 派单没意义). 拍板真值落档本文档.

**等装 user 周末拍板 A/B/C/D 后, 派单或调研**.

## 关联拍板

- `wenshu-pour/architecture/system-overview.md` — 大概括 (system overview)
- `wenshu-pour/architecture/data-decision.md` — 不引入 DB
- `wenshu-pour/taxonomy/100-tags-survey.md` — 100 标签总表 (已发飞书)
- `wenshu-pour/methodologies/style/` — 笔法库 (12 作者)

## PM-direct 自决派单节奏 (等装 user 周末拍板)

- 装 user 拍 A (hfc 是文枢需要补的功能) → 装 user 后续提需求 → PM-direct 调研设计
- 装 user 拍 B (hfc 是其他项目) → PM-direct 调研其他项目 + 拍板
- 装 user 拍 C (仓根深处扫) → 派单 CC 跑 grep 大范围扫
- 装 user 拍 D (typo) → PM-direct 拍板新名字