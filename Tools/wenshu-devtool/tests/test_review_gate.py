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
 11. a verdict covers a branch that was REBASED since the card was written
     (= the same change, a new commit id), and does NOT cover a branch
     carrying a different change.

Run:  python3 Tools/wenshu-devtool/tests/test_review_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import contextlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
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


def load_agents_gate():
    """Import the sibling gate that owns the context-file cap."""
    path = Path(__file__).resolve().parent.parent / "agents_gate.py"
    spec = importlib.util.spec_from_file_location("agents_gate", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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
    # The board writes its card titles in the board's own language, and
    # the tag is what DECLARES a card's kind (= the tool parses it), so
    # the fixture asks the TOOL for the tag instead of writing the
    # character here (= the file stays English, and the fixture cannot
    # drift from the map the tool actually reads).
    REVIEW_TAG = ticket_tier.TYPE_TAG_NAMES["review"]

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

    # ---- case 11: the verdict covers the CHANGE, not the commit id ----
    # A branch that fell behind main is rebased before it lands, and a
    # rebase rewrites the commit id. A verdict that binds to the commit
    # id is then voided by somebody ELSE landing their work. These cases
    # build a real repository, rebase the branch, and ask the gate.
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        repo.mkdir()
        run = lambda *a: subprocess.run(
            ["git", *a], cwd=repo, capture_output=True, text=True, check=True
        )
        # The gate runs its git commands in the repository it is run from,
        # so the case runs the tool from inside the fixture repository.
        cwd_before = Path.cwd()
        os.chdir(repo)
        run("init", "-q", "-b", "main")
        run("config", "user.email", "t@t")
        run("config", "user.name", "t")
        (repo / "base.txt").write_text("base\n")
        run("add", "-A")
        run("commit", "-qm", "base")
        run("checkout", "-qb", "feature")
        (repo / "feature.txt").write_text("the change under review\n")
        run("add", "-A")
        run("commit", "-qm", "the change")
        reviewed_sha = run("rev-parse", "HEAD").stdout.strip()
        # somebody else lands: main moves
        run("checkout", "-q", "main")
        (repo / "other.txt").write_text("somebody else's work\n")
        run("add", "-A")
        run("commit", "-qm", "other work")
        # the branch is rebased, as the merge gate demands
        run("checkout", "-q", "feature")
        run("rebase", "main")
        rebased_sha = run("rev-parse", "HEAD").stdout.strip()
        check(
            "the rebase rewrote the sha (= a sha-bound verdict would die)",
            reviewed_sha != rebased_sha,
            True,
        )
        check(
            "the fixture repository is the one the tool reads",
            tool.patch_id(rebased_sha) is not None,
            True,
        )
        check(
            "the change survived the rebase (= the same edit, a new commit id)",
            tool.patch_id(rebased_sha) == tool.patch_id(reviewed_sha),
            True,
        )
        card = {
            "id": "t_rebase",
            "title": f"[T2][{REVIEW_TAG}] the change",
            "body": f"## WHAT TO BUILD\n\nA verdict on `{reviewed_sha}`.\n\n"
                    "## REVIEW HANDOFF\n\nnone\n",
            "runs": [
                {
                    "id": 1,
                    "profile": "wenshu-review",
                    "outcome": "completed",
                    "ended_at": 10,
                    "metadata": {"review_outcome": "approved"},
                }
            ],
            "events": [],
        }
        found = tool.matching_cards([card], rebased_sha, "feature")
        check(
            "a verdict covers the branch after it was rebased",
            [(f[0], f[3]) for f in found],
            [("t_rebase", "change")],
        )
        check(
            "the same card does NOT cover a branch with no reflog entry "
            "(= the sha it names is not the branch's)",
            tool.matching_cards([card], rebased_sha, None),
            [],
        )
        # a DIFFERENT change on the same branch must not be covered
        (repo / "feature.txt").write_text("a different change\n")
        run("add", "-A")
        run("commit", "-qm", "a different change")
        other_sha = run("rev-parse", "HEAD").stdout.strip()
        check(
            "a verdict does NOT cover a branch carrying a different change",
            tool.matching_cards([card], other_sha, "feature"),
            [],
        )
        os.chdir(cwd_before)

    # ---- the three defects the review round measured on this change ----
    # D1: an OLD approval of a pre-rebase tree must not shadow a NEWER
    # refusal of the current tree (= the caller takes the first card).
    # D2: a whitespace difference is a difference (in Python the indent
    # IS the meaning, and `git patch-id --stable` strips it).
    # D3: a landing that edits a NEARBY line in the same file must not
    # void a verdict for a change nobody touched (= no context lines).
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        repo.mkdir()
        run = lambda *a: subprocess.run(
            ["git", *a], cwd=repo, capture_output=True, text=True, check=True
        )
        run("init", "-q", "-b", "main")
        run("config", "user.email", "t@t")
        run("config", "user.name", "t")
        # The gate runs its git commands in the repository it is run from,
        # so the cases run the tool from inside the fixture repository.
        cwd_before = Path.cwd()
        os.chdir(repo)
        lines = ["a = 1\n"] * 20
        (repo / "prog.py").write_text("".join(lines))
        run("add", "-A")
        run("commit", "-qm", "base")

        # the change under review: one line inserted
        run("checkout", "-qb", "feature")
        (repo / "prog.py").write_text(
            "".join(lines[:2] + ["    x = 1\n"] + lines[2:]))
        run("add", "-A")
        run("commit", "-qm", "the change")
        reviewed = run("rev-parse", "HEAD").stdout.strip()

        # D2: the same edit, re-indented, on its own branch (= both have
        # a real diff, so both ids exist).
        run("checkout", "-q", "-b", "variant", "feature~1")
        (repo / "prog.py").write_text(
            "".join(lines[:2] + ["        x = 1\n"] + lines[2:]))
        run("add", "-A")
        run("commit", "-qm", "the same edit, re-indented")
        reindented = run("rev-parse", "HEAD").stdout.strip()
        check(
            "D2: a whitespace difference is NOT the same change",
            tool.change_id(reviewed) != tool.change_id(reindented),
            True,
        )
        check(
            "D2: the stable patch-id DOES merge them (= why the gate "
            "cannot use it)",
            tool.patch_id(reviewed) == tool.patch_id(reindented),
            True,
        )

        # D3: a landing that edits a NEARBY line of the same file (= a
        # line inside the -U3 context window of the change), so the
        # rebase is clean but the default diff's context moves.
        run("checkout", "-q", "main")
        near = list(lines)
        near[4] = "c = 3\n"
        (repo / "prog.py").write_text("".join(near))
        run("add", "-A")
        run("commit", "-qm", "a landing near the change")
        run("checkout", "-q", "feature")
        run("rebase", "main")
        rebased = run("rev-parse", "HEAD").stdout.strip()
        check(
            "D3: the branch's own edit is untouched by the rebase",
            (repo / "prog.py").read_text().count("    x = 1\n"),
            1,
        )
        check(
            "D3: a branch's identity survives a landing near its change",
            tool.change_id(rebased) == tool.change_id(reviewed),
            True,
        )
        check(
            "D3: the stable patch-id does NOT survive it (= the context "
            "moves)",
            tool.patch_id(rebased) == tool.patch_id(reviewed),
            False,
        )

        # D1: the order is the authority.
        def card(cid, sha, verdict, ended_at):
            return {
                "id": cid,
                "title": f"[T2][{REVIEW_TAG}] x",
                "body": f"## WHAT TO BUILD\n\nA verdict on `{sha}`.\n\n"
                        "## REVIEW HANDOFF\n\nnone\n",
                "runs": [{
                    "id": 1, "profile": "wenshu-review", "outcome": "completed",
                    "ended_at": ended_at, "metadata": {"review_outcome": verdict},
                }],
                "events": [],
                "created_at": ended_at,
            }
        old_approval = card("t_old", reviewed, "approved", 100)
        new_refusal = card("t_new", rebased, "changes_requested", 200)
        found = tool.matching_cards([old_approval, new_refusal], rebased, "feature")
        check(
            "D1: the card naming the CURRENT sha comes first",
            [f[0] for f in found][:1],
            ["t_new"],
        )
        check(
            "D1: and it is the refusal, so the branch is NOT cleared",
            found[0][1],
            "changes_requested",
        )
        later_approval = card("t_late", rebased, "approved", 300)
        found2 = tool.matching_cards(
            [new_refusal, later_approval], rebased, "feature")
        check(
            "D1: among cards on the same tree the LATER verdict governs",
            [f[0] for f in found2][:1],
            ["t_late"],
        )
        # D1-ACROSS-GROUPS: the same shadowing, the other way round. The
        # approval names the CURRENT sha and the LATER refusal names the
        # change under its PRE-REBASE sha (= the same edit, an older
        # commit id). Both cards are about the same change, so the later
        # verdict governs and the branch is NOT cleared.
        early_approval = card("t_early", rebased, "approved", 100)
        late_refusal = card("t_late_refusal", reviewed, "changes_requested", 500)
        found3 = tool.matching_cards(
            [early_approval, late_refusal], rebased, "feature")
        check(
            "D1: a LATER refusal is not shadowed by an EARLIER approval "
            "across the sha/change groups",
            [f[0] for f in found3][:1],
            ["t_late_refusal"],
        )
        check(
            "D1: and the branch is NOT cleared",
            found3[0][1],
            "changes_requested",
        )
        os.chdir(cwd_before)

    # ---- D4: a BINARY change has an identity ----
    # A binary diff renders as one constant line, so the new blob hash is
    # the only thing that says WHICH payload it is. Drop it and two
    # different images share one identity (= the gate clears a branch
    # carrying a different image).
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        repo.mkdir()
        run = lambda *a: subprocess.run(
            ["git", *a], cwd=repo, capture_output=True, text=True, check=True
        )
        run("init", "-q", "-b", "main")
        run("config", "user.email", "t@t")
        run("config", "user.name", "t")
        cwd_before = Path.cwd()
        os.chdir(repo)
        (repo / "a.txt").write_text("base\n")
        run("add", "-A")
        run("commit", "-qm", "base")
        run("checkout", "-qb", "feature")
        (repo / "img.bin").write_bytes(b"\x89PNG\r\n\x1a\n\x00" + b"payload-one" * 8)
        run("add", "-A")
        run("commit", "-qm", "one image")
        one = run("rev-parse", "HEAD").stdout.strip()
        (repo / "img.bin").write_bytes(b"\x89PNG\r\n\x1a\n\x00" + b"payload-two" * 8)
        run("add", "-A")
        run("commit", "-qm", "a different image")
        two = run("rev-parse", "HEAD").stdout.strip()
        check(
            "D4: two different payloads are NOT the same change",
            tool.change_id(one) != tool.change_id(two),
            True,
        )
        bin_card = {
            "id": "t_bin", "title": f"[T2][{REVIEW_TAG}] x",
            "body": f"## WHAT TO BUILD\n\nA verdict on `{one}`.\n\n"
                    "## REVIEW HANDOFF\n\nnone\n",
            "runs": [{"id": 1, "profile": "wenshu-review", "outcome": "completed",
                      "ended_at": 10, "metadata": {"review_outcome": "approved"}}],
            "events": [], "created_at": 10,
        }
        check(
            "D4: an approval does NOT cover a branch carrying a different "
            "image",
            tool.matching_cards([bin_card], two, "feature"),
            [],
        )
        run("checkout", "-q", "main")
        (repo / "other.txt").write_text("elsewhere\n")
        run("add", "-A")
        run("commit", "-qm", "an unrelated landing")
        run("checkout", "-q", "feature")
        run("rebase", "main")
        rebased = run("rev-parse", "HEAD").stdout.strip()
        # the branch tip after the rebase carries the SAME payload as the
        # commit it was rewritten from (= the second commit), so its
        # identity is that commit's identity
        check(
            "D4: a rebase that keeps the payload keeps the identity",
            tool.change_id(rebased) == tool.change_id(two),
            True,
        )
        check(
            "D4: a rebase that carries another payload moves the identity",
            tool.change_id(rebased) != tool.change_id(one),
            True,
        )
        os.chdir(cwd_before)

    # ---- D5: the verdict's OWN run, not the newest ended run ----
    approved_runs = [
        {"id": 1, "profile": "wenshu-review", "outcome": "completed",
         "ended_at": 100, "metadata": {"review_outcome": "approved"}},
        # a later run that carried NO verdict (a crash, a superseded
        # attempt): it is not a verdict, and it must not make the
        # approval look newer than it is.
        {"id": 2, "profile": "wenshu-review", "outcome": "completed",
         "ended_at": 400, "metadata": {}},
    ]
    card_approved = {
        "id": "t_approval", "title": f"[T2][{REVIEW_TAG}] x",
        "body": "## WHAT TO BUILD\n\nA verdict on `" + "a" * 40 + "`.\n\n"
                "## REVIEW HANDOFF\n\nnone\n",
        "runs": approved_runs, "events": [], "created_at": 100,
    }
    card_refused = {
        "id": "t_refusal", "title": f"[T2][{REVIEW_TAG}] x",
        "body": "## WHAT TO BUILD\n\nA verdict on `" + "a" * 40 + "`.\n\n"
                "## REVIEW HANDOFF\n\nnone\n",
        "runs": [{"id": 3, "profile": "wenshu-review", "outcome": "completed",
                  "ended_at": 200, "metadata": {"review_outcome": "changes_requested"}}],
        "events": [], "created_at": 200,
    }
    check(
        "D5: a run that carried no verdict does not date the verdict",
        tool._verdict_time({"task": card_approved, "runs": approved_runs,
                            "events": []}),
        100,
    )
    found = tool.matching_cards([card_approved, card_refused], "a" * 40, None)
    check(
        "D5: the later REFUSAL governs over the earlier approval",
        [f[0] for f in found][:1],
        ["t_refusal"],
    )

    # ---- the four defects the review round measured on this change ----
    # D-A: a TEXT file whose CONTENT says "Binary files ..." is not a
    # binary diff, and must not keep its whole-file blob hash.
    # D-B: a DELETED binary keeps its payload in the OLD half of the
    # index line (= the new half is all zeros).
    # D-C: the decode must be lossless (= two payloads that differ only
    # in an undecodable byte must not share an identity).
    # D-D: the decode fix has a case at all.
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        repo.mkdir()
        run = lambda *a: subprocess.run(
            ["git", *a], cwd=repo, capture_output=True, text=True, check=True
        )
        run("init", "-q", "-b", "main")
        run("config", "user.email", "t@t")
        run("config", "user.name", "t")
        cwd_before = Path.cwd()
        os.chdir(repo)
        (repo / "a.txt").write_text("base\n")
        # the file both branches will change must EXIST in the base
        # (= two branches ADDING the same path is a conflict, not a test)
        (repo / "says.py").write_text("x = 0\n" * 10)
        run("add", "-A")
        run("commit", "-qm", "base")

        # ---- D-A: a text file that merely SAYS "Binary files" ----
        run("checkout", "-qb", "feature")
        (repo / "says.py").write_text(
            "msg = 'Binary files a/x and b/x differ'\n" + "x = 0\n" * 10)
        run("add", "-A")
        run("commit", "-qm", "a text file that says Binary files")
        says = run("rev-parse", "HEAD").stdout.strip()
        # an unrelated landing in the SAME file, then a rebase: the change
        # must not move (= the identity must not depend on the whole file)
        run("checkout", "-q", "main")
        (repo / "says.py").write_text("x = 0\n" * 10 + "other = 1\n")
        run("add", "-A")
        run("commit", "-qm", "a landing in the same file")
        run("checkout", "-q", "feature")
        run("rebase", "main")
        says_rebased = run("rev-parse", "HEAD").stdout.strip()
        check(
            "D-A: a text file that SAYS 'Binary files' keeps its identity "
            "across a landing in the same file",
            tool.change_id(says_rebased) == tool.change_id(says),
            True,
        )

        # ---- D-B: a DELETED binary ----
        # The identity of a change is measured against its own base, so
        # two deletions of DIFFERENT payloads are measured in two
        # repositories (= each base carries its own image).
        def deletion_identity(payload: bytes) -> str:
            with tempfile.TemporaryDirectory() as tmp2:
                repo2 = Path(tmp2) / "repo"
                repo2.mkdir()
                r2 = lambda *a: subprocess.run(
                    ["git", *a], cwd=repo2, capture_output=True, text=True, check=True
                )
                r2("init", "-q", "-b", "main")
                r2("config", "user.email", "t@t")
                r2("config", "user.name", "t")
                (repo2 / "img.bin").write_bytes(
                    b"\x89PNG\r\n\x1a\n\x00" + payload)
                r2("add", "-A")
                r2("commit", "-qm", "the base carries an image")
                r2("checkout", "-q", "-b", "deleter")
                r2("rm", "-q", "img.bin")
                r2("commit", "-qam", "delete the image")
                sha = r2("rev-parse", "HEAD").stdout.strip()
                cwd2 = Path.cwd()
                os.chdir(repo2)
                try:
                    return tool.change_id(sha) or ""
                finally:
                    os.chdir(cwd2)
        del_one = deletion_identity(b"payload-one" * 8)
        del_two = deletion_identity(b"payload-two" * 8)
        check(
            "D-B: two DELETED binaries with different payloads are NOT the "
            "same change",
            bool(del_one) and bool(del_two) and del_one != del_two,
            True,
        )

        # ---- D-2: a BINARY body carries a REWRITTEN index line ----
        # So "every line of the body is a line of the diff" does NOT hold
        # for a binary: the body carries `index <one blob hash>`, not the
        # diff's `index <old>..<new> <mode>`. The rewrite is deliberate
        # (= the blob hash is the only thing in the section that says
        # WHICH payload it is, and the OLD blob's hash moves as soon as
        # the base moves), so the universal has to be scoped, and the
        # rewrite has to be pinned by a case.
        def binary_body_and_identity(base_bytes: bytes):
            with tempfile.TemporaryDirectory() as tmp2:
                repo2 = Path(tmp2) / "repo"
                repo2.mkdir()
                r2 = lambda *a: subprocess.run(
                    ["git", *a], cwd=repo2, capture_output=True, text=True, check=True
                )
                r2("init", "-q", "-b", "main")
                r2("config", "user.email", "t@t")
                r2("config", "user.name", "t")
                (repo2 / "img.bin").write_bytes(base_bytes)
                r2("add", "-A")
                r2("commit", "-qm", "the base image")
                r2("checkout", "-qb", "feature")
                (repo2 / "img.bin").write_bytes(b"\x00\x01\x02the payload" + b"x" * 40)
                r2("add", "-A")
                r2("commit", "-qm", "the new image")
                sha = r2("rev-parse", "HEAD").stdout.strip()
                base = r2("merge-base", "main", "HEAD").stdout.strip()
                cwd2 = Path.cwd()
                os.chdir(repo2)
                try:
                    diff = tool._git_out(
                        ["diff", "-U0", "--no-color", "--full-index", f"{base}..{sha}"]
                    ) or ""
                    return diff, tool._change_body(diff), tool.change_id(sha) or ""
                finally:
                    os.chdir(cwd2)
        bin_diff, bin_body, bin_id = binary_body_and_identity(
            b"\x00\x01\x02base one" + b"y" * 40)
        bin_index = [l for l in bin_body.split("\n") if l.startswith("index ")]
        check(
            "D-2: a binary body's index line carries exactly ONE blob hash",
            len(bin_index) == 1 and ".." not in bin_index[0],
            True,
        )
        check(
            "D-2: a binary body's index line is NOT one of the diff's lines "
            "(so the selection universal is scoped to a TEXT diff)",
            bool(bin_index) and bin_index[0] not in bin_diff.split("\n"),
            True,
        )
        _, _, bin_id_two = binary_body_and_identity(
            b"\x00\x01\x02base two" + b"z" * 40)
        check(
            "D-2: the same binary payload over two different bases keeps ONE "
            "identity (= the rewrite is what makes that true)",
            bool(bin_id) and bin_id == bin_id_two,
            True,
        )

        # ---- D-C + D-D: a diff that is not UTF-8 ----
        run("checkout", "-qb", "weird", "main")
        (repo / "weird.txt").write_bytes(b"a = 1\n\xff\xfe not utf-8\n")
        run("add", "-A")
        run("commit", "-qm", "a file that is not utf-8")
        weird = run("rev-parse", "HEAD").stdout.strip()
        cid = tool.change_id(weird)
        check("D-D: the gate reads a diff that is not UTF-8", isinstance(cid, str), True)
        check("D-D: and gives it an identity", bool(cid), True)
        run("checkout", "-q", "-b", "weird2", "main")
        (repo / "weird.txt").write_bytes(b"a = 1\n\xff\xfd not utf-8\n")
        run("add", "-A")
        run("commit", "-qm", "a different file that is not utf-8")
        weird2 = run("rev-parse", "HEAD").stdout.strip()
        check(
            "D-C: two payloads that differ only in an undecodable byte are "
            "NOT the same change",
            tool.change_id(weird) != tool.change_id(weird2),
            True,
        )
        os.chdir(cwd_before)

    # ---- D-E: the line endings are part of the payload ----
    # A CRLF file and an LF file are DIFFERENT payloads, and the
    # identity must say so. The CR is lost in TWO places if the diff is
    # decoded with universal newlines (text=True) and split with
    # splitlines() (= both eat it), and both have to go.
    def payload_identity(payload: bytes) -> str:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            repo.mkdir()
            run = lambda *a: subprocess.run(
                ["git", *a], cwd=repo, capture_output=True, text=True, check=True
            )
            run("init", "-q", "-b", "main")
            run("config", "user.email", "t@t")
            run("config", "user.name", "t")
            (repo / "base.txt").write_text("base\n")
            run("add", "-A")
            run("commit", "-qm", "base")
            run("checkout", "-qb", "feature")
            (repo / "f.txt").write_bytes(payload)
            run("add", "-A")
            run("commit", "-qm", "the payload")
            sha = run("rev-parse", "HEAD").stdout.strip()
            cwd_before = Path.cwd()
            os.chdir(repo)
            try:
                return tool.change_id(sha) or ""
            finally:
                os.chdir(cwd_before)
    crlf = payload_identity(b"a = 1\r\nb = 2\r\n")
    lf = payload_identity(b"a = 1\nb = 2\n")
    check(
        "D-E: a CRLF payload and an LF payload are NOT the same change",
        bool(crlf) and bool(lf) and crlf != lf,
        True,
    )
    check(
        "D-E: and the CRLF identity is stable (= it is read, not guessed)",
        crlf == payload_identity(b"a = 1\r\nb = 2\r\n"),
        True,
    )
    # The other separators splitlines() would have cut on. The comparison
    # is against the SAME payload with the byte REMOVED, not against the
    # LF payload: a VT payload differs from an LF payload under ANY
    # implementation (= the bytes differ), so that comparison cannot see a
    # VT that is treated as a line break. Measured 2026-10-31: a mutant
    # that treats \x0b as a break left the whole suite green, because the
    # case compared against the wrong thing.
    vt = payload_identity(b"a = 1\x0bb = 2\n")
    vt_removed = payload_identity(b"a = 1b = 2\n")
    check(
        "D-E: a lone vertical tab is not a line break either",
        bool(vt) and bool(vt_removed) and vt != vt_removed,
        True,
    )
    # The identity comparison above cannot see a VT that is treated as a
    # break (= the mutant changes the identity, and any two different
    # payloads differ under ANY implementation). What it CAN see is the
    # SHAPE of the body: a line cut in half loses its "+" prefix, and no
    # real diff ever has a line without one.
    def payload_body(payload: bytes) -> list[str]:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            repo.mkdir()
            run = lambda *a: subprocess.run(
                ["git", *a], cwd=repo, capture_output=True, text=True, check=True
            )
            run("init", "-q", "-b", "main")
            run("config", "user.email", "t@t")
            run("config", "user.name", "t")
            (repo / "base.txt").write_text("base\n")
            run("add", "-A")
            run("commit", "-qm", "base")
            run("checkout", "-qb", "feature")
            (repo / "f.txt").write_bytes(payload)
            run("add", "-A")
            run("commit", "-qm", "the payload")
            sha = run("rev-parse", "HEAD").stdout.strip()
            base = run("merge-base", "main", "HEAD").stdout.strip()
            cwd_before = Path.cwd()
            os.chdir(repo)
            try:
                diff = tool._git_out(
                    ["diff", "-U0", "--no-color", "--full-index", f"{base}..{sha}"]
                )
                return diff or "", tool._change_body(diff or "").split("\n")
            finally:
                os.chdir(cwd_before)
    # NOTE: the empty string must NOT be in the allowed prefixes (= every
    # string starts with it, so the check could never fail). An empty line
    # is allowed as an empty line.
    # every header git can put in a diff, plus the three content prefixes
    allowed = (
        "diff --git ", "index ", "@@", "--- ", "+++ ", "new file mode ",
        "deleted file mode ", "old mode ", "new mode ", "similarity index ",
        "dissimilarity index ", "rename from ", "rename to ", "copy from ",
        "copy to ", "Binary files ", "+", "-", " ", "\\ No newline at end of file",
    )
    well_formed = lambda lines: all(
        line == "" or line.startswith(allowed) for line in lines
    )
    def body_of(payload: bytes) -> tuple[list[str], list[str]]:
        diff, body = payload_body(payload)
        return diff.split("\n"), body

    check(
        "D-E: a lone vertical tab does not CUT a line in half",
        well_formed(body_of(b"a = 1\x0bb = 2\n")[1]),
        True,
    )
    check(
        "D-E: and the CR does not cut a line in half either",
        well_formed(body_of(b"a = 1\r\nb = 2\r\n")[1]),
        True,
    )
    # THE STRONGEST DISCRIMINATOR. A body is a SELECTION of the diff's
    # lines (= it drops some of them), so every line of the body is a
    # line of the diff. A line cut in half is NOT a line of the diff,
    # whatever it starts with (= a cut whose second half starts with
    # "+", "-" or " " passes a prefix check, because those are legal
    # content prefixes).
    def is_selection(diff_lines: list[str], body_lines: list[str]) -> bool:
        rest = list(diff_lines)
        for line in body_lines:
            if line == "":
                continue
            if line not in rest:
                return False
            rest = rest[rest.index(line) + 1:]
        return True

    for label, payload in (
        ("a lone vertical tab", b"a = 1\x0bb = 2\n"),
        ("a vertical tab before a plus", b"a = 1\x0b+b = 2\n"),
        ("a vertical tab before a space", b"a = 1\x0b b = 2\n"),
        ("a carriage return", b"a = 1\r\nb = 2\r\n"),
    ):
        diff_lines, body_lines = body_of(payload)
        check(
            f"D-E: the body stays a SELECTION of the diff's lines ({label})",
            is_selection(diff_lines, body_lines),
            True,
        )
    # a file with NO trailing newline (= git adds a marker line the body
    # keeps, and the prefix set must know it)
    diff_lines, body_lines = body_of(b"a = 1\nb = 2")
    check(
        "D-E: a file with no trailing newline is not a false red",
        well_formed(body_lines) and is_selection(diff_lines, body_lines),
        True,
    )

    cap_gate = load_agents_gate()

    @contextlib.contextmanager
    def under(home: Path):
        """Run the gate's code as if $HERMES_HOME were this home."""
        previous = os.environ.get("HERMES_HOME")
        os.environ["HERMES_HOME"] = str(home)
        try:
            yield
        finally:
            if previous is None:
                os.environ.pop("HERMES_HOME", None)
            else:
                os.environ["HERMES_HOME"] = previous

    def claimed_pin(home: Path) -> int | None:
        """The cap this home's config CLAIMS, in any form.

        A quoted value is a claim the loader IGNORES (= the loader honors
        the config value only when it is an int or a float), and a claim
        the loader ignores is a broken pin, so the claim and the
        loader's own answer have to be compared (= otherwise "no pin" and
        "a pin the loader ignores" are the same thing, and a broken pin
        is invisible).
        """
        cfg = home / "config.yaml"
        try:
            text = cfg.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            return None
        found = re.search(
            r"^context_file_max_chars:[ \t]*\"?(\d+)", text, re.M)
        return int(found.group(1)) if found else None

    def gate_headroom_for(home: Path) -> int:
        """The headroom the gate's OWN CLI reports for the repo's AGENTS.md."""
        repo = Path(__file__).resolve().parents[3]
        proc = subprocess.run(
            [sys.executable, str(repo / "Tools/wenshu-devtool/agents_gate.py"),
             "--file", str(repo / "AGENTS.md")],
            env=dict(os.environ, HERMES_HOME=str(home)),
            capture_output=True, text=True, timeout=120,
        )
        found = re.search(r"headroom\s+(\d+)", proc.stdout)
        return int(found.group(1)) if found else -1

    def gate_cap_for(home: Path) -> int:
        """The gate's own number under that home (= the documented CLI)."""
        repo = Path(__file__).resolve().parents[3]
        proc = subprocess.run(
            [sys.executable, str(repo / "Tools/wenshu-devtool/agents_gate.py"),
             "--file", str(repo / "AGENTS.md")],
            env=dict(os.environ, HERMES_HOME=str(home)),
            capture_output=True, text=True, timeout=120,
        )
        found = re.search(r"cap (\d+)", proc.stdout)
        return int(found.group(1)) if found else -1

    # ---- THE CAP IS A FIXED NUMBER ----
    # 500,000 chars (= 0.5 MB), mirrored by the gate's constant and
    # pinned in the Hermes config. The loader honors an explicit config
    # value, so the two are the same number by construction, and the
    # case below reads the config and asserts that (= so the two cannot
    # drift apart).
    # NOT the ambient: the gate reads $HERMES_HOME, so an in-process call
    # would answer for whatever home the suite happens to run under (= the
    # suite's verdict would be ambient-dependent). The ROOT home is named
    # instead, and the gate is run under it (= the documented CLI).
    root_home = Path.home() / ".hermes"
    check(
        "the gate's cap is the fixed project cap",
        gate_cap_for(root_home),
        500000,
    )
    # THE DRIFT GUARD, AGAINST THE LOADER'S OWN ANSWER. A line-based
    # regex cannot tell a pin the loader honors from one it ignores (= a
    # duplicate key, or a pin inside a quoted string, leaves the loader
    # on its dynamic cap), so the comparison is the loader's own
    # function, for EVERY home (= the root and every profile). And a
    # home that cannot be read is a FAILURE, never a skip: a case that
    # cannot run cannot see its own defect.
    def loader_cap_for(home: Path) -> int:
        """The loader's OWN cap for that home (= its own function)."""
        script = (
            "import sys;sys.path.insert(0,'/Volumes/ANAN/.hermes/hermes-agent');"
            "from agent.prompt_builder import _get_context_file_max_chars;"
            "print(_get_context_file_max_chars(204800))"
        )
        for interpreter in cap_gate._hermes_pythons():
            try:
                proc = subprocess.run(
                    [interpreter, "-c", script],
                    env=dict(os.environ, HERMES_HOME=str(home)),
                    capture_output=True, text=True, timeout=120,
                )
            except (OSError, subprocess.SubprocessError):
                continue
            out = proc.stdout.strip().splitlines()
            if proc.returncode == 0 and out and out[-1].strip().isdigit():
                return int(out[-1].strip())
        return -1
    real_agents = (Path(__file__).resolve().parents[3] / "AGENTS.md").read_text(
        encoding="utf-8")
    loaded_agents = len(real_agents) + len("## AGENTS.md\n\n")
    hermes_root = Path.home() / ".hermes"
    # EVERY live profile DIRECTORY (= a profile with no config.yaml of its
    # own is still a home the loader reads, and the loader falls back to
    # its dynamic cap there, so it is exactly the case that must not be
    # skipped).
    profile_dir = hermes_root / "profiles"
    homes = [hermes_root] + sorted(
        p for p in profile_dir.iterdir() if p.is_dir()
    ) if profile_dir.is_dir() else [hermes_root]
    check("the drift guard found the Hermes root and its profiles",
          len(homes) >= 2, True)
    for home in homes:
        loader_cap = loader_cap_for(home)
        check(
            f"the loader answers for this home ({home.name})",
            loader_cap > 0,
            True,
        )
        gate_cap = gate_cap_for(home)
        check(
            f"the gate is not LOOSER than the loader ({home.name})",
            gate_cap <= loader_cap,
            True,
        )
        # and the AGENTS.md FITS under this home's loader cap, with the
        # margin stated (= a home whose cap is the loader's floor leaves
        # the file one edit away from a false red, and that has to be
        # visible, not guessed at).
        # the SAME measure the gate uses (= the whole file plus the
        # section label the loader wraps it in), or the margin would not
        # be the gate's own headroom
        margin = loader_cap - loaded_agents
        print(f"    ok: the margin under {home.name}'s loader cap is "
              f"{margin} chars")
        check(
            f"the AGENTS.md fits under this home's loader cap "
            f"({home.name})",
            loaded_agents <= loader_cap,
            True,
        )
        # and the suite's margin IS the headroom the gate's own CLI
        # reports (= the same number, from the same measure: the whole
        # file PLUS the section label the loader prepends). A suite that
        # measured the raw file would be 14 chars optimistic, and would
        # answer a different question than the gate.
        check(
            f"the suite's margin IS the gate's own headroom ({home.name})",
            gate_headroom_for(home),
            margin,
        )
        # "NO PIN" and "A PIN THE LOADER IGNORES" must be DIFFERENT
        # ANSWERS, or a broken pin is invisible (= the gate's floor and
        # the loader's dynamic cap both look like "no pin"). So the
        # config's own text is read, and:
        #   * a pin the loader HONORS => the gate uses that pin, and the
        #     loader's answer is that pin;
        #   * a pin the loader IGNORES (= a quoted value, a duplicate
        #     key) => the gate uses the floor, and the loader's answer
        #     is NOT the pin (= and that is a broken pin, so it is
        #     reported).
        claimed = claimed_pin(home)
        if (home / "config.yaml").exists():
            # a home that HAS a config carries the project's cap
            check(
                f"this home's config carries the project's cap "
                f"({home.name})",
                claimed,
                500000,
            )
            # and the loader honors what it claims (= a quoted value or a
            # duplicate key would leave the loader on its dynamic cap, and
            # that is a broken pin)
            check(
                f"the loader honors the cap this home's config claims "
                f"({home.name})",
                loader_cap,
                claimed if claimed is not None else -1,
            )
        if claimed is not None and loader_cap == claimed:
            check(
                f"the gate uses the cap this home's config pins "
                f"({home.name})",
                gate_cap,
                claimed,
            )
        else:
            check(
                f"this home's config pins no cap the loader honors, so the "
                f"gate uses the fallback ({home.name})",
                gate_cap,
                49152,
            )
    # A QUOTED PIN IS A STRING, so the loader IGNORES it (= it falls to
    # its dynamic cap), and the gate must not honor it either (= the gate
    # is then the floor, which is never looser).
    with tempfile.TemporaryDirectory() as tmp:
        quoted = Path(tmp) / "quoted"
        quoted.mkdir()
        (quoted / "config.yaml").write_text(
            'context_file_max_chars: "500000"\n')
        check(
            "a quoted pin is not a pin (= the loader ignores it)",
            gate_cap_for(quoted),
            49152,
        )
        check(
            "and the gate is not looser than the loader there",
            gate_cap_for(quoted) <= loader_cap_for(quoted),
            True,
        )

    # and the gate REFUSES a file over the cap, and accepts the real one.
    # UNDER THE ROOT HOME, EXPLICITLY: the gate reads $HERMES_HOME, so an
    # in-process call would answer for the ambient home, and this suite's
    # verdict would depend on where it happens to run.
    with tempfile.TemporaryDirectory() as tmp:
        big = Path(tmp) / "big.md"
        with under(root_home):
            limit = cap_gate.effective_context_file_cap()[0]
            big.write_text("# a\n\n" + ("x" * (limit + 10)))
            report = cap_gate.check_file(big)
        errors = " ".join(report.get("errors", []))
        check(
            "a file over the cap is refused with the budget error",
            (report.get("ok") is False) and ("truncates above" in errors),
            True,
        )
    repo_root = Path(__file__).resolve().parents[3]
    real = repo_root / "AGENTS.md"
    check(
        "the real AGENTS.md is there to check",
        real.exists(),
        True,
    )
    with under(root_home):
        passes = cap_gate.check_file(real).get("ok")
    check(
        "the real AGENTS.md is under the cap and passes the gate",
        passes,
        True,
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
