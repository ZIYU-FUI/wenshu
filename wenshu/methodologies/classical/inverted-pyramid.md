---
id: inverted-pyramid
name: 倒金字塔 (Inverted Pyramid 新闻结构)
category: classical
author: 西方新闻学传统 (19 世纪电报时代, 公版)
version: "1.0.0"
translation_source: 西方新闻学传统, 起源 19 世纪中期电报时代, 公版; 早期文献见 Lincoln-Pritchett 1900 战时通信手册 + AP Style 早期版本。
license: 公版 (public domain, 19 世纪中期已成新闻学共识)
applicable_types:
  - news
  - press_release
  - short_report
  - executive_summary
description: |
  倒金字塔 (Inverted Pyramid) 是西方新闻学 19 世纪电报时代的核心结构。
  起源: 19 世纪中期电报易中断, 记者把最重要的事写在前 (导语), 后续追加背景。
  现代应用: 所有硬新闻 (硬消息) + 新闻稿 + 高管摘要 (Executive Summary)。
  核心原则: 最重要的事实 → 次重要 → 背景 → 细节。
  读者读到任何一处都可停止阅读, 不影响对核心事实的掌握。
tags:
  - 公版
  - 新闻学
  - 报告
  - 高管摘要
estimated_duration: "1-3 小时 (单篇)"
difficulty: beginner

stages:
  - id: lead
    title: Lead 导语 (最重要的事实)
    order: 1
    description: |
      文章开头, 用 1-3 句话浓缩 5W1H 的核心 (What / Who / When / Where, Why 可放导语或次段)。
      例: "央行今日宣布降息 0.25 个百分点, 创 2020 年以来最大降幅。"
      倒金字塔的灵魂: 读者读完导语 = 掌握 80% 关键信息。
    fields:
      - type: textarea
        id: lead
        label: 导语 (Lead) 1-3 句核心事实
        required: true

  - id: nut_graf
    title: Nut Graf 核心解释段 (为什么重要)
    order: 2
    description: |
      第二段, 解释"为什么读者要关心" — 称为 Nut Graf (坚果段, 美新闻学术语)。
      倒金字塔独有: 把"重要性"显式说出来, 让读者知道"这事跟我的关系"。
      例: "这是央行今年第三次降息, 旨在应对经济下行压力, 房贷利率将随之下降。"
    depends_on: lead
    fields:
      - type: textarea
        id: nut_graf
        label: 核心解释段 (为什么重要)
        required: true

  - id: main_facts
    title: Main Facts 主要事实 (5W1H 展开)
    order: 3
    description: |
      第三段起, 按重要性递减展开 5W1H:
      What (详细) → Who (更多细节) → When (背景时间) → Where (范围) → Why / How (深层)。
      每段 1 个核心事实, 段落长度递减。
    depends_on: nut_graf
    fields:
      - type: textarea
        id: main_facts
        label: 主要事实 5W1H 展开
        required: true

  - id: background
    title: Background 背景 (历史 / 上下文)
    order: 4
    description: |
      历史背景: 这事以前怎么发生的? 与过去的关联?
      例: "央行去年共降息 2 次, 累计降幅 0.75 个百分点, 创 2018 年以来最快节奏。"
      倒金字塔特有: 背景放在主体之后, 让"重要性"先行。
    depends_on: main_facts
    fields:
      - type: textarea
        id: background
        label: 背景 / 历史
        required: true

  - id: details
    title: Details 细节 (次要事实 / 数据)
    order: 5
    description: |
      最后段, 放数据 / 引语 / 细节, 读者跳过也不影响主线。
      例: "具体降息 0.25 个百分点, 自 8 月 1 日起执行; 央行行长在记者会上表示..."
    depends_on: background
    fields:
      - type: textarea
        id: details
        label: 细节 (数据 / 引语)

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 3 起草 (硬新闻 / 新闻稿 / 高管摘要), Step 4 修订 (倒金字塔完整性检查)。
  - 完整自检: 5 段齐全? 每段 1 个核心事实?
  - 导语自检: 导语能否独立成新闻? 即使后文全删, 读者能掌握 80% 信息?
  - Nut Graf 自检: "为什么重要" 是否显式说出? 不要让读者自己猜。
  - 反模式:
    - 把背景放导语 (倒金字塔变正金字塔, 信息被埋没)。
    - 把细节 / 引语放导语 (读者没动力读完)。
    - 段落长度相等 (倒金字塔 = 越往下越短)。
  - 与"按时间顺序叙事" 冲突 (用倒金字塔就别用时间叙事, 用 Hero's Journey)。
---

# 倒金字塔 · Inverted Pyramid

> **本方法论状态**: 文枢翻译公版新闻学结构。
> **原始出处**: 西方新闻学 19 世纪中期电报时代的传统结构, 公版。
> **适用节点**: Step 3 起草 (硬新闻 / 新闻稿 / 高管摘要), Step 4 修订 (倒金字塔完整性检查)。

---

## 1. 适用场景

- 硬新闻 (突发 / 政策 / 事件)
- 新闻稿 / 公关稿
- 高管摘要 / 决策简报
- 调查报告摘要

**不适用**:
- 调查报道长文 (倒金字塔 + 时间叙事混用)
- 文学 / 散文 (用 Hero's Journey)
- 学术论文 (用 IMRaD)

## 2. 历史起源

19 世纪中期, 电报 (telegraph) 普及, 但易中断 / 出错。
记者对策: 把最重要的事写在前, 万一电报中断, 核心事实已送达。
→ 倒金字塔成为行业标准, 沿用至今。
AP Style Book (1900s 起, 公版) 系统化倒金字塔结构。

## 3. 倒金字塔 vs 正金字塔

```
倒金字塔:                       正金字塔 (Hero's Journey):
┌────────────┐                  ┌────────────┐
│ Lead       │ ← 最重要          │  开场 / 启程 │ ← 背景
├────────────┤                  ├────────────┤
│ Nut Graf   │ ← 重要性          │  上升       │
├────────────┤                  ├────────────┤
│ Main Facts │ ← 主要事实        │  中段       │
├────────────┤                  ├────────────┤
│ Background │ ← 背景            │  下降       │
├────────────┤                  ├────────────┤
│ Details    │ ← 细节            │  结尾       │ ← 最高潮
└────────────┘                  └────────────┘
```

**关键区别**: 倒金字塔 "高潮在前", 正金字塔 "高潮在后"。

## 4. 5 段详解

(见 frontmatter stages[])

**核心特征**:
- 导语 (Lead) = 5W1H 的核心, 1-3 句浓缩。
- Nut Graf = "为什么重要" 的显式解释 (倒金字塔独有)。
- Main Facts = 5W1H 展开, 重要性递减。
- Background = 历史 / 上下文, 放在主体之后。
- Details = 数据 / 引语, 放在最后 (可删)。

## 5. 段落长度递减规则

倒金字塔的灵魂: 段落长度越往下越短。

```
段落 1 (Lead):     50-80 字
段落 2 (Nut Graf): 80-120 字
段落 3 (Main Facts): 100-150 字
段落 4 (Background): 80-100 字
段落 5 (Details):   30-50 字
```

(以上为典型比例, 非硬性规定)

## 6. 文枢使用方式

- Step 3 起草: 文枢按 5 段顺序写, 段落长度递减。
- Step 4 修订: 检查 5 段齐全? 段落长度递减? Nut Graf 是否显式说出"为什么重要"?
- 反模式:
  - 时间叙事 (开始 / 中间 / 结束) → 不适合倒金字塔
  - 把背景放导语 → 信息埋没
  - 把细节放导语 → 读者跳过

## 7. 范例 (虚构)

```
Lead: 央行今日宣布降息 0.25 个百分点, 创 2020 年以来最大降幅。
Nut Graf: 这是央行今年第三次降息, 旨在应对经济下行压力, 房贷利率将随之下降。
Main Facts: 央行行长在新闻发布会上宣布, 自 8 月 1 日起执行。
  降息后, 1 年期 LPR 降至 3.35%, 5 年期以上 LPR 降至 3.85%。
  这是央行年内第 3 次降息, 累计降幅 0.75 个百分点。
Background: 央行上次降息在 2026 年 5 月, 当时降息 0.25 个百分点。
  央行去年共降息 2 次, 累计降幅 0.75 个百分点, 创 2018 年以来最快节奏。
Details: 央行行长在记者会上表示: "我们将根据经济形势, 灵活调整货币政策。"
```

## 8. 与本目录其他方法论的关系

| 方法论 | 关系 |
|--------|------|
| 5W1H | 倒金字塔 = 5W1H 的"重要性排序", 5W1H = 内容, 倒金字塔 = 结构 |
| IMRaD | 倒金字塔更短更精简, IMRaD 是学术论文的扩展版 |
| AIDA (Lewis 1898) | 倒金字塔是"事实报道", AIDA 是"说服结构", 互补 |

## 9. 版本

- v1.0.0 (2026-07-25): 文枢翻译公版第一版, 依据 AP Style Book 1900s 公版 + 西方新闻学公版教材。
