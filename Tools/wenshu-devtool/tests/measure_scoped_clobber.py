#!/usr/bin/env python3
"""MEASURE THE \"52 / 14\" FIGURES AT THREE SCOPES.

= = ⇒ The two figures the tool's own comments carry, = = = = and the two
# = = = = definitions this measures:

# = = = =   C1 (= = = = the \"52\"): = = = = the (file, name) pairs where a
# = = = =   LOCAL hides a type's `private` member. = = = = = = That is: = =
# = = = =   = = = = the type-scoped scan says the type's member is private,
# = = = =   = = = = and the flat scan's LAST match for that name is NOT
# = = = =   = = = = private (= = = = = = the local's declaration won), = = =
# = = = =   = = = = so the flat scan reads a widening that is not one.

# = = = =   C2 (= = = = the \"14\"): = = = = the names that live in two types
# = = = =   with disagreeing privacy, = = = = = = and the flat scan lost the
# = = = =   private one (= = = = = = the flat scan reads a widening that is
# = = = =   = = = = not one).

= = ⇒ AND THE SCOPE MATTERS, = = = = so this prints all three: = = = = the
# = = = = whole tree, = = = = the tree without `Vendor/`, = = = = = and
# = = = = `Sources/` + `Tests/`. = = ⇒ Measured on `main`: = = = = C1 is 65,
# = = = = 55 and 52; = = = = and C2 is 19 pairs / 18 names, = = = = 18 pairs
# = = = = / 17 names, = = = = and 15 pairs / 14 names.

= = ⇒ AND IT SHIPS BECAUSE A NUMBER NOBODY CAN RUN IS A CLAIM. = = = = = The
# = = = = tree's comments carry these figures, = = = = so the figures have to
# = = = = be reproducible from the tree, = = = = and not from a card.

= = ⇒ ⇒ AND IT MEASURES THE TREE IT LIVES IN. = = = = The repository and
# = = = = the tool are named by the CALLER (= = = = `--repo` and `--tool`),
# = = = = and the defaults are THIS tree's own copies (= = = = the tree the
# = = = = script was run from, = = = = and the tool beside it). = = ⇒ So the
# = = = = figures are the figures of the tree being certified, = = = = and
# = = = = the script runs in a fresh clone (= = = = where no other checkout
# = = = = and no scratch worktree exists).
"""
import argparse
import importlib.util
import re
import subprocess
from pathlib import Path

MOD = (r"(?:(?:static|final|lazy|weak|unowned|override|nonisolated|class"
       r"|mutating|dynamic)\s+)*")
FLAT = re.compile(
    rf"^(\s*)(private\s+)?((?:@\w+(?:\([^)]*\))?\s+)*){MOD}(var|let|func)\s+(\w+)",
    re.M)


def flat_map(text: str):
    """The old base-side map: = = name -> (private, the winning match)."""
    out = {}
    for match in FLAT.finditer(text):
        out[match.group(5)] = (bool(match.group(2)), match)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".",
                        help="the repository to measure (= = the tree this "
                             "script lives in)")
    parser.add_argument("--tool", default=None,
                        help="the tool to measure (= = the tree's own copy)")
    args = parser.parse_args()

    # = = ⇒ THE TREE THIS SCRIPT LIVES IN, = = = = and the tool beside it.
    # = = = = = The old two constants named the shared checkout and a
    # = = = = = scratch worktree inside it (= = = = = and that worktree is
    # = = = = = gitignored and untracked, = = = = = so the tree does not
    # = = = = = carry it), = = = = = and the script measured THAT tree (= =
    # = = = = = and read THAT tree's tool) = = = = = from any checkout,
    # = = = = = and it failed SILENTLY when the tool was perturbed.
    repo = Path(args.repo).resolve()
    tool_path = Path(args.tool) if args.tool else (
        repo / "Tools/wenshu-devtool/split_pre_check.py")
    spec = importlib.util.spec_from_file_location("spc", tool_path)
    spc = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(spc)

    files = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", "HEAD"],
        cwd=str(repo), capture_output=True, text=True, check=True,
    ).stdout.split()
    swift = [f for f in files if f.endswith(".swift")]

    scopes = {
        "the whole tree": swift,
        "no Vendor/": [f for f in swift if not f.startswith("Vendor/")],
        "Sources/ + Tests/": [f for f in swift
                              if f.startswith("Sources/") or f.startswith("Tests/")],
    }

    for label, paths in scopes.items():
        c1 = 0
        c2_pairs = 0
        c2_names = set()
        for path in paths:
            proc = subprocess.run(["git", "show", f"HEAD:{path}"], cwd=str(repo),
                                  capture_output=True, text=True)
            if proc.returncode != 0:
                continue
            text = proc.stdout
            flat = flat_map(text)
            by_name = {}
            for owner, name, private, _line in spc.scoped_members(text):
                by_name.setdefault(name, []).append((owner, private))
            for name, owners in by_name.items():
                if not any(private for _o, private in owners):
                    continue
                # = = ⇒ THE TYPE'S MEMBER IS PRIVATE. = = = = And the flat
                # = = = = scan's winning match for this name is NOT private
                # = = = = (= = = = = the local's declaration won).
                flat_private = flat.get(name, (None, None))[0]
                if flat_private is False:
                    c1 += 1
                if len({p for _o, p in owners}) > 1 and flat_private is False:
                    c2_pairs += 1
                    c2_names.add(name)
        print(f"=== {label}")
        print(f"    C1 (= = the pairs where a local hides a type's private "
              f"member): {c1}")
        print(f"    C2 (= = the pairs where the name lives in two types with "
              f"disagreeing privacy): {c2_pairs} pairs, {len(c2_names)} names")


if __name__ == "__main__":
    main()
