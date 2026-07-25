# wenshu-pour/architecture/system-overview.md
# PM-direct 自决派单 WO-001AA — 装机 user 7/25 拍 "可以, 把我们暂定的文档对应放到目录里吧"

# 文枢系统总览 (大概括文档)

> 文枢 = 写作助手 + 默认方法论 + 项目组机制 + 装机后用户个性化 (用户私域).
> 本文档 = 大概括, 装 user 周末看完整张图, 装 user 后续提需求时 PM-direct 查本图.

## 1. 装机 user 视角

装机 user 装 wenshu 后看到:

```
~/.wenshu-hermes/                              # hermes 自带隔离目录 (1:1 跟 ~/.hermes/)
├── config.yaml                                # hermes config (含 wenshu 默认段落)
├── SOUL.md                                    # wenshu 默认写作助手身份 (装机 user 装机读)
├── AGENTS.md                                  # wenshu 7 步工作流 (装机 user 操作手册)
├── methodologies/                             # 装机脚本拷入 wenshu/methodologies/ (9 公版 + 法无定法)
│   ├── README.md                              # 拍板入口
│   ├── INDEX.md                               # 5 表
│   ├── foundations/                           # Aristotle/Freytag/Hero's Journey/Snowflake/Seven Basic Plots
│   ├── classical/                             # 5W1H/Inverted Pyramid/IMRaD
│   ├── commercial/                            # AIDA
│   ├── examples/                              # SCQA
│   ├── style/                                 # 笔法库 (装机 user 拍板)
│   │   ├── README.md                          # 4-axis 提炼说明
│   │   ├── INDEX.md                           # 5 表 + 装 user 拍板入口
│   │   ├── lu-xun.md                          # 公版模板
│   │   ├── luo-guanzhong.md                   # 古人模板
│   │   ├── lu-xun-voice-dna.md                # 实际蒸馏示例
│   │   └── authors/                           # 装机后用户提交的私有作者 voice-dna (不预装)
│   └── lego/                                  # 节点碎片库 (v1.0+ 拍板重建, 装 user 拍)
├── authors/                                   # 装机后用户提交的私有作者 voice-dna (用户私域)
├── projects/                                  # 装机 user 写小说时建 (Story 1 5 步向导建项目, 5 元组 + OB md 6 目录 + worktree)
└── agent-team/                                # 项目组机制 (9 隐藏角色 + 协调员, v1.0+ 拍板)
```

## 2. wenshu-pour/ 项目文件夹结构 (PM-direct 私域, 不打包给装机 user)

```
wenshu-pour/
├── README.md                                  # 目录说明
├── install-boundary.md                        # 装机边界 (装机内容 vs PM 沉淀)
├── user-stories.md                            # Story 1/2/3 + 15 场景 + 项目组机制 + 笔法库
├── legacy-surveys/                            # 调研报告 (PM 沉淀)
│   ├── README.md
│   ├── 8-legacy-projects-survey.md            # 8 项目调研 (~58KB)
│   └── novel-platform-survey.md                # 1 项目调研 (~26KB)
├── methodologies/                             # 笔法库 + 人物库 (装机 user 拍板)
│   └── style/
│       ├── README.md                          # 4-axis 提炼说明
│       ├── INDEX.md                           # 5 表 + 装 user 拍板入口
│       ├── lu-xun.md                          # 公版模板
│       ├── luo-guanzhong.md                   # 古人模板
│       ├── lu-xun-voice-dna.md                # 实际蒸馏示例
│       └── authors/                           # (未来) 装 user 提交私有作者的蒸馏路径
├── architecture/                              # 架构文档 (装机 user 拍板)
│   └── system-overview.md                     # 本文档 (大概括)
├── agent-team/                                # (未来) 项目组机制 9 隐藏角色 + 协调员
├── user-stories/                              # (未来) Story 2 v0.3/v0.4 草稿
└── research/                                  # (未来) PM-direct 调研报告
```

## 3. 装机内容 vs PM 沉淀 边界 (按 wenshu-pour/install-boundary.md)

### 装机内容 (wenshu/ 仓根, 装机脚本拷入 ~/.wenshu-hermes/)
- `wenshu/SOUL.md` — 默认写作助手身份 (装 user 装机读)
- `wenshu/AGENTS.md` — 7 步工作流 (装 user 操作手册)
- `wenshu/methodologies/{foundations,classical,commercial,examples}/` — 9 公版方法论 + SCQA
- `wenshu/methodologies/{README.md, INDEX.md}` — 拍板入口 + 5 表
- desktop app + installer (Tauri)

### 不打包给装机 user (PM-direct 私域, 在 wenshu-pour/)
- `wenshu-pour/` — PM-direct 调研 + 拍板沉淀 + Story 草稿 + 架构文档
- `wenshu/docs/` — 仓根 docs (协作过程留痕)
- 调研报告 — 派 CC 调研时写
- 8 老项目调研 — 装机 user 之前的活跃项目调研 (legacy-surveys/)
- novel-platform 调研 — 装机 user 之前的活跃项目调研 (legacy-surveys/)

### 装机后用户提交 (在 ~/.wenshu-hermes/, 不打包)
- `~/.wenshu-hermes/authors/<author-name>/voice-dna.md` — 装机后用户粘 1-2 段代表片段, 自动蒸馏
- `~/.wenshu-hermes/methodologies/style/authors/<author-name>.md` — 装机后用户私有作者笔法
- `~/.wenshu-hermes/projects/<project-name>/` — 装机 user 写小说时建 (Story 1 5 步向导)

## 4. 文枢需要补的功能 (装机 user 后续提需求, hermes 没有)

### 4.1 装机后用户提交私有作者 (PM-direct 自决拍板)

- **现状**: hermes 自带 author-imitator skill (aif profile 装的, 581 行 SKILL.md, 4-phase pipeline, copyright-handling 4-path 决策树). 但 hermes 装机用户默认没有 author-imitator.
- **文枢补的功能**: 装机脚本把 author-imitator skill 拷入 `~/.wenshu-hermes/skills/author-imitator/` (或 symlink), 装机用户可在 wenshu 里调.
- **装机 user 提交私有作者流程** (author-imitator Path A — 装机 user 拍板 7/25):
    1. 装机 user 粘 1-2 段 (200-500 字) 已合法持有的纸质书 / 电子书
    2. 跑 Phase 1 (语料) → `source: user_paste`
    3. 跑 Phase 2 (思维蒸馏) → `confidence: high` (真本)
    4. Phase 3 (5 轴评分) → 自动统计
    5. Phase 4 → 输出 `~/.wenshu-hermes/authors/<author-name>/voice-dna.md`
- **不侵权**: 文枢只蒸馏用户**已合法持有**的片段, 不抓盗版, 不传播完整作品. 装机 user 怎么用不归文枢管 (wenshu-pour/install-boundary.md 协议).

### 4.2 多 hermes 桥接 (装机 user 7/24 拍板: 跨设备多主机, 每个主机跑自己的 hermes, 桥接) — PM-direct 后续调研

- hermes 自带 gateway + multi-profile gate, 但**官方文档没承诺多 hermes 桥接** (PM-direct 7/24 调研)
- 装机 user 后续提需求 → PM-direct 调研 + 派单

### 4.3 hermes 监控 (装机 user 7/24 拍板: hermes 运行不稳, 晚上掉了没人知道) — PM-direct 后续调研

- hermes 自带 logs + cron, 但**官方文档没承诺自动监控 + 重启** (PM-direct 后续调研)
- 装机 user 后续提需求 → PM-direct 调研 + 派单

### 4.4 跨设备共享数据层 (装机 user 7/24 拍板: 改公司级共享数据层, 各部门一个文件夹权限, hermes 跨文件夹权限) — PM-direct 后续调研

- 装机 user 后续提需求 → PM-direct 调研 + 派单

### 4.5 笔法库 UI (装机 user 拍: 装机后看笔法库 + 选笔法 + 选作者) — v1.0+ 拍板

- hermes 自带 CLI / TUI / Desktop, 但**官方文档没承诺文枢笔法库 UI** (PM-direct 后续调研)
- 装机 user 后续提需求 → PM-direct 调研 + 派单

### 4.6 项目组机制 UI (装机 user 拍: 9 隐藏角色 + 协调员, 装机 user UI 看不到) — v1.0+ 拍板

- hermes 自带 delegate_task + acp_adapter (PM-direct 7/25 调研 official docs), 但**官方文档没承诺文枢项目组 UI** (PM-direct 后续调研)
- 装机 user 后续提需求 → PM-direct 调研 + 派单

### 4.7 worktree UI (装机 user 拍: 试不同走向, 装机 user 写小说时切 worktree) — v1.0+ 拍板

- hermes 自带 project + worktree + git-worktree-ops.ts (PM-direct 7/25 调研 official docs), 但**官方文档没承诺文枢 worktree UI** (PM-direct 后续调研)
- 装机 user 后续提需求 → PM-direct 调研 + 派单

## 5. 装机脚本 (scripts/install.sh)

装机脚本拷入 (按装机内容边界):
```bash
cp wenshu/SOUL.md ~/.wenshu-hermes/
cp wenshu/AGENTS.md ~/.wenshu-hermes/
cp -r wenshu/methodologies/. ~/.wenshu-hermes/methodologies/
# (wenshu-pour/, wenshu/docs/ 不拷入)
# (wenshu/methodologies/lego/ 不拷入, 等装 user 拍板重建方案)
# (wenshu/methodologies/style/authors/ 不拷入, 用户私域)
```

## 6. 未来实装 (PM-direct 装机 user 后续提需求时拍)

- wenshu-pour/authors/ — 装机后用户提交私有作者的蒸馏路径 (装机 user 7/25 拍板)
- wenshu-pour/agent-team/ — 项目组机制 9 隐藏角色 + 协调员
- wenshu-pour/user-stories/ — Story 2 v0.3 (worktree UI) / Story 2 v0.4 (项目组机制)
- wenshu-pour/research/ — 未来装机 user 拍板的调研报告 (笔法库 UI / 项目组 UI / 多 hermes 桥接 / 监控 / 跨设备共享 等)

---

## 装 user 周末拍板 5 件事

1. wenshu-pour/architecture/system-overview.md (本大概括) OK?
2. .wenshu-hermes/ 目录布局 (3 类目: hermes 自带 + 文枢装机 + 用户私域) OK?
3. 文枢需要补的功能 7 项 (4.1-4.7) OK?
4. 装机脚本拷入清单 OK?
5. 未来实装 wenshu-pour/ 子目录 OK?

---

## 装 user 后续提需求 (PM-direct 派单节奏)

按装机 user 7/24 拍板 "commit 我自决, 不用问" + "你落地吧" 协议, PM-direct 自决派单:

- 装 user 提需求 → PM-direct 5 分钟调研 hermes 官方文档 (装机 user 7/24 立 "任何事前先找官方文档") → PM-direct 5 分钟拍板真值 (装 user 视角 / wenshu 方向 / 是否依赖装 user 视觉) → 派单 (WO-XXX) → 落档 wenshu-pour/ → commit (PM-direct 自决) → 装 user 周末审改.

## 装 user 提需求 — PM-direct 不调研硬规则 (装机 user 8/25 拍)

> 装机 user 8/25 拍板: "这些是文枢需要补的功能 hermes 没有, 不用调研, 我之后会提需求"
> 装机 user 7/25 拍板: "你查一下官方文档去吧, 我记得我已经和你提过要求, 做任何事前先去找官方的文档"
> → 装 user 提需求时, PM-direct 5 分钟调研官方文档 (不调研硬规则优先), 拍板真值落档, 不下 "X 不存在" 结论 (Mem0 原则).

---

**PM-direct 自决派单 (WO-001AA v0.1)**:

- 落档 `wenshu-pour/architecture/system-overview.md` (本大概括, ~3KB)
- 落档 `wenshu-pour/README.md` v0.2 (项目文件夹结构图 + wenshu-pour/ 子目录列表)
- 装机 user 周末审改时一并看 (按 wenshu-pour 协议, 不 commit, 等装 user 拍板)