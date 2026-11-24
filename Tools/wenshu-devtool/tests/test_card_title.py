#!/usr/bin/env python3
"""test_card_title.py — the ONE reader of a draft body's title.

`ticket_tier.py` and `effort_budget_gate.py` both classify a card from a body FILE,
which is the documented pre-flight: an author writes `card.md`, runs the tool, and gets
the tier and the evidence-budget verdicts before the card exists on the board. A draft
has no board row, so its title has to come out of the file, and the tier model puts the
tier tag in the title. One gate read that line and the other passed an empty string, so
the same body earned `title carries no tier tag` from one tool and a credited tag from
the other.

`card_title.py` is the one reader, and this suite pins the four properties that make the
agreement hold:

  1. the title is the body's FIRST heading, tags and all, because parsing the tags is
     the caller's business and there is already one parser for them.
  2. blank lines before the heading are skipped, because a file may open with them.
  3. a body that opens with PROSE has no title, and the reader says so instead of
     inventing one from a line further down — an invented title is a claim about a line
     the author never wrote.
  4. the two gates agree: for the same file, the tier tool's card and the effort gate's
     card carry the same title. Not "usually": the same string, from the same call.

Run:  python3 Tools/wenshu-devtool/tests/test_card_title.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""

from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

DEVTOOL = Path(__file__).resolve().parent.parent
FAILURES: list[str] = []


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def check(name: str, got, want) -> None:
    if got == want:
        print(f"ok   {name}")
    else:
        print(f"FAIL  {name}\n          got:  {got!r}\n          want: {want!r}")
        FAILURES.append(name)


def main() -> int:
    card_title = _load("card_title", DEVTOOL / "card_title.py")
    tier = _load("ticket_tier", DEVTOOL / "ticket_tier.py")
    budget = _load("effort_budget_gate", DEVTOOL / "effort_budget_gate.py")

    read = card_title.title_from_body

    # 1. the first heading, with its tags left in place
    check("an H1 is the title", read("# [T2] The window is measured twice\n\ntext"),
          "[T2] The window is measured twice")
    check("the tag is kept as written and only the heading marker is stripped",
          read("# [T2]   The window  \n"), "[T2]   The window")
    check("a deeper heading is still a heading", read("## [T1] Sub\n"), "[T1] Sub")

    # 2. blank lines before it
    check("leading blank lines are skipped", read("\n\n   \n# [T3] Title\nbody\n"),
          "[T3] Title")

    # 3. prose is not a title, and a hash without a space is not a heading
    check("a body that opens with prose has no title", read("Just a paragraph.\n"), "")
    check("a hash glued to a word is not a heading", read("#not-a-heading\n"), "")
    check("an empty body has no title", read(""), "")
    check("a heading after prose is not the title",
          read("Prose first.\n\n# [T2] Later heading\n"), "")

    # 4. the two gates agree, from one call, on one file
    body = "# [T2] The agreement\n\n## GATES\n\n`swift test --filter NothingTests`\n"
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as handle:
        handle.write(body)
        path = handle.name
    try:
        tier_title = tier.card_from_file(path)["title"]
        budget_title = budget._card_from_file(path)["title"]
        check("the tier tool reads the draft's title from the body",
              tier_title, "[T2] The agreement")
        check("both gates carry the same title for the same file",
              (tier_title, budget_title), ("[T2] The agreement", "[T2] The agreement"))
        # And the consequence that started the ticket: a draft whose own first line
        # carries the tag is no longer charged for a tag it already has.
        errors = tier.find_contract_errors(tier.card_from_file(path))
        check("a tagged draft is not charged a missing tier tag",
              any("carries no tier tag" in e for e in errors), False)
    finally:
        Path(path).unlink(missing_ok=True)

    if FAILURES:
        print(f"\n{len(FAILURES)} case(s) FAILED")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
