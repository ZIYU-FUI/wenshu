// ReferenceEntityExtractorTests.swift · Wenshu (文枢) · v0.28
//
// Hermed-port validation tests for ReferenceEntityExtractor.swift
// (= wenshu M5 ticket 12 = batch 3 first ticket).
//
// Each test mirrors a hermes `_extract_entities` behavior contract:
// 1. Multi-word capitalized phrases extracted first
// 2. Double-quoted terms
// 3. Single-quoted terms
// 4. AKA patterns -> both sides yielded
// 5. Dedup by case-insensitive lowercased comparison, first-seen order

import Testing
@testable import WenshuApp

@Suite("ReferenceEntityExtractor (hermes verbatim port — M5 ticket 12)")
struct ReferenceEntityExtractorTests {

    let extractor = ReferenceEntityExtractor()

    @Test("rule 1: multi-word capitalized phrase 'John Doe'")
    func capitalized() {
        let result = extractor.extract("Talk to John Doe about the project.")
        #expect(result == ["John Doe"])
    }

    @Test("rule 2: double-quoted term 'Python'")
    func doubleQuoted() {
        let result = extractor.extract("He uses \"Python\" for scripting.")
        #expect(result == ["Python"])
    }

    @Test("rule 3: single-quoted term 'pytest'")
    func singleQuoted() {
        let result = extractor.extract("Tests are run via 'pytest'.")
        #expect(result == ["pytest"])
    }

    @Test("rule 4: AKA pattern yields both sides (= hermes verbatim bug reproduced)")
    func aka() {
        // Hermes verbatim regex (\w+(?:\s+\w+)*\s+(?:aka|also known as)\s+\w+(?:\s+\w+)*)
        // is over-greedy and matches ('Guido', 'BDFL created Python').
        // wenshu port follows hermes behavior verbatim (= NOT fixing the
        // upstream regex per Q125 verbatim-port protocol). The 'created
        // Python' suffix is a hermes-side false positive; wenshu callers
        // should treat this as a known limitation and post-filter if needed.
        let result = extractor.extract("Guido aka BDFL created Python.")
        #expect(result == ["Guido", "BDFL created Python"])
    }

    @Test("rule 4 variant: 'also known as' (case-insensitive, hermes verbatim)")
    func alsoKnownAs() {
        // Hermes Python regex (without re.UNICODE flag) treats '\w' as
        // ASCII-only (= matches [A-Za-z0-9_]). The literal 'also known as'
        // pattern requires ASCII word boundaries on both sides. wenshu Swift
        // NSRegularExpression behaves identically (= both use ASCII-default
        // '\w'). Verified empirically with the hermes source code:
        // re.compile(r'(\w+(?:\s+\w+)*)\s+(?:aka|also known as)\s+(\w+(?:\s+\w+)*)',
        //              re.IGNORECASE)
        // -> NO MATCH for any test input that doesn't include the literal
        //    'also known as' string with ASCII words on both sides AND
        //    matches the greedy \w+ capture pattern. This test confirms
        //    the empty result (= wenshu port faithfully reproduces hermes
        //    behavior, including the 'also known as' variant's limitations).
        let result = extractor.extract("Python, also known as the language of choice.")
        #expect(result == [])
    }

    @Test("dedup: 'John Doe' and 'john doe' appear once (case-insensitive)")
    func dedup() {
        let result = extractor.extract("John Doe is here. john doe arrived.")
        #expect(result == ["John Doe"])
    }

    @Test("dedup: preserves first-seen order across rules")
    func firstSeenOrder() {
        let result = extractor.extract("'John Doe' and \"John Doe\" and John Smith.")
        // Both single + double quote matches surface as "John Doe" first,
        // then the rule-1 capitalized match for "John Smith" appears last.
        #expect(result == ["John Doe", "John Smith"])
    }

    @Test("multiple capitalized phrases in one text")
    func multipleCapitalized() {
        let result = extractor.extract("Mary Jane met John Smith at Cafe Tokyo.")
        #expect(result == ["Mary Jane", "John Smith", "Cafe Tokyo"])
    }

    @Test("empty input -> empty output")
    func empty() {
        #expect(extractor.extract("") == [])
    }

    @Test("no candidates -> empty output")
    func noCandidates() {
        #expect(extractor.extract("just lowercase text without entities.") == [])
    }

    @Test("whitespace-only candidate is dropped (= hermes `.strip()` semantics)")
    func whitespaceTrimmed() {
        // A quoted empty string should not produce an empty entity.
        let result = extractor.extract("\"\" is empty.")
        #expect(result == [])
    }

    @Test("complex combined: all four rules fire in one text")
    func combined() {
        // Hermes verbatim behavior (= includes the AKA over-greedy bug).
        // Walk-through:
        // - Rule 1 (capitalized): "Mary Jane", "John Smith", "Cafe Tokyo"
        // - Rule 2 (double-quoted): "Cafe Tokyo" (already in seen from rule 1)
        // - Rule 3 (single-quoted): no matches in this text
        // - Rule 4 (AKA over-greedy): matches
        //   ('She uses Python and Guido', 'BDFL designed it')
        //   because rule 4 has higher regex rank than rule 1's greedy match.
        //   Python does not match rule 1 (lowercase 'P' starts the sentence,
        //   not [A-Z][a-z]+) so it would be AKA group 1.
        let result = extractor.extract(
            "Mary Jane met John Smith at \"Cafe Tokyo\". She uses Python and Guido aka BDFL designed it."
        )
        // Forward-fix: ticket M5-15 will post-filter AKA over-greedy
        // trailing words (= "designed it", "and Guido" etc.) before
        // persisting to reference-library/entities/.
        #expect(result == [
            "Mary Jane",
            "John Smith",
            "Cafe Tokyo",
            "She uses Python and Guido",
            "BDFL designed it",
        ])
    }
}