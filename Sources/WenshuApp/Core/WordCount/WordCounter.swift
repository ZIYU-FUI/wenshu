//
//  WordCounter.swift · Wenshu · v0.19 ticket 20 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  Apple HIG 字数统计. 中文按字符算, 英文按 word 算 (跟 Obsidian Word count plugin 行为对齐).
//  Apple HIG 真值: String.enumerateSubstrings(.byComposedCharacterSequences / .byWords).
//

import Foundation

/// WordCount: 字数统计结果 (跟 Obsidian Word count 1:1)
public struct WordCount: Equatable, Sendable {
    public let words: Int           // 英文 word 数
    public let characters: Int      // 字符总数 (含空格)
    public let charactersNoSpaces: Int  // 字符总数 (不含空格)
    public let chineseChars: Int    // 中文字符数 (CJK)
    public let sentences: Int       // 句数
    public let paragraphs: Int     // 段落数

    public init(words: Int, characters: Int, charactersNoSpaces: Int, chineseChars: Int, sentences: Int, paragraphs: Int) {
        self.words = words
        self.characters = characters
        self.charactersNoSpaces = charactersNoSpaces
        self.chineseChars = chineseChars
        self.sentences = sentences
        self.paragraphs = paragraphs
    }
}

/// WordCounter: 静态字数统计工具
/// 跟 Obsidian Word count plugin 行为对齐 (https://obsidian.md/help/plugins/word-count)
public enum WordCounter {

    /// 统计 markdown content 字数
    public static func count(_ content: String) -> WordCount {
        var words = 0
        var chineseChars = 0
        // 1. 英文 word 数 (用 .byWords) — 只算包含 ASCII 字母 / 数字的 word (过滤纯 CJK word)
        content.enumerateSubstrings(in: content.startIndex..<content.endIndex, options: .byWords) { substring, range, _, _ in
            if let s = substring, !s.isEmpty {
                // Apple HIG: 检查是否包含 ASCII 字符 (拉丁字母)
                let hasAscii = s.unicodeScalars.contains { $0.isASCII }
                if hasAscii {
                    words += 1
                }
            }
        }
        // 2. 中文字符数 (CJK Unicode 范围)
        // Apple HIG: String.unicodeScalars + isChinese 范围
        for scalar in content.unicodeScalars {
            if isChinese(scalar) {
                chineseChars += 1
            }
        }
        // 3. 字符总数 (含 / 不含空格)
        let characters = content.count
        let charactersNoSpaces = content.filter { $0 != " " && $0 != "\n" && $0 != "\t" }.count
        // 4. 句数 (中文句号 / 英文句号 / 问号 / 感叹号)
        let sentences = countSentences(content)
        // 5. 段落数 (按 \n\n 或 起始分割)
        let paragraphs = countParagraphs(content)

        return WordCount(
            words: words,
            characters: characters,
            charactersNoSpaces: charactersNoSpaces,
            chineseChars: chineseChars,
            sentences: sentences,
            paragraphs: paragraphs
        )
    }

    /// 中文 unicode 范围 (CJK Unified Ideographs + Extension A)
    /// Apple HIG: Unicode 4E00-9FFF (基本) + 3400-4DBF (扩展 A)
    private static func isChinese(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF)
    }

    private static func countSentences(_ content: String) -> Int {
        let pattern = #"[。.!?！？]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let range = NSRange(location: 0, length: (content as NSString).length)
        let matches = regex.matches(in: content, range: range)
        return matches.count
    }

    private static func countParagraphs(_ content: String) -> Int {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        // 按 2+ 个连续换行分割 (\n\s*\n)
        guard let regex = try? NSRegularExpression(pattern: #"\n\s*\n"#) else { return 1 }
        let range = NSRange(location: 0, length: (trimmed as NSString).length)
        let splits = regex.matches(in: trimmed, range: range)
        // 段数 = split 数 + 1
        return splits.count + 1
    }
}
