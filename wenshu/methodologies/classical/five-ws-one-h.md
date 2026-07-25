---
id: five-ws-one-h
name: 5W1H (六何分析法)
category: classical
author: 西方新闻学 / 修辞学传统 (公版, 起源不可考)
version: "1.0.0"
translation_source: 西方新闻学传统, 起源不可考 (19 世纪末已成共识); 早期文献如 Thomas Nast 1860s 漫画 + Rudyard Kipling 1898 "六忠实的仆人"; 公版。
license: 公版 (public domain, 19 世纪末已成新闻学共识, 概念名 = 公用领域)
applicable_types:
  - news
  - report
  - research_summary
  - decision_analysis
  - event_description
description: |
  5W1H = Why / What / Who / When / Where / How, 西方新闻学传统 (19 世纪末) 的
  事件描述核心问题清单, 也叫 "六何分析法"。
  Rudyard Kipling 1898 年《Just So Stories》序言 (公版):
  "I keep six honest serving-men: What, Why, When, How, Where, Who."
  应用场景: 新闻报道 / 事故报告 / 决策分析 / 调查采访。
  核心原则: 任何一个事件的完整描述 = 6 问齐答, 缺一项 = 信息不全。
tags:
  - 公版
  - 新闻学
  - 调查报告
  - 通用
estimated_duration: "1-3 小时 (单事件描述)"
difficulty: beginner

stages:
  - id: what
    title: What 是什么 (What happened?)
    order: 1
    description: |
      事件本身: 发生了什么? 描述客观事实, 不带解释。
      例: "银行劫案发生", "新政策发布"。
      新闻学传统: 这是 6 问的"主语", 开头先讲。
    fields:
      - type: textarea
        id: what
        label: What 事件内容
        required: true

  - id: who
    title: Who 是谁 (Who?)
    order: 2
    description: |
      当事人 / 行为主体 / 受影响者: 谁做的? 谁参与的? 谁是受众?
      例: "劫匪张三", "新政策由财政部发布, 影响中小企业"。
      多个 Who 时, 分主要 / 次要 / 受影响者。
    depends_on: what
    fields:
      - type: textarea
        id: who
        label: Who 当事人
        required: true

  - id: when
    title: When 何时 (When?)
    order: 3
    description: |
      时间维度: 何时发生? 持续多久? 频率?
      例: "2026-07-25 14:30", "过去 6 个月", "每周一次"。
      区分 "事发时间" vs "报道时间" vs "持续时间"。
    depends_on: who
    fields:
      - type: text
        id: when
        label: When 时间
        required: true

  - id: where
    title: Where 何地 (Where?)
    order: 4
    description: |
      地点 / 空间维度: 在哪发生? 范围多大?
      例: "北京海淀区中关村大街 1 号", "全国范围", "线上平台 X"。
      区分 "事发地点" vs "影响范围"。
    depends_on: when
    fields:
      - type: text
        id: where
        label: Where 地点
        required: true

  - id: why
    title: Why 为什么 (Why?)
    order: 5
    description: |
      原因 / 动机: 为什么发生? 深层原因是什么?
      例: "劫匪因经济困难", "政策因经济下行压力"。
      区分 "直接原因" vs "根本原因", 多个 Why 可分层 (5 Why 分析)。
    depends_on: where
    fields:
      - type: textarea
        id: why
        label: Why 原因 / 动机
        required: true

  - id: how
    title: How 怎么 (How?)
    order: 6
    description: |
      方式 / 过程 / 方法: 怎么发生的? 用了什么手段? 流程怎样?
      例: "持枪威胁 + 撬开金库", "经过 6 个月调研 + 3 次听证"。
      与 Why 的区别: How 强调"步骤", Why 强调"原因"。
    depends_on: why
    fields:
      - type: textarea
        id: how
        label: How 方式 / 过程
        required: true

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 2 调研 (事件描述), Step 3 起草 (短报告 / 简讯), Step 4 修订 (信息完整性检查)。
  - 完整自检: 6 问齐答? 缺一项 = 信息不全, 标注 "信息不足"。
  - 顺序灵活: 新闻 = What→Who→When→Where→Why→How, 决策分析 = Why→What→How→Who→When→Where。
  - 5 Why 扩展: 对 Why 不满意时, 追问 5 层 "为什么", 直到根因。
  - 反模式: 把 Why 和 How 混为一谈 (例: 把"因为持枪"当 Why, 实为 How)。
  - 与倒金字塔 (本目录另存) 配合: 倒金字塔 = 5W1H 答案的"重要性排序"。
---

# 5W1H · 六何分析法

> **本方法论状态**: 文枢翻译公版新闻学方法论。
> **原始出处**: 西方新闻学传统, 公版。Rudyard Kipling 1898 年诗作"六忠实的仆人" (Just So Stories 序言) 是经典出处之一。
> **适用节点**: Step 2 调研 (事件描述), Step 3 起草 (短报告 / 简讯)。

---

## 1. 适用场景

- 新闻报道 / 简讯
- 事故 / 事件报告
- 决策分析 (项目立项 / 复盘)
- 调查采访大纲
- 学术摘要 / 简历 / 自我介绍

**不适用**:
- 文学创作 (用三幕剧 / 英雄之旅)
- 学术论文长文 (用 IMRaD)
- 纯叙事散文 (无明确事件)

## 2. Kipling 1898 诗 (公版原文引用)

> "I keep six honest serving-men
> (They taught me all I knew);
> Their names are What and Why and When
> And How and Where and Who."

(《Just So Stories》"The Elephant's Child" 序言, 1902; 诗作 1898 公开发表)

## 3. 六问详解

| # | 问题 | 含义 | 新闻传统顺序 |
|---|------|------|--------------|
| 1 | What | 何事 | 1 (导语) |
| 2 | Who | 何人 | 2 |
| 3 | When | 何时 | 3 |
| 4 | Where | 何地 | 4 |
| 5 | Why | 为何 | 5 (深度) |
| 6 | How | 如何 | 6 (深度) |

## 4. 顺序的灵活性

不同场景, 6 问的顺序不同:

| 场景 | 推荐顺序 |
|------|---------|
| 突发新闻 | What → Who → When → Where → Why → How |
| 决策分析 | Why → What → How → Who → When → Where |
| 事故报告 | What → When → Where → Who → How → Why |
| 调查采访 | Who → What → Why → How → When → Where |

## 5. 5 Why 扩展

对 Why 不满意时, 连续追问 5 个 "为什么" 找根因 (Toyota Production System, 公版方法论):

```
Why 1: 机器停了
Why 2: 因为保险丝烧断了
Why 3: 因为泵负荷过大
Why 4: 因为轴承润滑不足
Why 5: 因为没有定期维护
→ 根因 = 缺乏预防性维护制度
```

## 6. 文枢使用方式

- Step 2 调研: 文枢按 6 问引导用户填空, 缺一项主动追问。
- Step 3 起草: 按选定顺序输出。
- Step 4 修订: 完整性检查 = 6 问齐答? Why / How 是否深度足够?

## 7. 与本目录其他方法论的关系

| 方法论 | 关系 |
|--------|------|
| 倒金字塔 (Inverted Pyramid) | 5W1H = 内容, 倒金字塔 = 排序方式 |
| IMRaD | IMRaD 是 5W1H 在学术场景的"特化", 但更结构化 |
| AIDA (Lewis 1898) | 5W1H 是"事实描述", AIDA 是"说服结构" |

## 8. 版本

- v1.0.0 (2026-07-25): 文枢翻译公版第一版, 依据 Kipling 1898 公开诗作 + 新闻学公版教材。
