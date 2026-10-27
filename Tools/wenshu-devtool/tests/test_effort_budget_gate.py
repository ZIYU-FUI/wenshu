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
    files: tuple[str, ...] = ("Sources/WenshuApp/Foo.swift",),
    gates: str = "",
    budget: str = "",
) -> str:
    """A card body with the sections the tools read."""
    parts = ["## GOAL", goal, "", "## WHAT TO BUILD"]
    parts.extend(files)
    if gates:
        parts += ["", "## GATES", gates]
    if budget:
        parts += ["", budget]
    return "\n".join(parts) + "\n"


def card(
    goal: str = "x",
    files: tuple[str, ...] = ("Sources/WenshuApp/Foo.swift",),
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


def main() -> int:
    results: list[bool] = []

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

    failed = results.count(False)
    print()
    print(f"{len(results) - failed}/{len(results)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
