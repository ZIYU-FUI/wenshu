#!/usr/bin/env python3
"""test_measure_drill.py — the measure-drill detector's own test suite.

Every case runs on a FIXTURE written to a temporary directory, so the
tests stay valid when the real app tree changes.

The five cases are the five things the naive detector got wrong:

  1. a parameter that is declared, assigned in the initializer and never
     read => DEAD.
  2. a parameter that is read in the view's body => alive.
  3. a parameter that is read ONLY from an extension of the same type in
     the same file => alive. (This case killed two of the audit's own
     findings: EditorFormatToolbar.onClose and PreviewPane.onDoubleClick.)
  4. a type name that appears only in a comment or a string literal =>
     not a use of that name.
  5. a view struct with an explicit init(...) => the parameters counted
     are the initializer's, not the stored properties'.

Run:  python3 Tools/wenshu-devtool/tests/test_measure_drill.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "measure-drill.py"


def load_tool():
    """Import measure-drill.py as a module, whatever its directory is."""
    spec = importlib.util.spec_from_file_location("measure_drill", TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def dead_names(tool, files: dict) -> set:
    """The dead-parameter names the tool reports for a fixture tree.

    files maps a repo-relative path to its Swift source. The tree is
    written to a temporary directory, because the tool walks a real
    directory.
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for rel, source in files.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(source, encoding="utf-8")
        report = tool.analyze(str(root))
        return {entry["param"] for entry in report["dead"]}


def heaviest(tool, files: dict) -> dict:
    """The heaviest-initializers table, as {type name: argument count}."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for rel, source in files.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(source, encoding="utf-8")
        report = tool.analyze(str(root))
        return {site["type"]: site["args"] for site in report["sites"]}


# --------------------------------------------------------------- fixtures

DEAD = """
import SwiftUI

struct LonelyView: View {
    let payload: String
    let count: Int

    var body: some View {
        Text("nothing")
    }
}
"""

ALIVE_IN_BODY = """
import SwiftUI

struct ReadView: View {
    let payload: String
    let count: Int

    var body: some View {
        Text("\\(payload) \\(count)")
    }
}
"""

ALIVE_IN_EXTENSION = """
import SwiftUI

struct ExtendedView: View {
    let payload: String
    let count: Int

    var body: some View {
        Text("\\(payload)")
    }
}

extension ExtendedView {
    var doubled: Int { count * 2 }
}
"""

NAME_IN_COMMENT_AND_STRING = """
import SwiftUI

struct CommentedView: View {
    let payload: String

    var body: some View {
        // HelperView(payload: payload)
        Text("HelperView(payload: \\"other\\")")
    }
}
"""
EXPLICIT_INIT = """
import SwiftUI

struct ExplicitView: View {
    let payload: String
    let count: Int

    init(payload: String, count: Int) {
        self.payload = payload
        self.count = count
    }

    var body: some View {
        Text("\\(payload)")
    }
}
"""

EXPLICIT_INIT_EXTRA_STORED = """
import SwiftUI

struct MixedView: View {
    let payload: String
    let count: Int
    let ignored: String

    init(payload: String, count: Int) {
        self.payload = payload
        self.count = count
        self.ignored = ""
    }

    var body: some View {
        Text("\\(payload)")
    }
}

struct MixedCaller: View {
    var body: some View {
        MixedView(payload: "x", count: 1)
    }
}
"""


# ------------------------------------------------------------------ cases

def case_1_unread_parameter_is_dead(tool):
    """A parameter that is never read is dead."""
    names = dead_names(tool, {"LonelyView.swift": DEAD})
    return (
        "payload" in names and "count" in names,
        f"expected payload and count to be dead, got {sorted(names)}",
    )


def case_2_parameter_read_in_body_is_alive(tool):
    """A parameter read in the body is alive."""
    names = dead_names(tool, {"ReadView.swift": ALIVE_IN_BODY})
    return (
        not names,
        f"expected no dead parameters, got {sorted(names)}",
    )


def case_3_parameter_read_in_extension_is_alive(tool):
    """A parameter read only from an extension in the same file is alive.

    This is the case that produced two false positives in the first
    detector: EditorFormatToolbar.onClose and PreviewPane.onDoubleClick.
    """
    names = dead_names(tool, {"ExtendedView.swift": ALIVE_IN_EXTENSION})
    return (
        not names,
        f"expected no dead parameters, got {sorted(names)}",
    )


def case_4_name_in_comment_or_string_is_not_a_use(tool):
    """A name that appears only in a comment or a string is not a use.

    So the parameter is UNREAD, and an unread parameter is dead. The
    point of the case is the direction: if the detector counted the
    comment or the string as a use, this parameter would come out alive.
    """
    names = dead_names(tool, {"CommentedView.swift": NAME_IN_COMMENT_AND_STRING})
    return (
        "payload" in names,
        f"expected payload to be dead (its only mentions are a comment and a string), got {sorted(names)}",
    )


def case_5_explicit_init_wins_over_stored_properties(tool):
    """With an explicit init, its parameters are the counted ones.

    'ignored' is a stored property that the initializer never takes, so
    it is NOT a parameter of this type and must not be counted.
    """
    sites = heaviest(tool, {"MixedView.swift": EXPLICIT_INIT_EXTRA_STORED})
    count = sites.get("MixedView")
    ok = count == 2
    return (
        ok,
        f"expected MixedView to take 2 arguments, got {count}",
    )


CASES = [
    ("unread parameter is dead", case_1_unread_parameter_is_dead),
    ("parameter read in body is alive", case_2_parameter_read_in_body_is_alive),
    ("parameter read in an extension is alive", case_3_parameter_read_in_extension_is_alive),
    ("name in a comment or string is not a use", case_4_name_in_comment_or_string_is_not_a_use),
    ("explicit init wins over stored properties", case_5_explicit_init_wins_over_stored_properties),
]


def main() -> int:
    tool = load_tool()
    passed = 0
    failed = 0
    for name, case in CASES:
        try:
            ok, detail = case(tool)
        except Exception as exc:  # a case that raises is a failure, not a crash
            ok, detail = False, f"raised {type(exc).__name__}: {exc}"
        if ok:
            passed += 1
            print(f"PASS  {name}")
        else:
            failed += 1
            print(f"FAIL  {name}: {detail}")
    print(f"{passed} passed, {failed} failed, {len(CASES)} total")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
