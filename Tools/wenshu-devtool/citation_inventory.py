#!/usr/bin/env python3
"""Inventory the `OOB.md` citations a tree carries, and which of them resolve.

A citation is `(see OOB.md #YYYY-MM-DD)` (the canonical form 1.6 requires) or an inline
`OOB.md #YYYY-MM-DD`. Comment lines wrap, so a file's comment text is joined before the
search: searching line by line alone misses a citation split across two lines. This tool
reports BOTH the per-line sites (= what a reader can go and edit) and the count of
wrapped-only citations, and the two add up to the total, so no count in its output is
left unreconciled.

The register's dates are the row keys of OOB.md that START with `YYYY-MM-DD` in the first
cell; a tag may follow the date inside that cell. A date with no row
means one of two things and the tool does not guess which: the decision was never
registered, or the citation names a register that lived outside the tree. Either way a
reader following the citation finds nothing, which is why a dangling citation is a defect
even when the decision it names is real.

`--sites` prints a worklist: for each dangling site, the enclosing comment line, the rows
that share the most significant WORDS with it, and an action. The action and the rows are
ADVICE, NOT EVIDENCE: "shares >= 3 words with a row" is a word count, not a finding that the
row carries the same claim, and a reader who re-points on the score alone will re-point at
unrelated decisions. READ the row before acting. DROP is the default when nothing registers
the date, because a citation is a claim that the register carries it and an unsupported one
cannot be repaired by inventing a row.
"""
import argparse
import collections
import json
import os
import re
import subprocess

CITE = re.compile(r"OOB\.md\s*#(\d{4}-\d{2}-\d{2})")
# A dated row's key cell carries the date AND may carry a tag after it (= the register's
# oldest rows write `| 2026-07-23 (v0.74 boss OOB) |`). Requiring the date to fill the whole
# cell made that row invisible: its date was counted as a MISSING row, 5 live citations to it
# were inventoried as dangling, and a repair then deleted pointers that had a real target.
# The date must still START the cell, so prose that merely mentions a date stays unmatched.
ROW = re.compile(r"^\|\s*(\d{4}-\d{2}-\d{2})\b[^|]*\|(.*)$", re.M)
STOP = set("""the a and or of to in for on with that this it is as by at from see oob md date
line rules rule not but all its if then than into onto over under more most same other
such very which while when where are been being have has had do does""".split())


def repo_root():
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def git(repo, *a):
    return subprocess.run(["git", "-C", repo, *a], capture_output=True, text=True).stdout


def comment_lines(path, blob):
    """The blob's comment lines, prefix stripped (= one entry per physical line, so a
    site has a line number a reader can open)."""
    out = []
    for ln in blob.split("\n"):
        st = ln.strip()
        if path.endswith((".swift", ".js")):
            if st.startswith(("//", "///", "/*", "*")):
                out.append(re.sub(r"^(///|//|\*|/\*)+\s*", "", st))
        elif path.endswith((".py", ".sh")):
            if st.startswith("#") and not st.startswith("#!"):
                out.append(st.lstrip("#").strip())
    return out


def comment_text(path, blob):
    """The file's comment text joined, so a wrapped citation is one string."""
    return " ".join(comment_lines(path, blob))


def significant(s):
    s = re.sub(r"[^a-z0-9_./\-]+", " ", s.lower())
    return {w for w in s.split() if len(w) > 3 and w not in STOP}


def register_rows(repo):
    """The register keyed by DATE (several rows can share one date), plus the count of
    dated ROW LINES — the two quantities are different and printing one under the
    other's name is how a census goes wrong."""
    text = open(os.path.join(repo, "OOB.md"), encoding="utf-8").read()
    found = ROW.findall(text)
    rows = collections.defaultdict(list)
    for d, body in found:
        rows[d].append(body)
    return rows, len(found)


def inventory(repo, with_sites=False):
    rows, dated_row_lines = register_rows(repo)
    real = set(rows)
    files = git(repo, "ls-files", "--", "*.swift", "*.py", "*.sh", "*.js").split()
    total = resolved = 0
    by_date, by_file, sites = collections.Counter(), collections.Counter(), []
    wrapped_by_date = collections.Counter()
    joined_total = joined_dangling = 0
    for f in files:
        blob = git(repo, "show", f"HEAD:{f}")
        joined = comment_text(f, blob)
        j_dates = CITE.findall(joined)
        joined_total += len(j_dates)
        for d in j_dates:
            if d not in real:
                joined_dangling += 1
                wrapped_by_date[d] += 1
        n_lines = 0
        for i, line in enumerate(blob.split("\n"), 1):
            st = line.strip()
            cited = CITE.findall(st)
            if not cited:
                continue
            if not comment_lines(f, st):
                continue          # the citation sits in code, not in a comment
            n_lines += len(cited)
            for d in cited:
                total += 1
                if d in real:
                    resolved += 1
                    continue
                by_date[d] += 1
                by_file[f] += 1
                if with_sites:
                    cand = []
                    ct = significant(st)
                    for rd, bodies in rows.items():
                        for b in bodies:
                            sc = len(ct & significant(b))
                            if sc >= 2:
                                cand.append({"score": sc, "date": rd, "row": b.strip()[:200]})
                    cand.sort(key=lambda c: -c["score"])
                    sites.append({"file": f, "line": i, "cited_date": d,
                                  "text": st[:400], "candidates": cand[:3],
                                  "action": "repoint" if cand and cand[0]["score"] >= 3 else "drop"})
    dangling = sum(by_date.values())
    wrapped_total = joined_total - total
    wrapped_dangling = joined_dangling - dangling
    return {"register_dated_rows": dated_row_lines, "register_dates": len(real),
            "total_citations": joined_total, "resolve": joined_total - joined_dangling,
            "dangling": joined_dangling,
            # addressable = a site with a file:line a reader can open. A wrapped site has no
            # line to open and is NOT a file: adding one to this count invented a file.
            "dangling_files": len(by_file),
            # a date can dangle ONLY in wrapped text, so on_one_line's dates alone undercount.
            "dangling_dates": len(set(by_date) | set(wrapped_by_date)),
            "on_one_line": {"citations": total, "dangling": dangling, "sites": len(sites)},
            "wrapped_across_lines": {"citations": wrapped_total, "dangling": wrapped_dangling},
            "by_date": dict(by_date.most_common()), "by_file": dict(by_file.most_common()),
            "sites": sites}


def main(argv=None):
    ap = argparse.ArgumentParser(description="OOB.md citation inventory (AGENTS.md 1.6)")
    ap.add_argument("--repo", default=repo_root())
    ap.add_argument("--sites", action="store_true", help="print the per-site worklist")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default=None, help="write the JSON report here")
    args = ap.parse_args(argv)
    rep = inventory(args.repo, with_sites=args.sites)
    if args.out:
        with open(args.out, "w") as fh:
            json.dump(rep, fh, ensure_ascii=False, indent=1)
    if args.json:
        print(json.dumps(rep, ensure_ascii=False, indent=1))
        return 0
    print(f"OOB.md: {rep['register_dated_rows']} dated rows over "
          f"{rep['register_dates']} distinct dates (= a date can carry several rows)")
    w, o = rep["wrapped_across_lines"], rep["on_one_line"]
    print(f"citations: {rep['total_citations']} | resolve: {rep['resolve']} | "
          f"DANGLING: {rep['dangling']} over {len(rep['by_file'])} addressable files, "
          f"{rep['dangling_dates']} dates")
    addr = f"{o['sites']} with a file:line to open" if args.sites else "addresses not computed (--sites)"
    print(f"   the count split, so it reconciles: on one line {o['citations']} "
          f"({o['dangling']} dangling, {addr}) + wrapped across "
          f"two lines {w['citations']} ({w['dangling']} dangling, no single line to open)")
    dates = sorted(rep["by_date"].items(), key=lambda kv: (-kv[1], kv[0]))
    for d, n in dates[:12]:
        print(f"   {d}  {n}")
    if len(dates) > 12:
        print(f"   … top 12 of {len(dates)} dangling dates (the count above is the count)")
    if args.sites:
        rp = sum(1 for s in rep["sites"] if s["action"] == "repoint")
        print(f"sites: {len(rep['sites'])} -> repoint {rp}, drop {len(rep['sites']) - rp} "
              "(candidate rows are word-overlap ADVICE; read them before acting)")
        for s in rep["sites"][:40]:  # capped: the marker below says it is capped
            b = s["candidates"][0] if s["candidates"] else None
            print(f"   {s['action']:7s} {s['file']}:{s['line']} #{s['cited_date']} "
                  f"-> {('#' + b['date'] + ' score ' + str(b['score'])) if b else 'no row'}")
        if len(rep["sites"]) > 40:
            print(f"   … {len(rep['sites']) - 40} more sites not printed "
                  f"(--json carries all {len(rep['sites'])})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
