#!/usr/bin/env python3
"""test_run_suites.py — the battery's OWN exit code, tested on a fixture directory.

`run-suites.sh` prints one honest rc per suite. Its first version still exited 0 no matter
what those lines said, because the last statement in the file was a `printf`. A gate that
cannot go red is not a gate, so this suite tests the aggregation rather than the printouts:

  1. every suite green  -> exit 0, and the summary counts what ran.
  2. a suite red        -> exit 1, and the summary names the red count.
  3. the per-line rc    -> is the SUITE's status (44), not the printer's (0).
  4. a known-red suite  -> exit 0, counted separately, line marked.
  5. NO suite matched   -> exit non-zero: nothing was measured is not a pass.
  6. the index range    -> `from`/`to` select exactly the suites they name.
  7. the baseline file  -> a static check that it lists names which exist as suites.
  8. a STALE baseline   -> the battery itself exits 93, and a window does not fake that.

Run:  python3 Tools/wenshu-devtool/tests/test_run_suites.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "run-suites.sh"
BASELINE = HERE / "known-red.txt"
REPO_ROOT = HERE.parent.parent.parent

FAKE = "import sys\nsys.exit({code})\n"


def run(glob: str, *args: str, baseline: str | None = None) -> tuple[int, str]:
    env = dict(os.environ)
    env["RUN_SUITES_GLOB"] = glob
    env["RUN_SUITES_BASELINE"] = baseline if baseline is not None else str(BASELINE)
    proc = subprocess.run(
        ["bash", str(SCRIPT), *args], capture_output=True, text=True, env=env, cwd=REPO_ROOT
    )
    return proc.returncode, proc.stdout


def fixture(dirpath: Path, codes: dict[str, int]) -> str:
    for name, code in sorted(codes.items()):
        (dirpath / f"test_{name}.py").write_text(FAKE.format(code=code), encoding="utf-8")
    return f"{dirpath}/test_*.py"


def check(label: str, ok: bool, detail: str = "") -> bool:
    print(f"{'PASS' if ok else 'FAIL'} {label}" + ("" if ok else f"  {detail}"))
    return ok


def main() -> int:
    failures = 0
    with tempfile.TemporaryDirectory() as td:
        tdp = Path(td)
        # A register with no live entries. Every case passes it explicitly on purpose: the real
        # known-red.txt beside this script names the REAL suites, and case 8 is exactly what
        # happens when a register names suites the run cannot find — so a case that leaned on the
        # default would exit 93 for a reason it is not testing.
        blank = tdp / "blank-known-red.txt"
        blank.write_text("# no live entries\n", encoding="utf-8")

        # 1. all green
        gdir = tdp / "green"
        gdir.mkdir()
        g = fixture(gdir, {"aaa": 0, "bbb": 0})
        rc, out = run(g, baseline=str(blank))
        failures += not check("1 all-green exits 0", rc == 0, f"rc={rc}\n{out}")
        failures += not check("1 summary counts the suites", "suites=2 red=0" in out, out)

        # 2 + 3. a red suite, and the rc it prints is its own
        rdir = tdp / "red"
        rdir.mkdir()
        r = fixture(rdir, {"aaa": 0, "bbb": 44})
        rc, out = run(r, baseline=str(blank))
        failures += not check("2 a red suite fails the battery", rc == 1, f"rc={rc}\n{out}")
        failures += not check("2 summary names one red", "red=1" in out, out)
        failures += not check("3 the line carries the suite's own rc", "test_bbb rc=44" in out, out)

        # 4. a known red is counted, not hidden, and does not fail the battery
        bdir = tdp / "base"
        bdir.mkdir()
        b = fixture(bdir, {"aaa": 1})
        bfile = tdp / "known-red.txt"
        bfile.write_text("# a comment only\n\ntest_aaa   # trailing comment\n", encoding="utf-8")
        rc, out = run(b, baseline=str(bfile))
        failures += not check("4 a known-red suite exits 0", rc == 0, f"rc={rc}\n{out}")
        failures += not check("4 it stays visible in the line", "known-red" in out, out)
        failures += not check("4 and in the summary", "red=0 known-red=1" in out, out)

        # 4b. a name the baseline does NOT carry still fails
        rc, out = run(b, baseline=str(tdp / "absent.txt"))
        failures += not check("4b an unlisted red fails", rc != 0, f"rc={rc}\n{out}")

        # 5. no suite matched is not a pass (and 92 is what the card says it is)
        edir = tdp / "empty"
        edir.mkdir()
        rc, out = run(f"{edir}/test_*.py", baseline=str(blank))
        failures += not check("5 an empty battery exits 92", rc == 92, f"rc={rc}\n{out}")
        failures += not check("5 and says it measured nothing", "no suite matched" in out, out)

        # 6. the index range selects exactly one suite
        rc, out = run(g, "2", "2", baseline=str(blank))
        picked = [ln for ln in out.splitlines() if ln.startswith("test_")]
        failures += not check("6 from/to select one suite", picked == ["test_bbb rc=0"], f"{picked}\n{out}")

        # 8. the BATTERY's exit code, not a suite-level check: a register entry that forgives no
        #    suite is an empty baseline wearing a name, so the run must not be allowed to pass.
        sdir = tdp / "stale"
        sdir.mkdir()
        s = fixture(sdir, {"aaa": 0})
        sfile = tdp / "stale-known-red.txt"
        sfile.write_text("test_aaa\ntest_ghost   # renamed away\n", encoding="utf-8")
        rc, out = run(s, baseline=str(sfile))
        failures += not check("8 a stale register entry exits 93", rc == 93, f"rc={rc}\n{out}")
        failures += not check("8 and names the entry", "test_ghost" in out, out)

        # 8b. a window that runs one suite must not make the register's other entries look stale
        wfile = tdp / "ok-known-red.txt"
        wfile.write_text("test_aaa\n", encoding="utf-8")
        rc, out = run(s, "1", "1", baseline=str(wfile))
        failures += not check("8b a window does not trip the stale check", rc == 0, f"rc={rc}\n{out}")

    # 7. the real baseline file must name suites that exist, or it enforces nothing
    if BASELINE.is_file():
        names = set()
        for line in BASELINE.read_text(encoding="utf-8").splitlines():
            token = re.sub(r"#.*", "", line).strip()
            if token:
                names.add(token)
        present = {p.stem for p in (REPO_ROOT / "Tools/wenshu-devtool/tests").glob("test_*.py")}
        stale = sorted(names - present)
        failures += not check(
            "7 known-red.txt names existing suites", not stale, f"stale: {stale}"
        )
    else:
        failures += not check("7 known-red.txt exists", False, str(BASELINE))

    print("OK" if failures == 0 else f"{failures} case(s) failed")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
