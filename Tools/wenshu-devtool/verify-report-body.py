#!/usr/bin/env python3
"""verify-report-body.py — a report body's own claims, EXECUTED, with teeth.

    usage: verify-report-body.py BODY.md
               [--pattern LIT --occurrences N]         # how many times a stated pattern appears
               [--command-contains SUBSTR --expect-output N]  # run the command the body publishes
               [--pandoc]                              # render it and look for stray emphasis

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

FAILS = []


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

    text = read_body(a.body)
    lines = text.split("\n")

    bad = unfold_spans(text)
    check("fold-scan", not bad, f"{len(bad)} prose lines with an unbalanced backtick"
          + (f" at L{bad[:6]}" if bad else ""))

    if a.pattern is not None:
        n, lns = count_occurrences(text, a.pattern)
        if a.occurrences is None:
            check("pattern-count", True, f"{a.pattern!r} occurs {n} time(s) on lines {lns} (no --occurrences given: no claim to test)")
        else:
            check("pattern-count", n == a.occurrences,
                  f"{a.pattern!r} occurs {n} time(s) on lines {lns}; body claims {a.occurrences}")

    if a.command_contains:
        cmd, cands = extract_command(text, a.command_contains)
        if cmd is None:
            check("command-extract", False,
                  f"{len(cands)} spans contain {a.command_contains!r}, need exactly 1: {cands}")
        else:
            r = subprocess.run(["/bin/sh", "-c", cmd], capture_output=True, text=True)
            out = r.stdout.strip()
            print(f"      ran verbatim: {cmd[:150]}")
            if r.returncode != 0:
                print(f"      rc={r.returncode} stderr={r.stderr.strip()[:150]}")
            check("command-output", out == a.expect_output,
                  f"printed {out!r}, body claims {a.expect_output!r}")

    if a.pandoc:
        if not shutil.which("pandoc"):
            check("render", False, "pandoc not on PATH (the renderer of record; not substituting a guess)")
        else:
            r = subprocess.run(["pandoc", "-f", "gfm", "-t", "plain", a.body],
                               capture_output=True, text=True)
            stray = [i for i, ln in enumerate(r.stdout.split("\n"), 1) if "**" in ln]
            check("render-no-stray-emphasis", not stray,
                  f"{len(stray)} rendered lines still carry a literal '**'"
                  + (f" e.g. {stray[:8]}" if stray else "")
                  + " (= emphasis opened and never closed; gate 8 counts backticks and cannot see it)")

    print(f"\nverify-report-body: {len(FAILS)} failing check(s)"
          + (f" -> {FAILS}" if FAILS else ""))
    return 1 if FAILS else 0


sys.exit(main())
