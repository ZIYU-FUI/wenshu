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
import subprocess
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "inventory-measure.py"

sys.path.insert(0, str(TOOL.parent))
spec = importlib.util.spec_from_file_location("inventory_measure", TOOL)
assert spec is not None and spec.loader is not None
inv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inv)

TICKET_ID = inv.TICKET_ID
SKIP_RULE = inv.SKIP_RULE


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
# = =
# = = AND IT IS THE REBASE'S STARTING POINT, = = not the branch's old
# = = = = base. = = After a rebase the branch's tip CARRIES `main`'s
# = = = = commits, = = so `git diff <old base> HEAD` also shows what `main`
# = = = = changed in the meantime (= = 79 ticket ids this branch never
# = = = = wrote), = = and the certificate charged the branch for another
# = = = = lane's lines. = = The branch's OWN diff is measured against the
# = = = = commit the branch started from.
BASE_COMMIT = "77635be756560dd670a37f9346701a77d78c20b2"


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
    # = = THE METHOD'S EXEMPLARS ARE READ FROM ITS OWN LISTING GROUPS.
    # = = = =
    # = = The method lists the forms it reaches inside "(= = ...)" groups,
    # = = and a group can SPAN TWO print lines (= = the connector-ticket
    # = = family's example does), = = so the method's text is JOINED first
    # = = and the groups are parsed out of the whole. = = That is also
    # = = what separates an ADVERTISED FORM from a MENTION: = = a mention
    # = = (= = "their own A112/A115 labels", = = "the p90") sits outside
    # = = a group.
    method_lines = [
        line for line in source.split("\n") if line.strip().startswith("print(")
    ]
    # = = the print calls' own text, = = with the regex lines removed (= =
    # = = = a regex's character classes are not ticket forms)
    method_text = "\n".join(
        line
        for line in method_lines
        if "\\\\" not in line and "b(" not in line
    )
    exemplars = set()
    for group in re.findall(r"\(=[^)]*\)", method_text):
        for token in re.findall(r"\b[a-zA-Z][A-Za-z0-9]*(?:-[A-Za-z0-9.]*)*-?", group):
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
            # = = AN EXEMPLAR LOOKS LIKE A TICKET ID, = = NOT LIKE A WORD.
            looks_like_id = "-" in token or bool(re.match(r"^[A-Za-z]{1,3}\d", token))
            if not looks_like_id:
                continue
            # = = THE FORM ITSELF, = = NOT A SUFFIX OF IT. = = `round-x`
            # = = is a lowercase form the matcher cannot reach, = = and it
            # = = must be caught (= = the last round measured a method
            # = = advertising one leaving the suite green).
            if re.match(r"^[A-Za-z][A-Za-z]*-?\d", token) or re.match(
                r"^(?:TICKET-HERMES|GAP|TKT)[-_]", token
            ) or re.match(r"^round-", token):
                exemplars.add(token)
    for token in sorted(exemplars):
        # = = THE SPAN, = = NOT THE PRESENCE. = = `search` is truthy for a
        # = = FRAGMENT (= = `P1` inside `P1-02`), = = so reachability alone
        # = = does not hold the "matched whole" property. = = The matched
        # = = TEXT must equal the exemplar.
        matched = TICKET_ID.search(token)
        if matched is None:
            failures.append(
                f"the printed method names {token!r}, = = so the matcher must reach it"
            )
        elif matched.group(0) != token:
            failures.append(
                f"the printed method names {token!r}, = = and the matcher matches "
                f"{matched.group(0)!r} = = = = the id must be matched WHOLE"
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

    # = = the skip names the CODE carries (= = the table's keys). = = The
    # = = name-level check below reads these, = = because the printed
    # = = method must SAY each skip the code performs. = = But the names
    # = = alone cannot hold the rule (= = see below), = = so this list is
    # = = not the guard: = = = it is the method's own vocabulary.
    code_skips = list(SKIP_RULE.keys())

    # = = THE RULE'S BEHAVIOUR, = = NOT ITS NAMES. = =
    # = =
    # = = The last round measured this failing: = = the guard compared the
    # = = table's KEY NAMES, = = so editing one cell's EXPRESSION (= = the
    # = = cell's value) left the guard green, = = and the published
    # = = census row moved by 917 (= = a 2.1x change in the tree's
    # = = headline number) while the printed method still claimed the
    # = = opposite of what the code did. = =
    # = =
    # = = So the guard calls the tool's OWN predicate (= = `skipped`, = =
    # = = which is compiled from that one table) on three sample lines
    # = = and asserts the OUTCOMES: = = a collapse receipt is skipped,
    # = = a `// /` line is skipped, = = and an ordinary comment carrying
    # = = a ticket id is NOT skipped. = = No edit to the table's
    # = = expressions can defeat that, = = because the predicate IS the
    # = = table. = =
    # = =
    # = = AND THIS IS NOT A COPY OF THE RULE: = = a test that asserted
    # = = the table's VALUES against literals would carry a second copy
    # = = of the rule (= = the defect class this card exists to close).
    # = = These three lines are SAMPLES (= = the shapes the tree really
    # = = has), = = and their EXPECTATIONS are the rule's BEHAVIOUR.
    # = = AND THE RECEIPTS ARE ENUMERATED, = = NOT SAMPLED. = =
    # = =
    # = = The last round measured this failing: = = the guard's receipt
    # = = sample was a line INVENTED by the test (= = it carried both
    # = = A112 and A115), = = and the tree's receipts carry ONE of them
    # = = (= = 627 carry A112, = = 290 carry A115, = = and NONE carries
    # = = = = both). = = So narrowing the rule to A112-only, = =
    # = = A115-only, = = or both-labels kept that invented sample
    # = = skipped, = = the suite stayed GREEN, = = and the published row
    # = = = = moved 833 -> 1123 / 1460 / 1750. = =
    # = =
    # = = So the guard reads the TREE's own receipts (= = every line that
    # = = carries the receipt marker) and asserts the rule skips EVERY one
    # = = of them. = = A narrowing cannot pass that, = = because the tree
    # = = = = holds receipts the narrowing would let through.
    receipt_marker = "rationale lines collapsed"
    tree_receipts = []
    for tree_path in inv.production_files("HEAD"):
        try:
            tree_text = inv.read("HEAD", tree_path)
        except subprocess.CalledProcessError:
            continue
        for tree_line in tree_text.splitlines():
            if receipt_marker in tree_line and inv.is_comment(tree_line):
                tree_receipts.append((tree_path, tree_line))
    if not tree_receipts:
        failures.append(
            "the tree carries no collapse receipt (= = the marker "
            f"{receipt_marker!r} is in no production comment), = = so the guard "
            "has nothing to hold the receipt rule"
        )
    else:
        missed = [
            (path, line)
            for path, line in tree_receipts
            if not inv.skipped(line)
        ]
        if missed:
            path, line = missed[0]
            failures.append(
                f"the skip rule does not skip {len(missed)} of the tree's "
                f"{len(tree_receipts)} collapse receipts (= = {path}: "
                f"{line.strip()[:80]!r}), = = and a receipt the rule lets "
                "through is counted as a ticket reference"
            )

    for sample, expected, what in (
        (
            "    // / a malformed doc comment",
            True,
            "a `// /` line",
        ),
        (
            "    // T4-REF the tree's own reference",
            False,
            "an ordinary comment carrying a ticket id",
        ),
    ):
        actual = inv.skipped(sample)
        if actual is not expected:
            failures.append(
                f"the skip rule does not skip {what} (= = {sample.strip()!r} = = "
                f"skipped() said {actual}, = = and the rule says {expected})"
            )

    # = = AND THE MEASURED ROW MUST CALL THE PREDICATE. = = A table the
    # = = guard reads is not enough: = = the measured row could still run
    # = = its own copy of the rule, = = and the last round measured that
    # = = (the row's number moved while the guard was green). = = So the
    # = = guard also checks that the rule's expressions appear ONLY inside
    # = = the table, = = and that the table has the readers.
    # = = THE TABLE IS THE ONLY COPY OF THE RULE THAT THE TICKET ROW
    # = = READS. = = Measures 1 and 2 legitimately LOOK at those two kinds
    # = = of line (= = they count them), = = so their use of the same
    # = = expressions is not a second copy of the ticket row's rule. = =
    # = = = The defect was a COMBINED condition (= = a skip written as
    # = = = = `RECEIPT.search(line) or line.strip().startswith("// /")`)
    # = = = = inside the ticket row, = = = = which is a copy the table
    # = = = = does not see. = = So the guard looks for the COMBINED form.
    for combined in (
        'RECEIPT.search(line) or line.strip().startswith("// /")',
        'line.strip().startswith("// /") or RECEIPT.search(line)',
    ):
        if combined in source:
            failures.append(
                "the ticket row's skip rule is written out as a combined "
                f"condition (= = {combined!r}), = = and it must read the one table"
            )
    if source.count("skipped(line)") < 3:
        # = = three: = = the predicate's own body, = = the measured row,
        # = = and the per-hit reader
        failures.append(
            "both the measured row and the per-hit reader must call "
            "'skipped(line)', = = so the rule has one reader"
        )

    # = = AND THE MEASURED ROW MUST CALL THE PREDICATE. = = A table the
    # = = guard reads is not enough: = = the measured row could still run
    # = = its own copy of the rule, = = and the last round measured that
    # = = (the row's number moved while the guard was green). = = So the
    # = = guard also checks that BOTH readers call `skipped`, = = and that
    # = = the rule's expressions appear ONLY inside the table.
    if source.count("skipped(line)") < 3:
        # = = three: = = the predicate's own body, = = the measured row,
        # = = and the per-hit reader
        failures.append(
            "both the measured row and the per-hit reader must call "
            "'skipped(line)', = = so the rule has one reader"
        )

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



def check_the_at_base_attribution_is_per_file():
    """The at_base status is the BASE'S debt IN THAT FILE, = = not anywhere.

    = = THE DEFECT THIS GUARDS: = = the tool's own text said the status is
    = = decided on the base's own line text, = = and the code decided it
    = = on a TREE-WIDE token set, = = and the per-line map that would have
    = = implemented the stated rule was computed and thrown away. = = So a
    = = token the base carried in ONE file was published as `at_base` for
    = = a DIFFERENT file the base never touched, = = and the reader was
    = = asked to check a number the rule did not produce.
    = =
    = = So the test builds a REAL repo with a REAL base and a REAL tip:
    = = file A carries the id at the base, = = and the change adds the SAME
    = = id to file B. = = B's hit is the CHANGE'S OWN, = = and the tool
    = = must say so.
    """
    import subprocess
    import tempfile

    with tempfile.TemporaryDirectory() as scratch:
        repo = Path(scratch) / "repo"
        repo.mkdir()
        run_git = lambda *args: subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True,
            text=True,
            check=True,
        )
        run_git("init", "-q")
        run_git("config", "user.email", "t@example.com")
        run_git("config", "user.name", "t")
        sources = repo / "Sources"
        sources.mkdir()
        file_a = sources / "A.swift"
        file_b = sources / "B.swift"
        file_a.write_text("// T4-REF old\n", encoding="utf-8")
        file_b.write_text("// nothing here yet\n", encoding="utf-8")
        run_git("add", ".")
        run_git("commit", "-q", "-m", "base")
        base = run_git("rev-parse", "HEAD").stdout.strip()

        file_b.write_text("// nothing here yet\n// T4-REF new in B\n", encoding="utf-8")
        run_git("add", ".")
        run_git("commit", "-q", "-m", "tip")
        tip = run_git("rev-parse", "HEAD").stdout.strip()

        result = subprocess.run(
            [
                sys.executable,
                str(TOOL),
                "--base",
                base,
                "--tip",
                tip,
            ],
            cwd=str(repo),
            capture_output=True,
            text=True,
        )
        out = result.stdout + result.stderr
        if result.returncode != 0:
            return [f"the tool failed on the synthetic repo: {out.strip()[-300:]}"]
        failures = []
        # = = B's hit must be the CHANGE'S OWN: = = the base never carried
        # = = that id in B, = = so the tree-wide reading would say at_base
        line = next(
            (
                l
                for l in out.split("\n")
                if "B.swift" in l and "T4-REF" in l
            ),
            None,
        )
        if line is None:
            return ["the tool published no hit for the file the change added"]
        if "the change's own" not in line:
            failures.append(
                f"the hit the change added to B.swift is published as {line.strip()!r}, "
                f"= = and the base never carried that id in B, = = so it is the change's own"
            )
        # = = and A's hit IS the base's debt = = (the base carried it there)
        line_a = next(
            (l for l in out.split("\n") if "A.swift" in l and "T4-REF" in l),
            None,
        )
        if line_a is not None and "at_base" not in line_a:
            failures.append(
                f"the hit the base carried in A.swift is published as {line_a.strip()!r}, "
                f"= = and it is the base's debt"
            )
        return failures


def check_the_tip_read_survives_the_tree():
    """The tip's file set is the TIP's own, = = and a deleted file is not fatal.

    = = THREE DEFECTS, = = ONE SHAPE. = = The last round measured them:
    = = = = (1) a file the change DELETED was read at the tip with no
    = = = = guard, = = and the tool DIED; = = (2) a file the change ADDED
    = = = = was never measured, = = because the file list came from the
    = = = = base; = = = = (3) the denominator counted every changed path
    = = = = (= = 13) while the table read only the production `.swift`
    = = = = files among them (= = 8).
    = =
    = = = = So the tool must read the tip's own file set, = = skip a file
    = = = = the tip does not have, = = and print the number of files it
    = = = = actually measured.
    """
    import subprocess
    import tempfile

    with tempfile.TemporaryDirectory() as scratch:
        repo = Path(scratch) / "repo"
        repo.mkdir()
        run_git = lambda *args: subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True,
            text=True,
            check=True,
        )
        run_git("init", "-q")
        run_git("config", "user.email", "t@example.com")
        run_git("config", "user.name", "t")
        sources = repo / "Sources"
        sources.mkdir()
        kept = sources / "Kept.swift"
        removed = sources / "Removed.swift"
        kept.write_text("// T4-KEEP one\n", encoding="utf-8")
        removed.write_text("// T4-GONE one\n", encoding="utf-8")
        run_git("add", ".")
        run_git("commit", "-q", "-m", "base")
        base = run_git("rev-parse", "HEAD").stdout.strip()

        # = = the change DELETES one file and ADDS another = =
        removed.unlink()
        (sources / "Added.swift").write_text("// T4-NEW one\n", encoding="utf-8")
        # = = and it touches a NON-PRODUCTION file, = = so "every changed
        # = = path" (= = 3) and "the production files among them" (= = 2)
        # = = are different numbers: = = the denominator must be the second
        (repo / "README.md").write_text("# a doc the change touched\n", encoding="utf-8")
        run_git("add", "-A")
        run_git("commit", "-q", "-m", "tip")
        tip = run_git("rev-parse", "HEAD").stdout.strip()

        result = subprocess.run(
            [sys.executable, str(TOOL), "--base", base, "--tip", tip],
            cwd=str(repo),
            capture_output=True,
            text=True,
        )
        out = result.stdout + result.stderr
        if result.returncode != 0:
            return [
                "the tool died on a change that deleted a production file: "
                + out.strip()[-300:]
            ]
        failures = []
        # = = the ADDED file's hit must be published = =
        added_line = next(
            (l for l in out.split("\n") if "Added.swift" in l and "T4-NEW" in l),
            None,
        )
        if added_line is None:
            failures.append(
                "the tool measured no hit for the file the change ADDED, = = so a "
                "ticket id introduced in a new file is invisible to the attribution"
            )
        # = = and the DELETED file must not be published = =
        if "Removed.swift" in out and "T4-GONE" in out:
            failures.append(
                "the tool published a hit for the file the change DELETED"
            )
        # = = the denominator must be the number of files READ = =
        denominator = next(
            (l for l in out.split("\n") if "production file(s) this change touched" in l),
            None,
        )
        if denominator is None:
            failures.append("the tool did not print the number of files it measured")
        else:
            # = = ONE production file was READ (= = the added one). = =
            # = =
            # = = The changed production files are TWO (= = the added one
            # = = and the DELETED one), = = and the file the change did
            # = = NOT touch (= = `Kept.swift`) is not among them. = = So the
            # = = denominator must be the number of files the table READ
            # = = (= = one), = = not the number of paths the change moved
            # = = (= = two). = =
            # = =
            # = = The last round measured this failing: = = the
            # = = denominator counted the DELETED file, = = which the table
            # = = skipped because there is nothing at the tip to attribute,
            # = = = = so the published number named a file the number did
            # = = = = not come from.
            if "1 production file(s)" not in denominator:
                failures.append(
                    f"the tool says {denominator.strip()!r}, = = and it read ONE "
                    f"production file (= = the added one), = = because the deleted "
                    f"one is not at the tip to read"
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
    failures.extend(check_the_at_base_attribution_is_per_file())
    failures.extend(check_the_tip_read_survives_the_tree())

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
