#!/usr/bin/env python3
"""The chord-glyph rule's own suite.

It proves three things, each by measurement rather than by assertion:

  1. the rule REFUSES a message that names a chord the tree does not bind,
     and it names the LINE;
  2. the rule PASSES a message that agrees with the tree;
  3. the rule's own arms are each green (= = the refusal does NOT happen)
     when the arm is present, while the baseline (= = the same message
     without the arm) IS refused.

The tree the rule judges is the tree it runs in (= = the tree the commit
ships), so every case builds its own throwaway tree = = a copy of the roster
file with a known table = = and the rule is handed that tree.
"""
import importlib.util
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL_DIR = os.path.dirname(HERE)
FILTER = os.path.join(TOOL_DIR, "commit_filter.py")
ROSTER_REL = "Sources/WenshuApp/Features/Chat/View/ChatView+KeyboardShortcuts.swift"

# The table every case is judged against = = the tree's OWN cheat-sheet row,
# in the tree's own order (= the chord, then the action it names).
ROSTER_TABLE = (
    "⌘K focus input · ⌘L clear chat · ⌘N new chat · ⌘P print · ⌘R reload · "
    "⌘. cancel streaming · ⌘⇧C copy conversation · ⌘⇧D copy last assistant · "
    "⌘⇧E edit last user · ⌘⇧F code block · ⌘⇧G regenerate · "
    "⌘⇧K clear chat (in place) · ⌘⇧O open chat markdown · ⌘⇧S export markdown · "
    "⌥T toggle theme"
)

FALSE_MSG = (
    "fix(chat): the code block's chord is ⌘K\n\n"
    "The code block control binds ⌘K now, and the roster still names the code\n"
    "block for it.\n"
)
TRUE_MSG = (
    "fix(chat): the code block's chord is ⌘⇧F\n\n"
    "The code block control binds ⌘⇧F (command-shift-f).\n"
)


def load_filter():
    spec = importlib.util.spec_from_file_location("commit_filter_under_test", FILTER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def make_tree(table=ROSTER_TABLE):
    """A throwaway tree carrying the roster line the rule reads."""
    root = tempfile.mkdtemp(prefix="chordrule-")
    path = os.path.join(root, ROSTER_REL)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write('            wenshuLogger.info("[wenshu.shortcuts] ' + table + '")\n')
    return root


def run(mod, text, tree):
    mod.CHORD_ROSTER_CACHE.clear()
    return list(mod.chord_rule(text, repo=tree))


def case(name, ok, detail=""):
    print(("ok: " if ok else "FAIL: ") + name + ((" | " + detail) if detail else ""))
    return ok


def main():
    mod = load_filter()
    results = []
    tree = make_tree()

    # ---- 1. the rule refuses a message the tree contradicts ----
    errs = run(mod, FALSE_MSG, tree)
    lines = sorted({int(e.split("commit message:")[1].split()[0]) for e in errs})
    results.append(case("a message that names a chord the tree does not bind is refused",
                         len(errs) == 2, f"lines {lines}"))
    results.append(case("every refusal names a line that carries the false chord",
                         lines == [1, 3], f"lines {lines}"))
    results.append(case("the refusal names the chord the tree binds and where it read it",
                         all("⌘⇧F" in e and ROSTER_REL in e for e in errs),
                         errs[0][:120] if errs else ""))

    # ---- 2. the rule passes a message the tree agrees with ----
    errs = run(mod, TRUE_MSG, tree)
    results.append(case("a message that agrees with the tree passes", not errs, str(errs)[:120]))

    # ---- 3. a sentence naming two actions passes when both chords are right ----
    two = ("fix(chat): chords\n\n"
           "The code block control binds ⌘⇧F, and the clear chat control keeps ⌘⇧K.\n")
    errs = run(mod, two, tree)
    results.append(case("a sentence naming two actions passes when both chords are right",
                         not errs, str(errs)[:120]))

    # ---- 4. a modifier glyph followed by prose punctuation is not a chord ----
    punct = ("fix(chat): the roster\n\n"
             "Every chord mention in this message carries ⇧, and the table agrees.\n")
    errs = run(mod, punct, tree)
    results.append(case("a modifier glyph followed by a comma is not a chord mention",
                         not errs, str(errs)[:120]))

    # ---- 5. a LIST of chords reads each item as its own ----
    listing = ("fix(chat): the roster\n\n"
               "The tree's own words = ⌘K focus input, ⌘⇧K clear chat (in place), ⌘⇧F code\n"
               "block.\n")
    errs = run(mod, listing, tree)
    results.append(case("a list of chords is read item by item (= = no item borrows the previous one's phrase)",
                         not errs, str(errs)[:120]))

    # = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    # THE ARMS: each arm removes the thing that makes the refusal happen, so
    # with the arm the refusal must NOT happen (= = green), and without it the
    # baseline IS refused (= = red).
    # = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    # ARM A: the tree publishes no table (= = nothing to judge against).
    arm_a_tree = make_tree(table="")
    arm_a = run(mod, FALSE_MSG, arm_a_tree)
    results.append(case("ARM A (no roster table) => the refusal does not happen",
                         len(arm_a) == 0, f"{len(arm_a)} refusals"))
    shutil.rmtree(arm_a_tree, ignore_errors=True)

    # ARM B: the action phrase is SPLIT across the wrap (= = the rule cannot
    #   see the phrase, so it judges nobody with it).
    arm_b_msg = ("fix(chat): the chord\n\n"
                 "The control binds ⌘K, and the roster names the code\n"
                 "block for it.\n")
    arm_b = run(mod, arm_b_msg, tree)
    results.append(case("ARM B (the phrase is split across the wrap) => the mention is skipped",
                         len(arm_b) == 0, f"{len(arm_b)} refusals"))

    # ARM C: the previous chord's item is NOT read as this chord's phrase.
    arm_c_msg = ("fix(chat): the roster\n\n"
                 "The tree's own words = ⌘K focus input, ⌘⇧F code block.\n")
    arm_c = run(mod, arm_c_msg, tree)
    results.append(case("ARM C (a list item does not borrow the previous item's phrase)",
                         len(arm_c) == 0, f"{len(arm_c)} refusals"))

    # ARM D: the attribution needs the WHOLE phrase (= = one token is not a
    #   phrase: the roster's "clear chat (in place)" holds the token "in", and
    #   a sentence that merely contains "in" names nothing).
    roster = mod._chord_roster(tree)
    named_one = [entry for entry in roster if set(mod._chord_tokens(entry[1])) & {"in"}]
    true_sentence = "the docblock still listed ⌘K in the formatting quintet"
    arm_d = [entry for entry in named_one
             if set(mod._chord_tokens(entry[1])) & set(mod._chord_tokens(true_sentence))]
    results.append(case("ARM D (one token would name an action) => a TRUE sentence would be refused",
                         len(arm_d) > 0, f"one-token rule names {arm_d}"))

    # the baseline itself must be RED (= = the rule really refuses it)
    red = run(mod, FALSE_MSG, tree)
    results.append(case("the baseline (the false message) IS refused", len(red) == 2,
                         f"{len(red)} refusals"))
    shutil.rmtree(tree, ignore_errors=True)

    failed = [i for i, ok in enumerate(results) if not ok]
    print(f"\n{len(results) - len(failed)} ok, {len(failed)} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
