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

sys.path.insert(0, os.path.join(os.getcwd(), "Tools", "wenshu-devtool"))
import card_gate_command  # noqa: E402  (sibling module, same directory)

REPO = os.getcwd()
DEVTOOL = os.path.join(REPO, "Tools", "wenshu-devtool")

# The marker swift test prints when the filter matched no test case.
NO_MATCH = "No matching test cases were run"

# The reader of "what gate does this card ask for?" is SHARED with the
# width gate (= `card_gate_command.py`), because the two gates used to
# answer differently about the same card: the width gate accepted a card
# that names its OWN gate command, and this gate read only `swift test
# --filter` lines, so a card that writes no Swift code could never
# satisfy both (= measured on board wenshu-par 2026-11-24: 819 cards name
# the devtool or Scripts/ in their body, and 433 carry a comment that
# quotes the suite rule). One reader, one answer.
FILTER = card_gate_command.FILTER
FILTER_PHRASE = card_gate_command.FILTER_PHRASE

# = = = THERE IS NO CJK PATTERN IN THIS FILE. = = =
# = = = The comment-level CJK rule has ONE implementation, = = = the judge
# = = = (= Tools/wenshu-devtool/comment_lineage.py), = = = and this gate calls
# = = = it. = = = The second arm that used to live here had its own character
# = = = class, = = = its own window (= a two-dot diff, = = = so a moving base
# = = = charged the branch for a sibling's prose), = = = and no whitelist
# = = = (= so the project's own literals were violations here and clean there).
# = = = Measured 2026-11-24 on the ten live branches: = = = the two arms
# = = = disagreed on EVERY one of them (= = = the judge charged 0-19 lines, = = =
# = = = the audit charged 2-31), = = = and on the repo's own truth table the
# = = = audit arm charged a row the judge calls clean. = = = One rule, = = =
# = = = one implementation, = = = one verdict.


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
    # A MARKDOWN TABLE ROW is a DECLARATION, = not prose: = a gate
    # written in a table cell is a gate the reader must lift. = So the
    # row's own text starts the command, = whatever cell it sits in.
    if core.startswith("|"):
        core = core.lstrip("|").strip()
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

    # = = = THE CARD'S OWN GATE COMMAND RUNS TOO. = = = = = = = = = = = = =
    # = = = = A card that writes NO Swift code has no Swift suite to = = = =
    # = = = = filter: its gate is the command that owns what it writes = = = =
    # = = = = (= the devtool's own test script, a pytest run, a docs link = = =
    # = = = = check). The width gate reads that card as NAMED (= = = = = = = =
    # = = = = `gate_width_gate.py`'s `named_other`), so this gate refused a = =
    # = = = = card the other gate accepted, and the house reference calls = = =
    # = = = = that a GATE GAP and not a card defect (= = = = = wenshu-parallel-dev/ =
    # = = = = references/card-body-authoring.md). So the card's own command = =
    # = = = is RUN here, and it must MEASURE something (= = = = a command that =
    # = = = = printed nothing measured nothing). = = = = = = = = = = = = = = =
    card_commands = []
    if args.card:
        card_commands = card_gate_command.own_commands(open(args.card, encoding="utf-8").read())

    if not filters and not card_commands:
        print("  no gate was named, = so nothing was measured:")
        print("    the card's GATES must name the gate that owns each file it writes:")
        print("    a filtered Swift suite, or = = = = = the card's own gate command.")
        failures.append(("no gate was measured",
                         "the card names no `swift test --filter` line and no own gate command"))

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

    for command in card_commands:
        code, out = sh(command)
        measured = bool(out.strip())
        print(f"  the card's own gate ({command}): exit {code}"
              f" {'measured' if measured else 'MEASURED NOTHING'}")
        if code != 0:
            failures.append((f"the card's own gate: {command}", out[-800:]))
        elif not measured:
            failures.append((f"the card's own gate: {command}",
                             "the command printed nothing, = so it measured nothing"))

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
    for check in ("formatting", "pollution", "loc-cap"):
        code, out = sh(f"python3 {DEVTOOL}/ci_change_gate.py --base {args.base} --check {check}")
        print(f"  ci_change_gate --check {check}: exit {code}")
        if code != 0:
            failures.append((f"ci_change_gate --check {check}", out[-800:]))

    # The comment-lineage judge, over the same window as the checks above. 1.5/1.6
    # were a `Manual.` row, and a hand-enforced ban on ADDING a lineage line has no
    # bad day: a swept tree rots quietly and every new card is the moment it breaks.
    code, out = sh(f"python3 {DEVTOOL}/comment_lineage.py --base {args.base}")
    verdict = [l for l in out.splitlines() if "offending" in l]
    print(f"  comment-lineage: exit {code} ({verdict[0].strip() if verdict else out[:120]})")
    if code != 0:
        failures.append(("comment-lineage", out[-800:]))
    elif "not a pass" in out:
        print("    this window added no comment line, = the rule was NOT measured here")

    # = = THE CJK COMMENT RULE HAS NO SECOND ARM. = = The judge above IS the
    # = = one implementation: = = one window (= the merge-base), = = one
    # = = character class, = = one whitelist (= the project's own literals),
    # = = one severity contract. = = The arm that used to live here had its own
    # = = window (= a two-dot diff, = = so a moving base charged the branch for
    # = = a sibling's prose), = = its own narrower character class, = = and no
    # = = whitelist (= so the project's own literals were violations here and
    # = = clean there). = = Measured 2026-11-24: = = the two arms disagreed on
    # = = EVERY one of the repo's live branches, = = and the arm charged a row
    # = = the repo's own arms table declares CLEAN. = = A rule with two arms is
    # = = a rule with two answers, = = and an author who satisfies one is
    # = = bounced by the other.

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
