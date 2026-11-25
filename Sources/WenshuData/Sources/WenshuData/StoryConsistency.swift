//
//  StoryConsistency.swift
//
//  The claims a manuscript makes about its own world, the rules that
//  world obeys, and the conflicts between them.
//
//  Why: a long novel states its world as prose, so the facts that hold
//  it (= who is where, who is alive, which law the world follows) can
//  only be read by re-reading the book. A question about a finished
//  book therefore costs a whole book per answer, and two answers to
//  the same question can disagree.
//
//  So the claims are held apart from the sentences, and the check is
//  arithmetic over the claims: the same claims always give the same
//  conflicts, and a conflict names the claims that met.
//
//  Three things the world needs for that, and where each comes from:
//
//  - a claim carries how firmly it is made (= a hint contradicts
//    nothing), so a check can ignore the claims it should not weigh;
//  - a rule carries how loudly a conflict it finds is reported, so a
//    report can be ordered by how much it matters;
//  - two claims are compared at the same MOMENT of the story, because
//    a world changes over time (= a character dies between two
//    chapters, which is not a contradiction) and only a claim about
//    the same moment can contradict another.
//
//  A rule therefore says one of three things about the world's own
//  attributes:
//  - one value at a time (= an identity holds one value at a moment),
//  - a value that never changes (= an origin does not move),
//  - two attributes that cannot both hold (= the dead do not speak).
//
//  This file holds the arithmetic only: it reads claims and rules and
//  returns conflicts. Where the claims come from and who reads the
//  conflicts belong to other layers, and keeping them out is what lets
//  this arithmetic be tested on its own.
//

import Foundation

/// How loudly a conflict is reported.
public enum StorySeverity: Sendable, Equatable, Comparable {
    /// The world cannot be true in both ways at once.
    case blocking
    /// The world is probably wrong, and a reader may notice.
    case warning

    /// The order a report reads in (= the louder kind first).
    public var rank: Int {
        switch self {
        case .blocking: return 0
        case .warning: return 1
        }
    }

    public static func < (lhs: StorySeverity, rhs: StorySeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// One claim the manuscript makes about one subject.
public struct StoryFact: Sendable, Equatable, Hashable {
    /// The claim's own name (= stable across checks, so a report can point at it).
    public let id: String
    /// What the claim is about (= a character, a place, an object).
    public let subject: String
    /// The property the claim is about (= "alive", "carries", "born-in").
    public let attribute: String
    /// The value the claim gives that property.
    public let value: String
    /// How firmly the manuscript makes the claim (0...1).
    /// A claim below a check's threshold is one the manuscript only
    /// hints at, and a hint contradicts nothing.
    public let grade: Double
    /// The chapter the claim belongs to (= the book's own position).
    /// Nil = the claim comes from the book's own documents (= its
    /// setting and its character sheets), which stand beside the
    /// chapters rather than inside them.
    public let chapter: Int?

    public init(
        id: String,
        subject: String,
        attribute: String,
        value: String,
        grade: Double = 1.0,
        chapter: Int? = nil
    ) {
        self.id = id
        self.subject = subject
        self.attribute = attribute
        self.value = value
        self.grade = grade
        self.chapter = chapter
    }
}

/// What a rule asks of the world's claims.
public enum StoryRuleCheck: Sendable, Equatable {
    /// One value at a time: at one moment, a subject's attribute holds
    /// a single value (= an identity holds one name at a moment).
    case oneValuePerMoment(attribute: String)
    /// A value that never changes: the attribute's value is the same at
    /// every moment (= an origin does not move).
    case neverChanges(attribute: String)
    /// Two attributes that cannot both hold at one moment (= the dead
    /// do not speak).
    case notTogether(first: String, second: String)
}

/// One rule the world obeys.
public struct StoryRule: Sendable, Equatable {
    /// The rule's own name (= a report names the rule it broke).
    ///
    /// Two rules in one set should carry different names: a report
    /// names the rule that broke it, and a name two rules share is a
    /// name two findings cannot be told apart by. The report's order
    /// does not depend on it (= the order is total either way), so a
    /// shared name costs the reader a name, not the report a row.
    public let id: String
    /// How loudly a conflict this rule finds is reported.
    public let severity: StorySeverity
    /// What the rule says, in one line (= the report shows it).
    public let summary: String
    /// What the rule asks of the claims.
    public let check: StoryRuleCheck

    public init(id: String, severity: StorySeverity, summary: String, check: StoryRuleCheck) {
        self.id = id
        self.severity = severity
        self.summary = summary
        self.check = check
    }
}

/// One conflict the world's claims and rules produce.
public struct StoryFinding: Sendable, Equatable {
    /// The rule that found the conflict.
    public let ruleID: String
    /// What the conflict is about.
    public let subject: String
    /// The property the conflict is about.
    public let attribute: String
    /// How loudly the conflict is reported.
    public let severity: StorySeverity
    /// The rule's own sentence (= the report shows it).
    public let summary: String
    /// The claims that met (= a report can point at each one).
    public let factIDs: [String]

    public init(
        ruleID: String,
        subject: String,
        attribute: String,
        severity: StorySeverity,
        summary: String,
        factIDs: [String]
    ) {
        self.ruleID = ruleID
        self.subject = subject
        self.attribute = attribute
        self.severity = severity
        self.summary = summary
        self.factIDs = factIDs
    }
}

/// The world's claims and rules, and the conflicts between them.
public struct StoryConsistency: Sendable {
    /// The claims a check weighs (0...1). A claim below it is one the
    /// manuscript only hints at, and a hint contradicts nothing.
    public static let defaultMinimumGrade: Double = 0.5

    /// The conflicts the world's claims and rules produce.
    ///
    /// The claims are compared at the same moment of the story, so a
    /// value that changes between two chapters (= a character dies) is
    /// not a conflict, and only a rule that says a value never changes
    /// finds one there.
    ///
    /// The report's order is **total**: severity, then the rule's name,
    /// the subject, the attribute, the claims that met, and the rule's
    /// own sentence. The last key is what makes it total (= two rules
    /// that share a name and a subject can still be told apart, = = and
    /// a report that reads the same way twice is a report two readers
    /// can share). Swift's own sort does not promise a stable order, so
    /// the order is carried by the keys rather than by the sort.
    public static func findings(
        facts: [StoryFact],
        rules: [StoryRule],
        minimumGrade: Double = defaultMinimumGrade
    ) -> [StoryFinding] {
        let weighed = facts.filter { $0.grade >= minimumGrade }
        var found: [StoryFinding] = []
        for rule in rules {
            switch rule.check {
            case let .oneValuePerMoment(attribute):
                found.append(contentsOf: oneValueFindings(
                    rule: rule, attribute: attribute, facts: weighed
                ))
            case let .neverChanges(attribute):
                found.append(contentsOf: neverChangingFindings(
                    rule: rule, attribute: attribute, facts: weighed
                ))
            case let .notTogether(first, second):
                found.append(contentsOf: togetherFindings(
                    rule: rule, first: first, second: second, facts: weighed
                ))
            }
        }
        return found.sorted(by: readsBefore)
    }

    // MARK: - The three checks

    /// Whether one finding reads before another.
    ///
    /// The keys are total: every field a finding carries takes part,
    /// so two findings that tie on all of them are the same finding and
    /// their order cannot matter.
    private static func readsBefore(_ lhs: StoryFinding, _ rhs: StoryFinding) -> Bool {
        if lhs.severity != rhs.severity {
            return lhs.severity < rhs.severity
        }
        if lhs.ruleID != rhs.ruleID {
            return lhs.ruleID < rhs.ruleID
        }
        if lhs.subject != rhs.subject {
            return lhs.subject < rhs.subject
        }
        if lhs.attribute != rhs.attribute {
            return lhs.attribute < rhs.attribute
        }
        if lhs.factIDs != rhs.factIDs {
            return lhs.factIDs.lexicographicallyPrecedes(rhs.factIDs)
        }
        return lhs.summary < rhs.summary
    }

    /// One value at a moment: at one moment, a subject's attribute
    /// holds more than one value.
    private static func oneValueFindings(
        rule: StoryRule,
        attribute: String,
        facts: [StoryFact]
    ) -> [StoryFinding] {
        var found: [StoryFinding] = []
        for (subject, moment) in moments(of: facts, attribute: attribute) {
            let meeting = facts.filter {
                $0.subject == subject && $0.attribute == attribute && $0.chapter == moment
            }
            guard distinctValues(of: meeting).count > 1 else { continue }
            found.append(StoryFinding(
                ruleID: rule.id,
                subject: subject,
                attribute: attribute,
                severity: rule.severity,
                summary: rule.summary,
                factIDs: meeting.map(\.id).sorted()
            ))
        }
        return found
    }

    /// A value that never changes: the attribute's value differs
    /// between two moments of the story.
    private static func neverChangingFindings(
        rule: StoryRule,
        attribute: String,
        facts: [StoryFact]
    ) -> [StoryFinding] {
        var found: [StoryFinding] = []
        for subject in subjects(of: facts, attribute: attribute) {
            let owned = facts.filter { $0.subject == subject && $0.attribute == attribute }
            guard distinctValues(of: owned).count > 1 else { continue }
            found.append(StoryFinding(
                ruleID: rule.id,
                subject: subject,
                attribute: attribute,
                severity: rule.severity,
                summary: rule.summary,
                factIDs: owned.map(\.id).sorted()
            ))
        }
        return found
    }

    /// Two attributes that cannot both hold at one moment.
    private static func togetherFindings(
        rule: StoryRule,
        first: String,
        second: String,
        facts: [StoryFact]
    ) -> [StoryFinding] {
        let firsts = facts.filter { $0.attribute == first }
        let seconds = facts.filter { $0.attribute == second }
        var found: [StoryFinding] = []
        for (subject, chapter) in moments(of: firsts, attribute: first) {
            let subjectSeconds = seconds.filter { $0.subject == subject && $0.chapter == chapter }
            guard !subjectSeconds.isEmpty else { continue }
            let meeting = firsts.filter { $0.subject == subject && $0.chapter == chapter }
                + subjectSeconds
            found.append(StoryFinding(
                ruleID: rule.id,
                subject: subject,
                attribute: "\(first) + \(second)",
                severity: rule.severity,
                summary: rule.summary,
                factIDs: meeting.map(\.id).sorted()
            ))
        }
        return found
    }

    // MARK: - Helpers

    /// The subjects an attribute is claimed of.
    private static func subjects(of facts: [StoryFact], attribute: String) -> Set<String> {
        Set(facts.filter { $0.attribute == attribute }.map(\.subject))
    }

    /// The subjects and the moments an attribute is claimed at.
    private static func moments(of facts: [StoryFact], attribute: String) -> [(subject: String, chapter: Int?)] {
        var seen: Set<String> = []
        var pairs: [(subject: String, chapter: Int?)] = []
        for fact in facts where fact.attribute == attribute {
            let key = "\(fact.subject)\u{1}\(fact.chapter.map(String.init) ?? "*")"
            guard seen.insert(key).inserted else { continue }
            pairs.append((fact.subject, fact.chapter))
        }
        return pairs.sorted { lhs, rhs in
            if lhs.subject != rhs.subject {
                return lhs.subject < rhs.subject
            }
            return momentKey(lhs.chapter) < momentKey(rhs.chapter)
        }
    }

    /// The order two moments read in (= the book's own documents come
    /// first, because they stand beside the chapters rather than
    /// inside them).
    private static func momentKey(_ chapter: Int?) -> String {
        guard let chapter else { return "*" }
        return String(format: "%09d", chapter)
    }

    /// The values a set of claims gives, compared as the manuscript
    /// wrote them (= the surrounding space is not part of a value).
    private static func distinctValues(of facts: [StoryFact]) -> [String] {
        var seen: Set<String> = []
        for fact in facts {
            seen.insert(fact.value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return seen.sorted()
    }
}
