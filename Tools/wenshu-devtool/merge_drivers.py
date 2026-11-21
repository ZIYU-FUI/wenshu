#!/usr/bin/env python3
"""merge_drivers.py — read BOTH halves of a merge driver before claiming one runs.

WHAT THE TWO HALVES ARE

  .gitattributes  (tracked, in the repo) NAMES the driver:
                                           docs/agents/nfi.md merge=nfi-registry
  .git/config     (local, NOT in the repo) DEFINES it:
                                           merge.nfi-registry.driver = <command>

Only the first half ships with the checkout. The second is written by
Scripts/setup-dev-env.sh, so a fresh clone, a machine that skipped the
installer, or a worktree added before it ran holds an attribute with no driver
behind it. A linked worktree shares the one common config of its repo, so an
unwired main checkout means every worktree under it is unwired too.

WHY THIS NEEDS A CHECK

git does not report a missing driver: when `merge=<name>` names a driver git
cannot find, git falls back to its built-in text merge and prints nothing. For
the nervous file index (= one row per extracted file, merged at the KEY level
so that two cards each adding a row both keep theirs) that fallback is exactly
the collision the driver exists to prevent, hand-resolved by a reader who was
told the overlap was already handled.

Measured at 62b2b4e5fb: `git config --get merge.nfi-registry.driver` is empty
in the shared checkout and in each linked worktree, while
`git config --get merge.xcstrings.driver` returns a command. The two
instruments that read .gitattributes reported the registry as driver-managed.
Neither one asked git config. So the attributes read is kept here (= it is the
tracked half) and the config read is added beside it (= the local half), and a
pair that does not match is a failure, not a note.

Run from anywhere:

    python3 Tools/wenshu-devtool/merge_drivers.py
"""
from __future__ import annotations

import fnmatch
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
INSTALLER = "Scripts/setup-dev-env.sh"


class WiringError(RuntimeError):
    """The config read itself failed (= a repo git cannot open).

    An unreadable config is not an unset config: reporting one as the other
    would call a broken checkout correctly wired, or a wired one broken.
    """


@dataclass(frozen=True)
class Rule:
    """One `merge=<name>` rule of .gitattributes."""

    name: str      # the driver git is told to use (= nfi-registry)
    pattern: str   # the path or glob it is declared on
    lineno: int    # 1-based line in .gitattributes, so the fix is openable
    line: str      # that line as written

    @property
    def config_key(self) -> str:
        """The git-config key that would define this driver."""
        return f"merge.{self.name}.driver"


def _git(repo, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True
    )


def declared_rules(repo) -> list[Rule]:
    """Every `merge=<name>` rule in .gitattributes, in file order.

    Comment lines are skipped. .gitattributes is mostly prose explaining WHY
    each driver exists, and one of those lines quotes `merge=union` — reading
    it as a rule would invent a driver named "union`" and demand config for it.
    """
    path = Path(repo) / ".gitattributes"
    if not path.exists():
        return []
    rules: list[Rule] = []
    for lineno, raw in enumerate(
        path.read_text(encoding="utf-8").split("\n"), start=1
    ):
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parts = stripped.split()
        if len(parts) < 2:
            continue
        for token in parts[1:]:
            if token.startswith("merge="):
                name = token[len("merge="):]
                # `merge=` with no value UNSETS the attribute (= no driver).
                if name:
                    rules.append(Rule(name, parts[0], lineno, stripped))
                break
    return rules


def driver_setting(repo, name: str) -> str | None:
    """The command git would run for `merge=<name>` here, or None if it has none.

    `git config --get` exits 1 and prints nothing when the key is unset, and
    prints the value when it is set, so the printed value decides and the exit
    code only decides whether a silent failure was an unset key or a broken
    read. Any other non-zero exit with no output raises: an unreadable config
    is not an empty one.
    """
    out = _git(repo, "config", "--get", f"merge.{name}.driver")
    value = out.stdout.strip()
    if value:
        return value
    if out.returncode in (0, 1):
        return None
    raise WiringError(
        f"git -C {repo} config --get merge.{name}.driver failed rc={out.returncode}"
        + (f": {out.stderr.strip()}" if out.stderr.strip() else "")
    )


def rule_for(repo, path: str) -> Rule | None:
    """The rule that applies to a tracked path, or None.

    The match is the one the wave gate has always used: the pattern against
    the basename, then against the path as written. It is NOT git's own
    gitattributes matcher (= which also knows about negation, directories and
    the last-match rule) and this repo's two rules are one glob and one exact
    path, so no rule here depends on the difference.
    """
    name = Path(path).name
    for rule in reversed(declared_rules(repo)):
        if fnmatch.fnmatch(name, rule.pattern) or fnmatch.fnmatch(path, rule.pattern):
            return rule
    return None


def wiring(repo, rule: Rule) -> tuple[bool, str | None]:
    """(is this declared driver defined, the value or None)."""
    value = driver_setting(repo, rule.name)
    return value is not None, value


def unwired_rules(repo) -> list[Rule]:
    """Declared drivers that git config does not define (= the silent fallback)."""
    return [r for r in declared_rules(repo) if driver_setting(repo, r.name) is None]


def installer_line(repo, rule: Rule) -> str | None:
    """The line of Scripts/setup-dev-env.sh that installs this driver, or None.

    The remedy printed is the one the repo ships rather than a copy kept in
    two places: if the installer stops installing the key, the printed remedy
    says so instead of telling the reader to run a script that no longer does
    the thing.
    """
    path = Path(repo) / INSTALLER
    if not path.exists():
        return None
    want = f"git config {rule.config_key} "
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").split("\n"), start=1):
        if raw.strip().startswith(want):
            return f"{INSTALLER}:{lineno}:  {raw.strip()}"
    return None


def remedy(repo, rule: Rule) -> list[str]:
    """What to run, printed as lines under a failure.

    The command printed is the installer's own line, so the reader copies the
    value that ships with the repo instead of a value typed out again here.
    """
    installed = installer_line(repo, rule)
    if installed:
        return [
            f"wire it: {installed.split(':  ', 1)[1]}",
            f"or run the installer: bash {INSTALLER}  (= {installed})",
        ]
    return [
        f"wire it: git config {rule.config_key} \"<driver command> %O %A %B\"",
        f"and {INSTALLER} installs no such key (= the attribute has no "
        f"installer; the fix belongs there)",
    ]


def audit(repo) -> tuple[bool, list[str]]:
    """(every declared driver is defined, lines that say so per rule)."""
    lines: list[str] = []
    ok = True
    rules = declared_rules(repo)
    if not rules:
        return False, [
            "FAIL  .gitattributes declares no merge driver (= nothing was checked)"
        ]
    for rule in rules:
        defined, value = wiring(repo, rule)
        if defined:
            lines.append(
                f"  WIRED    {rule.pattern}  .gitattributes:{rule.lineno}  "
                f"merge={rule.name}  ->  {rule.config_key} = {value}"
            )
            continue
        ok = False
        lines.append(
            f"  UNWIRED  {rule.pattern}  .gitattributes:{rule.lineno}  "
            f"merge={rule.name}  ->  {rule.config_key} is not set"
        )
        lines.append(
            "           git has no driver for that attribute, so it uses its built-in "
            "text merge and prints nothing (= the key-level merge never runs)."
        )
        for line in remedy(repo, rule):
            lines.append(f"           {line}")
    return ok, lines


def main() -> int:
    repo = REPO
    if len(sys.argv) > 1:
        repo = Path(sys.argv[1]).resolve()
    ok, lines = audit(repo)
    print(f"merge drivers declared by {repo}/.gitattributes:")
    for line in lines:
        print(line)
    print(f"merge_drivers: {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
