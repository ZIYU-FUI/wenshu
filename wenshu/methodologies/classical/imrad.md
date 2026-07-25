---
id: imrad
name: IMRaD (学术论文标准结构)
category: classical
author: 20 世纪科学界通用 (无单一作者, 公版)
version: "1.0.0"
translation_source: 20 世纪科学界通用结构, 起源 1900s (The American Naturalist 等早期生物学期刊), 公版; American National Standards Institute (ANSI) 1972 标准化, 公版。
license: 公版 (public domain, 20 世纪科学界通用结构, 无版权)
applicable_types:
  - research_paper
  - thesis
  - technical_report
  - literature_review
description: |
  IMRaD = Introduction / Methods / Results / and Discussion, 20 世纪科学界通用结构。
  历史: 1900s 早期生物学期刊 (如 American Naturalist, Botanical Gazette 等) 演化而来,
  1970s 成为科学论文事实标准。
  ANSI / ISO 均有 IMRaD 标准 (1970s 公版)。
  适用: 自然科学 / 社会科学 / 工程学论文。
  注意: 人文学科论文结构不同 (argument-driven), 仍可用 IMRaD 但需调整。
tags:
  - 公版
  - 学术
  - 科研
  - 标准化
estimated_duration: "2-6 个月 (一篇完整论文)"
difficulty: intermediate

stages:
  - id: introduction
    title: I · Introduction 引言
    order: 1
    description: |
      回答 "为什么这项研究重要":
      1. 研究领域背景 (1-2 段)
      2. 文献综述 + 现有研究的局限 (文献综述常独立为 "Literature Review" 段)
      3. 研究问题 / 假设 (Research Question / Hypothesis)
      4. 本研究的贡献 / 创新 (Contribution)
      5. 论文结构概述 (可选)
      末尾常含 "In this paper, we..." 的明确陈述。
    fields:
      - type: textarea
        id: background
        label: 研究背景
        required: true
      - type: textarea
        id: literature_gap
        label: 文献缺口 / 局限
        required: true
      - type: text
        id: research_question
        label: 研究问题 / 假设
        required: true
      - type: textarea
        id: contribution
        label: 本研究贡献

  - id: methods
    title: M · Methods 方法
    order: 2
    description: |
      回答 "怎么做的研究":
      1. 研究设计 (experimental / observational / theoretical)
      2. 数据来源 (样本 / 数据库 / 仪器)
      3. 实验步骤 / 流程 (可详可略, 关键步骤必写)
      4. 数据分析方法 (统计 / 算法 / 软件)
      5. 验证方法 (复现 / 对照 / 灵敏度分析)
      原则: 详尽到他人能复现。
    depends_on: introduction
    fields:
      - type: textarea
        id: design
        label: 研究设计
        required: true
      - type: textarea
        id: data
        label: 数据来源
        required: true
      - type: textarea
        id: procedure
        label: 实验步骤
        required: true
      - type: textarea
        id: analysis
        label: 数据分析方法

  - id: results
    title: R · Results 结果
    order: 3
    description: |
      回答 "发现了什么":
      1. 主要发现 (按重要性排序)
      2. 数据呈现 (图表 + 数字)
      3. 统计显著性 / 误差
      4. 异常 / 不符合预期的结果 (单独讨论)
      注意: Results 只报告"是什么", 不解释"为什么" (留给 Discussion)。
    depends_on: methods
    fields:
      - type: textarea
        id: main_findings
        label: 主要发现
        required: true
      - type: list
        id: figures
        label: 图表
        item_template:
          text: 图表编号 + 标题 + 关键结论
      - type: textarea
        id: anomalies
        label: 异常结果

  - id: discussion
    title: D · Discussion 讨论
    order: 4
    description: |
      回答 "结果意味着什么":
      1. 主要发现的解释
      2. 与现有文献的关系 (一致 / 冲突 / 拓展)
      3. 理论意义 / 实践意义
      4. 局限 (Limitations)
      5. 未来研究方向 (Future Work)
      注意: Discussion 不要复述 Results, 要"解释 + 拓展 + 局限"。
    depends_on: results
    fields:
      - type: textarea
        id: interpretation
        label: 主要发现解释
        required: true
      - type: textarea
        id: comparison
        label: 与文献对比
        required: true
      - type: textarea
        id: limitations
        label: 局限
        required: true
      - type: textarea
        id: future_work
        label: 未来研究方向

  - id: conclusion_optional
    title: Conclusion 结论 (可选独立段)
    order: 5
    description: |
      简短总结 (1-2 段):
      - 重申研究问题
      - 重申主要发现
      - 重申意义
      不少期刊允许 Discussion 末尾 = Conclusion, 不必独立。
    depends_on: discussion
    fields:
      - type: textarea
        id: conclusion
        label: 结论

  - id: abstract_optional
    title: Abstract 摘要 (论文前置)
    order: 6
    description: |
      摘要 = 5W1H + IMRaD 的"极致浓缩":
      - Background (1 句)
      - Objective / Question (1 句)
      - Methods (1-2 句)
      - Results (2-3 句)
      - Conclusions (1-2 句)
      通常 150-300 字, 单段。
      **写作顺序**: Abstract 最后写 (最难)。
    fields:
      - type: textarea
        id: abstract
        label: 摘要 (150-300 字)
        required: true

ai_guidance: |
  文枢 agent 使用提示:
  - 适用节点: Step 2 调研 (文献综述), Step 3 起草 (主), Step 4 修订 (IMRaD 完整性检查)。
  - 完整性自检: 4 段齐全? 各段是否聚焦"对应问题"?
  - 顺序自检: I → M → R → D 的顺序不能错。
  - Results vs Discussion 自检: Results 只说"是什么", Discussion 才说"为什么"。
  - Abstract 自检: 摘要是否最后写? 150-300 字是否单段? 5 部分是否齐?
  - 人文学科提示: Argument-driven 论文可改为 I (Introduction + Thesis) → B (Body) → C (Conclusion), 但仍可用 IMRaD 套。
  - 反模式:
    - 把 Discussion 写成 Results 复述 (缺解释)。
    - 把 Limitations 写得过于谦虚 (人文学科常见, 影响可信度)。
    - 把 Future Work 写成空话 (应具体到下一步实验设计)。
---

# IMRaD · 学术论文标准结构

> **本方法论状态**: 文枢翻译公版学术结构。
> **原始出处**: 20 世纪科学界通用结构, 起源 1900s, ANSI 1972 标准化, 公版。
> **适用节点**: Step 2 调研 (文献综述), Step 3 起草 (主), Step 4 修订 (IMRaD 完整性检查)。

---

## 1. 适用场景

- 自然科学论文 (物理 / 化学 / 生物 / 医学)
- 社会科学论文 (心理学 / 经济学 / 社会学)
- 工程学论文 (CS / EE / ME)
- 学位论文 (硕士 / 博士)
- 技术报告

**不适用**:
- 人文学科纯 argument-driven 论文 (哲学 / 文学批评): 可改 IBC 结构
- 文学创作 (用 Hero's Journey)
- 新闻 (用倒金字塔)

## 2. IMRaD 起源

- **1900s**: 美国生物学期刊 (American Naturalist 等) 开始出现 "Introduction / Methods / Results / Discussion" 雏形。
- **1950s-60s**: IMRaD 成为生物医学领域标准。
- **1970s**: ANSI Z39 / ISO 215 标准化, 推广到所有学科。
- **21 世纪**: IMRaD 是 80%+ 科学期刊要求的结构。

## 3. IMRaD 4 段详解

(见 frontmatter stages[])

**核心问题对照**:
| 段 | 回答 | 时态 (英语) |
|----|------|-------------|
| Introduction | 为什么 | 一般现在时 (已知) / 一般过去时 (本研究) |
| Methods | 怎么做 | 一般过去时 |
| Results | 发现了什么 | 一般过去时 |
| Discussion | 意味着什么 | 一般现在时 + 过去时 |

## 4. 摘要 (Abstract) 的特殊地位

- Abstract 不是 IMRaD 的"第 5 段", 而是独立的 "前置浓缩"。
- Abstract 通常 150-300 字, 单段。
- **写作顺序**: Abstract 最后写 (写完 4 段后, 再浓缩)。
- Abstract 结构 = IMRaD 的微缩版 (5 句: Background / Objective / Methods / Results / Conclusions)。

## 5. 论文其他标准部分

(不在 IMRaD 核心, 但常伴随)

| 部分 | 位置 | 作用 |
|------|------|------|
| Title | 最前 | 核心信息 (研究对象 + 方法 + 结果) |
| Keywords | Abstract 后 | 索引词 (3-8 个) |
| Introduction | 正文起 | 文献综述 + 缺口 |
| Methods | I | 复现所需细节 |
| Results | M | 客观发现 |
| Discussion | R | 解释 + 对比 + 局限 |
| Conclusion | D 末 | 重申结论 |
| Acknowledgments | Conclusion 后 | 资助 / 致谢 |
| References | 末 | 文献列表 (GB/T 7714 / APA / IEEE 等格式) |
| Appendices | 末后 | 补充材料 |

## 6. 文枢使用方式

- Step 2 调研: 用户调研 = Introduction 的"文献综述 + 缺口"。
- Step 3 起草: 按 I → M → R → D 顺序写, Abstract 最后写。
- Step 4 修订:
  - 完整性检查 = 4 段齐全?
  - 时态自检 (英语论文) = Methods/Results 用过去时, Introduction/Discussion 用现在时。
  - Results vs Discussion 不混淆。
  - Abstract 是否单段 150-300 字?

## 7. 反模式

- **重复**: Discussion 复述 Results 数字 = 浪费篇幅。
- **过度谦虚**: Limitations 写得过度 (影响可信度)。
- **空 Future Work**: 不具体到下一步实验。
- **摘要当导语**: Abstract 写得像 Introduction, 不浓缩。
- **错时态** (英语论文): Methods/Results 用现在时 = 大忌。

## 8. 与本目录其他方法论的关系

| 方法论 | 关系 |
|--------|------|
| 倒金字塔 | IMRaD 是"学术版倒金字塔", 但更长更结构化 |
| 5W1H | IMRaD = 5W1H 在学术场景的"特化" |
| AIDA (Lewis 1898) | IMRaD 是"客观陈述", AIDA 是"说服结构", 不直接相关 |

## 9. 版本

- v1.0.0 (2026-07-25): 文枢翻译公版第一版, 依据 ANSI / ISO 215 标准化文档 (1972+ 公版) + 学术期刊公版指南。
