#!/usr/bin/env python3
"""
pre_review_gate.py · Wenshu (文枢)

The gate that runs BEFORE a branch goes back to the review lane.

WHY THIS EXISTS

Six review rounds on one branch found, in order: = a tree that did not
compile, = a formatting gate that exited 1, = a registry row carrying
another file's count, = a heading face that never reached the editor, =
an assertion written about a range the author had never looked at, =
and a card whose GATES did not run the engine's own suite. = Every one
of those was a claim made from REASONING and not from a measurement.

So the rule this tool enforces is simple: = a branch goes back to
review only when every gate has been MEASURED ON THE EXACT TREE THAT
WILL BE REVIEWED, = and the tool says so in its output.

THE FOUR RULES IT ENFORCES

1. = THE TREE MUST BE COMMITTED. = A gate reads HEAD, = so a gate run
   against a dirty worktree measures the wrong tree, = and the amend
   that follows it moves HEAD again. = So the tool refuses a dirty
   tree BEFORE it measures anything.

2. = THE BUILD MUST BUILD THE TESTS. = `swift build` does not build
   the test target, = so a green build says nothing about a broken
   test file. = `swift build --build-tests` is the check that covers
   it.

3. = EVERY GATE THE CARD NAMES MUST RUN, = AND EVERY GATE IT RUNS
   MUST HAVE MEASURED SOMETHING. = A `swift test --filter` that matches
   no test case exits 0, = prints no summary, = and prints "No matching
   test cases were run". = A tool that reads only the exit code calls
   that a PASS, = so a card whose suite was renamed measures NOTHING and
   still looks measured. = The repository's own CI already refuses that
   reading (= .github/workflows/ci.yml: = a log with no "Test run with"
   summary is a failure), = and this gate holds the same rule. = And a
   card that names NO suite at all measures nothing either, = so an
   empty filter list is a failure too.

4. = EVERY TREE THE CHANGE TOUCHES MUST HAVE ITS OWN SUITE. = The
   vendored engine has its own suite, = and a change that touches the
   vendored tree runs it.

USAGE

    python3 Tools/wenshu-devtool/pre_review_gate.py --base <sha> \\
        --filter '<the card's own suite>' [--filter '<another>'] \\
        [--card <the card body file>]

EXIT

    0 = every gate measured and green
    1 = a gate failed, = or the tree is dirty, = or a gate could not run
"""

import argparse
import os
import re
import subprocess
import sys

REPO = os.getcwd()
DEVTOOL = os.path.join(REPO, "Tools", "wenshu-devtool")

# The marker swift test prints when the filter matched no test case.
NO_MATCH = "No matching test cases were run"

# A filter the card writes. = Both quote styles are accepted: = a card
# written with double quotes names the same suite as one written with
# single quotes, = and a reader that takes only one of them turns the
# card's own gate into a filter that ran nothing.
FILTER = re.compile(r"swift test --filter\s+(['\"])(.+?)\1")

# The phrase that says the card names a filter at all.
FILTER_PHRASE = "swift test --filter"
CJK = re.compile(r"[一-鿿]")


def sh(command, cwd=REPO, timeout=3600):
    """Run a command, = and return (exit code, output)."""
    try:
        done = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, f"TIMEOUT: {command}"
    return done.returncode, (done.stdout + done.stderr)


def measure_tests(output):
    """What a test run actually measured, = read from its OWN summaries.

    Swift Testing reports `Test run with N tests in M suites`; = the
    XCTest bundles report `Executed N tests, with M failures`; = and a
    filter that matched nothing reports NEITHER, = plus the no-match
    warning.

    Returns (tests_measured, matched_nothing). = `tests_measured` is the
    LARGEST count either framework reported, = because the two frameworks
    report different suites and adding them would count one test twice.
    """
    swift_testing = [int(n) for n in re.findall(r"Test run with (\d+) tests?", output)]
    xctest = [int(n) for n in re.findall(r"Executed (\d+) tests?", output)]
    measured = max(swift_testing + xctest) if (swift_testing or xctest) else 0
    return measured, NO_MATCH in output


def gate_scope(text):
    """The card's GATES section, = or the whole body when it has none.

    = A card's GATES section is where its gate lines live, = so the
    reader reads that section, = and NOT the prose around it: = a WHY
    sentence that merely MENTIONS `swift test --filter` is a sentence
    about the gate, = not a gate, = and reading it as one made the
    reader report a card as broken for its own explanation.
    """
    match = re.search(r"^##\s+GATES\b", text, re.MULTILINE | re.IGNORECASE)
    if not match:
        return text
    rest = text[match.end():]
    following = re.search(r"^##\s+", rest, re.MULTILINE)
    return rest[:following.start()] if following else rest


def is_gate_line(line):
    """Does the line READ as a command to run?

    = The phrase alone does not make a line a gate: = a sentence that
    mentions it (= "the reader read only the EXIT CODE of each
    `swift test --filter`") = is prose. = A gate line is one whose
    text starts with the command, = or carries it after a shell
    connective (= `cd <wt> && swift test --filter ...`).
    """
    core = line.strip()
    core = re.sub(r"^[-*+]\s+", "", core)
    core = re.sub(r"^\d+\.\s+", "", core)
    core = core.strip()
    while core.startswith("`"):
        core = core[1:].strip()
    core = re.sub(r"^\$\s*", "", core)
    index = core.find(FILTER_PHRASE)
    if index == -1:
        return False
    before = core[:index].rstrip()
    if before == "":
        return True
    return before.endswith(("&&", ";", "|", "||", "(", "{"))


def filters_from_card(text):
    """The card's own narrow suites, = and the gate lines it cannot read.

    Returns (filters, unparsed_lines). = `unparsed_lines` names the
    card's GATE lines the reader could not parse, = because a card
    whose gate line cannot be read measures nothing, = and the reader
    must say so rather than measure a smaller set than the card asks
    for.

    = Only the card's GATES section is read, = and only the lines in it
    that read as commands (= a prose mention is not a gate), = so a
    card is never failed for its own explanation, = and never measured
    against a suite its prose quoted.
    """
    scope = gate_scope(text)
    filters = []
    unparsed = []
    for line in scope.split("\n"):
        if FILTER_PHRASE not in line:
            continue
        if not is_gate_line(line):
            continue
        found = FILTER.findall(line)
        if found:
            filters.extend(match[1] for match in found)
        else:
            unparsed.append(line.strip())
    return filters, unparsed


def blank_strings(line, in_multiline=False):
    """The line with its string literals blanked, = so a `//` inside a
    string is not read as a comment. = A string that is never closed on
    the line runs to the end of it, = which is how Swift reads it too.

    = A MULTILINE literal (= three double quotes) = is blanked as one:
    = the scanner toggles on the quote one at a time, = so the triple
    leaves its state wrong (= and a `//` after it would be read as a
    comment). = So the triple is matched as a unit.

    = Returns (blanked, in_multiline): = the state says whether a
    multiline literal is OPEN at the end of the line, = because such a
    literal SPANS lines (= and the line after it is still inside the
    literal, = so a `//` there is not a comment either).
    """
    out = []
    in_string = False
    escaped = False
    index = 0
    while index < len(line):
        char = line[index]
        if in_multiline:
            if line.startswith('"""', index):
                out.append(" ")
                out.append(" ")
                out.append(" ")
                in_multiline = False
                index += 3
                continue
            out.append(" ")
            index += 1
            continue
        if escaped:
            out.append(" ")
            escaped = False
            index += 1
            continue
        if char == "\\" and in_string:
            out.append(" ")
            escaped = True
            index += 1
            continue
        if line.startswith('"""', index):
            out.append(" ")
            out.append(" ")
            out.append(" ")
            in_multiline = True
            index += 3
            continue
        if char == '"':
            in_string = not in_string
            out.append(" ")
            index += 1
            continue
        out.append(" " if in_string else char)
        index += 1
    return "".join(out), in_multiline


def comment_parts(added_lines):
    """The COMMENT part of every added line that carries one.

    = The CJK audit greps the COMMENT PART, = not the whole raw line: =
    a line whose CJK sits inside a string literal AND which carries a
    trailing comment (= the repository's own idiom, = e.g. a model's
    `displayName` with a note beside it) = would otherwise be reported
    as CJK-in-a-comment, = and the literal does not stay.

    = The string literals are blanked first, = so a `//` inside a
    literal is not read as a comment's start, = and the comment's own
    text is what comes back. = The multiline state is carried across the
    lines, = because a multiline literal spans them.

    Returns a list of (line, comment_part) pairs.
    """
    parts = []
    in_block = False
    in_multiline = False
    for raw in added_lines:
        scrubbed, in_multiline = blank_strings(raw, in_multiline)
        is_comment = in_block
        index = 0
        while index < len(scrubbed):
            if in_block:
                end = scrubbed.find("*/", index)
                if end == -1:
                    is_comment = True
                    index = len(scrubbed)
                    break
                in_block = False
                index = end + 2
                continue
            block = scrubbed.find("/*", index)
            line_marker = scrubbed.find("//", index)
            if line_marker != -1 and (block == -1 or line_marker < block):
                is_comment = True
                index = len(scrubbed)
                break
            if block != -1:
                in_block = True
                is_comment = True
                index = block + 2
                continue
            break
        if in_block:
            is_comment = True
        if not is_comment:
            continue
        marker = scrubbed.find("//")
        if marker != -1:
            parts.append((raw, raw[marker:]))
            continue
        block = scrubbed.find("/*")
        if block != -1:
            parts.append((raw, raw[block:]))
            continue
        parts.append((raw, raw))
    return parts


def comment_lines(added_lines):
    """The added lines that are COMMENT lines, = and only those.

    A comment line is one whose text is a comment: = a whole-line `//`,
    = a trailing `//` after code (= the style the repository uses in 543
    lines across 184 files), = or a line inside a `/* */` block. = A `//`
    inside a string literal is NOT a comment, = so the scanner blanks the
    string literals before it looks for the marker.
    """
    comments = []
    in_block = False
    in_multiline = False
    for raw in added_lines:
        scrubbed, in_multiline = blank_strings(raw, in_multiline)
        is_comment = in_block
        index = 0
        while index < len(scrubbed):
            if in_block:
                end = scrubbed.find("*/", index)
                if end == -1:
                    is_comment = True
                    index = len(scrubbed)
                    break
                in_block = False
                index = end + 2
                continue
            block = scrubbed.find("/*", index)
            line_marker = scrubbed.find("//", index)
            if line_marker != -1 and (block == -1 or line_marker < block):
                is_comment = True
                break
            if block != -1:
                in_block = True
                is_comment = True
                index = block + 2
                continue
            break
        if in_block:
            is_comment = True
        if is_comment:
            comments.append(raw)
    return comments


def cjk_audit(base):
    """§7.5: zero new CJK in the COMMENTS this change adds."""
    diff = sh(f"git diff {base} HEAD -- '*.swift'")[1]
    added = [line[1:] for line in diff.split("\n") if line.startswith("+") and not line.startswith("+++")]
    comments = [line for line, part in comment_parts(added) if CJK.search(part)]
    if comments:
        return 1, "CJK comment lines added:\n" + "\n".join("  " + line[:110] for line in comments)
    return 0, f"no new CJK comment line ({len(added)} added line(s) scanned)"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--filter", action="append", default=[])
    parser.add_argument("--card", default=None)
    args = parser.parse_args()

    failures = []

    # RULE 1: the tree must be committed.
    dirty = sh("git status --porcelain")[1].strip()
    if dirty:
        print("pre_review_gate: FAILED")
        print("  the worktree is dirty, = so a gate would measure the WRONG tree:")
        for line in dirty.split("\n")[:10]:
            print("    " + line)
        print("  commit first, = then measure.")
        return 1

    print(f"pre_review_gate: the tree is clean at {sh('git rev-parse --short HEAD')[1].strip()}")

    # RULE 2: the build must build the tests.
    code, out = sh("swift build --build-tests")
    print(f"  build --build-tests: exit {code}")
    if code != 0:
        failures.append(("swift build --build-tests", out[-800:]))

    # RULE 3: the card's own narrow suites, = and the ones named on the
    # command line. = A filter the card names but this reader cannot parse
    # is named, = because the card asked for a gate that did not run.
    card_filters = []
    if args.card:
        text = open(args.card, encoding="utf-8").read()
        card_filters, unparsed = filters_from_card(text)
        for line in unparsed:
            failures.append((f"the card's unreadable filter line: {line}", ""))

    filters = list(dict.fromkeys(args.filter + card_filters))
    if not filters:
        print("  no suite was named, = so no suite was measured:")
        print("    the card's GATES must name the suite that owns each file it writes.")
        failures.append(("no suite was measured", "the card names no `swift test --filter` line"))

    for name in filters:
        code, out = sh(f"swift test --filter '{name}'")
        measured, matched_nothing = measure_tests(out)
        summary = [line for line in out.split("\n") if "Test run with" in line or "Executed" in line]
        print(f"  swift test --filter '{name}': exit {code} {summary[-1].strip() if summary else ''}")
        if code != 0:
            failures.append((f"swift test --filter '{name}'", out[-800:]))
        elif matched_nothing:
            print(f"    the filter matched no test case (= {NO_MATCH}), = so it measured NOTHING")
            failures.append((f"swift test --filter '{name}'", "the filter matched no test case"))
        elif measured == 0:
            print("    the run reported no test, = so it measured NOTHING")
            failures.append((f"swift test --filter '{name}'", "the run reported no test"))

    # RULE 4: the vendored engine has its own suite, = and a change that
    # touches the vendored tree runs it.
    vendored = sh("git diff --name-only %s HEAD -- 'Vendor/MarkdownEngine/*'" % args.base)[1].split()
    if vendored:
        code, out = sh("swift test", cwd=os.path.join(REPO, "Vendor", "MarkdownEngine"))
        summary = [line for line in out.split("\n") if "Test run with" in line]
        print(f"  the vendored engine's own suite: exit {code} {summary[-1].strip() if summary else ''}")
        if code != 0:
            failures.append(("the vendored engine's suite", out[-800:]))
        elif measure_tests(out)[0] == 0:
            print("    the engine's suite reported no test, = so it measured NOTHING")
            failures.append(("the vendored engine's suite", "the run reported no test"))

    # The house's own gates.
    for check in ("formatting", "pollution"):
        code, out = sh(f"python3 {DEVTOOL}/ci_change_gate.py --base {args.base} --check {check}")
        print(f"  ci_change_gate --check {check}: exit {code}")
        if code != 0:
            failures.append((f"ci_change_gate --check {check}", out[-800:]))

    code, out = cjk_audit(args.base)
    print(f"  the CJK audit: exit {code} ({out.splitlines()[0] if out else ''})")
    if code != 0:
        failures.append(("the CJK audit", out))

    code, out = sh(f"python3 {DEVTOOL}/verify-dead.py")
    dead = [line for line in out.split("\n") if "DEAD" in line]
    print(f"  verify-dead: exit {code} {dead[-1].strip() if dead else ''}")
    if code != 0:
        failures.append(("verify-dead", out[-800:]))

    code, out = sh(f"python3 {os.path.join(REPO, 'Scripts', 'merge-nfi-registry.py')} {args.base} docs/agents/nfi.md docs/agents/nfi.md")
    print(f"  the registry's round-trip: exit {code}")
    if code != 0:
        failures.append(("the registry's round-trip", out[-800:]))

    if failures:
        print("pre_review_gate: FAILED")
        for name, detail in failures:
            print(f"  --- {name}")
            for line in detail.split("\n")[-12:]:
                print("    " + line)
        return 1

    print("pre_review_gate: every gate was measured on this tree and is green")
    return 0


if __name__ == "__main__":
    sys.exit(main())
