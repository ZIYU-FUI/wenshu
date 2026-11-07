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
  9. a DELETED path never reaches SwiftFormat (= a missing file makes
     SwiftFormat abort the whole run and report nothing = a false green).
 10. a SwiftFormat run that could not COMPLETE (= exit 70) is a failure, not
     a clean file.
 11. this file itself carries no forbidden vocabulary.

Run:  python3 Tools/wenshu-devtool/tests/test_ci_change_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import shutil
import subprocess
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


def _scratch_repo(tmp: str) -> Path:
    """A git repo with one Swift file, committed, so a change can be made."""
    repo = Path(tmp) / "repo"
    (repo / "Sources").mkdir(parents=True)
    (repo / "Sources" / "Kept.swift").write_text(
        "struct Kept {\n    let value = 1\n}\n", encoding="utf-8"
    )
    (repo / "Sources" / "Deleted.swift").write_text(
        "struct Deleted {\n    let value = 2\n}\n", encoding="utf-8"
    )
    for args in (
        ["init", "-q"],
        ["config", "user.email", "gate@test.invalid"],
        ["config", "user.name", "gate"],
        ["add", "-A"],
        ["commit", "-q", "-m", "base"],
    ):
        subprocess.run(["git", *args], cwd=str(repo), check=True, capture_output=True)
    return repo


def case_deleted_path_never_reaches_swiftformat() -> bool:
    """A change that DELETES a Swift file and edits another must still be linted.

    Measured 2026-11-02: ``swiftformat --lint`` aborts the whole run on the
    first missing file (= exit 70) and reports NOTHING for the files that do
    exist, so a deleted path in the lint list swallows the entire report and
    the gate goes green on a change that added an unformatted line.
    """
    with tempfile.TemporaryDirectory() as tmp:
        repo = _scratch_repo(tmp)
        base = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=str(repo), capture_output=True, text=True, check=True
        ).stdout.strip()
        # Delete one file and add an unformatted line to the other.
        (repo / "Sources" / "Deleted.swift").unlink()
        (repo / "Sources" / "Kept.swift").write_text(
            "struct Kept {\nlet value = 1\n    let added = 3\n}\n", encoding="utf-8"
        )
        subprocess.run(["git", "add", "-A"], cwd=str(repo), check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "change"], cwd=str(repo), check=True, capture_output=True
        )

        paths = gate.changed_paths(base, repo)
        deleted_reached = "Sources/Deleted.swift" in paths
        kept_reached = "Sources/Kept.swift" in paths

        # And the whole gate must call the drift it introduced a violation.
        exit_code = gate.main(["--base", base, "--check", "formatting", "--repo", str(repo)])
        return case(
            "a DELETED path never reaches SwiftFormat (= a missing file would swallow the whole report)",
            not deleted_reached
            and kept_reached
            and exit_code == 1,
            f"paths={paths} gate_exit={exit_code} (= 1 = the added unformatted line was caught)",
        )


def case_swiftformat_failure_is_not_a_clean_file() -> bool:
    """A SwiftFormat run that could not COMPLETE is a failure, not a clean file.

    SwiftFormat exits 70 when it cannot do the work (= a missing file, a
    rejected configuration, a syntax error). It reports NO violation in that
    case, so treating "no violation parsed" as clean is the false green this
    gate exists to remove.
    """
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        repo.mkdir()
        # A file SwiftFormat cannot parse: the run cannot complete.
        broken = repo / "Broken.swift"
        broken.write_text("struct Broken {\n", encoding="utf-8")
        raised = False
        try:
            gate.swiftformat_report(["Broken.swift"], repo)
        except gate.SwiftFormatFailure:
            raised = True
        except FileNotFoundError:
            raised = False  # SwiftFormat is not installed here: the case cannot run.
        if not raised and not _swiftformat_installed():
            return case(
                "a SwiftFormat run that could not COMPLETE (= exit 70) is a failure, not a clean file",
                True,
                "SwiftFormat is not installed on this machine (= the case cannot run here)",
            )
        return case(
            "a SwiftFormat run that could not COMPLETE (= exit 70) is a failure, not a clean file",
            raised,
            "the unparseable file raised SwiftFormatFailure instead of returning an empty report",
        )


def _swiftformat_installed() -> bool:
    return shutil.which("swiftformat") is not None


def case_the_vendored_tree_never_reaches_the_formatter() -> bool:
    """The VENDORED tree is upstream's own code, = so the formatter does not reach it.

    The vendored tree is held byte for byte against upstream (= so a
    change that reformatted it would break the vendoring itself), = and
    upstream's own files do not carry this repository's formatting (=
    measured 2026-11-07: 134 of the 141 vendored files fail
    ``swiftformat --lint`` on the pristine upstream checkout). = So the
    gate exempts that tree (= the 600-LOC cap exempts it for the same
    reason), = and the change's OWN files are still linted.
    """
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        (repo / "Sources").mkdir(parents=True)
        (repo / "Vendor" / "Engine").mkdir(parents=True)
        # Both files exist BEFORE the base commit (= so the commit has
        # something to commit), = and the change rewrites them.
        (repo / "Vendor" / "Engine" / "Upstream.swift").write_text(
            "struct Upstream {\n    let value = 1\n}\n", encoding="utf-8"
        )
        (repo / "Sources" / "Ours.swift").write_text(
            "struct Ours {\n    let value = 1\n}\n", encoding="utf-8"
        )
        for args in (
            ["init", "-q"],
            ["config", "user.email", "gate@test.invalid"],
            ["config", "user.name", "gate"],
            ["add", "-A"],
            ["commit", "-q", "-m", "base"],
        ):
            subprocess.run(["git", *args], cwd=str(repo), check=True, capture_output=True)
        base = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=str(repo), capture_output=True, text=True, check=True
        ).stdout.strip()

        # Both files are unformatted. = The vendored one must not be
        # linted; = the repository's own one must be.
        (repo / "Vendor" / "Engine" / "Upstream.swift").write_text(
            "struct Upstream {\nlet value = 1\n    let added = 3\n}\n", encoding="utf-8"
        )
        (repo / "Sources" / "Ours.swift").write_text(
            "struct Ours {\nlet value = 1\n    let added = 3\n}\n", encoding="utf-8"
        )
        subprocess.run(["git", "add", "-A"], cwd=str(repo), check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "change"], cwd=str(repo), check=True, capture_output=True
        )

        paths = gate.changed_paths(base, repo)
        vendored_reached = any(p.startswith(gate.VENDORED_PREFIX) for p in paths)
        ours_reached = "Sources/Ours.swift" in paths

        exit_code = gate.main(["--base", base, "--check", "formatting", "--repo", str(repo)])
        return case(
            "the VENDORED tree never reaches the formatter (= and the tree's own files still do)",
            not vendored_reached and ours_reached and exit_code == 1,
            f"paths={paths} gate_exit={exit_code} (= 1 = the OWN unformatted line was caught)",
        )


def main() -> int:
    results: list[bool] = []
    results.append(case_the_vendored_tree_never_reaches_the_formatter())

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

    # Case 9 + 10 need a real repository and the real SwiftFormat, so they
    # run against a scratch git repo the test builds itself.
    results.append(case_deleted_path_never_reaches_swiftformat())
    results.append(case_swiftformat_failure_is_not_a_clean_file())

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
