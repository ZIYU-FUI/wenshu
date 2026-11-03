#!/usr/bin/env python3
"""
card_sha.py - put a branch's REAL sha into a card body, and check that a
card body names a sha that exists.

WHY THIS TOOL EXISTS
  A card's sha is read by the merge gate, so a sha that does not exist is
  a card nobody can satisfy. Measured 2026-11-03 on the wenshu-par board:
  three cards carried a "full sha" that was a hand-written guess (= the
  short sha with random characters appended to reach 40), and the gate
  could not tell a guess from a sha. The short sha in the body's FIRST
  paragraph was real in every case, so the cards still worked by accident.

  So: never type a sha. Read it.

WHAT IT DOES
  --read      the sha a branch or ref points at, the full one and the short
              one, read from git (= never invented)
  --write     rewrite a card body's sha lines in place, from the repo
  --check     every sha a card body names, checked against the repo, and
              which one the gate would read (= the first paragraph of
              WHAT TO BUILD)

Usage:
    python3 card_sha.py --read wt/review-lane-cost
    python3 card_sha.py --write card.md --branch wt/review-lane-cost
    python3 card_sha.py --check card.md

Exit code: 0 = fine, 1 = a problem (a sha that does not exist, or a card
whose first paragraph names none), 2 = the repo could not be read.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review_gate  # the gate's own reader, called rather than copied

SHA_RE = re.compile(r"\b[0-9a-f]{7,40}\b")
FULL_SHA_RE = re.compile(r"\b[0-9a-f]{40}\b")
# A sha is 40 hex characters, LOWERCASE. A run of 34 or more that is NOT 40
# is a sha somebody typed wrong (= the failure measured 2026-11-03: a short
# sha with random characters appended, sometimes landing on 41), so those
# runs are checked against the repo as well.
#
# AND THE CANDIDATE IS NOT REQUIRED TO BE LOWERCASE HEX. A guess typed in
# UPPERCASE, or one with a non-hex character in it, is still a guess, and a
# detector that only recognises lowercase hex lets it through with a false
# green (= `git cat-file -t` accepts uppercase hex and returns 128 for a
# sha that does not exist, so `exists()` was already correct: the hole was
# purely the detector). So the candidate is a run of >=34 word characters
# that holds >=30 hex characters, in either case.
SUSPECT_SHA_RE = re.compile(r"\b[0-9A-Za-z]{34,}\b")


def sha_candidates(body: str) -> list[str]:
    """The sha-shaped tokens in a body, including the ones that are not
    valid lowercase hex (= a guess typed in uppercase, or with a non-hex
    character in it).

    A token is a candidate when it is long enough to be a sha (= >=34
    characters) and holds enough hex characters to be one (= >=30). A real
    sha is 40 hex characters, so a real sha always qualifies, and a guess
    that got the case or one character wrong still qualifies.
    """
    out: set[str] = set()
    for token in SUSPECT_SHA_RE.findall(body):
        hexish = sum(1 for c in token if c in "0123456789abcdefABCDEF")
        if hexish >= 30:
            out.add(token)
    return sorted(out)


def git(args: list[str], repo: str) -> tuple[int, str, str]:
    """Run a git command in the repo. Returns (rc, stdout, stderr)."""
    p = subprocess.run(["git", *args], capture_output=True, text=True, cwd=repo)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def resolve(ref: str, repo: str) -> tuple[str | None, str | None]:
    """The sha a ref points at, full and short. Read from git, never typed."""
    rc, out, _ = git(["rev-parse", "--verify", "-q", f"{ref}^{{commit}}"], repo)
    if rc != 0 or not out:
        return None, None
    rc2, short, _ = git(["rev-parse", "--short=9", ref], repo)
    return out, (short if rc2 == 0 else out[:9])


def exists(sha: str, repo: str) -> bool:
    rc, _, _ = git(["cat-file", "-t", sha], repo)
    return rc == 0


def first_paragraph_sha(body: str) -> str | None:
    """The sha the merge gate reads from a body.

    This is `review_gate.reviewed_sha(body)` CALLED, not a second
    implementation of it: the gate reads the first PARAGRAPH of the
    `## WHAT TO BUILD` section (= the text up to the first blank line) and
    takes its first `[0-9a-f]{7,40}` match. A re-implementation that reads
    further would report a sha the gate never looks at (= a false positive
    on a card that is fine), and one that reads less would miss the sha the
    gate actually uses.
    """
    return review_gate.reviewed_sha(body)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--read", metavar="REF", help="print the sha a ref points at")
    ap.add_argument("--write", metavar="FILE", help="rewrite a card body's sha lines")
    ap.add_argument("--check", metavar="FILE", help="check a card body's shas")
    ap.add_argument("--branch", default=None, help="the branch to read the sha from")
    ap.add_argument("--repo", default=None, help="the repo (default: the cwd)")
    args = ap.parse_args()

    repo = args.repo or str(Path.cwd())
    if not (Path(repo) / ".git").exists():
        print(f"not a git repository: {repo}", file=sys.stderr)
        return 2

    if args.read:
        full, short = resolve(args.read, repo)
        if not full:
            print(f"the ref does not resolve: {args.read}", file=sys.stderr)
            return 2
        print(full)
        print(short)
        return 0

    if args.write:
        if not args.branch:
            print("--write needs --branch", file=sys.stderr)
            return 2
        path = Path(args.write)
        body = path.read_text(encoding="utf-8")
        full, short = resolve(args.branch, repo)
        if not full or not short:
            print(f"the branch does not resolve: {args.branch}", file=sys.stderr)
            return 2
        # The first paragraph's short sha, and the "The sha under review"
        # line's full sha. Both are replaced with what git says.
        m = re.search(r"(##\s*WHAT TO BUILD\s*\n+)(\s*)([^\n]*)", body)
        if not m:
            print("the body has no WHAT TO BUILD section", file=sys.stderr)
            return 1
        para = m.group(3)
        new_para = re.sub(
            r"[0-9a-f]{7,40}", short, para, count=1
        )
        body = body[: m.start(3)] + new_para + body[m.end(3) :]
        # The board phrases that line many ways ("The sha under review:
        # <sha>", "The sha under review is <sha> on branch ...", with or
        # without bold), so the rewrite matches the LINE and replaces the
        # sha inside it, rather than one exact form.
        def _rewrite_sha_line(line: str) -> str:
            if "sha under review" not in line.lower():
                return line
            return re.sub(r"[0-9a-fA-F]{7,40}", full, line, count=1)

        body = "\n".join(_rewrite_sha_line(l) for l in body.splitlines())
        # AND CHECK THE SLOT THE GATE ACTUALLY READS BEFORE WRITING. A
        # --write that reports success without setting that slot is the
        # defect this branch has been about, three rounds running: a gate
        # that reports success while the defect is present. So the new body
        # is checked FIRST (= the gate's own reader, called on the text
        # that would be written), and a body the gate would still read as
        # no-sha FAILS WITHOUT TOUCHING THE FILE.
        gate_sha = review_gate.reviewed_sha(body)
        if gate_sha != short:
            print(
                f"the body does not name {short} where the merge gate reads "
                f"it: it reads {gate_sha!r} from the first paragraph of "
                f"WHAT TO BUILD. Put the sha there (= 'A verdict on "
                f"`<sha>` (branch `<branch>`).') and run this again. "
                f"The file was NOT changed."
            )
            return 1
        path.write_text(body, encoding="utf-8")
        print(f"the body now names {short} (full {full})")
        return 0

    if args.check:
        path = Path(args.check)
        body = path.read_text(encoding="utf-8")
        problems: list[str] = []
        gate_sha = first_paragraph_sha(body)
        if not gate_sha:
            problems.append(
                "the first paragraph of WHAT TO BUILD names no sha = the merge "
                "gate reads no sha from this card, so no verdict on it can "
                "cover the branch"
            )
        elif not exists(gate_sha, repo):
            problems.append(
                f"the sha the gate reads ({gate_sha}) does not exist in the repo"
            )
        for full in sha_candidates(body):
            if not exists(full, repo):
                problems.append(
                    f"a sha in the body does not exist: {full} "
                    f"({len(full)} characters; a sha is 40 lowercase hex)"
                )
        if problems:
            for p in problems:
                print(f"  !! {p}")
            return 1
        print(f"the body names {gate_sha}, and every sha in it exists")
        return 0

    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
