# 20 — Word count 字数统计 (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 9 件: Word count (当前 note / vault 字数, 作家必备)。

**改完:**
- `Sources/WenshuApp/Core/WordCount/WordCounter.swift` (String.enumerateSubstrings(.word) Apple HIG 统计)
- `Sources/WenshuApp/Core/WordCount/WordCountBadge.swift` (SwiftUI View, 顶栏显示当前 note 字数)

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/WordCount/WordCounter.swift Apple HIG
- [ ] Sources/WenshuApp/Core/WordCount/WordCountBadge.swift 顶栏 View
- [ ] swift build exit 0
- [ ] 单元测试: WordCounterTests (英文 / 中文 / 混合)
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView

## 业务语言描述 (老板懂)
- 写作 app 强需求: 作家必备, 每日字数 / 总字数 / 章节字数
- 中文按字符算, 英文按 word 算

## 真值引用
- Obsidian Word count: https://obsidian.md/help/plugins/word-count
- Apple HIG: String.enumerateSubstrings(.word)
