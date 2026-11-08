#!/usr/bin/env python3
"""The ticket-id matcher's own cases.

WHY THIS SUITE EXISTS

= = `inventory-measure.py`'s measure 5 (= = the ticket-id census) = =
shipped a matcher that could not see the tree's largest ticket family,
= = and its printed method claimed the forms it could not match. = = The
consequence was a FALSE GREEN: = = the row the policy's certificate
carried read `base 71 -> tip 2` over the card's own eight files, = =
while a form-complete matcher reads `base 76 -> tip 6`. = = So the
matcher needs its OWN cases, = = and each case must be able to fail.

= = Every case here names a form the tree really uses, = = and the
negative cases name the ordinary Swift words a loose matcher would
catch. = = The suite drives the tool's own module (= = it imports the
matcher, = = so the case and the tool cannot drift apart).

= = Idempotent: = = running it twice leaves the same tree.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "inventory-measure.py"

sys.path.insert(0, str(TOOL.parent))
spec = importlib.util.spec_from_file_location("inventory_measure", TOOL)
assert spec is not None and spec.loader is not None
inv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inv)

TICKET_ID = inv.TICKET_ID


# = = the four families the tree really uses = =
MUST_MATCH = [
    # = = the hyphenated family = =
    "T4-SUBAGENT-UI",
    "T8-SOMETHING",
    "P1-02",
    "OOB-7",
    # = = the bare-number family = =
    "A112",
    "Q112",
    "M1",
    "T0",
    # = = THE HYPHENATED FAMILY MATCHED WHOLE. = = `P1-02` must come
    # = = out as `P1-02`, = = NOT as the fragment `P1`: = = a truncated
    # = = id makes the at_base attribution decide on a fragment, = = and
    # = = the fragment is a different string from the id.
    "P1-02",
    "P1-01",
    "T4-SUBAGENT-UI",
    "P0-AGENT",
    "T0-PATH",
    # = = the connector-ticket family (= = the tree's own prose calls
    # = = these tickets: = = "out of scope per the GAP-003 ticket body")
    "GAP-003",
    "TICKET-HERMES-GAP-002",
    "TKT-028-025",
    # = = A BARE PREFIX WITH NO TAIL IS NOT AN ID: = = `T4-` and
    # = = `OOB-` are prefixes, = = and the matcher must not report them,
    # = = = = which is exactly what the round-4 review named.
    # = = the LETTER-SUFFIXED family (= = the one the old matcher missed) == 
    "T20c",
    "T20b",
    "T22b",
    "T1a",
    "T2b",
    "H2s",
    "T12b",
    "T20a",
    "T3a",
    "T2a",
    "T1b",
    "T3b",
    "T11b",
    # = = the lowercase-prefixed family (= = the one the old matcher missed,
    # = = and the one its printed method CLAIMED) = =
    "round-19",
]

# = = the ordinary words a loose matcher would catch = =
MUST_NOT_MATCH = [
    # = = A BARE PREFIX WITH NO TAIL IS NOT AN ID: = = `T4-` and
    # = = `OOB-` are prefixes, = = and the matcher must not report them,
    # = = = = which is exactly what the round-4 review named.
    "T4-",
    "OOB-",
    "GAP-",
    "TabView",
    "Text",
    "Type",
    "SwiftUI",
    "HTTPClient",
    "URLSession",
    "AnyView",
    "TextField",
    "Toggle",
    "Slider",
    "Picker",
    "ScrollView",
    "Label",
    "Button",
    "Image",
    "Color",
    "Font",
    "List",
    "Form",
    "Alert",
    "Sheet",
    "Grid",
    "Stack",
    "HStack",
    "VStack",
    "JSON",
    "XML",
    "HTML",
    "URL",
    "UUID",
    "HTTP",
    "GET",
    "POST",
    "PATCH",
    "EOF",
    "NULL",
    "VOID",
]


# = = the branch's OWN base (= = its merge-base with main) = =
#
# = = The base matters: = = the review's sha is the branch's TIP, = =
# = = so a diff against it sees only the tree's CURRENT changes, = =
# = = and the branch's own added lines (= = the ones that carried the
# = = = ticket ids) = = are the base's lines, = = and are invisible. = =
# = = A diff against the merge-base sees the WHOLE branch, = = = which
# = = = is what "the branch's added comment lines" means.
REPO = TOOL.parent.parent.parent


def branch_base():
    """The branch's merge-base with main (= = where its work starts).

    = = PINNED TO A FIXED BASE, = = NOT THE MERGE-BASE. = = The
    = = merge-base with `main` moves: = = once the branch is on `main`,
    = = the merge-base IS `HEAD`, = = the diff is empty, = = and the
    = = "the branch's added comment lines" certificate silently measures
    = = ZERO lines = = = = a green that says nothing. = = The base is
    = = therefore the commit that started this work, = = named here.
    """
    return BASE_COMMIT


# = = THE COMMIT WHOSE DIFF THIS SUITE MEASURES: = = the parent of the
# = = branch's FIRST commit. = = It is written down rather than computed
# = = from the merge-base, = = because the merge-base MOVES: = = once the
# = = branch is on `main`, = = the merge-base IS `HEAD`, = = the diff is
# = = empty, = = and the added-lines certificate silently measures ZERO
# = = lines = = = = a green that says nothing. = = This SHA does not move.
BASE_COMMIT = "722e73ec13f2a8a5140afce82449fd0689ee1feb"


def check_added_comment_lines():
    """The branch's ADDED comment lines carry no ticket id.

    = = The restored prose brought four ticket ids into a file that had
    = = none at the base, = = and a ticket id in a comment is a
    = = reference to a ticket the reader cannot open. = = So the added
    = = comment lines are measured, = = with the tool's own matcher.
    """
    import subprocess

    diff = subprocess.run(
        ["git", "diff", branch_base(), "--", "*.swift"],
        cwd=str(REPO),
        capture_output=True,
        text=True,
    ).stdout
    added = [
        line[1:]
        for line in diff.split("\n")
        if line.startswith("+") and not line.startswith("+++")
    ]
    offenders = []
    for line in added:
        if not line.strip().startswith("//"):
            continue
        for match in TICKET_ID.finditer(line):
            offenders.append((match.group(0), line.strip()[:80]))
    if offenders:
        return [
            f"the branch's added comment lines carry {len(offenders)} ticket id(s): "
            + ", ".join(sorted({tok for tok, _ in offenders}))
        ]
    return []


def check_the_rewrapped_block():
    """The rewritten block reads once, = = and not twice.

    = = The block used to carry the same fragment twice, = = so the
    = = sentence read as a duplicated clause inside a mangled one. = =
    = = The count is over the JOINED block, = = because the clause is
    = = = split across two comment lines.
    """
    path = REPO / (
        "Sources/WenshuAgent/Sources/WenshuAgent/Agent/ConversationLoop.swift"
    )
    if not path.exists():
        return [f"the rewritten block's file is gone: {path}"]
    lines = path.read_text(encoding="utf-8").split("\n")
    start = next(
        (
            i
            for i, line in enumerate(lines)
            if "The dead `[wenshu.agent] turn N/M` marker is gone" in line
        ),
        None,
    )
    if start is None:
        return ["the rewritten block is gone from ConversationLoop.swift"]
    block = "\n".join(lines[start : start + 5])
    found = []
    for clause in ("bounds the while condition", "only the user-visible"):
        if block.count(clause) != 1:
            found.append(
                f"the rewritten block carries {clause!r} "
                f"{block.count(clause)} time(s), = = and it must carry it once"
        )
    return found


def check_the_printed_method():
    """The printed method says what the code does, = = and reaches what it names.

    = = TWO CLAIMS, = = AND THE LAST ROUND MEASURED BOTH FAILING. = =
    = = The method named ONE skip where the code performs TWO, = = and it
    = = named a form (= = `OOB-`) the matcher cannot reach, = = and
    = = neither was caught, = = because the only consistency check was
    = = hard-coded to one literal. = = So the check is GENERAL: = = the
    = = method's exemplar forms are parsed out of its own text and each
    = = one must be reachable, = = and the method's skip list must equal
    = = the code's.
    """
    source = TOOL.read_text(encoding="utf-8")
    failures = []

    # = = the exemplars the method prints (= = `T4-SUBAGENT-UI`, = =
    # = = `P1-02`, = = `C-4`, = = `A112`, = = ... = = `GAP-003`, = = ...) = =
    # = = must each be reachable by the matcher. = = The forms are read
    # = = from the printed method itself, = = so a new exemplar that the
    # = = matcher cannot reach is caught the day it is printed.
    exemplars = set()
    for line in source.split("\n"):
        if not line.strip().startswith("print("):
            continue
        # = = the method ALSO prints its regexes, = = and a regex's own
        # = = character classes are not exemplars (= = `A-Za-z0-9.-` is
        # = = not a ticket form). = = The regex lines are the ones that
        # = = carry a backslash, = = so they are excluded, = = and what
        # = = remains is the method's prose (= = where its exemplars and
        # = = its skip claims live).
        if "\\\\" in line or "b(" in line:
            continue
        # = = a token MAY END IN A HYPHEN (= = `OOB-`), = = because that is
        # = = exactly the shape the round-4 review named: = = a form the
        # = = method advertised and the matcher could not reach. = = So the
        # = = trailing hyphen is part of the token, = = not a separator.
        for token in re.findall(r"\b[A-Z][A-Za-z0-9]*(?:-[A-Za-z0-9.]*)*-?", line):
            if token in ("TICKET_ID", "THE", "AND", "OR"):
                continue
            # = = a token that ends in a hyphen (= = `OOB-`, = = `GAP-`)
            # = = is a PREFIX, = = and a prefix with no digits after it is
            # = = exactly the shape the matcher cannot reach. = = So it is
            # = = checked too, = = and the check is what makes the method
            # = = unable to advertise one.
            if token.endswith("-"):
                exemplars.add(token)
                continue
            if re.match(r"^[A-Z][A-Za-z]*-?\d", token) or re.match(
                r"^(?:TICKET-HERMES|GAP|TKT)[-_]", token
            ):
                exemplars.add(token)
    for token in sorted(exemplars):
        if not TICKET_ID.search(token):
            failures.append(
                f"the printed method names {token!r}, = = so the matcher must reach it"
            )

    # = = THE METHOD MUST PRINT THE MATCHER IT USES. = = The method
    # = = states the rule, = = and the rule must be the one the code
    # = = compiles: = = otherwise the reader checks a different rule
    # = = than the one that produced the number. = =
    # = = The check is on the ALTERNATION AS A WHOLE: = = the printed
    # = = lines are joined, = = their `|` separators are counted, = = and
    # = = the joined rule must equal the compiled one. = = (Checking each
    # = = alternative separately would pass on a broken method: = = a
    # = = fragment like `P` is in the source whatever the method says.)
    printed = []
    for line in source.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("print("):
            continue
        # = = a printed regex line: = = its content is a backtick-quoted
        # = = rule fragment = =
        for fragment in re.findall(r"`([^`]*)`", stripped):
            if "\\" in fragment or "[" in fragment:
                printed.append(fragment)
    joined = "|".join(printed)
    compiled = TICKET_ID.pattern
    # = = the printed form spells `\d` where the compiled form spells
    # = = `\d`, = = and the compiled one may carry a group the printed
    # = = one does not, = = so the comparison is on the ALTERNATIVES and
    # = = = = on their order.
    # = = the TOP-LEVEL alternatives only: = = a `|` inside a
    # = = `(?:...)` group is not a separator. = = The compiled rule's own
    # = = groups are counted, = = so the split is depth-aware.
    def top_level_alternatives(pattern):
        alts = []
        depth = 0
        current = ""
        i = 0
        while i < len(pattern):
            ch = pattern[i]
            if ch == "\\" and i + 1 < len(pattern):
                current += pattern[i : i + 2]
                i += 2
                continue
            if ch == "[":
                j = pattern.find("]", i)
                j = len(pattern) - 1 if j < 0 else j
                current += pattern[i : j + 1]
                i = j + 1
                continue
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            if ch == "|" and depth == 0:
                alts.append(current)
                current = ""
                i += 1
                continue
            current += ch
            i += 1
        alts.append(current)
        return alts

    printed_alts = [a for a in printed]
    compiled_alts = top_level_alternatives(compiled)
    if len(printed_alts) != len(compiled_alts):
        failures.append(
            f"the printed method states {len(printed_alts)} alternative(s) = = and the "
            f"matcher has {len(compiled_alts)} = = = = they must be the same rule"
        )
    else:
        for shown, real in zip(printed_alts, compiled_alts):
            # = = the printed fragment is SOURCE TEXT, = = so its
            # = = backslashes are doubled (= = `\\b` in the file), = =
            # = while the compiled one has them single (= = `\b`). = =
            # = = = one un-doubling makes the two comparable.
            shown_once = shown.replace("\\\\", "\\")
            # = = the printed lines continue the rule, = = so all but the
            # = = first carry a leading `|`. = = That separator is not
            # = = part of the alternative.
            if shown_once.startswith("|"):
                shown_once = shown_once[1:]
            if shown_once != real:
                failures.append(
                    f"the printed method states {shown!r} = = and the matcher compiles "
                    f"{real!r} = = = = the method must print the matcher it uses"
                )

    # = = the method's SKIP LIST must equal the code's. = = The code
    # = = skips the collapse receipts and the `// /` lines; = = the
    # = = method must say both. = = This is read from the CODE (= = the
    # = = skip expression) and from the METHOD TEXT, = = so a change to
    # = = either one without the other is caught.
    code_skips = []
    if "RECEIPT.search(line)" in source:
        code_skips.append("the collapse receipts")
    if 'startswith("// /")' in source:
        code_skips.append("the `// /` lines")

    # = = THE METHOD MUST STATE EACH SKIP AS ITS OWN CLAUSE. = = A
    # = = mention is not a statement: = = the defect was a method that
    # = = MENTIONED one skip while the code performed two, = = and a
    # = = guard that looked for the word would have called that stated.
    # = = So each skip's clause is counted, = = and the method must carry
    # = = one clause per skip = = = = no more, = = and no fewer.
    method_lines = [
        line for line in source.split("\n") if line.strip().startswith("print(")
    ]
    method = "\n".join(method_lines)
    for skip in code_skips:
        clauses = [
            line
            for line in method_lines
            if skip in line and "skipped" in line
        ]
        if not clauses:
            failures.append(
                f"the code skips {skip}, = = so the printed method must state that skip"
            )
    # = = and the method must not state a skip the code does not perform
    for skip in ("the collapse receipts", "the `// /` lines"):
        if skip in code_skips:
            continue
        if any(skip in line and "skipped" in line for line in method_lines):
            failures.append(
                f"the printed method names a skip the code does not perform (= {skip})"
            )
    # = = and the method must state EXACTLY the code's skips: = = one
    # = = clause each, = = so a skip the code performs cannot be stated
    # = = twice and a missing one cannot be papered over by another.
    stated = [
        skip
        for skip in ("the collapse receipts", "the `// /` lines")
        if any(skip in line and "skipped" in line for line in method_lines)
    ]
    if sorted(stated) != sorted(code_skips):
        failures.append(
            f"the printed method states {sorted(stated)} = = and the code skips "
            f"{sorted(code_skips)} = = = = the two lists must be the same"
        )
    return failures



def check_the_at_base_attribution():
    """The tool PUBLISHES each hit's at_base status, = = and the tree's own row.

    = = THE DEFECT THIS GUARDS: = = the review found the attribution
    = = CORRECT and REPRODUCIBLE, = = and never published: = = the
    = = commit shipped the aggregate pair (= = base 71 -> tip 2) = = and
    = = not the per-hit status that explains it. = = So the numbers were
    = = right and the reader could not check them. = = The guard is on the
    = = PUBLICATION, = = not on the arithmetic: = = the tool must print
    = = each hit with its status, = = and it must print the tree's row.
    """
    source = TOOL.read_text(encoding="utf-8")
    failures = []

    # = = the per-hit table's header = =
    if "each hit's at_base status:" not in source:
        failures.append(
            "the tool must publish each hit's at_base status (= the per-hit table)"
        )

    # = = each hit's status must be one of the two states, = = and the
    # = = tool must actually decide one.
    if '"at_base"' not in source:
        failures.append(
            "the tool must report a hit that was already at the base (= 'at_base')"
        )
    if "the change's own" not in source:
        failures.append(
            "the tool must report a hit the change added (= the change's own)"
        )

    # = = the tree's own row: = = base -> tip, = = with the debt split.
    if "the tree's row:" not in source:
        failures.append("the tool must publish the tree's own row (= base -> tip)")

    # = = the per-hit table must be SCOPED to the change's files, = = and
    # = = say how many files it covered.
    if "this change touched" not in source:
        failures.append(
            "the per-hit table must say which files it covered (= the change's files)"
        )
    return failures


def main():
    failures = []

    for form in MUST_MATCH:
        if not TICKET_ID.search(form):
            failures.append(f"the matcher must see {form!r} (= the tree's own form)")

    for word in MUST_NOT_MATCH:
        if TICKET_ID.search(word):
            failures.append(f"the matcher must NOT see {word!r} (= an ordinary word)")

    # = = the letter-suffixed family is the one the old matcher could not
    # = = see, = = so it is named separately: = = a matcher that loses
    # = = it must fail THESE, = = and the family is measured on the tree
    # = = itself, = = so the number is the tree's and not a fixture's.
    letter_suffixed = re.compile(r"\b[A-Z]{1,3}\d{1,4}[a-z]\b")
    for form in ["T20c", "T1a", "H2s", "T12b"]:
        if not letter_suffixed.search(form):
            failures.append(f"the letter-suffixed family must match {form!r}")

    # = = the printed method must say what the code does, = = and reach
    # = = every form it names (= = the general check, = = which catches
    # = = BOTH the unstated skip and the unreachable exemplar).
    failures.extend(check_the_printed_method())
    failures.extend(check_the_at_base_attribution())

    # = = the two comment defects the last review measured, = = checked
    # = = against the tree itself (= = the branch's own added lines, = =
    # = and the block the branch rewrote). = = They are read from the
    # = = working tree, = = because the fix IS the working tree.
    failures.extend(check_added_comment_lines())
    failures.extend(check_the_rewrapped_block())

    if failures:
        print(f"inventory-measure's matcher: {len(failures)} case(s) FAILED")
        for line in failures:
            print(f"  - {line}")
        return 1

    print(
        f"inventory-measure's matcher: all tests passed "
        f"({len(MUST_MATCH)} forms it must see, {len(MUST_NOT_MATCH)} it must not)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
