---
id: hero-journey-campbell
name: 英雄之旅 (Campbell 17 阶段 / Hero with a Thousand Faces)
category: foundations
author: Joseph Campbell (1949《The Hero with a Thousand Faces》)
version: "1.0.0"
translation_source: Joseph Campbell《The Hero with a Thousand Faces》1949, Bollingen Series XVII, Princeton University Press
license: Joseph Campbell 1949 作品在美国 / 公版国家为公版 (Campbell 1987 逝世, 出版 ~77 年, 公版国家)。中国著作权法 50 年, 2027 年后公版。翻译引用章节标题 + 概念名 (学界通用), 不复述大段原文。
applicable_types:
  - novel
  - screenplay
  - short_story
  - myth_retelling
description: |
  Joseph Campbell 1949 年《The Hero with a Thousand Faces》(千面英雄) 第 4 章
  "The Hero's Journey" 提出的人类学 / 神话学原型结构, 综合自全世界 100+ 神话样本。
  三大阶段 17 子阶段:
  I. Departure 启程 (5): Ordinary World / Call to Adventure / Refusal / Meeting Mentor / Crossing Threshold
  II. Initiation 启蒙 (7 + 1): Tests, Allies, Enemies / Approach to Inmost Cave / Ordeal / Reward / (Road Back) ...
  III. Return 回归 (3 + 1): Road Back / Resurrection / Return with the Elixir
  
  Vogler 1992《The Writer's Journey》(商业书, 不在本卡范围) 把 Campbell 简化成 12 阶段,
  但本卡采用 Campbell 原始 17 阶段 (含 Mundane World / Supernatural World / Belly of the Whale 等).
tags:
  - 公版
  - 神话
  - 原型
  - 跨文化
estimated_duration: "2-4 周"
difficulty: intermediate

stages:
  # ─── Part I: Departure 启程 (5) ───
  - id: ordinary_world
    title: I.1 Ordinary World 平凡世界
    order: 1
    description: |
      英雄的日常生活。Campbell: "展示英雄的局限 / 缺失 / 不完整, 观众才能识别"。
      与 Supernatural World 形成对照。
    fields:
      - type: textarea
        id: ordinary
        label: 平凡世界
        required: true
      - type: text
        id: hero_flaw
        label: 英雄的缺陷 / 局限

  - id: call_to_adventure
    title: I.2 Call to Adventure 冒险召唤
    order: 2
    description: |
      召唤信号 (信使 / 危机 / 机遇) 打破平衡, 提示 "特殊世界" 的存在。
      Campbell: "通常英雄先忽视或拒绝"。
    depends_on: ordinary_world
    fields:
      - type: textarea
        id: call
        label: 召唤的具体形式
        required: true

  - id: refusal_of_call
    title: I.3 Refusal of the Call 拒绝召唤
    order: 3
    description: |
      英雄犹豫 / 拒绝, 因为恐惧 / 责任 / 怀疑。
      Campbell: "这一犹豫是必要的, 让后面的献祭有重量"。
    depends_on: call_to_adventure
    fields:
      - type: textarea
        id: refusal
        label: 拒绝的原因
      - type: text
        id: threshold_guardian
        label: 门槛守卫 (阻碍召唤的角色)

  - id: meeting_mentor
    title: I.4 Meeting with the Mentor 遇见导师
    order: 4
    description: |
      导师提供指导 / 礼物 / 护身符, 帮助英雄跨越门槛。
      Campbell: 导师往往是已经历过旅程的人 (老叟 / 仙女 / 神祇)。
    depends_on: refusal_of_call
    fields:
      - type: textarea
        id: mentor
        label: 导师形象 / 礼物 / 教诲

  - id: crossing_threshold
    title: I.5 Crossing the First Threshold 跨越第一门槛
    order: 5
    description: |
      英雄正式踏入 "特殊世界 (Supernatural World)"。Campbell: "这是承诺的点,
      此后无法回头"。常伴有"吞噬仪式 (Belly of the Whale)" — 英雄被吞入子宫 / 龙腹 / 海底,
      象征"旧身份死亡"。
    depends_on: meeting_mentor
    fields:
      - type: textarea
        id: crossing
        label: 跨越门槛场景
        required: true
      - type: textarea
        id: belly_of_whale
        label: 吞咽仪式 (Belly of the Whale)

  # ─── Part II: Initiation 启蒙 (7) ───
  - id: road_of_trials
    title: II.1 The Road of Trials 试炼之路
    order: 6
    description: |
      英雄面对一连串试炼, 收获盟友与敌人。神话原型常表现为 "三重试炼"。
      Campbell: "试炼的本质是, 英雄必须克服他最深的恐惧 / 执念"。
    depends_on: crossing_threshold
    fields:
      - type: list
        id: trials
        label: 试炼场景
        item_template:
          text: 试炼描述
      - type: textarea
        id: allies
        label: 盟友
      - type: textarea
        id: enemies
        label: 敌人

  - id: meeting_goddess
    title: II.2 Meeting with the Goddess 遇见女神
    order: 7
    description: |
      与女性原型 / 神圣母亲 / 爱 / 灵魂相遇。
      Campbell (Jung 视角): "女神代表英雄潜意识中的阿尼玛 (Anima) / 真我"。
    depends_on: road_of_trials
    fields:
      - type: textarea
        id: goddess
        label: 女神 / 爱 / 灵魂相遇
        required: false

  - id: woman_as_temptress
    title: II.3 Woman as the Temptress (Temptation) 妖妇 / 诱惑
    order: 8
    description: |
      反面诱惑, 可能让英雄放弃任务。
      Campbell: "诱惑可以是肉欲 / 权力 / 恐惧 / 自欺"。
    depends_on: meeting_goddess
    fields:
      - type: textarea
        id: temptation
        label: 诱惑的形式
        required: false

  - id: atonement_father
    title: II.4 Atonement with the Father 与父和解
    order: 9
    description: |
      与父亲原型 (权威 / 神祇 / 内在律法) 和解。
      Campbell (Freud / Jung 视角): "弑父 / 与父合一 是文明的核心戏剧"。
    depends_on: woman_as_temptress
    fields:
      - type: textarea
        id: father
        label: 与父和解 (权威 / 律法 / 神)
        required: false

  - id: apotheosis
    title: II.5 Apotheosis 神化
    order: 10
    description: |
      英雄升至神格 / 顿悟 / 神圣婚姻 (神圣合一)。Campbell: "死亡的另一面就是神化"。
    depends_on: atonement_father
    fields:
      - type: textarea
        id: apotheosis
        label: 神化 / 顿悟场景

  - id: ultimate_boon
    title: II.6 The Ultimate Boon 至高奖赏
    order: 11
    description: |
      英雄获得他要找的东西 (宝物 / 知识 / 爱 / 治愈)。
      Campbell: "没有奖赏, 回归将没有意义"。
    depends_on: apotheosis
    fields:
      - type: textarea
        id: boon
        label: 至高奖赏
        required: true

  # ─── Part III: Return 回归 (4) ───
  - id: refusal_of_return
    title: III.1 Refusal of the Return 拒绝回归
    order: 12
    description: |
      英雄可能不愿回归 (天堂 / 涅槃 / 与神合一 太诱惑)。
      Campbell: "除非任务带回奖赏, 否则世界将不得救赎"。
    depends_on: ultimate_boon
    fields:
      - type: textarea
        id: refusal_return
        label: 拒绝回归的原因
        required: false

  - id: magic_flight
    title: III.2 The Magic Flight 魔法逃亡
    order: 13
    description: |
      英雄带着奖赏逃亡, 追逐者追赶。
      Campbell: "奖赏是神圣的, 不能被凡人日常占有, 必须被夺回"。
    depends_on: refusal_of_return
    fields:
      - type: textarea
        id: flight
        label: 逃亡 + 追逐场景
        required: false

  - id: rescue_from_without
    title: III.3 Rescue from Without 外部拯救
    order: 14
    description: |
      当英雄无法自救时, 外部力量介入。
      Campbell: "智慧老人 / 自然之力 / 偶然事件 把英雄从自身极限中救出"。
    depends_on: magic_flight
    fields:
      - type: textarea
        id: rescue
        label: 外部拯救
        required: false

  - id: crossing_return_threshold
    title: III.4 Crossing the Return Threshold 跨越回归门槛
    order: 15
    description: |
      英雄带着奖赏回到平凡世界。Campbell: "回归之难, 不亚于启程"。
    depends_on: rescue_from_without
    fields:
      - type: textarea
        id: return_threshold
        label: 回归门槛
        required: true

  - id: master_of_two_worlds
    title: III.5 Master of Two Worlds 双界之主
    order: 16
    description: |
      英雄能在平凡世界与特殊世界之间自由往返。
      Campbell: "悟者既能在俗世生活, 也能进入灵界"。
    depends_on: crossing_return_threshold
    fields:
      - type: textarea
        id: master_two_worlds
        label: 双界之主 (内化)

  - id: freedom_to_live
    title: III.6 Freedom to Live 自由地生
    order: 17
    description: |
      终极目标: 不再恐惧死亡 / 不再需要启程。Campbell: "英雄获得完全的存在"。
    depends_on: master_of_two_worlds
    fields:
      - type: textarea
        id: freedom
        label: 自由 / 终极状态
        required: true

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 3 起草 (主, 长篇 / 神话 / 史诗类), Step 4 修订 (叠加完整性检查)。
  - 17 阶段不必全用, 但起程 / 启蒙 / 回归 三大幕 + 跨越门槛 + 严酷考验 + 复活 是骨架。
  - Vogler 12 阶段 (商业) 是简化版; 严格长篇用 17 阶段。
  - 跨文化提示: Campbell 的样本遍及希腊 / 北欧 / 印度 / 印第安 / 日 / 中, 不要局限于西方英雄。
  - 反模式: 把"遇见女神"理解成"加入恋爱戏", 应理解为灵魂 / 真我 / 神圣爱。
  - 现实主义小说: 可隐去神话色彩, 但 "缺陷 → 召唤 → 试炼 → 转变 → 回归" 的弧线仍可识别。
---

# 英雄之旅 · Campbell 17 阶段

> **本方法论状态**: 文枢翻译公版方法论 (Campbell 1949 在美国 / 公版国家已公版)。
> **原始出处**: Joseph Campbell《The Hero with a Thousand Faces》(千面英雄) 1949, Princeton University Press / Bollingen Series XVII。
> **适用节点**: Step 3 起草 (主), Step 4 修订 (叠加完整性检查)。

---

## 1. 适用场景

- 神话 / 史诗 / 奇幻
- 冒险 / 英雄题材
- 跨文化重述 (神话新编 / 民间故事改编)
- 长篇小说 (主角成长弧)

**不适用**:
- 反英雄 / 群像 → 用 Booker 七大基本情节
- 短小静态文本 → 17 阶段太重, 用三幕剧
- 商业文案 / 说服类 → 用 SCQA / AIDA

## 2. 17 阶段总图

```
Departure 启程 (5)
  I.1 Ordinary World 平凡世界
  I.2 Call to Adventure 冒险召唤
  I.3 Refusal of the Call 拒绝召唤
  I.4 Meeting with the Mentor 遇见导师
  I.5 Crossing the First Threshold 跨越第一门槛
      (+ Belly of the Whale 吞咽仪式)

Initiation 启蒙 (7)
  II.1  Road of Trials 试炼之路
  II.2  Meeting with the Goddess 遇见女神
  II.3  Woman as the Temptress 诱惑
  II.4  Atonement with the Father 与父和解
  II.5  Apotheosis 神化
  II.6  The Ultimate Boon 至高奖赏

Return 回归 (5)
  III.1 Refusal of the Return 拒绝回归
  III.2 The Magic Flight 魔法逃亡
  III.3 Rescue from Without 外部拯救
  III.4 Crossing the Return Threshold 跨越回归门槛
  III.5 Master of Two Worlds 双界之主
  III.6 Freedom to Live 自由地生
```

## 3. 三大阶段详解

### 3.1 Departure 启程 (I)
- **核心问题**: "英雄为什么要离开? 离开需要什么代价?"
- **心理弧**: 局限 → 召唤 → 拒绝 → 接受 → 跨越。
- **缺失**: 没有启程, 后面的一切都没有意义。

### 3.2 Initiation 启蒙 (II)
- **核心问题**: "英雄在特殊世界获得什么?"
- **心理弧**: 试炼 → 失去自我 → 重生 → 奖赏。
- **严酷考验 (Ordeal)**: 死亡的临界点 (Campbell: "英雄必须经历象征性的死亡与重生")。

### 3.3 Return 回归 (III)
- **核心问题**: "英雄带着什么回到平凡世界?"
- **心理弧**: 不愿归 → 被追 → 被救 → 跨越 → 整合。
- **常见反模式**: 英雄拿到奖赏就结束 (缺回归 = 故事未完成)。

## 4. 神话样本 (Campbell 引用, 公版故事)

- **Odyssey** (荷马, ~800 BC, 公版): Odyssey 经历 17 阶段几乎全样本 (Call / Refusal / Mentor=雅典娜 / Threshold / Trials / Goddess=Calypso / Temptress=Circe / Ordeal=冥府 / Boon=归乡 / Return)。
- **Odyssey 的 Temptation** (II.3): Calypso 与 Circe 是双重诱惑原型。
- **西游记** (吴承恩, 16 世纪, 公版): 孙悟空的 "菩提祖师 = 导师", "紧箍咒 = 与父和解", "取经 = 启蒙", "成佛 = Apotheosis"。

## 5. 文枢使用方式

- Step 3 起草: 文枢按 17 阶段顺序起草, 但允许跳过非必要阶段 (如 "Woman as Temptress" 对儿童文学可省)。
- Step 4 修订: 完整性检查 = 17 阶段齐全? 启程 / 启蒙 / 回归三大幕各自完整?
- Step 4 反模式: "英雄赢得奖赏就结束" (缺 Return 段) / "英雄无明显缺陷" (缺 Ordinary World 的局限)。

## 6. 与本目录其他方法论的关系

| 方法论 | 关系 |
|--------|------|
| Aristotle 三幕剧 | 兼容 (英雄之旅 = 三幕剧的"扩展", 17 子阶段可映射到 3 大段) |
| Freytag 五幕剧 | 兼容 (英雄之旅的 Climax 约 = Freytag Climax) |
| Booker 七大基本情节 | 互补 (Booker 谈"故事类型", 英雄之旅谈"故事弧") |

## 7. 版本

- v1.0.0 (2026-07-25): 文枢翻译公版第一版, 依据 Princeton 1949 原版及 Joseph Campbell Foundation 公开课件 (CC-BY)。7/17 草稿 hero-journey.yaml (Vogler 12 阶段简化版) 已被本 17 阶段版覆盖。
