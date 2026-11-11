#!/usr/bin/env python3
"""MEASURE THE PROMOTIONS ARM'S BLAST RADIUS, = = AT THE MEMBER LEVEL.

= = ⇒ WHY THIS SCRIPT EXISTS: = = the arm's two sides use TWO DIFFERENT
# = = = = regexes for a member, = = and the old one's asymmetry is the defect
# = = = = the repair fixes:
# = = = =   OLD base side: = = = = the access level BEFORE the attribute
# = = = =                 (= = = = so `@AppStorage(...) private var x` was
# = = = =                 = = = = never read as private AT ALL), = = = = and
# = = = =                 = = = = the LAST match per NAME wins.
# = = = =   OLD tip side:  = = = = the access level AFTER the attribute, = =
# = = = =                 = = = = and "is private" is tested by a regex
# = = = =                 = = = = with NO attribute allowance.

= = ⇒ So the old arm's BASE map (= = keyed by NAME alone) applied a type's
# = = = = `private` member to a tip declaration that is a LOCAL, = = and two
# = = = = types in one file shared one privacy. = = ⇒ The old arm therefore
# = = = = names members that are not widened (= = the false positives), = =
# = = = and it MISSES the members whose access level sits after an
# = = = = attribute (= = = = the newly reachable ones).

= = ⇒ The NEW arm (= = = = this tree's own `scoped_members` on both sides, = =
# = = = = and the three pairing rules) names a member by (OWNING TYPE, NAME).

= = ⇒ The report is at the MEMBER level, = = = = because a commit-level
# = = = = comparison hides it: = = = = two arms can report the same NUMBER
# = = = = of findings on a commit while naming DIFFERENT members.
"""
from __future__ import annotations

import argparse
import importlib.util
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

MODIFIERS = (
    r"(?:(?:static|final|lazy|weak|unowned|override|nonisolated|class"
    r"|mutating|dynamic)\s+)*"
)
OLD_BASE = re.compile(
    rf"^(\s*)(private\s+)?((?:@\w+(?:\([^)]*\))?\s+)*){MODIFIERS}"
    r"(var|let|func)\s+(\w+)",
    re.M,
)
OLD_TIP = re.compile(
    rf"^(\s*)((?:@\w+(?:\([^)]*\))?\s+)*)"
    rf"(?:(public|internal|private|fileprivate|open)\s+)?{MODIFIERS}"
    r"(var|let|func)\s+(\w+)"
)
OLD_IS_PRIVATE = re.compile(rf"^\s*private\s+{MODIFIERS}(?:var|let|func)\s+(\w+)\b")


def load_tool(path: Path):
    spec = importlib.util.spec_from_file_location("split_pre_check", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load the tool at {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_tree(repo: Path, sha: str) -> Dict[str, str]:
    names = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", sha],
        cwd=str(repo), capture_output=True, text=True, check=True,
    ).stdout.split()
    swift = [n for n in names if n.endswith(".swift")]
    if not swift:
        return {}
    proc = subprocess.run(
        ["git", "cat-file", "--batch"], cwd=str(repo),
        input=("\n".join(f"{sha}:{n}" for n in swift) + "\n").encode(),
        capture_output=True, check=True,
    )
    out: Dict[str, str] = {}
    data = proc.stdout
    pos = 0
    for name in swift:
        newline = data.find(b"\n", pos)
        if newline < 0:
            break
        header = data[pos:newline]
        if b"missing" in header:
            pos = newline + 1
            continue
        size = int(header.split()[-1])
        start = newline + 1
        out[name] = data[start:start + size].decode("utf-8", "replace")
        pos = start + size + 1
    return out


def old_arm(base: Dict[str, str], tip: Dict[str, str], paths: List[str],
            counterparts: Dict[str, List[str]]) -> Set[Tuple[str, str]]:
    """The OLD arm's own two scans: = = the base map, = = then the tip scan."""
    members: Dict[Tuple[str, str], bool] = {}
    for base_rel in {b for group in counterparts.values() for b in group}:
        for match in OLD_BASE.finditer(base.get(base_rel) or ""):
            members[(base_rel, match.group(5))] = bool(match.group(2))
    hits: Set[Tuple[str, str]] = set()
    for rel in paths:
        text = tip.get(rel)
        if text is None:
            continue
        own = counterparts.get(rel, [])
        for line in text.split("\n"):
            match = OLD_TIP.match(line)
            if not match:
                continue
            name = match.group(5)
            if not any(members.get((b, name)) is True for b in own):
                continue
            if not OLD_IS_PRIVATE.search(line):
                hits.add((rel, name))
    return hits


def new_arm(tool, base: Dict[str, str], tip: Dict[str, str], paths: List[str],
            counterparts: Dict[str, List[str]]) -> Set[Tuple[str, str, str]]:
    """The tree's own arm: = = the member is (OWNING TYPE, NAME)."""
    by_name: Dict[str, Dict[str, List[Tuple[str, bool]]]] = {}
    for base_rel in {b for group in counterparts.values() for b in group}:
        for owner, name, private, _line in tool.scoped_members(base.get(base_rel) or ""):
            by_name.setdefault(base_rel, {}).setdefault(name, []).append((owner, private))
    tips_of_base: Dict[str, List[str]] = {}
    for tip_rel, base_rels in counterparts.items():
        for base_rel in base_rels:
            tips_of_base.setdefault(base_rel, []).append(tip_rel)
    types = {rel: set(tool._TYPE_DECL.findall(tip.get(rel) or "")) for rel in paths}
    hits: Set[Tuple[str, str, str]] = set()
    for rel in paths:
        text = tip.get(rel)
        if text is None:
            continue
        own = counterparts.get(rel, [])
        for owner, name, private, _line in tool.scoped_members(text):
            if private:
                continue
            candidates = [(b, o, p) for b in own
                          for o, p in by_name.get(b, {}).get(name, [])]
            exact = [c for c in candidates if c[1] == owner]
            if exact:
                matched = exact[0]
            elif len(candidates) == 1 and not tool._owner_survives(
                    candidates[0][1], tips_of_base, types):
                matched = candidates[0]
            else:
                continue
            if matched[2]:
                hits.add((rel, owner, name))
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="the repository to measure")
    parser.add_argument("--tool", default=None,
                        help="the tool to measure (= = the tree's own copy)")
    parser.add_argument("--window", type=int, default=300,
                        help="how many commits of the first parent to walk")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    tool_path = Path(args.tool) if args.tool else (
        repo / "Tools/wenshu-devtool/split_pre_check.py")
    tool = load_tool(tool_path)

    log = subprocess.run(
        ["git", "log", "--format=%H %P", f"-{args.window}"],
        cwd=str(repo), capture_output=True, text=True, check=True,
    ).stdout.split("\n")
    pairs = []
    for line in log:
        fields = line.split()
        if len(fields) >= 2:
            pairs.append((fields[0], fields[1]))

    commits = 0
    old_only: Dict[str, List[Tuple[str, str]]] = {}
    new_only: Dict[str, List[Tuple[str, str]]] = {}
    same = 0
    old_members = 0
    new_members = 0
    for tip, parent in pairs:
        base_tree = read_tree(repo, parent)
        tip_tree = read_tree(repo, tip)
        paths = sorted(
            (set(tip_tree) - set(base_tree))
            | {p for p in tip_tree if p in base_tree and tip_tree[p] != base_tree[p]}
        )
        if not paths:
            continue
        counterparts = tool._counterparts(base_tree, tip_tree, paths)
        old = old_arm(base_tree, tip_tree, paths, counterparts)
        new = new_arm(tool, base_tree, tip_tree, paths, counterparts)
        if not old and not new:
            continue
        commits += 1
        old_members += len(old)
        new_members += len(new)
        old_keys = {(rel, name) for rel, name in old}
        new_keys = {(rel, name) for rel, _owner, name in new}
        only_old = sorted(old_keys - new_keys)
        only_new = sorted(new_keys - old_keys)
        if only_old:
            old_only[tip] = only_old
        if only_new:
            new_only[tip] = only_new
        if not only_old and not only_new:
            same += 1

    print(f"=== the window: {len(pairs)} commits")
    print(f"=== the commits with a promotion: {commits}")
    print(f"=== the OLD arm names {old_members} members; "
          f"the NEW arm names {new_members}")
    print(f"=== the members only the OLD arm names: "
          f"{sum(len(v) for v in old_only.values())} "
          f"in {len(old_only)} commits (= = the false positives)")
    print(f"=== the members only the NEW arm names: "
          f"{sum(len(v) for v in new_only.values())} "
          f"in {len(new_only)} commits (= = the newly reachable ones)")
    print(f"=== the commits where the two name the same members: {same}")
    for tip, members in old_only.items():
        print(f"\n  only the OLD arm names, {tip[:12]}:")
        for rel, name in members:
            print(f"    {rel} :: {name}")
    for tip, members in new_only.items():
        print(f"\n  only the NEW arm names, {tip[:12]}:")
        for rel, name in members:
            print(f"    {rel} :: {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
