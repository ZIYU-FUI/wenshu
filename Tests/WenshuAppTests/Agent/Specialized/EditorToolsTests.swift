//
//  EditorToolsTests.swift · Wenshu · P1 ticket #10 (PORT-SPECIALIZED-005, 2026-09-04)
//
//  5 round-trip tests for `EditorTransformTools` actor (the
//  Swift port of hermes's `agent/editing/editor_tools.py`).
//
//    1. testAvailableTransforms_returns6Transforms
//    2. testPromptPrefix_expand_containsExpandDirective
//    3. testPromptPrefix_shorten_containsShortenDirective
//    4. testPromptPrefix_shiftTone_formal_containsFormalToneDirective
//    5. testDefaultTone_dramatize_returnsLiterary
//
//  Stateless actor (= no BookStore dependency); tests construct
//  the actor with `EditorTransformTools()` and exercise the
//  public surface straight.
//
//  Acceptance: `--filter "EditorTools"` = 5/5 pass.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("EditorTransformTools (PORT-SPECIALIZED-005)")
struct EditorToolsTests {

    // MARK: - Test 1: available transforms

    @Test("availableTransforms returns the 6 paragraph transforms")
    func testAvailableTransforms_returns6Transforms() async {
        let tools = EditorTransformTools()
        let transforms = await tools.availableTransforms()
        #expect(transforms.count == 6, "EditorTransform must expose 6 transforms; got \(transforms.count)")
        // Sanity-check the exact set (= catches accidental case
        // renames or duplicate cases).
        let rawValues = Set(transforms.map(\.rawValue))
        #expect(rawValues.contains("expand"))
        #expect(rawValues.contains("shorten"))
        #expect(rawValues.contains("rephrase"))
        #expect(rawValues.contains("shiftTone"))
        #expect(rawValues.contains("simplify"))
        #expect(rawValues.contains("dramatize"))
    }

    // MARK: - Test 2: expand directive

    @Test("promptPrefix for .expand contains the expand directive")
    func testPromptPrefix_expand_containsExpandDirective() async {
        let tools = EditorTransformTools()
        let prefix = await tools.promptPrefix(for: .expand)
        #expect(!prefix.isEmpty, "expand promptPrefix must be non-empty")
        #expect(prefix.contains("TRANSFORM: expand"), "expand promptPrefix must contain the expand directive token; got \(prefix)")
        // The directive must instruct the model to lengthen.
        #expect(prefix.lowercased().contains("lengthen") || prefix.lowercased().contains("longer"), "expand directive must instruct the LLM to lengthen the paragraph")
    }

    // MARK: - Test 3: shorten directive

    @Test("promptPrefix for .shorten contains the shorten directive")
    func testPromptPrefix_shorten_containsShortenDirective() async {
        let tools = EditorTransformTools()
        let prefix = await tools.promptPrefix(for: .shorten)
        #expect(!prefix.isEmpty, "shorten promptPrefix must be non-empty")
        #expect(prefix.contains("TRANSFORM: shorten"), "shorten promptPrefix must contain the shorten directive token; got \(prefix)")
        // The directive must instruct the model to cut length.
        #expect(prefix.lowercased().contains("condense") || prefix.lowercased().contains("half"), "shorten directive must instruct the LLM to cut length")
    }

    // MARK: - Test 4: shiftTone formal directive

    @Test("promptPrefix for .shiftTone + .formal contains the formal-tone directive")
    func testPromptPrefix_shiftTone_formal_containsFormalToneDirective() async {
        let tools = EditorTransformTools()
        let prefix = await tools.promptPrefix(for: .shiftTone, targetTone: .formal)
        #expect(!prefix.isEmpty, "shiftTone(.formal) promptPrefix must be non-empty")
        #expect(prefix.contains("shift_tone"), "shiftTone promptPrefix must contain the shift_tone directive token; got \(prefix)")
        #expect(prefix.contains("formal"), "shiftTone(.formal) promptPrefix must mention the formal target tone")
        // Defensive: the prefix must NOT bleed in another tone's
        // signature (= catches the bug where switch fall-through
        // returns the same string for every tone).
        #expect(!prefix.contains("casual"), "shiftTone(.formal) promptPrefix must not leak the casual directive")
    }

    // MARK: - Test 5: default tone for dramatize

    @Test("defaultTone for .dramatize returns .literary")
    func testDefaultTone_dramatize_returnsLiterary() async {
        let tools = EditorTransformTools()
        let tone = await tools.defaultTone(for: .dramatize)
        #expect(tone == .literary, "defaultTone for .dramatize must be .literary; got \(String(describing: tone))")
    }
}
