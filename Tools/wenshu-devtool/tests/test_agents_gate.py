#!/usr/bin/env python3
"""test_agents_gate.py — the AGENTS.md contract gate's own test suite.

Every case runs on a FIXTURE AGENTS.md written to a temporary file, so the
tests stay valid when the real file changes.

The cases are the ways this file can rot, each one measured on the file
that stood before this gate landed (2026-10-27):

  1. the real AGENTS.md passes (= the gate does not block a good file).
  2. a body above the loader's cap is an error (= the tail is not loaded).
  3. a path that does not exist is an error (= the false guarantee).
  4. a skill that is not installed is an error (= the phantom skill).
  5. CJK outside the vocabulary rows is an error (= the hidden CJK).
  6. CJK in rows 1.3 / 1.4 is allowed (= the rule that names the vocabulary
     must be able to name it).
  7. a non-contiguous rule id is an error (= the reader cannot order them).
  8. a duplicated row id is an error (= one rule stated twice).
  9. a section reference that resolves to nothing is an error.
 10. a missing required section is an error (= §1 / §7 / §8 / §10).
 11. frontmatter without name / version / description is an error.
 12. a backticked path inside a fenced block is NOT checked (= the block is
     an example, not a reference).

Run:  python3 Tools/wenshu-devtool/tests/test_agents_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "agents_gate.py"
REPO = TOOL.parent.parent.parent

spec = importlib.util.spec_from_file_location("agents_gate", TOOL)
assert spec is not None and spec.loader is not None
ag = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ag)

FRONT = """---
name: fixture
description: A fixture AGENTS.md for the gate's own test suite.
version: 1.0.0
---
"""


def fixture(body: str, front: str = FRONT) -> str:
    """A whole file: frontmatter + body."""
    return front + "\n" + body


# The banned family comes from commit_filter.py (= the repo's enforcement
# SSOT for it), so this test file names no policed token itself: a test
# that spelled the vocabulary out would need the CI pollution check to
# exclude it, and the list would be a second copy to drift.
sys.path.insert(0, str(TOOL.parent))
from commit_filter import FORBIDDEN_TOKENS as _BANNED  # noqa: E402

BANNED = " / ".join(_BANNED[:2])


def good_body() -> str:
    """A body that satisfies every check the gate makes."""
    return f"""# AGENTS.md — fixture

## §1 Rules

| #   | Rule | Enforcement |
| --- | ---- | ----------- |
| 1.1 | A rule with a real reference. | `docs/agents/nfi.md`. |
| 1.2 | A rule that names the vocabulary. | Manual. |
| 1.3 | Forbidden hedges: 可 / 应当. | Manual. |
| 1.4 | Forbidden xianxia vocabulary: {BANNED}. | commit_filter.py. |

## §7 Gates

| #   | Gate | Reference |
| --- | ---- | --------- |
| 7.1 | A gate. | `Tools/wenshu-devtool/verify-dead.py`. |

## §8 Workflow

| #   | Step | Skill |
| --- | ---- | ----- |
| 8.1 | A step. | wenshu-pocock-workflow. |

## §10 Protocol

| #   | Rule |
| --- | ---- |
| 10.1 | A rule. |
"""


def check(body: str, front: str = FRONT) -> dict:
    """Run the gate on a fixture body written to a temp file."""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "AGENTS.md"
        path.write_text(fixture(body, front), encoding="utf-8")
        return ag.check_file(path)


def case(name: str, ok: bool, detail: str = "") -> bool:
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    if not ok and detail:
        print(f"      {detail}")
    return ok


def has_error(result: dict, needle: str) -> bool:
    """Whether an error mentions the given fragment."""
    return any(needle in err for err in result["errors"])


def main() -> int:
    results: list[bool] = []

    # 1. the real file passes.
    real = ag.check_file(REPO / "AGENTS.md")
    results.append(
        case(
            "the real AGENTS.md passes the gate",
            real["ok"],
            "; ".join(real["errors"][:4]),
        )
    )

    # 2. a body above the cap is an error.
    huge = good_body() + ("\n" + ("x" * 500) + "\n") * 60
    r = check(huge)
    results.append(
        case(
            "a body above the loader cap is an error",
            has_error(r, "truncates above"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 3. a path that does not exist is an error.
    r = check(good_body().replace("`docs/agents/nfi.md`", "`docs/agents/does-not-exist.md`"))
    results.append(
        case(
            "a path that does not exist is an error",
            has_error(r, "does not exist"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 4. a skill that is not installed is an error.
    r = check(good_body().replace("wenshu-pocock-workflow", "wenshu-not-a-real-skill"))
    results.append(
        case(
            "a skill that is not installed is an error",
            has_error(r, "not installed"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 5. CJK outside the vocabulary rows is an error.
    r = check(good_body().replace("A rule with a real reference.", "A rule with 中文 inside."))
    results.append(
        case(
            "CJK outside the vocabulary rows is an error",
            has_error(r, "CJK"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 6. CJK in rows 1.3 / 1.4 is allowed (= the fixture itself carries it).
    r = check(good_body())
    results.append(
        case(
            "CJK in rows 1.3 / 1.4 is allowed",
            not has_error(r, "CJK"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 7. a non-contiguous rule id is an error.
    r = check(good_body().replace("| 1.2 | A rule that names the vocabulary.", "| 1.4 | A rule that names the vocabulary."))
    results.append(
        case(
            "a non-contiguous rule id is an error",
            has_error(r, "contiguous") or has_error(r, "1.2") or not r["ok"],
            "; ".join(r["errors"][:3]),
        )
    )

    # 8. a duplicated row id is an error.
    r = check(good_body().replace("| 1.2 | A rule that names the vocabulary.", "| 1.1 | A rule that names the vocabulary."))
    results.append(
        case(
            "a duplicated row id is an error",
            not r["ok"],
            "; ".join(r["errors"][:3]),
        )
    )

    # 9. a section reference that resolves to nothing is an error.
    r = check(good_body() + "\nSee §42 for the rest.\n")
    results.append(
        case(
            "a section reference to nothing is an error",
            has_error(r, "42") or not r["ok"],
            "; ".join(r["errors"][:3]),
        )
    )

    # 10. a missing required section is an error.
    #     Renaming a heading keeps its section number (= still present), so the
    #     section has to go entirely for this to be an error.
    without_7 = good_body().replace("## §7 Gates", "## Gates")
    r = check(without_7)
    results.append(
        case(
            "a missing required section is an error",
            has_error(r, "§7 is missing"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 10b. renaming a section heading keeps it (= a heading is a heading).
    r = check(good_body().replace("## §7 Gates", "## §7 Renamed"))
    results.append(
        case(
            "renaming a section heading keeps the section",
            not has_error(r, "§7 is missing"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 11. frontmatter without the required keys is an error.
    r = check(good_body(), front="---\nname: fixture\n---\n")
    results.append(
        case(
            "frontmatter without name / version / description is an error",
            has_error(r, "version") or has_error(r, "description"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 12. a backticked path inside a fenced block is NOT checked.
    r = check(
        good_body()
        + "\n```bash\npython3 Tools/wenshu-devtool/not-a-real-tool.py\n```\n"
    )
    results.append(
        case(
            "a path inside a fenced block is not checked",
            not has_error(r, "not-a-real-tool.py"),
            "; ".join(r["errors"][:3]),
        )
    )

    passed = sum(1 for r_ in results if r_)
    print(f"\n{passed}/{len(results)} cases passed")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
