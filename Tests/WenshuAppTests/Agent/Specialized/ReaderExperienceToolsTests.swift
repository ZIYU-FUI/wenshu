//
//  ReaderExperienceToolsTests.swift · Wenshu · P1 ticket #7 (PORT-SPECIALIZED-002, 2026-09-04)
//
//  5 round-trip tests for `ReaderExperienceAnalyzer` actor (the
//  Swift port of hermes's `agent/specialized/reader_experience.py`).
//
//    1. testTensionAnalysis_chapterWithRisingAction_returnsHighScore
//    2. testPacingAnalysis_chapterWithDialogueHeavy_returnsFastPacing
//    3. testForeshadowingDensity_chapterWithSetup_returnsMatch
//    4. testCliffhanger_chapterEndingWithQuestion_returnsDetected
//    5. testPayoffDetector_chapterResolvingEarlierSetup_returnsDetected
//
//  Stateless actor (= no BookStore dependency); tests construct
//  the actor with `bookStore: nil` and pass raw chapter text
//  straight to `analyze(chapterText:kind:)`.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ReaderExperienceAnalyzer (PORT-SPECIALIZED-002)")
struct ReaderExperienceToolsTests {

    // MARK: - Test 1: tension

    @Test("tension analysis returns a high score for a chapter with rising action")
    func testTensionAnalysis_chapterWithRisingAction_returnsHighScore() async throws {
        let analyzer = ReaderExperienceAnalyzer()
        let chapter = """
        Mara woke up tired but calm. The morning light filtered through the curtains and she stretched.

        By midday, a strange letter arrived. Mara opened it carefully, wondering who could have sent it.

        In the afternoon, the enemy approached the gates. Soldiers shouted, swords drawn, blood on the cobblestones.

        At night, the fire spread across the village. Mara screamed, trapped, terrified, doomed to die.

        At the final moment, Mara killed the warlord and escaped the burning ruin. Victory!
        """
        let report = try await analyzer.analyze(chapterText: chapter, kind: .tension)
        #expect(report.kind == .tension)
        #expect(report.score >= 0.5, "Expected high tension score for rising-action chapter; got \(report.score)")
        #expect(!report.summary.isEmpty)
    }

    // MARK: - Test 2: pacing

    @Test("pacing analysis returns a fast-pacing label for a dialogue-heavy chapter")
    func testPacingAnalysis_chapterWithDialogueHeavy_returnsFastPacing() async throws {
        let analyzer = ReaderExperienceAnalyzer()
        let chapter = """
        "Where are we going?" she asked.

        "To the shore," he replied.

        "Why the shore?" she demanded.

        "Because the ship leaves at dawn," he said.

        "And if I refuse?" she whispered.

        "Then you die here," he answered.
        """
        let report = try await analyzer.analyze(chapterText: chapter, kind: .pacing)
        #expect(report.kind == .pacing)
        #expect(report.score >= 0.5, "Expected fast pacing for dialogue-heavy chapter; got \(report.score)")
        #expect(!report.highlights.isEmpty, "Expected at least one dialogue-line highlight")
        #expect(report.highlights.allSatisfy { $0.label == "dialogue line" })
    }

    // MARK: - Test 3: foreshadowing density

    @Test("foreshadowing density returns matched setup sentences for a chapter that plants setups")
    func testForeshadowingDensity_chapterWithSetup_returnsMatch() async throws {
        let analyzer = ReaderExperienceAnalyzer()
        let chapter = """
        Little did she know, the letter would change everything. She promised to return before winter.

        The captain warned her about the fog. He wondered if the old map still pointed to the right cove.

        She sensed something wrong. The air smelled of salt and burned sugar.
        """
        let report = try await analyzer.analyze(chapterText: chapter, kind: .foreshadowingDensity)
        #expect(report.kind == .foreshadowingDensity)
        #expect(report.highlights.contains(where: { $0.label == "setup" }))
        #expect(report.score > 0.0, "Expected non-zero foreshadowing density for setup-heavy chapter; got \(report.score)")
    }

    // MARK: - Test 4: cliffhanger

    @Test("cliffhanger analyzer detects a chapter ending with a question")
    func testCliffhanger_chapterEndingWithQuestion_returnsDetected() async throws {
        let analyzer = ReaderExperienceAnalyzer()
        let chapter = """
        The footsteps grew louder as Mara crept through the corridor. The candle flickered.

        She pushed the heavy door open and saw the shadow standing at the far end of the room.

        "Who is there?" Mara called out. But no one answered. Was it him at last?
        """
        let report = try await analyzer.analyze(chapterText: chapter, kind: .cliffhanger)
        #expect(report.kind == .cliffhanger)
        #expect(report.score == 1.0, "Expected cliffhanger score = 1.0 when chapter ends with a question; got \(report.score)")
        #expect(report.highlights.contains(where: { $0.label == "cliffhanger" }))
    }

    // MARK: - Test 5: payoff detector

    @Test("payoff detector returns detected when chapter resolves an earlier setup")
    func testPayoffDetector_chapterResolvingEarlierSetup_returnsDetected() async throws {
        let analyzer = ReaderExperienceAnalyzer()
        let chapter = """
        Mara remembered the promise she had made at the start of the journey. The warlord had warned her, and now the moment of reckoning had arrived.

        As expected, the trap sprung the moment Mara stepped through the gate. She had discovered the weak point weeks earlier, and now the warlord fell defeated at last.
        """
        let report = try await analyzer.analyze(chapterText: chapter, kind: .payoffDetector)
        #expect(report.kind == .payoffDetector)
        #expect(report.score == 1.0, "Expected payoff score = 1.0 when both resolution verbs AND callback phrase are present; got \(report.score)")
        #expect(report.highlights.contains(where: { $0.label == "callback" }))
    }
}
