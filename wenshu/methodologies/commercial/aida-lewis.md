---
id: aida-lewis
name: AIDA 模型 (E. St. Elmo Lewis 1898)
category: commercial
author: E. St. Elmo Lewis (1898 公开提出)
version: "1.0.0"
translation_source: E. St. Elmo Lewis 1898 年在《The Inland Printer》和《The Western Druggist》发表"销售圈 (Salesmanship / The Catch-Line)"。Lewis 1928 逝世, 公版 ~96 年。原始论文公版, 概念名 AIDA = 公用领域。
license: 公版 (public domain, Lewis 1928 逝世, ~96 年)
applicable_types:
  - marketing_copy
  - sales_page
  - email_marketing
  - landing_page
  - ad_copy
description: |
  AIDA = Attention / Interest / Desire / Action, 美国广告 / 销售先驱 E. St. Elmo Lewis
  1898 年提出的"消费者心理 4 阶段模型"。
  核心: 把消费者从"看到" → "想看" → "想要" → "购买"逐级推进。
  起源: Lewis 在广告公司 (Campbell-Ewald 等) 工作期间, 系统研究广告销售转化路径。
  现代应用: 销售页 / 着陆页 / 邮件营销 / 广告文案 / 路演开场。
  后世扩展: AIDCA / AIDAS (加 Conviction / Satisfaction), 但本卡采用 Lewis 原始 4 段 AIDA。
tags:
  - 公版
  - 销售
  - 广告
  - 营销
estimated_duration: "1-3 天 (单篇销售页)"
difficulty: beginner

stages:
  - id: attention
    title: A · Attention 注意力 (抓住眼球)
    order: 1
    description: |
      第一步: 抓住潜在客户的注意力。
      手段: 强烈标题 / 视觉冲击 / 反常陈述 / 数字冲击 / 痛点钩子。
      反模式: 平庸标题 (例: "我们的产品很好" → 0 注意力)。
      Lewis 1898 原文: "Catch-Line = 第一句话必须抓住注意力, 否则后文无意义"。
    fields:
      - type: text
        id: hook
        label: 注意力钩子 (Hook)
        required: true

  - id: interest
    title: I · Interest 兴趣 (建立关联)
    order: 2
    description: |
      第二步: 让潜在客户对产品 / 服务产生兴趣。
      手段: 讲故事 / 共情场景 / 行业洞察 / 数据 / 反直觉事实。
      反模式: 堆功能 (客户没兴趣, 只关心"跟我有啥关系")。
      Lewis 1898: "抓住注意力后, 立刻把"产品特性"翻译为"客户利益"。
    depends_on: attention
    fields:
      - type: textarea
        id: interest_content
        label: 兴趣建立 (客户利益)
        required: true

  - id: desire
    title: D · Desire 欲望 (强化想要)
    order: 3
    description: |
      第三步: 让潜在客户从"有兴趣"变为"想要"。
      手段: 社会证明 (评价 / 用户数) / 案例 / 稀缺性 (限时 / 限量) / 风险逆转 (退款保证)。
      反模式: 重复讲功能 (兴趣阶段已讲过, 这里要"情感 + 利益强化")。
      Lewis 1898: "客户已知道功能, 这里要让他"想要" — 想象拥有后的好处"。
    depends_on: interest
    fields:
      - type: textarea
        id: desire_content
        label: 欲望强化 (社会证明 + 案例 + 稀缺)
        required: true
      - type: textarea
        id: risk_reversal
        label: 风险逆转 (退款 / 试用 / 担保)

  - id: action
    title: A · Action 行动 (召唤购买)
    order: 4
    description: |
      第四步: 让潜在客户立即采取行动 (CTA, Call to Action)。
      手段: 明确 CTA (动词) / 紧迫感 (限时优惠) / 减少决策成本 (一键下单) / 重复 CTA。
      反模式: 没有明确 CTA (客户读完后, 不知道下一步干啥)。
      Lewis 1898: "没有 CTA, 前面 AID 全白费"。
    depends_on: desire
    fields:
      - type: textarea
        id: cta
        label: CTA 行动召唤
        required: true
      - type: text
        id: urgency
        label: 紧迫感 (限时 / 限量)

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 3 起草 (销售页 / 着陆页 / 广告文案 / 邮件营销), Step 4 修订 (AIDA 完整性检查)。
  - 完整性自检: 4 阶段齐全? 每阶段是否承担"对应任务"?
  - 反模式:
    - Attention 直接讲功能 (客户没兴趣)。
    - Interest 重复 Attention (信息冗余)。
    - Desire 缺社会证明 (信任不足)。
    - Action 没有 CTA (转化率为 0)。
  - 与 SCQA 关系: SCQA = "说服的开场", AIDA = "销售的完整流程"。可叠加: SCQA 开场 → AIDA 推进。
  - 与 5W1H 关系: AIDA 是"说服结构", 5W1H 是"事实描述", 互补。
  - 中文文化提示: 中国消费者对"硬销售" 抗拒, AIDA 中 Desire 阶段要更软 (更多信任建设, 少紧迫感)。
  - 长销售页 vs 短销售页:
    - 短 (< 1000 字): AIDA 各 1 段。
    - 长 (> 3000 字): 每阶段可多段, 多次重复 CTA。
---

# AIDA · Lewis 1898

> **本方法论状态**: 文枢翻译公版营销模型。
> **原始出处**: E. St. Elmo Lewis 1898 年公开发表 (Lewis 1928 逝世, 公版 ~96 年)。
> **适用节点**: Step 3 起草 (销售页 / 着陆页 / 广告文案), Step 4 修订 (AIDA 完整性检查)。

---

## 1. 适用场景

- 销售页 / 着陆页 (Sales Page / Landing Page)
- 邮件营销 (Email Marketing)
- 广告文案 (广告标题 + 描述)
- 产品发布会开场 (Keynote Opening)
- 短视频 / 直播带货脚本

**不适用**:
- 学术论文 (用 IMRaD)
- 新闻 (用倒金字塔)
- 文学创作 (用 Hero's Journey)
- 内部沟通 (员工邮件 / 项目计划)

## 2. Lewis 1898 原文引用 (公版)

Lewis 在《The Inland Printer》和《The Western Druggist》1898 年文章中提出的"销售圈":
> "The mission of the copy is to catch the eye, hold the interest, create desire, and prompt action."

(广告文案的任务 = 抓住眼球, 保持兴趣, 创造欲望, 促使行动)
→ 后世缩写为 AIDA (1960s 后期被命名, 但 Lewis 原始 4 段已公版)。

## 3. 4 阶段详解

(见 frontmatter stages[])

**核心问题对照**:
| 阶段 | 回答 | 时态 / 风格 |
|------|------|-------------|
| Attention | 凭什么让我看? | 钩子 / 数字 / 反常 |
| Interest | 凭啥跟我相关? | 共情 / 利益翻译 |
| Desire | 为啥我现在就要? | 信任 / 证明 / 稀缺 |
| Action | 我要干啥? | 明确 CTA |

## 4. AIDA vs AIDCA / AIDAS

后世扩展:
- **AIDCA** (1950s): 加 **Conviction 信念** (强化信任)
- **AIDAS** (Strong 1925): 加 **Satisfaction 满足** (售后 / 复购)

本卡采用 Lewis 原始 4 段 AIDA, 因为:
1. 100+ 年公版历史
2. 简洁可执行
3. 用户可扩展 (留 ai_guidance 提示)

## 5. 文枢使用方式

- Step 3 起草: 文枢按 A → I → D → A 顺序写, 每段 1 个核心任务。
- Step 4 修订:
  - 完整性 = 4 段齐全?
  - 注意力钩子是否强 (数字 / 反常 / 痛点)?
  - 兴趣是否"利益化" (不是功能)?
  - 欲望是否"信任化" (社会证明)?
  - CTA 是否明确 (动词 + 紧迫)?

## 6. 中文文化适配

中国消费者对"硬销售" 抗拒:
- AIDA 中 Desire 阶段要更软: 多案例 / 多测评 / 多长尾用户证言, 少紧迫感。
- CTA 可改为"咨询客服 / 加入购物车" 而非"立即抢购"。
- 信任建设 (KOL 测评 / 媒体报道) 比"限时折扣" 更有效。

## 7. 与本目录其他方法论的关系

| 方法论 | 关系 |
|--------|------|
| SCQA | SCQA = "说服的开场", AIDA = "销售完整流程", 可叠加 |
| 5W1H | AIDA 是"说服结构", 5W1H 是"事实描述", 互补 |
| 倒金字塔 | AIDA 是"商业沟通", 倒金字塔是"新闻报道", 风格不同 |

## 8. 反模式

- **无 CTA**: 客户读完不知道干啥。
- **堆功能**: 客户没兴趣, 只关心利益。
- **重复**: Attention / Interest / Desire 三阶段内容重复。
- **强销售感**: 中国消费者抗拒"硬销售", Desire 阶段过度紧迫感会适得其反。
- **AIDA 错位**: Attention 直接讲产品名 (应该是钩子), Desire 讲功能 (应该是证明)。

## 9. 范例提示 (简化版)

```
A: "90% 的 SaaS 创业者都在重复同一个错误: 堆功能。"
I: "你的客户越来越不买账——他们要的不是更多功能, 而是更清晰的价值主张。"
D: "我们的 200+ 付费用户中, 87% 反馈首页从'功能列表'改为'用户自述三句话'后, 转化率提升 30%+。"
   "限时优惠: 今天升级, 享 50% 折扣 + 30 天退款保证。"
A: "立即试用 30 天 — [立即升级] 按钮"
```

## 10. 版本

- v1.0.0 (2026-07-25): 文枢翻译公版第一版, 依据 Lewis 1898 公开论文 (公版) + 现代营销公版教材。
