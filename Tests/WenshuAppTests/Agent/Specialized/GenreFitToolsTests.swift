//
//  GenreFitToolsTests.swift · Wenshu · P1 ticket #9 (PORT-SPECIALIZED-004, 2026-09-04)
//
//  5 round-trip tests for `GenreFitAnalyzer` actor (the Swift
//  port of hermes's `agent/specialized/genre_fit.py`).
//
//    1. testAvailableGenres_returnsAllPresets
//    2. testConventionsForGenre_mystery_returnsCorrectBeats
//    3. testAnalyze_mysteryChapterWithClueHits_returnsHighScore
//    4. testAnalyze_romanceChapterWithDeusExMachina_returnsForbiddenHit
//    5. testAnalyze_sciFiChapterWithWarpDrive_returnsExpectedVocab
//
//  Stateless actor (= no BookStore dependency); tests construct
//  the actor with `GenreFitAnalyzer()` and pass raw chapter text
//  straight to `analyze(chapterText:genre:)`.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("GenreFitAnalyzer (PORT-SPECIALIZED-004)")
struct GenreFitToolsTests {

    // MARK: - Test 1: available genres

    @Test("available genres returns all 10 presets")
    func testAvailableGenres_returnsAllPresets() async {
        let analyzer = GenreFitAnalyzer()
        let summaries = await analyzer.availableGenres()
        #expect(summaries.count == LiteraryGenre.allCases.count,
                "Expected 10 genre summaries; got \(summaries.count)")
        let rawValues = Set(summaries.map { $0.genre.rawValue })
        let expectedRaw = Set(LiteraryGenre.allCases.map { $0.rawValue })
        #expect(rawValues == expectedRaw,
                "Expected summaries to cover all 10 LiteraryGenre cases.")
        // Every genre must have at least 1 required beat.
        for summary in summaries {
            #expect(summary.requiredBeatCount >= 1,
                    "Genre \(summary.genre.rawValue) must have at least 1 required beat.")
            #expect(!summary.displayName.isEmpty,
                    "Genre \(summary.genre.rawValue) must have a non-empty displayName.")
        }
    }

    // MARK: - Test 2: conventions

    @Test("conventions for mystery genre returns the correct required beats")
    func testConventionsForGenre_mystery_returnsCorrectBeats() async throws {
        let analyzer = GenreFitAnalyzer()
        let preset = try await analyzer.conventions(for: .mystery)
        #expect(preset.genre == .mystery)
        #expect(preset.requiredBeats.contains("crime introduction"))
        #expect(preset.requiredBeats.contains("investigation"))
        #expect(preset.requiredBeats.contains("clue"))
        #expect(preset.requiredBeats.contains("suspect"))
        #expect(preset.requiredBeats.contains("red herring"))
        #expect(preset.requiredBeats.contains("alibi"))
        #expect(preset.requiredBeats.contains("revelation"))
        #expect(preset.requiredBeats.contains("resolution"))
        // Mystery vocab must include the canonical tokens.
        let vocab = preset.expectedVocab.map { $0.lowercased() }
        for token in ["alibi", "suspect", "clue"] {
            #expect(vocab.contains(token),
                    "Mystery preset must include expected vocab `\(token)`.")
        }
        #expect(!preset.forbiddenPatterns.isEmpty,
                "Mystery preset must declare at least one forbidden pattern.")
    }

    // MARK: - Test 3: mystery high-score

    @Test("mystery chapter with clue hits and reveal returns a high score")
    func testAnalyze_mysteryChapterWithClueHits_returnsHighScore() async throws {
        let analyzer = GenreFitAnalyzer()
        let chapter = """
        Detective Mara arrived at the crime scene. The victim lay on the floor, blood pooling around her.

        Mara examined the room for a clue. She found a fingerprint on the glass and a footprint near the door.

        The suspect had a clear alibi, but Mara suspected the butler was the real culprit.

        Mara interrogated the witness and realized the red herring had led everyone astray.

        It was the gardener, after all. The detective arrested him and the case was closed.
        """
        let report = try await analyzer.analyze(chapterText: chapter, genre: .mystery)
        #expect(report.genre == .mystery)
        #expect(report.score >= 60.0,
                "Expected high mystery score for chapter with crime / clue / suspect / reveal; got \(report.score)")
        // Required beats that should have matched.
        #expect(report.matchedBeats.contains("crime introduction"),
                "Chapter should match `crime introduction` beat.")
        #expect(report.matchedBeats.contains("clue"),
                "Chapter should match `clue` beat.")
        #expect(report.matchedBeats.contains("suspect"),
                "Chapter should match `suspect` beat.")
        // Expected vocab credit.
        #expect(report.expectedVocabUsed.contains { $0.lowercased() == "clue" },
                "Chapter should credit expected vocab `clue`.")
        #expect(report.expectedVocabUsed.contains { $0.lowercased() == "suspect" },
                "Chapter should credit expected vocab `suspect`.")
    }

    // MARK: - Test 4: romance forbidden

    @Test("romance chapter with `deus ex machina` returns a forbidden hit")
    func testAnalyze_romanceChapterWithDeusExMachina_returnsForbiddenHit() async throws {
        let analyzer = GenreFitAnalyzer()
        let chapter = """
        They met cute at the coffee shop, our eyes met across the room.

        He felt a spark, drawn to her, and she flirted with him in return.

        They had an argument and a misunderstanding, a wall between them.

        Then a sudden love struck them out of nowhere, a deus ex machina moment, and they were together forever.
        """
        let report = try await analyzer.analyze(chapterText: chapter, genre: .romance)
        #expect(report.genre == .romance)
        #expect(report.forbiddenHits.contains { $0.lowercased() == "deus ex machina" },
                "Chapter should flag `deus ex machina` as a forbidden hit.")
        #expect(report.forbiddenHits.contains { $0.lowercased() == "sudden love" },
                "Chapter should flag `sudden love` as a forbidden hit.")
        // Score must be penalized (= not 100; the penalty for 2 forbidden
        // hits alone is 24 points).
        #expect(report.score < 100.0,
                "Score must be reduced by forbidden-pattern penalty; got \(report.score).")
    }

    // MARK: - Test 5: sci-fi expected vocab

    @Test("sci-fi chapter with warp drive + spaceship returns the expected vocab hit")
    func testAnalyze_sciFiChapterWithWarpDrive_returnsExpectedVocab() async throws {
        let analyzer = GenreFitAnalyzer()
        let chapter = """
        The starship glided through the galaxy toward the colony on the distant planet.

        The quantum computer plotted the course, but the warp drive was failing.

        The captain activated the terraform module and the android logged the encounter.

        What does it mean to be human, asked the android, the ethical question of the age.
        """
        let report = try await analyzer.analyze(chapterText: chapter, genre: .sciFi)
        #expect(report.genre == .sciFi)
        let usedLower = report.expectedVocabUsed.map { $0.lowercased() }
        #expect(usedLower.contains("warp drive"),
                "Chapter should credit `warp drive` as expected vocab; used = \(report.expectedVocabUsed).")
        #expect(usedLower.contains("spaceship") || usedLower.contains("starship"),
                "Chapter should credit `spaceship` or `starship` as expected vocab; used = \(report.expectedVocabUsed).")
        #expect(report.matchedBeats.contains("speculative tech"),
                "Chapter should match the `speculative tech` beat.")
        #expect(report.matchedBeats.contains("ethical question"),
                "Chapter should match the `ethical question` beat.")
        #expect(report.forbiddenHits.isEmpty,
                "Sci-fi chapter should have no forbidden hits; got \(report.forbiddenHits).")
    }
}
