---
id: three-act-aristotle
name: 三幕剧 (Aristotle 三幕式结构)
category: foundations
author: 亚里士多德 (Aristotle, 《诗学》~335 BC)
version: "1.0.0"
translation_source: Aristotle《Poetics》~335 BC, English translations public domain (S.H. Butcher 1898 etc.)
license: 公版 (public domain, ~335 BC)
applicable_types:
  - novel
  - screenplay
  - short_story
  - stage_play
description: |
  亚里士多德在《诗学》(Peri Poietikes, ~335 BC) 第六至第九章首次系统提出戏剧的
  "开头—中段—结尾" 三段式结构, 并定义完整 (whole) 故事的六大要素:
  情节 (mythos) / 性格 (ethos) / 思想 (dianoia) / 措辞 (lexis) / 旋律 (melos) / 景观 (opsis)。
  核心原则: 完整性 (beginning / middle / end) + 必然律 / 或然律 (necessity / probability) +
  发现 (anagnorisis) 与逆转 (peripeteia)。后世所有三幕式编剧法 (Field / Trottier / McKee)
  都回溯到这一公版源头。
tags:
  - 公版
  - 戏剧
  - 经典结构
  - 西方文论
estimated_duration: "1-2 周"
difficulty: beginner

stages:
  - id: protasis
    title: Protasis 开端 (Beginning)
    order: 1
    description: |
      故事开场, 介绍情境与人物, 不必然从"时间起点"开始。
      亚里士多德强调 "美的事物必须完整, 有开头、中段、结尾"。
      比例建议 (后世 Field / Trottier 沿用): 约 25% 篇幅, 末点 = "inciting incident 触发事件"
    fields:
      - type: textarea
        id: opening
        label: 开端内容 (人物 + 情境 + 触发事件)
        required: true

  - id: epitasis
    title: Epitasis 中段 (Middle)
    order: 2
    description: |
      主体情节, 冲突升级、纠葛、发现 (anagnorisis) 与逆转 (peripeteia) 集中发生。
      亚里士多德《诗学》第十一章: "逆转与发现是情节的灵魂"。
      比例: 约 50% 篇幅; 中点 (midpoint) = 主角从被动转主动 / 从主动转被动。
    depends_on: protasis
    fields:
      - type: textarea
        id: middle
        label: 中段内容 (冲突 + 纠葛 + 逆转 / 发现)
        required: true
      - type: text
        id: midpoint
        label: 中点转折
        required: true
      - type: text
        id: anagnorisis
        label: 发现 (anagnorisis) 关键时刻

  - id: catastrophe
    title: Catastrophe 结尾 (End)
    order: 3
    description: |
      收束, 解决冲突, 不必 "大团圆"。亚里士多德区分 "复杂情节的结局" =
      必然或或然的解决 + 整体一致 (unity of action)。
      比例: 约 25% 篇幅; 末点 = 新平衡 (resolution) 或主题揭示 (theme statement)。
    depends_on: epitasis
    fields:
      - type: textarea
        id: ending
        label: 结尾内容 (高潮 + 解决 + 新平衡)
        required: true
      - type: text
        id: theme_statement
        label: 主题陈述 (dianoia 思想核心)

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 3 起草 (主), Step 4 修订 (叠加完整性检查)。
  - 完整性自检: 故事是否"有开头、有中段、有结尾" (Poetics §7 完整原则)?
  - 必然 / 或然律自检: 结局是否由前面的情节必然或或然推出, 而非突然翻转?
  - 必含: 至少一处 anagnorisis (发现) 或 peripeteia (逆转), 否则只是"编年史"。
  - 不强制套 25 / 50 / 25 比例, 但 Plot Point 1 / Midpoint / Plot Point 2 应明确。
  - 与五幕剧 (Freytag) 可叠加: 五幕剧 = 三幕剧的细化版。
---

# 三幕剧 · Aristotle 三幕式结构

> **本方法论状态**: 文枢翻译公版方法论 (装机自带, 用户可改可删)。
> **原始出处**: 亚里士多德《Περὶ ποιητικῆς (Peri Poietikes / 诗学)》约公元前 335 年, 公版。
> **适用节点**: Step 3 起草 (主), Step 4 修订 (叠加完整性检查)。

---

## 1. 适用场景

- 小说 (长篇 / 短篇)
- 电影 / 剧本
- 话剧 / 舞台剧
- 任何"有起承转合"的叙事文本

**不适用** (用别的方法):
- 群像叙事 / 多 POV → 用 Booker 七大基本情节 (本目录另存)
- 学术论文 / 技术文档 → 用 IMRaD (本目录另存)
- 新闻报道 → 用倒金字塔 (本目录另存)

## 2. 六大要素 (Poetics §6)

亚里士多德定义的"完整情节"包含六大要素, **情节 (mythos) 居首位**:

| # | 要素 | 含义 | 现代对应 |
|---|------|------|----------|
| 1 | **Mythos 情节** | 事件的安排 / 结构 | Plot |
| 2 | **Ethos 性格** | 人物的道德选择倾向 | Character |
| 3 | **Dianoia 思想** | 人物 / 作者的命题陈述 | Theme |
| 4 | **Lexis 措辞** | 对话的措辞 / 修辞 | Dialogue |
| 5 | **Melos 旋律** | 音乐 / 节奏 | Soundtrack |
| 6 | **Opsis 景观** | 视觉 / 布景 | Spectacle |

**核心**: 情节 > 性格 (Poetics §6: "情节是悲剧的灵魂, 性格居次")。

## 3. 三幕结构 (Poetics §7)

```
[Protasis]  开端  ~25%     ─┐
                          │
   触发事件 (inciting)    │ Plot Point 1
                          │
[Epitasis]  中段  ~50%    ─┤
                          │ Midpoint (中点)
                          │ Plot Point 2
[Catastrophe] 结尾  ~25%  ─┘
```

### 3.1 完整性原则 (Poetics §7)

> "美的事物 (zoon) 必须完整 (holon), 有开头 (archē)、中段 (meson)、结尾 (telos)。"

- **开端**: 不必然上承, 但自然引出后续。
- **中段**: 由开端自然引发, 又自然引向结尾。
- **结尾**: 由前面的情节必然或或然推出, 之后无他事。

### 3.2 必然律 / 或然律 (Poetics §9)

- **Necessity 必然律**: 在某些情境下, 人物不得不如此行动。
- **Probability 或然律**: 在类似情境下, 人物很可能如此行动。
- 反模式: **Deus ex machina 机械降神** (Poetics §15 亚里士多德明确反对)。

### 3.3 发现 (Anagnorisis) + 逆转 (Peripeteia)

**Poetics §11**: "逆转与发现是情节的灵魂 (psychē)。"

- **Anagnorisis 发现**: 从不知到知的转变 (如 Oedipus 发现自己杀了父亲)。
- **Peripeteia 逆转**: 行动的转向 (如 Oedipus 从王到流亡)。
- 二者常同时发生, 引发 **Catharsis 净化** (情感净化 / 怜悯 + 恐惧的释放)。

## 4. 文枢使用方式

文枢在 Step 3 起草节点会问用户"这次按什么方法":
- 用户选 "三幕剧 (Aristotle)" → 文枢按 3 段结构起草。
- 用户选 "凭直觉" → 文枢不套方法。

在 Step 4 修订节点可选叠加 "三幕完整性检查":
- 完整性: 有开头、有中段、有结尾?
- 必然 / 或然律: 结尾是否由中段必然推出?
- 必含: 至少一处 anagnorisis 或 peripeteia?
- 整体一致 (unity of action): 情节是否一条主线, 而非多线平行?

## 5. 范例提示 (亚里士多德原典举例)

**Oedipus Rex (索福克勒斯, ~429 BC)**:
- **开端**: Oedipus 追查瘟疫 → 发现神谕指向"杀父娶母者"。
- **中段**: 真相逐步浮现 (anagnorisis) → 角色逆转 (peripeteia)。
- **结尾**: Oedipus 自戳双目, 流亡。
- 亚里士多德评: 这是"最完美的悲剧" (Poetics §13)。

## 6. 与本目录其他方法论的关系

| 方法论 | 关系 |
|--------|------|
| Freytag 五幕剧 | 细化 (五幕剧 = 三幕剧的展开) |
| Hero's Journey (Campbell) | 兼容 (英雄之旅 17 阶段 ⊃ 三幕剧) |
| 七大基本情节 (Booker) | 互补 (Booker 谈"故事类型", 三幕剧谈"故事结构") |

## 7. 版本

- v1.0.0 (2026-07-25): 文枢翻译公版第一版, 依据 S.H. Butcher 1898 英译本与 Loeb 1932 希腊原文校订。
