// SearchRankingOrderStabilityTests.swift
//
// **⇒ THE RANKING'S ORDER MUST NOT DEPEND ON THE PROCESS THAT RAN IT.**
//
// The library's ranking sums a document's score over the terms the query
// asked for. The terms are kept in a `Set`, and a `Set` visits its members
// in an order the process's hash seed decides: two launches of the app can
// visit the same terms in two different orders, and the sum's last bits
// follow. Two documents of nearly equal score therefore trade places, and
// the list the user reads shuffles under them.
//
// So this file measures two things, and both are about the app's own
// functions:
//
//   - the ranking's ORDER over the retrieval fixture, asked with the same
//     terms in a different order (= = the terms are the same set, = = only
//     the order they are visited in changes);
//   - the ranking's ORDER over the same fixture, measured in a second
//     process (= = a second hash seed).
//
// Both must be the same order every time. The tie-break by title is the
// last line of defence, and it only fires when two scores are exactly
// equal: a sum that carries a seed-dependent rounding error never lets the
// tie-break reach the question.

import Foundation
import Testing
@testable import WenshuApp

@Suite("the library ranking's order is the same in every process")
struct SearchRankingOrderStabilityTests {
    // MARK: - The measurements

    /// The corpus the app's own library search reads (= the fixture's
    /// documents, as the app's own store would hand them over).
    private static func corpus() -> RankerTable.LibraryCorpus {
        RankerTable.libraryCorpus(docs: RetrievalQualityCorpus.documents)
    }

    /// The order the app's own library search answers in.
    private static func order(
        of query: String,
        library: RankerTable.LibraryCorpus
    ) -> [String] {
        ReferenceLibrarySearch.search(
            query: query,
            references: library.references,
            bodyOf: { library.bodyOf($0) }
        ).map { library.pathOf($0.reference.id) }
    }

    /// The same question with its terms presented in another order.
    ///
    /// **⇒ THE TERMS ARE THE SAME SET.** = = The scorer weighs a term by
    /// its rarity and counts a term's occurrences, = = and both are keyed
    /// by the term itself, = = so the set of terms decides the answer and
    /// their order does not. A space joins them because a space is a term
    /// boundary, = = so the terms come back exactly as they went in.
    private static func reordered(query: String, by shift: Int) -> String? {
        let tokens = TokenOverlapRanking.tokenize(query)
        guard tokens.count > 1 else { return nil }
        return Array(tokens[shift...] + tokens[..<shift]).joined(separator: " ")
    }

    /// The fixture's questions and the order each one answers in.
    private static func measuredOrders() -> [(text: String, order: [String])] {
        let library = Self.corpus()
        return RetrievalQualityCorpus.queries.map { query in
            (query.text, Self.order(of: query.text, library: library))
        }
    }

    // MARK: - The number the terms add up to

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

    // MARK: - The order the terms are visited in

    @Test("the ranking's order does not depend on the order the terms are visited in")
    func orderIsIndependentOfTheVisitOrder() {
        let library = Self.corpus()
        for query in RetrievalQualityCorpus.queries {
            let baseline = Self.order(of: query.text, library: library)
            #expect(!baseline.isEmpty, "the fixture's question should answer with something")
            let tokens = TokenOverlapRanking.tokenize(query.text)
            guard tokens.count > 1 else { continue }
            for shift in 1 ..< tokens.count {
                guard let reordered = Self.reordered(query: query.text, by: shift) else { continue }
                let other = Self.order(of: reordered, library: library)
                #expect(
                    other == baseline,
                    """
                    the same terms in another order answered differently \
                    (question: \(query.text), shift: \(shift))
                    """
                )
            }
        }
    }

    // MARK: - The order across two processes

    /// The marker the probe prints one measured order per line.
    private static let probeMarker = "RANKORDER"

    /// The environment variable that tells the probe to print.
    private static let probeVariable = "WENSHU_RANK_ORDER_PROBE"

    @Test("the ranking's order is the same in another process")
    func orderIsTheSameInAnotherProcess() throws {
        guard let helper = Bundle.main.executablePath,
              helper.hasSuffix("swiftpm-testing-helper"),
              let bundle = Self.bundlePath()
        else {
            // The suite runs under a runner that cannot start a second
            // process of itself; the visit-order measurement above is the
            // same property measured without one.
            print("RANKORDERPROBE skipped: no second-process runner available")
            return
        }

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

        let other = Self.parseProbeOutput(output)
        let mine = Self.measuredOrders()
        #expect(
            other.count == mine.count,
            "the second process should measure every question; it measured \(other.count)"
        )
        for (index, measured) in mine.enumerated() where index < other.count {
            #expect(
                other[index] == measured.order,
                """
                the same question answered in a different order in another process \
                (question: \(measured.text))
                """
            )
        }
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

    /// The probe: it measures the ranking and prints what it measured.
    ///
    /// **⇒ IT MEASURES THE APP'S OWN SEARCH, = = AND NOT A COPY.** = = A
    /// probe that re-declared the ranking would measure itself, = = and
    /// this file's whole claim is about the app's own function.
    @Test("rank order probe")
    func rankOrderProbe() {
        guard ProcessInfo.processInfo.environment[Self.probeVariable] == "1" else {
            return
        }
        for measured in Self.measuredOrders() {
            print("\(Self.probeMarker)\t\(measured.order.joined(separator: "|"))")
        }
    }
}
