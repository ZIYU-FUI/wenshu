# 装机 user 拍板 (7/25 19:30): 数据层拍板真值

## 拍板: 不引入数据库

文枢 v1.0 + v2.0 沿用 "文件系统 + hermes 自带 SQLite", **不引入新数据库**.

## 理由 (5 条)

1. **文件系统 + hermes 自带 SQLite 够用**: 5 元组 / 章节 / 资料库 / worktree / 笔法库 / 标签枚举 / 项目组机制, 全部用文件系统 + hermes 现有 SQLite
2. **装机 user 用 Obsidian 读项目目录**: 文件系统 + Markdown = 装机 user 私域 OB md 真值匹配, 不需要 DB
3. **DB 增加架构复杂度**: DB schema 维护 + migration + ORM + connection pool = 装机 user 拍 "不激进" + "找得回来" 原则违反
4. **hermes 自带 SQLite 4 个 DB 已经在用**: kanban.db / projects.db / sessions.db / memory provider, 再加新 DB = 重复造轮子
5. **装机 user 装 wenshu 后个性化** (`~/.wenshu-hermes/authors/<author>/voice-dna.md`): 用户提交私有作者, 作者库自动增长, 文件系统比 DB 更自然

## 装机 user 后续真要 DB 拍板路径 (v2.0+)

- 沿用 hermes 自带 SQLite, 不重写
- 拍 "哪个需求 DB 真必要" 再决定 (哪个查询性能 / 跨设备同步 / 一致性约束真必要)

## hermes 自带 SQLite (不重写)

| DB | 用途 | 装机后是否够用 |
|---|---|---|
| `kanban.db` | 任务管理 (PM↔CC 协作) | ✅ |
| `projects.db` | 项目 + worktree + branch | ✅ |
| `sessions.db` | 会话历史 | ✅ |
| `memory/` (provider) | 长期记忆 | ✅ |

## 文枢 v1.0 数据需求 (全部文件系统)

| 数据需求 | 落档位置 | hermes 方案 |
|---|---|---|
| 5 元组项目目录 | `~/.wenshu-hermes/projects/<project>/{时间,场景,角色,资料库,大纲,章节}/` | 文件系统 |
| worktree 试不同走向 | `~/.wenshu-hermes/projects/<project>/.worktrees/<branch>/` | hermes `git worktree` + `projects.db` |
| 笔法库 (12 作者 voice-dna) | `~/.wenshu-hermes/methodologies/style/{README,INDEX,lu-xun,luo-guanzhong,lu-xun-voice-dna}.md` + `authors/<author>/voice-dna.md` | 文件系统 |
| 100 标签枚举 | `~/.wenshu-hermes/taxonomy/{tags-index.md, skills/<9-维度>/SKILL.md}` | 文件系统 (Markdown + YAML frontmatter) |
| 章节内容 | `~/.wenshu-hermes/projects/<project>/章节/*.md` | 文件系统 (装机 user 用 Obsidian 读) |
| 资料库三层 | `~/.wenshu-hermes/projects/<project>/资料库/{raw,entity,concept}/` | 文件系统 |
| 一致性守护 | LLM + filesystem 检索 (grep / read_file) | LLM tool |
| 项目组机制 | hermes `delegate_task` + `acp_adapter` (SQLite 够用) | hermes 自带 |

## 装机 user 拍板 5 件事 (7/25 19:30 拍板: 不引入 DB)

1. ✅ 不引入 DB (文件系统 + hermes 自带 SQLite 够用)
2. ✅ 项目数据全部在文件系统 (`~/.wenshu-hermes/projects/<project>/`)
3. ✅ 章节 / 资料库 / 笔法库 / 标签 / 私有作者全部 Markdown + YAML (不用 DB)
4. ✅ 跨项目检索 (一致性守护 / 反向建议员 / 调研员) 用 filesystem 检索 (grep / read_file)
5. ✅ 装机 user 后续真要 DB 拍板路径: 用 hermes 自带 SQLite 不重写, 拍 "哪个需求 DB 真必要" 再决定

## 派单节奏 (PM-direct 自决)

按 R16 + "commit 我自决, 不用问" + "用法无定法" 协议, PM-direct 自决派单:

- 装 user 提需求 → PM-direct 5 分钟调研 hermes 官方文档 (装 user 7/24 立 "任何事前先找官方文档")
- PM-direct 5 分钟拍板真值 (装 user 视角 / wenshu 方向 / 是否依赖装 user 视觉)
- 派单 (WO-XXX) → 落档 wenshu-pour/ → commit (PM-direct 自决) → 装 user 周末审改

## 装 user 后续提需求 — PM-direct 不调研硬规则 (8/25 拍)

> 装机 user 8/25 拍板: "这些是文枢需要补的功能 hermes 没有, 不用调研, 我之后会提需求"
> 装机 user 7/25 拍板: "你查一下官方文档去吧, 我记得我已经和你提过要求, 做任何事前先去找官方的文档"
> → 装 user 提需求时, PM-direct 5 分钟调研官方文档 (不调研硬规则优先), 拍板真值落档, 不下 "X 不存在" 结论 (Mem0 原则).

## 关联拍板

- `wenshu-pour/architecture/system-overview.md` — 大概括 (system overview)
- `wenshu-pour/install-boundary.md` — 装机内容 vs PM 沉淀 边界
- `wenshu-pour/README.md` — 目录说明
- `wenshu-pour/methodologies/style/` — 笔法库 (12 作者 voice-dna)
- `wenshu-pour/user-stories.md` — Story 1/2/3 + 15 场景 + 项目组机制
- `wenshu-pour/legacy-surveys/` — 8 老项目 + novel-platform 调研

## 装机 user 后续提需求路径

按 hermes 自带 + 文枢沿用, 装机 user 后续提需求时:

- **多 hermes 桥接** (跨设备 / 跨主机) → hermes gateway + multi-profile gate 调研
- **hermes 监控** (晚上掉了没人知道) → hermes logs + cron 调研
- **跨设备共享数据层** (改公司级共享) → hermes gateway 调研
- **笔法库 UI / 项目组 UI / worktree UI** → hermes Desktop / TUI 调研
- **100 标签大调研** → 各大书平台调研 (书格 / 起点 / 晋江 / 番茄 / 当当 / 微信读书 / 豆瓣 / Kindle / 掌阅)
- **author-imitator skill 装机** → hermes skills/ 调研 + install.sh 拷入

每个需求 PM-direct 5 分钟调研 → 拍板 → 派单 → 落档 wenshu-pour/ → commit → 装 user 周末审改.