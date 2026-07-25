---
id: snowflake-ingermanson
name: 雪花法 (Randy Ingermanson 雪花 10 步法)
category: foundations
author: Randy Ingermanson (1996 公开网站传授)
version: "1.0.0"
translation_source: Randy Ingermanson 1996 年起在 Advanced Fiction Writing 网站 (www.advancedfictionwriting.com) 公开传授的雪花法 (Snowflake Method), 公开教学 (CC-BY 类, 可自由引用 + 翻译)
license: 公开教学 (Randy Ingermanson 1996 起公开传授, 允许非商业引用 + 翻译)
applicable_types:
  - novel
  - long_form_narrative
description: |
  Randy Ingermanson (物理学家 / 小说家) 1996 年提出的小说规划方法, 灵感来自雪花分形几何。
  核心思想: 从一句话故事 → 一段故事 → 角色简介 → 一页剧情 → 角色详细档案 →
  四页剧情 → 完整角色档案 → 场景清单 → 场景详情 → 第一稿。
  自顶向下 + 自底向上结合, 强调 "先骨架后血肉", 与 Larry Brooks "Story Engineering" 的
  编剧结构化思维一致。
tags:
  - 公开教学
  - 长篇小说
  - 规划方法
  - 分形
estimated_duration: "2-4 周 (10 步迭代)"
difficulty: intermediate

stages:
  - id: step1_one_sentence
    title: Step 1 · 一句话故事
    order: 1
    description: |
      用一句话写出故事核心, 包含: 主角 + 困境 + 关键冲突 + 可能的结局方向。
      目标: 让陌生人能在 30 秒内听完还想追问。
      Ingermanson 模板: "[主角] 在 [情境] 中 [遭遇冲突], 除非 [关键转折], 否则 [失败/代价]。"
    fields:
      - type: text
        id: one_sentence
        label: 一句话故事
        required: true

  - id: step2_one_paragraph
    title: Step 2 · 一段话故事
    order: 2
    description: |
      把一句话扩展成 5 句 (一整段):
      1. 一句话 (来自 Step 1)
      2. 故事设置 (setup)
      3. 第一情节点 (first plot point)
      4. 第二情节点 (second plot point)
      5. 结尾 (ending)
    depends_on: step1_one_sentence
    fields:
      - type: textarea
        id: paragraph
        label: 一段话故事 (5 句)
        required: true

  - id: step3_character_summaries
    title: Step 3 · 主要角色简介 (1 句 1 角色)
    order: 3
    description: |
      为主要角色写 1 句话简介, 包括: 名字 + 故事目标 + 故事冲突 / 矛盾 (人物内在)。
      推荐: 1 主角 + 1-3 重要配角 + 1 反派 = 4 句话。
    depends_on: step2_one_paragraph
    fields:
      - type: list
        id: characters
        label: 主要角色简介 (1 句 1 角色)
        item_template:
          text: 角色名 + 目标 + 矛盾

  - id: step4_one_page
    title: Step 4 · 一页剧情
    order: 4
    description: |
      把 Step 2 的一段话扩展到一页 (约 500 字 = 5 段):
      1. 第一幕 (25%): 设置 + 第一情节点
      2. 第二幕前半 (25%): 上升冲突 + 中点
      3. 第二幕后半 (25%): 中点后果 + 第二情节点
      4. 第三幕前半 (15%): 高潮前置
      5. 第三幕后半 (10%): 高潮 + 结局
    depends_on: step3_character_summaries
    fields:
      - type: textarea
        id: one_page
        label: 一页剧情
        required: true

  - id: step5_character_paragraphs
    title: Step 5 · 主要角色详细档案 (1 段 1 角色)
    order: 5
    description: |
      把 Step 3 角色 1 句话扩展成 1 段 (4 句):
      1. 目标 (motivation)
      2. 当前状态 (status quo)
      3. 内在冲突 (internal conflict)
      4. 一句话总结
      Ingermanson: "内在冲突 = 故事的灵魂"。
    depends_on: step4_one_page
    fields:
      - type: list
        id: character_details
        label: 主要角色详细档案 (1 段 1 角色)
        item_template:
          text: 角色名 + 目标 + 状态 + 内在冲突 + 总结

  - id: step6_four_pages
    title: Step 6 · 四页剧情
    order: 6
    description: |
      把 Step 4 一页扩展到 4 页 (约 2000 字 = 8 段):
      把三幕剧细分: Setup / Response / Attack / Resolution / 各自再分前后。
    depends_on: step5_character_paragraphs
    fields:
      - type: textarea
        id: four_pages
        label: 四页剧情 (8 段)
        required: true

  - id: step7_full_character_profiles
    title: Step 7 · 完整角色档案 (1 页 1 角色)
    order: 7
    description: |
      角色 1 段 → 1 页, 含: 外貌 / 习惯 / 童年 / 教育 / 心理创伤 / 信念 / 秘密 / 人际关系 / 角色弧。
    depends_on: step6_four_pages
    fields:
      - type: list
        id: character_profiles
        label: 完整角色档案
        item_template:
          text: 角色完整档案

  - id: step8_scene_list
    title: Step 8 · 场景清单
    order: 8
    description: |
      从 4 页剧情分解出所有场景, 每场景 1 行:
      POV + 场景目标 + 冲突 + 结局 (Setup / Response / Attack / Resolution 分类)。
    depends_on: step7_full_character_profiles
    fields:
      - type: list
        id: scenes
        label: 场景清单
        item_template:
          text: POV + 目标 + 冲突 + 结局

  - id: step9_scene_details
    title: Step 9 · 场景详情 (每个场景 1 页)
    order: 9
    description: |
      每个场景展开成 1 页, 含: 开场动作 / 推进事件 / 关键场景 / 场景高潮 / 场景结局。
    depends_on: step8_scene_list
    fields:
      - type: list
        id: scene_details
        label: 场景详情
        item_template:
          text: 场景 1 页

  - id: step10_first_draft
    title: Step 10 · 第一稿
    order: 10
    description: |
      终于开始写! Ingermanson: "不要回头改, 先写完第一稿再说"。
      写作时遵循 Step 9 场景详情, 但允许灵活调整。
    depends_on: step9_scene_details
    fields:
      - type: textarea
        id: first_draft
        label: 第一稿 (或写稿进度)

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 1 规划 (主, 长篇小说), Step 3 起草 (按 Step 10 跑场景)。
  - 不要在 Step 1 / 2 卡太久, 关键是 Step 8 场景清单出全。
  - 内在冲突检查: 主角有无 Step 5 的"内在冲突"? 无则故事 = 编年史。
  - 反模式: Step 1 1 句话太模糊 (如 "主角冒险" → 必须有冲突 + 转折)。
  - 短篇小说 (≤ 1 万字) 不必走完 10 步, 走 Step 1 / 4 / 8 即可。
  - 不替代大纲方法, 但与 Aristotle 三幕剧 / Freytag 五幕剧可叠加 (Step 2 / 4 / 6 对应三幕 / 五幕)。
---

# 雪花法 · Ingermanson 10 步

> **本方法论状态**: 文枢翻译公开教学 (允许非商业翻译 + 引用)。
> **原始出处**: Randy Ingermanson 1996 年起在 Advanced Fiction Writing 网站公开传授, 至今免费。
> **适用节点**: Step 1 规划 (主, 长篇小说), Step 3 起草 (按 Step 10 跑场景)。

---

## 1. 适用场景

- 长篇小说 (≥ 5 万字)
- 系列小说 (Step 1 可复用)
- 复杂 POV 多线叙事
- 需要严密情节设计的悬疑 / 推理 / 史诗

**不适用**:
- 短篇小说 (≤ 1 万字): 走 Step 1 / 4 / 8 即可
- 散文 / 诗歌: 不适用
- 实验性 / 意识流: 与结构化方法冲突

## 2. 雪花分形思想

雪花法名字来自 Koch 雪花分形几何:
- **整体 → 部分**: 一步比一步大, 但每步形状相似。
- **自顶向下**: Step 1 → Step 10, 颗粒度递减。
- **自底向上**: 场景 → 段落 → 页 → 章 → 书。

```
        ┌───── Step 4: 1 页 ─────┐
        │                        │
   ┌────┴────┐              ┌────┴────┐
   │ Step 6  │              │ Step 6  │
   │ 4 页    │              │ 4 页    │
   └────┬────┘              └────┬────┘
        │                        │
   Step 8 / 9               Step 8 / 9
   场景清单 + 详情           场景清单 + 详情
```

## 3. 10 步详解

(见 frontmatter stages[])

**核心步骤 (跳过其余仍可)**:
- Step 1: 一句话故事 (核心吸引力)
- Step 4: 一页剧情 (骨架)
- Step 5: 主角内在冲突 (灵魂)
- Step 8: 场景清单 (可执行分解)

## 4. 文枢使用方式

- Step 1 规划节点: 文枢按 Step 1 → Step 7 引导用户, 一边填空一边问"内在冲突是什么?"。
- Step 3 起草节点: 按 Step 10 跑场景, 每个场景用 Step 9 的 1 页详情。
- 修订节点: 反向用 Step 8 场景清单自检 — 场景冲突是否清晰? Setup / Response / Attack / Resolution 是否齐全?

## 5. Ingermanson 提示原话 (公开教学引用)

- Step 1: "Take an hour and write a one-sentence summary of your book."
- Step 5: "Take another hour and expand that sentence into a full paragraph... all the major plot points."
- Step 10: "Write the first draft. Don't look back."

## 6. 与本目录其他方法论的关系

| 方法论 | 关系 |
|--------|------|
| Aristotle 三幕剧 | 雪花 Step 2 / 4 / 6 对应三幕 (五点 / Setup + Climax + Resolution) |
| Freytag 五幕剧 | 雪花 Step 4 / 6 对应五幕 |
| Hero's Journey | 雪花 Step 5 / 7 内在冲突 = Hero Journey 的"Ordinary World 缺陷 + Refusal 犹豫" |

## 7. 版本

- v1.0.0 (2026-07-25): 文枢翻译公开教学第一版, 依据 Advanced Fiction Writing 网站 1996-2024 公开发布 (CC-BY 风格, 允许非商业引用翻译)。
