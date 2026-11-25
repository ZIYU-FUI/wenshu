//
//  StoryForeshadowTests.swift · Wenshu
//
//  The chains a book hangs across its chapters, and the ways they break.
//
//  The fixtures carry the book's own Chinese markers, because the
//  production vocabulary is code points and a fixture written in
//  English would not prove the two agree.
//

import Foundation
import Testing
import WenshuData

@Suite("ForeshadowChain (= the book's own thread chains, checked)")
struct StoryForeshadowTests {
    // MARK: - The markers a chapter carries

    @Test("a chapter's plant and payoff lines are read out of its thread section")
    func theMarkersAreRead() {
        let markers = ForeshadowChain.markers(in: """
        # 第一章

        正文。

        ## 伏笔

        - **埋设**: 左手的旧疤。
        - **兑现**: 北门下的旧疤。
        """)
        #expect(markers.plants == ["左手的旧疤。"])
        #expect(markers.payoffs.count == 1)
        #expect(markers.payoffs.first?.text == "北门下的旧疤。")
        #expect(markers.payoffs.first?.sourceChapter == nil)
    }

    @Test("a line outside the thread section is not a marker")
    func linesOutsideTheSectionAreNotMarkers() {
        let markers = ForeshadowChain.markers(in: """
        # 第一章

        - **埋设**: 左手的旧疤。
        """)
        #expect(markers.plants.isEmpty)
    }

    @Test("a payoff whose text mentions a plant is not read as a plant")
    func aPayoffMentioningAPlantIsNotAPlant() {
        let markers = ForeshadowChain.markers(in: """
        ## 伏笔

        - **兑现**: 第三章埋下的旧疤。
        """)
        #expect(markers.plants.isEmpty)
        #expect(markers.payoffs.count == 1)
    }

    @Test("a note whose label merely mentions the plant is not a plant")
    func aNoteMentioningThePlantIsNotAPlant() {
        // The head must BE the label, not mention it: a note saying
        // "this chapter plants nothing" is not a thread, and reading it
        // as one reports a thread the book does not have.
        let markers = ForeshadowChain.markers(in: """
        ## 伏笔

        - 埋设备注: 本章不埋新伏笔。
        """)
        #expect(markers.plants.isEmpty)
        #expect(markers.payoffs.isEmpty)
    }

    @Test("a note whose label merely mentions the payoff is not a payoff")
    func aNoteMentioningThePayoffIsNotAPayoff() {
        let markers = ForeshadowChain.markers(in: """
        ## 伏笔

        - 兑现方式: 对照第 3 章的写法。
        """)
        #expect(markers.plants.isEmpty)
        #expect(markers.payoffs.isEmpty)
    }

    @Test("a marker line written with the full width colon is still a marker")
    func aFullWidthColonIsStillAMarker() {
        // The template ships the half width colon, but a chapter a
        // writer typed by hand carries the full width one (= the
        // punctuation the same template uses two lines away).
        let markers = ForeshadowChain.markers(in: """
        ## 伏笔

        - **埋设**：左手的旧疤。
        - **兑现**：北门下的旧疤。
        """)
        #expect(markers.plants == ["左手的旧疤。"])
        #expect(markers.payoffs.count == 1)
        #expect(markers.payoffs.first?.text == "北门下的旧疤。")
    }

    @Test("the template's own placeholder is not a thread the book has planted")
    func theTemplatePlaceholderIsNotAThread() {
        let markers = ForeshadowChain.markers(in: """
        ## 伏笔

        - **埋设**: <本章埋下一个细节，指向未来章节>
        - **兑现**: <本章兑现之前的某个伏笔，源自第 X 章>
        """)
        #expect(markers.plants.isEmpty)
        #expect(markers.payoffs.isEmpty)
    }

    // MARK: - The chapter a payoff names

    @Test("a payoff naming an arabic chapter is read")
    func arabicChapterIsRead() {
        #expect(ForeshadowVocabulary.ordinal(in: "源自第 3 章") == 3)
        #expect(ForeshadowVocabulary.ordinal(in: "源自第3章") == 3)
    }

    @Test("a payoff naming a chapter in the book's own numerals is read")
    func bookNumeralChapterIsRead() {
        #expect(ForeshadowVocabulary.ordinal(in: "源自第三章") == 3)
        #expect(ForeshadowVocabulary.ordinal(in: "源自第十章") == 10)
        #expect(ForeshadowVocabulary.ordinal(in: "源自第十二章") == 12)
    }

    @Test("a word that begins with the chapter word names no chapter")
    func anOrdinaryWordNamesNoChapter() {
        #expect(ForeshadowVocabulary.ordinal(in: "第二次她跑了") == nil)
    }

    @Test("a text with no chapter names no chapter")
    func noChapterNamesNone() {
        #expect(ForeshadowVocabulary.ordinal(in: "左手的旧疤") == nil)
    }

    // MARK: - The breaks

    @Test("a payoff that arrives before its plant is a break")
    func payoffBeforePlantIsABreak() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 5, body: """
            ## 伏笔

            - **兑现**: 旧疤，源自第 9 章。
            """),
            ForeshadowChapter(number: 9, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
        ])
        #expect(breaks == [.payoffBeforePlant(payoffChapter: 5, plantChapter: 9)])
    }

    @Test("a payoff naming a chapter that plants nothing is a break")
    func payoffNamingAPlantingChapterIsABreak() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 3, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
            ForeshadowChapter(number: 5, body: """
            ## 伏笔

            - **兑现**: 旧疤，源自第 3 章。
            """),
            ForeshadowChapter(number: 9, body: """
            ## 伏笔

            - **兑现**: 旧疤，源自第 5 章。
            """),
        ])
        #expect(breaks == [.payoffNamesChapterThatPlantsNothing(payoffChapter: 9, namedChapter: 5)])
    }

    @Test("a payoff naming a chapter the book does not have is a break")
    func payoffNamingAMissingChapterIsABreak() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 3, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
            ForeshadowChapter(number: 5, body: """
            ## 伏笔

            - **兑现**: 旧疤，源自第 99 章。
            """),
        ])
        #expect(breaks == [
            .plantNeverPaidOff(plantChapter: 3),
            .payoffNamesChapterThatDoesNotExist(payoffChapter: 5, namedChapter: 99),
        ])
    }

    @Test("a planted thread that is never paid off is a break")
    func unpaidPlantIsABreak() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 3, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
            ForeshadowChapter(number: 5, body: """
            ## 伏笔

            - **兑现**: 旧疤，源自第 3 章。
            """),
            ForeshadowChapter(number: 9, body: """
            ## 伏笔

            - **埋设**: 一封没有寄出的信。
            """),
        ])
        #expect(breaks == [.plantNeverPaidOff(plantChapter: 9)])
    }

    @Test("a book whose threads all close has no breaks")
    func aClosedBookHasNoBreaks() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 3, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
            ForeshadowChapter(number: 5, body: """
            ## 伏笔

            - **兑现**: 旧疤，源自第 3 章。
            """),
        ])
        #expect(breaks.isEmpty)
    }

    @Test("a payoff whose origin the file cannot read leaves no thread unpaid")
    func anUnreadablePayoffLeavesNoThreadUnpaid() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 3, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
            ForeshadowChapter(number: 5, body: """
            ## 伏笔

            - **兑现**: 旧疤。
            """),
        ])
        #expect(breaks.isEmpty)
    }

    @Test("the breaks read in the book's own order")
    func theBreaksReadInOrder() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 3, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
            ForeshadowChapter(number: 5, body: """
            ## 伏笔

            - **兑现**: 旧疤，源自第 9 章。
            """),
            ForeshadowChapter(number: 7, body: """
            ## 伏笔

            - **埋设**: 一封没有寄出的信。
            """),
            ForeshadowChapter(number: 9, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            """),
        ])
        #expect(breaks == [
            .plantNeverPaidOff(plantChapter: 3),
            .payoffBeforePlant(payoffChapter: 5, plantChapter: 9),
            .plantNeverPaidOff(plantChapter: 7),
        ])
    }

    @Test("a book with no markers has no breaks")
    func aBookWithNoMarkersHasNoBreaks() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 1, body: "# 第一章\n\n正文。"),
        ])
        #expect(breaks.isEmpty)
    }

    @Test("one unpaid chapter is one break however many threads it plants")
    func oneUnpaidChapterIsOneBreak() {
        // The break's payload is chapter grain, so a chapter that
        // plants two threads and is paid off by neither is ONE thing
        // for the writer to fix (= and the report says it once).
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 3, body: """
            ## 伏笔

            - **埋设**: 左手的旧疤。
            - **埋设**: 一封没有寄出的信。
            """),
        ])
        #expect(breaks == [.plantNeverPaidOff(plantChapter: 3)])
    }

    @Test("two payoffs naming the same absent chapter are one break")
    func twoPayoffsNamingTheSameChapterAreOneBreak() {
        let breaks = ForeshadowChain.scan(chapters: [
            ForeshadowChapter(number: 9, body: """
            ## 伏笔

            - **兑现**: 旧疤，源自第 5 章。
            - **兑现**: 另一处旧疤，源自第 5 章。
            """),
        ])
        #expect(breaks == [
            .payoffNamesChapterThatDoesNotExist(payoffChapter: 9, namedChapter: 5),
        ])
    }
}
