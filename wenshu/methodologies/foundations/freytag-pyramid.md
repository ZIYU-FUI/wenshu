---
id: freytag-pyramid
name: 五幕剧 (Freytag 金字塔 / 戏剧技巧)
category: foundations
author: Gustav Freytag (1863《Die Technik des Dramas》)
version: "1.0.0"
translation_source: Gustav Freytag《Die Technik des Dramas》1863, 公版 (~163 年)
license: 公版 (public domain, 1863)
applicable_types:
  - novel
  - screenplay
  - stage_play
  - short_story
description: |
  Gustav Freytag 1863 年在《Die Technik des Dramas (戏剧技巧)》中提出的
  五幕金字塔结构: 开场 (Exposition) → 上升情节 (Rising Action) →
  高潮 (Climax) → 下降情节 (Falling Action) → 结局 (Catastrophe / Dénouement)。
  又称 "Freytag's Pyramid"。原本是为希腊 / 莎士比亚戏剧设计的
  "对称化" 情节图式, 后被小说 / 电影 / 编剧广泛借用。
  与 Aristotle 三幕剧相比, 五幕剧 = 把 Aristotle 的中段 (Epitasis) 拆成
  "上升 + 高潮 + 下降" 三幕, 更适合有清晰 "转折点" 的剧本。
tags:
  - 公版
  - 戏剧
  - 编剧
  - 19 世纪
estimated_duration: "1-3 周"
difficulty: beginner

stages:
  - id: exposition
    title: Exposition 开场 (介绍部)
    order: 1
    description: |
      第一幕。介绍人物、世界、情境、背景。Freytag 强调 "激发 (erregende Moment)"
      = 引发后续冲突的触发点。比例约 15-20%。
    fields:
      - type: textarea
        id: opening
        label: 开场内容 (人物 + 世界 + 触发点)
        required: true

  - id: rising_action
    title: Rising Action 上升情节
    order: 2
    description: |
      第二幕。冲突升级, 障碍叠加, 人物之间的张力 (Spannung) 累积。
      比例最大, 约 30-40%。
    depends_on: exposition
    fields:
      - type: textarea
        id: rising
        label: 上升情节 (冲突 + 张力)
        required: true
      - type: list
        id: obstacles
        label: 障碍清单

  - id: climax
    title: Climax 高潮
    order: 3
    description: |
      第三幕 (金字塔顶点)。主角与反派 / 核心冲突的正面决战。
      Freytag: "这是全剧张力的最高点, 之后张力必然下降"。
    depends_on: rising_action
    fields:
      - type: textarea
        id: climax
        label: 高潮内容
        required: true
      - type: text
        id: turning_point
        label: 转折点 (决定性瞬间)

  - id: falling_action
    title: Falling Action 下降情节
    order: 4
    description: |
      第四幕。高潮之后, 冲突余波、后果显现、人物关系重新调整。
      比例约 15-20%。
    depends_on: climax
    fields:
      - type: textarea
        id: falling
        label: 下降情节 (余波 + 后果)

  - id: catastrophe
    title: Catastrophe / Dénouement 结局
    order: 5
    description: |
      第五幕 (金字塔右端)。最终解决 + 新平衡。Freytag 用 "Catastrophe"
      指结局 (不分好坏), 后世编剧法多用 "Resolution / Dénouement"。
      "Das letzte Moment (最后激发点)" = 主角命运的最终落定。
    depends_on: falling_action
    fields:
      - type: textarea
        id: resolution
        label: 结局内容
        required: true
      - type: text
        id: theme_statement
        label: 主题陈述

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 3 起草 (主), Step 4 修订 (叠加金字塔完整性检查)。
  - 完整性自检: 五幕是否齐全? 每幕是否有清晰的 "张力变化"?
  - Climax 自检: 是否全剧张力最高点? 不在中段, 不在结尾。
  - 与 Aristotle 三幕剧的对应: Exposition↔Protasis, Rising+Climax+Falling↔Epitasis,
    Catastrophe↔Catastrophe。三幕粗框 + 五幕细框可叠加。
  - 不适用纯群像叙事 (无单一 Climax) → 用 Booker 七大基本情节。
  - 不适用意识流 / 反结构 → 用 Hero's Journey 或 Snowflake 反推。
---

# 五幕剧 · Freytag 金字塔

> **本方法论状态**: 文枢翻译公版方法论。
> **原始出处**: Gustav Freytag《Die Technik des Dramas》1863 年 (德文), 公版。
> **适用节点**: Step 3 起草 (主), Step 4 修订 (叠加金字塔完整性检查)。

---

## 1. 适用场景

- 戏剧 (话剧 / 音乐剧)
- 电影剧本 (尤其古典好莱坞结构)
- 长篇小说 (章节切分)
- 任何有"清晰 Climax"的叙事

**不适用**:
- 群像 / 无单一主角 → 用 Booker 七大基本情节
- 意识流 / 反情节 → 用 Snowflake 或 Hero's Journey
- 新闻 / 学术 → 用倒金字塔 / IMRaD

## 2. 金字塔图式

```
              Climax (高潮)
                 /\
                /  \
               /    \
              /      \
             /        \
Exposition /          \ Catastrophe
(开场)    /            \ (结局)
        /                \
       / Rising           \
      /  Action  →→→→→→  Falling
     /                      \
    /                        \
   /                          \
  ─────────────────────────────
   T0  T1     T2     T3    T4    T5
```

**关键概念**:
- **Erregende Moment 激发点** (Freytag §2): 触发后续冲突的事件, 一般在开场末。
- **Höhepunkt Climax** (Freytag §3): 全剧张力顶点, 是 "Fallende Handlung 下降情节" 的起点。
- **Letztes Moment 最后激发点** (Freytag §4): 结局中决定命运的最后瞬间。

## 3. 五幕详解

### 3.1 第一幕 · Exposition 开场
- 介绍人物、世界、设定、前史。
- 末点 = **激发点** (inciting moment)。

### 3.2 第二幕 · Rising Action 上升情节
- 冲突、障碍、盟友 / 反派逐层展开。
- 张力曲线上升, 但不到顶点。

### 3.3 第三幕 · Climax 高潮
- 全剧张力顶点。
- 主角与反派 / 核心矛盾正面交锋。
- Freytag §3: "Climax 之后, 张力必然下降, 因为冲突已经 (部分) 解决"。

### 3.4 第四幕 · Falling Action 下降情节
- 高潮后果显现。
- 人物消化余波, 关系重新校准。

### 3.5 第五幕 · Catastrophe / Dénouement 结局
- 新平衡建立。
- Freytag 用 Catastrophe (广义, 不限悲剧) → 后世多用 Dénouement (解扣)。

## 4. 与 Aristotle 三幕剧的关系

| Freytag 五幕 | Aristotle 三幕 | 备注 |
|--------------|----------------|------|
| Exposition | Protasis 开端 | 开场 |
| Rising Action | Epitasis 中段前半 | 冲突上升 |
| Climax | Epitasis 中段顶点 | 灵魂所在 |
| Falling Action | Epitasis 中段后半 | 余波 |
| Catastrophe | Catastrophe 结尾 | 结局 |

**核心区别**: Aristotle 强调 "情节 (mythos) 优先 + 必然律 + 发现 / 逆转";
Freytag 强调 "张力曲线对称 + 高潮顶点数学化"。

## 5. 文枢使用方式

- Step 3: 文枢按五幕顺序起草, 每幕要求明确"输入字段"。
- Step 4: 完整性检查 = 五幕都有? Climax 是否全剧张力顶点?
- Step 4 反模式: 把 Climax 写到结尾 (高潮 = 结局不是结尾)。

## 6. 范例提示

- **Romeo and Juliet** (Shakespeare, 1597): Act I=Exposition, Act II=Rising, Act III=Climax (Mercutio 死 + Romeo 杀 Tybalt), Act IV=Falling, Act V=Catastrophe。
- **Die Räuber** (Schiller, 1781): Freytag 在《Die Technik des Dramas》第五章用作主要案例。

## 7. 版本

- v1.0.0 (2026-07-25): 文枢翻译公版第一版, 依据 Freytag 1863 德文原版 (公版)。
