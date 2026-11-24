#!/usr/bin/env python3
"""test_plan_gate.py — the plan-of-record gate's own test suite.

Every case builds a FIXTURE plan under a temporary directory, so the suite
never depends on the repo's real `.scratch/` tree (a card worktree's
`.scratch/` is deleted with the worktree, so a suite that read one would
pass on one machine and fail on the next).

The cases:

  1. a complete plan passes.
  2. a plan with no spec.md fails, and the finding says so.
  3. a spec missing one of the four canonical sections fails, and the
     finding names the missing section.
  4. the Chinese heading spelling passes (= 2 of the repo's 9 specs use it).
  5. an issues/ directory that holds no ticket file fails.
  6. a plan with no issues/_index.md fails.
  7. a blocked-by edge naming an issue that does not exist fails, and the
     finding names the edge.
  8. a blocked-by edge naming an issue that exists passes.
  9. the gate reads the SHARED checkout, never a worktree's own `.scratch/`.
 10. the CLI exits 0 on a complete plan and 1 on an incomplete one, and
     prints the plan it read and the scope it read it for.
 11. a card body names its plan of record by the `.scratch/<scope>/` path
     it carries.

Run:  python3 Tools/wenshu-devtool/tests/test_plan_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "plan_gate.py"

FAILURES: list[str] = []


def load_tool():
    """Import plan_gate.py as a module, whatever its directory is."""
    spec = importlib.util.spec_from_file_location("plan_gate", TOOL)
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


# The Chinese heading spellings, as the repo's own Chinese spec writes them.
#
# = = These four literals are DATA the gate must recognise (= AGENTS.md 1.1's
# = = test-fixture exemption), = = so they carry the CJK the repo's own spec
# = = carries, = = and they are the fixture's own text and not a comment.
ZH_BUSINESS = "业务"
ZH_CURRENT = "现状"
ZH_APPLE = "Apple 官方依据"
ZH_AFTER = "改完是什么样"


def english_spec() -> str:
    """A spec carrying the four canonical sections in English."""
    return "\n".join(
        [
            "# Fixture scope",
            "",
            "## 1. Business",
            "",
            "why this scope exists",
            "",
            "## 2. Current state",
            "",
            "what the tree does today",
            "",
            "## 3. Apple canonical",
            "",
            "what Apple ships",
            "",
            "## 4. After the fix",
            "",
            "what the tree does after",
            "",
        ]
    )


def chinese_spec() -> str:
    """A spec carrying the four canonical sections in the Chinese spelling."""
    return "\n".join(
        [
            "# Fixture scope",
            "",
            f"## {ZH_BUSINESS}",
            "",
            "why this scope exists",
            "",
            f"## {ZH_CURRENT}",
            "",
            "what the tree does today",
            "",
            f"## {ZH_APPLE}",
            "",
            "what Apple ships",
            "",
            f"## {ZH_AFTER}",
            "",
            "what the tree does after",
            "",
        ]
    )


def index_text(blocked_by: str = "-") -> str:
    """An index in the tracker convention (= a table with a Blocked by column)."""
    return "\n".join(
        [
            "# Index - fixture scope",
            "",
            "| Issue | State | Blocked by |",
            "| ----- | ----- | ---------- |",
            "| 001-first-ticket | new | - |",
            f"| 002-second-ticket | new | {blocked_by} |",
            "",
        ]
    )


def make_plan(
    root: Path,
    scope: str,
    spec: str | None = None,
    index: str | None = None,
    tickets: tuple[str, ...] = ("001-first-ticket.md", "002-second-ticket.md"),
) -> Path:
    """Write a fixture plan under a root, and return the plan directory."""
    plan = root / ".scratch" / scope
    (plan / "issues").mkdir(parents=True, exist_ok=True)
    if spec is not None:
        (plan / "spec.md").write_text(spec, encoding="utf-8")
    for ticket in tickets:
        (plan / "issues" / ticket).write_text(f"# {ticket}\n", encoding="utf-8")
    if index is not None:
        (plan / "issues" / "_index.md").write_text(index, encoding="utf-8")
    return plan


def run_main(tool, argv: list[str]) -> tuple[int, str]:
    """Run the tool's own main() and capture what it printed."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = tool.main(argv)
    return code, out.getvalue()


def main() -> int:
    tool = load_tool()
    print("plan_gate: the plan-of-record gate\n")

    with tempfile.TemporaryDirectory() as tmp:
        # The gate resolves the repo it was handed (plan_gate.main does
        # Path(args.repo).resolve()), so the fixture root must be compared
        # in its resolved form. Measured 2026-11-24: with TMPDIR on a
        # symlinked root (= /tmp -> /private/tmp) the unresolved string
        # never appears in the gate's output and the CLI case failed for a
        # reason that had nothing to do with the plan.
        root = Path(tmp).resolve()

        # 1. a complete plan passes.
        repo = root / "repo-complete"
        make_plan(repo, "scope-good", spec=english_spec(), index=index_text())
        report = tool.check_scope(repo, "scope-good")
        check("a complete plan passes", report["ok"], True)
        check("a complete plan has no findings", report["findings"], [])
        check(
            "a complete plan carries the four canonical sections",
            report["spec"]["sections"],
            ["business", "current state", "apple canonical", "after fix"],
        )
        check(
            "a complete plan reads the repo it was given",
            report["shared_checkout"],
            str(repo),
        )

        # 2. no spec.md fails, and the finding says so.
        repo = root / "repo-no-spec"
        make_plan(repo, "scope-nospec", spec=None, index=index_text())
        report = tool.check_scope(repo, "scope-nospec")
        check("a plan with no spec.md fails", report["ok"], False)
        check(
            "the finding names the missing spec.md",
            any("spec.md" in finding for finding in report["findings"]),
            True,
        )

        # 3. a spec missing one section fails, and names the missing one.
        repo = root / "repo-partial-spec"
        partial = "\n".join(
            line for line in english_spec().splitlines() if "Current state" not in line
        )
        make_plan(repo, "scope-partial", spec=partial, index=index_text())
        report = tool.check_scope(repo, "scope-partial")
        check("a spec missing one section fails", report["ok"], False)
        check(
            "the finding names the missing section",
            any("'current state'" in finding for finding in report["findings"]),
            True,
        )
        check(
            "the missing section is named in the report",
            report["spec"]["missing"],
            ["current state"],
        )

        # 4. the Chinese spelling passes.
        repo = root / "repo-chinese"
        make_plan(repo, "scope-zh", spec=chinese_spec(), index=index_text())
        report = tool.check_scope(repo, "scope-zh")
        check("the Chinese heading spelling passes", report["ok"], True)
        check(
            "the Chinese spelling names the same four sections",
            report["spec"]["sections"],
            ["business", "current state", "apple canonical", "after fix"],
        )

        # 5. an issues/ directory with no ticket fails.
        repo = root / "repo-no-ticket"
        make_plan(
            repo,
            "scope-noticket",
            spec=english_spec(),
            index=index_text(),
            tickets=(),
        )
        report = tool.check_scope(repo, "scope-noticket")
        check("an issues/ directory with no ticket fails", report["ok"], False)
        check(
            "the finding names the missing ticket file",
            any("ticket file" in finding for finding in report["findings"]),
            True,
        )

        # 6. no _index.md fails.
        repo = root / "repo-no-index"
        make_plan(repo, "scope-noindex", spec=english_spec(), index=None)
        report = tool.check_scope(repo, "scope-noindex")
        check("a plan with no _index.md fails", report["ok"], False)
        check(
            "the finding names the missing _index.md",
            any("_index.md" in finding for finding in report["findings"]),
            True,
        )

        # 7. an edge naming an issue that does not exist fails.
        repo = root / "repo-dangling-edge"
        make_plan(
            repo,
            "scope-dangling",
            spec=english_spec(),
            index=index_text(blocked_by="009"),
            tickets=("001-first-ticket.md",),
        )
        report = tool.check_scope(repo, "scope-dangling")
        check("a dangling blocked-by edge fails", report["ok"], False)
        check(
            "the finding names the edge",
            any(
                "002-second-ticket -> 009" in finding
                for finding in report["findings"]
            ),
            True,
        )
        check(
            "the dangling edge is reported as unresolved",
            [edge["resolved"] for edge in report["edges"]],
            [False],
        )

        # 8. an edge naming an issue that exists passes.
        repo = root / "repo-live-edge"
        make_plan(
            repo,
            "scope-live",
            spec=english_spec(),
            index=index_text(blocked_by="001"),
            tickets=("001-first-ticket.md", "002-second-ticket.md"),
        )
        report = tool.check_scope(repo, "scope-live")
        check("a resolved blocked-by edge passes", report["ok"], True)
        check(
            "the resolved edge is reported as resolved",
            [edge["resolved"] for edge in report["edges"]],
            [True],
        )

        # 9. the gate reads the SHARED checkout, never a worktree's own copy.
        shared = root / "shared"
        (shared / ".git" / "worktrees" / "wt").mkdir(parents=True)
        make_plan(shared, "scope-shared", spec=english_spec(), index=index_text())
        worktree = root / "worktree"
        worktree.mkdir()
        (worktree / ".git").write_text(
            f"gitdir: {shared / '.git' / 'worktrees' / 'wt'}\n", encoding="utf-8"
        )
        # The worktree carries its OWN plan, and it is the broken one: a gate
        # that read the worktree would report a failure the shared checkout
        # does not have.
        make_plan(worktree, "scope-shared", spec=None, index=None)
        report = tool.check_scope(worktree, "scope-shared")
        check("the gate reads the shared checkout, not the worktree", report["ok"], True)
        check(
            "the shared checkout is the one the gate names",
            report["shared_checkout"],
            str(shared),
        )
        check(
            "the shared checkout's spec is the one the gate read",
            report["spec"]["exists"],
            True,
        )

        # 10. the CLI's exit code and its output.
        repo = root / "repo-cli"
        make_plan(repo, "scope-cli", spec=english_spec(), index=index_text())
        code, out = run_main(
            tool, ["--scope", "scope-cli", "--repo", str(repo)]
        )
        good_repo = repo
        check("the CLI exits 0 on a complete plan", code, 0)
        check(
            "the CLI prints the scope it read it for",
            "scope-cli" in out,
            True,
        )
        check(
            "the CLI prints the plan it read",
            str(repo / ".scratch" / "scope-cli" / "spec.md") in out,
            True,
        )

        repo = root / "repo-cli-bad"
        make_plan(repo, "scope-cli-bad", spec=None, index=index_text())
        code, out = run_main(
            tool, ["--scope", "scope-cli-bad", "--repo", str(repo)]
        )
        check("the CLI exits 1 on an incomplete plan", code, 1)
        check(
            "the CLI names what is missing",
            "spec.md" in out,
            True,
        )

        code, out = run_main(
            tool, ["--scope", "scope-cli", "--repo", str(good_repo), "--json"]
        )
        check("the CLI exits 0 in --json mode", code, 0)
        check("the CLI prints JSON in --json mode", out.strip().startswith("{"), True)

        # 11. a card body names its plan of record by the path it carries.
        body = "\n".join(
            [
                "## WHAT TO BUILD",
                "",
                "The plan of record is `.scratch/2026-11-24-flow-gates/spec.md`.",
                "",
            ]
        )
        check(
            "a card body names its scope by the .scratch path it carries",
            tool.extract_scopes(body),
            ["2026-11-24-flow-gates"],
        )
        check(
            "a card body naming no scope names none",
            tool.extract_scopes("## WHAT TO BUILD\n\nBuild the thing.\n"),
            [],
        )

        # 12. an index row must name a ticket that EXISTS. = = = = = = = = =
        # = = = = = A row is the plan's list of its tickets, = = = = = = = = =
        # = = = = = and a row naming a ticket that is not there is a row that
        # = = = = = lies about the plan: = = = = = the closeout gate reads the
        # = = = = = ROWS (= = = = = the ticket set), = = = = = so a stale row is
        # = = = = = a ticket the scope waits for that can never land.
        stale = root / "repo-stale-row"
        make_plan(
            stale,
            "scope-stale-row",
            spec=english_spec(),
            index=index_text(),
            tickets=("001-first-ticket.md",),
        )
        report = tool.check_scope(stale, "scope-stale-row")
        check("the plan with a stale index row is not ok", report["ok"], False)
        check(
            "the stale index row is named",
            any(
                "002-second-ticket" in finding and "no ticket file" in finding
                for finding in report["findings"]
            ),
            True,
        )
        complete = root / "repo-complete-rows"
        make_plan(
            complete,
            "scope-complete-rows",
            spec=english_spec(),
            index=index_text(),
            tickets=("001-first-ticket.md", "002-second-ticket.md"),
        )
        check(
            "a plan whose rows all name a ticket is ok",
            tool.check_scope(complete, "scope-complete-rows")["ok"],
            True,
        )

    print()
    if FAILURES:
        print(f"plan_gate: {len(FAILURES)} case(s) FAILED")
        for name in FAILURES:
            print(f"  - {name}")
        return 1
    print("plan_gate: every case passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
