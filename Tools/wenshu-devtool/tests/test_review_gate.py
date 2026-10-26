#!/usr/bin/env python3
"""test_review_gate.py — the independent-review gate's own test suite.

Every case runs on a FIXTURE body written to a temporary file, so the tests
stay valid when the real card bodies change.

The cases are the things the naive gate got wrong, each one measured on board
wenshu-par:

  1. a body that writes CODE owes a verdict; a body that writes only prose
     does not (measured: 5 false-done cards were all code, 0 prose).
  2. a body that writes code and names no reviewer is a contract error.
  3. a body that names the implementer as its reviewer is a contract error:
     a card cannot be reviewed by the profile that implemented it.
  4. a body that names another profile passes the contract.
  5. the tier NEVER decides who reviews: a T1 body and a T3 body owe the
     same verdict (AGENTS.md 1.13 = the tier is the cost, never the bar).
  6. a card created BEFORE the contract started is reported, never blocked.
  7. a handoff that named no reviewer reads as a self-review, not a verdict.
  8. an approving verdict only counts from the profile that was named.
  9. changes requested AFTER the last approval void that approval.
 10. a card that never handed off owes a verdict it does not have.

Run:  python3 Tools/wenshu-devtool/tests/test_review_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "review_gate.py"

FAILURES: list[str] = []


def load_tool():
    """Import review_gate.py as a module, whatever its directory is."""
    spec = importlib.util.spec_from_file_location("review_gate", TOOL)
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


def body_with(files: str, handoff: str | None = None, extra: str = "") -> str:
    """A card body that writes the named files, with an optional handoff."""
    sections = [
        "## GOAL",
        "Make the thing work.",
        "",
        "## WHAT TO BUILD",
        files,
        "",
        "## GATES",
        "swift build exits 0.",
    ]
    if handoff is not None:
        sections += ["", "## REVIEW HANDOFF", handoff]
    if extra:
        sections += ["", extra]
    return "\n".join(sections) + "\n"


def main() -> int:
    tool = load_tool()
    print("review_gate: the independent-review gate\n")

    # 1. code owes a verdict, prose does not.
    code_body = body_with("Sources/WenshuApp/Features/Editor/View/InspectorView.swift")
    prose_body = body_with("docs/agents/domain.md")
    check("a body that writes code owes a verdict", tool.review_required(code_body)[0], True)
    check("a body that writes only prose does not", tool.review_required(prose_body)[0], False)

    # 2. code with no handoff is a contract error.
    errors = tool.contract_errors(code_body, assignee="wenshu-dev")
    check(
        "code with no handoff is a contract error",
        len(errors) == 1 and "REVIEW HANDOFF" in errors[0],
        True,
    )
    check(
        "prose with no handoff is not a contract error",
        tool.contract_errors(prose_body, assignee="wenshu-dev"),
        [],
    )

    # 3. naming the implementer is a contract error.
    self_review = body_with(
        "Sources/WenshuApp/Features/Editor/View/InspectorView.swift",
        handoff='reviewer="wenshu-dev"',
    )
    errors = tool.contract_errors(self_review, assignee="wenshu-dev")
    check(
        "naming the implementer is a contract error",
        len(errors) == 1 and "implementer profile" in errors[0],
        True,
    )
    check(
        "naming the implementer is NOT an error when the assignee differs",
        tool.contract_errors(self_review, assignee="wenshu-dev-2"),
        [],
    )

    # 4. naming another profile passes the contract.
    good = body_with(
        "Sources/WenshuApp/Features/Editor/View/InspectorView.swift",
        handoff='reviewer="wenshu-review"',
    )
    check("a body naming another profile passes", tool.contract_errors(good, "wenshu-dev"), [])
    check(
        "the named reviewer is read from the body",
        tool.named_reviewer(tool.handoff_text(good)),
        "wenshu-review",
    )

    # 5. the tier never decides who reviews.
    t1_body = body_with("Sources/WenshuApp/Features/Editor/View/InspectorView.swift")
    t3_body = body_with(
        "Sources/WenshuApp/Features/Editor/View/InspectorView.swift\n"
        "Sources/WenshuApp/Features/Chat/View/ChatView.swift\n"
        "Sources/WenshuApp/Features/Library/View/LibraryRootView.swift\n"
        "Sources/WenshuApp/Features/Outline/View/OutlineView.swift\n"
        "Sources/WenshuApp/Features/Session/View/SessionView.swift\n"
        "Sources/WenshuApp/Features/Book/View/BookView.swift",
    )
    ticket_tier = load_tool_tier()
    check("the tier of the small body", ticket_tier.tier_of(t1_body)[0], "T1")
    check("the tier of the large body", ticket_tier.tier_of(t3_body)[0], "T3")
    check(
        "both tiers owe the same verdict (the tier is not the bar)",
        tool.review_required(t1_body)[0] == tool.review_required(t3_body)[0],
        True,
    )

    # 6. a pre-contract card is reported, never blocked.
    old = tool.REVIEW_CONTRACT_FROM - 1
    check("a card created before the contract is not subject", tool.is_subject(old), False)
    check("a card created after the contract is subject", tool.is_subject(tool.REVIEW_CONTRACT_FROM), True)
    check(
        "a pre-contract card with no handoff raises no error",
        tool.contract_errors(code_body, assignee="wenshu-dev", created_at=old),
        [],
    )
    check(
        "a post-contract card with no handoff raises an error",
        len(tool.contract_errors(code_body, assignee="wenshu-dev", created_at=tool.REVIEW_CONTRACT_FROM)),
        1,
    )

    # 7. a handoff that named no reviewer reads as a self-review.
    doc = {
        "events": [
            {"kind": "review_requested", "created_at": 100, "payload": {"implementer": "wenshu-dev", "reviewer": None}},
        ],
        "runs": [],
    }
    verdict = tool.verdict_from_doc(doc)
    check("a handoff with no reviewer reads as no_reviewer_named", verdict["status"], "no_reviewer_named")

    # 8. an approving verdict counts only from the named profile.
    doc = {
        "events": [
            {"kind": "review_requested", "created_at": 100, "payload": {"implementer": "wenshu-dev", "reviewer": "wenshu-review"}},
        ],
        "runs": [
            {"id": 5, "profile": "wenshu-dev", "outcome": "completed", "ended_at": 200,
             "metadata": {"review_outcome": "approved"}},
        ],
    }
    check(
        "an approval from the implementer does not count",
        tool.verdict_from_doc(doc)["status"],
        "not_approved",
    )
    doc["runs"].append(
        {"id": 6, "profile": "wenshu-review", "outcome": "completed", "ended_at": 300,
         "metadata": {"review_outcome": "approved"}}
    )
    check(
        "an approval from the named reviewer counts",
        tool.verdict_from_doc(doc)["status"],
        "approved",
    )

    # 9. changes requested after the last approval void it.
    doc["events"].append(
        {"kind": "changes_requested", "created_at": 400, "payload": {"reason": "no"}}
    )
    check(
        "changes requested after the approval void it",
        tool.verdict_from_doc(doc)["status"],
        "changes_requested",
    )

    # 10. a card that never handed off owes a verdict it does not have.
    verdict = tool.verdict_from_doc({"events": [], "runs": []})
    check("a card that never handed off reads as no_handoff", verdict["status"], "no_handoff")

    # A reviewer equal to the implementer is a self-review even when named.
    doc = {
        "events": [
            {"kind": "review_requested", "created_at": 100, "payload": {"implementer": "wenshu-dev", "reviewer": "wenshu-dev"}},
        ],
        "runs": [],
    }
    check("the implementer reviewing itself reads as self_review", tool.verdict_from_doc(doc)["status"], "self_review")

    # 11. The implementer is NOT the card's current assignee. A handoff
    # reassigns the card to the reviewer, so the assignee is the reviewer
    # for the whole review. Reading the implementer from the assignee made
    # every handed-off card look like it was reviewed by its implementer.
    handed_off = {
        "events": [
            {"kind": "review_requested", "created_at": 100, "payload": {"implementer": "wenshu-dev", "reviewer": "wenshu-review"}},
        ],
        "runs": [
            {"id": 5, "profile": "wenshu-dev", "status": "review", "started_at": 90, "ended_at": 99},
            {"id": 6, "profile": "wenshu-review", "status": "running", "started_at": 101},
        ],
    }
    check(
        "the implementer is the profile that implemented, not the current assignee",
        tool.implementer_of(handed_off),
        "wenshu-dev",
    )
    check(
        "a card handed off to a different reviewer breaks no contract",
        tool.contract_errors(
            body_with("Tools/wenshu-devtool/ticket_tier.py", handoff='    reviewer="wenshu-review"'),
            tool.implementer_of(handed_off),
        ),
        [],
    )
    # With no handoff at all, the implementer is the first profile that ran.
    check(
        "with no handoff the implementer is the first profile that ran",
        tool.implementer_of({"events": [], "runs": handed_off["runs"]}),
        "wenshu-dev",
    )

    print()
    if FAILURES:
        print(f"review_gate: {len(FAILURES)} case(s) FAILED")
        for name in FAILURES:
            print(f"  - {name}")
        return 1
    print("review_gate: every case passed")
    return 0


def load_tool_tier():
    """Import the sibling tier tool, so the tier-independence case is real."""
    path = Path(__file__).resolve().parent.parent / "ticket_tier.py"
    spec = importlib.util.spec_from_file_location("ticket_tier", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    sys.exit(main())
