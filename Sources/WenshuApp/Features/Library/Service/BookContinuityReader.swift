//
//  BookContinuityReader.swift
//
//  A book, read and checked, and the report it produces.
//
//  Why: the continuity kernel and the thread-chain kernel both
//  produce findings, and nothing in the tree ever ran them over a
//  book. The kernel has been proven against arguments a test wrote by
//  hand; = = and the context bundle carries two arrays for the
//  report (= `worldContext` and `foreshadowContext`) that are empty
//  on every turn.
//
//  So this is the layer that reads a book through the stores that
//  already own it, runs the two kernels over what it read, and hands
//  the report to the turn.
//
//  It reads through the existing stores, = = so no second persistence
//  system appears and the `.ws` format does not change. It writes
//  nothing.
//
//  The rules the consistency kernel weighs are the caller's, = = and
//  this reader ships the book's own default set: = the world's
//  documents say what they say, = = and a book whose rules have not
//  been written down yet reports no conflict, = = which is the honest
//  state of that book.
//

import Foundation
import WenshuAgent
import WenshuData

/// A book, read and checked.
struct BookContinuityReader {
    /// The book's directory (= the canonical reference path).
    let bookDirectory: URL

    /// The rules this book's own claims call for.
    ///
    /// A book does not name its rules in a shape a machine can read: = =
    /// measured over a real book's world documents, = = the properties
    /// its claims state are 117 different names the author wrote, = =
    /// and no fixed list of them can be right for every book. = = So the
    /// app does not guess them: = = it counts the properties a book
    /// states more than once about one subject, = = and each of those
    /// gets the rule that weighs one value at one moment. = = A book
    /// that states every property once reports no conflict, = = and
    /// that is the honest state of it.
    ///
    /// The property's own name is the book's, = = so it is carried at
    /// run time (= = the file itself stays English-only).
    static func rules(for facts: [StoryFact]) -> [StoryRule] {
        var repeats: [String: Int] = [:]
        var pairs: Set<String> = []
        for fact in facts {
            let pair = "\(fact.subject)\u{0000}\(fact.attribute)"
            let seen = repeats[pair, default: 0]
            repeats[pair] = seen + 1
            if seen > 0 {
                pairs.insert(fact.attribute)
            }
        }
        return pairs.sorted().map { attribute in
            StoryRule(
                id: "one-value-per-moment:\(attribute)",
                severity: .blocking,
                summary: "One value at a moment: \(attribute) holds a single value at one moment.",
                check: .oneValuePerMoment(attribute: attribute)
            )
        }
    }

    /// The report the book produces.
    ///
    /// The book's chapters go to the thread-chain kernel, = = and the
    /// book's documents go to the claim reader and then to the
    /// consistency kernel. A book that cannot be read produces an empty
    /// report, = = because a report about a book nobody can read is a
    /// report about nothing.
    func report() -> ContinuityReport {
        ContinuityReport(
            worldConflicts: worldConflicts(),
            brokenThreads: brokenThreads()
        )
    }

    // MARK: - The world's conflicts

    /// The conflicts the book's own claims produce.
    private func worldConflicts() -> [ContinuityReport.WorldConflict] {
        let facts = locatedFacts()
        guard !facts.isEmpty else { return [] }
        let rules = Self.rules(for: facts)
        guard !rules.isEmpty else { return [] }
        return StoryConsistency.findings(facts: facts, rules: rules).map { finding in
            ContinuityReport.WorldConflict(
                subject: finding.subject,
                attribute: finding.attribute,
                severity: finding.severity == .blocking ? "blocking" : "warning",
                rule: finding.summary,
                claimIDs: finding.factIDs
            )
        }
    }

    /// The book's claims, each one naming the document it came from.
    ///
    /// The claim reader names a claim after its subject and the line it
    /// came from), = = and a book may hold two documents about one
    /// subject (= a world's sheet and a character's sheet, = = both
    /// named after the same person). = = Their claims would then share
    /// a name, = = and a report that points at a name two files hold is
    /// a report the writer cannot locate. = = So the document's own
    /// path is folded into the claim's name here, = = and the subject
    /// stays what the document is about, = = so the kernel still weighs
    /// two documents about one subject together.
    private func locatedFacts() -> [StoryFact] {
        var located: [StoryFact] = []
        for (document, path) in documents() {
            for fact in StoryClaimReader.claims(in: document) {
                located.append(StoryFact(
                    id: "\(path)#\(Self.line(of: fact))",
                    subject: fact.subject,
                    attribute: fact.attribute,
                    value: fact.value,
                    grade: fact.grade,
                    chapter: fact.chapter
                ))
            }
        }
        return located
    }

    /// The line a claim came from.
    ///
    /// The claim reader's own name ends with the line, = = so the line
    /// is read back out of the name rather than guessed.
    private static func line(of fact: StoryFact) -> String {
        guard let hash = fact.id.lastIndex(of: "#") else { return fact.id }
        return String(fact.id[fact.id.index(after: hash)...])
    }

    // MARK: - The broken threads

    /// The breaks the book's own chapters produce.
    private func brokenThreads() -> [ContinuityReport.BrokenThread] {
        ForeshadowChain.scan(chapters: chapters()).map { break_ in
            ContinuityReport.BrokenThread(
                chapter: break_.chapter,
                kind: Self.kindName(of: break_),
                detail: Self.detail(of: break_)
            )
        }
    }

    /// The name of a break's shape.
    private static func kindName(of item: ForeshadowBreak) -> String {
        switch item {
        case .payoffBeforePlant: return "payoff-before-plant"
        case .payoffNamesChapterThatPlantsNothing: return "payoff-names-nothing-planted"
        case .payoffNamesChapterThatDoesNotExist: return "payoff-names-a-missing-chapter"
        case .plantNeverPaidOff: return "plant-never-paid-off"
        }
    }

    /// One break in one line.
    ///
    /// The line says what the writer has to do about it, = = and the
    /// chapter it happens in, = = because a break the writer cannot
    /// locate is a break the writer cannot fix.
    private static func detail(of item: ForeshadowBreak) -> String {
        switch item {
        case let .payoffBeforePlant(payoffChapter, plantChapter):
            return "a thread is paid off in chapter \(payoffChapter) before chapter \(plantChapter) plants it"
        case let .payoffNamesChapterThatPlantsNothing(payoffChapter, namedChapter):
            return "chapter \(payoffChapter) pays off a thread from chapter \(namedChapter), which plants nothing"
        case let .payoffNamesChapterThatDoesNotExist(payoffChapter, namedChapter):
            return "chapter \(payoffChapter) pays off a thread from chapter \(namedChapter), which the book does not have"
        case let .plantNeverPaidOff(plantChapter):
            return "chapter \(plantChapter) plants a thread that no chapter pays off"
        }
    }

    // MARK: - What the book says

    /// The book's chapters, as the thread-chain kernel reads them.
    ///
    /// The chapter's number is the book's own: = the position it holds
    /// in the book, = = one-based, = = which is the number the book's
    /// own marker lines name when they say which chapter a thread came
    /// from.
    private func chapters() -> [ForeshadowChapter] {
        let chaptersDirectory = bookDirectory.appendingPathComponent("chapters", isDirectory: true)
        let indexURL = bookDirectory.appendingPathComponent("chapters.json")
        guard let documents = try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        ) else { return [] }
        return documents.enumerated().compactMap { offset, document in
            guard let body = FileSystemChapterStore.loadChapterBodyFromFileSystem(
                id: document.id,
                chaptersDirectory: chaptersDirectory
            ) else { return nil }
            return ForeshadowChapter(number: offset + 1, body: body)
        }
    }

    /// The book's own documents, as the claim reader reads them.
    ///
    /// A document is a file under the book's `world/` and `characters/`
    /// folders, = = and its title is its name. A document that states
    /// no claim states nothing, = = so the reader's silence is the
    /// book's silence.
    private func documents() -> [(StoryDocument, String)] {
        var read: [(StoryDocument, String)] = []
        for folder in ["world", "characters"] {
            let directory = bookDirectory.appendingPathComponent(folder, isDirectory: true)
            guard let names = try? FileManager.default.contentsOfDirectory(
                atPath: directory.path
            ) else { continue }
            for name in names.sorted() where name.hasSuffix(".md") {
                let url = directory.appendingPathComponent(name)
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let title = String(name.dropLast(".md".count))
                read.append((
                    StoryDocument(title: title, text: text),
                    "\(folder)/\(name)"
                ))
            }
        }
        return read
    }
}
