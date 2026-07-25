# methodologies/ · 文枢方法论库

> **本目录状态**:文枢开机扫描的方法论库。装机时由 `scripts/install.sh` postinstall 拷到 `~/.wenshu-hermes/methodologies/`。
> **哲学**(来自 `../SOUL.md §3`):**法无定法,贵在得法。** 节点框架通用,真正方法论由用户自由组合。
> **用法**:用户把方法论 `.md` 文件放在本目录下,文枢启动时自动扫描 + 列成"可选方法清单"。写当前项目时,用户可选 / 切 / 替 / 加。

---

## 1. 架构

```
~/.wenshu-hermes/methodologies/
├── README.md                          ← 本文件
├── examples/                          ← 示例方法论(装机自带的,用户可删可改)
│   ├── scqa-storytelling.md           ← SCQA 故事法(商业文案 / 说服类)
│   ├── star-case-study.md             ← STAR 案例法(待加)
│   ├── pyramid-principle.md           ← 金字塔原理(待加)
│   └── ...
└── <user-method>.md                   ← 用户自己加的 (例: 公司内部话术模板 / 个人创作套路)
```

## 2. 单文件格式

每个方法论文件 = 一个 `.md`,头部 YAML frontmatter(可选) + markdown 正文:

```markdown
---
name: SCQA 故事法
applies_to: [step-3-draft, step-4-revise]
tags: [business, persuasion, narrative]
credit: Barbara Minto (金字塔原理 origin) / 文枢示例改造
---

# SCQA · 故事法

## 适用场景
商业文案 / 演讲 / 说服类短文 / 产品 PRD。

## 步骤
1. **S**ituation — 陈述背景(共识起点)
2. **C**omplication — 抛出冲突(打破共识)
3. **Q**uestion — 引出核心问题
4. **A**nswer — 给出答案(就是你的论点)

## 文枢使用
- 起草节点 Step 3 默认不套方法;用户选 SCQA 后,文枢按 4 段结构跑
- 修订节点 Step 4 可叠加"SCQA 完整性检查"
```

`applies_to` 字段建议(可选,文枢会扫):
- `step-2-research`
- `step-3-draft`
- `step-4-revise`
- `step-5-finalize`
- 留空 = 任意节点通用

## 3. 用户可注入方法论路径

用户可在以下路径加方法论:

| 路径 | 何时生效 |
|------|----------|
| `~/.wenshu-hermes/methodologies/<name>.md` | 文枢下次启动自动扫,列成可选 |
| 当前项目 `settings/methodology.md` | 文枢在该项目启动时读,作为当前项目方法选择 |

## 4. "啥方法也别套" 的写法

不需要文件 — 用户一句话:"凭直觉,别套方法",文枢每步用自己的默认(详见 `../AGENTS.md §3` 步骤标注)。

## 5. 示例方法论

见 `examples/`:

- [scqa-storytelling.md](examples/scqa-storytelling.md) — 商业文案 / 说服类(文枢示例)

用户装文枢后可自行加:STAR / 金字塔原理 / 七步成诗 / Hero's Journey / 三幕剧 / 自己拍的套路。

## 6. 翻译公版授权

**策略**(2026-07-25 装机 user 拍):**公版优先, 商业书避免**。

文枢翻译方法论的硬约束:
- ✅ **公版 / 公开教学**:可直接翻译, 引用概念名 + 必要引文, 不复述大段原文。
- ⚠️ **商业书**(Save the Cat / StoryBrand / Minto 金字塔原理 / 4P / 等):**需装机 user 单独派单授权** — CC 严禁自行翻译。
- ❌ **仍在版权期** 的学术书:**概念名引用 OK, 不复述大段内容** — CC 翻译前先确认作者逝世年限 (中国 50 年 / 美 70 年)。

### 6.1 已翻译列表 (公版 + 公开教学, 9 套)

| 目录 | 方法论 | 原作者 | 公版 / 公开 | 状态 |
|------|--------|--------|------------|------|
| foundations/ | [three-act-aristotle.md](foundations/three-act-aristotle.md) | Aristotle《Poetics》~335 BC | 公版 ~2300 年 | ✅ v1.0.0 |
| foundations/ | [freytag-pyramid.md](foundations/freytag-pyramid.md) | Gustav Freytag《Die Technik des Dramas》1863 | 公版 ~163 年 | ✅ v1.0.0 |
| foundations/ | [hero-journey-campbell.md](foundations/hero-journey-campbell.md) | Joseph Campbell《The Hero with a Thousand Faces》1949 | 公版国家公版 / 中国 2027+ | ✅ v1.0.0 |
| foundations/ | [snowflake-ingermanson.md](foundations/snowflake-ingermanson.md) | Randy Ingermanson 1996 公开网站 | 公开教学 (CC-BY 风格) | ✅ v1.0.0 |
| foundations/ | [seven-basic-plots-booker.md](foundations/seven-basic-plots-booker.md) | Christopher Booker《The Seven Basic Plots》2004 | 公版国家 2049+ / 中国 2069+ / 概念名公用 | ✅ v1.0.0 |
| classical/ | [five-ws-one-h.md](classical/five-ws-one-h.md) | 西方新闻学传统 (Kipling 1898 诗) | 公版 19 世纪末 | ✅ v1.0.0 |
| classical/ | [inverted-pyramid.md](classical/inverted-pyramid.md) | 西方新闻学 19 世纪电报时代 | 公版 19 世纪中期 | ✅ v1.0.0 |
| classical/ | [imrad.md](classical/imrad.md) | 20 世纪科学界通用结构 | 公版 (ANSI 1972 标准化) | ✅ v1.0.0 |
| commercial/ | [aida-lewis.md](commercial/aida-lewis.md) | E. St. Elmo Lewis 1898 | 公版 ~96 年 (Lewis 1928 逝世) | ✅ v1.0.0 |

### 6.2 待翻译列表 (商业书, **需装机 user 拍授权**)

> **强边界**: 装机 user 未授权前, CC 严禁翻译这些商业书 — 一动 = 立即撤回 + 升级装机 user。

| 方法论 | 作者 | 商业书 | 授权状态 |
|--------|------|--------|---------|
| Save the Cat | Blake Snyder 2005 | 《Save the Cat!》 | ⏳ 装机 user 待拍 |
| StoryBrand | Donald Miller 2017 | 《Building a StoryBrand》 | ⏳ 装机 user 待拍 |
| Pyramid Principle | Barbara Minto 1987+ | 《The Pyramid Principle》 | ⏳ 装机 user 待拍 |
| 4P 营销 | E. Jerome McCarthy 1960 | 《Basic Marketing: A Managerial Approach》 | ⏳ 装机 user 待拍 |
| Hero's Journey 12 阶段 (Vogler 简化版) | Christopher Vogler 1992+ | 《The Writer's Journey》 | ⏳ 装机 user 待拍 (注意: Campbell 17 阶段公版版已在 foundations/) |

**派单流程**: 装机 user 拍授权 → PM 派工单 → CC 翻译 → 自验 → 装机 user 验收。

## 7. 版本

- v0.2 (2026-07-25):加翻译公版授权段 + 已翻译 9 套列表 + 待翻译商业书列表
- v0.1 (2026-07-24):方法论库架构 + 单文件格式 + 用户可注入路径 + SCQA 示例
