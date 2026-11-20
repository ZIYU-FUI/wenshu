#!/usr/bin/env python3
"""Census of the NFI registry, measured with THE GATE'S OWN rulers, for any tree.

Usage: nfi-census.py <tree-root> [<tree-root> ...]   (e.g. `.` and a `.worktrees/<card>` and a
throwaway clone holding a landing merge)

Why this file exists: `docs/agents/nfi.md` publishes a census per tree (main / branch tip /
landing), and a number quoted under the wrong tree label is the defect this family keeps catching.
The numbers in that document are this tool's output, so the document can be re-checked without
trusting anybody's transcription.

Every number is printed beside the tree it came from, because the verdict's whole complaint
about the previous publication was that a census taken at a tip was quoted as if it described
the landed tree. The rulers are imported from the tree itself (`rows`, `LITERAL`, `wc_lines`,
and the driver's `key_of`), so a tool and a tree can never disagree about what a row is.

Key reading follows nfi-loc-check.py:174: `cells[1].strip("`")`. Passing the raw cell was my own
first version of this arm, and it reported 0 readable / 429 unreadable on a tree whose real
census is 426 readable — a ruler that reads nothing looks exactly like a tree with nothing in it.
"""
import importlib.util, os, subprocess, sys, pathlib


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def reason_of(root, key):
    """The gate's own reason rule, in its fixed order: shorthand FIRST, then existence."""
    if "..." in key:
        return "shorthand"
    if "/" not in key:
        return "not-a-path"
    return "absent" if not os.path.exists(os.path.join(root, key)) else "readable"


def census(root):
    root = str(pathlib.Path(root).resolve())
    loc = load(f"{root}/Tools/wenshu-devtool/nfi-loc-check.py", "loc_" + str(abs(hash(root))))
    drv = load(f"{root}/Scripts/merge-nfi-registry.py", "drv_" + str(abs(hash(root))))
    text = pathlib.Path(f"{root}/docs/agents/nfi.md").read_text(encoding="utf-8")
    rows = list(loc.rows(text))
    data = [c for c in rows if len(c) > 2 and not set(c[0]) <= set("- ")]
    numeric = readable = abbrev = unmeas = 0
    unmeas_keys = []
    for c in data:
        key = c[1].strip("`")
        loc_cell = c[2].strip("`")
        if not loc.LITERAL.match(loc_cell):
            continue
        numeric += 1
        if "..." in key:
            abbrev += 1
        elif loc.wc_lines(os.path.join(root, key)) is not None:
            readable += 1
        else:
            unmeas += 1
            unmeas_keys.append((key, reason_of(root, key)))
    keys = {}
    for r in drv.split_rows(text)[1]:
        k = drv.key_of(r)
        if k:
            keys[k] = keys.get(k, 0) + 1
    tip = subprocess.run(["git", "-C", root, "rev-parse", "--short", "HEAD"],
                         capture_output=True, text=True).stdout.strip()
    print(f"tree {root}")
    print(f"  HEAD={tip}  data rows={len(data)}  numeric LOC rows={numeric}")
    print(f"  readable={readable}  abbreviated={abbrev}  unreadable={unmeas}   "
          f"(sum={readable + abbrev + unmeas}, equals numeric: {readable + abbrev + unmeas == numeric})")
    print(f"  duplicate keys: { {k: v for k, v in keys.items() if v > 1} or 'none' }")
    for probe in ("Vendor/MarkdownEngine/", "262", "Vendor/MarkdownEngine/Package.swift",
                  "docs/agents/2026-11-03-session-close-board-client.md"):
        print(f"    key {probe!r:58s} -> {keys.get(probe, 0)}")
    for k, why in unmeas_keys:
        print(f"    unreadable: {k}  ::  {why}")
    print()


for arg in sys.argv[1:]:
    census(arg)
