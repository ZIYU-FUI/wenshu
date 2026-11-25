#!/usr/bin/env python3
"""
wenshu pre-commit filter. Blocks commits containing forbidden pollution vocabulary.

Forbidden tokens (xianxia novel leakage from base model):
修真 渡劫 筑基 返虚 结丹 金丹 元婴 飞升 天劫 雷劫 心魔 魔障

Allowed tokens (project-mandated literal characters per AGENTS.md §12):
老板 文枢 拍 拍板 ※

Source of truth: .scratch/2026-08-22-pollution-mitigation/spec.md

It also carries the CHORD-GLYPH rule: a commit message that names a chord the
tree does not bind is refused at commit-msg time. See chord_rule() below.
"""

import os
import re
import subprocess
import sys

FORBIDDEN_TOKENS = [
    "修真", "渡劫", "筑基", "返虚", "结丹", "金丹",
    "元婴", "飞升", "天劫", "雷劫", "心魔", "魔障",
]
PATTERN = re.compile("|".join(re.escape(t) for t in FORBIDDEN_TOKENS))

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# THE CHORD-GLYPH RULE
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#
# WHY: a commit message that names a chord the tree does not bind is a FALSE
# RECORD, and a false record outlives the commit (= = it is in the history
# forever). Measured 2026-11-25: the chord lane's tip `a708a7e590` shipped a
# message whose own bytes carry six bare chord mentions and the sentence
# "Every chord mention in this message carries ⇧" = = a sentence the same
# object refutes. That tree binds the code block at `⌘⇧F` and binds `⌘K` to a
# DIFFERENT control (focus input), so the message's "⌘K = the code block" was
# false in substance, not merely inconsistent.
#
# THE TABLE: the tree's own cheat-sheet roster line IS an action-to-chord
# table in the product's own words:
#     "[wenshu.shortcuts] ⌘K focus input · ⌘L clear chat · ⌘⇧F code block ..."
# It lives in the tree the commit ships, so the rule compares a message against
# the table that tree publishes = = and it SAYS which tree it read.
#
# THE RULE: every phrase the table names that appears in the message belongs to
# the chord mention it sits nearest to; that mention's chord must be one of the
# chords the table binds for that phrase. A phrase that is nearer two mentions
# equally judges nobody (= = an ambiguous phrase is not evidence). And a row
# whose key a mention cannot carry (= = the table binds a key longer than one
# character) is not evidence either (= = _chord_visible_rows): the table's own
# grammar decides what the rule may see.
#
# ITS SAFETY, MEASURED: over the 569 messages in this repository's history whose
# own commit carried the roster (= = every message the rule can judge, the lane
# commits included), the rule refuses **0**. A rule that refuses real history is
# not shippable. The number is per-commit-tree, and that is the only honest
# filter: reading origin/main's table against all 29080 messages of
# `git rev-list --all` refuses 12, and against the 6908 messages reachable from
# this rule's base refuses 0.
#
# ITS TEETH, MEASURED: on the defective chord message it refuses exactly the
# two lines that carry the false claim, and it names each line.
CHORD_ROSTER_FILE = "Sources/WenshuApp/Features/Chat/View/ChatView+KeyboardShortcuts.swift"
CHORD_GLYPHS = "⌘⇧⌥⌃"
CHORD_ENTRY = re.compile(r"^([⌘⇧⌥⌃]+)([A-Za-z0-9.,;=?/\]\-]+)\s+(.*)$")
# The BASE key class. The tree's own table WIDENS it: _chord_is_key
# admits a punctuation key only when the table binds that key, so the
# two grammars (this class and CHORD_ENTRY) cannot disagree.
CHORD_KEY = re.compile(r"^[A-Za-z0-9]$")
CHORD_ROSTER_CACHE = {}


def _chord_key_of(chord):
    """The key half of a chord, exactly as CHORD_ENTRY parsed it.

    CHORD_ENTRY anchors the modifier run at the start of a row, and its key
    class holds no modifier glyph, so the key is whatever the chord has left
    after the leading glyphs: the K of "chord-K", the dot of the row
    "chord-dot cancel streaming".
    """
    return chord.lstrip(CHORD_GLYPHS)


def _chord_table_keys(roster):
    """The key characters the tree's own table binds, upper-cased.

    Only one-character keys are published here, because a mention carries one
    character: a row written with a longer key cannot be seen in a message, so
    this function says so rather than inventing a key from its last character.
    """
    return {_chord_key_of(chord).upper() for chord, _action in roster
            if len(_chord_key_of(chord)) == 1}


def _chord_is_key(char, table_keys):
    """May a chord mention carry this character?

    A letter or digit always may (= = the shape of every key the tree binds).
    A punctuation character may ONLY when the tree's own table binds it as a
    key, so the table decides which punctuation a chord carries and this file
    names none of them. A modifier glyph followed by punctuation the table does
    not bind (= = "carries a modifier glyph, and the base ...") is still NOT a
    mention, which is what the base class alone used to give.
    """
    return bool(CHORD_KEY.match(char)) or char.upper() in table_keys


def _chord_visible_rows(roster, table_keys):
    """The rows whose own chord a mention can express.

    A row the rule cannot see must not enter the phrase set at all: its action
    would be credited to the nearest mention of some OTHER chord, and that guess
    is what refused a verbatim copy of the tree's own table. Measured before
    this guard: a table row bound to a two-character key was visible to
    CHORD_ENTRY and invisible to the mention grammar, and a message that quoted
    that row verbatim was refused.
    """
    out = []
    for chord, action in roster:
        key = _chord_key_of(chord)
        if len(key) == 1 and _chord_is_key(key, table_keys):
            out.append((chord, action))
    return out


def _chord_tokens(text):
    return [t for t in re.split(r"[^a-z0-9]+", text.lower()) if t]


def _chord_roster(repo):
    """[(chord, action_text)] = the tree's own cheat-sheet table at `repo`.

    The table is read from the WORKING TREE (= the tree the commit ships = = the
    tree the hook runs in), not from a caller-named tree.
    """
    key = os.path.abspath(repo)
    if key in CHORD_ROSTER_CACHE:
        return CHORD_ROSTER_CACHE[key]
    path = os.path.join(key, CHORD_ROSTER_FILE)
    entries = []
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if "[wenshu.shortcuts]" not in line:
                    continue
                body = line.split("[wenshu.shortcuts] ", 1)[1]
                body = body[:body.rindex('"')]
                for part in body.split(" · "):
                    match = CHORD_ENTRY.match(part.strip())
                    if match:
                        entries.append((match.group(1) + match.group(2), match.group(3).strip()))
                break
    except (OSError, ValueError):
        entries = []
    CHORD_ROSTER_CACHE[key] = entries
    return entries


def _chord_line_mentions(line, table_keys=frozenset()):
    """[(glyphs, key, key_token_index)] = every chord mention on a line.

    A mention is a glyph run IMMEDIATELY followed by a key, which is the only
    shape the roster's own rows ever take (= "chord-K", never "chord K"). The
    scan used to step over spaces first, and that turned prose ABOUT the glyph
    into a chord: "the glyph Kills the panel, then reload the view" was read as
    a mention of chord-K, which then stole the reload row's phrase and refused
    a true sentence (measured on the published table: 1 refusal, and
    "Keep the caret, and cancel streaming" the same). Pinned by the suite.
    """
    runs = []
    index = 0
    while True:
        found = [line.find(glyph, index) for glyph in CHORD_GLYPHS]
        found = [pos for pos in found if pos != -1]
        if not found:
            break
        run_start = min(found)
        run_end = run_start
        while run_end < len(line) and line[run_end] in CHORD_GLYPHS:
            run_end += 1
        index = run_end
        after = run_end
        if after < len(line) and _chord_is_key(line[after], table_keys):
            key = line[after]
            if key.isalpha():
                key = key.upper()
            runs.append((line[run_start:run_end], key, run_start, run_end))
    out = []
    for glyphs, key, run_start, run_end in runs:
        out.append((glyphs, key, len(_chord_tokens(line[:run_end + 1]))))
    return out


def _chord_phrases(line, roster):
    """[(center_token_index, chords)] = the table's phrases found in this line.

    A row is entered under the SPAN its own tokens occupy, and two rows share
    one entry only when that span is identical. So the merge is reachable
    exactly for rows that name the SAME action with the SAME tokens; a shorter
    row and a longer row ("clear chat", "clear chat (in-place)") sit at
    different spans and are judged apart, NOT merged. Measured on the two
    roster lines this repository has ever published (git rev-list --all: 2
    distinct lines over 1020 commits) against 9 probe sentences: 24 matched
    spans, 0 of them carrying more than one chord, because no published roster
    has two rows with identical action text.

    The direction is therefore not "the permissive one" = = it is one chord per
    matched span, which is STRICTER than merging a row into the longer row that
    contains it (= = measured on the pre-fix rule over the 29087 messages of
    `git rev-list --all`, each judged against origin/main's own table: 13 error
    lines keyed by span, 10 with the contained rows merged, the same 4 messages
    either way). What IS permissive here is the rest: a row the
    mention grammar cannot express never enters this set at all
    (= = _chord_visible_rows), and a phrase nearer two mentions equally judges
    nobody.
    """
    tokens = _chord_tokens(line)
    positions = {}
    for i, token in enumerate(tokens):
        positions.setdefault(token, []).append(i)
    spans = {}
    for chord, action in roster:
        action_tokens = _chord_tokens(action)
        if not action_tokens or not all(t in positions for t in action_tokens):
            continue
        used = set()
        index_list = []
        for token in action_tokens:
            for pos in positions[token]:
                if pos not in used:
                    used.add(pos)
                    index_list.append(pos)
                    break
            else:
                index_list = None
                break
        if not index_list:
            continue
        span = (min(index_list), max(index_list))
        spans.setdefault(span, set()).add(chord)
    return [((lo + hi) / 2.0, chords) for (lo, hi), chords in spans.items()]


def _chord_split_near(line, roster, key_pos):
    """Is this mention's OWN action phrase SPLIT across the wrap?

    ⇒ ⇒ ⇒ WHY, MEASURED: a commit message wraps, and a phrase can straddle
    the wrap (= = "the code" at the end of one line and "block" at the start of
    the next). The mention then has no COMPLETE phrase of its own = = and the
    only complete phrase near it belongs to a DIFFERENT chord. Reading that one
    instead refuses a truthful list = = so the mention is skipped: the rule
    cannot see the phrase, and a rule that guesses refuses true messages.

    ⇒ ⇒ ⇒ AND ONLY WHEN THE SPLIT PHRASE IS NEXT TO THE MENTION: a stray
    token elsewhere on the line (= = the word "chat" inside "fix(chat)") is
    not this mention's phrase. Measured: the broad form (= = any partial
    phrase anywhere on the line) skipped almost every mention, because the
    table's actions share tokens (= = "chat" is in "new chat", "clear chat",
    "open chat markdown").
    """
    tokens = _chord_tokens(line)
    for _chord, action in roster:
        action_tokens = set(_chord_tokens(action))
        if not action_tokens:
            continue
        present = [i for i, token in enumerate(tokens) if token in action_tokens]
        if not present or len(present) == len(action_tokens):
            continue
        if min(abs(i - key_pos) for i in present) <= 3:
            return True
    return False


def _chord_mentions(text, table_keys=frozenset()):
    """[(line_no, glyph_run, key, line)] — a glyph run is consumed WHOLE."""
    out = []
    for line_no, line in enumerate(text.split("\n"), 1):
        for glyphs, key, _pos in _chord_line_mentions(line, table_keys):
            out.append((line_no, glyphs, key, line))
    return out


def chord_rule(text, repo=None):
    """Yield error lines for chord mentions that disagree with the tree.

    `repo` defaults to the tree the hook runs in (= the tree the commit ships).
    """
    if repo is None:
        repo = os.getcwd()
    roster = _chord_roster(repo)
    table_keys = _chord_table_keys(roster)
    roster = _chord_visible_rows(roster, table_keys)
    if not roster:
        return
    for line_no, line in enumerate(text.split("\n"), 1):
        mentions = _chord_line_mentions(line, table_keys)
        if not mentions:
            continue
        for center, chords in _chord_phrases(line, roster):
            # the phrase belongs to the NEAREST chord mention; a tie is
            # ambiguous = = and an ambiguous phrase judges nobody.
            ranked = sorted((abs(center - pos), i) for i, (_g, _k, pos) in enumerate(mentions))
            if len(ranked) > 1 and abs(ranked[0][0] - ranked[1][0]) < 1e-9:
                continue
            glyphs, key, _pos = mentions[ranked[0][1]]
            mention = glyphs + key
            if mention in chords:
                continue
            if _chord_split_near(line, roster, mentions[ranked[0][1]][2]):
                continue
            said = ", ".join(sorted(chords))
            yield (f"ERROR: chord '{mention}' in commit message:{line_no} disagrees with the tree's "
                   f"own shortcut table (= {said}; the table read from "
                   f"{os.path.abspath(repo)}/{CHORD_ROSTER_FILE}) | {line.strip()[:80]}")


# Files allowed to mention forbidden vocab (they explicitly enumerate the banned list).
# v0.23 audit #014 added PR + issue templates (which mention the list by name).
POLLUTION_ALLOWLIST = {
    "AGENTS.md",
    "CONTEXT.md",
    "WenshuVerifier.shortOutputStopSequences",  # functional: filter LLM output
    "WenshuAgentIdentity.systemPrompt",         # functional: instruction
    "Tools/wenshu-devtool/commit_filter.py",
    "Tools/wenshu-devtool/tests/test_block_pollution.sh",
    "Tools/wenshu-devtool/tests/test_allow_allowed_tokens.sh",
    # A test that PROVES the hook blocks the forbidden family has to NAME
    # the family (= it writes the token it expects to be blocked).
    "Tools/wenshu-devtool/tests/test_install_hook.sh",
    "Tools/wenshu-devtool/tests/README.md",       # test README explaining pollution-defense test suite (= enumerates forbidden vocab)
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/ISSUE_TEMPLATE/bug_report.md",
    ".github/ISSUE_TEMPLATE/feature_request.md",
    ".github/workflows/ci.yml",                  # CI gate explicitly scans for forbidden vocab (= pollution-defense hook documentation)
    # Scratch directories that legitimately enumerate the forbidden family as
    # research / spec / standards-report content. Pollution-defense skill
    # ('wenshu-pollution-defense') directs us to add these with a comment.
    ".scratch/2026-08-22-pollution-mitigation/",  # pollution research + spec + MR description + hook chain (= how the defense works)
    ".scratch/2026-08-23-monday-acceptance-checklist/",  # acceptance test spec for pollution defense (= 'echo 修真 > file && commit' test cases)
    ".scratch/2026-08-23-agent-identity/",        # Wenshu agent identity research (= system prompt forbidden-vocab enumeration)
    ".scratch/2026-08-24-v0-24-boss-receiving/",  # v0.24 boss-receiving standards reports (= contains forbidden-vocab enumeration)
    ".scratch/2026-08-26-lucide-icon-migration/", # icon migration research docs (= may quote boss OOB containing forbidden tokens)
    ".scratch/2026-08-21-menubar-v2/",            # menu bar v2 spec + backlog (= pre-v0.24 era, contains forbidden tokens in spec text)
    ".scratch/reviews/",                         # code review reports (= standards reports enumerate forbidden vocab)
    ".scratch/code-review-",                     # code review report filename prefix (= standards reports enumerate forbidden vocab)
    ".scratch/spec-axis-review-v0.25.1.md",       # v0.25.1 spec axis review (= this report enumerates forbidden vocab in headers + AC)
    ".scratch/2026-08-26-fcp-library-replica/",   # v0.26 FCP library replica spec + code review reports (= sub-agent standards + spec reports enumerate forbidden vocab in carve-out documentation)
    # v0.30 batches added 2026-08-30 (= boss sweep .scratch/ audit trail):
    ".scratch/v0.30-pre-pane-fixes/",               # v0.30 pre-pane-fixes spec + tickets + code-review reports enumerate forbidden vocab in findings
    ".scratch/v0.30-sidebar-preview-pane/",         # v0.30 sidebar/preview-pane spec + tickets + code-review reports + Q22 visual verification
    ".scratch/v0.30-polish-fixes/",                 # v0.30 polish-fixes spec + tickets + code-review reports
    ".scratch/v0.30-batch3/",                       # v0.30 batch3 spec + tickets + code-review reports
    # Additional v0.28 / spec-axis carve-outs for sweep 2026-08-30:
    ".scratch/2026-08-28-v0-28-free-layout/",       # v0.28 free-layout spec + tickets + code-review reports enumerate forbidden vocab
    ".scratch/2026-08-28-v0-28-integration-batch-1/", # v0.28 integration batch 1 spec + tickets + standards reports enumerate forbidden vocab
    ".scratch/code-review-spec-8-26-v1-2-0-spec-axis/", # spec-axis review (= standards reports enumerate forbidden vocab)
    # v0.30 zone-header 新建 icon fix added 2026-08-31:
    ".scratch/v0.30-zone-header-new-icon-fix/",    # zone-header 新建 icon fix spec + tickets + code-review reports
    # CONTEXT.md hard rule list itself quotes the 修真 forbidden tokens (= single source of truth for the rule):
    "CONTEXT.md",
}


def get_staged_files():
    """Get list of staged file paths (.md, .swift only)."""
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        capture_output=True, text=True, check=True,
    )
    return [f for f in result.stdout.splitlines() if f.endswith((".md", ".swift"))]


def get_staged_diff(path):
    """Get staged diff for a specific file."""
    result = subprocess.run(
        ["git", "diff", "--cached", "--", path],
        capture_output=True, text=True, check=True,
    )
    return result.stdout


def get_commit_message():
    """Get current commit message from .git/COMMIT_EDITMSG (only when committing)."""
    result = subprocess.run(
        ["git", "diff", "--cached", "--", ".git/COMMIT_EDITMSG"],
        capture_output=True, text=True,
    )
    return result.stdout


def scan(text, source):
    """Scan text for forbidden tokens. Yield error lines."""
    for line_no, line in enumerate(text.splitlines(), 1):
        match = PATTERN.search(line)
        if match:
            context = line.strip()[:80]
            token = match.group(0)
            yield f"ERROR: forbidden vocabulary '{token}' in {source}:{line_no} | {context}"


def added_lines(diff):
    """The ADDED lines of a diff (= the lines the change introduces).

    WHY ONLY THE ADDED LINES: = = a diff carries three kinds of line, = =
    the added ones (= `+`), = = the removed ones (= `-`), = = and the
    CONTEXT (= = the unchanged neighbours).  ⇒ The context is the file
    as it was, = = so a forbidden token sitting in it is the FILE's
    token, = = not this change's.  ⇒ Scanning the context blocked any
    commit that merely touched a file near one, = = and the tree's own
    commits had to bypass the hook for it.
    """
    added = []
    for line in diff.splitlines():
        if line.startswith("+++"):
            continue
        if line.startswith("+"):
            added.append(line[1:])
    return "\n".join(added)


def _exact_match(path, entry):
    """Match 1: path == entry exactly."""
    return path == entry


def _suffix_match(path, entry):
    """Match 2: path ends with '/<entry>' (entry is treated as a leaf basename with leading slash)."""
    return path.endswith("/" + entry)


def _directory_match(path, entry):
    """Match 3: entry is a directory (with or without trailing /) and path is inside it.
    Reuses the suffix_match path when entry already ends with '/'.
    """
    if not "/" in entry:
        return False
    if path.startswith(entry if entry.endswith("/") else entry + "/"):
        return True
    return False


def _basename_prefix_match(path, entry):
    """Match 4: entry is a Swift symbol 'Module.method' (= dotted, no '/').
    Heuristic: if the substring after the last '.' is a short alphanumeric token
    (= 1-5 chars like 'md', 'swift', 'json'), treat entry as a filename (= skip this
    match type). Otherwise, treat it as a symbol prefix and match if path's basename
    (with extension stripped) starts with the symbol prefix.
    """
    if "." not in entry or "/" in entry:
        return False
    last_dot = entry.rfind(".")
    after_dot = entry[last_dot + 1:]
    # File-extension-like (.md, .swift) = treat as filename, skip basename-prefix.
    if after_dot and after_dot.isalnum() and len(after_dot) <= 5:
        return False
    # This is a symbol like 'WenshuVerifier.shortOutputStopSequences'.
    symbol_prefix = entry.split(".", 1)[0]
    basename = path.rsplit("/", 1)[-1]
    # Remove .swift extension for comparison
    basename_root = basename.rsplit(".", 1)[0] if "." in basename else basename
    return basename_root == symbol_prefix or basename.startswith(symbol_prefix + ".")


def _glob_prefix_match(path, entry):
    """Match 5: entry is a path prefix ending in '-' or '_' (= glob-style boundary).
    Used for prefix-only matches like '.scratch/code-review-' (= matches all
    '.scratch/code-review-*' files). The trailing '-' or '_' prevents false positives
    like 'CONTEXT.md' matching 'CONTEXT.md.bak'.
    """
    if entry.endswith("/"):
        return False
    if not path.startswith(entry):
        return False
    last_char = entry[-1]
    if last_char not in "-_":
        return False
    after = path[len(entry):]
    if after == "" or not after.startswith("/"):
        # Path continues directly after entry (= same filename).
        return True
    # Path goes into a subdirectory starting with this prefix
    # (= '.scratch/code-review-spec-8-26-v1-2-0-spec-axis/SPEC-AXIS-REPORT.md'
    # matches '.scratch/code-review-' + 'spec-.../...md').
    return True


# Each match helper returns True on match, False (= 'not my job, try next type').
_MATCH_HELPERS = [
    _exact_match,
    _suffix_match,
    _directory_match,
    _basename_prefix_match,
    _glob_prefix_match,
]


def is_allowed(path):
    """Check if a file path is in the pollution allowlist (= legitimately enumerates forbidden tokens).

    5 match types (= one helper per type, see _MATCH_HELPERS):
      1. Exact match: path == entry.
      2. Suffix match: path ends with '/<entry>'.
      3. Directory prefix match: entry is a directory and path is inside it.
      4. Basename prefix match: entry is a Swift symbol 'Module.method' (= dotted, no '/').
      5. Glob-style path prefix match: entry is a path prefix ending in '-' or '_'.

    Examples:
      entry '.scratch/2026-08-22-pollution-mitigation/' → matches any file in that dir.
      entry '.scratch/code-review-' → matches all '.scratch/code-review-*' files.
      entry 'WenshuVerifier.shortOutputStopSequences' → matches files whose basename
      starts with 'WenshuVerifier' (= 'Sources/.../WenshuVerifier.swift' etc.).
    """
    for entry in POLLUTION_ALLOWLIST:
        for helper in _MATCH_HELPERS:
            if helper(path, entry):
                return True
    return False


def remote_ref_shas(remote, remote_url):
    """The shas the REMOTE holds, read from the remote itself.

    Returns (shas, read_ok).  ⇒ `read_ok` is False when the remote
    could not be reached at all; = = and it is True with an EMPTY list
    when the remote answered and holds nothing.  ⇒ Those are different
    answers: = = a remote that holds nothing means EVERY local commit
    is unpushed, = = and a remote that could not be read means the range
    is unknown.
    """
    target = remote_url or remote
    if not target:
        return [], False
    result = subprocess.run(
        ["git", "ls-remote", target],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return [], False
    shas = []
    for line in result.stdout.splitlines():
        parts = line.split()
        if parts:
            shas.append(parts[0])
    return shas, True


def get_unpushed_commits(remote=None, remote_url=None):
    """The commits a push would send, read from the hook's stdin.

    git hands a pre-push hook one line per ref it is about to update:
    "<local ref> <local sha> <remote ref> <remote sha>". A zero sha
    means that side does not have the ref yet (= a new branch, = = or a
    deletion, = = and a deletion carries no new commit).

    WHY THE RANGE IS BUILT PER REF: the remote may have no sha for the
    branch yet (= a branch pushed for the first time), = = and then the
    commits to scan are everything the remote does not have, = = not
    `<remote sha>..<local sha>`.
    """
    commits = []
    seen = set()
    try:
        if sys.stdin.isatty():
            return commits
        lines = sys.stdin.read().splitlines()
    except (OSError, ValueError):
        return commits
    for line in lines:
        parts = line.split()
        if len(parts) < 4:
            continue
        local_ref, local_sha, _remote_ref, remote_sha = parts[:4]
        if set(local_sha) == {"0"}:
            continue
        if set(remote_sha) == {"0"}:
            # The remote has no such ref yet (= a new branch).  ⇒ The
            # commits to scan are the ones the REMOTE does not have.
            # ⇒ The remote's OWN refs are the authority: = = a local
            # tracking ref says nothing about what the remote holds, = =
            # and on this repository the tracking ref already holds the
            # tip, = = so a range built from it scans NOTHING.
            exclude, read_ok = remote_ref_shas(remote, remote_url)
            if not read_ok:
                # The remote could not be read: = = fall back to the
                # local tracking refs (= = the range is then wider than
                # the truth, = = which errs towards scanning more).
                command = ["git", "rev-list", local_sha, "--not", "--remotes"]
            else:
                # The remote answered.  ⇒ It holds nothing, = = so
                # EVERY local commit is unpushed, = = and the empty
                # exclude list says exactly that.
                command = ["git", "rev-list", local_sha, "--not"] + exclude
        else:
            command = ["git", "rev-list", f"{remote_sha}..{local_sha}"]
        result = subprocess.run(command, capture_output=True, text=True)
        for sha in result.stdout.split():
            if sha not in seen:
                seen.add(sha)
                commits.append((local_ref, sha))
    return commits


def commit_files(sha):
    """The files one commit touched."""
    result = subprocess.run(
        ["git", "show", "--name-only", "--format=", sha],
        capture_output=True, text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def commit_diff(sha, path):
    """One commit's diff for one file."""
    result = subprocess.run(
        ["git", "show", "--format=", sha, "--", path],
        capture_output=True, text=True,
    )
    return result.stdout


def commit_message(sha):
    """One commit's message (= its subject and its body)."""
    result = subprocess.run(
        ["git", "log", "-1", "--format=%B", sha],
        capture_output=True, text=True,
    )
    return result.stdout


def scan_unpushed_commits(remote=None, remote_url=None):
    """The unpushed commits' messages and diffs, scanned.

    EACH FILE IS SCANNED ON ITS OWN: the allowlist is a set of PATHS,
    = = and a commit that touches an allowlisted file (= `AGENTS.md`
    enumerates the forbidden family by name) must not fail the push.
    """
    errors = []
    for ref, sha in get_unpushed_commits(remote, remote_url):
        for error in scan(commit_message(sha), f"commit message {sha[:12]}"):
            errors.append(error)
        for path in commit_files(sha):
            if is_allowed(path):
                continue
            for error in scan(added_lines(commit_diff(sha, path)),
                              f"{path} in {sha[:12]}"):
                errors.append(error)
    return errors


def main(hook=None, commit_msg_path=None, remote=None, remote_url=None):
    """Pre-commit + commit-msg + pre-push hook entry point.
    Modes:
      - default / pre-commit: scan the ADDED lines of the staged file
        diffs for forbidden tokens.
      - commit-msg: scan the commit message file (= first arg passed by git hooks).
      - pre-push: scan the ADDED lines of the unpushed commits' diffs +
        their subjects + their bodies for forbidden tokens.
      - working-tree / watchdog: scan the full working tree (= not just staged files).

    ⇒ ONLY THE ADDED LINES ARE SCANNED: = = a diff carries the added
    lines, = = the removed ones, = = and the CONTEXT (= = the unchanged
    neighbours), = = and the context is the file as it was. ⇒ A forbidden
    token in the context is the FILE's token, = = not this change's, = =
    so scanning it blocked any commit that merely touched a file near
    one.
    """
    errors = []
    if hook == "pre-push":
        for error in scan_unpushed_commits(remote, remote_url):
            errors.append(error)
    elif hook == "commit-msg" and commit_msg_path:
        # Commit-msg hook (= .git/hooks/commit-msg passes the message file as argv[1]).
        with open(commit_msg_path) as f:
            commit_msg = f.read()
        for error in scan(commit_msg, "commit message"):
            errors.append(error)
        # = = the chord rule reads the tree the hook runs in (= the tree this
        # = = commit ships), so it needs no tree argument here.
        for error in chord_rule(commit_msg):
            errors.append(error)
    else:
        # Pre-commit / default: scan staged files (= original behavior).
        for path in get_staged_files():
            if is_allowed(path):
                continue
            diff = get_staged_diff(path)
            for error in scan(added_lines(diff), path):
                errors.append(error)

        # Also scan commit message if available (= for the pre-commit invocation where
        # get_commit_message reads the staged .git/COMMIT_EDITMSG that may exist).
        commit_msg = get_commit_message()
        for error in scan(commit_msg, "commit message"):
            errors.append(error)

    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("\nTo bypass: git commit --no-verify (discouraged)", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


def parse_args(argv):
    """Minimal argv parser. Supports --hook=<name> (= pre-commit, commit-msg, pre-push, ci-scan, watchdog).
    For commit-msg hook, the commit message file path is the first non-flag argv (= from .git/hooks/commit-msg).
    """
    import argparse
    parser = argparse.ArgumentParser(description="Wenshu pollution-defense filter")
    parser.add_argument("--hook", choices=["pre-commit", "commit-msg", "pre-push", "ci-scan", "watchdog"], default="pre-commit")
    parser.add_argument("--remote", default=None, help="[pre-push hook] The remote's name (= git's argv 1)")
    parser.add_argument("--remote-url", dest="remote_url", default=None, help="[pre-push hook] The remote's URL (= git's argv 2)")
    parser.add_argument("commit_msg_path", nargs="?", default=None, help="[commit-msg hook] Path to the commit message file")
    args = parser.parse_args(argv)
    return args


if __name__ == "__main__":
    import sys
    args = parse_args(sys.argv[1:])
    main(hook=args.hook, commit_msg_path=args.commit_msg_path,
         remote=args.remote, remote_url=args.remote_url)