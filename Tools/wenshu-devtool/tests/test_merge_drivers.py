#!/usr/bin/env python3
"""test_merge_drivers.py — a fresh clone can wire its own merge drivers.

= = WHY THIS TEST EXISTS. = = A merge driver has two halves:
`.gitattributes` NAMES it (= tracked, so it travels with the clone) and
`.git/config` DEFINES it (= local, so it does NOT). Only the first half
ships, and git does not report the gap: when `merge=<name>` names a
driver git cannot find, git falls back to its built-in text merge and
prints nothing.

So a fresh clone that never ran the installer merges the string catalog
and the nervous file index as PLAIN TEXT, and two cards that each add one
key collide where the driver would have kept both rows.

The wiring used to live inside `Scripts/setup-dev-env.sh`, which also
installs Homebrew and builds the package, so "wire my merge drivers" cost
a toolchain install. The wiring now lives in
`Scripts/install-merge-drivers.sh`, which needs git and python3 only.

THE CASES

  1. a fresh clone (= a repo whose `.git/config` names no driver) audits
     UNWIRED, and the remedy names the installer that wires it.
  2. running the installer on that clone makes it audit WIRED (= the
     driver is defined).
  3. the driver the installer writes is the ONE the repo's own merge
     scripts are (= the command names `Scripts/...`, so it travels).
  4. a wired clone merges two branches that each added one string-catalog
     key WITHOUT a textual conflict (= the driver actually ran, which is
     the property the whole thing exists for).
  5. the installer is safe to run twice (= the second run changes
     nothing).

Run:  python3 Tools/wenshu-devtool/tests/test_merge_drivers.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]

INSTALLER = REPO_ROOT / "Scripts" / "install-merge-drivers.sh"

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}  {detail}")
        FAILURES.append(name)


def git(cwd: Path, *args: str) -> str:
    out = subprocess.run(
        ["git", "-C", str(cwd), *args],
        capture_output=True,
        text=True,
        env={
            **__import__("os").environ,
            "GIT_AUTHOR_NAME": "t",
            "GIT_AUTHOR_EMAIL": "t@t",
        },
    )
    if out.returncode != 0:
        raise RuntimeError(f"git {args} failed: {out.stderr}")
    return out.stdout.strip()


def fresh_clone(tmp: Path) -> Path:
    """A fresh clone of THIS TREE, with no merge driver wired.

    The tree's FILES are copied (= what a checkout carries) and then given
    their own git history, so the clone measures the code as it stands
    and not only the part that happens to be committed. A clone that
    inherited the source repo's `.git/config` would already be wired, and
    the case would prove nothing.

    Only the files git tracks (= plus the untracked ones it would carry)
    are copied: the source repo's `.git` directory is not, because its
    `info/` and `objects/` hold another session's state and a copy of it
    races git's own background writes when the temporary directory is
    cleaned up.
    """
    clone = tmp / "clone"
    clone.mkdir(parents=True)
    listing = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "ls-files", "--cached", "--others",
         "--exclude-standard", "-z"],
        capture_output=True,
        check=True,
    ).stdout.decode()
    for rel in listing.split("\0"):
        if not rel:
            continue
        source = REPO_ROOT / rel
        if not source.is_file():
            continue
        target = clone / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=clone, check=True)
    git(clone, "config", "user.name", "t")
    git(clone, "config", "user.email", "t@t")
    git(clone, "add", "-A")
    git(clone, "commit", "-qm", "the tree under test")
    # The clone must not inherit any local wiring.
    for key in ("merge.xcstrings.driver", "merge.nfi-registry.driver"):
        subprocess.run(
            ["git", "-C", str(clone), "config", "--unset", key],
            capture_output=True,
        )
    return clone


def audit(clone: Path) -> tuple[bool, str]:
    out = subprocess.run(
        [
            "python3",
            str(clone / "Tools" / "wenshu-devtool" / "merge_drivers.py"),
            str(clone),
        ],
        capture_output=True,
        text=True,
    )
    return out.returncode == 0, out.stdout


def case_one_and_two(clone: Path) -> None:
    print("case 1 and 2: a fresh clone is unwired, and the installer wires it")
    ok, before = audit(clone)
    check(
        "case 1: a fresh clone audits UNWIRED (= the gap is real and visible)",
        not ok and "UNWIRED" in before,
        before[-600:],
    )
    check(
        "case 1: the remedy names the installer that wires the driver",
        "install-merge-drivers.sh" in before,
        before[-600:],
    )

    run = subprocess.run(
        ["bash", str(clone / "Scripts" / "install-merge-drivers.sh")],
        capture_output=True,
        text=True,
    )
    check(
        "case 2: the installer runs on a fresh clone (= git and python3 only)",
        run.returncode == 0,
        run.stdout + run.stderr,
    )
    ok, after = audit(clone)
    check(
        "case 2: the clone audits WIRED after the installer ran",
        ok and "UNWIRED" not in after and after.count("WIRED") >= 2,
        after[-800:],
    )


def case_three(clone: Path) -> None:
    print("case 3: the driver command travels with the repo")
    value = git(clone, "config", "--get", "merge.xcstrings.driver")
    check(
        "case 3: the driver names the repo's own script (= not an absolute path)",
        "Scripts/merge-xcstrings.py" in value and "%O" in value and "%A" in value,
        value,
    )
    check(
        "case 3: the script the driver names is IN the clone",
        (clone / "Scripts" / "merge-xcstrings.py").is_file(),
        "the driver names a script the clone does not carry",
    )


def _catalog(key: str, value: str) -> str:
    """A minimal catalog document in the shape the driver reads."""
    return (
        "{\n"
        '  "sourceLanguage" : "en",\n'
        '  "strings" : {\n'
        f'    "{key}" : {{\n'
        '      "extractionState" : "manual",\n'
        '      "localizations" : {\n'
        '        "en" : {\n'
        '          "stringUnit" : {\n'
        '            "state" : "translated",\n'
        f'            "value" : "{value}"\n'
        "          }\n"
        "        }\n"
        "      }\n"
        "    }\n"
        "  }\n"
        "}\n"
    )


def case_four(clone: Path) -> None:
    print("case 4: a wired clone merges two catalog keys without a conflict")
    # A small catalog (= the shape the driver reads), matching the
    # `*.xcstrings` attribute, with two sides each adding one key.
    catalog = clone / "fixture.xcstrings"
    base = _catalog("shared.key", "Shared")
    catalog.write_text(base, encoding="utf-8")
    git(clone, "add", "-A")
    git(clone, "commit", "-qm", "the catalog")
    head = git(clone, "rev-parse", "HEAD")

    git(clone, "checkout", "-q", "-b", "side-a")
    catalog.write_text(_catalog("side.a", "A"), encoding="utf-8")
    git(clone, "add", "-A")
    git(clone, "commit", "-qm", "side a adds a key")

    git(clone, "checkout", "-q", head)
    git(clone, "checkout", "-q", "-b", "side-b")
    catalog.write_text(_catalog("side.b", "B"), encoding="utf-8")
    git(clone, "add", "-A")
    git(clone, "commit", "-qm", "side b adds a key")

    # A TWO-WAY merge (= an octopus merge never runs a custom merge
    # driver, so the case would have proved nothing about the driver).
    git(clone, "checkout", "-q", "side-a")
    merge = subprocess.run(
        ["git", "-C", str(clone), "merge", "side-b", "-m", "both"],
        capture_output=True,
        text=True,
    )
    unmerged = git(clone, "diff", "--name-only", "--diff-filter=U")
    check(
        "case 4: the two sides merge WITHOUT a textual conflict (= the driver ran)",
        merge.returncode == 0 and not unmerged,
        f"rc={merge.returncode} unmerged={unmerged} "
        f"{merge.stdout[-300:]}{merge.stderr[-300:]}",
    )
    if merge.returncode == 0:
        merged = catalog.read_text(encoding="utf-8")
        check(
            "case 4: BOTH keys survive the merge (= the key-level merge kept them)",
            "side.a" in merged and "side.b" in merged,
            merged[:400],
        )


def case_five(clone: Path) -> None:
    print("case 5: the installer is safe to run twice")
    before = git(clone, "config", "--get", "merge.xcstrings.driver")
    run = subprocess.run(
        ["bash", str(clone / "Scripts" / "install-merge-drivers.sh")],
        capture_output=True,
        text=True,
    )
    after = git(clone, "config", "--get", "merge.xcstrings.driver")
    check(
        "case 5: a second run changes nothing",
        run.returncode == 0 and before == after,
        f"before={before} after={after}",
    )


def _drop(path: Path) -> None:
    """Remove the temporary clone, tolerating what git leaves behind.

    git keeps a background process that may be writing into `.git` while
    the temporary directory is removed, and a plain rmtree then fails on
    a directory it judged empty a moment earlier.
    """
    shutil.rmtree(path, ignore_errors=True)


def main() -> int:
    print("a fresh clone can wire its own merge drivers")
    if not INSTALLER.is_file():
        print(f"FAILED: {INSTALLER} is missing")
        return 1
    with tempfile.TemporaryDirectory() as tmp:
        clone = fresh_clone(Path(tmp))
        case_one_and_two(clone)
        case_three(clone)
        case_four(clone)
        case_five(clone)
        _drop(clone)

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s): {FAILURES}")
        return 1
    print("a fresh clone can wire its own merge drivers: every case passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
