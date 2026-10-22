#!/usr/bin/env python3
"""test_ticket_tier.py — the difficulty tier's own test suite.

Every case runs on a FIXTURE body written to a temporary file, so the tests
stay valid when the real card bodies change.

The cases are the things the naive classifier got wrong, each one measured on
board wenshu-par:

  1. a card that touches ONE file is T1, and its cap must be 15m.
  2. a card naming a persistence surface is T3 whatever its file count.
  3. a card naming a package boundary is T3.
  4. a card that inlines the code to write is T3, even with one file.
  5. a cited rule ("AGENTS.md §7.3") is not a file the card writes.
  6. a card naming a runtime surface (AppKit, AX census) is not T1.
  7. a card demanding a red-baseline comparison is not a T1 gate.
  8. a T1 card that asks for the whole suite is an error, not a pass.
  9. the tier never reads the body's LENGTH as difficulty, and never reads
     the gate the body asks for (both would be circular).
 10. the tier of a body that changes NOTHING is still decided by the work,
     not by the absence of a signal.

Run:  python3 Tools/wenshu-devtool/tests/test_ticket_tier.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "ticket_tier.py"

FAILURES: list[str] = []


def load_tool():
    """Import ticket_tier.py as a module, whatever its directory is."""
    spec = importlib.util.spec_from_file_location("ticket_tier", TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(name: str, got, want) -> None:
    """Assert one case, and record the failure instead of raising."""
    if got == want:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}\n          got:  {got!r}\n          want: {want!r}")
        FAILURES.append(name)


def tier_of_body(tool, body: str) -> str:
    """The tier a body earns, via a real file, so the file path is exercised."""
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as handle:
        handle.write(body)
        path = handle.name
    try:
        card = tool.card_from_file(path)
        return tool.tier_of(card["body"])[0]
    finally:
        Path(path).unlink(missing_ok=True)


ONE_FILE = """## GOAL

The chat bubble must not wear the error colour.

## WHAT TO BUILD

Edit `Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift` so the
bubble keeps its own tint.

## GATES

`swift test --filter ChatMessageViewTests` exits 0.
"""

TWO_FILES = """## GOAL

Move the app facade out of the red-box directory.

## WHAT TO BUILD

- `Sources/WenshuApp/App/WenshuAppDelegate.swift`
- `Sources/WenshuApp/Shared/UI/LibraryRootView.swift`

## GATES

`swift test --filter LibraryRootViewTests` exits 0.
"""

PERSISTENCE = """## GOAL

Add the new model for a saved card cover.

## WHAT TO BUILD

- `Sources/WenshuApp/Persistence/Models/WSCardCover.swift`

The model is registered in `Schema([...])` inside `Persistence/Container.swift`,
and the store is opened with `ModelContainer`.

## GATES

`swift test --filter WSCardCoverTests` exits 0.
"""

PACKAGE = """## GOAL

Move the tool contract into the agent package.

## WHAT TO BUILD

- `Sources/WenshuAgent/Sources/WenshuAgent/Public/WenshuAgent.swift`

`Package.swift` changes, and the module boundary moves with it.

## GATES

`swift test --filter WenshuAgentTests` exits 0.
"""

INLINED_CODE = """## GOAL

Split the export modifier by export kind.

## WHAT TO BUILD

Edit `Sources/WenshuApp/Features/Editor/View/ExportSheet.swift`:

```swift
protocol ExportModifierProtocol {
    func exportRows() -> [ExportRow]
    func fileName(for sheet: ExportSheet) -> String
}

struct MarkdownExportModifier: ExportModifierProtocol {
    let sheet: ExportSheet
    let options: MarkdownExportOptions

    func exportRows() -> [ExportRow] {
        sheet.rows.map { row in
            ExportRow(
                identifier: row.identifier,
                title: row.title,
                body: MarkdownExportRenderer.render(row, options: options),
                attachments: row.attachments
            )
        }
    }

    func fileName(for sheet: ExportSheet) -> String {
        "\\(sheet.fileNameStem).md"
    }
}

struct PDFExportModifier: ExportModifierProtocol {
    let sheet: ExportSheet
    let pageSize: NSSize
    let margin: NSEdgeInsets

    func exportRows() -> [ExportRow] {
        sheet.rows.map { row in
            ExportRow(
                identifier: row.identifier,
                title: row.title,
                body: PDFExportRenderer.render(row, pageSize: pageSize, margin: margin),
                attachments: row.attachments
            )
        }
    }

    func fileName(for sheet: ExportSheet) -> String {
        "\\(sheet.fileNameStem).pdf"
    }
}

struct PlainTextExportModifier: ExportModifierProtocol {
    let sheet: ExportSheet
    let lineWidth: Int

    func exportRows() -> [ExportRow] {
        sheet.rows.map { row in
            ExportRow(
                identifier: row.identifier,
                title: row.title,
                body: PlainTextExportRenderer.render(row, lineWidth: lineWidth),
                attachments: row.attachments
            )
        }
    }

    func fileName(for sheet: ExportSheet) -> String {
        "\\(sheet.fileNameStem).txt"
    }
}

struct JSONExportModifier: ExportModifierProtocol {
    let sheet: ExportSheet
    let includeMetadata: Bool

    func exportRows() -> [ExportRow] {
        sheet.rows.map { row in
            ExportRow(
                identifier: row.identifier,
                title: row.title,
                body: JSONExportRenderer.render(row, includeMetadata: includeMetadata),
                attachments: row.attachments
            )
        }
    }

    func fileName(for sheet: ExportSheet) -> String {
        "\\(sheet.fileNameStem).json"
    }
}

struct RTFExportModifier: ExportModifierProtocol {
    let sheet: ExportSheet
    let defaultFont: NSFont

    func exportRows() -> [ExportRow] {
        sheet.rows.map { row in
            ExportRow(
                identifier: row.identifier,
                title: row.title,
                body: RTFExportRenderer.render(row, defaultFont: defaultFont),
                attachments: row.attachments
            )
        }
    }

    func fileName(for sheet: ExportSheet) -> String {
        "\\(sheet.fileNameStem).rtf"
    }
}

struct HTMLExportModifier: ExportModifierProtocol {
    let sheet: ExportSheet
    let styleSheet: String

    func exportRows() -> [ExportRow] {
        sheet.rows.map { row in
            ExportRow(
                identifier: row.identifier,
                title: row.title,
                body: HTMLExportRenderer.render(row, styleSheet: styleSheet),
                attachments: row.attachments
            )
        }
    }

    func fileName(for sheet: ExportSheet) -> String {
        "\\(sheet.fileNameStem).html"
    }
}
```

## GATES

`swift test --filter ExportSheetTests` exits 0.
"""

CITED_ONLY = """## GOAL

Re-point the chapter-focus-lock gate.

Follow `AGENTS.md` §7.3 and the rule in `Tests/WenshuAppTests/Shared/State/ChapterFocusLockTests.swift` §1.2.

## WHAT TO BUILD

Edit `Sources/WenshuApp/Features/Editor/View/EditorView.swift`.

## GATES

`swift test --filter ChapterFocusLockTests` exits 0.
"""

RUNTIME_SURFACE = """## GOAL

Dragging the window narrow must not kill the window.

## WHAT TO BUILD

- `Sources/WenshuApp/Shared/UI/LibraryRootView.swift`
- `Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift`

The crash is read from the AppKit unified log with `log show --predicate`, and
the fix needs a screenshot of the narrow window.

## GATES

`swift test --filter EditorChatNSControllerTests` exits 0.
"""

BASELINE_DEMAND = """## GOAL

Restore the right-hand inspector column.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Editor/View/InspectorView.swift`

## GATES

`swift test` shows no NEW failing test versus the baseline.
"""

WHOLE_SUITE_T1 = """## GOAL

Delete the keys no screen asks for.

## WHAT TO BUILD

- `Sources/WenshuApp/Resources/Localizable.xcstrings`

## GATES

`swift test` exits 0.
"""

LONG_BODY_T1_WORK = """## GOAL

Fix the one source file.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Cover/Service/CoverImageGenerator.swift`

""" + ("The worker should keep the existing behaviour in every other file.\n" * 200)

# A card that FORBIDS a file is not doing that file's work. Measured on board
# wenshu-par: 15 of 47 cards name Package.swift and 13 of them do it to
# forbid it, and 20 more name the string catalog. A tier that reads the whole
# body called 24 cards package-boundary work, so the tier reads the SECTIONS.
FORBIDDEN_PACKAGE = """## GOAL

Show the stored cover picture on the card.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Cover/View/CoverView.swift`

## MUST NOT CHANGE

- `Package.swift` — no new dependency.

## GATES

`swift test --filter CoverViewTests` exits 0.
"""

FORBIDDEN_CATALOG = """## GOAL

Delete the keys no screen asks for.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Cover/Service/CoverImageGenerator.swift`

## MUST NOT CHANGE

- `Sources/WenshuApp/Resources/Localizable.xcstrings` — no new strings.

## GATES

`swift test --filter CoverImageGeneratorTests` exits 0.
"""

WRITES_PACKAGE = """## GOAL

Move the tool contract into the agent package.

## WHAT TO BUILD

- `Sources/WenshuAgent/Sources/WenshuAgent/Public/WenshuAgent.swift`
- `Package.swift` — the target list changes with it.

## GATES

`swift test --filter WenshuAgentTests` exits 0.
"""


def main() -> int:
    tool = load_tool()

    print("ticket_tier: the difficulty tier classifier\n")

    # 1. A one-file card is T1, and T1's cap is 15m.
    check("one file = T1", tier_of_body(tool, ONE_FILE), "T1")
    check("T1 cap = 900s", tool.TIERS["T1"]["runtime"], 900)
    check("T1 cap text = 15m", tool.TIERS["T1"]["runtime_text"], "15m")
    # 2. Persistence is deep whatever the file count.
    check("persistence = T3", tier_of_body(tool, PERSISTENCE), "T3")

    # 3. A package boundary is deep.
    check("package boundary = T3", tier_of_body(tool, PACKAGE), "T3")

    # 4. Inlined code is deep even with one file.
    check("inlined code = T3", tier_of_body(tool, INLINED_CODE), "T3")

    # 5. A cited rule is not a file the card writes.
    check(
        "cited rule is not a written file",
        sorted(tool.work_scope(CITED_ONLY)[0]),
        ["Sources/WenshuApp/Features/Editor/View/EditorView.swift"],
    )

    # 6. A runtime surface is not T1.
    check("runtime surface = T3", tier_of_body(tool, RUNTIME_SURFACE), "T3")

    # 7. A baseline demand is an error on a T1 card.
    baseline_card = {
        "id": "t_test",
        "title": "[T1] restore the inspector",
        "body": BASELINE_DEMAND,
        "max_runtime_seconds": 900,
    }
    findings = tool.find_errors(baseline_card)
    check(
        "T1 demanding a baseline compare is an error",
        any("red-baseline" in f for f in findings),
        True,
    )

    # 8. A T1 card asking for the whole suite is an error too.
    whole_card = {
        "id": "t_test",
        "title": "[T1] delete the dead keys",
        "body": WHOLE_SUITE_T1,
        "max_runtime_seconds": 900,
    }
    findings = tool.find_errors(whole_card)
    check(
        "T1 asking for the whole suite is an error",
        any("whole suite" in f for f in findings),
        True,
    )

    # 9. The tier is not a function of the body's length, and not a function
    #    of the gate the body asks for. Both would be circular: the tier
    #    changes the cap and the gate.
    long_card = {
        "id": "t_test",
        "title": "[T1] fix the cover generator",
        "body": LONG_BODY_T1_WORK,
        "max_runtime_seconds": 900,
    }
    check(
        "a long body does not raise the tier",
        tool.tier_of(LONG_BODY_T1_WORK)[0],
        "T1",
    )
    # Same work, but the body asks for the whole suite: the tier is unchanged,
    # and the mismatch is reported as a finding instead.
    noisy = ONE_FILE.replace(
        "`swift test --filter ChatMessageViewTests` exits 0.",
        "`swift test` exits 0.",
    )
    check("the gate does not raise the tier", tool.tier_of(noisy)[0], "T1")
    check(
        "the gate mismatch is reported",
        any("whole suite" in f for f in tool.find_errors(
            {"id": "t", "title": "[T1] x", "body": noisy, "max_runtime_seconds": 900}
        )),
        True,
    )

    # 10. Two files with no deep signal land in T2, the default.
    check("two files = T2", tier_of_body(tool, TWO_FILES), "T2")

    # 11. The title tag and the body must agree, and the cap must match.
    good = {
        "id": "t_ok",
        "title": "[T1] one file",
        "body": ONE_FILE,
        "max_runtime_seconds": 900,
    }
    check("a consistent card has no findings", tool.find_errors(good), [])
    bad_title = dict(good, title="[T3] one file")
    check(
        "a wrong title tag is an error",
        any("title says T3" in f for f in tool.find_errors(bad_title)),
        True,
    )
    bad_cap = dict(good, max_runtime_seconds=1800)
    check(
        "a wrong cap is an error",
        any("runtime cap" in f for f in tool.find_errors(bad_cap)),
        True,
    )
    missing_tag = dict(good, title="one file")
    check(
        "a missing title tag is an error",
        any("no tier tag" in f for f in tool.find_errors(missing_tag)),
        True,
    )

    # 12. Every tier's cap must cover the longest successful run measured in
    #     that tier, or the cap kills work that would have finished.
    measured_max = {"T1": 10.5, "T2": 26.2, "T3": 39.2}
    for tier, longest in measured_max.items():
        check(
            f"{tier} cap covers its measured longest successful run",
            tool.TIERS[tier]["runtime"] / 60 >= longest,
            True,
        )

    # 13. The retry budget must exceed the longest CONSECUTIVE failure streak
    #     the board has actually produced in that tier, or the breaker blocks
    #     a card that would have recovered.
    measured_streak = {"T1": 1, "T2": 2, "T3": 3}
    for tier, streak in measured_streak.items():
        check(
            f"{tier} retry budget exceeds its measured failure streak",
            tool.TIERS[tier]["retries"] > streak,
            True,
        )

    # 14. The gate width is read from the body and reported, and it is the
    #     lever that carries the time: a body asking for the whole suite or a
    #     red-baseline comparison is "wide".
    check("a filtered suite is a narrow gate", tool.gate_width(ONE_FILE), "narrow")
    check("a baseline demand is a wide gate", tool.gate_width(BASELINE_DEMAND), "wide")
    check("a whole-suite demand is a wide gate", tool.gate_width(WHOLE_SUITE_T1), "wide")
    check(
        "a body with no test command has an unstated gate",
        tool.gate_width("## GOAL\n\nDo the thing.\n"),
        "unstated",
    )

    # 15. A T2 card that demands the wide gate gets a note, not a hard error:
    #     the tier permits the wide gate, it only prices it.
    t2_wide = dict(good)
    t2_wide["body"] = TWO_FILES.replace(
        "`swift test --filter LibraryRootViewTests` exits 0.",
        "`swift test` shows no NEW failing test versus the baseline.",
    )
    t2_wide["title"] = "[T2] two files"
    t2_wide["max_runtime_seconds"] = 1800
    check(
        "a T2 wide gate is noted, not rejected",
        any("red-baseline" in f for f in tool.find_errors(t2_wide)),
        True,
    )
    check(
        "a T2 wide gate is not an error",
        any(f.startswith("title") or f.startswith("runtime") for f in tool.find_errors(t2_wide)),
        False,
    )

    # 16. A card that FORBIDS a file is not doing that file's work. This is
    #     the measured false positive: 13 of the 15 cards that name
    #     Package.swift do it to forbid it, and a tier that read the whole
    #     body called 24 cards package-boundary work.
    check(
        "a forbidden Package.swift is not a package boundary",
        tool.signals(FORBIDDEN_PACKAGE)["package_boundary"],
        False,
    )
    check(
        "a forbidden Package.swift is a forbidden file",
        "Package.swift" in tool.work_scope(FORBIDDEN_PACKAGE)[1],
        True,
    )
    check(
        "a forbidden catalog is not a catalog rewrite",
        tool.signals(FORBIDDEN_CATALOG)["catalog"],
        False,
    )
    check(
        "a card that WRITES Package.swift is a package boundary",
        tool.signals(WRITES_PACKAGE)["package_boundary"],
        True,
    )
    check("a card that writes Package.swift = T3", tier_of_body(tool, WRITES_PACKAGE), "T3")
    check(
        "a forbidden Package.swift does not force T3",
        tool.tier_of(FORBIDDEN_PACKAGE)[0],
        "T1",
    )

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s)")
        for name in FAILURES:
            print(f"  - {name}")
        return 1
    print("all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
