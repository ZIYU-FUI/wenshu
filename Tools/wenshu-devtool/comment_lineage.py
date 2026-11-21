#!/usr/bin/env python3
"""THE comment-lineage judge — AGENTS.md 1.1, 1.5, 1.6 and 7.5, measured as a delta.

One union classifier (every rule's pattern in ONE table, so there is never a second
version of a pattern free to drift), run over `<base>..<head>`, re-resolved at the head
and attributed against the base.

Charged: a comment line a change ADDS that carries ticket lineage (= a card id, a
Q-number, a review round, a phase number, a commit sha in prose), refactor history (=
what the code used to do, what was deleted, what is no longer asked), a follow-up chain
(= TODO, "for now", "later card"), retro or reviewer narrative, a CJK character outside
the whitelisted proper nouns, or an `OOB.md` reference that is not the canonical form.

Not charged, stated in code so each veto is auditable instead of hidden in a regex:
  * `(see OOB.md #YYYY-MM-DD)` is the REQUIRED form (1.6), so a date inside it is legal;
  * a comment whose only card ids are the arms table's synthetic names is measuring a
    rule, not recording lineage;
  * "the counterpart used to configure X" is a purpose clause, not deleted behaviour;
  * under `Tools/wenshu-devtool/` and `Scripts/` a gate may name the card and round that
    built it, because that provenance IS the engineering intent (1.5). The carve-out does
    not reach `Tools/wenshu-devtool/probes/` and never reaches the 1.1 CJK ban; UNITY_CARVE=0
    reprints the census the carve-out excludes.

The CJK literals in the tables below are DATA (= the whitelist and the pattern the judge
draws), which is the 1.1 exemption AGENTS.md states; they are not a comment naming a
product word.

Exit 0 when the change adds no offending line, 1 otherwise. A window that added no
comment line at all is reported separately: an empty measurement is not a pass.
"""
import argparse
import collections
import json
import os
import re
import subprocess
import sys

ALLOWED_CJK = ["老板", "文枢", "拍板", "拍", "※"]
CJK = re.compile(r"[\u3000-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff00-\uffef]")
OOB_CANON = re.compile(r"\(see OOB\.md #\d{4}-\d{2}-\d{2}\)")
SYNTH = {"t_aaaa0001", "t_cccc0003"}

CHECKS = [
    ("1.5", "card id in comment (ticket lineage)", re.compile(r"\bt_[0-9a-fA-F]{6,10}\b")),
    ("1.5", "Q-number shorthand", re.compile(r"\bQ\d+\b")),
    ("1.5", "version / review-finding narrative", re.compile(
        r"\bv\d+\.\d+(\.\d+)?\b|\bV\d+\.\d+\b|\bfinding [A-Z]?\d+\b|\bR\d+-[BF]\d+\b|round \d+ of t_")),
    ("1.5", "phase numbering", re.compile(r"\b[Pp]hase\s+\d+\b|\bARC\s+\d\b")),
    ("1.5", "refactor history / deleted behaviour", re.compile(
        r"previously|used to\b|was renamed|before this (fix|change|commit)|the old (code|path|name)"
        r"|we removed|it once was|no longer (asks|reads|needs)|were wrong|the defect (was|is) that", re.I)),
    ("1.5", "follow-up chain", re.compile(
        r"\bTODO\b|\bFIXME\b|follow[- ]?up|next card|later card|\bfor now\b|to be added later")),
    ("1.5", "boss name / date / words", re.compile(
        r"老板\s*[:：]?\s*(ruled|ruling|rule|directive|asked|said|says|wants|decided)|老板\s*\d{4}|老板[:：]"
        r"|\bboss\b[^.\n]{0,20}\b(rule|ruling|ruled|directive|asked|said|says|wants|decided|correct)\b"
        r"|per the boss|boss OOB|the boss's (rule|ruling|word|directive)|boss \d{4}-\d\d-\d\d", re.I)),
    ("1.5", "review round / pass counter", re.compile(
        r"\bround[- ]\d+\b|\bthe (second|third|fourth|fifth|sixth|next) pass\b|\bround \d+ of\b"
        r"|\bthe \d+(?:st|nd|rd|th) round\b|CORRECTED")),
    ("1.5", "board / verdict comment id", re.compile(
        r"\bverdict comment \d+|\bboard comment \d+|\bcomment \d{3,}\b")),
    ("1.5", "commit sha in prose", re.compile(
        r"\b[0-9a-f]{8,12}\b(?=.{0,40}(approval|approved|refused|verdict|commit|push|tip|landing))", re.I)),
    ("1.5", "retro / reviewer narrative", re.compile(
        r"as asked|the reviewer (wrote|found|asked)|was corrected|now says|stops claiming|no longer asks")),
    ("1.6", "OOB.md citation not in the canonical form", re.compile(r"OOB")),
]

# Phrases the pattern charges that are not refactor history: a purpose clause versus a
# history clause are different sentences, and the veto carries its reason here.
NOT_HISTORY = [
    ("counterpart used to configure",
     "a doc comment's purpose clause (= the counterpart [that is] used to configure X), "
     "not a claim about what the code once did"),
]

ROW_KEY = re.compile(r"^\|\s*(\d{4}-\d{2}-\d{2})\s*\|", re.M)
CITED_DATE = re.compile(r"OOB\.md\s*#(\d{4}-\d{2}-\d{2})")


def register_dates(repo, head):
    """The dates the register really carries (= the `| YYYY-MM-DD |` row keys of the
    OOB.md at the head under test). A citation to any other date sends a reader to a
    row that does not exist, which is a defect even when the decision is real."""
    return set(ROW_KEY.findall(repo.git("show", f"{head}:OOB.md")))


CARVE_ROOTS = ("Tools/wenshu-devtool/", "Scripts/")
CARVE_NOT = ("Tools/wenshu-devtool/probes/",)


def carved(path, enabled=True):
    """The 1.5 governance-tool carve-out (= switchable, so the census it excludes
    reprints from this file instead of living only in a document)."""
    return enabled and path.startswith(CARVE_ROOTS) and not path.startswith(CARVE_NOT)


def classify(st, path="", carve=True):
    """Every rule for one comment line, in one pass. Returns [(rule, label, severity)]."""
    hits = []
    stripped = st
    for a in ALLOWED_CJK:
        stripped = stripped.replace(a, "")
    if CJK.search(stripped):
        hits.append(("1.1/7.5", "CJK in the comment", "P0"))
    for rid, label, rx in CHECKS:
        if not rx.search(st):
            continue
        if label == "OOB.md citation not in the canonical form":
            if OOB_CANON.search(st) and not re.search(r"OOB\.md\s*#\d{4}-\d{2}-\d{2}\s*[.:]", st):
                continue
        if label.startswith("version") and not re.search(r"\bv\d|\bV\d|finding|round \d+ of t_", st):
            continue
        if label == "refactor history / deleted behaviour":
            if any(ph in st for ph, _ in NOT_HISTORY):
                continue
        if carved(path, carve) and rid in ("1.5", "1.6"):
            continue
        hits.append((rid, label, "P1"))
    return hits


def is_comment(st, path):
    """A comment line, by extension (= `#` is a comment only in .py/.sh; in Swift
    `#expect` is code)."""
    if st in ("//", "///", "#", "/*", "*/", "*"):
        return False
    if path.endswith((".swift", ".js")):
        return st.startswith(("//", "///", "/*", "*"))
    return st.startswith("#") and not st.startswith("#!")


class Repo:
    def __init__(self, path):
        self.path = path

    def git(self, *args):
        return subprocess.run(["git", "-C", self.path, *args],
                              capture_output=True, text=True).stdout


def added_comment_lines(repo, base, head):
    """The window's added comment lines: `<base>..<head>`, code and tool sources only
    (= the unit every count in the report is stated in: a delta over a window, not a
    whole-tree state count)."""
    diff = repo.git("diff", "-U0", "--no-color", f"{base}..{head}",
                    "--", "*.swift", "*.py", "*.sh", "*.js")
    cur, recs = None, []
    for ln in diff.splitlines():
        if ln.startswith("+++ b/"):
            cur = ln[6:].strip()
        elif ln.startswith("+") and not ln.startswith("+++"):
            st = ln[1:].strip()
            if cur and is_comment(st, cur):
                recs.append((cur, st))
    return recs


def measure(repo_path, base, head="HEAD", carve=True):
    repo = Repo(repo_path)
    head_sha = repo.git("rev-parse", head).strip()
    base_sha = repo.git("rev-parse", base).strip()
    recs = added_comment_lines(repo, base_sha, head_sha)
    tip, blob = {}, {}

    def tip_lines(f):
        if f not in tip:
            tip[f] = repo.git("show", f"{head_sha}:{f}").splitlines()
        return tip[f]

    def base_blob(f):
        if f not in blob:
            blob[f] = repo.git("show", f"{base_sha}:{f}")
        return blob[f]

    dates = register_dates(repo, head_sha)
    rows, dropped_synth, seen = [], 0, set()
    for f, st in recs:
        hits = classify(st, f, carve)
        for d in CITED_DATE.findall(st):
            if d not in dates and not carved(f, carve):
                hits.append(("1.6", "citation names a date the register does not carry", "P1"))
        if not hits:
            continue
        tids = set(re.findall(r"\bt_[0-9a-fA-F]{6,10}\b", st))
        if tids and tids <= SYNTH and all(
                lab == "card id in comment (ticket lineage)" for _r, lab, _s in hits):
            dropped_synth += 1
            continue
        at = [i for i, l in enumerate(tip_lines(f), 1) if l.strip() == st]
        line = at[0] if at else None
        if (f, line, st) in seen:
            continue
        seen.add((f, line, st))
        if not base_blob(f):
            attr = "NEW FILE"
        elif st in base_blob(f):
            attr = "RE-WROTE-BASE"
        else:
            attr = "ADDED"
        rows.append({"file": f, "line": line, "text": st,
                     "rule": hits[0][0],
                     "severity": "P0" if any(s == "P0" for _, _, s in hits) else "P1",
                     "labels": [lab for _, lab, _ in hits], "attribution": attr})
    label_counts = collections.Counter(lab for r in rows for lab in r["labels"])
    return {
        "window": f"{base_sha[:10]}..{head_sha[:10]}",
        "register_rows": len(dates),
        "unit": "comment lines ADDED by the diff over this window (a delta, not a state count)",
        "added_comment_lines": len(recs),
        "offending": len(rows),
        "offending_files": len({r["file"] for r in rows}),
        "P0": sum(1 for r in rows if r["severity"] == "P0"),
        "P1": sum(1 for r in rows if r["severity"] == "P1"),
        "excluded_synthetic_card_id_lines": dropped_synth,
        "attribution": dict(collections.Counter(r["attribution"] for r in rows)),
        "unresolved_at_head": sum(1 for r in rows if r["line"] is None),
        "by_label": [{"rule": next((k[0] for k in CHECKS if k[1] == lab), "1.1/7.5"),
                      "label": lab, "lines": n,
                      "files": len({r["file"] for r in rows if lab in r["labels"]})}
                     for lab, n in label_counts.most_common()],
        "rows": rows,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="the comment-lineage judge (AGENTS.md 1.1 / 1.5 / 1.6 / 7.5)")
    ap.add_argument("--base", required=True, help="the commit the change is measured against")
    ap.add_argument("--head", default="HEAD", help="the tip under test (default HEAD)")
    ap.add_argument("--repo", default=os.path.dirname(os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))), help="repository root (= this file's repo)")
    ap.add_argument("--json", action="store_true", help="print the report as JSON")
    ap.add_argument("--report", default=None, help="also write the JSON report here")
    args = ap.parse_args(argv)

    rep = measure(args.repo, args.base, args.head,
                  carve=os.environ.get("UNITY_CARVE", "1") != "0")
    if args.report:
        with open(args.report, "w") as fh:
            json.dump(rep, fh, ensure_ascii=False, indent=1)
    if args.json:
        print(json.dumps(rep, ensure_ascii=False, indent=1))
    else:
        print(f"comment-lineage: window {rep['window']} | {rep['unit']}")
        print(f"  added comment lines: {rep['added_comment_lines']}")
        if rep["added_comment_lines"] == 0:
            print("  NO added comment line in this window: nothing was measured, "
                  "so this is not a pass on the rule")
        print(f"  offending: {rep['offending']} rows / {rep['offending_files']} files "
              f"(P0={rep['P0']}, P1={rep['P1']})")
        if rep["excluded_synthetic_card_id_lines"]:
            print(f"  excluded as arms-table input: {rep['excluded_synthetic_card_id_lines']}")
        for r in rep["rows"][:20]:
            print(f"  {r['file']}:{r['line']}: {'; '.join(r['labels'])}")
        if rep["offending"] > 20:
            print(f"  … {rep['offending'] - 20} more (see --json)")
    return 1 if rep["offending"] else 0


if __name__ == "__main__":
    sys.exit(main())
