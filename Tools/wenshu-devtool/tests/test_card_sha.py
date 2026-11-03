#!/usr/bin/env python3
"""test_card_sha.py — the card-sha tool's own test suite.

The tool reads a real git repo, so the cases run on a FIXTURE repo written
to a temporary directory: a couple of commits, so a real sha exists and a
made-up one does not.

The cases are the ways a sha goes wrong:

  1. --read prints the sha a ref points at, read from git.
  2. --read on a ref that does not resolve says so.
  3. --check on a body whose shas all exist passes.
  4. --check on a body naming a sha that does not exist fails (= the case
     this tool exists for: a hand-written sha).
  5. --check on a body whose FIRST paragraph names no sha fails (= the merge
     gate reads no sha from it, so no verdict on it can cover the branch).
  6. --check catches a sha of the WRONG LENGTH (= a short sha with random
     characters appended, which is what happened in practice).
  7. --write replaces both sha lines with what git says.
  8. --write on a body with no WHAT TO BUILD section fails.
  9. the gate's own reader is reproduced (= the first paragraph of WHAT TO
     BUILD, its first hex run), so the tool and the gate agree.

Run:  python3 Tools/wenshu-devtool/tests/test_card_sha.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "card_sha.py"

spec = importlib.util.spec_from_file_location("card_sha", TOOL)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    if got == want:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        FAILURES.append(name)


def make_repo(root: Path) -> tuple[str, str]:
    """A tiny repo with one commit. Returns (full sha, short sha)."""
    env = {
        "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@e",
        "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@e",
        "PATH": "/usr/bin:/bin:/usr/local/bin", "HOME": str(root),
    }
    root.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q"], cwd=root, env=env, check=True)
    (root / "a.txt").write_text("hello\n")
    subprocess.run(["git", "add", "."], cwd=root, env=env, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "one"], cwd=root, env=env, check=True)
    full = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=root, env=env,
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    short = subprocess.run(
        ["git", "rev-parse", "--short=9", "HEAD"], cwd=root, env=env,
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return full, short


def case_1_read_prints_the_sha_from_git() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        full, short = make_repo(repo)
        got_full, got_short = mod.resolve("HEAD", str(repo))
        check("the full sha", got_full, full)
        check("the short sha", got_short, short)


def case_2_an_unresolvable_ref_is_not_a_sha() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        make_repo(repo)
        check("no sha for a ref that does not exist", mod.resolve("nope", str(repo)), (None, None))


def case_3_a_body_whose_shas_exist_passes() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        full, short = make_repo(repo)
        body = (
            "# [T2] x\n\n## WHAT TO BUILD\n\n"
            f"A verdict on `{short}` (branch `wt/x`).\n\n"
            f"The sha under review: **{full}**\n"
        )
        path = Path(tmp) / "card.md"
        path.write_text(body)
        import argparse

        sys.argv = ["card_sha.py", "--check", str(path), "--repo", str(repo)]
        check("exit 0", mod.main(), 0)


def case_4_a_body_naming_a_sha_that_does_not_exist_fails() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        full, short = make_repo(repo)
        fake = full[:-1] + ("f" if full[-1] != "f" else "e")
        body = (
            "# [T2] x\n\n## WHAT TO BUILD\n\n"
            f"A verdict on `{short}` (branch `wt/x`).\n\n"
            f"The sha under review: **{fake}**\n"
        )
        path = Path(tmp) / "card.md"
        path.write_text(body)
        sys.argv = ["card_sha.py", "--check", str(path), "--repo", str(repo)]
        check("exit 1", mod.main(), 1)


def case_5_a_body_whose_first_paragraph_names_no_sha_fails() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        make_repo(repo)
        body = (
            "# [T2] x\n\n## WHAT TO BUILD\n\n"
            "A verdict on the change (branch `wt/x`).\n\n"
            "The sha under review: **" + "a" * 40 + "**\n"
        )
        path = Path(tmp) / "card.md"
        path.write_text(body)
        sys.argv = ["card_sha.py", "--check", str(path), "--repo", str(repo)]
        check("exit 1", mod.main(), 1)


def case_6_a_sha_of_the_wrong_length_is_caught() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        full, short = make_repo(repo)
        padded = full + "f"  # 41 characters (= what a hand-written sha looks like)
        body = (
            "# [T2] x\n\n## WHAT TO BUILD\n\n"
            f"A verdict on `{short}` (branch `wt/x`).\n\n"
            f"The sha under review: **{padded}**\n"
        )
        path = Path(tmp) / "card.md"
        path.write_text(body)
        sys.argv = ["card_sha.py", "--check", str(path), "--repo", str(repo)]
        check("exit 1", mod.main(), 1)


def case_7_write_replaces_both_sha_lines() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        full, short = make_repo(repo)
        body = (
            "# [T2] x\n\n## WHAT TO BUILD\n\n"
            "A verdict on `deadbee` (branch `wt/x`).\n\n"
            "The sha under review: **" + "b" * 40 + "**\n"
        )
        path = Path(tmp) / "card.md"
        path.write_text(body)
        sys.argv = [
            "card_sha.py", "--write", str(path), "--branch", "HEAD",
            "--repo", str(repo),
        ]
        check("exit 0", mod.main(), 0)
        out = path.read_text()
        check("the first paragraph names the real short sha", f"`{short}`" in out, True)
        check("the sha line names the real full sha", f"**{full}**" in out, True)
        check("the old short sha is gone", "`deadbee`" not in out, True)


def case_8_write_on_a_body_without_what_to_build_fails() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        make_repo(repo)
        path = Path(tmp) / "card.md"
        path.write_text("# [T2] x\n\n## WHY\n\nno section\n")
        sys.argv = [
            "card_sha.py", "--write", str(path), "--branch", "HEAD",
            "--repo", str(repo),
        ]
        check("exit 1", mod.main(), 1)


def case_9_the_gate_reader_is_reproduced() -> None:
    """The tool must read the sha the SAME way `review_gate.reviewed_sha`
    does (= the first paragraph of WHAT TO BUILD, its first hex run), or it
    would check a different sha than the gate uses."""
    body = (
        "## WHAT TO BUILD\n\n"
        "A verdict on `abcdef1234` (branch `wt/x`).\n\n"
        "The sha under review: **0123456789abcdef0123456789abcdef01234567**\n"
    )
    check("the first paragraph's sha", mod.first_paragraph_sha(body), "abcdef1234")
    # a sha named ONLY later is invisible to the gate (= and to this tool)
    late = (
        "## WHAT TO BUILD\n\n"
        "A verdict on the change.\n\n"
        "The sha under review: **0123456789abcdef0123456789abcdef01234567**\n"
    )
    check("a sha named later is not read", mod.first_paragraph_sha(late), None)


def main() -> int:
    cases = [
        case_1_read_prints_the_sha_from_git,
        case_2_an_unresolvable_ref_is_not_a_sha,
        case_3_a_body_whose_shas_exist_passes,
        case_4_a_body_naming_a_sha_that_does_not_exist_fails,
        case_5_a_body_whose_first_paragraph_names_no_sha_fails,
        case_6_a_sha_of_the_wrong_length_is_caught,
        case_7_write_replaces_both_sha_lines,
        case_8_write_on_a_body_without_what_to_build_fails,
        case_9_the_gate_reader_is_reproduced,
    ]
    for case in cases:
        print(f"== {case.__name__}")
        case()
    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s): {', '.join(FAILURES)}")
        return 1
    print(f"ok: {len(cases)} cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
