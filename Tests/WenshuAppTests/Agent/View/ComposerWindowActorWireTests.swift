//
//  ComposerWindowActorWireTests.swift · Wenshu · v2.9c ticket T30 (boss 2026-09-28 OOB A5 follow-up)
//
//  Structural tests for the v2.9c ComposerWindow NoteComposer
//  wire-up (= boss 2026-09-28 OOB inventory follow-up A5 = 'ComposerWindow
//  form shell 存在 = 没真的调用 NoteComposer'; = form was
//  input-only with no Run button).
//
//  Per boss 2026-09-28 OOB: '重复的应该合并'; = NoteComposer is
//  the canonical rename / merge / split surface (= the view
//  never modifies content directly). v2.9c wires the Run
//  button to call NoteComposer per the selected operation.
//
//  Three source-level tests pin the canonical shape:
//
//    1. testComposerWindowRunButton —
//       ComposerWindow.form has a Run button (= i18n key
//       composer.run).
//
//    2. testComposerWindowCallsNoteComposer —
//       ComposerWindow.runOperation calls NoteComposer.rename /
//       .merge / .split (= the view delegates all composer
//       logic to the canonical NoteComposer enum).
//
//    3. testComposerWindowNoteComposerMergeSignature —
//       The merge call uses the canonical
//       NoteComposer.merge(targetName:sourceContents:) signature
//       (= NOT a custom signature; = SSOT on NoteComposer).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v2.8b SecondaryWindowsTests + v2.9b
//  CanvasWindowActorWireTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("ComposerWindow NoteComposer wire-up (v2.9c — boss 2026-09-28 OOB A5 follow-up)")
struct ComposerWindowActorWireTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("ComposerWindow has Run button (= i18n key composer.run)")
    func testComposerWindowRunButton() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/ComposerWindow.swift"), encoding: .utf8)
        #expect(source.contains("composer.run"),
                "ComposerWindow.form must include a Run action (= boss A5 follow-up = '没真的调用 NoteComposer')")
    }

    @Test("ComposerWindow.runOperation calls NoteComposer.rename / merge / split")
    func testComposerWindowCallsNoteComposer() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/ComposerWindow.swift"), encoding: .utf8)
        let callsRename = source.contains("NoteComposer.rename")
        let callsMerge = source.contains("NoteComposer.merge")
        let callsSplit = source.contains("NoteComposer.split")
        #expect(callsRename && callsMerge && callsSplit,
                "ComposerWindow.runOperation must call NoteComposer.rename / merge / split (= SSOT on NoteComposer)")
    }

    @Test("NoteComposer.merge signature is the canonical (targetName:sourceContents:) shape")
    func testComposerWindowNoteComposerMergeSignature() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/ComposerWindow.swift"), encoding: .utf8)
        let usesCanonicalSignature = source.contains("NoteComposer.merge(\n                targetName:") ||
                                     source.contains("NoteComposer.merge(") && source.contains("targetName:") && source.contains("sourceContents:")
        #expect(usesCanonicalSignature,
                "ComposerWindow.runOperation must call NoteComposer.merge with the canonical (targetName:sourceContents:) parameter labels")
    }
}