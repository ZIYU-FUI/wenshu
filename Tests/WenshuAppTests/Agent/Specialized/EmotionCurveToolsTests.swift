//
//  EmotionCurveToolsTests.swift · Wenshu · P1 ticket #11 (PORT-SPECIALIZED-006, 2026-09-04)
//
//  5 round-trip tests for `EmotionCurveAnalyzer` actor (the
//  Swift port of hermes's `agent/specialized/emotion_curve.py`).
//
//    1. testAnalyze_chapterWithPositiveEnding_returnsPositiveOverallScore
//    2. testAnalyze_chapterWithSadTone_returnsNegativeOverallScore
//    3. testAnalyze_chapterWithSwingTone_returnsHighVolatility
//    4. testAnalyze_chapterWithUniformTone_returnsFlatSpot
//    5. testAnalyze_shortChapter_returnsOneWindow
//
//  Stateless actor (= no BookStore dependency); tests construct
//  the actor with `EmotionCurveAnalyzer()` and pass raw chapter
//  text straight to `analyze(chapterText:windowCount:)`.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("EmotionCurveAnalyzer (PORT-SPECIALIZED-006)")
struct EmotionCurveToolsTests {

    // MARK: - Test 1: positive overall

    @Test("chapter with positive ending returns positive overall score")
    func testAnalyze_chapterWithPositiveEnding_returnsPositiveOverallScore() async throws {
        let analyzer = EmotionCurveAnalyzer()
        // Each segment is mostly positive vocabulary with
        // the last segment loaded with positive lexicon hits
        // (= happy, hope, glad, lovely, win, celebrate, etc.).
        let chapter = """
        The morning was beautiful and the sun was bright over the village.
        Children laughed and played in the garden while the birds sang.
        She felt hope rising in her chest as she walked toward the future.
        Friends gathered to celebrate the wonderful news with smiles and joy.
        The wedding was a triumph of love and everyone was glad and happy.
        They felt grateful for the warmth and the kindness of the people.
        The journey was successful and the team was winning every challenge.
        At last the brave explorers returned home with a victorious smile.
        The community rejoiced and the day was filled with bright delight.
        The finale was a celebration of love and hope and peaceful triumph.
        """
        let report = try await analyzer.analyze(
            chapterText: chapter,
            windowCount: 10
        )
        // 10 windows for 10 segments.
        #expect(report.windows.count == 10,
                "Expected 10 windows; got \(report.windows.count).")
        // Overall score must be positive (= the chapter is
        // dominated by positive lexicon hits).
        #expect(report.overallScore > 0.0,
                "Expected positive overall score; got \(report.overallScore).")
        // The last window should be positive (= that's the
        // "positive ending" the test name advertises).
        #expect(report.windows.last?.score ?? 0.0 > 0.0,
                "Expected the last window to score positive; got \(String(describing: report.windows.last?.score)).")
        // Pacing hint should mention the positive tone.
        #expect(report.pacingHint.lowercased().contains("positive")
                || report.pacingHint.lowercased().contains("balanced"),
                "Expected pacing hint to mention the tone; got `\(report.pacingHint)`.")
    }

    // MARK: - Test 2: sad overall

    @Test("chapter with sad tone returns negative overall score")
    func testAnalyze_chapterWithSadTone_returnsNegativeOverallScore() async throws {
        let analyzer = EmotionCurveAnalyzer()
        // Each segment is mostly negative vocabulary; = the
        // analyzer should see a uniformly sad chapter.
        let chapter = """
        The village was gloomy and the people felt afraid and sad.
        A terrible death cast a shadow of grief over the broken homes.
        The cruel winter brought painful loss and cruel violence.
        Children cried and wept as the harsh storm destroyed the harvest.
        Many died and the survivors were left with sorrow and misery.
        The defeated army retreated in fear and the wounded were dying.
        The dread was awful and the hurt was deep in every grieving heart.
        Hope was lost and the loss was total — failure was everywhere.
        The death toll climbed and the grief grew worse with every day.
        At last the survivors wept in sorrow over the buried dead.
        """
        let report = try await analyzer.analyze(
            chapterText: chapter,
            windowCount: 10
        )
        #expect(report.windows.count == 10,
                "Expected 10 windows; got \(report.windows.count).")
        // Overall score must be strongly negative.
        #expect(report.overallScore < 0.0,
                "Expected negative overall score; got \(report.overallScore).")
        // Pacing hint should mention the negative tone.
        #expect(report.pacingHint.lowercased().contains("negative")
                || report.pacingHint.lowercased().contains("balanced"),
                "Expected pacing hint to mention the tone; got `\(report.pacingHint)`.")
    }

    // MARK: - Test 3: high volatility (= swing tone)

    @Test("chapter with swing tone returns high volatility")
    func testAnalyze_chapterWithSwingTone_returnsHighVolatility() async throws {
        let analyzer = EmotionCurveAnalyzer()
        // Alternate positive and negative segments so the
        // analyzer sees extreme swings between adjacent
        // windows.
        let chapter = """
        The morning was beautiful and the sun was bright over the village.
        A terrible death cast a shadow of grief over the broken homes.
        Children laughed and played in the garden while the birds sang.
        Many died and the survivors were left with sorrow and misery.
        She felt hope rising in her chest as she walked toward the future.
        The defeated army retreated in fear and the wounded were dying.
        Friends gathered to celebrate the wonderful news with smiles and joy.
        The dread was awful and the hurt was deep in every grieving heart.
        The wedding was a triumph of love and everyone was glad and happy.
        The loss was total — failure was everywhere and hope was lost.
        """
        let report = try await analyzer.analyze(
            chapterText: chapter,
            windowCount: 10
        )
        #expect(report.windows.count == 10,
                "Expected 10 windows; got \(report.windows.count).")
        // Volatility must be high (= the chapter swings).
        #expect(report.volatility > 0.3,
                "Expected high volatility (>0.3); got \(report.volatility).")
        // The analyzer should suggest at least one lift
        // (= before a spike window).
        #expect(report.suggestedLifts.count >= 1,
                "Expected at least one suggested lift; got \(report.suggestedLifts.count).")
    }

    // MARK: - Test 4: flat spot (= uniform tone)

    @Test("chapter with uniform tone returns flat spot")
    func testAnalyze_chapterWithUniformTone_returnsFlatSpot() async throws {
        let analyzer = EmotionCurveAnalyzer()
        // Build a chapter that is intentionally neutral
        // (= no lexicon hits in most windows). = uses common
        // English words that are NOT in the lexicon.
        // 10 segments × ~30 chars each.
        let segment = "The cat sat on the mat by the door near the wall. "
        let chapter = String(repeating: segment, count: 20) // 10 windows of neutral text
        let report = try await analyzer.analyze(
            chapterText: chapter,
            windowCount: 10
        )
        #expect(report.windows.count == 10,
                "Expected 10 windows; got \(report.windows.count).")
        // Most windows should be flagged as flat (= |score|
        // below the epsilon).
        #expect(report.flatSpots.count >= 5,
                "Expected at least 5 flat spots; got \(report.flatSpots.count).")
        // Overall score should be near zero (= no positive /
        // negative hits).
        #expect(abs(report.overallScore) < 0.05,
                "Expected near-zero overall score; got \(report.overallScore).")
        // The pacing hint should call out the flat stretches.
        #expect(report.pacingHint.lowercased().contains("flat")
                || report.pacingHint.lowercased().contains("steady"),
                "Expected pacing hint to mention the flat stretches; got `\(report.pacingHint)`.")
    }

    // MARK: - Test 5: short chapter (= 1 window)

    @Test("short chapter returns one window")
    func testAnalyze_shortChapter_returnsOneWindow() async throws {
        let analyzer = EmotionCurveAnalyzer()
        // A short chapter with one happy sentence.
        let chapter = "She was glad and happy on that bright morning."
        let report = try await analyzer.analyze(
            chapterText: chapter,
            windowCount: 1
        )
        #expect(report.windows.count == 1,
                "Expected 1 window; got \(report.windows.count).")
        #expect(report.windows.first?.index == 0,
                "Expected the first window index to be 0.")
        #expect(report.windows.first?.startOffset == 0,
                "Expected the first window to start at offset 0.")
        #expect(report.windows.first?.endOffset == chapter.count,
                "Expected the first window to span the full chapter.")
        // Single window = overall score equals the window's
        // own score, and volatility = 0 (= less than 2
        // samples).
        #expect(report.overallScore == report.windows.first?.score ?? 0.0,
                "Overall score should equal the only window's score.")
        #expect(report.volatility == 0.0,
                "Volatility should be 0.0 for a single window; got \(report.volatility).")
    }
}
