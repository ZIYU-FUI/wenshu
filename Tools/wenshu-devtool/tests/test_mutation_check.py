#!/usr/bin/env python3
"""test_mutation_check.py — the mutation checker's own test suite.

The checker runs a suite against a COPY of a tree, so the cases build a
FIXTURE tree: a tiny package with a guarded file and a test that guards it.

The cases are the ways the checker can be wrong:

  1. a control run on a green suite exits 3 (= the control only) and says so.
  2. a mutation that the guard DOES catch exits 0 and says the suite bit.
  3. a mutation that the guard does NOT catch exits 1 and says so (= the
     guard is empty, and this tool must be able to say that).
  4. a suite that is already red exits 2 (= no verdict).
  5. a mutation whose text is not in the guarded file exits 2 with a
     message naming the file (= not a silent pass).
  6. a guarded file outside the suite's package directory exits 2 with a
     message (= the reviewer found this: it raised an unhandled ValueError).
  7. the control's exit code differs from "the suite bit", so a caller
     gating on it cannot read the control as a proven bite.

Run:  python3 Tools/wenshu-devtool/tests/test_mutation_check.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import io
import contextlib
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "mutation_check.py"

spec = importlib.util.spec_from_file_location("mutation_check", TOOL)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

FAILURES: list[str] = []

# The guarded file's logic, and the test that guards it. The test asserts on
# the PRINTED output (= it reads the guarded file and checks the string), so
# reverting the guarded file's return makes the test RED.
GUARDED = '''def decide(value: int) -> str:
    if value > 0:
        return "positive"
    return "not positive"
'''

TEST = '''import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from guarded import decide

out = decide(1)
if out != "positive":
    print(f"FAIL the tool printed {out!r}")
    sys.exit(1)
print("ok: the guard holds")
'''


def check(name: str, got, want) -> None:
    if got == want:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        FAILURES.append(name)


def make_tree(root: Path) -> tuple[Path, Path]:
    """A fixture package: a guarded file and the test that guards it."""
    pkg = root / "pkg"
    pkg.mkdir(parents=True)
    guarded = pkg / "guarded.py"
    guarded.write_text(GUARDED)
    tests = pkg / "tests"
    tests.mkdir()
    test = tests / "test_guarded.py"
    test.write_text(TEST)
    return guarded, test


def run_tool(guarded: Path, test: Path, *extra: str) -> tuple[int, str]:
    argv = ["mutation_check.py", "--suite", str(test), "--guard", str(guarded), *extra]
    saved = sys.argv
    sys.argv = argv
    out = io.StringIO()
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = mod.main()
    finally:
        sys.argv = saved
    return code, out.getvalue()


def case_1_the_control_exits_with_its_own_code() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        guarded, test = make_tree(Path(tmp))
        code, out = run_tool(guarded, test, "--control")
        check("the control exits 3 (= not a proven bite)", code, 3)
        check("it says CONTROL ONLY", "CONTROL ONLY" in out, True)
        check("it shows the suite is green", "GREEN" in out.upper(), True)


def case_2_a_mutation_the_guard_catches_exits_zero() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        guarded, test = make_tree(Path(tmp))
        code, out = run_tool(
            guarded, test,
            "--mutate", 'return "positive"',
            "--replace", 'return "WRONG"',
        )
        check("exit 0", code, 0)
        check("it says the suite bit", "THE SUITE BIT" in out, True)


def case_3_a_mutation_the_guard_misses_exits_one() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        guarded, test = make_tree(Path(tmp))
        # The test does not read this line, so the mutation changes nothing
        # the suite can see.
        code, out = run_tool(
            guarded, test,
            "--mutate", 'def decide(value: int) -> str:',
            "--replace", 'def decide(value: int) -> str:  # touched',
        )
        check("exit 1", code, 1)
        check("it says the suite did not bite", "DID NOT BITE" in out, True)


def case_4_a_suite_that_is_already_red_exits_two() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        guarded, test = make_tree(Path(tmp))
        test.write_text("import sys\nsys.exit(1)\n")
        code, out = run_tool(guarded, test, "--control")
        check("exit 2", code, 2)
        check("it says there is no verdict", "no verdict" in out, True)


def case_5_a_mutation_text_that_is_not_there_exits_two() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        guarded, test = make_tree(Path(tmp))
        code, out = run_tool(
            guarded, test,
            "--mutate", "this text is not in the file",
            "--replace", "neither is this",
        )
        check("exit 2", code, 2)
        check("it names the file", "guarded.py" in out, True)


def case_6_a_guarded_file_outside_the_package_exits_two() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        guarded, test = make_tree(Path(tmp) / "pkg")
        outside = Path(tmp) / "elsewhere.py"
        outside.write_text(GUARDED)
        code, out = run_tool(outside, test, "--control")
        check("exit 2", code, 2)
        check("it explains why", "outside" in out, True)


def case_7_the_control_code_differs_from_the_bite_code() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        guarded, test = make_tree(Path(tmp))
        control, _ = run_tool(guarded, test, "--control")
        bite, _ = run_tool(
            guarded, test,
            "--mutate", 'return "positive"',
            "--replace", 'return "WRONG"',
        )
        check("the control is not the bite", control != bite, True)


def main() -> int:
    cases = [
        case_1_the_control_exits_with_its_own_code,
        case_2_a_mutation_the_guard_catches_exits_zero,
        case_3_a_mutation_the_guard_misses_exits_one,
        case_4_a_suite_that_is_already_red_exits_two,
        case_5_a_mutation_text_that_is_not_there_exits_two,
        case_6_a_guarded_file_outside_the_package_exits_two,
        case_7_the_control_code_differs_from_the_bite_code,
    ]
    for case in cases:
        print(f"== {case.__name__}")
        case()
    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s): {', '.join(FAILURES)}")
        return 1
    print(f"ok: {len(cases)} cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
