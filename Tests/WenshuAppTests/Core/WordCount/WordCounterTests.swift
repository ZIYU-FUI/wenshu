//
//  WordCounterTests.swift · Wenshu · v0.19 ticket 20
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WordCounter (Obsidian replica)")
struct WordCounterTests {

    @Test("空内容")
    func emptyContent() {
        let count = WordCounter.count("")
        #expect(count.words == 0)
        #expect(count.characters == 0)
        #expect(count.chineseChars == 0)
        #expect(count.sentences == 0)
        #expect(count.paragraphs == 0)
    }

    @Test("英文 word 计数")
    func englishWords() {
        let count = WordCounter.count("The quick brown fox")
        #expect(count.words == 4)
        #expect(count.characters == 19)  // 含 3 个空格
        #expect(count.charactersNoSpaces == 16)
        #expect(count.chineseChars == 0)
    }

    @Test("中文字符计数")
    func chineseChars() {
        let count = WordCounter.count("林黛玉进贾府")
        #expect(count.chineseChars == 6)
        #expect(count.words == 0, "中文不计入英文 word")
    }

    @Test("中英混合")
    func mixedChineseEnglish() {
        let count = WordCounter.count("Hello 林黛玉 world")
        #expect(count.words == 2, "Hello / world 各算 1 word")
        #expect(count.chineseChars == 3, "林黛玉 = 3 中文字")
    }

    @Test("句数")
    func sentences() {
        let count = WordCounter.count("First sentence. Second sentence! Third? 第四句。")
        #expect(count.sentences == 4)
    }

    @Test("段落数")
    func paragraphs() {
        let count = WordCounter.count("First paragraph.\n\nSecond paragraph.\n\nThird paragraph.")
        #expect(count.paragraphs == 3)
    }

    @Test("单段落 (无空行)")
    func singleParagraph() {
        let count = WordCounter.count("Just one paragraph with multiple lines.\nBut no blank line.")
        #expect(count.paragraphs == 1)
    }

    @Test("中文标点 + 句数")
    func chineseSentences() {
        let count = WordCounter.count("林黛玉哭了。宝玉走了！宝钗问：为什么？")
        // Apple HIG: 中文标点 。！？ + 英文标点 .!? 都算 1 个句末标点
        // "林黛玉哭了。" "宝玉走了！" "宝钗问：为什么？" = 3 句 (regex 把 "？" 算 1 个)
        #expect(count.sentences == 3)
    }

    @Test("markdown 内容 (含 # ## 等)")
    func markdownContent() {
        let count = WordCounter.count("# 第一章\n\n林黛玉进贾府，与贾宝玉初见。\n\n## 第一节")
        #expect(count.chineseChars >= 14)  // "第一章林黛玉进贾府与贾宝玉初见第一节" 中文字
        #expect(count.paragraphs >= 3)  // "# 第一章" / "林黛玉..." / "## 第一节"
    }

    @Test("中文标点 . 不算英文句号")
    func mixedPunctuation() {
        // "林黛玉. 贾宝玉" 中 . 是英文句号, 算 1 句
        let count = WordCounter.count("林黛玉. 贾宝玉")
        #expect(count.sentences == 1)
    }
}
