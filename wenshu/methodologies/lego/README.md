# lego/ · 文枢方法论节点碎片库 (乐高积木库)

> **本目录状态**:文枢方法论库的"积木层"。装机时由 `scripts/install.sh` postinstall 拷到 `~/.wenshu-hermes/methodologies/lego/`。
> **哲学**(来自 `../../../SOUL.md §3`):**法无定法,贵在得法。** 节点框架通用,真正方法论由用户自由组合。
> **用法**:每个 `.md` 文件 = 一个独立的写作技巧 / 节拍 / 节点碎片,用户可任意组合到任何方法论的任意节点。

---

## 1. 是什么 / 不是什么

| | 节点碎片 (lego/) | 完整方法论 (foundations/ classical/ commercial/) |
|---|---|---|
| **颗粒度** | 单节点 / 单技巧 / 单节拍 | 完整流程 (12 stages 之类) |
| **文件大小** | ≤ 200-400 字 | 通常 2-10 KB |
| **复用** | 跨方法论自由拼装 | 一次性套用 |
| **例子** | `cliffhanger.md`, `mbti-character.md`, `call-to-action.md` | `hero-journey-campbell.md`, `aida-lewis.md` |

**乐高比喻**:`lego/` 是积木块(每个 = 一种写作原子操作),`foundations/` / `classical/` / `commercial/` 是说明书(告诉用户怎么搭一座城堡)。用户可以拿任何积木块去任何说明书里,也可以自己拼一份新说明书 — 这就是法无定法。

## 2. 目录结构

```
lego/
├── README.md                          ← 本文件
├── INDEX.md                           ← 全部节点碎片目录索引 (按 category 分组)
├── structure/                         ← 结构性节点 (17 文件)
│   ├── in-medias-res.md
│   ├── parallel-plot.md
│   └── ...
├── character/                         ← 人物节点 (8 文件)
│   ├── mbti-character.md
│   ├── enneagram.md
│   └── ...
├── plot/                              ← 情节节点 (7 文件)
│   ├── cliffhanger.md  ← 注意:cliffhanger 实际归 pacing
│   └── ...
├── pacing/                            ← 节奏节点 (5 文件)
│   ├── cliffhanger.md
│   ├── fast-paced.md
│   └── ...
├── theme/                             ← 主题节点 (5 文件)
│   ├── symbolism.md
│   └── ...
├── commercial/                        ← 商业写作节点 (7 文件,新增)
│   ├── elevator-pitch.md
│   ├── call-to-action.md
│   └── ...
├── academic/                          ← 学术写作节点 (6 文件,新增)
│   ├── thesis-statement.md
│   └── ...
├── content-marketing/                 ← 内容营销节点 (4 文件,新增)
│   ├── story-arc.md
│   └── ...
└── meta/                              ← 元节点 / 工具 (6 文件,新增)
    ├── brainstorming.md
    ├── outlining.md
    └── ...
```

## 3. 单节点文件格式 (~ 200-400 字)

每个节点 = 一个独立 `.md`,**必须有 YAML frontmatter** + markdown 正文:

```markdown
---
id: cliffhanger
name: Cliffhanger 悬念结尾
category: pacing
applicable: 小说 / 剧本 / 剧集 / 短视频
tags: [suspense, end-of-chapter, engagement]
description: |
  在章节结尾或场景末留下未解决问题 / 威胁 / 揭示,
  强制读者翻下一章。
---

## 怎么用
在 7 步 workflow 的 Step 5 (创作输出) 末尾应用,
或在任何你觉得读者要走的节点。

## 适用方法论 (举例, 不限于此)
- 救猫咪 节拍 14 (All Is Lost)
- 五幕剧 第 4 幕 (Falling Action 起点)
- 任何希望读者继续的场景

## 来源
- 公版通用技巧 (无授权限制)
```

**frontmatter 字段说明**:

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 文件主键,kebab-case,跨方法论唯一 |
| `name` | string | ✅ | 中文 + 英文双名显示 |
| `category` | string | ✅ | 必须 = 所在子目录名 (structure / character / ...) |
| `applicable` | string | ✅ | 适用的体裁 / 文体,用 `/` 分隔 |
| `tags` | list | 可选 | 检索标签 |
| `description` | string | ✅ | 一段话说明,2-4 行 |

## 4. 用户怎么用节点碎片

### 4.1 单节点直接用 (最简单)

文枢 Step 3 起草时,用户说"这一章结尾给我 cliffhanger",文枢查 `lego/pacing/cliffhanger.md`,按里面"怎么用"的提示起草。

### 4.2 多节点拼装 (中等)

用户写一份"我的方法论":
```markdown
# 我的方法论 (示例)
1. 起点: in-medias-res (lego/structure/)
2. 中段: cliffhanger 结尾 5 次 (lego/pacing/)
3. 人物: mbti-character + character-arc-positive (lego/character/)
4. 主题: leitmotif 主题歌 (lego/theme/)
5. 收尾: twist-ending (lego/plot/)
```

文枢按这 5 个节点顺序起草。这是法无定法的核心 — 任意组合。

### 4.3 套用既有方法论 + 加节点 (高级)

用户选 `foundations/hero-journey-campbell.md` 的 17 阶段,但在 `I.5 Crossing Threshold` 阶段想"加点 cliffhanger",文枢自动从 `lego/pacing/cliffhanger.md` 拉该节点的提示。

## 5. 用户可注入节点路径

用户可在以下路径加自己的节点 (跟完整方法论同规则):

| 路径 | 何时生效 |
|------|----------|
| `~/.wenshu-hermes/methodologies/lego/<name>.md` | 文枢下次启动自动扫,加入节点碎片库 |
| 当前项目 `settings/lego/<name>.md` | 文枢在该项目启动时读,作为当前项目可用节点 |

## 6. 节点怎么新增

### 6.1 用户自己加

仿照 §3 的格式,丢到 `~/.wenshu-hermes/methodologies/lego/<category>/`,重启文枢即可。文枢会扫描并加载。

### 6.2 PR 进文枢仓

如果觉得节点通用有价值,PR 到本目录。CC 跑校验:
1. frontmatter 必有 id / name / category / applicable / description
2. category 必须跟所在子目录名一致
3. 文件大小 ≤ 400 字 (强制简洁)
4. id 跨目录唯一 (不能跟现有节点撞)

## 7. 节点 vs 完整方法论的边界

**写节点碎片**的情况:
- 一种独立的写作技巧 / 节拍 / 操作
- 可在多个方法论 / 体裁里复用
- 单文件能说清楚 (≤ 400 字)
- 例: cliffhanger / mbti-character / call-to-action / thesis-statement

**写完整方法论**的情况(改去 `foundations/` `classical/` `commercial/`):
- 一个完整的多阶段流程 (≥ 4 stages)
- 自带 stages / fields / depends_on 结构
- 文件 ≥ 1KB
- 例: hero-journey-campbell (17 stages) / aida-lewis (4 stages)

如果不确定,先写节点碎片 — 颗粒度小、好调整。

## 8. 节点分类哲学 (8 个 category)

| category | 包含什么 | 例子 |
|----------|----------|------|
| **structure** | 文本的整体构造方式 (POV / 时间 / 嵌套) | 多线并行, 倒叙, 多视角 |
| **character** | 人物塑造技巧 | MBTI, 九型, 上升弧, 反派深度 |
| **plot** | 情节操作 (一个具体情节机制) | 麦高芬, 误导, 反转结局 |
| **pacing** | 节奏控制 (读者的阅读速度) | 悬念结尾, 慢热, 时间跳跃 |
| **theme** | 主题表达 (用象征 / 意象承载主题) | 象征, 主旋律, 寓言 |
| **commercial** | 商业写作专用 (7/24 后扩) | 电梯演讲, 价值主张, 行动召唤 |
| **academic** | 学术写作专用 (7/24 后扩) | 论点陈述, 文献综述, 引文 |
| **content-marketing** | 内容营销专用 (7/24 后扩) | 故事弧, CTA, SEO 关键词 |
| **meta** | 元节点 / 工具 (适用于任何文体) | 头脑风暴, 列大纲, 朗读校对 |

## 9. 当前节点数

| category | 文件数 | 来源 |
|----------|--------|------|
| structure | 17 | 7/17 私域 atoms 翻译 |
| character | 8 | 7/17 私域 atoms 翻译 |
| plot | 7 | 7/17 私域 atoms 翻译 |
| pacing | 5 | 7/17 私域 atoms 翻译 |
| theme | 5 | 7/17 私域 atoms 翻译 |
| commercial | 7 | 7/24 新增通用 |
| academic | 6 | 7/24 新增通用 |
| content-marketing | 4 | 7/24 新增通用 |
| meta | 6 | 7/24 新增通用 |
| **节点总数** | **65** | — |
| **含 README + INDEX** | **67** | — |

## 10. 版本

- v0.1 (2026-07-25):WO-001M 工单 — 节点碎片库落地 (42 私域翻译 + 23 新增通用 = 65 节点 + README + INDEX)。由装机 user 7/24 拍板,法无定法乐高积木库架构确立。
