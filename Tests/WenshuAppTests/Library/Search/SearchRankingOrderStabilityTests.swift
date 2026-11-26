// SearchRankingOrderStabilityTests.swift
//
// **⇒ THE RANKING'S ORDER MUST NOT DEPEND ON HOW THE SUM WAS WALKED.**
//
// The library's ranking sums a document's score over the terms the query
// asked for. The sum's value depends on the order its addends are visited
// in, because floating-point addition does not associate. The terms are kept
// in a `Set`, and a `Set` visits them in whatever order its buckets came out
// in - not in any order the ranking chose.
//
// The MEASURED mechanism, taken off this branch with
// Sources/WenshuApp/Features/Library/Service/SearchRanking.swift:186 reverted
// to `let querySet = Set(queryTokens)`:
//
//   - a `String`'s hash VALUE is the same on every thread of one process, and
//     differs between processes;
//   - a `Set`'s VISIT ORDER is not the process's business: it is the layout
//     that ONE INSTANCE settled on, and the same terms put into a second
//     instance - or into the same instance in another arrival order - settle
//     differently. Three launches of the fixture below measured three
//     different rankings, and 144 rotations of ONE launch's arrival order
//     measured 16 of them, all in that one process and with no sibling test
//     running beside it;
//   - at the pinned tip both numbers are 0: one ranking, every launch, every
//     rotation.
//
// So the defect lives in the visit order, not in the process, and the
// cross-process arm below is CORROBORATING rather than discriminating. It is
// still a gate, and it FAILS when the second process cannot start: an
// assertion that skips is an assertion that measured nothing.
//
// Every arm asks the app's own `ReferenceLibrarySearch.search` and the app's
// own `TokenOverlapRanking.score`. A probe that re-declared the ranking would
// have measured itself.

import Foundation
import Testing
@testable import WenshuApp

@Suite("the library ranking's order is the same in every process")
struct SearchRankingOrderStabilityTests {
    // MARK: - The tie fixture

    /// One pair is two documents that match DIFFERENT terms carrying the SAME
    /// weights and the SAME occurrence counts. Their scores are equal in exact
    /// arithmetic, so the title tie-break is the rule that should decide them
    /// - and it only fires when the two sums come out bit-equal.
    ///
    /// **⇒ THE FIXTURE EXISTS TO MAKE THE TIE-BREAK REACH THE QUESTION.** The
    /// sum walks every term the query asked for, = = but only this document's
    /// own three of them add anything, = = so what matters is the visit order
    /// RESTRICTED to that triple, = = and a triple is laid out per instance
    /// rather than per process. A corpus whose tied documents share their
    /// terms cannot show this: both sides then add the same values in the same
    /// relative order, tie exactly, and no seed moves a slot.
    static let pairCount = 24

    /// The three terms one side of one pair matches.
    static func terms(pair: Int, side: String) -> [String] {
        ["\(side)\(pair)1", "\(side)\(pair)2", "\(side)\(pair)3"]
    }

    /// The body of one side: the same three occurrence counts on both sides,
    /// so the two addend multisets are equal and only the order they are
    /// summed in can separate them.
    static func body(pair: Int, side: String) -> String {
        let matched = terms(pair: pair, side: side)
        var parts: [String] = []
        parts.append(contentsOf: Array(repeating: matched[0], count: 5))
        parts.append(matched[1])
        parts.append(contentsOf: Array(repeating: matched[2], count: 3))
        parts.append(contentsOf: (0 ..< 20).map { "noise\(pair)\($0)" })
        return parts.joined(separator: " ")
    }

    /// The tie fixture: `pairCount` tied pairs, plus documents that answer
    /// nothing, so the ranking places the tied pairs against a crowd.
    static func tieFixture() -> (library: RankerTable.LibraryCorpus, query: [String]) {
        var references: [Reference] = []
        var paths: [UUID: String] = [:]
        var bodies: [UUID: String] = [:]
        var query: [String] = []

        func add(_ path: String, _ text: String) {
            let reference = Reference(title: path)
            paths[reference.id] = path
            bodies[reference.id] = text
            references.append(reference)
        }

        for pair in 0 ..< pairCount {
            add("pair-\(pair)-side-a", body(pair: pair, side: "a"))
            add("pair-\(pair)-side-b", body(pair: pair, side: "b"))
            query.append(contentsOf: terms(pair: pair, side: "a")
                + terms(pair: pair, side: "b"))
        }
        for unrelated in 0 ..< 12 {
            add("solo-\(unrelated)",
                (0 ..< 24).map { "solo\(unrelated)x\($0)" }.joined(separator: " "))
        }
        return (
            RankerTable.LibraryCorpus(references: references, paths: paths, bodies: bodies),
            query
        )
    }

    /// The app's own ranking over the tie fixture, as the paths it returned.
    static func tiedOrder(
        library: RankerTable.LibraryCorpus, query: [String]
    ) -> [String] {
        ReferenceLibrarySearch.search(
            query: query.joined(separator: " "),
            references: library.references,
            bodyOf: { library.bodyOf($0) }
        ).map { library.pathOf($0.reference.id) }
    }

    /// The pairs the ranking put in the WRONG order: the side whose title
    /// sorts second placed before the side whose title sorts first.
    static func flippedPairs(_ order: [String]) -> [Int] {
        (0 ..< pairCount).filter { pair in
            let first = order.firstIndex(of: "pair-\(pair)-side-a") ?? -1
            let second = order.firstIndex(of: "pair-\(pair)-side-b") ?? -1
            return first > second
        }
    }

    // MARK: - The number the terms add up to

    /// The corpus the app's own library search reads (= the fixture's
    /// documents, as the app's own store would hand them over).
    private static func corpus() -> RankerTable.LibraryCorpus {
        RankerTable.libraryCorpus(docs: RetrievalQualityCorpus.documents)
    }

    @Test("a document's score does not depend on the order the terms arrive in")
    func scoreDoesNotDependOnTheArrivalOrder() {
        let library = Self.corpus()
        let documents = library.references.map { reference in
            TokenOverlapRanking.tokenize(reference.title)
                + TokenOverlapRanking.tokenize(library.bodyOf(reference) ?? "")
        }
        for query in RetrievalQualityCorpus.queries {
            let terms = TokenOverlapRanking.tokenize(query.text)
            guard terms.count > 1 else { continue }
            let statistics = TokenOverlapRanking.corpusStatistics(
                documents: documents,
                queryTokens: terms
            )
            for document in documents {
                let baseline = TokenOverlapRanking.score(
                    queryTokens: terms,
                    docTokens: document,
                    statistics: statistics
                )
                for shift in 1 ..< terms.count {
                    let reordered = Array(terms[shift...] + terms[..<shift])
                    let other = TokenOverlapRanking.score(
                        queryTokens: reordered,
                        docTokens: document,
                        statistics: statistics
                    )
                    #expect(
                        other.bitPattern == baseline.bitPattern,
                        """
                        the same terms in another order scored differently \
                        (question: \(query.text), shift: \(shift))
                        """
                    )
                }
            }
        }
    }

    // MARK: - The tie-break, in this process

    /// **Criterion 4's claim.** A tied pair is decided by the tie-break, not by
    /// which side happened to round higher.
    @Test("a tied pair is ordered by its title, not by the sum's rounding")
    func tiedPairsAreOrderedByTheTieBreak() {
        let fixture = Self.tieFixture()
        let order = Self.tiedOrder(library: fixture.library, query: fixture.query)
        let flipped = Self.flippedPairs(order)
        #expect(
            flipped.isEmpty,
            """
            \(flipped.count) of \(Self.pairCount) tied pairs were ordered by the \
            rounding of a sum walked in the Set's own order rather than by the \
            title tie-break (pairs: \(flipped))
            """
        )
    }

    // MARK: - The same terms, arriving in another order

    /// **⇒ THE DISCRIMINATING ARM: = = ONE PROCESS, = = NO CHILD, = = NO
    /// SIBLING RUNNING CONCURRENTLY.** The query's terms are the same set in
    /// every rotation and only the order they arrive in differs, and a `Set`
    /// settles its layout from the arrival. Under an unpinned walk a rotation
    /// is enough to re-associate a tied pair's sum.
    @Test("the ranking's order does not depend on the order the terms arrive in")
    func tiedPairsStayOrderedWhenTheTermsArriveInAnotherOrder() {
        let fixture = Self.tieFixture()
        let baseline = Self.tiedOrder(library: fixture.library, query: fixture.query)

        var drifted: [Int] = []
        for shift in 0 ..< fixture.query.count {
            let rotated = Array(fixture.query[shift...] + fixture.query[..<shift])
            let order = Self.tiedOrder(library: fixture.library, query: rotated)
            if order != baseline {
                drifted.append(shift)
            }
        }
        #expect(
            drifted.isEmpty,
            """
            \(drifted.count) of \(fixture.query.count) arrival orders answered the \
            same question with a different ranking (first drifting shifts: \
            \(drifted.prefix(8).map(String.init).joined(separator: ", ")))
            """
        )
    }

    // MARK: - The same terms, in another process

    /// The marker the probe prints one measured order against.
    private static let probeMarker = "RANKORDER"

    /// The environment variable that tells the probe to measure and print.
    private static let probeVariable = "WENSHU_RANK_ORDER_PROBE"

    /// Fault injection: stand the second process up as unstartable, so the
    /// skip path can be SHOWN to fail rather than trusted to. `swift test`
    /// with this set to 1 must be red, not green.
    private static let noRunnerVariable = "WENSHU_RANK_ORDER_NO_RUNNER"

    /// CORROBORATING rather than discriminating: this measures the PROCESS
    /// axis, and the defect lives in the instance axis. It is kept because a
    /// second seed is a second layout, and the pinned ranking must not care
    /// about that either - and because it fails loudly when the child cannot
    /// run, instead of passing by not measuring.
    @Test("the ranking's order is the same in another process")
    func tiedPairsStayOrderedInAnotherProcess() throws {
        let blocked = ProcessInfo.processInfo.environment[Self.noRunnerVariable] == "1"
        let helper = try #require(
            blocked ? nil : Bundle.main.executablePath,
            """
            the second-process runner is unavailable, so this arm measured \
            nothing and must not be read as a pass
            """
        )
        let bundle = try #require(
            Self.bundlePath(),
            """
            the second-process runner was not told where the test bundle is, \
            so this arm measured nothing
            """
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: helper)
        process.arguments = [
            "--test-bundle-path", bundle,
            "--filter", "rankOrderProbe",
            bundle,
            "--testing-library", "swift-testing",
        ]
        var environment = ProcessInfo.processInfo.environment
        environment[Self.probeVariable] = "1"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        process.waitUntilExit()
        #expect(
            process.terminationStatus == 0,
            "the second process should measure the ranking; it said: \(output)"
        )

        // **⇒ A CHILD THAT MEASURED NOTHING IS A FAILURE, NOT A SKIP.**
        let mine = Self.tieFixture()
        let measured = Self.tiedOrder(library: mine.library, query: mine.query)
        let other = try #require(
            Self.parseProbeOutput(output).nilIfEmpty(),
            """
            the second process printed no measured order, so this arm measured \
            nothing (runner: \(helper), bundle: \(bundle), output: \(output))
            """
        )
        #expect(
            other.count == 1,
            """
            the second process should measure the tie fixture once; it measured \
            it \(other.count) times
            """
        )
        let theirs = other.first ?? []
        #expect(
            theirs == measured,
            """
            the tie fixture was answered in a different order in another \
            process (this one flipped \(Self.flippedPairs(measured).count) \
            pairs, the other flipped \(Self.flippedPairs(theirs).count))
            """
        )
    }

    /// Where the test bundle sits (= the runner is told where it is).
    private static func bundlePath() -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--test-bundle-path"),
              index + 1 < arguments.count
        else { return nil }
        return arguments[index + 1]
    }

    /// The orders a probe process measured.
    private static func parseProbeOutput(_ output: String) -> [[String]] {
        output
            .split(separator: "\n")
            .compactMap { line -> [String]? in
                guard line.hasPrefix(probeMarker) else { return nil }
                let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard fields.count >= 2 else { return nil }
                return fields[1].split(separator: "|").map(String.init)
            }
    }

    /// The probe: it measures the tie fixture and prints what it measured.
    ///
    /// **⇒ IT MEASURES THE APP'S OWN SEARCH, = = AND NOT A COPY.**
    @Test("rank order probe")
    func rankOrderProbe() {
        guard ProcessInfo.processInfo.environment[Self.probeVariable] == "1" else {
            return
        }
        let fixture = Self.tieFixture()
        let order = Self.tiedOrder(library: fixture.library, query: fixture.query)
        print("\(Self.probeMarker)\t\(order.joined(separator: "|"))")
    }
}

private extension Array {
    /// Empty in, nil out (= so `#require` can tell "measured nothing" apart
    /// from "measured one thing that agreed").
    func nilIfEmpty() -> [Element]? {
        isEmpty ? nil : self
    }
}
