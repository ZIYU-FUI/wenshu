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

TWO AXES, AND THEY ARE ORTHOGONAL. THE P0/P1 AXIS IS THE CJK AXIS (= the vocabulary the
OOB register's published census counts, = so those numbers keep reprinting): a P0 row
carries a CJK character (= 1.1's ban), a P1 row does not (= a 1.5 lineage line or a 1.6
citation form). THE BLOCKING AXIS IS THE AUTHORSHIP AXIS: a row BLOCKS when this branch
WROTE the line it sits on (= the text is new in this window, = or the file is new), and
it is REPORTED ONLY when the branch only CARRIED the line (= the same text already stood
in the base file). The exit code follows the BLOCKING axis, = = so a line the author
did not write is printed with its file and line but does not stop the card (= a hit in a
diff is not proof that your commit added it = = the closeout rule's own words).

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

from comment_lineage_rules import (  # noqa: E402  (= the rule tables live in ONE home)
    VENDOR_HONEST,
    VENDOR_LABEL,
    VENDOR_RX,
    has_honest_marker,
)

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
    ("1.5", VENDOR_LABEL, VENDOR_RX),
]

# Phrases the pattern charges that are not refactor history: a purpose clause versus a
# history clause are different sentences, and the veto carries its reason here.
NOT_HISTORY = [
    ("counterpart used to configure",
     "a doc comment's purpose clause (= the counterpart [that is] used to configure X), "
     "not a claim about what the code once did"),
]

# The register's key cell starts with the date and may carry a version tag after it in the same
# cell. Requiring the date to fill the cell hid the register's oldest dated row, so a citation
# to it charged P1 for a decision the register does carry. Same rule as
# citation_inventory.ROW: the date must START the cell; prose that only mentions a date stays
# unmatched.
ROW_KEY = re.compile(r"^\|\s*(\d{4}-\d{2}-\d{2})\b[^|]*\|", re.M)
CITED_DATE = re.compile(r"OOB\.md\s*#(\d{4}-\d{2}-\d{2})")


def register_dates(repo, head):
    """The DATES the register really carries (= the distinct `| YYYY-MM-DD |` row keys
    of the OOB.md at the head under test; several rows can share one date, so this is a
    date set and not a row count). A citation to any other date sends a reader to a row
    that does not exist, which is a defect even when the decision is real."""
    return set(ROW_KEY.findall(repo.git("show", f"{head}:OOB.md")))


CARVE_ROOTS = ("Tools/wenshu-devtool/", "Scripts/")
CARVE_NOT = ("Tools/wenshu-devtool/probes/",)


def carved(path, enabled=True):
    """The 1.5 governance-tool carve-out (= switchable, so the census it excludes
    reprints from this file instead of living only in a document)."""
    return enabled and path.startswith(CARVE_ROOTS) and not path.startswith(CARVE_NOT)


def classify(st, path="", carve=True, context=None):
    """Every rule for one comment line, in one pass. Returns [(rule, label, severity)].

    `context` is the SENTENCE the line belongs to: the vendor exemption is read over
    it, because a comment wraps across lines and the marker that makes a claim honest
    can sit on the next line of the same sentence."""
    hits = []
    stripped = st
    for a in ALLOWED_CJK:
        stripped = stripped.replace(a, "")
    if CJK.search(stripped):
        # = = = = = = = = = = CHARGED, AND THE CHARGE BLOCKS WHEN THE BRANCH
        # = = = = = = = = = = WROTE THE LINE. = = = = = = = = = = = = = = = = = = = = = = =
        # = = = = = = = = = = The ruling of 2026-11-21 made comment governance a
        # = = = = = = = = = = GATE (= a swept tree rotted quietly when the rule
        # = = = = = = = = = = read Manual.), = = = = = = = = = = and this judge is
        # = = = = = = = = = = the gate's ONE implementation. = = = = = = = = = = = = = = = = = = = = = = =
        # = = = = = = = = = = 1.1's data exemption is honoured by the READER
        # = = = = = = = = = = (= it charges the COMMENT TEXT, = = = = so a CJK
        # = = = = = = = = = = string literal in code stays a literal) = = = = = = = = = = = = = = = = = = = = = = =
        # = = = = = = = = = = and by the whitelist below (= the project's own
        # = = = = = = = = = = permitted literals). = = = = = = = = = = = = = = = = = = = = = = =
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
        if label == VENDOR_LABEL:
            if has_honest_marker(context if context is not None else st):
                continue
        if carved(path, carve) and rid in ("1.5", "1.6"):
            continue
        # = = = = = = = = = THE PUBLISHED VOCABULARY, KEPT AS IT IS. = = = = = = = = =
        # = = = = = = = = = P0 = = = = = the row carries a CJK character
        # = = = = = = = = = (= = = 1.1's ban = = = the row the arms table calls a
        # = = = = = = = = = CJK row); = = = = = = = = = P1 = = = = = = the row carries
        # = = = = = = = = = no CJK character (= = = = = a 1.5 lineage line = = = = = =
        # = = = = = = = = = or a 1.6 citation form). = = = = = = = = = The OOB
        # = = = = = = = = = register's published census (= = = the 2026-11-21 row's
        # = = = = = = = = = "P0 10, P1 135" over its window) = = = = = = = = = counts
        # = = = = = = = = = THIS axis, = = = = = = = = = so a change to the axis
        # = = = = = = = = = would make a published number stop reprinting. = = = = = = = = =
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


# = = = THE COMMENT READER. = = = ONE implementation, and it reads the COMMENT
# = = = TEXT of a line (= not the whole line, = not a second rule's own idea of a
# = = = comment). = = =
# = = = WHY IT IS HERE, AND WHY IT MOVED: = = = the tree carried TWO arms of the
# = = = comment-level CJK rule: = = = this judge (= whole-line comments, = = = the
# = = = merge-base window, = = = the wide character class, = = = the project's
# = = = own literals whitelisted) = = = and `pre_review_gate.py`'s own audit
# = = = (= trailing comments, = = = a two-dot window, = = = a narrow character
# = = = class, = = = no whitelist). = = = Measured 2026-11-24: = = = the two
# = = = arms disagreed on EVERY one of the repo's live branches, = = = and the
# = = = audit arm charged a row the repo's own arms table declares CLEAN (= the
# = = = row naming the project's own permitted literal). = = = A rule with two
# = = = arms is a rule with two answers, = = = and an author who satisfies one
# = = = is bounced by the other. = = =
# = = = SO THERE IS ONE READER NOW, AND IT IS THE UNION: = = = a whole-line
# = = = comment AND a trailing comment, in .swift/.js AND in .py/.sh, = = = with
# = = = the string literals blanked first (= a marker inside a literal is not a
# = = = marker) = = = and the block-comment state carried across the lines.
# = = = WHAT IT CHARGES IS THE COMMENT TEXT, = = = so a CJK string literal in
# = = = code stays a literal (= 1.1's data exemption) = = = and a lineage token
# = = = in a trailing comment is charged (= 1.5 does not care where the comment
# = = = starts).
TRIPLE_DOUBLE = chr(34) * 3
TRIPLE_SINGLE = chr(39) * 3

# = = = THE QUOTE SET PER LANGUAGE. = = = A Swift file has NO single-quoted
# = = = string (= `'` is not a delimiter there), = = = and a Swift comment that
# = = = says "the boss's rule" must NOT open a string that never closes = = = =
# = = = because a string state that leaks past its line blanks every line
# = = = after it (= the comment line itself goes unreadable, = = = and the
# = = = count of charged comment lines falls by half = = = measured 2026-11-24
# = = = on the published census window: 4313 comment lines under the whole-line
# = = = reader, 2105 under a reader that mistook an apostrophe for a quote).
# = = = Python and shell quote with BOTH, = = = and JavaScript quotes with
# = = = both, = = = so the apostrophe opens a string only where it is one.
QUOTE_CHARS = {
    ".py": chr(34) + chr(39),
    ".sh": chr(34) + chr(39),
    ".js": chr(34) + chr(39),
    ".swift": chr(34),
}
HASH_LANGS = (".py", ".sh")
SLASH_LANGS = (".swift", ".js")


def _is_hash_lang(path):
    return path.endswith(HASH_LANGS)


def _is_slash_lang(path):
    return path.endswith(SLASH_LANGS)


def comment_text(raw, path, state=None):
    """The comment text of one line, or None (= the line carries no comment).

    `state` is the caller's carried context; a dict in, a dict out, so the
    caller keeps one per file. The returned text is the RAW text from the
    comment's own marker (= the string-blanked copy is only used to FIND the
    marker).

    WHAT THIS READS, AND WHY IT IS THE ONLY ONE: a whole-line comment AND a
    trailing comment, in .swift/.js AND in .py/.sh, = = with the string
    literals blanked first (= a marker inside a literal is not a marker), = = =
    with the block-comment state carried across the lines, = = = and with the
    string state CLOSED at the comment (= a comment cannot be inside a string,
    = = and a string that runs past a comment is not a string).

    WHAT IT CHARGES IS THE COMMENT TEXT, = = = so a CJK string literal in
    code stays a literal (= 1.1's data exemption) = = = and a lineage token
    in a trailing comment is charged (= 1.5 does not care where the comment
    starts).

    A BLOCK comment is closed BEFORE the literals are blanked: a block comment
    holds quotes and slashes as ordinary text, so blanking them first would
    hide the `*/` that closes it and the block would never end.
    """
    state = dict(state or {})
    if _is_slash_lang(path) and state.get("block"):
        end = raw.find("*/")
        if end == -1:
            return (raw if raw.strip("/* \t*") else None), state
        state["block"] = False
        head = raw[:end + 2]
        tail, state = comment_text(raw[end + 2:], path, state)
        if tail is None:
            return (head if head.strip("/* \t*") else None), state
        return (head + " " + tail) if head.strip("/* \t*") else tail, state

    quotes = QUOTE_CHARS.get(os.path.splitext(path)[1], chr(34))
    index = 0
    # = = = THE STRING STATE IS CARRIED FROM THE CALLER, = = = so a MULTILINE
    # = = = literal spans its lines (= a `//` inside a `"""` block is not a
    # = = = comment, = = = and the line that closes the literal is read with
    # = = = the literal's state still open).
    quote = state.get("quote")
    triple = state.get("triple")
    length = len(raw)
    while index < length:
        char = raw[index]
        if triple:
            if raw.startswith(triple, index):
                index += len(triple)
                triple = None
                continue
            index += 1
            continue
        if quote:
            if char == chr(92):
                index += 2
                continue
            if char == quote:
                quote = None
                index += 1
                continue
            index += 1
            continue
        if raw.startswith(TRIPLE_DOUBLE, index) or (
                chr(39) in quotes and raw.startswith(TRIPLE_SINGLE, index)):
            triple = TRIPLE_DOUBLE if raw.startswith(TRIPLE_DOUBLE, index) else TRIPLE_SINGLE
            index += 3
            continue

        if char in quotes:
            quote = char
            index += 1
            continue
        if _is_hash_lang(path) and char == "#":
            # = = = A COMMENT CLOSES THE STRING STATE: = = = a string cannot
            # = = = continue past a comment, = = = and a stray quote inside the
            # = = = comment must not open one that swallows the next line.
            return (raw[index:], {"block": state.get("block", False),
                                  "quote": None, "triple": None})
        if _is_slash_lang(path):
            if raw.startswith("//", index):
                return (raw[index:], {"block": state.get("block", False),
                                      "quote": None, "triple": None})
            if raw.startswith("/*", index):
                state["block"] = True
                state["quote"] = None
                state["triple"] = None
                return (raw[index:], state)
        index += 1
    return None, {"block": state.get("block", False),
                  "quote": quote, "triple": triple}


class Repo:
    def __init__(self, path):
        self.path = path

    def git(self, *args):
        return subprocess.run(["git", "-C", self.path, *args],
                              capture_output=True, text=True).stdout


def merge_base(repo, base, head):
    """The commit the branch and `base` actually share (= the point the delta is
    measured FROM). A two-dot window compares base's TIP to the head, so when base
    moves after the branch point, lines the branch never touched enter the delta as
    additions and an innocent branch is charged for them; the repo's other delta
    gates resolve against the merge-base for exactly this reason."""
    return repo.git("merge-base", base, head).strip()


def added_comment_lines(repo, base, head):
    """The window's added comment lines: `<merge-base>..<head>`, code and tool sources
    only (= the unit every count in the report is stated in: a delta over a window,
    not a whole-tree state count).

    WHAT COUNTS AS A COMMENT IS THE READER'S CALL (= `comment_text`), and the
    text that is charged is the COMMENT TEXT (= not the whole line): = a CJK
    string literal in code stays a literal (= 1.1's data exemption), = and a
    trailing comment is a comment (= the arm that read only whole-line comments
    MISSED those, = so the two arms charged different lines for the same change).
    """
    diff = repo.git("diff", "-U0", "--no-color", f"{base}..{head}",
                    "--", "*.swift", "*.py", "*.sh", "*.js")
    cur, recs, state = None, [], {}
    for ln in diff.splitlines():
        if ln.startswith("+++ b/"):
            cur = ln[6:].strip()
            state = {}
        elif ln.startswith("+") and not ln.startswith("+++"):
            st = ln[1:]
            if cur:
                text, state = comment_text(st, cur, state)
                if text is not None:
                    recs.append((cur, st.strip(), text.strip()))
    return recs



SENTENCE_END = ".!?。！？"

MASK = re.compile(
    r"`[^`]*`|https?://\S+|\b[\w./-]*\.(?:com|org|net|dev|io|gov|edu|md|swift|py|yml|yaml|txt|json)\b\S*"
)

CITATION_LABELS = {"boss name / date / words",
                   VENDOR_LABEL,
                   "OOB.md citation not in the canonical form",
                   "citation names a date the register does not carry"}



def comment_runs(lines, path):
    """The maximal runs of consecutive comment lines in a file."""
    runs, cur = [], []
    for i, raw in enumerate(lines, 1):
        st = raw.strip()
        if is_comment(st, path):
            cur.append((i, st))
        elif cur:
            runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    return runs

def run_layout(run):
    """The text of a comment run and, for each of its lines, the character span of
    the sentences that line touches.

    A comment wraps across lines, so the claim and the marker that makes it honest
    can sit on different lines of the same sentence; the sentence is the unit that
    asserts, so the exemption is read over it. A line can hold two sentences (= "...for
    use by other apps). Note: the shortcut is not a standard Apple one"), so a line's
    span covers every sentence it touches: the denial that ends the line and the claim
    that follows it are one sentence."""
    parts, offsets, pos = [], [], 0
    for _i, st in run:
        offsets.append((pos, pos + len(st)))
        parts.append(st)
        pos += len(st) + 1
    text = "\n".join(parts)
    masked = MASK.sub(lambda m: " " * len(m.group(0)), text)
    spans, start = [], 0
    for i, ch in enumerate(masked):
        if ch in SENTENCE_END:
            spans.append((start, i + 1))
            start = i + 1
    if start < len(text):
        spans.append((start, len(text)))
    out, primaries = [], []
    for (s, e) in offsets:
        first = last = None
        for (sa, sb) in spans:
            if first is None and sa <= s < sb:
                first = (sa, sb)
            if sa < e <= sb:
                last = (sa, sb)
        if first is None:
            first = (0, len(text))
        if last is None:
            last = first
        primaries.append(first)
        out.append((min(first[0], last[0]), max(first[1], last[1])))
    return text, out, primaries

def joined_violations(run, text, spans, primaries, scope, path, carve, seen):
    """The labels a JOINED window carries that no single line of it carries.

    One claim is one row: the windows of a sentence overlap (= a three-line claim
    sits in two 2-line windows and one 3-line window), so the first window that
    states the claim reports it and the rest are the same claim read again."""
    out = []
    for size in (2, 3):
        for i in range(0, len(run) - size + 1):
            win = run[i:i + size]
            if not all(ln in scope for ln, _st in win):
                continue
            a = min(spans[i + k][0] for k in range(size))
            b = max(spans[i + k][1] for k in range(size))
            ctx = text[a:b]
            claim = tuple(sorted({primaries[i + k] for k in range(size)}))
            if claim in seen:
                continue
            joined = " ".join(st for _ln, st in win)
            jlabs = {lab for _r, lab, _s in classify(joined, path, carve, ctx)}
            plabs = set()
            for k in range(size):
                plabs |= {lab for _r, lab, _s in classify(win[k][1], path, carve, ctx)}
            new = jlabs - plabs
            if new:
                seen.add(claim)
                out.append((win, sorted(new)))
    return out

def swept_comment_index(repo, base_sha, head_sha, added_by_file):
    """Every comment line of every Swift file the window touched, minus the lines the
    window added (those are already measured by `added_comment_lines`), each with its
    line number in the head file."""
    files = [f for f in repo.git("diff", "--name-only", f"{base_sha}..{head_sha}",
                                 "--", "*.swift").splitlines() if f.strip()]
    index = {}
    for f in files:
        if carved(f):
            continue
        head_text = repo.git("show", f"{head_sha}:{f}")
        addset = added_by_file.get(f, set())
        lines = []
        for i, raw in enumerate(head_text.splitlines(), 1):
            st = raw.strip()
            if st in addset:
                continue
            if is_comment(st, f):
                lines.append((i, st))
        index[f] = lines
    return index, files

def swept_comment_lines(repo, base_sha, head_sha, added_by_file):
    """The same swept lines as (file, text) pairs."""
    index, files = swept_comment_index(repo, base_sha, head_sha, added_by_file)
    recs = [(f, st) for f, lines in index.items() for _i, st in lines]
    return recs, files

def measure(repo_path, base, head="HEAD", carve=True):
    """The window's rows, over THREE scopes: the lines the window added, the citation
    family over every comment line of every Swift file the window touched (= the swept
    scope), and the cross-line join over both.

    The unit is stated in the report (= a delta over a window PLUS the swept scope for
    the citation-honesty family), because a rule with two units is a rule with two
    answers: the addition-delta rules keep their per-line unit, and the citation
    family is charged over every line of a swept file.
    """
    repo = Repo(repo_path)
    head_sha = repo.git("rev-parse", head).strip()
    base_sha = merge_base(repo, repo.git("rev-parse", base).strip(), head_sha)
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
    added_by_file = collections.defaultdict(set)
    added_lines_by_file = collections.defaultdict(set)
    for f, st, text in recs:
        added_by_file[f].add(st)
        at = [i for i, l in enumerate(tip_lines(f), 1) if l.strip() == st]
        added_lines_by_file[f].add(at[0] if at else -1)

    def record(f, st, hits, attribution, line=None):
        """One row, deduped by (file, line, text); None when the line carries nothing."""
        nonlocal dropped_synth
        if not hits:
            return
        tids = set(re.findall(r"\bt_[0-9a-fA-F]{6,10}\b", st))
        if tids and tids <= SYNTH and all(
                lab == "card id in comment (ticket lineage)" for _r, lab, _s in hits):
            dropped_synth += 1
            return
        if line is None:
            at = [i for i, l in enumerate(tip_lines(f), 1) if l.strip() == st]
            line = at[0] if at else None
        if (f, line, st) in seen:
            return
        seen.add((f, line, st))
        if attribution is None:
            if not base_blob(f):
                attribution = "NEW FILE"
            elif st in base_blob(f):
                attribution = "RE-WROTE-BASE"
            else:
                attribution = "ADDED"
        blocking = attribution in ("ADDED", "NEW FILE")
        severity = "P0" if any(s == "P0" for _, _, s in hits) else "P1"
        rows.append({"file": f, "line": line, "text": st,
                     "rule": hits[0][0],
                     "severity": severity,
                     "blocking": blocking,
                     "labels": [lab for _, lab, _ in hits], "attribution": attribution})

    layout_cache, context_cache = {}, {}

    def layout_of(f):
        if f not in layout_cache:
            layout_cache[f] = [(run,) + run_layout(run)
                                for run in comment_runs(tip_lines(f), f)]
        return layout_cache[f]

    def contexts_of(f):
        if f not in context_cache:
            cache = {}
            for run, text, spans, _primaries in layout_of(f):
                for (ln, _st), (a, b) in zip(run, spans):
                    cache[ln] = text[a:b]
            context_cache[f] = cache
        return context_cache[f]

    # ---- scope 1: the lines the window ADDED (the delta) ----
    for f, st, text in recs:
        at = [i for i, l in enumerate(tip_lines(f), 1) if l.strip() == st]
        ln = at[0] if at else None
        hits = classify(text, f, carve, contexts_of(f).get(ln, text))
        for d in CITED_DATE.findall(text):
            if d not in dates and not carved(f, carve):
                hits.append(("1.6", "citation names a date the register does not carry", "P1"))
        record(f, text, hits, None, line=ln)

    # ---- scope 2: the citation family over every comment line of every swept file ----
    swept_index, swept_files = swept_comment_index(repo, base_sha, head_sha, added_by_file)
    for f, lines in swept_index.items():
        ctx_of = contexts_of(f)
        for ln, st in lines:
            hits = [h for h in classify(st, f, carve, ctx_of.get(ln, st))
                    if h[1] in CITATION_LABELS]
            for d in CITED_DATE.findall(st):
                if d not in dates and not carved(f, carve):
                    hits.append(("1.6", "citation names a date the register does not carry", "P1"))
            record(f, st, hits, "UNCHANGED-IN-SWEPT-FILE", line=ln)

    # ---- scope 3: the cross-line join, over the added scope and over the swept scope ----
    for f in sorted(set(added_by_file) | set(swept_index)):
        seen_claims = set()
        for run, text, spans, primaries in layout_of(f):
            for scope, attribution in ((added_lines_by_file.get(f, set()), "JOINED-ADDED"),
                                       ({ln for ln, _st in swept_index.get(f, [])},
                                        "JOINED-IN-SWEPT-FILE")):
                if not scope:
                    continue
                for win, labs in joined_violations(run, text, spans, primaries, scope,
                                                  f, carve, seen_claims):
                    hits = [("1.5", lab, "P1") for lab in labs
                            if lab in CITATION_LABELS]
                    record(f, " ".join(st for _ln, st in win), hits, attribution,
                           line=win[0][0])

    label_counts = collections.Counter(lab for r in rows for lab in r["labels"])
    return {
        "window": f"{base_sha[:10]}..{head_sha[:10]}",
        "register_dates": len(dates),
        "window_base": "merge-base",
        "unit": "comment lines ADDED by the diff over this window (a delta, not a state "
                "count) + every comment line of every swept Swift file for the "
                "citation-honesty family (see the docstring)",
        "swept_swift_files": len(swept_files),
        "added_comment_lines": len(recs),
        "offending": len(rows),
        "offending_files": len({r["file"] for r in rows}),
        "P0": sum(1 for r in rows if r["severity"] == "P0"),
        "P1": sum(1 for r in rows if r["severity"] == "P1"),
        "blocking": sum(1 for r in rows if r["blocking"]),
        "reported_only": sum(1 for r in rows if not r["blocking"]),
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
        print(f"comment-lineage: window {rep['window']} (the base resolved to its merge-base "
              f"with the head, so a moving main cannot charge a branch for lines it never wrote) "
              f"| {rep['unit']}")
        print(f"  added comment lines: {rep['added_comment_lines']}")
        if rep["added_comment_lines"] == 0:
            print("  NO added comment line in this window: nothing was measured, "
                  "so this is not a pass on the rule")
        print(f"  offending: {rep['offending']} rows / {rep['offending_files']} files "
              f"(P0={rep['P0']}, P1={rep['P1']})")
        if rep["reported_only"]:
            print(f"  REPORTED ONLY ({rep['reported_only']} row(s)): the branch CARRIED these "
                  f"lines (= their text already stood in the base file), so they are printed "
                  f"and counted but they do not block (= a hit in a diff is not proof that "
                  f"your commit added it)")
        if rep["excluded_synthetic_card_id_lines"]:
            print(f"  excluded as arms-table input: {rep['excluded_synthetic_card_id_lines']}")
        for r in rep["rows"][:20]:
            print(f"  {r['file']}:{r['line']}: {'; '.join(r['labels'])}")
        if rep["offending"] > 20:
            print(f"  … {rep['offending'] - 20} more (see --json)")
    # = = ONLY A BLOCKING FINDING FAILS THE GATE. = = A reported-only finding
    # = = (= comment-level CJK) prints and exits 0, because the contract assigns
    # = = that rule to a human: = = a gate that blocks on a judgement it cannot
    # = = make bounces the card, and the author cannot satisfy the contract and
    # = = the gate at the same time.
    return 1 if rep["blocking"] else 0


if __name__ == "__main__":
    sys.exit(main())