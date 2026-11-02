#!/usr/bin/env python3
"""test_ci_change_gate.py — the CI change gate's own test suite.

Every case runs on a FIXTURE diff written out as text, so the tests stay
valid when the real diffs change. The vocabulary comes from
``commit_filter.py`` (= the repository's own source), so this file carries
none of it itself.

The cases are the ways a change can be clean or not, each one measured
against the two gates' own claims:

  1. the diff reader reports the lines a change ADDS.
  2. a deleted line is not an added line (= removing a violation adds none).
  3. the pollution gate catches a forbidden word on an added line.
  4. the pollution gate lets an allowlisted path through (= the rule docs).
  5. the pollution gate ignores a word that only ever existed in the history.
  6. the formatting gate catches a violation on an added line.
  7. the formatting gate ignores a violation on a line the change did not
     touch (= the tree's own drift belongs to the tree).
  8. the formatting gate ignores a violation in a file the change did not
     touch.
  9. this file itself carries no forbidden vocabulary.

Run:  python3 Tools/wenshu-devtool/tests/test_ci_change_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "ci_change_gate.py"

sys.path.insert(0, str(TOOL.parent))
from commit_filter import FORBIDDEN_TOKENS  # noqa: E402

spec = importlib.util.spec_from_file_location("ci_change_gate", TOOL)
assert spec is not None and spec.loader is not None
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

TOKEN = FORBIDDEN_TOKENS[0]

DIFF_WITH_ADDITION = """diff --git a/Sources/WenshuApp/Feature.swift b/Sources/WenshuApp/Feature.swift
index 1111111..2222222 100644
--- a/Sources/WenshuApp/Feature.swift
+++ b/Sources/WenshuApp/Feature.swift
@@ -10,0 +11,2 @@
+    let added = 1
+    let alsoAdded = 2
@@ -30,0 +33 @@
+    let third = 3
"""

DIFF_WITH_DELETION = """diff --git a/Sources/WenshuApp/Feature.swift b/Sources/WenshuApp/Feature.swift
index 1111111..2222222 100644
--- a/Sources/WenshuApp/Feature.swift
+++ b/Sources/WenshuApp/Feature.swift
@@ -10,2 +9,0 @@
-    let removed = 1
-    let alsoRemoved = 2
"""

DIFF_WITH_VOCABULARY = """diff --git a/Sources/WenshuApp/Feature.swift b/Sources/WenshuApp/Feature.swift
index 1111111..2222222 100644
--- a/Sources/WenshuApp/Feature.swift
+++ b/Sources/WenshuApp/Feature.swift
@@ -10,0 +11 @@
+    let forbidden = "%s"
""" % TOKEN

DIFF_VOCABULARY_IN_ALLOWLIST = """diff --git a/AGENTS.md b/AGENTS.md
index 1111111..2222222 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -10,0 +11 @@
+    the forbidden family is named here: %s
""" % TOKEN


def case(name: str, ok: bool, detail: str = "") -> bool:
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {name}" + (f"  ({detail})" if detail else ""))
    return ok


def main() -> int:
    results: list[bool] = []

    ranges, lines = gate.parse_diff(DIFF_WITH_ADDITION)
    path = "Sources/WenshuApp/Feature.swift"
    results.append(
        case(
            "the diff reader reports the lines a change ADDS",
            set(lines.get(path, {})) == {11, 12, 33} and ranges.get(path) == [(11, 12), (33, 33)],
            f"lines={sorted(lines.get(path, {}))} ranges={ranges.get(path)}",
        )
    )

    _, deleted_lines = gate.parse_diff(DIFF_WITH_DELETION)
    results.append(
        case(
            "a deleted line is not an added line",
            deleted_lines.get(path, {}) == {},
            f"lines={deleted_lines.get(path)}",
        )
    )

    _, vocab_lines = gate.parse_diff(DIFF_WITH_VOCABULARY)
    offenders = gate.pollution_offenders(vocab_lines)
    results.append(
        case(
            "the pollution gate catches a forbidden word on an added line",
            len(offenders) == 1
            and offenders[0][0] == path
            and offenders[0][1] == 11
            and offenders[0][2] == TOKEN,
            f"offenders={offenders}",
        )
    )

    _, allowed_lines = gate.parse_diff(DIFF_VOCABULARY_IN_ALLOWLIST)
    results.append(
        case(
            "the pollution gate lets an allowlisted path through",
            gate.pollution_offenders(allowed_lines) == [],
            f"offenders={gate.pollution_offenders(allowed_lines)}",
        )
    )

    results.append(
        case(
            "the pollution gate ignores a word that only ever existed in the history",
            gate.pollution_offenders({}) == [],
            "the history is not read at all",
        )
    )

    violations = [
        (path, 11, "trailingCommas", "Add or remove trailing commas."),
        (path, 500, "blankLinesAtStartOfScope", "Remove leading blank line."),
    ]
    results.append(
        case(
            "the formatting gate catches a violation on an added line",
            len(gate.format_offenders(violations, ranges)) == 1
            and gate.format_offenders(violations, ranges)[0][1] == 11,
            f"offenders={gate.format_offenders(violations, ranges)}",
        )
    )

    results.append(
        case(
            "the formatting gate ignores a violation on a line the change did not touch",
            all(o[1] != 500 for o in gate.format_offenders(violations, ranges)),
            "the tree's own drift belongs to the tree",
        )
    )

    other_file = [("Sources/WenshuApp/Other.swift", 11, "trailingCommas", "x")]
    results.append(
        case(
            "the formatting gate ignores a violation in a file the change did not touch",
            gate.format_offenders(other_file, ranges) == [],
            f"offenders={gate.format_offenders(other_file, ranges)}",
        )
    )

    absolute = (
        "/repo/Sources/WenshuApp/Feature.swift:11:1: error: (consecutiveSpaces) Replace consecutive spaces."
    )
    results.append(
        case(
            "a violation SwiftFormat reports with an ABSOLUTE path still meets the change's path",
            len(
                gate.format_offenders(
                    gate.format_violations(absolute, Path("/repo")), ranges
                )
            )
            == 1,
            "SwiftFormat resolves the path before it prints it (= the first version of this gate reported nothing)",
        )
    )

    with tempfile.TemporaryDirectory() as tmp:
        with_config = Path(tmp) / "with"
        with_config.mkdir()
        (with_config / ".swift-format").write_text("{}", encoding="utf-8")
        without_config = Path(tmp) / "without"
        without_config.mkdir()
        results.append(
            case(
                "the repository's .swift-format is NOT passed to SwiftFormat",
                "--config" not in gate.swiftformat_args(["A.swift"], with_config)
                and "--config" not in gate.swiftformat_args(["A.swift"], without_config),
                "SwiftFormat rejects that file (= nine of its rule names do not exist in this version), = and a rejected config reports nothing",
            )
        )

    own_text = Path(__file__).read_text(encoding="utf-8")
    results.append(
        case(
            "this file itself carries no forbidden vocabulary",
            all(token not in own_text for token in FORBIDDEN_TOKENS),
            "the vocabulary is read from commit_filter.py, never written here",
        )
    )

    print()
    passed = sum(1 for r in results if r)
    print(f"{passed}/{len(results)} cases passed")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
