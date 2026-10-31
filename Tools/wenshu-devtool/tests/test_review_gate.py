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
import json
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

    # 12. The IMPLEMENTER is not the card's current assignee. A handoff
    #     reassigns the card to the reviewer, so the assignee is the
    #     reviewer for the whole review, and reading it as the implementer
    #     reports every finished card as reviewing itself.
    #
    #     Measured 2026-10-30: 27 of 166 cards on wenshu-par were reported
    #     as self-reviews by the board sweep for that reason, and all 27
    #     are BUILD cards whose implementer was wenshu-dev.
    # The two sources of the implementer must DISAGREE here, or the check
    # below cannot tell which one was read: the handoff records the
    # implementer, and the runs give the same answer only when the first
    # run is the implementer's. The runs below are ordered so that the
    # LAST run is the implementer's, so a reader that takes the last run
    # gives a different answer than a reader that takes the recorded one.
    # The handoff records the implementer, and the runs give the same
    # answer only when the FIRST run is the implementer's. So this
    # fixture's two sources DISAGREE: the handoff says wenshu-dev, and the
    # earliest run says wenshu-review. A reader that takes the wrong one
    # gives the wrong answer, and the check below can tell them apart.
    reviewed = {
        "task": {"assignee": "wenshu-review"},
        "events": [{"kind": "review_requested", "created_at": 20, "payload": {"implementer": "wenshu-dev"}}],
        "runs": [
            {"profile": "wenshu-review", "started_at": 5},
            {"profile": "wenshu-dev", "started_at": 10},
        ],
    }
    check(
        "the implementer is not the card's current assignee",
        tool.implementer_of(reviewed),
        "wenshu-dev",
    )
    # With no handoff, the implementer is the FIRST profile that ran, so
    # the two rules give different answers and the check can tell them
    # apart.
    check(
        "with no handoff the implementer is the earliest run, not the latest",
        tool.implementer_of({"events": [], "runs": reviewed["runs"]}),
        "wenshu-review",
    )
    # And a card with no runs at all has no implementer to report, rather
    # than borrowing one.
    check(
        "a card with no runs has no implementer",
        tool.implementer_of({"events": [], "runs": []}),
        None,
    )
    check(
        "a build card handed to the reviewer breaks no contract",
        tool.contract_errors(
            body_with(
                "Sources/WenshuApp/Features/Editor/View/InspectorView.swift",
                handoff='reviewer="wenshu-review"',
            ),
            tool.implementer_of(reviewed),
        ),
        [],
    )
    # And the exemption is NARROW: a card whose runs are all the reviewer's
    # has no implementation phase, so it IS the review and it is not
    # reviewing itself.
    review_only = {
        "task": {"assignee": "wenshu-review"},
        "events": [],
        "runs": [{"profile": "wenshu-review", "started_at": 20}],
    }
    check(
        "a card with no implementation phase is not reviewing itself",
        tool.contract_errors(
            body_with(
                "Sources/WenshuApp/Features/Editor/View/InspectorView.swift",
                handoff='reviewer="wenshu-review"',
            ),
            tool.implementer_of(review_only),
            is_review=True,
        ),
        [],
    )

    # 12. A REVIEW card is the review (boss ruling 2026-10-30). It was
    # created FOR the reviewer and never handed off, so its REVIEW HANDOFF
    # section is not a handoff: there is no implementer to hand off from,
    # and naming a reviewer there would name the implementer.
    review_card_body = body_with(
        "A verdict on `a159635f2d`.",
        handoff="This card is the review. There is no implementer to hand off from.",
    )
    check(
        "a review card's handoff section needs no reviewer name",
        tool.contract_errors(
            review_card_body,
            assignee="wenshu-review",
            kind="review",
            is_review=True,
        ),
        [],
    )
    check(
        "a build card's handoff section still needs a reviewer name",
        tool.contract_errors(
            body_with(
                "Sources/WenshuApp/Features/Editor/View/InspectorView.swift",
                handoff="Nothing here names a reviewer.",
            ),
            assignee="pocock",
            kind="build",
        ) != [],
        True,
    )
    # The exemption is narrow: a card whose kind is not review still has to
    # name its reviewer, because that is where the reviewer is declared.
    check(
        "the exemption is narrow: a build card still needs the reviewer name",
        tool.contract_errors(
            body_with(
                "Sources/WenshuApp/Features/Editor/View/InspectorView.swift",
                handoff="Nothing here names a reviewer.",
            ),
            assignee="pocock",
            kind="review",
            is_review=False,
        ) != [],
        True,
    )

    # 13. The branch lookup hands card_kind a WRAPPED doc, never a raw
    # sqlite row. card_kind reads the body and the title out of
    # doc["task"], so a raw row makes it judge the card on an empty body
    # and an empty title: a card whose runs carry two profiles then reads
    # as a research card and is SKIPPED by the lookup, so the review card
    # of a reworked card would vanish from the merge gate.
    review_card = {
        "id": "t_test",
        "assignee": "wenshu-review",
        "title": "[T2][review] The review card",
        "body": "## WHAT TO BUILD\n\nA verdict on `a159635f2d`.\n",
        "runs": [{"profile": "wenshu-review", "started_at": 10}],
    }
    wrapped = {"task": review_card, "runs": review_card["runs"], "events": []}
    check(
        "the branch lookup reads the kind from the wrapped doc",
        tool.card_kind(wrapped),
        "review",
    )
    # The same card with a second profile (= it was reworked) must still
    # read as a review card.
    reworked = dict(review_card)
    reworked["runs"] = review_card["runs"] + [{"profile": "pocock", "started_at": 5}]
    reworked_doc = {"task": reworked, "runs": reworked["runs"], "events": []}
    check(
        "a reworked review card still reads as a review card",
        tool.card_kind(reworked_doc),
        "review",
    )
    check(
        "the raw row is what the bug read (the empty body and title)",
        tool.card_kind(reworked),
        "research",
    )

    # 14. A card body is not always TEXT: the board stores some of them
    # as a BLOB, and a NULL for the cards created without one. The gate
    # reads EVERY card on the board, so one card's storage type must not
    # crash the whole sweep.
    check(
        "a BLOB body is decoded, not passed to the section reader",
        tool.review_cards_for.__doc__ is not None
        and "BLOB" in (tool.review_cards_for.__doc__ or ""),
        True,
    )

    # 15. The board stores a run's metadata as JSON TEXT. A run read
    # straight out of sqlite therefore carries a string, and a test for
    # ``isinstance(metadata, dict)`` drops the verdict: the --branch path
    # read an approval as no approval while the --card path (through the
    # CLI, which decodes) read the same run as approved.
    approval = {"review_outcome": "approved"}
    check(
        "a run whose metadata is JSON text still carries its verdict",
        tool._run_metadata({"metadata": json.dumps(approval)}),
        approval,
    )
    check(
        "a run whose metadata is a dict still carries its verdict",
        tool._run_metadata({"metadata": approval}),
        approval,
    )
    check(
        "a run whose metadata is unreadable carries no verdict",
        tool._run_metadata({"metadata": "not json"}),
        {},
    )

    # 16. The verdict of a review card is the reviewer's own completion,
    # and it carries either an approval or a request for changes. The
    # board's request_changes transition is NOT the route here (= it needs
    # a review_requested handoff this flow never creates), so the reject
    # route is a completion whose metadata says so.
    review_task = {
        "id": "t_test",
        "assignee": "wenshu-review",
        "created_by": "pocock",
        "title": "[T2][review] The review card",
        "body": "## WHAT TO BUILD\n\nA verdict on `a159635f2d`.\n",
    }

    def review_doc(runs):
        return {"task": review_task, "runs": runs, "events": []}

    check(
        "a review card with an approving run reads approved",
        tool.verdict_from_doc(
            review_doc(
                [
                    {
                        "id": 1,
                        "profile": "wenshu-review",
                        "outcome": "completed",
                        "ended_at": 10,
                        "metadata": {"review_outcome": "approved"},
                    }
                ]
            )
        )["status"],
        "approved",
    )
    check(
        "a review card asking for changes reads changes_requested",
        tool.verdict_from_doc(
            review_doc(
                [
                    {
                        "id": 2,
                        "profile": "wenshu-review",
                        "outcome": "completed",
                        "ended_at": 10,
                        "metadata": {"review_outcome": "changes_requested"},
                    }
                ]
            )
        )["status"],
        "changes_requested",
    )
    check(
        "a review card with NO run yet carries no contract error",
        tool.contract_errors(
            "## WHAT TO BUILD\n\nA verdict on `a159635f2d`.\n\n"
            "## REVIEW HANDOFF\n\napprove with `kanban_complete(metadata="
            '{"review_outcome": "approved"})`.\n',
            assignee="wenshu-review",
            created_at=tool.REVIEW_CONTRACT_FROM + 86400,
            kind="review",
            is_review=True,
        ),
        [],
    )
    check(
        "a card with no run is read as having no implementation phase",
        tool.is_review_card({"task": review_task, "runs": [], "events": []}),
        True,
    )
    check(
        "a review card whose reviewer is its implementer reads self_review",
        tool.verdict_from_doc(
            {
                "task": dict(review_task, created_by="wenshu-review"),
                "runs": [
                    {
                        "id": 3,
                        "profile": "wenshu-review",
                        "outcome": "completed",
                        "ended_at": 10,
                        "metadata": {"review_outcome": "approved"},
                    }
                ],
                "events": [],
            }
        )["status"],
        "self_review",
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
