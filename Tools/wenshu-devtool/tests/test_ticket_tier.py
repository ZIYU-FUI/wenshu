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
 11. the board sweep over a board that cannot be read reports no agreement
     and exits non-zero.

Run:  python3 Tools/wenshu-devtool/tests/test_ticket_tier.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "ticket_tier.py"

FAILURES: list[str] = []


class _StubCLI:
    """A stand-in for the `subprocess` module, so no live board is read.

    The board reader shells out to the hermes CLI, so the only way to
    exercise the unreadable case without touching the live board is to
    stand in for the CLI. This stands in for it.
    """

    def __init__(self, returncode: int = 1, stdout: str = "", stderr: str = "") -> None:
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr

    def run(self, args, **kwargs):
        return subprocess.CompletedProcess(
            args=args,
            returncode=self.returncode,
            stdout=self.stdout,
            stderr=self.stderr,
        )


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


def run_check(tool, cli, argv: list[str]) -> tuple[int, str, str]:
    """Run the tool's own main() over a stubbed CLI, and capture its streams.

    The board reader shells out to the hermes CLI, so the sweep is exercised
    through the real main() with the CLI stood in for. The live board is
    never read, and the tool's own exit code is the thing under test.
    """
    saved_argv = sys.argv
    saved_subprocess = tool.subprocess
    tool.subprocess = cli
    sys.argv = ["ticket_tier.py", *argv]
    out = io.StringIO()
    err = io.StringIO()
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = tool.main()
    finally:
        sys.argv = saved_argv
        tool.subprocess = saved_subprocess
    return code, out.getvalue(), err.getvalue()


# The evidence budget is part of the contract every card states, so the
# fixture carries one. The budget names the file the card will READ, and
# the read list is a cap on reading, not a set of files to change: the
# wave gate keeps it out of the written set.
ONE_FILE = """## GOAL

The chat bubble must not wear the error colour.

## WHAT TO BUILD

Edit `Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift` so the
bubble keeps its own tint.

## GATES

`swift test --filter ChatMessageViewTests` exits 0.

## EVIDENCE BUDGET

read:   Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
stop when: the diff is written and the named suite passes
no:    the board history and the sibling worktrees
deliver: one commit on the card branch with the diff
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

# The body's SHAPE is what predicts the timeout loop, more than the work
# does. Measured on board wenshu-par: a body with fewer than 9 sections ran
# 2.12 times for 25.3 min per card with 0.25 timeouts, a body with 9-11 ran
# 3.05 times for 59.5 min with 1.10 timeouts, and 11+ ran 4.50 times for
# 93.3 min with 1.25 timeouts. A T1 body over its section budget is a body
# that should be two cards.
def body_with_sections(count: int) -> str:
    """A T2 card body carrying exactly `count` sections."""
    head = [
        "## GOAL\n\nDo the thing.\n",
        "## WHAT TO BUILD\n\n"
        "- `Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift`\n"
        "- `Sources/WenshuApp/Features/Chat/View/ChatToolUsePartView.swift`\n",
    ]
    tail = ["## GATES\n\n`swift test --filter ChatMessageViewTests` exits 0.\n"]
    filler = [f"## SECTION {i}\n\nThe card needs this section.\n" for i in range(count)]
    return "\n".join(head + filler[: count - len(head) - len(tail)] + tail)


# A card's ORDER names the files it writes; the paths in its CURRENT STATE
# section are CONTEXT (= what the tree looks like today). Measured on board
# wenshu-par, 2026-10-29: card t_6876ec70 wrote two files and was rated T3
# because its CURRENT STATE described seven others, so it carried a 45m cap
# and a full gate set it never needed; card t_dae9ab0d wrote none and was
# rated T3 for the same reason.
CONTEXT_PATHS = """## GOAL

The mention parser must not name a role.

## CURRENT STATE

Today the parser reads the role out of these files:

- `Sources/WenshuApp/Features/Agent/Store/SubAgentIdentity.swift`
- `Sources/WenshuApp/Features/Agent/Store/SubAgentMentionParser.swift`
- `Sources/WenshuApp/Features/Chat/Model/ChatMessage.swift`
- `Sources/WenshuApp/Features/Chat/Store/ChatViewModelLongRunningGoal.swift`
- `Sources/WenshuApp/Features/Chat/View/ChatView.swift`
- `Sources/WenshuApp/Resources/Localizable.xcstrings`

## WHAT TO BUILD

- `Sources/WenshuApp/Resources/Localizable.xcstrings`
- `Tests/WenshuAppTests/Agent/Conversation/SubAgentMentionParserTests.swift`

## GATES

`swift test --filter SubAgentMentionParserTests` exits 0.
"""

# A bare file name in the order (= no directory) is a file the card writes,
# so it counts as a file. It cannot be placed in the tree, so it is neither
# a source file nor an area: an unplaceable name must not inflate either.
BARE_NAME_ORDER = """## GOAL

The row wrapper has no caller.

## WHAT TO BUILD

- `SidebarInline.swift`
- `Sources/WenshuApp/Features/Library/View/SidebarServiceMutation.swift`

## GATES

`swift test --filter SidebarServiceMutationTests` exits 0.
"""

# The tier's file counts come from the ORDER, so the tier is decided by the
# work the card asks for, not by the files its prose happens to mention.
# (The measured shape of the tool: the tier rates BLAST RADIUS = how many
# suites must prove the card, so the set it rates must be the set the card
# writes.)

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

    # 6. A runtime surface is not T1. It is not T3 either: a live-app proof
    #    is extra evidence to gather, not a wider blast radius. Measured, a
    #    live-app proof correlates with minutes per card at r = +0.175, which
    #    is a cost signal and not a safety signal.
    check("runtime surface is not T1", tier_of_body(tool, RUNTIME_SURFACE), "T2")
    check(
        "a live-app proof is reported as a note",
        any("live-app proof" in f for f in tool.find_errors(
            {"id": "t", "title": "[T2] runtime surface", "body": RUNTIME_SURFACE,
             "max_runtime_seconds": 1500}
        )),
        True,
    )

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
    # A card with NO cap has no fuse: the dispatcher only reaps a worker
    # whose card carries one (= the reaper's query is `WHERE
    # t.max_runtime_seconds IS NOT NULL`), so the card runs until the quota
    # wall instead of until its work is done. Measured 2026-10-30: the
    # newest card on the board was created with no cap at all.
    no_cap = {k: v for k, v in good.items() if k != "max_runtime_seconds"}
    # The rule starts on its epoch (= a rule that starts on a date does not
    # look back at the cards that predate it), so the fixture is dated.
    no_cap["created_at"] = tool.CAP_CONTRACT_FROM
    findings = tool.find_errors(no_cap)
    check(
        "a card with no runtime cap is an error",
        any("no runtime cap" in f for f in findings),
        True,
    )
    check(
        "a card with no runtime cap says what the tier buys",
        any("no runtime cap" in f and "900" in f for f in findings),
        True,
    )
    # The rule starts on its epoch, so a card that predates it is not
    # reported (= the cards already on the board were dispatched under a
    # flow that did not ask for a cap, and they have all finished).
    legacy_no_cap = dict(no_cap, created_at=tool.CAP_CONTRACT_FROM - 1)
    check(
        "a card with no runtime cap from before the epoch is not an error",
        not any("no runtime cap" in f for f in tool.find_errors(legacy_no_cap)),
        True,
    )
    missing_tag = dict(good, title="one file")
    check(
        "a missing title tag is an error",
        any("no tier tag" in f for f in tool.find_errors(missing_tag)),
        True,
    )

    # 12. An INSTRUMENT card measures the built product instead of
    #     writing it, so the tier cannot see it in the ORDER (= the files
    #     the card writes): an instrument card writes no source file, so
    #     it reads as the cheapest tier there is. But it builds the app,
    #     launches it, waits, and reads a verdict, and that work has a
    #     wall clock of its own.
    #
    #     Measured 2026-10-30: `t_0cb4b46d` (launch-time crash triage)
    #     was priced T1 (= a 15-minute cap), ran the arm twice on that
    #     cap, and timed out both times (908 s and 906 s against a 900 s
    #     limit). It closed only after a human raised the cap by hand.
    instrument_body = (
        "## WHAT TO BUILD\n"
        "This card writes no source file. It runs the arm:\n"
        "```\n"
        "python3 .../scripts/launch_arm.py --arm launch-after-guard-fix "
        "--app <bundle> --exec <binary> --trials 6 --wait 95\n"
        "```\n"
        "The crash oracle matches on the binary's uuid, so an arm with no "
        "uuid measures nothing, and a vacuous trial proves nothing.\n"
    )
    instrument_tier, instrument_reasons = tool.tier_of(instrument_body)
    check(
        "an instrument card is not T1",
        instrument_tier,
        "T2",
    )
    check(
        "an instrument card says why it is not T1",
        any("instrument" in r for r in instrument_reasons),
        True,
    )
    # The same card WITHOUT the instrument is T1: the signal has to name
    # the instrument, not the general English of measuring.
    plain_body = instrument_body.replace(
        "python3 .../scripts/launch_arm.py --arm launch-after-guard-fix "
        "--app <bundle> --exec <binary> --trials 6 --wait 95",
        "edit the file",
    ).replace(
        "The crash oracle matches on the binary's uuid, so an arm with no "
        "uuid measures nothing, and a vacuous trial proves nothing.",
        "the file changes",
    )
    check(
        "a card that names no instrument is still T1",
        tool.tier_of(plain_body)[0],
        "T1",
    )
    # An instrument card is not T3 either: it writes no source file, so
    # its blast radius is small even though its clock is long.
    check(
        "an instrument card is not T3",
        instrument_tier != "T3",
        True,
    )

    # 13. The INSTRUMENT lane has its own floor, the way the review lane
    #     does. The floor is DERIVED from the card: the invocation names
    #     the trial count and the per-trial wait, so the wall clock the
    #     card cannot avoid is spelled out in the card itself.
    #
    #     Measured 2026-10-30: the launch-time crash triage card ran
    #     `launch_arm.py --trials 6 --wait 95` (= 570 s of waiting before
    #     it read a line), was priced T1 (= a 900 s cap), and timed out
    #     twice (908 s and 906 s). It closed only after a human raised
    #     the cap by hand.
    check(
        "an instrument card's arm wait is read from its own invocation",
        tool.instrument_wait(instrument_body),
        6 * 95,
    )
    check(
        "an instrument card's floor is its tier's runtime plus the arm's wait",
        tool.instrument_floor(instrument_body, 1500),
        1500 + 6 * 95,
    )
    check(
        "a card that names no instrument has no floor",
        tool.instrument_floor(plain_body, 1500),
        0,
    )
    # The floor is what the gate checks: under it, the card dies before
    # its instrument reports.
    under_floor = {
        "body": instrument_body,
        "created_at": tool.CAP_CONTRACT_FROM,
        "max_runtime_seconds": 1500,
        "title": "[T2] an instrument card",
    }
    check(
        "an instrument card under its floor is an error",
        any("instrument needs at least" in f for f in tool.find_errors(under_floor)),
        True,
    )
    # Over the floor is generous, not wrong (= the review lane's rule).
    over_floor = dict(under_floor, max_runtime_seconds=2070)
    check(
        "an instrument card over its floor is not an error",
        not any("instrument needs at least" in f for f in tool.find_errors(over_floor)),
        True,
    )

    # 11b. The REVIEW lane has its own clock. A card in the review column runs
    # the review's work (re-read the diff, re-derive the acceptance, re-run the
    # gates), which is slower than the implementation it audits, so the tier's
    # implementation cap would kill it before it could hand back a verdict.
    # Measured on this board: at a 1500 cap the review runs died at 25.1 min
    # (seven of them), and at 3600 a 27-min review completed. So the lane has
    # a FLOOR of 3600s, and a card above it is generous rather than wrong.
    review_card = dict(good, status="review", max_runtime_seconds=3600)
    check(
        "a review card at the lane's floor has no cap finding",
        any("runtime cap" in f for f in tool.find_errors(review_card)),
        False,
    )
    review_under = dict(good, status="review", max_runtime_seconds=1500)
    check(
        "a review card under the lane's floor is an error",
        any("review lane needs at least" in f for f in tool.find_errors(review_under)),
        True,
    )
    review_over = dict(good, status="review", max_runtime_seconds=5400)
    check(
        "a review card above the floor is not an error",
        any("runtime cap" in f for f in tool.find_errors(review_over)),
        False,
    )
    # The floor belongs to the LANE, so it does not move with the tier: a T2
    # card in review is still held to the review lane's clock, not to T2's.
    review_t2 = dict(
        good,
        status="review",
        title="[T2] two files",
        body=TWO_FILES,
        max_runtime_seconds=2700,
    )
    check(
        "the review floor does not depend on the tier",
        any("review lane needs at least" in f for f in tool.find_errors(review_t2)),
        True,
    )

    # 12. Every tier's cap must cover the longest successful run measured in
    #     that tier, or the cap kills work that would have finished.
    measured_max = {"T1": 10.5, "T2": 16.0, "T3": 39.2}
    for tier, longest in measured_max.items():
        check(
            f"{tier} cap covers its measured longest successful run",
            tool.TIERS[tier]["runtime"] / 60 >= longest,
            True,
        )

    # 13. The retry budget must exceed the longest CONSECUTIVE failure streak
    #     the board has actually produced in that tier, or the breaker blocks
    #     a card that would have recovered.
    measured_streak = {"T1": 1, "T2": 2, "T3": 4}
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
    t2_wide["max_runtime_seconds"] = 1500
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

    # 17. The body's section count is the tier's speed lever, and a body over
    #     its tier's section budget is reported.
    check(
        "a body over its section budget is an error",
        any("sections" in f for f in tool.find_errors(
            {"id": "t", "title": "[T2] ten sections", "body": body_with_sections(10),
             "max_runtime_seconds": 1500}
        )),
        True,
    )
    check(
        "a body inside its section budget is not an error",
        any("sections" in f for f in tool.find_errors(
            {"id": "t", "title": "[T2] nine sections", "body": body_with_sections(9),
             "max_runtime_seconds": 1500}
        )),
        False,
    )
    check(
        "T1 buys 7 sections, T2 buys 9, T3 buys 12",
        [tool.TIERS[t]["sections_max"] for t in ("T1", "T2", "T3")],
        [7, 9, 12],
    )

    # 18. The review lane is detected by WHO HOLDS THE CARD, not by the card's
    #     momentary status. A review card is handed off while the implementer is
    #     still "running", sits "review" in the queue, and goes back to
    #     "running" while the reviewer works on it -- so a status test sees the
    #     lane only in the queue window. It then judged the review itself as
    #     implementation work: a generous review cap was reported as a tier
    #     violation, and a review whose cap was under the lane's floor was NOT
    #     flagged, which is exactly the card that dies on the clock and hands
    #     back no verdict.
    floor = tool.REVIEW_LANE_CAP_FLOOR
    review_card = {
        "id": "t_rev",
        "title": "[T3] the trailing column gets a switcher",
        "body": PERSISTENCE,
        "status": "running",
        "assignee": tool.REVIEW_PROFILE,
        "max_runtime_seconds": floor,
    }
    check(
        "a running review is in the review lane",
        tool.in_review_lane(review_card),
        True,
    )
    check(
        "a running review with a generous cap is not a tier violation",
        [e for e in tool.find_contract_errors(review_card) if "runtime cap" in e],
        [],
    )
    review_under_floor = dict(review_card, max_runtime_seconds=2700)
    check(
        "a running review under the floor IS flagged",
        any(
            "review lane needs at least" in e
            for e in tool.find_contract_errors(review_under_floor)
        ),
        True,
    )
    queued_review = dict(review_card, status="review", assignee="")
    check(
        "a queued review is in the review lane",
        tool.in_review_lane(queued_review),
        True,
    )
    implementation = {
        "id": "t_impl",
        "title": "[T3] the trailing column gets a switcher",
        "body": PERSISTENCE,
        "status": "running",
        "assignee": "wenshu-dev",
        # T2's cap on a T3 card: the tier must still catch it.
        "max_runtime_seconds": 1500,
    }
    check(
        "an implementation card is not in the review lane",
        tool.in_review_lane(implementation),
        False,
    )
    check(
        "an implementation card is still judged against its tier",
        any(
            "tier T3 buys" in e
            for e in tool.find_contract_errors(implementation)
        ),
        True,
    )
    # A card that names a reviewer in its handoff is a card that will be
    # reviewed, so the reviewer named there identifies the lane even when
    # the profile is not the board's usual one.
    named = {
        "id": "t_named",
        "title": "[T1] a picture in a picture",
        "body": (
            "## GOAL\n\nOne file.\n\n"
            "## REVIEW HANDOFF\n\n"
            'reviewer="wenshu-review-alt"\n'
        ),
        "status": "running",
        "assignee": "wenshu-review-alt",
        "max_runtime_seconds": floor,
    }
    check(
        "the reviewer named in the body identifies the lane",
        tool.in_review_lane(named),
        True,
    )
    check(
        "a named reviewer's generous cap is not a tier violation",
        [e for e in tool.find_contract_errors(named) if "runtime cap" in e],
        [],
    )

    # 19. The board sweep must not be able to PASS by reading no cards. A
    #     board that cannot be read is not an empty board: the old reader
    #     returned [] for both, so a mistyped slug printed "every card
    #     agrees with its tier" and exited 0, and the boss read that line as
    #     evidence the board was checked. It was not.
    refusing = _StubCLI(
        returncode=1,
        stderr="kanban: board 'nosuchboard' does not exist.",
    )
    code, out, err = run_check(
        tool, refusing, ["--check", "--board", "nosuchboard"]
    )
    check("an unreadable board does not exit 0", code != 0, True)
    check(
        "an unreadable board does not report agreement",
        "every card agrees" in out,
        False,
    )
    check(
        "an unreadable board says the board could not be read",
        "could not be read" in out + err,
        True,
    )

    # An EMPTY board is a different fact and stays a pass: the board was
    # read, and it holds no cards to disagree with their tier.
    empty = _StubCLI(returncode=0, stdout="[]")
    code, out, err = run_check(tool, empty, ["--check"])
    check("an empty board still exits 0", code, 0)
    check(
        "an empty board still reports agreement",
        "every card agrees" in out,
        True,
    )

    # A readable board with cards still reports the SAME findings, so the
    # fix changed what the sweep reports when it reads nothing, and nothing
    # else.
    agreeing = _StubCLI(
        returncode=0,
        stdout=json.dumps([
            {
                "id": "t_ok",
                "title": "[T1] one file",
                "body": ONE_FILE,
                "status": "ready",
                "max_runtime_seconds": 900,
            }
        ]),
    )
    code, out, err = run_check(tool, agreeing, ["--check"])
    check("a readable board still exits 0", code, 0)
    check(
        "a readable board still reports agreement",
        "every card agrees" in out,
        True,
    )

    # 12. The tier rates the ORDER (= the files the card writes), not every
    #     path the body mentions. A CURRENT STATE section describes the tree
    #     as it is today, so its paths are CONTEXT: a card that writes two
    #     files and describes six others is a T2 card, not a T3 one that
    #     carries a 45m cap and the full gate set.
    check(
        "the order's files are the tier's files",
        sorted(tool.order_paths(CONTEXT_PATHS)),
        [
            "Sources/WenshuApp/Resources/Localizable.xcstrings",
            "Tests/WenshuAppTests/Agent/Conversation/SubAgentMentionParserTests.swift",
        ],
    )
    check(
        "a card is rated on what it writes, not on what it mentions",
        tier_of_body(tool, CONTEXT_PATHS),
        "T1",
    )
    check(
        "the context paths are still named by the body (= the gate can see them)",
        len(tool.work_scope(CONTEXT_PATHS)[0]),
        7,
    )

    # 13. A bare file name in the order counts as a file, and it is neither
    #     a source file nor an area: it cannot be placed in the tree, so it
    #     must not push the card over the three-area T3 line.
    check(
        "a bare file name in the order is a file the card writes",
        "SidebarInline.swift" in tool.order_paths(BARE_NAME_ORDER),
        True,
    )
    check(
        "a bare file name is not an area of the tree",
        tool.signals(BARE_NAME_ORDER)["n_areas"],
        1,
    )
    check(
        "a bare file name is not a source file",
        tool.signals(BARE_NAME_ORDER)["n_sources"],
        1,
    )
    check(
        "a bare file name does not make the card T3",
        tier_of_body(tool, BARE_NAME_ORDER),
        "T1",
    )

    # 13. An area is a DIRECTORY, so the file's name never becomes one. A
    #     tree that is two levels deep (= `Tests/WenshuMobileTests/
    #     GlassSurfaceTests.swift`) used to fall through to the file path
    #     itself, so ONE test file counted as its own area.
    check(
        "a shallow test file is an area of its directory, not of itself",
        sorted(
            tool.areas_of(
                [
                    "Sources/WenshuMobileApp/Features/Connection/View/ConnectionView.swift",
                    "Tests/WenshuMobileTests/GlassSurfaceTests.swift",
                ]
            )
        ),
        ["Sources/WenshuMobileApp/Features", "Tests/WenshuMobileTests"],
    )
    check(
        "a deep test file keeps its own area",
        sorted(
            tool.areas_of(
                [
                    "Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift",
                    "Tests/WenshuAppTests/Chat/View/ChatMessageViewTests.swift",
                ]
            )
        ),
        ["Sources/WenshuApp/Features", "Tests/WenshuAppTests/Chat"],
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
