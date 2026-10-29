#!/usr/bin/env python3
"""test_effort_budget_gate.py — the evidence-budget gate's own test suite.

Every case runs on a FIXTURE body written to a temporary file, so the tests
stay valid when the real card bodies change.

The cases are the ways a card can spend evidence without a budget, each one
measured on board wenshu-par, 2026-10-27:

  1. a card with no evidence budget is an error.
  2. a card with all four budget lines passes.
  3. a card missing one of the four lines is an error.
  4. a read line naming no file is an error (= unbounded research).
  5. a read line naming more than the cap is an error.
  6. a read line naming the worker's own history is an error.
  7. a card created before the contract epoch is reported, never blocked.
  8. a done / review / archived card is out of scope.
  9. a card WITH a GATES section still owes a budget (orthogonality).
 10. the heading is found as a heading, not as a word.
 11. a read line may name a .py / .sh / .md path, not only a .swift one.
 12. the empty read line is unbounded, not a pass.
 13. the --body mode returns non-zero on a finding, zero on a clean card.
 14. a body stored as a BLOB is read, not crashed on.
 15. a BLOB body is scoped by the same rule as a TEXT one.
 16. a BLOB body that states no budget still reports the finding.

Run:  python3 Tools/wenshu-devtool/tests/test_effort_budget_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "effort_budget_gate.py"

spec = importlib.util.spec_from_file_location("effort_budget_gate", TOOL)
assert spec is not None and spec.loader is not None
ebg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ebg)


def body(
    goal: str = "x",
    files: tuple[str, ...] = ("Sources/WenshuApp/Foo.swift:120-138",),
    gates: str = "",
    budget: str = "",
) -> str:
    """A card body with the sections the tools read.

    The order names a file WITH a line anchor. A card created after
    ORDER_CONTRACT_FROM carries an order (= the seam it writes), and the
    gate reads a path with no anchor as a card that sends the worker
    hunting for the file. So the default order is anchored, and a test
    that wants the unanchored shape passes its own order.
    """
    parts = ["## GOAL", goal, "", "## WHAT TO BUILD"]
    parts.extend(files)
    if gates:
        parts += ["", "## GATES", gates]
    if budget:
        parts += ["", budget]
    return "\n".join(parts) + "\n"


def card(
    goal: str = "x",
    files: tuple[str, ...] = ("Sources/WenshuApp/Foo.swift:120-138",),
    gates: str = "",
    budget: str = "",
    status: str = "ready",
    created_at: int | None = None,
) -> dict:
    """A card dict shaped like the one the board hands to the tool."""
    return {
        "id": "t_fixture",
        "title": goal,
        "body": body(goal=goal, files=files, gates=gates, budget=budget),
        "status": status,
        "created_at": created_at,
    }


def good_budget(
    read: str = "Sources/WenshuApp/Foo.swift",
    stop: str = "the diff is written and the named suite passes",
    no: str = "the board history and the sibling worktrees",
    deliver: str = "one commit on the card branch with the diff",
) -> str:
    """A budget section that satisfies every rule."""
    return "\n".join(
        [
            "## EVIDENCE BUDGET",
            "",
            f"read:   {read}",
            f"stop when: {stop}",
            f"no:    {no}",
            f"deliver: {deliver}",
        ]
    )


def case(name: str, ok: bool, detail: str = "") -> bool:
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    if not ok and detail:
        print(f"      {detail}")
    return ok


def guarded(fn):
    """Run fn and report a raise as a failure instead of aborting the suite.

    A case that raises would abort the suite before it prints its count,
    so the suite could never go RED on its own teeth. The failure has to
    be a failed CASE, not a dead runner: the gate's job is to report, and
    the suite's job is to report the gate not reporting.
    """
    try:
        return fn(), ""
    except TypeError as exc:
        return None, f"raised {type(exc).__name__}: {exc}"


def main() -> int:
    results: list[bool] = []

    # The suite reads NO board. A case that checks the order shape reaches
    # the one-writer-per-file check, which reads the live board: a live card
    # that writes the fixture's file would decide the fixture's verdict, and
    # the suite would then depend on what the board happens to hold.
    ebg.BOARD_DB = Path(tempfile.gettempdir()) / "wenshu-devtool-no-such-board.db"
    ebg._OPEN_CARDS_CACHE.clear()

    # 1. no budget at all -> an error
    errors = ebg.contract_errors(card())
    results.append(
        case(
            "a card with no evidence budget is an error",
            bool(errors) and "EVIDENCE BUDGET" in errors[0],
            f"got {errors}",
        )
    )

    # 2. all four lines -> no error
    errors = ebg.contract_errors(card(budget=good_budget()))
    results.append(case("a card with all four budget lines passes", not errors, f"got {errors}"))

    # 3. one line missing -> an error naming the missing key
    partial = "\n".join(
        [
            "## EVIDENCE BUDGET",
            "",
            "read:   Sources/WenshuApp/Foo.swift",
            "stop when: the diff is written",
            "deliver: one commit",
        ]
    )
    errors = ebg.contract_errors(card(budget=partial))
    results.append(
        case(
            "a card missing one of the four lines is an error",
            any("'no:'" in e for e in errors),
            f"got {errors}",
        )
    )

    # 4. a read line that names no file -> unbounded research
    errors = ebg.contract_errors(card(budget=good_budget(read="the whole area")))
    results.append(
        case(
            "a read line naming no file is an error",
            any("names no file" in e for e in errors),
            f"got {errors}",
        )
    )

    # 5. over the cap
    many = ", ".join(f"Sources/WenshuApp/File{i:02d}.swift" for i in range(ebg.MAX_READ_FILES + 3))
    errors = ebg.contract_errors(card(budget=good_budget(read=many)))
    results.append(
        case(
            "a read line naming more than the cap is an error",
            any("over the cap" in e for e in errors),
            f"got {errors}",
        )
    )

    # 6. the worker's own history is never evidence
    errors = ebg.contract_errors(
        card(budget=good_budget(read="Sources/WenshuApp/Foo.swift, kanban.db, state.db"))
    )
    results.append(
        case(
            "a read line naming the worker's own history is an error",
            any("own history" in e for e in errors),
            f"got {errors}",
        )
    )

    # 7. a card created before the contract epoch is reported, never blocked
    old = card(budget=good_budget(), created_at=ebg.EVIDENCE_CONTRACT_FROM - 1)
    row = ebg.report(old)
    results.append(
        case(
            "a card created before the contract epoch is reported, never blocked",
            row["legacy"] is True and not ebg.is_subject(old["created_at"]),
            f"got {row}",
        )
    )
    new = card(budget=good_budget(), created_at=ebg.EVIDENCE_CONTRACT_FROM)
    results.append(
        case(
            "a card created on the contract epoch is a subject",
            ebg.is_subject(new["created_at"]) is True,
            f"got {ebg.is_subject(new['created_at'])}",
        )
    )

    # 8. a spent card is out of scope
    for status in ("done", "review", "archived"):
        errors = ebg.contract_errors(card(status=status))
        results.append(
            case(f"a {status} card is out of scope", not errors, f"got {errors}")
        )

    # 9. orthogonality: a card WITH a GATES section still owes a budget
    scoped, _why = ebg.in_scope(card(gates="swift build"))
    errors = ebg.contract_errors(card(gates="swift build"))
    results.append(
        case(
            "a card with a GATES section still owes a budget",
            scoped is True and bool(errors),
            f"scoped={scoped} errors={errors}",
        )
    )

    # 10. the heading is a heading, not a word
    tricky = (
        "## GOAL\n"
        "x\n\n"
        "## EXAMPLE\n"
        "```\n"
        "## EVIDENCE BUDGET\n"
        "read:   Sources/WenshuApp/Example.swift\n"
        "```\n"
    )
    section = ebg.budget_section(tricky)
    results.append(
        case(
            "a fenced example does not become the card's budget",
            section is None,
            f"got {section!r}",
        )
    )
    # ...and a real budget AFTER a fenced example is still found
    both = tricky + "\n" + good_budget() + "\n"
    section = ebg.budget_section(both)
    results.append(
        case(
            "a real budget after a fenced example is still found",
            section is not None and "Foo.swift" in section,
            f"got {section!r}",
        )
    )

    # 11. a read line may name a non-Swift path
    errors = ebg.contract_errors(
        card(budget=good_budget(read="Tools/wenshu-devtool/wave_gate.py"))
    )
    results.append(
        case(
            "a read line may name a .py path",
            not errors,
            f"got {errors}",
        )
    )
    errors = ebg.contract_errors(
        card(budget=good_budget(read="Scripts/merge-preflight.sh, AGENTS.md"))
    )
    results.append(
        case(
            "a read line may name a .sh and a .md path",
            not errors,
            f"got {errors}",
        )
    )

    # 12. the empty read line is unbounded, not a pass
    errors = ebg.contract_errors(card(budget=good_budget(read="")))
    results.append(
        case(
            "an empty read line is an error",
            any("names no file" in e for e in errors),
            f"got {errors}",
        )
    )

    # 13. the --body mode returns non-zero when the card has a finding
    with tempfile.TemporaryDirectory() as tmp:
        bad = Path(tmp) / "bad_card.md"
        bad.write_text(body(goal="x"), encoding="utf-8")
        rc = ebg.main(["--body", str(bad)])
        results.append(case("the --body mode returns non-zero on a finding", rc != 0, f"got {rc}"))

        good = Path(tmp) / "good_card.md"
        good.write_text(body(goal="x", budget=good_budget()), encoding="utf-8")
        rc = ebg.main(["--body", str(good)])
        results.append(case("the --body mode returns zero on a clean card", rc == 0, f"got {rc}"))

    # 14. a body stored as a BLOB is read, not crashed on
    #
    # A board holds a body as TEXT, but a body written through a path that
    # bound a bytes value is stored as a BLOB, and sqlite3 hands that back
    # as bytes. A str pattern then met a bytes body and raised TypeError,
    # so the board-wide --check sweep DIED on the first such card instead
    # of reporting it. Measured 2026-10-27 on wenshu-par: five cards held
    # their body as a BLOB, and --check crashed on the first of them.
    blob = card(budget=good_budget())
    blob["body"] = blob["body"].encode("utf-8")
    row, raised = guarded(lambda: ebg.report(blob))
    results.append(
        case(
            "a body stored as a BLOB is read, not crashed on",
            not raised
            and row is not None
            and not row["findings"]
            and row["read_count"] == 1
            and bool(row["deliver"]),
            raised or f"got {row}",
        )
    )

    # 15. a BLOB body is scoped by the same rule as a TEXT one
    #
    # The scope rule reads the body's GATES marker, so it is the first
    # reader a bytes body met. The scope answer must not depend on how
    # the board happened to store the body.
    scoped_card = card(gates="swift build", budget=good_budget())
    blob_scoped = dict(scoped_card)
    blob_scoped["body"] = scoped_card["body"].encode("utf-8")
    text_scope, text_raised = guarded(lambda: ebg.in_scope(scoped_card))
    blob_scope, blob_raised = guarded(lambda: ebg.in_scope(blob_scoped))
    results.append(
        case(
            "a BLOB body is scoped by the same rule as a TEXT one",
            not blob_raised
            and not text_raised
            and blob_scope == text_scope
            and blob_scope is not None
            and blob_scope[0] is True,
            blob_raised or text_raised or f"got {blob_scope} vs {text_scope}",
        )
    )

    # 16. a BLOB body that states no budget still reports the finding
    #
    # The crash hid the finding: the cards that genuinely state no budget
    # were invisible behind the exception. A BLOB body must report the
    # same finding a TEXT body reports.
    bare = card()
    bare["body"] = bare["body"].encode("utf-8")
    errors, raised = guarded(lambda: ebg.contract_errors(bare))
    results.append(
        case(
            "a BLOB body that states no budget still reports the finding",
            not raised
            and errors is not None
            and bool(errors)
            and "EVIDENCE BUDGET" in errors[0],
            raised or f"got {errors}",
        )
    )

    # 17. the ORDER shape: a card created after the order epoch carries an
    # order (= the seam it writes), and a path with no line anchor sends the
    # worker hunting for the file.
    #
    # The rule landed with no test at all: the fixture's default order named
    # a path with no anchor, so the one case that reached the rule (the
    # --body mode, which stamps the card with NOW) went RED, and the rule
    # itself was untested. These cases pin both directions.
    after = card(budget=good_budget(), created_at=ebg.ORDER_CONTRACT_FROM)
    errors = ebg.contract_errors(after)
    results.append(
        case(
            "an order that names a path with a line anchor passes",
            not errors,
            f"got {errors}",
        )
    )

    unanchored = card(
        files=("Sources/WenshuApp/Foo.swift",),
        budget=good_budget(),
        created_at=ebg.ORDER_CONTRACT_FROM,
    )
    errors = ebg.contract_errors(unanchored)
    results.append(
        case(
            "an order that names a path with no line anchor is an error",
            any("without a line anchor" in e for e in errors),
            f"got {errors}",
        )
    )

    before = card(
        files=("Sources/WenshuApp/Foo.swift",),
        budget=good_budget(),
        created_at=ebg.ORDER_CONTRACT_FROM - 1,
    )
    errors = ebg.contract_errors(before)
    results.append(
        case(
            "a card created before the order epoch is reported, never blocked",
            not errors,
            f"got {errors}",
        )
    )

    no_order = card(budget=good_budget(), created_at=ebg.ORDER_CONTRACT_FROM)
    no_order["body"] = no_order["body"].replace("## WHAT TO BUILD", "## CONTEXT")
    errors = ebg.contract_errors(no_order)
    results.append(
        case(
            "a card with no WHAT TO BUILD section is an error",
            any("WHAT TO BUILD" in e for e in errors),
            f"got {errors}",
        )
    )

    # 5. The LOCALIZATION section has to say WHERE the strings go. A card
    #    that says "add it to the String Catalog" tells the worker WHAT and
    #    not WHERE, and the hunt for the file is expensive: a board session
    #    has no prompt cache, so every look-up re-sends the whole history.
    #    Measured 2026-10-29 on the mobile line: the worker searched for the
    #    catalog twelve times and the file was not in that repo at all.
    def with_localization(section: str) -> dict:
        c = card(budget=good_budget(), created_at=ebg.ORDER_CONTRACT_FROM)
        c["body"] = c["body"].rstrip("\n") + "\n\n## LOCALIZATION\n\n" + section + "\n"
        return c

    bare = with_localization(
        "New user-facing copy IS expected here. Add it to the String Catalog\n"
        "the other views read (`Localizable.xcstrings`), and name them in the\n"
        "commit body."
    )
    errors = ebg.contract_errors(bare)
    results.append(
        case(
            "a LOCALIZATION section that names a catalog without its path is an error",
            any("LOCALIZATION section" in e for e in errors),
            f"got {errors}",
        )
    )

    with_path = with_localization(
        "New copy IS expected here. Add it to\n"
        "`Sources/WenshuApp/Resources/Localizable.xcstrings`, and name the keys\n"
        "in the commit body."
    )
    results.append(
        case(
            "a LOCALIZATION section that names the catalog's path is accepted",
            not ebg.contract_errors(with_path),
            f"got {ebg.contract_errors(with_path)}",
        )
    )

    no_catalog = with_localization(
        "New copy IS expected here. This project has no string catalog, so the\n"
        "new copy is a literal string in the view; adding a catalog is a\n"
        "separate card."
    )
    results.append(
        case(
            "a LOCALIZATION section that says there is no catalog is accepted",
            not ebg.contract_errors(no_catalog),
            f"got {ebg.contract_errors(no_catalog)}",
        )
    )

    # 5b. A section that names a path for a DIFFERENT file is not a path for
    #     the catalog. This is the second way the check can pass, so it needs
    #     its own case: a mutation that makes the path test accept any path
    #     must turn this one red.
    other_path = with_localization(
        "New copy IS expected here. The view is\n"
        "`Sources/WenshuApp/Features/Editor/View/EditorView.swift:120-138`, and\n"
        "the new copy goes to the String Catalog the other views read\n"
        "(`Localizable.xcstrings`)."
    )
    errors = ebg.contract_errors(other_path)
    results.append(
        case(
            "a LOCALIZATION section that names only another file's path is an error",
            any("LOCALIZATION section" in e for e in errors),
            f"got {errors}",
        )
    )

    # 5c. The section may name the catalog in WORDS and give neither the
    #     path nor the file name (= "the String Catalog the other views
    #     read"). That is the shape 15 of the real cards carry, and it is the
    #     vaguest of the three.
    words_only = with_localization(
        "New copy IS expected here. Add it to the String Catalog the other\n"
        "views read, and name the keys in the commit body."
    )
    errors = ebg.contract_errors(words_only)
    results.append(
        case(
            "a LOCALIZATION section that names the catalog in words only is an error",
            any("LOCALIZATION section" in e for e in errors),
            f"got {errors}",
        )
    )

    # 5d. A `.strings` file is the same question (= the hand-written file
    #     that shadows the catalog), so the check reads it too.
    strings_name = with_localization(
        "New copy IS expected here. Add it to the hand-written\n"
        "`Localizable.strings` file, and name the keys in the commit body."
    )
    errors = ebg.contract_errors(strings_name)
    results.append(
        case(
            "a LOCALIZATION section that names a .strings file without its path is an error",
            # The finding must NAME the file, or a check that stopped
            # recognising `.strings` would still pass this case.
            any("LOCALIZATION section" in e and "Localizable.strings" in e for e in errors),
            f"got {errors}",
        )
    )

    # 5e. The path check has to look at the EXTENSION, not at the presence
    #     of a path: a card that names one file's path and then says "the
    #     catalog" has still not said where the catalog is.
    path_wrong_ext = with_localization(
        "New copy IS expected here. The catalog is at\n"
        "`Sources/WenshuApp/Resources/Localizable.xcstrings`, and the new copy\n"
        "goes into the same file."
    )
    results.append(
        case(
            "a LOCALIZATION section that names the catalog's path is accepted",
            not ebg.contract_errors(path_wrong_ext),
            f"got {ebg.contract_errors(path_wrong_ext)}",
        )
    )

    unrelated = with_localization(
        "No new user-facing copy is expected: the view draws the Mac's own\n"
        "strings and the empty state already carries its text."
    )
    results.append(
        case(
            "a LOCALIZATION section that says nothing about a catalog is accepted",
            not ebg.contract_errors(unrelated),
            f"got {ebg.contract_errors(unrelated)}",
        )
    )

    failed = results.count(False)
    print()
    print(f"{len(results) - failed}/{len(results)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
