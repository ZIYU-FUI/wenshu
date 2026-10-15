// WordCounter.swift
//
// Word count: characters, characters-no-spaces, words, in-progress
// (mirrors the Obsidian Word Count plugin). Uses Foundation
// String.enumerateSubstrings(.byComposedCharacterSequences /
// .byWords) — supports CJK via Apple's word-segmentation rules.

import Foundation

/// WordCount: (Obsidian Word count 1:1)
struct WordCount: Equatable, Sendable {
    let words: Int           // word
    let characters: Int      // ()
    let charactersNoSpaces: Int  // ()
    let chineseChars: Int    // in progress (CJK)
    let sentences: Int       //
    let paragraphs: Int     //

    init(words: Int, characters: Int, charactersNoSpaces: Int, chineseChars: Int, sentences: Int, paragraphs: Int) {
        self.words = words
        self.characters = characters
        self.charactersNoSpaces = charactersNoSpaces
        self.chineseChars = chineseChars
        self.sentences = sentences
        self.paragraphs = paragraphs
    }
}

/// WordCounter:
/// Obsidian Word count plugin ok (https://obsidian.md/help/plugins/word-count)
enum WordCounter {

    /// markdown content
    static func count(_ content: String) -> WordCount {
        var words = 0
        var chineseChars = 0
        // 1. word (.byWords) — ASCII / word (CJK word)
        content.enumerateSubstrings(in: content.startIndex..<content.endIndex, options: .byWords) { substring, range, _, _ in
            if let s = substring, !s.isEmpty {
                // Apple HIG: yesno ASCII ()
                let hasAscii = s.unicodeScalars.contains { $0.isASCII }
                if hasAscii {
                    words += 1
                }
            }
        }
        // 2. in progress (CJK Unicode)
        // Apple HIG: String.unicodeScalars + isChinese
        for scalar in content.unicodeScalars {
            if isChinese(scalar) {
                chineseChars += 1
            }
        }
        // 3. Total number of characters (includes / without spaces)
        let characters = content.count
        let charactersNoSpaces = content.filter { $0 != " " && $0 != "\n" && $0 != "\t" }.count
        // 4. Period (Chinese stop / English stop / question mark / exclamation mark)
        let sentences = countSentences(content)
        // 5. (\n\n)
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

    /// in progress unicode (CJK Unified Ideographs + Extension A)
    /// Apple HIG: Unicode 4E00-9FFF (basic) + 3400-4DBF (A)
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
        // 2+ ok (\n\s*\n)
        guard let regex = try? NSRegularExpression(pattern: #"\n\s*\n"#) else { return 1 }
        let range = NSRange(location: 0, length: (trimmed as NSString).length)
        let splits = regex.matches(in: trimmed, range: range)
        // = split + 1
        return splits.count + 1
    }
}
