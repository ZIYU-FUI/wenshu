#!/usr/bin/env python3
"""Derive the candidate suite set for the source-read gate.

A test file is a CANDIDATE when it reads a production source file,
in ANY shape. The rule is the OR of three ways a read can reach the
filesystem:

  1. a SourceLocator use (= it reads production source by
     construction: the helper resolves the path against the repo root,
     not against the working directory);
  2. a repo-relative path LITERAL ("Sources/...", "Package.swift",
     "Tests/...") that reaches a filesystem API (= the shape the card
     banned: the literal is resolved against the working directory);
  3. a `currentDirectoryPath` read that reaches a filesystem API (= the
     same dependency, spelled out).

The set is DERIVED from the tree, so it cannot go stale: a test file
that starts reading production source tomorrow is in tomorrow's
candidate set, with no edit to this script.

EVERY alternative is evaluated on its own. An earlier version of this
script tested the literal FIRST and `continue`d when it was absent,
which made the SourceLocator alternative unreachable for any file that
had no quoted repo-path literal (= every file that reads production
source by a non-literal path). That short-circuit also hid the card's
own banned shape, which carries no quoted literal at all:

    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

so the gate reported PASS on a tree where the defect was fully
reintroduced. The three alternatives below are independent, and a file
qualifying under ANY of them is a candidate.

Output: one line per directory group, TAB-separated:
    <group>\t<suite1>|<suite2>|...
The suite names are the test type names (= what `swift test --filter`
matches), ANCHORED to the test target (= `^WenshuAppTests.<Name>/`).

WHY THE ANCHOR: `swift test --filter` takes a REGEX, and it matches
anywhere in the test's fully-qualified name. An unanchored `AppTests`
also matches `WenshuAppTests.<anything>` (= every suite in the target):
a measured 3,071 tests / 501 suites instead of the 8 in the suite named.
The anchor is what makes the filter mean "this suite".

SUITE NAMES: a suite is a `@Suite`-annotated type, or (for the
XCTest-style files, which carry no `@Suite`) a type whose name ends in
`Tests`. A `@Suite` is included whatever its name is: an E2E suite
named `AnbaiqiangLiveResearch` is a suite, and dropping it because its
name does not end in `Tests` would silently remove it from the gate.
"""
import os
import re
import sys
from collections import OrderedDict

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
TESTS = os.path.join(ROOT, "Tests")
TARGET = "WenshuAppTests"

# A repo-relative path inside a quoted string. The prefix is allowed
# to be anything (`"/Sources/..."`, `"../Sources/..."`), because what
# matters is that the path is RELATIVE and therefore resolved against
# the working directory.
LITERAL = re.compile(r'"[^"\n]*\b(?:Sources/|Package\.swift|Tests/)')
# The working directory, spelled out.
CWD = re.compile(r'currentDirectoryPath')
# A filesystem API that READS.
FS_API = re.compile(
    r'(contentsOfFile:|contentsOf:\s|String\(data:\s*Data\(contentsOf:|'
    r'Data\(contentsOf:|fileExists\(atPath:|enumerator\(atPath:|enumerator\(at:|'
    r'contentsOfDirectory\(atPath:|contentsOfDirectory\(at:)'
)
# A type declaration, with the `@Suite` attribute in front of it.
DECL = re.compile(
    r'(?:@Suite[^\n]*\n\s*)?'
    r'(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?:final\s+)?(?:struct|class|enum|actor)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)'
)
# A `@Suite`-annotated declaration. Other attributes may sit between
# the `@Suite` and the declaration (`@Suite("...")` + `@MainActor` +
# `struct X`), so any number of attribute lines may intervene.
SUITE_DECL = re.compile(
    r'@Suite[^\n]*\n(?:\s*@[^\n]*\n)*\s*'
    r'(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?:final\s+)?(?:struct|class|enum|actor)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)'
)

groups = OrderedDict()

for dirpath, _dirs, names in os.walk(TESTS):
    for name in sorted(names):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(dirpath, name)
        with open(path, encoding="utf-8", errors="replace") as fh:
            src = fh.read()

        # --- the three alternatives, each evaluated on its own ---------
        reads_by_locator = "SourceLocator" in src
        reads_by_literal = bool(LITERAL.search(src)) and bool(FS_API.search(src))
        reads_by_cwd = bool(CWD.search(src)) and bool(
            LITERAL.search(src) or FS_API.search(src))
        if not (reads_by_locator or reads_by_literal or reads_by_cwd):
            continue

        # --- the suite names in this file ------------------------------
        suites = []
        for m in SUITE_DECL.finditer(src):
            if m.group(1) not in suites:
                suites.append(m.group(1))
        for m in DECL.finditer(src):
            name_ = m.group(1)
            if name_.endswith("Tests") and name_ not in suites:
                suites.append(name_)
        if not suites:
            continue

        rel = os.path.relpath(path, ROOT)
        parts = rel.split(os.sep)
        try:
            idx = parts.index("WenshuAppTests")
        except ValueError:
            idx = len(parts) - 2
        group = "/".join(parts[idx + 1:-1]) or "(root)"
        bucket = groups.setdefault(group, [])
        for s in suites:
            if s not in bucket:
                bucket.append(s)

for group, suites in groups.items():
    alternation = "|".join(re.escape(s) for s in suites)
    print(f"{group}\t^{TARGET}\\.({alternation})/")
