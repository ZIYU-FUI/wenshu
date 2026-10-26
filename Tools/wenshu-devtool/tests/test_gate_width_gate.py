#!/usr/bin/env python3
"""test_gate_width_gate.py — the gate-width gate's own test suite.

Every case runs on a FIXTURE body written to a temporary file, so the tests
stay valid when the real card bodies change.

The cases are the ways a card can ask for a gate wider than its tier buys,
each one measured on board wenshu-par, 2026-10-26:

  1. a T2 card demanding "the whole app test suite" is an error.
  2. a T3 card may demand the whole suite (= T3 owns the full gate set).
  3. a T1 card asking for a bare `swift test` is an error.
  4. a card naming `swift test --filter <suite>` is a narrow gate.
  5. a card that names NO suite is an error (= the worker picks the gate).
  6. a card whose prose says "a filtered suite per touched area" passes.
  7. a card created before the contract epoch is reported, never blocked.
  8. the gate agrees with the tier tool about what "wide" means.

Run:  python3 Tools/wenshu-devtool/tests/test_gate_width_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "gate_width_gate.py"

sys.path.insert(0, str(TOOL.parent))
import ticket_tier  # noqa: E402

spec = importlib.util.spec_from_file_location("gate_width_gate", TOOL)
assert spec is not None and spec.loader is not None
gwg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gwg)


def body(
    goal: str = "x",
    files: tuple[str, ...] = ("Sources/WenshuApp/Foo.swift",),
    gates: str = "",
    acceptance: str = "",
) -> str:
    """A card body with the sections the tools read."""
    parts = ["## GOAL", goal, "", "## WHAT TO BUILD"]
    parts.extend(files)
    if gates:
        parts += ["", "## GATES", gates]
    if acceptance:
        parts += ["", "## ACCEPTANCE", acceptance]
    return "\n".join(parts) + "\n"


def case(name: str, ok: bool, detail: str = "") -> bool:
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    if not ok and detail:
        print(f"      {detail}")
    return ok


def main() -> int:
    results: list[bool] = []

    # 1. a T2 card demanding the whole suite is an error.
    #    Two source files + one test file = T2 by the tier's own rules.
    b = body(
        files=(
            "Sources/WenshuApp/Features/Agent/Foo.swift",
            "Sources/WenshuApp/Features/Agent/Bar.swift",
            "Tests/WenshuAppTests/Agent/FooTests.swift",
        ),
        acceptance="The whole app test suite has no new failures against the baseline.",
    )
    row = gwg.report_body(b, None)
    results.append(
        case(
            "a T2 card demanding the whole suite is an error",
            row["tier"] == "T2"
            and any("wide gate" in f for f in row["findings"]),
            f"tier={row['tier']} findings={row['findings']}",
        )
    )

    # 2. a T3 card may demand the whole suite.
    #    Six source files = T3, and T3 owns the full gate set.
    t3_files = tuple(f"Sources/WenshuApp/F{i}.swift" for i in range(6))
    b = body(
        files=t3_files,
        acceptance="The whole app test suite has no new failures against the baseline.",
    )
    row = gwg.report_body(b, None)
    results.append(
        case(
            "a T3 card may demand the whole suite",
            row["tier"] == "T3"
            and not any("wide gate" in f for f in row["findings"]),
            f"tier={row['tier']} findings={row['findings']}",
        )
    )

    # 3. a T1 card asking for a bare `swift test` is an error.
    b = body(gates="swift test")
    row = gwg.report_body(b, None)
    results.append(
        case(
            "a T1 card asking for a bare `swift test` is an error",
            row["tier"] == "T1"
            and row["gate_width"] == "wide"
            and any("wide gate" in f for f in row["findings"]),
            f"tier={row['tier']} gate={row['gate_width']} findings={row['findings']}",
        )
    )

    # 4. a card naming `swift test --filter <suite>` is a narrow gate.
    b = body(
        files=(
            "Sources/WenshuApp/Features/Agent/Foo.swift",
            "Sources/WenshuApp/Features/Agent/Bar.swift",
            "Tests/WenshuAppTests/Agent/FooTests.swift",
        ),
        gates="swift test --filter FooTests",
    )
    row = gwg.report_body(b, None)
    results.append(
        case(
            "a card naming `swift test --filter <suite>` is a narrow gate",
            row["gate_width"] == "narrow" and not row["findings"],
            f"gate={row['gate_width']} findings={row['findings']}",
        )
    )

    # 5. a card that names NO suite is an error: the worker picks the gate,
    #    and the worker picks the whole suite.
    b = body(
        files=(
            "Sources/WenshuApp/Features/Agent/Foo.swift",
            "Sources/WenshuApp/Features/Agent/Bar.swift",
            "Tests/WenshuAppTests/Agent/FooTests.swift",
        ),
        acceptance="it works",
    )
    row = gwg.report_body(b, None)
    results.append(
        case(
            "a card that names no suite is an error",
            row["gate_width"] == "unstated"
            and any("names no suite" in f for f in row["findings"]),
            f"gate={row['gate_width']} findings={row['findings']}",
        )
    )

    # 6. a card whose prose says "a filtered suite per touched area" passes.
    b = body(
        files=(
            "Sources/WenshuApp/Features/Agent/Foo.swift",
            "Sources/WenshuApp/Features/Agent/Bar.swift",
            "Tests/WenshuAppTests/Agent/FooTests.swift",
        ),
        gates="swift build, then a filtered suite per touched area.",
    )
    row = gwg.report_body(b, None)
    results.append(
        case(
            "a card whose prose says 'a filtered suite per touched area' passes",
            not row["findings"],
            f"findings={row['findings']}",
        )
    )

    # 7. a card created before the contract epoch is reported, never blocked.
    b = body(
        files=(
            "Sources/WenshuApp/Features/Agent/Foo.swift",
            "Sources/WenshuApp/Features/Agent/Bar.swift",
            "Tests/WenshuAppTests/Agent/FooTests.swift",
        ),
        acceptance="The whole app test suite has no new failures against the baseline.",
    )
    pre = gwg.report_body(b, gwg.GATE_CONTRACT_FROM - 1)
    post = gwg.report_body(b, gwg.GATE_CONTRACT_FROM)
    results.append(
        case(
            "a card created before the contract epoch is reported, never blocked",
            not pre["findings"] and bool(post["findings"]),
            f"pre={pre['findings']} post={post['findings']}",
        )
    )

    # 8. the gate agrees with the tier tool about what "wide" means.
    #    The two tools read the SAME forms, so a card cannot be wide to one
    #    and narrow to the other.
    forms = [
        "swift test",
        "The whole app test suite has no new failures against the baseline.",
        "swift test --filter FooTests",
    ]
    disagreements = []
    for form in forms:
        b = body(gates=form)
        mine = gwg.gate_demands(b)["wide"]
        theirs = ticket_tier.gate_width(b) == "wide"
        if mine != theirs:
            disagreements.append((form, mine, theirs))
    results.append(
        case(
            "the gate agrees with the tier tool about what 'wide' means",
            not disagreements,
            f"disagreements={disagreements}",
        )
    )

    # 9. a card that writes NO Swift code names its own gate command.
    #    A tool card or a docs card has no Swift suite to filter, so the
    #    rule cannot be "name a swift test --filter" for it, or the gate
    #    would block every non-Swift card on the board.
    b = body(
        files=("Tools/wenshu-devtool/wave_gate.py",),
        gates="python3 Tools/wenshu-devtool/tests/test_wave_gate.py",
    )
    row = gwg.report_body(b, None)
    results.append(
        case(
            "a card that writes no Swift code names its own gate command",
            row["gate_width"] == "narrow" and not row["findings"],
            f"gate={row['gate_width']} findings={row['findings']}",
        )
    )

    print()
    passed = sum(1 for r in results if r)
    print(f"{passed}/{len(results)} cases passed")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
