//
//  StoryConsistencyTests.swift · Wenshu
//
//  The world's claims and rules, and the conflicts between them.
//

import Foundation
import Testing
import WenshuData

@Suite("StoryConsistency (= the world's claims, checked against its rules)")
struct StoryConsistencyTests {
    // MARK: - One value at a time

    @Test("two claims of one attribute at one moment conflict, and the finding names both claims")
    func oneValuePerMomentFindsTheConflict() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", chapter: 3),
        ]
        let rule = StoryRule(
            id: "one-alive",
            severity: .blocking,
            summary: "a character is alive or dead at a moment, never both",
            check: .oneValuePerMoment(attribute: "alive")
        )
        let found = StoryConsistency.findings(facts: facts, rules: [rule])
        #expect(found.count == 1)
        #expect(found.first?.subject == "Zhang")
        #expect(found.first?.severity == .blocking)
        #expect(found.first?.factIDs == ["f1", "f2"])
    }

    @Test("the same attribute at two moments is not a conflict (= a world changes over time)")
    func oneValuePerMomentIgnoresOtherMoments() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", chapter: 9),
        ]
        let rule = StoryRule(
            id: "one-alive",
            severity: .blocking,
            summary: "a character is alive or dead at a moment",
            check: .oneValuePerMoment(attribute: "alive")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).isEmpty)
    }

    @Test("a claim of one subject never conflicts with a claim of another")
    func oneValuePerMomentIsPerSubject() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Wang", attribute: "alive", value: "no", chapter: 3),
        ]
        let rule = StoryRule(
            id: "one-alive",
            severity: .blocking,
            summary: "a character is alive or dead at a moment",
            check: .oneValuePerMoment(attribute: "alive")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).isEmpty)
    }

    @Test("the surrounding space is not part of a value")
    func oneValuePerMomentIgnoresSurroundingSpace() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "  yes  ", chapter: 3),
        ]
        let rule = StoryRule(
            id: "one-alive",
            severity: .blocking,
            summary: "a character is alive or dead at a moment",
            check: .oneValuePerMoment(attribute: "alive")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).isEmpty)
    }

    // MARK: - A value that never changes

    @Test("an attribute that never changes is a conflict when two moments disagree")
    func neverChangesFindsTheConflict() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "born-in", value: "North", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "born-in", value: "West", chapter: 9),
        ]
        let rule = StoryRule(
            id: "fixed-origin",
            severity: .blocking,
            summary: "an origin does not move",
            check: .neverChanges(attribute: "born-in")
        )
        let found = StoryConsistency.findings(facts: facts, rules: [rule])
        #expect(found.count == 1)
        #expect(found.first?.attribute == "born-in")
        #expect(found.first?.factIDs == ["f1", "f2"])
    }

    @Test("an attribute that never changes is no conflict when every moment agrees")
    func neverChangesIgnoresAgreement() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "born-in", value: "North", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "born-in", value: "North", chapter: 9),
        ]
        let rule = StoryRule(
            id: "fixed-origin",
            severity: .blocking,
            summary: "an origin does not move",
            check: .neverChanges(attribute: "born-in")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).isEmpty)
    }

    // MARK: - Two attributes that cannot both hold

    @Test("two attributes that cannot both hold are a conflict at one moment")
    func notTogetherFindsTheConflict() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "dead", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "speaks", value: "yes", chapter: 3),
        ]
        let rule = StoryRule(
            id: "dead-do-not-speak",
            severity: .blocking,
            summary: "the dead do not speak",
            check: .notTogether(first: "dead", second: "speaks")
        )
        let found = StoryConsistency.findings(facts: facts, rules: [rule])
        #expect(found.count == 1)
        #expect(found.first?.subject == "Zhang")
        #expect(found.first?.factIDs == ["f1", "f2"])
    }

    @Test("the same two attributes at two moments are no conflict")
    func notTogetherIgnoresOtherMoments() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "dead", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "speaks", value: "yes", chapter: 9),
        ]
        let rule = StoryRule(
            id: "dead-do-not-speak",
            severity: .blocking,
            summary: "the dead do not speak",
            check: .notTogether(first: "dead", second: "speaks")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).isEmpty)
    }

    @Test("the same attribute of two subjects never conflicts with itself")
    func notTogetherIsPerSubject() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "dead", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Wang", attribute: "speaks", value: "yes", chapter: 3),
        ]
        let rule = StoryRule(
            id: "dead-do-not-speak",
            severity: .blocking,
            summary: "the dead do not speak",
            check: .notTogether(first: "dead", second: "speaks")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).isEmpty)
    }

    // MARK: - How firmly a claim is made

    @Test("a claim below the grade a check weighs contradicts nothing")
    func aHintContradictsNothing() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", grade: 0.9, chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", grade: 0.2, chapter: 3),
        ]
        let rule = StoryRule(
            id: "one-alive",
            severity: .blocking,
            summary: "a character is alive or dead at a moment",
            check: .oneValuePerMoment(attribute: "alive")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).isEmpty)
    }

    @Test("a claim at the grade a check weighs is weighed")
    func aStatedClaimIsWeighed() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", grade: 0.5, chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", grade: 0.5, chapter: 3),
        ]
        let rule = StoryRule(
            id: "one-alive",
            severity: .blocking,
            summary: "a character is alive or dead at a moment",
            check: .oneValuePerMoment(attribute: "alive")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).count == 1)
    }

    @Test("the grade a check weighs is the caller's own number")
    func theGradeIsTheCallers() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", grade: 0.2, chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", grade: 0.2, chapter: 3),
        ]
        let rule = StoryRule(
            id: "one-alive",
            severity: .blocking,
            summary: "a character is alive or dead at a moment",
            check: .oneValuePerMoment(attribute: "alive")
        )
        let found = StoryConsistency.findings(facts: facts, rules: [rule], minimumGrade: 0.1)
        #expect(found.count == 1)
    }

    // MARK: - The book's own documents

    @Test("two claims from the book's own documents meet (= they stand beside the chapters)")
    func documentClaimsMeetEachOther() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "born-in", value: "North", chapter: nil),
            StoryFact(id: "f2", subject: "Zhang", attribute: "born-in", value: "West", chapter: nil),
        ]
        let rule = StoryRule(
            id: "one-origin",
            severity: .warning,
            summary: "one origin",
            check: .oneValuePerMoment(attribute: "born-in")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).count == 1)
    }

    @Test("a claim from the book's own documents does not meet a chapter's claim")
    func documentClaimsDoNotMeetChapterClaims() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: nil),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", chapter: 3),
        ]
        let rule = StoryRule(
            id: "one-alive",
            severity: .blocking,
            summary: "a character is alive or dead at a moment",
            check: .oneValuePerMoment(attribute: "alive")
        )
        #expect(StoryConsistency.findings(facts: facts, rules: [rule]).isEmpty)
    }

    // MARK: - The order a report reads in

    @Test("the louder conflict is reported first")
    func theLouderConflictReadsFirst() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", chapter: 3),
            StoryFact(id: "f3", subject: "Wang", attribute: "origin", value: "North", chapter: 3),
            StoryFact(id: "f4", subject: "Wang", attribute: "origin", value: "West", chapter: 3),
        ]
        let rules = [
            StoryRule(
                id: "z-warning",
                severity: .warning,
                summary: "one origin",
                check: .oneValuePerMoment(attribute: "origin")
            ),
            StoryRule(
                id: "a-blocking",
                severity: .blocking,
                summary: "alive or dead",
                check: .oneValuePerMoment(attribute: "alive")
            ),
        ]
        let found = StoryConsistency.findings(facts: facts, rules: rules)
        #expect(found.count == 2)
        #expect(found[0].severity == .blocking)
        #expect(found[1].severity == .warning)
    }

    @Test("two runs over the same world read the same way")
    func theReportIsStable() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", chapter: 3),
            StoryFact(id: "f3", subject: "Wang", attribute: "alive", value: "yes", chapter: 5),
            StoryFact(id: "f4", subject: "Wang", attribute: "alive", value: "no", chapter: 5),
        ]
        let rules = [
            StoryRule(
                id: "one-alive",
                severity: .blocking,
                summary: "alive or dead",
                check: .oneValuePerMoment(attribute: "alive")
            ),
        ]
        let first = StoryConsistency.findings(facts: facts, rules: rules)
        let second = StoryConsistency.findings(facts: facts.reversed(), rules: rules)
        #expect(first == second)
        #expect(first.map(\.subject) == ["Wang", "Zhang"])
    }

    @Test("two rules that share a name still read the same way twice")
    func twoRulesSharingANameStillReadTheSameWayTwice() {
        // Two rules with the same name, the same severity, and the same
        // subject and attribute over the same claims: they differ only
        // in what they say. The report must order them the same way
        // whatever order the rules arrive in.
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", chapter: 3),
        ]
        let rules = [
            StoryRule(
                id: "one-alive",
                severity: .blocking,
                summary: "a character is alive or dead",
                check: .oneValuePerMoment(attribute: "alive")
            ),
            StoryRule(
                id: "one-alive",
                severity: .blocking,
                summary: "a character is alive or dead at a moment",
                check: .oneValuePerMoment(attribute: "alive")
            ),
        ]
        let first = StoryConsistency.findings(facts: facts, rules: rules)
        let second = StoryConsistency.findings(facts: facts, rules: rules.reversed())
        #expect(first == second)
        #expect(first.count == 2)
        #expect(first.map(\.summary) == [
            "a character is alive or dead",
            "a character is alive or dead at a moment",
        ])
    }

    @Test("the report reads the same way whatever order the rules arrive in")
    func theReportIsStableAcrossRuleOrder() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", chapter: 3),
            StoryFact(id: "f3", subject: "Wang", attribute: "origin", value: "North", chapter: 3),
            StoryFact(id: "f4", subject: "Wang", attribute: "origin", value: "West", chapter: 3),
        ]
        let rules = [
            StoryRule(
                id: "one-origin",
                severity: .blocking,
                summary: "one origin",
                check: .oneValuePerMoment(attribute: "origin")
            ),
            StoryRule(
                id: "one-alive",
                severity: .blocking,
                summary: "alive or dead",
                check: .oneValuePerMoment(attribute: "alive")
            ),
        ]
        let first = StoryConsistency.findings(facts: facts, rules: rules)
        let second = StoryConsistency.findings(facts: facts, rules: rules.reversed())
        #expect(first == second)
        #expect(first.map(\.ruleID) == ["one-alive", "one-origin"])
    }

    // MARK: - Nothing to say

    @Test("no claims and no rules produce no conflicts")
    func nothingProducesNothing() {
        #expect(StoryConsistency.findings(facts: [], rules: []).isEmpty)
    }

    @Test("claims without a rule produce no conflicts")
    func claimsWithoutRulesProduceNothing() {
        let facts = [
            StoryFact(id: "f1", subject: "Zhang", attribute: "alive", value: "yes", chapter: 3),
            StoryFact(id: "f2", subject: "Zhang", attribute: "alive", value: "no", chapter: 3),
        ]
        #expect(StoryConsistency.findings(facts: facts, rules: []).isEmpty)
    }
}
