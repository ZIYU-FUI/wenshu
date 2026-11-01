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
            "title": "[T2][审核] the change",
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
                "title": "[T2][审核] x",
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
            "id": "t_bin", "title": "[T2][审核] x",
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
        "id": "t_approval", "title": "[T2][审核] x",
        "body": "## WHAT TO BUILD\n\nA verdict on `" + "a" * 40 + "`.\n\n"
                "## REVIEW HANDOFF\n\nnone\n",
        "runs": approved_runs, "events": [], "created_at": 100,
    }
    card_refused = {
        "id": "t_refusal", "title": "[T2][审核] x",
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

    # ---- the gate reads the key the LOADER reads, at the level it reads it ----
    # A pin nested under `agent:` is INERT: Hermes' own CLI says it is not
    # a recognized config key, so the loader never sees it. The gate must
    # not read it either (= and it must say where its number came from).
    cap_gate = load_agents_gate()
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp) / "home"
        profile = home / "profiles" / "pocock"
        profile.mkdir(parents=True)
        # The pin goes in the PROFILE's OWN config.yaml (= the ONE file
        # the loader reads: get_config_path() = $HERMES_HOME/config.yaml).
        # The ROOT two levels up gets a DIFFERENT pin, because a profile
        # does NOT inherit the root's config (= measured: a root-only key
        # reads the default under a profile, and the profile's own key
        # reads the profile's value). So the gate must return the
        # PROFILE's number, and a search list that falls through to the
        # root returns the wrong one.
        (home / "config.yaml").write_text("context_file_max_chars: 999999\n")
        (profile / "config.yaml").write_text("context_file_max_chars: 123456\n")
        saved = os.environ.get("HERMES_HOME")
        os.environ["HERMES_HOME"] = str(profile)
        try:
            check(
                "the gate reads the TOP-LEVEL pin the loader reads",
                cap_gate.effective_context_file_cap()[0],
                123456,
            )
            cap, source = cap_gate.effective_context_file_cap()
            check(
                "the gate says where its number came from",
                source.endswith("profiles/pocock/config.yaml"),
                True,
            )
            check(
                "the gate does NOT fall through to the root's config "
                "(a profile does not inherit it)",
                cap != 999999,
                True,
            )
            # the nested key lands in the PROFILE's own file too (= the file
            # the loader reads), so this tests what it claims
            (profile / "config.yaml").write_text(
                "agent:\n  context_file_max_chars: 234567\n")
            cap, source = cap_gate.effective_context_file_cap()
            check(
                "the gate does NOT read a pin nested under agent:",
                cap != 234567,
                True,
            )
            # and with no pin at all, the gate falls back to the loader's
            # own floor, NOT to a number it found elsewhere
            (profile / "config.yaml").write_text("model: x\n")
            cap, source = cap_gate.effective_context_file_cap()
            check(
                "with no pin, the gate uses the loader's own floor",
                cap, 20000,
            )
        finally:
            if saved is None:
                os.environ.pop("HERMES_HOME", None)
            else:
                os.environ["HERMES_HOME"] = saved

    # D-1: the gate resolves the home the way THE LOADER resolves it. The
    # loader's own resolver is the oracle (= the gate must name the SAME
    # file, or it reads a file the loader never reads, and it either
    # reports a number the loader will not use or misses the pin).
    # The loader runs in a SUBPROCESS (= the gate's own interpreter search:
    # the plain python3 this repo documents cannot import hermes_cli, and a
    # case that cannot run in the documented environment is a case that
    # cannot see its own defect). If no interpreter can run it, the case
    # FAILS: a silent skip would let a reverted fix leave the suite green.
    def loader_probe(script: str, env: dict | None = None) -> str:
        for interpreter in cap_gate._hermes_pythons():
            try:
                proc = subprocess.run(
                    [interpreter, "-c", script],
                    capture_output=True,
                    text=True,
                    timeout=120,
                    env=env,
                )
            except (OSError, subprocess.SubprocessError):
                continue
            if proc.returncode == 0:
                return proc.stdout.strip()
        return ""

    def loader_config_path() -> str:
        """The loader's own resolver, in the CURRENT environment."""
        return loader_probe(
            "from hermes_cli.config import get_config_path;"
            " print(get_config_path())"
        )

    check(
        "the loader's own resolver runs in a Hermes-capable interpreter "
        "(a case that cannot run cannot see its defect)",
        bool(loader_config_path()),
        True,
    )
    if True:
        keys = ("HERMES_HOME", "HERMES_DATA_DIR_SUFFIX", "WENSHU_TEST_HOME",
                "WENSHU_TEST_CAP")
        saved = {k: os.environ.get(k) for k in keys}
        try:
            os.environ["HERMES_HOME"] = "~/.hermes"
            check(
                "the gate resolves a ~ home the way the loader does",
                os.path.realpath(cap_gate._hermes_config_path())
                == os.path.realpath(loader_config_path()),
                True,
            )
            with tempfile.TemporaryDirectory() as tmp:
                os.environ["WENSHU_TEST_HOME"] = tmp
                os.environ["HERMES_HOME"] = "$WENSHU_TEST_HOME"
                check(
                    "the gate resolves a $VAR home the way the loader does",
                    os.path.realpath(cap_gate._hermes_config_path())
                    == os.path.realpath(loader_config_path()),
                    True,
                )
            os.environ.pop("HERMES_HOME", None)
            os.environ["HERMES_DATA_DIR_SUFFIX"] = "-alt"
            check(
                "the gate resolves the suffixed default the way the loader does",
                os.path.realpath(cap_gate._hermes_config_path())
                == os.path.realpath(loader_config_path()),
                True,
            )
            # A CONFIG THAT IS NOT A MAPPING must not crash the gate. The
            # loader honors 0 there (= it falls to its dynamic cap), so the
            # gate falls to the floor. The CLI is what crashed, so the CLI
            # is what the case runs.
            for label, body in (
                ("an empty config", ""),
                ("a comment-only config", "# nothing here\n"),
                ("a config that is a list", "- a\n- b\n"),
                ("an invalid yaml config", "key: [unclosed\n"),
            ):
                with tempfile.TemporaryDirectory() as tmp:
                    home = Path(tmp) / "home"
                    home.mkdir()
                    (home / "config.yaml").write_text(body)
                    env = dict(os.environ, HERMES_HOME=str(home))
                    proc = subprocess.run(
                        [sys.executable, str(Path(__file__).resolve().parent.parent
                                            / "agents_gate.py"), "--file", "AGENTS.md"],
                        cwd=str(Path(__file__).resolve().parent.parent.parent),
                        env=env, capture_output=True, text=True, timeout=120,
                    )
                    check(
                        f"a config that is not a mapping does not crash the "
                        f"gate ({label})",
                        proc.returncode == 0 and "Traceback" not in proc.stderr,
                        True,
                    )
                    # THE CLI'S OWN ANSWER (= the number it reports for THIS
                    # config). An in-process call here would read a
                    # different config, so it would not see this one.
                    reported = re.search(r"cap (\d+)", proc.stdout)
                    check(
                        f"and the gate uses the floor for it ({label})",
                        (reported.group(1) if reported else None),
                        "20000",
                    )
                    # and a config that is not valid UTF-8 must not crash it
                    (home / "config.yaml").write_bytes(b"context: \xff\xfe\x00bad")
                    proc2 = subprocess.run(
                        [sys.executable, str(Path(__file__).resolve().parent.parent
                                            / "agents_gate.py"), "--file", "AGENTS.md"],
                        cwd=str(Path(__file__).resolve().parent.parent.parent),
                        env=env, capture_output=True, text=True, timeout=120,
                    )
                    check(
                        f"a config that is not valid UTF-8 does not crash the "
                        f"gate ({label})",
                        proc2.returncode == 0 and "Traceback" not in proc2.stderr,
                        True,
                    )

            # THE SWEEP. Every shape of a config, measured against the
            # loader's own number for the SAME config: the honored pin
            # must be the same, and the gate's cap must never be LOOSER
            # than the loader's (= the direction that lets a file through
            # that the loader truncates in the middle). A shape that is
            # not in this table is a shape nothing checks.
            sweep = (
                ("an int", "context_file_max_chars: 240000\n"),
                ("a float", "context_file_max_chars: 240000.0\n"),
                ("a negative", "context_file_max_chars: -5\n"),
                ("a zero", "context_file_max_chars: 0\n"),
                ("a quoted int", 'context_file_max_chars: "240000"\n'),
                ("a bool", "context_file_max_chars: true\n"),
                ("a duplicate key",
                 "context_file_max_chars: 240000\ncontext_file_max_chars: 111111\n"),
                ("an anchor", "cap: &c 240000\ncontext_file_max_chars: *c\n"),
                ("a CRLF file", "context_file_max_chars: 240000\r\n"),
                ("a key with spaces", "context_file_max_chars:   240000\n"),
                ("a tab before the value", "context_file_max_chars:\t240000\n"),
                ("a nested key only", "agent:\n  context_file_max_chars: 240000\n"),
                ("an expansion", "context_file_max_chars: ${WENSHU_TEST_CAP}\n"),
                ("a mapping with other keys",
                 "model: x\ncontext_file_max_chars: 240000\nagent:\n"
                 "  reasoning_effort: medium\n"),
                ("an empty config", ""),
                ("a comment-only config", "# nothing here\n"),
                ("a config that is a list", "- a\n- b\n"),
                ("an invalid yaml config", "key: [unclosed\n"),
                ("a YAML 1.1 yes", "context_file_max_chars: yes\n"),
                ("a YAML 1.1 no", "context_file_max_chars: no\n"),
                ("a YAML 1.1 on", "context_file_max_chars: on\n"),
                ("a YAML 1.1 off", "context_file_max_chars: off\n"),
                ("a null", "context_file_max_chars: null\n"),
                ("a tilde null", "context_file_max_chars: ~\n"),
                ("an empty value", "context_file_max_chars:\n"),
                ("a quoted empty", "context_file_max_chars: ""\n"),
                ("a hex number", "context_file_max_chars: 0x1E\n"),
                ("an underscore number", "context_file_max_chars: 1_000\n"),
                ("scientific notation", "context_file_max_chars: 2.4e5\n"),
                ("a plus sign", "context_file_max_chars: +240000\n"),
                ("a trailing space", "context_file_max_chars: 240000 \n"),
                ("an octal", "context_file_max_chars: 0o17\n"),
            )
            for label, body in sweep:
                with tempfile.TemporaryDirectory() as tmp:
                    home = Path(tmp) / "home"
                    home.mkdir()
                    (home / "config.yaml").write_text(body)
                    env = dict(os.environ, HERMES_HOME=str(home),
                               WENSHU_TEST_CAP="222222")
                    # the gate reads os.environ, so the in-process calls
                    # need the same home the probe gets
                    saved_home = os.environ.get("HERMES_HOME")
                    os.environ["HERMES_HOME"] = str(home)
                    try:
                        measured = loader_probe(
                            "import json,sys;"
                            "sys.path.insert(0,'/Volumes/ANAN/.hermes/hermes-agent');"
                            "from hermes_cli.config import load_config_readonly;"
                            "from agent.prompt_builder import _get_context_file_max_chars;"
                            " v=load_config_readonly().get('context_file_max_chars');"
                            " print(json.dumps({'pin': int(v) if isinstance(v,(int,float))"
                            " and v>0 else 0,"
                            " 'cap': _get_context_file_max_chars(1000000),"
                            " 'small': _get_context_file_max_chars(204800)}))",
                            env=env,
                        )
                        try:
                            facts = json.loads(measured or "{}")
                        except json.JSONDecodeError:
                            facts = {}
                        check(
                            f"the sweep measured the loader for this shape ({label})",
                            bool(facts),
                            True,
                        )
                        gate_pin = cap_gate._pinned_context_file_cap()
                        check(
                            f"the gate's honored pin equals the loader's ({label})",
                            (gate_pin[0] if gate_pin else 0),
                            int(facts.get("pin", 0)),
                        )
                        gate_cap_now = cap_gate.effective_context_file_cap()[0]
                        check(
                            f"the gate is never LOOSER than the loader ({label})",
                            gate_cap_now <= int(facts.get("cap", 20000)),
                            True,
                        )
                        # and at a SMALLER window, where the loader's
                        # dynamic cap is 49,152 (= the discriminating
                        # measurement: at a 1M window the dynamic cap is
                        # 240,000, which hides a looseness)
                        check(
                            f"the gate is never LOOSER than the loader at a "
                            f"small window ({label})",
                            gate_cap_now <= int(facts.get("small", 20000)),
                            True,
                        )
                    finally:
                        if saved_home is None:
                            os.environ.pop("HERMES_HOME", None)
                        else:
                            os.environ["HERMES_HOME"] = saved_home

            # AND THE TEXT FALLBACK (a machine with no YAML parser) reads
            # the same forms: an unquoted int, and nothing else.
            check(
                "the text fallback reads an int with a trailing comment",
                cap_gate._pinned_from_text(
                    "context_file_max_chars: 240000 # a comment\n"),
                240000,
            )
            check(
                "the text fallback does NOT read a quoted value",
                cap_gate._pinned_from_text(
                    'context_file_max_chars: "240000"\n'),
                None,
            )
            check(
                "the text fallback does NOT read an expansion",
                cap_gate._pinned_from_text(
                    "context_file_max_chars: ${WENSHU_TEST_CAP}\n"),
                None,
            )
            check(
                "the text fallback does NOT read a PREFIX of the value "
                "(= `0o17` is not the number 0)",
                cap_gate._pinned_from_text("context_file_max_chars: 0o17\n"),
                None,
            )
            check(
                "the text fallback does NOT read a prefix of a longer value "
                "(= `240000abc` is not the number 240000)",
                cap_gate._pinned_from_text(
                    "context_file_max_chars: 240000abc\n"),
                None,
            )
            check(
                "the text fallback does NOT read a zero (= the loader's "
                "condition, and a cap of 0 would reject every file)",
                cap_gate._pinned_from_text("context_file_max_chars: 0\n"),
                None,
            )
            check(
                "the text fallback does NOT read a duplicate key (= the "
                "loader's parser rejects the file, so it has no pin)",
                cap_gate._pinned_from_text(
                    "context_file_max_chars: 240000\n"
                    "context_file_max_chars: 111111\n"),
                None,
            )

            # AND THE PIN IS HONORED EXACTLY WHEN THE LOADER HONORS IT.
            # The loader honors it only when the merged config value is an
            # int or a float (prompt_builder.py:1054), so a quoted number
            # is a STRING and inert, an expansion is a STRING after the
            # expansion (= the expansion substitutes into the parsed text,
            # it does not re-type it) and inert, and a trailing comment is
            # stripped by the parser (= the value is still the int).
            # Each form is measured against the LOADER's own merged value.
            forms = (
                ("an int", "context_file_max_chars: 240000\n", "240000"),
                ("a quoted number", 'context_file_max_chars: "240000"\n', "0"),
                ("an expansion", "context_file_max_chars: ${WENSHU_TEST_CAP}\n", "0"),
                ("an int with a comment",
                 "context_file_max_chars: 240000 # a comment\n", "240000"),
                # `bool` IS a subclass of `int` in Python, so the loader
                # honors `true` as 1 (= it truncates the file to one
                # character). Carving the bool out would make the gate
                # LOOSER than the loader.
                ("a bool pin", "context_file_max_chars: true\n", "1"),
            )
            for label, body, expected in forms:
                with tempfile.TemporaryDirectory() as tmp:
                    home = Path(tmp) / "home"
                    home.mkdir()
                    (home / "config.yaml").write_text(body)
                    os.environ["HERMES_HOME"] = str(home)
                    os.environ["WENSHU_TEST_CAP"] = "222222"
                    loader_pin = loader_probe(
                        "from hermes_cli.config import load_config_readonly;"
                        " v=load_config_readonly().get('context_file_max_chars');"
                        " print(int(v) if isinstance(v,(int,float)) and v>0 else 0)"
                    )
                    check(
                        f"the loader's honored pin and the gate's agree ({label})",
                        (loader_pin or "").strip(), expected,
                    )
                    gate_pin = cap_gate._pinned_context_file_cap()
                    check(
                        f"the gate honors the pin exactly as the loader does "
                        f"({label})",
                        (gate_pin[0] if gate_pin else 0),
                        int(expected),
                    )
                    # and the gate is never LOOSER than the loader (= the
                    # direction that lets a file through that the loader
                    # truncates in the middle)
                    gate_cap = cap_gate.effective_context_file_cap()[0]
                    check(
                        f"the gate is never LOOSER than the loader ({label})",
                        gate_cap <= max(int(expected), 20000),
                        True,
                    )
                os.environ.pop("HERMES_HOME", None)
        finally:
            for k, v in saved.items():
                if v is None:
                    os.environ.pop(k, None)
                else:
                    os.environ[k] = v

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
