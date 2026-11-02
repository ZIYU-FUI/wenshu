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
import json
import subprocess
import os
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

    # 2. a file above the loader's cap is an error.
    #    The cap applies to the file AS THE LOADER READS IT (= the whole
    #    file, frontmatter included, plus the "## AGENTS.md" label), not
    #    to the body alone. A body-only budget passes a file the loader
    #    cuts in the middle.
    # The file must be over the cap THE GATE NOW USES (= the cap its own
    # home's config pins), not over a number written down here: a hard
    # 20,000 stops being "over the cap" the moment the cap moves, and the
    # case then passes for the wrong reason (= it checks a file the gate
    # accepts).
    cap = ag.effective_context_file_cap()[0]
    huge = good_body() + ("\n" + ("x" * 500) + "\n") * ((cap // 501) + 2)
    r = check(huge)
    results.append(
        case(
            "a file above the loader cap is an error",
            has_error(r, "truncates above"),
            "; ".join(r["errors"][:3]),
        )
    )

    # 2b. the budget counts the frontmatter, so a file whose BODY fits but
    #     whose whole file does not is still an error.
    #     a frontmatter big enough to push the WHOLE file over the cap
    #     while its body alone stays under it.
    long_front = FRONT + ("#" * 200 + "\n") * ((cap // 201) + 2)
    r = check(good_body(), front=long_front)
    results.append(
        case(
            "the budget counts the frontmatter too",
            has_error(r, "truncates above") or has_error(r, "loads as"),
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

    # 13. the gate reads the pin with the LOADER's parser, so the two
    #     can never disagree about what a config pins. Measured
    #     2026-11-01: a DUPLICATE key (= the loader's parser REJECTS the
    #     file, and the loader falls back to its dynamic cap) was read by
    #     a regex as the FIRST match, so the gate said 500,000 where the
    #     loader said 49,152 = the gate was LOOSER than the loader, and it
    #     would accept a file the loader truncates in the middle (= the
    #     one failure this gate exists to prevent).
    #
    #     So the cases ask for the cap under a fixture HOME whose config
    #     carries each shape, and compare it with the LOADER's own answer.
    with tempfile.TemporaryDirectory() as tmp:
        _shape_no = [0, 0, 0, 0]

        def cap_under(config_text: str) -> int:
            # A FRESH home per shape: the loader keeps the LAST KNOWN GOOD
            # config for a home whose file breaks (= a duplicate key), so
            # a home reused across shapes would serve a cached answer and
            # the comparison would measure the cache, not the shape.
            home = Path(tmp) / f"home-{_shape_no[0]}"
            _shape_no[0] += 1
            home.mkdir()
            (home / "config.yaml").write_text(config_text, encoding="utf-8")
            previous = os.environ.get("HERMES_HOME")
            os.environ["HERMES_HOME"] = str(home)
            try:
                return ag.effective_context_file_cap()[0]
            finally:
                if previous is None:
                    os.environ.pop("HERMES_HOME", None)
                else:
                    os.environ["HERMES_HOME"] = previous

        def loader_cap_under(config_text: str,
                             interpreter: str | None = None) -> int | None:
            """The LOADER's own answer for that config (= its oracle).

            In ONE interpreter, so the oracle and the gate under test are
            the same pair of programs. Measured 2026-11-01: the oracle
            looped over the interpreters and returned the FIRST that
            worked, so every comparison used interpreter #1's answer
            while the gate ran elsewhere: the stated method was not the
            implemented one.
            """
            home = Path(tmp) / f"loader-home-{_shape_no[1]}"
            _shape_no[1] += 1
            home.mkdir()
            (home / "config.yaml").write_text(config_text, encoding="utf-8")
            script = (
                "import sys,json;"
                "roots=json.loads(sys.argv[1]);"
                "[sys.path.insert(0,r) for r in roots];"
                "from agent.prompt_builder import _get_context_file_max_chars;"
                "print(_get_context_file_max_chars(204800))"
            )
            roots = ag._hermes_source_roots()
            candidates = (
                [interpreter] if interpreter else list(ag._hermes_pythons())
            )
            for candidate in candidates:
                previous = os.environ.get("HERMES_HOME")
                os.environ["HERMES_HOME"] = str(home)
                try:
                    proc = subprocess.run(
                        [candidate, "-c", script, json.dumps(roots)],
                        capture_output=True, text=True, timeout=120,
                    )
                except (OSError, subprocess.SubprocessError):
                    continue
                finally:
                    if previous is None:
                        os.environ.pop("HERMES_HOME", None)
                    else:
                        os.environ["HERMES_HOME"] = previous
                if proc.returncode == 0:
                    try:
                        return int(proc.stdout.strip().splitlines()[-1])
                    except (ValueError, IndexError):
                        continue
            return None

        # The gate's reader is a CHAIN over the interpreters it finds, so
        # the case runs in EVERY one of them: an interpreter with a LAX
        # yaml parser installed answers a duplicate key where the loader
        # refuses it, and that interpreter is the one that would carry
        # the fail-open. Measured 2026-11-01: the third interpreter in
        # the gate's own search path has PyYAML 6.0.3.
        def gate_cap_in(interpreter: str, config_text: str) -> int | None:
            home = Path(tmp) / f"gate-home-{_shape_no[2]}"
            _shape_no[2] += 1
            home.mkdir()
            (home / "config.yaml").write_text(config_text, encoding="utf-8")
            # The gate comes from THE TREE UNDER TEST (= this file's own
            # directory), never from a hardcoded path to another checkout.
            # Measured 2026-11-01: a hardcoded path made the case measure
            # whatever sat at that path at run time, so the suite measured
            # TWO files and the split was invisible in the output. And the
            # landing flow runs the gates on a branch while main still
            # holds the old copy, so a branch that reintroduced a defect
            # landed green.
            script = (
                "import sys;sys.path.insert(0," + repr(str(TOOL.parent)) + ");"
                "import agents_gate as ag;"
                "print(ag.effective_context_file_cap()[0])"
            )
            previous = os.environ.get("HERMES_HOME")
            os.environ["HERMES_HOME"] = str(home)
            try:
                proc = subprocess.run(
                    [interpreter, "-c", script],
                    capture_output=True, text=True, timeout=120,
                )
            except (OSError, subprocess.SubprocessError):
                return None
            finally:
                if previous is None:
                    os.environ.pop("HERMES_HOME", None)
                else:
                    os.environ["HERMES_HOME"] = previous
            if proc.returncode != 0:
                return None
            try:
                return int(proc.stdout.strip().splitlines()[-1])
            except (ValueError, IndexError):
                return None

        shapes = (
            ("a plain pin", "context_file_max_chars: 500000\n"),
            ("a pin with a trailing comment",
             "context_file_max_chars: 500000  # a comment\n"),
            ("a DUPLICATE key (= the loader rejects the file)",
             "context_file_max_chars: 500000\ncontext_file_max_chars: 400000\n"),
            ("a quoted pin (= the loader ignores a string)",
             "context_file_max_chars: '500000'\n"),
            ("a pin of zero (= the loader rejects it)",
             "context_file_max_chars: 0\n"),
            ("a config that is not a mapping", "not: a mapping\n"),
        )
        for label, config_text in shapes:
            gate_cap = cap_under(config_text)
            loader_cap = loader_cap_under(config_text)
            results.append(
                case(
                    f"the gate and the loader agree on {label}",
                    loader_cap is not None and gate_cap == loader_cap,
                    f"the gate says {gate_cap}, the loader says {loader_cap}",
                )
            )

        # THE SUBPROCESS FALLBACK, WHICH EVERY OTHER CASE MISSES.
        #
        # The gate's reader has two branches: it asks the loader's
        # package IN-PROCESS when that package is importable, and it
        # falls back to a SUBPROCESS when it is not. Every interpreter
        # the gate would use can import that package, so every case
        # above ran the IN-PROCESS branch, and the subprocess branch was
        # NEVER EXERCISED = a defect in it was invisible.
        #
        # Measured 2026-11-01: with the subprocess branch restored to
        # fall through to a lax parser, the suite stayed 116/116 green
        # (= the fail-open was not caught), while the same gate under
        # `python3 -E -s` (= the loader's package NOT importable, so the
        # subprocess branch IS taken) answered 400,000 where the loader
        # answers 49,152.
        #
        # So the case runs the gate with the loader's package made
        # unimportable, and compares with the loader's own answer.
        # An interpreter where the loader's package is NOT importable,
        # so the reader's SUBPROCESS link is the one that must answer.
        #
        # Measured 2026-11-02: `-E -s` does NOT do it (= a venv python
        # has the package on its own path), but `-S -E` with PYTHONPATH
        # cleared does, in EVERY interpreter the gate would use (= `-S`
        # skips every site-packages, and the package is otherwise only
        # reachable through PYTHONPATH).
        #
        # So the case PROVES the precondition and ASSERTS the link the
        # reader names: a case that can pass while the branch it names
        # was never exercised is the failure mode this commit ends.
        subprocess_interpreter = sys.executable
        precondition = subprocess.run(
            [subprocess_interpreter, "-S", "-E", "-c", "import hermes_cli.config"],
            capture_output=True, text=True, timeout=60,
            env={k: v for k, v in os.environ.items() if k != "PYTHONPATH"},
        )
        results.append(
            case(
                "the reader's SUBPROCESS link is reachable (= the loader's "
                "package is unimportable under the interpreter the case uses)",
                precondition.returncode != 0,
                f"importing the loader's package returned {precondition.returncode} "
                f"(0 means it IS importable = the in-process link would answer)",
            )
        )

        def gate_cap_without_the_package(
            config_text: str,
        ) -> tuple[int | None, str | None]:
            home = Path(tmp) / f"subproc-home-{_shape_no[3]}"
            _shape_no[3] += 1
            home.mkdir()
            (home / "config.yaml").write_text(config_text, encoding="utf-8")
            # The child reports BOTH the cap the gate would use AND the
            # link the reader answered on (= so the case can require the
            # subprocess link, and cannot pass while the in-process link
            # answered it).
            script = (
                "import os,sys;sys.path.insert(0," + repr(str(TOOL.parent)) + ");"
                "import agents_gate as ag;"
                "cap,reason=ag.effective_context_file_cap();"
                "text=open(os.path.join(os.environ['HERMES_HOME'],'config.yaml'),"
                "encoding='utf-8').read();"
                "value,link=ag._config_as_the_loader_reads(text);"
                "print(cap);print(link)"
            )
            if subprocess_interpreter is None:
                return None, None
            previous = os.environ.get("HERMES_HOME")
            os.environ["HERMES_HOME"] = str(home)
            try:
                proc = subprocess.run(
                    [subprocess_interpreter, "-S", "-E", "-c", script],
                    capture_output=True, text=True, timeout=120,
                    env={k: v for k, v in os.environ.items() if k != "PYTHONPATH"},
                )
            except (OSError, subprocess.SubprocessError):
                return None, None
            finally:
                if previous is None:
                    os.environ.pop("HERMES_HOME", None)
                else:
                    os.environ["HERMES_HOME"] = previous
            if proc.returncode != 0:
                return None, None
            lines = proc.stdout.strip().splitlines()
            if len(lines) < 2:
                return None, None
            try:
                return int(lines[-2]), lines[-1].strip()
            except ValueError:
                return None, None

        for label, config_text in shapes:
            gate_cap, branch = gate_cap_without_the_package(config_text)
            loader_cap = loader_cap_under(config_text)
            results.append(
                case(
                    f"the gate's SUBPROCESS branch and the loader agree "
                    f"on {label}",
                    # The branch is ASSERTED, so the case cannot pass
                    # while the branch it names was never exercised.
                    branch in ("subprocess", "rejected-subprocess")
                    and loader_cap is not None
                    and gate_cap == loader_cap,
                    f"the gate says {gate_cap} on the {branch} branch, "
                    f"the loader says {loader_cap}",
                )
            )

        # And in EVERY interpreter the gate would use, because the gate
        # picks one at runtime and a LAX yaml parser in one of them
        # answers a duplicate key where the loader refuses it.
        interpreters = sorted(set(ag._hermes_pythons()))
        for interpreter in interpreters:
            for label, config_text in shapes:
                gate_cap = gate_cap_in(interpreter, config_text)
                loader_cap = loader_cap_under(config_text, interpreter)
                results.append(
                    case(
                        f"the gate and the loader agree on {label} in "
                        f"{Path(interpreter).parent.parent.name}",
                        loader_cap is not None and gate_cap == loader_cap,
                        f"the gate says {gate_cap}, the loader says "
                        f"{loader_cap}",
                    )
                )

    passed = sum(1 for r_ in results if r_)
    print(f"\n{passed}/{len(results)} cases passed")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
