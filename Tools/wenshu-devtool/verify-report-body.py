#!/usr/bin/env python3
"""verify-report-body.py — a report body's own claims, EXECUTED, with teeth.

    usage: verify-report-body.py BODY.md
               [--pattern LIT --occurrences N]         # how many times a stated pattern appears
               [--command-contains SUBSTR --expect-output N]  # run the command the body publishes
               [--pandoc]                              # render it and look for stray emphasis

--pattern IS MATCHED LITERALLY, = = NOT AS A REGEX: = = count_occurrences wraps it in re.escape,
so 'rule[ ]6\.5' counts the BRACKETED TEXT and a regex-shaped string that the body never printed
measures 0. = = The bracket spelling is deliberate in this repo's report bodies; = = a caller who
passes a real regex gets a confident 0 (finding B9 on card t_2699b55c, = = stated here so a caller
learns it from the tool and not from a card body that gets pruned).

The two selectors are PAIRS. = = A selector with no expectation is a usage error (exit 2) and never
reaches a check, = = because "no claim to test" printed as PASS is how the tool used to reward the
missing ruler (finding B4) and to compare stdout against None (finding B5).

WHY THIS FILE EXISTS. Round 11's acceptance script printed

    the ONE census pattern appears 3 time(s) in the body (header + gate 7 = 2 expected)

and exited 0, because that line was a `print` with no `assert` behind it (verdict comment 2186,
R11-B3). A check that prints a contradiction and still passes is the exact failure mode this whole
axis was created to end, and it was living in the axis's own acceptance harness. So every claim here
is an assertion, and every assertion names the measured value and the expected one.

It also refuses the other half of the same trap: a number the body publishes is verified by RUNNING
the command the body publishes, extracted from the body, not by re-typing it here (the R10-B2 / R11-B1
class: a transcription that looks right and measures nothing).

Nothing here is report-round-specific; a round card passes its own pattern, command and expectation.
"""
import argparse, re, shutil, subprocess, sys
from pathlib import Path

FAILS = []

# THE COMMAND ARM NEEDS A TREE. = = The body's own `git show <sha>:<path> | wc -l` resolves against
# a repository or it resolves to NOTHING, = = and "nothing" prints 0, = = which PASSed a claim of 0
# and FAILed a claim of 139 from the same body: = = one missing cwd= broke the gate in BOTH
# directions depending on where the reader happened to stand (finding B2+). = = So the tree is
# pinned to the repo this tool lives in (= = this file is <root>/Tools/wenshu-devtool/this.py) and
# the root is printed with every run, = = so the provenance carries its own tree.
_HERE = Path(__file__).resolve()
# <root>/Tools/wenshu-devtool/this.py = = three levels up. = = A copy of this tool parked somewhere
# shallower has no repo above it at all, = = and the refusal in main() is what says so out loud
# instead of a traceback.
REPO_ROOT = _HERE.parents[2] if len(_HERE.parents) >= 3 else _HERE.parent


def check(name, ok, detail):
    print(f"{'PASS' if ok else 'FAIL'}  {name}: {detail}")
    if not ok:
        FAILS.append(name)


def read_body(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def count_occurrences(text, pattern):
    """Lines are reported so a wrong count can be found by eye, not argued about."""
    hits = []
    for i, line in enumerate(text.split("\n"), 1):
        hits.extend((i, m.start()) for m in re.finditer(re.escape(pattern), line))
    lines = sorted({n for n, _ in hits})
    return len(hits), lines


def unfold_spans(text):
    """Prose lines whose inline-code backticks do not balance (= a command folded across lines)."""
    bad, in_fence = [], False
    for i, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if line.count("`") % 2 == 1:
            bad.append(i)
    return bad


def extract_command(text, marker):
    """The single inline/ fenced command in the body that contains MARKER, verbatim.

    Inline spans are taken as `...` runs; a span is a command if it holds a shell verb. Joins across
    folded lines must use a TOKEN-AWARE glue: joining with a space can put a space INSIDE a path,
    which is R10-B2 exactly (the command then runs, prints 0, and the provenance still reads verified).
    """
    cands = []
    for m in re.finditer(r"`([^`\n]+)`", text):
        if marker in m.group(1):
            cands.append(m.group(1).strip())
    for m in re.finditer(r"```\n(.*?)```", text, re.S):
        if marker in m.group(1):
            cands.append(m.group(1).strip())
    if len(cands) != 1:
        return None, [c[:70] for c in cands]
    return cands[0], cands


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("body")
    ap.add_argument("--pattern")
    ap.add_argument("--occurrences", type=int)
    ap.add_argument("--command-contains")
    ap.add_argument("--expect-output")
    ap.add_argument("--pandoc", action="store_true")
    a = ap.parse_args()

    # THE SELECTORS ARE PAIRS (= = findings B4 and B5). = = Before this, `--pattern` with no
    # `--occurrences` called check("pattern-count", True, ...) with a LITERAL True, = = so any
    # pattern against any body exited green while printing the count 0 in its own message, = = and
    # `--command-contains` with no `--expect-output` compared stdout to None and printed
    # "body claims None". = = A file whose whole premise is that a published number must ship its
    # ruler cannot reward the missing ruler; = = and a usage error must be rc=2 BEFORE any check
    # runs, = = not a PASS with a note after it.
    unpaired = []
    if (a.pattern is None) != (a.occurrences is None):
        unpaired.append("--pattern and --occurrences are ONE claim: a selector with no expectation "
                        "tests nothing, so it is refused rather than passed")
    if bool(a.command_contains) != (a.expect_output is not None):
        unpaired.append("--command-contains and --expect-output are ONE claim: with no claimed "
                        "value there is nothing to compare the command's stdout against")
    if unpaired:
        for msg in unpaired:
            print("usage error: " + msg, file=sys.stderr)
        return 2
    if not (REPO_ROOT / ".git").exists():
        print(f"usage error: this tool is not inside a git repository (resolved root "
              f"{REPO_ROOT}), so the command arm has no tree to run in", file=sys.stderr)
        return 2

    text = read_body(a.body)
    lines = text.split("\n")

    bad = unfold_spans(text)
    check("fold-scan", not bad, f"{len(bad)} prose lines with an unbalanced backtick"
          + (f" at L{bad[:6]}" if bad else ""))

    if a.pattern is not None:
        n, lns = count_occurrences(text, a.pattern)
        check("pattern-count", n == a.occurrences,
              f"{a.pattern!r} occurs {n} time(s) on lines {lns}; body claims {a.occurrences}"
              " [--pattern is a LITERAL, re.escape'd]")

    if a.command_contains:
        cmd, cands = extract_command(text, a.command_contains)
        if cmd is None:
            check("command-extract", False,
                  f"{len(cands)} spans contain {a.command_contains!r}, need exactly 1: {cands}")
        else:
            # BASH + PIPEFAIL (= = finding B2). = = `/bin/sh -c "a | b"` reports the LAST stage,
            # so a dead `git show` upstream exited 0 through `wc -l` and the rc guard below never
            # fired while stderr held "fatal: invalid object name". = = And printing rc and stderr
            # and then walking into check() anyway is the second half of the same bug: = = a report
            # of a death is not a refusal of it.
            r = subprocess.run(["/bin/bash", "-o", "pipefail", "-c", cmd],
                               capture_output=True, text=True, cwd=str(REPO_ROOT))
            out = r.stdout.strip()
            print(f"      ran verbatim in {REPO_ROOT}: {cmd[:150]}")
            if r.returncode != 0 or r.stderr.strip():
                check("command-output", False,
                      f"the command the body publishes did not complete (rc={r.returncode}, "
                      f"stderr={r.stderr.strip()[:200]!r}); no comparison is scored from a run "
                      "that died")
            else:
                check("command-output", out == a.expect_output,
                      f"printed {out!r}, body claims {a.expect_output!r}")

    if a.pandoc:
        if not shutil.which("pandoc"):
            check("render", False, "pandoc not on PATH (the renderer of record; not substituting a guess)")
        else:
            r = subprocess.run(["pandoc", "-f", "gfm", "-t", "plain", a.body],
                               capture_output=True, text=True, cwd=str(REPO_ROOT))
            # (= = finding B3). = = This block scored r.stdout without ever reading r.returncode,
            # so a pandoc that printed nothing and exited 6 certified "0 rendered lines carry **"
            # on the body whose true render holds 7. = = Absence was refused (:122) but FAILURE was
            # not, = = and an empty render is not the same fact as a clean one.
            if r.returncode != 0:
                check("render-no-stray-emphasis", False,
                      f"pandoc did not render (rc={r.returncode}, "
                      f"stderr={r.stderr.strip()[:200]!r}); no stray count is scored from a "
                      "render that died")
            elif not r.stdout.strip():
                check("render-no-stray-emphasis", False,
                      "pandoc exited 0 and produced NO output: an empty render is not the "
                      "same fact as a clean one")
            else:
                stray = [i for i, ln in enumerate(r.stdout.split("\n"), 1) if "**" in ln]
                check("render-no-stray-emphasis", not stray,
                      f"{len(stray)} rendered lines still carry a literal '**'"
                      + (f" e.g. {stray[:8]}" if stray else "")
                      + " (= emphasis opened and never closed; gate 8 counts backticks and cannot see it)")

    print(f"\nverify-report-body: {len(FAILS)} failing check(s)"
          + (f" -> {FAILS}" if FAILS else ""))
    return 1 if FAILS else 0


sys.exit(main())
