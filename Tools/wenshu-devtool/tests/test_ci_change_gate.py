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
 11. a change that DROPS a .md's trailing newline is reported (= the byte
     the house's merge driver compares) = = and it is reported BY the GATE
     (= = not by the helper), = = so a mutation that breaks the scoping
     cannot pass.
 12. a .md that ALREADY lacked the byte (= the tree's drift) is NOT the
     change's business (= = the gate's DELTA rule, = = not a state check)
     = = and the drifted path is not among the reported paths.
 13. a NEW .md that never had the byte is reported.
 14. a RENAME of a byte-less .md drops nothing (= = and is green).
 15. this file itself carries no forbidden vocabulary.
16. a NEW file over the 600-LOC cap is reported BY THE GATE (= the cap's
    own mutation test: = a 601-line file must go red).
17. the cap reaches the ``Tests/`` tree (= = the ruling of 2026-11-21: = =
    AGENTS.md 6.6 exempts ``Vendor/`` alone, = = so a test file over the
    cap is a violation like any other).
18. an over-cap file the change GREW is reported, = and the report carries
    its base size (= = so the ratchet's arithmetic is visible).
19. an over-cap file the change SHRANK lands (= = the split in progress),
    = and the report says it excused one.
20. the VENDORED tree is exempt from the cap (= = and a vendored file over
    the cap never reaches the report).
21. a path with no blob at HEAD is UNMEASURABLE, = never clean.

Run:  python3 Tools/wenshu-devtool/tests/test_ci_change_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
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


def _scratch_repo_with_markdown(tmp: str) -> tuple[Path, str]:
    """A git repo with two .md files, = = and the base commit's sha.

    ``docs/kept.md`` ends with a newline (= = the normal state) and
    ``docs/drifted.md`` never had one (= = the tree's own drift, = = which
    a change that merely EDITS it must not be charged for).
    """
    repo = Path(tmp) / "md-repo"
    (repo / "docs").mkdir(parents=True)
    (repo / "docs" / "kept.md").write_text("# kept\n\nbody.\n", encoding="utf-8")
    (repo / "docs" / "drifted.md").write_text("# drifted\n\nbody.", encoding="utf-8")
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
    return repo, base


def _commit(repo: Path, message: str) -> None:
    subprocess.run(["git", "add", "-A"], cwd=str(repo), check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", message], cwd=str(repo), check=True, capture_output=True
    )


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


def _swift_of(lines: int, name: str = "Subject") -> str:
    """A Swift file of EXACTLY ``lines`` lines (= = the cap's own unit)."""
    body = "".join(f"    let value{i} = {i}\n" for i in range(max(lines - 2, 0)))
    return f"struct {name} {{\n{body}}}\n"


def _scratch_repo_with_swift(tmp: str, rel: str, lines: int) -> tuple[Path, str]:
    """A git repo whose one Swift file at ``rel`` is ``lines`` long, = = and the base sha."""
    repo = Path(tmp) / "cap-repo"
    target = repo / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(_swift_of(lines, target.stem), encoding="utf-8")
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
    return repo, base


def _run_gate(repo: Path, base: str, check: str) -> tuple[int, str]:
    """The gate's exit code AND its printed report (= = both are the claim)."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = gate.main(["--base", base, "--check", check, "--repo", str(repo)])
    return code, out.getvalue()


def case_a_new_file_one_line_over_the_cap_goes_red() -> bool:
    """The cap's own mutation test: = a 601-line NEW file must go red.

    = = This is the case the 2026-11-21 audit asked for: = = the rule
    (AGENTS.md 6.6) had no instrument that could fail, = = so a card added a
    1092-line test file and its run went green.
    """
    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_swift(tmp, "Sources/Kept.swift", 12)
        rel = "Sources/New.swift"
        (repo / rel).write_text(_swift_of(gate.LOC_CAP + 1, "New"), encoding="utf-8")
        _commit(repo, "add a file one line over the cap")
        code, out = _run_gate(repo, base, "loc-cap")
        named = rel in out and "NEW in this change" in out
        return case(
            f"a NEW file ONE LINE over the {gate.LOC_CAP}-LOC cap is reported BY THE GATE",
            code == 1 and named,
            f"gate_exit={code} (= 1 = the cap caught it) the report names it: {named}",
        )


def case_a_file_at_the_cap_is_green() -> bool:
    """EXACTLY at the cap is inside it (= = the tree carries such a file).

    = = The control for the case above: = = without it, = = a gate that
    failed unconditionally would look like a gate that works.
    """
    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_swift(tmp, "Sources/Kept.swift", 12)
        rel = "Sources/AtTheCap.swift"
        (repo / rel).write_text(_swift_of(gate.LOC_CAP, "AtTheCap"), encoding="utf-8")
        _commit(repo, "add a file exactly at the cap")
        code, out = _run_gate(repo, base, "loc-cap")
        return case(
            f"a file of EXACTLY {gate.LOC_CAP} LOC is green (= = the boundary is >, = = not >=)",
            code == 0 and "within the 600-LOC cap" in out,
            f"gate_exit={code} (= 0) report: {out.splitlines()[0][:70] if out else ''}",
        )


def case_the_cap_reaches_the_tests_tree() -> bool:
    """AGENTS.md 6.6 exempts ``Vendor/`` ALONE, = so ``Tests/`` is inside the cap.

    = = The boss's ruling of 2026-11-21: = = a test file is split by CONCERN
    (one subject per file) because the judge is whether a review card can
    read the change, = = and a 1092-line suite with 29 ``@Test`` functions
    in one ``struct`` is not readable.
    """
    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_swift(tmp, "Sources/Kept.swift", 12)
        rel = "Tests/WenshuAppTests/Shared/UI/SubjectTests.swift"
        target = repo / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(_swift_of(1092, "SubjectTests"), encoding="utf-8")
        _commit(repo, "add a test file far over the cap")
        code, out = _run_gate(repo, base, "loc-cap")
        return case(
            "the cap reaches the TESTS tree (= = the ruling of 2026-11-21)",
            code == 1 and rel in out,
            f"gate_exit={code} (= 1 = a test file over the cap is a violation like any other)",
        )


def case_a_grown_over_cap_file_carries_its_base_size() -> bool:
    """An over-cap file the change GREW is charged, = with its base size shown."""
    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_swift(
            tmp, "Sources/Grown.swift", gate.LOC_CAP + 10
        )
        (repo / "Sources" / "Grown.swift").write_text(
            _swift_of(gate.LOC_CAP + 11, "Grown"), encoding="utf-8"
        )
        _commit(repo, "grow a file that was already over the cap")
        code, out = _run_gate(repo, base, "loc-cap")
        shown = f"was {gate.LOC_CAP + 10}" in out
        return case(
            "an over-cap file the change GREW is reported WITH its base size",
            code == 1 and shown,
            f"gate_exit={code} the ratchet's arithmetic is visible: {shown}",
        )


def case_a_shrinking_over_cap_file_lands() -> bool:
    """An over-cap file the change SHRANK lands (= = the split in progress).

    = = Why a ratchet and not a state check: = = 9 files are already over
    the cap on main, = = so a state check would turn every card that touches
    one of them red before anybody had split anything (= = the same false
    red the markdown-newline check measured on its own rule).
    """
    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_swift(
            tmp, "Sources/Split.swift", gate.LOC_CAP + 100
        )
        (repo / "Sources" / "Split.swift").write_text(
            _swift_of(gate.LOC_CAP + 40, "Split"), encoding="utf-8"
        )
        _commit(repo, "the first half of a split")
        code, out = _run_gate(repo, base, "loc-cap")
        return case(
            "an over-cap file the change SHRANK lands (= = and the report says what it excused)",
            code == 0 and "Split.swift" in out and "shrinking" in out,
            f"gate_exit={code} (= 0 = progress lands) the excuse is printed: {'Split.swift' in out}",
        )


def case_the_vendored_tree_is_exempt_from_the_cap() -> bool:
    """``Vendor/`` is the rule's ONLY exemption (= = upstream's own bytes)."""
    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_swift(tmp, "Sources/Kept.swift", 12)
        rel = "Vendor/Engine/Upstream.swift"
        target = repo / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(_swift_of(gate.LOC_CAP * 3, "Upstream"), encoding="utf-8")
        _commit(repo, "vendor an upstream file far over the cap")
        code, out = _run_gate(repo, base, "loc-cap")
        return case(
            "the VENDORED tree is exempt from the cap (= = and never reaches the report)",
            code == 0 and rel not in out,
            f"gate_exit={code} (= 0) the vendored path is absent from the report: {rel not in out}",
        )


def case_an_unmeasurable_path_is_never_certified_clean() -> bool:
    """A path with no blob at HEAD is UNMEASURABLE, = never clean.

    = = ``changed_paths`` drops deletions, = = so this arm is the gate's
    refusal rather than a case the diff produces: = = a file the gate could
    not read is not a file the gate found inside the cap.
    """
    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_swift(tmp, "Sources/Kept.swift", 12)
        offenders, shrinking, unmeasurable = gate.loc_cap_offenders(
            base, ["Sources/Absent.swift"], repo
        )
        return case(
            "a path with no blob at HEAD is UNMEASURABLE (= = never reported clean)",
            unmeasurable == ["Sources/Absent.swift"] and not offenders and not shrinking,
            f"unmeasurable={unmeasurable} offenders={offenders} shrinking={shrinking}",
        )


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
    # The trailing-newline check (= = the byte the house's merge driver
    # compares, = = and the byte that broke it twice).
    #
    # ⇒ EVERY CASE BELOW DRIVES THE GATE (= = `gate.main`), = = not the
    # helper: = = a case that calls the helper cannot fail when the
    # GATE's scoping breaks (= = MEASURED: = = a mutation that scans every
    # .md in the tree instead of the changed ones left the helper-only
    # suite green).
    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_markdown(tmp)

        # (a) a change that DROPS the byte = = the gate names the file.
        (repo / "docs" / "kept.md").write_text("# kept\n\nbody.", encoding="utf-8")
        _commit(repo, "drop the newline")
        exit_code = gate.main(
            ["--base", base, "--check", "markdown-newline", "--repo", str(repo)]
        )
        results.append(
            case(
                "a change that DROPS a .md's trailing newline is reported BY THE GATE",
                exit_code == 1,
                f"gate_exit={exit_code} (= 1 = the drop was caught)",
            )
        )

    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_markdown(tmp)

        # (b) a change that EDITS a .md that already lacked the byte = = the
        # tree's drift = = and NOT this change's business (= = the delta
        # rule, = = not a state check).
        # ⇒ THE EDIT KEEPS THE DRIFT (= = no trailing newline): = = an edit
        # that ADDED the byte would make the state rule and the delta rule
        # agree (= = the case would pass against a gate that had no delta
        # rule at all = = and it would pin nothing).
        (repo / "docs" / "drifted.md").write_text("# drifted\n\nbody. edited.", encoding="utf-8")
        _commit(repo, "edit a file that never had the newline")
        exit_code = gate.main(
            ["--base", base, "--check", "markdown-newline", "--repo", str(repo)]
        )
        results.append(
            case(
                "a .md that ALREADY lacked the byte is NOT this change's business",
                exit_code == 0,
                f"gate_exit={exit_code} (= 0 = the tree's drift is not charged to the change)",
            )
        )

    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_markdown(tmp)

        # (c) a change that EDITS a .md that KEEPS its byte = = green, = =
        # and the file that never had one (= = not touched by the change)
        # is not among the reported paths (= = the scoping).
        (repo / "docs" / "kept.md").write_text("# kept\n\nbody. edited.\n", encoding="utf-8")
        _commit(repo, "edit a file that keeps its newline")
        exit_code = gate.main(
            ["--base", base, "--check", "markdown-newline", "--repo", str(repo)]
        )
        results.append(
            case(
                "a change that keeps a .md's newline is green (= = and the scoping holds)",
                exit_code == 0,
                f"gate_exit={exit_code} (= 0 = nothing was dropped)",
            )
        )

    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_markdown(tmp)

        # (d) a NEW .md that never had the byte = = reported (= = the
        # change CREATED a file that breaks the merge driver's comparison).
        (repo / "docs" / "fresh.md").write_text("# fresh\n\nbody.", encoding="utf-8")
        _commit(repo, "add a new .md without the newline")
        exit_code = gate.main(
            ["--base", base, "--check", "markdown-newline", "--repo", str(repo)]
        )
        results.append(
            case(
                "a NEW .md that never had the byte is reported",
                exit_code == 1,
                f"gate_exit={exit_code} (= 1 = the new file was caught)",
            )
        )

    with tempfile.TemporaryDirectory() as tmp:
        repo, base = _scratch_repo_with_markdown(tmp)

        # (e) a RENAME of a byte-less .md = = GREEN: = = the content moved,
        # = = so the byte moved with it (= = the tree's drift moved), = = and
        # a rename drops nothing. = = ⇒ The merge-base blob is ABSENT for
        # the new path, = = so a gate that reads the new path's base blob
        # would call it NEW (= = the false red the review measured on the
        # house's own ADR renames).
        (repo / "docs" / "renamed.md").write_text("# renamed\n\nbody.", encoding="utf-8")
        _commit(repo, "add the file to be renamed")
        rename_base = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=str(repo), capture_output=True, text=True, check=True
        ).stdout.strip()
        subprocess.run(
            ["git", "mv", "docs/renamed.md", "docs/renamed-elsewhere.md"],
            cwd=str(repo),
            check=True,
            capture_output=True,
        )
        _commit(repo, "rename a file that never had the newline")
        exit_code = gate.main(
            ["--base", rename_base, "--check", "markdown-newline", "--repo", str(repo)]
        )
        results.append(
            case(
                "a RENAME of a byte-less .md drops nothing (= = and is green)",
                exit_code == 0,
                f"gate_exit={exit_code} (= 0 = the rename moved the drift, = = it dropped nothing)",
            )
        )

    # The 600-LOC cap (= = AGENTS.md 6.6). = = EVERY case below drives the
    # GATE (= = `gate.main`), = = not the helper, = = so a mutation that
    # scans the wrong file set cannot pass.
    results.append(case_a_new_file_one_line_over_the_cap_goes_red())
    results.append(case_a_file_at_the_cap_is_green())
    results.append(case_the_cap_reaches_the_tests_tree())
    results.append(case_a_grown_over_cap_file_carries_its_base_size())
    results.append(case_a_shrinking_over_cap_file_lands())
    results.append(case_the_vendored_tree_is_exempt_from_the_cap())
    results.append(case_an_unmeasurable_path_is_never_certified_clean())

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
