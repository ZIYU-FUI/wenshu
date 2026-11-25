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
  8. the citation report reconciles with itself (= its headline count is the sum
     of the citations on one line and the ones wrapped across two, and every
     site it prints has a line that really carries the date it reports).
  9. a citation naming a date the register has no row for is charged by name,
     and a citation naming a date the register does carry is clean.
 11. a register row keyed `| 2026-01-01 (v0.74 boss OOB) |` is a row: the date need not fill
     the key cell on its own (= a tag after the date used to hide the row, and five live
     citations to it were inventoried as dangling). The widening is bounded too: a date that
     only appears in a row's body is not a key. The same case pins that a wrapped site adds no
     phantom `dangling_files`, that a wrapped-only date still counts as dangling in the census,
     and that the judge charges that same site as a FORM violation rather than a dangling date
     (= one site, two defect names, because the judge reads a physical line and the census
     joins them).
 10. the window resolves against the MERGE-BASE, not the base's tip (= with a
     two-dot window a moving base drops somebody else's deletion into the delta
     as an addition, and a clean branch gets charged for a lineage line it never
     wrote; the repo's other delta gates already work this way).
 12. a claim split over two comment lines is charged (= the window states it, no single
     line does), and the same claim on one line is charged too (= the per-line reading
     is not the only reader, and the split reading is not the only one that counts).

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
from comment_lineage import (  # noqa: E402
    classify,
    comment_text,
    is_comment,
    measure,
    main,
)

ARMS = os.path.join(HERE, "comment_lineage_arms.txt")
ALIAS = {"1.1": "1.1/7.5", "1.5": "1.5", "1.6": "1.6"}
DEFAULT_PATH = "Sources/WenshuApp/Demo.swift"
FAILURES = []


def check(name, ok, detail=""):
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f" — {detail}" if detail and not ok else ""))
    if not ok:
        FAILURES.append(name)

SWIFT = "Sources/WenshuApp/Demo.swift"

CJK_LITERAL_WITH_TRAILING_COMMENT = 'let u = "https://example.com/唐朝"  // the link'

CJK_IN_TRAILING_COMMENT = "let size = 11  // the body is 通用"

CJK_IN_BLOCK_COMMENT = "/* the body is 通用 */"

CJK_IN_MULTILINE_LITERAL = 'let doc = """\n[链接](https://example.com/通用)\n"""  // the note'

CJK_IN_BLOCK_COMMENT_WITH_URL = "let x = 1  /* the body is 通用 = see http://example.com */"

CJK_IN_BLOCK_COMMENT_WITH_TRAILING_NOTE = "let x = 1  /* the body is 通用 */  // a trailing note"

CJK_IN_BLOCK_COMMENT_AFTER_URL = "let x = 1  /* see http://example.com = the body is 通用 */"

def case_reader():
    """The reader: what is a comment, and what TEXT of it is charged.

    The unit charged is the COMMENT TEXT, = not the whole line: = so a CJK
    string literal in code stays a literal (= 1.1's data exemption), = and a
    trailing comment is read (= the shape the old whole-line-only reader
    MISSED, = and the reason the two arms disagreed).
    """
    text, _ = comment_text("// the sheet's own face", SWIFT)
    check("case 12: a whole-line comment is a comment",
          text is not None and "the sheet's own face" in text, f"text={text!r}")

    text, _ = comment_text("let x = 1  // the body's own size", SWIFT)
    check("case 12b: a TRAILING comment is a comment (= the shape the old reader missed)",
          text is not None and "the body's own size" in text, f"text={text!r}")

    text, _ = comment_text('let url = "https://example.com/a"  // the link', SWIFT)
    check("case 12c: a `//` inside a string literal is not the comment's start",
          text is not None and text.strip() == "// the link", f"text={text!r}")

    text, _ = comment_text('case .general: return "通用"', SWIFT)
    check("case 12d: a CJK string literal is NOT a comment (= the literals stay)",
          text is None, f"text={text!r}")

    text, _ = comment_text(CJK_LITERAL_WITH_TRAILING_COMMENT, SWIFT)
    check("case 12e: a CJK literal beside a trailing comment stays a literal",
          text is not None and "唐朝" not in text, f"text={text!r}")

    text, _ = comment_text(CJK_IN_TRAILING_COMMENT, SWIFT)
    check("case 12f: a CJK in a TRAILING comment IS charged",
          text is not None and "通用" in text, f"text={text!r}")

    text, _ = comment_text(CJK_IN_BLOCK_COMMENT, SWIFT)
    check("case 12g: a CJK in a BLOCK comment IS charged",
          text is not None and "通用" in text, f"text={text!r}")

    for fixture, label in (
        (CJK_IN_BLOCK_COMMENT_WITH_URL, "= the block holds a URL"),
        (CJK_IN_BLOCK_COMMENT_WITH_TRAILING_NOTE, "= a trailing note follows the block"),
        (CJK_IN_BLOCK_COMMENT_AFTER_URL, "= the CJK sits after the URL"),
    ):
        text, _ = comment_text(fixture, SWIFT)
        check(f"case 12h: a CJK in a BLOCK comment beside a `//` IS charged ({label})",
              text is not None and "通用" in text, f"text={text!r}")

    state = {}
    first, state = comment_text('let doc = """', SWIFT, state)
    second, state = comment_text("[链接](https://example.com/通用)", SWIFT, state)
    third, state = comment_text('"""  // the note', SWIFT, state)
    check("case 12i: a `//` inside a MULTILINE literal is NOT a comment",
          (first is None or "链接" not in first)
          and (second is None or "通用" not in second),
          f"first={first!r} second={second!r}")
    check("case 12j: and the comment AFTER the literal is still a comment",
          third is not None and "the note" in third, f"third={third!r}")

    text, _ = comment_text("# the shell's own note", "Scripts/x.sh")
    check("case 12k: `#` is a comment in .sh",
          text is not None and "the shell's own note" in text, f"text={text!r}")
    text, _ = comment_text("#expect(x == 1)", SWIFT)
    check("case 12l: `#expect` in a Swift file is CODE (= not a comment)",
          text is None, f"text={text!r}")
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


def arm_reading(text, path):
    """How an arm is read. A wrapped arm (= its text carries a `\\n`) is read as the
    JOINED window, and its per-line readings are returned beside it, so a wrapped
    violating arm can be held to the rule it is written for (= no single line of it
    may state the claim)."""
    if "\\n" in text:
        parts = text.split("\\n")
        joined = " ".join(p.strip() for p in parts)
        return joined, [classify(p, path) for p in parts]
    return text, None


def case_arms():
    arms = parse_arms()
    cov = collections.Counter()
    bad = []
    for kind, exp, text, path in arms:
        joined, per_line = arm_reading(text, path)
        got = {ALIAS.get(r, r) for r, _lab, _s in classify(joined, path)}
        want = ALIAS[exp]
        side = "carve" if (path.startswith(("Scripts/", "Tools/wenshu-devtool/"))
                           and not path.startswith("Tools/wenshu-devtool/probes/")) else "ban"
        cov[(kind, want, side)] += 1
        ok = (want in got) if kind == "R" else (want not in got)
        if ok and kind == "R" and per_line is not None:
            if any(ALIAS.get(r, r) == want for hits in per_line for r, _lab, _s in hits):
                ok = False
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
              rep["register_dates"] == 1 and rep["offending"] == 1,
              f'dates={rep["register_dates"]} offending={rep["offending"]}')
        check("case 9b: and the charged label names the dangling citation",
              "citation names a date the register does not carry" in labs, str(labs))


def case_moving_base():
    """The window resolves against the MERGE-BASE (= `base...head`, the same shape the
    repo's other delta gates use). With a two-dot window, a line the branch never wrote
    enters the delta as an addition the moment base moves, and a clean card is charged
    for somebody else's deletion — the false alarm that teaches an author to bypass the
    gate rather than obey it."""
    import tempfile, os, subprocess as sp
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")

    def sh(root, *a):
        sp.run(a, cwd=root, check=True, capture_output=True, env=env)

    def head(root):
        return sp.run(["git", "-C", root, "rev-parse", "HEAD"], capture_output=True,
                      text=True).stdout.strip()

    with tempfile.TemporaryDirectory() as tmp:
        sh(tmp, "git", "init", "-q", "-b", "main")
        f = os.path.join(tmp, "Probe.swift")
        open(f, "w").write("// base\n// card t_2699b55c refused a sha here\nstruct P { }\n")
        sh(tmp, "git", "add", "-A")
        sh(tmp, "git", "commit", "-qm", "shared history")
        sh(tmp, "git", "branch", "card")
        # main MOVES: the lineage line is deleted on main, never by the branch
        open(f, "w").write("// base\nstruct P { }\n")
        sh(tmp, "git", "commit", "-qam", "main removes the lineage line")
        main_tip = head(tmp)
        # the branch never touched that line: it still carries it, and adds a clean one
        sh(tmp, "git", "checkout", "-q", "card")
        open(f, "w").write("// base\n// card t_2699b55c refused a sha here\nstruct P { }\n"
                           "// the picker writes the key\n")
        sh(tmp, "git", "commit", "-qam", "card adds a clean line")
        rep = measure(tmp, main_tip, "HEAD")
        check("case 10: a moved base does not charge the branch with a line it never wrote",
              rep["offending"] == 0 and rep["added_comment_lines"] == 1,
              f'added={rep["added_comment_lines"]} offending={rep["offending"]}')
        check("case 10b: and the window names the merge-base, not main's tip",
              rep["window_base"] == "merge-base" and rep["window"].split("..")[0] != main_tip[:10],
              rep["window"])
        # the same moved base must still catch a real violation on the branch
        open(f, "w").write("// base\n// card t_2699b55c refused a sha here\nstruct P { }\n"
                           "// the picker writes the key\n// Q3 answered by the second sweep\n")
        sh(tmp, "git", "commit", "-qam", "card adds a lineage line")
        rep2 = measure(tmp, main_tip, "HEAD")
        check("case 10c: a genuine violation on the branch is still charged",
              rep2["offending"] == 1 and rep2["added_comment_lines"] == 2,
              f'added={rep2["added_comment_lines"]} offending={rep2["offending"]}')


def case_tagged_row_key():
    """A register row whose key cell carries a TAG after the date is still a row.

    Both tools used to match the key cell only when the date filled it
    (`^\\|\\s*(\\d{4}-\\d{2}-\\d{2})\\s*\\|`). The register's oldest row is keyed
    `| 2026-07-23 (v0.74 boss OOB) |`, so that date was invisible: five live citations to it
    were inventoried as DANGLING and a repair deleted pointers that had a real target. The
    widening must not over-reach either: a date that appears only inside a row's BODY is not a
    key, and a citation to it stays dangling.

    Pinned here, each one a way the count went wrong:
      a) the judge's `register_dates` sees the tagged key and not the prose date;
      b) the census resolves a citation to the tagged key (= 0 dangling for it);
      c) a site wrapped across two lines is counted as wrapped and gets NO file — the old
         `dangling_files` added 1 whenever a wrapped site existed, naming an addressable file
         that does not exist;
      d) `dangling_dates` counts a date that dangles ONLY in wrapped text;
      e) a wrapped pointer is charged, but NOT as a dangling citation: the judge reads one
         physical line, so the fragment `OOB.md` with no `#date` after it is charged under the
         canonical-FORM rule while the register rule never sees the date. The two tools
         therefore call the same site two different defects — the census counts it as
         wrapped-and-dangling and the judge calls it a form violation.
    """
    import tempfile, os, subprocess as sp
    from citation_inventory import inventory
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")

    def sh(root, *a):
        sp.run(a, cwd=root, check=True, capture_output=True, env=env)

    with tempfile.TemporaryDirectory() as tmp:
        sh(tmp, "git", "init", "-q", "-b", "main")
        open(os.path.join(tmp, "OOB.md"), "w").write(
            "| date | decision |\n| --- | --- |\n"
            "| 2026-01-01 (v0.74 boss OOB) | the row keyed with a tag after the date |\n"
            "| note | a body that mentions 2026-01-02 in prose only |\n")
        open(os.path.join(tmp, "Demo.swift"), "w").write("// base\nstruct Demo { }\n")
        sh(tmp, "git", "add", "-A")
        sh(tmp, "git", "commit", "-qm", "base")
        base = sp.run(["git", "-C", tmp, "rev-parse", "HEAD"], capture_output=True,
                      text=True).stdout.strip()
        open(os.path.join(tmp, "Demo.swift"), "w").write(
            "// base\n"
            "// a tagged row is a row (see OOB.md #2026-01-01)\n"
            "// a prose date is not a row (see OOB.md\n"
            "// #2026-01-02)\n"
            "struct Demo { }\n")
        sh(tmp, "git", "add", "-A")
        sh(tmp, "git", "commit", "-qm", "change")

        rep = measure(tmp, base, "HEAD")
        check("case 11: the judge reads a tagged key cell as a date the register carries",
              rep["register_dates"] == 1, f'dates={rep["register_dates"]}')
        labs = [(r["line"], r["labels"]) for r in rep["rows"]]
        check("case 11b: the tagged key itself is clean, and the split pointer is charged "
              "for its FORM, not as a dangling date",
              rep["offending"] == 1 and rep["P1"] == 1
              and labs == [(3, ["OOB.md citation not in the canonical form"])],
              f'offending={rep["offending"]} rows={labs}')

        inv = inventory(tmp)
        check("case 11c: the census counts one dated row, not two",
              inv["register_dated_rows"] == 1 and inv["register_dates"] == 1,
              f'rows={inv["register_dated_rows"]} dates={inv["register_dates"]}')
        check("case 11d: the tagged key resolves and the prose date dangles",
              inv["total_citations"] == 2 and inv["resolve"] == 1
              and inv["dangling"] == 1,
              f'total={inv["total_citations"]} resolve={inv["resolve"]} '
              f'dangling={inv["dangling"]}')
        check("case 11e: a wrapped site is not an addressable file",
              inv["wrapped_across_lines"]["dangling"] == 1
              and inv["on_one_line"]["dangling"] == 0
              and inv["dangling_files"] == 0,
              f'files={inv["dangling_files"]}')
        check("case 11f: and its date still counts as a dangling date",
              inv["dangling_dates"] == 1 and inv["by_date"] == {},
              f'dates={inv["dangling_dates"]} by_date={inv["by_date"]}')


def case_wrapped_claim():
    """The plant the review names: a parity claim split over two comment lines is
    charged (= the window states it and no single line does), and the same claim on
    one line is charged too (= the split reading is not the only reader)."""
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
                   GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")

        def sh(*a):
            subprocess.run(a, cwd=tmp, check=True, capture_output=True, env=env)

        def head():
            return subprocess.run(["git", "-C", tmp, "rev-parse", "HEAD"],
                                  capture_output=True, text=True).stdout.strip()

        sh("git", "init", "-q", "-b", "main")
        open(os.path.join(tmp, "Demo.swift"), "w").write("// base\nstruct Demo { }\n")
        sh("git", "add", "-A")
        sh("git", "commit", "-qm", "base")
        base = head()
        open(os.path.join(tmp, "Demo.swift"), "w").write(
            "// base\n// the composer matches the\n// Mail app panel\nstruct Demo { }\n")
        sh("git", "add", "-A")
        sh("git", "commit", "-qm", "split")
        split = measure(tmp, base, "HEAD")
        open(os.path.join(tmp, "Demo.swift"), "w").write(
            "// base\n// the composer matches the Mail app panel\nstruct Demo { }\n")
        sh("git", "add", "-A")
        sh("git", "commit", "-qm", "one line")
        one = measure(tmp, base, "HEAD")
        check("case 12: a claim split over two comment lines is charged",
              split["offending"] == 1 and split["added_comment_lines"] == 2,
              f'offending={split["offending"]} added={split["added_comment_lines"]}')
        check("case 12b: and the same claim on one line is charged too",
              one["offending"] == 1 and one["added_comment_lines"] == 1,
              f'offending={one["offending"]} added={one["added_comment_lines"]}')


def case_instrument_results():
    """`pre_review_gate.py` runs two instruments over the tree, and they once shared
    one `code, out` pair (= the second instrument's exit code was printed for the
    first (= a battery that never ran looked green to this gate. The two arms below
    stub the shell so exactly one instrument fails at a time and read back which exit
    code the label carries (= `run_instruments` in `Tools/wenshu-devtool/pre_review_gate.py`)."""
    from pre_review_gate import run_instruments
    names = {"battery": "test_comment_lineage_gate.py", "loc": "nfi-loc-check.py"}

    def stub(battery_rc, loc_rc):
        def _sh(command, cwd=None, timeout=None):
            if names["loc"] in command:
                return loc_rc, f"loc ran ({command})"
            if names["battery"] in command:
                return battery_rc, f"battery ran ({command})"
            raise AssertionError(f"an instrument this gate does not run: {command}")
        return _sh

    got = dict((label, code) for label, code, _out in run_instruments(stub(1, 0), "BASE"))
    check("case 13: a red battery is reported red even when the LOC checker is green",
          got["the comment-lineage battery"] == 1 and got["nfi-loc-check"] == 0, str(got))

    got = dict((label, code) for label, code, _out in run_instruments(stub(0, 1), "BASE"))
    check("case 13b: a red LOC checker is reported red even when the battery is green",
          got["the comment-lineage battery"] == 0 and got["nfi-loc-check"] == 1, str(got))
    return got


def run():
    print(f"comment_lineage_arms.txt: {len(parse_arms())} arms")
    arms = case_arms()
    case_reader()
    case_carve(arms)
    case_end_to_end()
    case_carve_switch()
    case_is_comment()
    case_citation_inventory()
    case_dangling_citation()
    case_moving_base()
    case_tagged_row_key()
    case_wrapped_claim()
    case_instrument_results()
    if FAILURES:
        print(f"\nFAIL {len(FAILURES)} case(s): {FAILURES}")
        return 1
    print("\nOK — every case passed")
    return 0


if __name__ == "__main__":
    sys.exit(run())