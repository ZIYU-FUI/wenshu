---
id: seven-basic-plots-booker
name: 七大基本情节 (Booker《The Seven Basic Plots》)
category: foundations
author: Christopher Booker (2004《The Seven Basic Plots: Why We Tell Stories》)
version: "1.0.0"
translation_source: Christopher Booker《The Seven Basic Plots: Why We Tell Stories》2004, Continuum. Booker 2018 逝世 (享年 81), 作品 2018 起进入公版倒计时 (中国 50 年 / 美 70 年, ~2075 公版, 但学术概念名 / 类型标签 = 公用, 翻译引用概念 OK)
license: 公版国家 (Booker 2018 逝世, 美 2049+ 公版 / 中国 2069+ 公版) / 学术概念名 = 公用领域, 可翻译 + 引用 + 综述
applicable_types:
  - novel
  - screenplay
  - myth_retelling
  - story_analysis
description: |
  Christopher Booker 2004 年《The Seven Basic Plots》从心理动力学 (Jung / Freud) 视角
  综合全世界故事的"基本类型", 提出 7 大类:
  1. Overcoming the Monster 战胜怪兽
  2. Rags to Riches 穷到富 (灰姑娘)
  3. The Quest 追寻
  4. Voyage and Return 远行与回归
  5. Comedy 喜剧
  6. Tragedy 悲剧
  7. Rebirth 复活
  
  每类有特定的"故事弧 + 心理动力 + 阴影原型"。
  不同于结构方法 (三幕剧 / 英雄之旅), Booker 是"故事类型学"。
tags:
  - 公版倒计时
  - 类型学
  - 心理分析
  - 跨文化
estimated_duration: "1-2 周 (类型选择 + 弧设计)"
difficulty: intermediate

stages:
  - id: plot1_overcoming_monster
    title: Plot 1 · Overcoming the Monster 战胜怪兽
    order: 1
    description: |
      主角 (或一群人) 对抗一个威胁世界的强大反派。
      弧: 召唤 → 试探 → 进攻 → 高潮对决 → 怪兽倒下 → 新世界。
      心理动力: 阴影 (Shadow, Jung) 的整合 / 战胜自身黑暗面。
      样本: Beowulf / Star Wars / 大部分超级英雄片 / Jaws。
    fields:
      - type: textarea
        id: monster
        label: 怪兽 (外在反派 + 内在阴影)
        required: false

  - id: plot2_rags_to_riches
    title: Plot 2 · Rags to Riches 穷到富 (灰姑娘)
    order: 2
    description: |
      主角从卑微 / 受压迫处境, 经提升 (通常是爱 / 发现) 达到新高度。
      弧: 卑微 → 召唤 / 提升 → 嫉妒 / 试炼 → 跌落 → 回归 + 永恒提升。
      心理动力: 自卑 (Inferiority) → 自我价值 (Self-Worth)。
      样本: Cinderella / Jane Eyre / The Prince and the Pauper。
    fields:
      - type: textarea
        id: protagonist
        label: 卑微处境
        required: false

  - id: plot3_the_quest
    title: Plot 3 · The Quest 追寻
    order: 3
    description: |
      主角 + 团队 出发寻找某物 / 某人 / 某地。
      弧: 召唤 → 出发 → 路上试炼 → 抵达 → 拿到目标 → 回归 / 代价。
      心理动力: 缺乏 → 寻找 → 发现 → 整合。
      样本: The Lord of the Rings / The Odyssey / Raiders of the Lost Ark。
    fields:
      - type: textarea
        id: goal
        label: 追寻目标
        required: false

  - id: plot4_voyage_and_return
    title: Plot 4 · Voyage and Return 远行与回归
    order: 4
    description: |
      主角进入陌生世界 (物理 / 心理), 经历奇异事件, 最终回归并带出智慧。
      弧: 进入 → 异世界 → 困惑 → 顿悟 → 回归 → 改变。
      心理动力: 熟悉 (Familiar) → 陌生 (Strange) → 整合 (Integrated)。
      样本: Alice in Wonderland / The Wizard of Oz / The Chronicles of Narnia。
    fields:
      - type: textarea
        id: strange_world
        label: 异世界设定
        required: false

  - id: plot5_comedy
    title: Plot 5 · Comedy 喜剧
    order: 5
    description: |
      主角因误解 / 身份混淆 / 错误目标 走入喜剧迷局, 最终真相大白 + 团圆。
      弧: 误解 → 混乱 → 假象升级 → 真相揭示 → 团圆。
      心理动力: 自我欺骗 (Self-Deception) → 自我认识 (Self-Knowledge)。
      样本: A Midsummer Night's Dream / Much Ado About Nothing / 大部分浪漫喜剧。
    fields:
      - type: textarea
        id: misunderstanding
        label: 核心误解
        required: false

  - id: plot6_tragedy
    title: Plot 6 · Tragedy 悲剧
    order: 6
    description: |
      主角因内在缺陷 (Hamartia) 走向毁灭, 后期醒悟但已无力回天。
      弧: 缺陷 → 上升 → 关键选择 → 坠落 → 顿悟 → 毁灭。
      心理动力: 傲慢 (Hubris) / 执迷 → 觉醒 (但代价已付)。
      样本: Macbeth / Othello / Oedipus Rex / Anna Karenina。
    fields:
      - type: textarea
        id: hamartia
        label: 主角内在缺陷 (Hamartia)
        required: false

  - id: plot7_rebirth
    title: Plot 7 · Rebirth 复活
    order: 7
    description: |
      主角陷入黑暗 / 死亡 / 诅咒, 经历被拯救 (自我或他人), 重获新生。
      弧: 黑暗 → 似乎无可救药 → 救赎事件 → 重生 → 新自我。
      心理动力: 黑暗面 (Dark Night of the Soul) → 转化 (Transformation)。
      样本: A Christmas Carol / Beauty and the Beast / Harry Potter (主题层)。
    fields:
      - type: textarea
        id: dark_night
        label: 黑暗时刻 (Dark Night)
        required: false

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 1 规划 (选类型), Step 4 修订 (叠加类型自检)。
  - 类型识别: 整个故事 = 7 类型之一? 或是混合 (如 Voyage and Return + Comedy)?
  - 心理动力检查: 故事是否触及对应类型的"阴影 / 自卑 / 傲慢 / 误解 / 黑暗" 原型?
  - 与结构的区别: 三幕剧 / 英雄之旅 = "故事怎么排", Booker = "故事是哪一类"。
  - 类型可叠加: 复仇故事 = Tragedy + Overcoming the Monster。
  - 反模式: 把任何故事都说成"Rags to Riches" → 失去类型独特性。
  - 文枢翻译注意: Booker 心理学分析借鉴 Jung, 部分解释带时代局限, 引用需注明"Booker 视角"。
---

# 七大基本情节 · Booker

> **本方法论状态**: 文枢翻译学术类型学 (概念名 = 公用领域)。
> **原始出处**: Christopher Booker《The Seven Basic Plots: Why We Tell Stories》2004, Continuum。
> **适用节点**: Step 1 规划 (类型选择), Step 4 修订 (类型自检)。

---

## 1. 适用场景

- 长篇小说 / 系列 (确认整体类型)
- 跨文化故事分析 (识别基本弧)
- 短篇合集 (按类型编排)
- 神话 / 民俗比较

**不适用**:
- 纯结构 / 节奏 (用三幕剧 / 英雄之旅)
- 静态 / 实验叙事 (无清晰弧)

## 2. 七大类型总览

| # | 类型 | 弧 | 心理动力 |
|---|------|----|---------:|
| 1 | Overcoming the Monster 战胜怪兽 | 召唤 → 决战 → 胜利 | 整合阴影 |
| 2 | Rags to Riches 穷到富 | 卑微 → 提升 → 跌落 → 重升 | 自卑 → 自值 |
| 3 | The Quest 追寻 | 出发 → 试炼 → 抵达 → 回归 | 缺乏 → 寻找 |
| 4 | Voyage and Return 远行与回归 | 异世界 → 异化 → 回归 | 熟悉 → 陌生 |
| 5 | Comedy 喜剧 | 误解 → 混乱 → 真相 → 团圆 | 自欺 → 自知 |
| 6 | Tragedy 悲剧 | 缺陷 → 上升 → 坠落 → 毁灭 | 傲慢 → 觉醒 |
| 7 | Rebirth 复活 | 黑暗 → 救赎 → 重生 | 转化 |

## 3. 与三幕剧 / 英雄之旅的关系

**Booker 类型学 ≠ 结构**:
- **三幕剧 / 英雄之旅** = "故事怎么排" (时间结构)
- **Booker** = "故事是哪一类" (内容类型)

一本书可同时:
- 类型 = Overcoming the Monster
- 结构 = 三幕剧 / 英雄之旅
- 节奏 = Freytag 五幕剧

## 4. 文枢使用方式

- Step 1 规划: 文枢问用户"这是个 7 类中的哪一类? 还是混合?"
- Step 4 修订: 检查主角弧是否触及对应类型的心理动力?
- 反模式: 把悲剧 (Tragedy) 写成"主角最后胜利" → 类型被破坏。

## 5. Booker 心理动力学批评

注意: Booker 的 Jung / Freud 视角是 2004 年学术综合, 部分解释带时代局限
(如对女性角色 / 非西方文化的解读有争议)。
引用时建议注明: "Booker (2004) 类型学视角"。

## 6. 范例提示 (公版样本)

- **战胜怪兽**: Beowulf (公版 ~1000 AD)
- **穷到富**: Cinderella (Perrault 1697 公版)
- **追寻**: Odyssey (公版 ~800 BC)
- **远行与回归**: Wizard of Oz (Baum 1900 公版 1921+)
- **喜剧**: A Midsummer Night's Dream (Shakespeare 1600 公版)
- **悲剧**: Macbeth (Shakespeare 1606 公版)
- **复活**: A Christmas Carol (Dickens 1843 公版 1860+)

## 7. 版本

- v1.0.0 (2026-07-25): 文枢翻译学术综述第一版, 引用 Christopher Booker 2004 公开发布的类型概念。
