#!/usr/bin/env python3
"""test_comment_lineage_gate.py — the comment-lineage judge's own test suite.

The cases are the ways this gate can rot, each one a thing that has already
happened to a gate in this repo:

  1. every arm in comment_lineage_arms.txt behaves as declared (= R charged,
     G clean), and every rule bucket has BOTH a violating arm and a compliant
     partner (= a bucket of only G arms can never fail; a bucket of only R arms
     may be matching everything).
  2. the carve-out is measured on the same words on both sides (= a carve-out
     that only exists in prose turns a real audit into a no-op), and a probe
     under Tools/wenshu-devtool/probes/ is still charged (= the boundary).
  3. the gate fails end to end (= a fixture repo is built in a temp dir, given
     a comment line that breaks the rule, and measured over the real window;
     exit 1). A gate that has never returned 1 is not a gate.
  4. a compliant change returns 0 WITH a non-zero added-comment count (= a
     green that measured something, not a green that saw nothing).
  5. a window that added no comment line says so and calls itself not-a-pass
     (= an empty collection is the one shape that fakes success).
  6. `#` is a comment only in .py/.sh (= a Swift `#expect` line carrying a
     charged token is code and must not be charged).
  7. UNITY_CARVE=0 reprints the census the carve-out excludes (= the boundary
     is switchable in the same file, so the number in the register can be
     reproduced rather than remembered).

Run:  python3 Tools/wenshu-devtool/tests/test_comment_lineage_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import collections
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
from comment_lineage import classify, is_comment, measure, main  # noqa: E402

ARMS = os.path.join(HERE, "comment_lineage_arms.txt")
ALIAS = {"1.1": "1.1/7.5", "1.5": "1.5", "1.6": "1.6"}
DEFAULT_PATH = "Sources/WenshuApp/Demo.swift"
FAILURES = []


def check(name, ok, detail=""):
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f" — {detail}" if detail and not ok else ""))
    if not ok:
        FAILURES.append(name)


def parse_arms():
    arms = []
    for ln in open(ARMS, encoding="utf-8"):
        ln = ln.rstrip("\n")
        if not ln.strip() or "|" not in ln or ln.lstrip().startswith("#"):
            continue
        kind, rest = ln.split("|", 1)
        exp, text = rest.split("|", 1)
        path = DEFAULT_PATH
        if "@path:" in text:
            text, path = text.rsplit("@path:", 1)
            path = path.strip()
        arms.append((kind.strip().rstrip(":"), exp.strip(), text, path))
    return arms


def case_arms():
    arms = parse_arms()
    cov = collections.Counter()
    bad = []
    for kind, exp, text, path in arms:
        got = {ALIAS.get(r, r) for r, _lab, _s in classify(text, path)}
        want = ALIAS[exp]
        side = "carve" if (path.startswith(("Scripts/", "Tools/wenshu-devtool/"))
                           and not path.startswith("Tools/wenshu-devtool/probes/")) else "ban"
        cov[(kind, want, side)] += 1
        ok = (want in got) if kind == "R" else (want not in got)
        if not ok:
            bad.append((kind, want, sorted(got), text[:70], path))
    rules = {"1.1/7.5", "1.5", "1.6"}
    missing = [r for r in rules
               if cov[("G", r, "ban")] + cov[("G", r, "carve")] == 0
               or cov[("R", r, "ban")] + cov[("R", r, "carve")] == 0]
    check("case 1: every arm behaves as declared",
          not bad, f"{len(bad)}/{len(arms)} wrong: {bad[:3]}")
    check("case 1b: every rule has a violating AND a compliant arm", not missing, str(missing))
    return arms


def case_carve(arms):
    words = collections.defaultdict(set)
    for kind, exp, text, path in arms:
        if exp in ("1.5", "1.6"):
            side = "carve" if (path.startswith(("Scripts/", "Tools/wenshu-devtool/"))
                               and not path.startswith("Tools/wenshu-devtool/probes/")) else "ban"
            words[text].add((kind, side))
    pair = [t for t, ks in words.items() if {("R", "ban"), ("G", "carve")} <= ks]
    check("case 2: the carve-out is measured on the same words on both sides",
          bool(pair), "no paired arm")
    probe = [(t, p) for _k, _e, t, p in arms if p.startswith("Tools/wenshu-devtool/probes/")]
    check("case 2b: a probe inside the carved tree is still charged",
          bool(probe) and all(classify(t, p) for t, p in probe), str(probe[:2]))
    check("case 2c: the 1.1 ban is never carved (= a CJK comment under Scripts/ is charged)",
          any(classify(t, p) for k, e, t, p in arms if e == "1.1" and p.startswith("Scripts/")))


def fixture_repo(root, base_comment, head_line):
    """A two-commit git repo whose only delta is one comment line in a Swift file."""
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")

    def sh(*a):
        subprocess.run(a, cwd=root, check=True, capture_output=True, env=env)

    sh("git", "init", "-q", "-b", "main")
    with open(os.path.join(root, "Demo.swift"), "w") as fh:
        fh.write("// " + base_comment + "\nstruct Demo { }\n")
    with open(os.path.join(root, "Probe.swift"), "w") as fh:
        fh.write("// base\nstruct Probe {}\n")
    sh("git", "add", "-A")
    sh("git", "commit", "-qm", "base")
    base = subprocess.run(["git", "-C", root, "rev-parse", "HEAD"],
                          capture_output=True, text=True).stdout.strip()
    with open(os.path.join(root, "Demo.swift"), "w") as fh:
        fh.write("// " + base_comment + "\n" + head_line + "\nstruct Demo { }\n")
    sh("git", "add", "-A")
    sh("git", "commit", "-qm", "change")
    return base


def case_end_to_end():
    with tempfile.TemporaryDirectory() as tmp:
        base = fixture_repo(tmp, "one door per question",
                       "// card t_2699b55c refused a sha here")
        rep = measure(tmp, base, "HEAD")
        check("case 3: a violating added comment line fails the window",
              rep["offending"] == 1 and rep["added_comment_lines"] == 1, str(rep)[:200])
        rc = main(["--base", base, "--repo", tmp])
        check("case 3b: and main() exits 1 on it", rc == 1, f"rc={rc}")

        base2 = fixture_repo(tmp, "one door per question",
                       "// a compliant line: the picker writes the key")
        rep2 = measure(tmp, base2, "HEAD")
        rc2 = main(["--base", base2, "--repo", tmp])
        check("case 4: a compliant change exits 0 having measured a real comment line",
              rc2 == 0 and rep2["added_comment_lines"] == 1 and rep2["offending"] == 0,
              f"rc={rc2} added={rep2['added_comment_lines']}")

        out = subprocess.run([sys.executable, os.path.join(TOOLS, "comment_lineage.py"),
                              "--base", base2, "--repo", tmp, "--head", base2],
                             capture_output=True, text=True).stdout
        check("case 5: an empty window is reported as not-a-pass, not as a clean rule",
              "not a pass" in out, out.strip()[:160])

        base3 = fixture_repo(tmp, "one door per question", '#expect(x == "TODO later")')
        rep3 = measure(tmp, base3, "HEAD")
        check("case 6: a Swift code line carrying a charged token is not a comment",
              rep3["offending"] == 0 and rep3["added_comment_lines"] == 0, str(rep3)[:200])


def case_carve_switch():
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
                   GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
        subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True,
                       capture_output=True, env=env)
        os.makedirs(os.path.join(tmp, "Tools/wenshu-devtool"), exist_ok=True)
        p = os.path.join(tmp, "Tools/wenshu-devtool/gate.py")
        open(p, "w").write("# base\n")
        subprocess.run(["git", "add", "-A"], cwd=tmp, check=True, capture_output=True, env=env)
        subprocess.run(["git", "commit", "-qm", "base"], cwd=tmp, check=True,
                       capture_output=True, env=env)
        base = subprocess.run(["git", "-C", tmp, "rev-parse", "HEAD"],
                              capture_output=True, text=True).stdout.strip()
        open(p, "w").write("# base\n# built by t_040d46e6 round 2 of the review lane\n")
        subprocess.run(["git", "add", "-A"], cwd=tmp, check=True, capture_output=True, env=env)
        subprocess.run(["git", "commit", "-qm", "change"], cwd=tmp, check=True,
                       capture_output=True, env=env)
        carved = measure(tmp, base, "HEAD", carve=True)
        census = measure(tmp, base, "HEAD", carve=False)
        check("case 7: the carve-out excuses the governance tool's own provenance",
              carved["offending"] == 0 and carved["added_comment_lines"] == 1, str(carved)[:200])
        check("case 7b: UNITY_CARVE=0 reprints the census it excludes",
              census["offending"] == 1, str(census)[:200])


def case_is_comment():
    check("case 6b: the comment predicate is by extension",
          is_comment("// note", "a.swift") and is_comment("# note", "a.py")
          and not is_comment('#expect("TODO")', "a.swift")
          and not is_comment("//", "a.swift"))


def case_citation_inventory():
    """The citation tool is a report, not a verdict, but its counts must reconcile:
    a site's own line must carry the date it reports, the per-file and per-date totals
    must equal the dangling count, and wrapped citations must be counted separately
    rather than lost."""
    from citation_inventory import inventory
    repo = subprocess.run(["git", "-C", TOOLS, "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True).stdout.strip()
    rep = inventory(repo, with_sites=True)
    tot, res, dang = rep["total_citations"], rep["resolve"], rep["dangling"]
    one, wr = rep["on_one_line"], rep["wrapped_across_lines"]
    check("case 8: citations resolve + dangling == total", tot == res + dang, f"{tot} {res} {dang}")
    check("case 8b: the split reconciles (= on-one-line + wrapped == the headline counts)",
          one["citations"] + wr["citations"] == tot and one["dangling"] + wr["dangling"] == dang,
          f"{one} {wr}")
    check("case 8c: the date/file tallies cover the on-one-line dangling",
          one["dangling"] == sum(rep["by_date"].values()) == sum(rep["by_file"].values()),
          f"{one['dangling']} {sum(rep['by_date'].values())} {sum(rep['by_file'].values())}")
    if rep["dangling"]:
        bad = []
        for site in rep["sites"]:
            blob = subprocess.run(["git", "-C", repo, "show", f"HEAD:{site['file']}"],
                                  capture_output=True, text=True).stdout.splitlines()
            if site["cited_date"] not in (blob[site["line"] - 1] if len(blob) >= site["line"] else ""):
                bad.append((site["file"], site["line"], site["cited_date"]))
        check("case 8d: every reported site's line really carries that date", not bad, str(bad[:2]))
        check("case 8e: sites == the on-one-line dangling (= nothing counted without an address)",
              len(rep["sites"]) == one["dangling"], f"{len(rep['sites'])} vs {one['dangling']}")


def case_dangling_citation():
    """The 1.6 half a delta check CAN hold: a citation may name a date the register
    does not carry (= the reader following it finds nothing, which is a defect even
    when the decision is real). Only the added line is charged, so the census already
    in the tree stays a registered backlog instead of blocking unrelated cards."""
    import tempfile, os, subprocess as sp
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")

    def sh(root, *a):
        sp.run(a, cwd=root, check=True, capture_output=True, env=env)

    with tempfile.TemporaryDirectory() as tmp:
        sh(tmp, "git", "init", "-q", "-b", "main")
        open(os.path.join(tmp, "OOB.md"), "w").write("| date | decision |\n| --- | --- |\n| 2026-01-01 | one row exists |\n")
        open(os.path.join(tmp, "Demo.swift"), "w").write("// base\nstruct Demo { }\n")
        sh(tmp, "git", "add", "-A")
        sh(tmp, "git", "commit", "-qm", "base")
        base = sp.run(["git", "-C", tmp, "rev-parse", "HEAD"], capture_output=True,
                      text=True).stdout.strip()
        open(os.path.join(tmp, "Demo.swift"), "w").write(
            "// base\n// a real decision (see OOB.md #2026-01-01)\n"
            "// a claim nothing registers (see OOB.md #2025-05-05)\nstruct Demo { }\n")
        sh(tmp, "git", "add", "-A")
        sh(tmp, "git", "commit", "-qm", "change")
        rep = measure(tmp, base, "HEAD")
        labs = [lab for r in rep["rows"] for lab in r["labels"]]
        check("case 9: a citation to a row the register carries is clean",
              rep["register_rows"] == 1 and rep["offending"] == 1,
              f'rows={rep["register_rows"]} offending={rep["offending"]}')
        check("case 9b: and the charged label names the dangling citation",
              "citation names a date the register does not carry" in labs, str(labs))


def run():
    print(f"comment_lineage_arms.txt: {len(parse_arms())} arms")
    arms = case_arms()
    case_carve(arms)
    case_end_to_end()
    case_carve_switch()
    case_is_comment()
    case_citation_inventory()
    case_dangling_citation()
    if FAILURES:
        print(f"\nFAIL {len(FAILURES)} case(s): {FAILURES}")
        return 1
    print("\nOK — every case passed")
    return 0


if __name__ == "__main__":
    sys.exit(run())
