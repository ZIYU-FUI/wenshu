#!/usr/bin/env python3
"""Derive the candidate suite set for the source-read gate.

A test file is a CANDIDATE when it reads a production source file, in any
shape: a repo-relative literal ("Sources/...", "Package.swift") that
reaches a filesystem API, or a SourceLocator use (= it reads production
source by construction).

The set is DERIVED from the tree, so it cannot go stale: a test file that
starts reading production source tomorrow is in tomorrow's candidate set,
with no edit to this script.

Output: one line per directory group, TAB-separated:
    <group>\t<suite1>|<suite2>|...
The suite names are the @Suite type names (= what `swift test --filter`
matches), ANCHORED to the test target (= `^WenshuAppTests.<Name>/`).

WHY THE ANCHOR: `swift test --filter` takes a REGEX, and it matches
anywhere in the test's fully-qualified name. An unanchored `AppTests`
also matches `WenshuAppTests.<anything>` (= every suite in the target):
a measured 3,071 tests / 501 suites instead of the 8 in the suite named.
The anchor is what makes the filter mean "this suite".
"""
import os
import re
import sys
from collections import OrderedDict

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
TESTS = os.path.join(ROOT, "Tests")
TARGET = "WenshuAppTests"

LITERAL = re.compile(r'"(Sources/|Package\.swift|Tests/)')
FS_API = re.compile(
    r'(contentsOfFile:|contentsOf:\s|String\(data:\s*Data\(contentsOf:|'
    r'fileExists\(atPath:|enumerator\(atPath:|enumerator\(at:|'
    r'contentsOfDirectory\(atPath:|contentsOfDirectory\(at:)'
)
SUITE_DECL = re.compile(r'^\s*(?:@Suite[^\n]*\n\s*)?'
                        r'(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
                        r'(?:final\s+)?(?:struct|class|enum|actor)\s+'
                        r'([A-Za-z_][A-Za-z0-9_]*)', re.M)

groups = OrderedDict()

for dirpath, _dirs, names in os.walk(TESTS):
    for name in sorted(names):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(dirpath, name)
        with open(path, encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        if not LITERAL.search(src):
            continue
        if not (FS_API.search(src) or "SourceLocator" in src):
            continue
        rel = os.path.relpath(path, ROOT)
        suites = [m.group(1) for m in SUITE_DECL.finditer(src)
                  if m.group(1).endswith("Tests")]
        if not suites:
            continue
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

