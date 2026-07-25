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

## 6. 版本

- v0.1 (2026-07-24):方法论库架构 + 单文件格式 + 用户可注入路径 + SCQA 示例
