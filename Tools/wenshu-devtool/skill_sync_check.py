#!/usr/bin/env python3
"""
skill_sync_check.py - prove that a rule written into a skill is a rule the
READER will actually see.

WHY THIS TOOL EXISTS
  A rule that nobody reads is not a rule. Measured on board wenshu-par,
  2026-11-03: the review lane loads `sdlc-review` 209 times and
  `wenshu-parallel-dev` 34 times, so a rule written into the 1199-line
  review-round reference is nearly invisible to the worker that has to
  follow it. And the two profiles can hold DIFFERENT copies of the same
  skill, which drift silently.

  So the question this tool answers is not "is the rule in the file" (= it
  is, if you wrote it) but "is the file the READER loads the file you
  wrote, and does it carry the rule". Two ways that fails:

    - the copies drift (= pocock's copy and wenshu-review's copy differ),
      so the reviewer runs on an older rule than the author thinks;
    - the rule is written into a skill nobody opens.

WHAT IT CHECKS
  1. every profile that dispatches work has the skill, at the path the
     loader reads.
  2. the profiles' copies of a shared skill CARRY the same rule markers
     (= no drift).
  3. a rule named in the checker's argument is present in the reader's
     copy.
  4. the skill's frontmatter still parses and its description still says
     when to load it.

Usage:
    python3 skill_sync_check.py
    python3 skill_sync_check.py --skill sdlc-review --rule "THE COST OF A REVIEW"
    python3 skill_sync_check.py --json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERMES = Path.home() / ".hermes"

# The shared skill tree. The profiles reach it through `skills.external_dirs`
# in their config.yaml, so a skill living HERE is loaded by every profile
# that names that directory. A skill in a profile's own directory is loaded
# only by that profile.
SHARED_TREE = HERMES / "shared" / "wenshu-skills"

# The fallback when the profiles directory cannot be read at all. It is a
# FALLBACK and never the truth: a hardcoded list asserts facts about
# profiles that may not exist (= the review lane's `wenshu-dev` has no
# directory at all), and a profile that does not exist cannot be a reader.
# Every real lookup goes through `discover_profiles()`.
_FALLBACK_PROFILES = ("pocock", "wenshu-review")


def discover_profiles() -> tuple:
    """The profiles that actually exist on this machine.

    A profile is a directory under `~/.hermes/profiles`. A name that is
    not a directory is not a profile, and this tool must not report on it.
    """
    root = HERMES / "profiles"
    if not root.exists():
        return _FALLBACK_PROFILES
    found = tuple(
        sorted(
            p.name
            for p in root.iterdir()
            if p.is_dir() and (p / "config.yaml").exists()
        )
    )
    return found or _FALLBACK_PROFILES

# The skills that carry the board's flow rules.
SHARED_SKILLS = ("sdlc-review", "wenshu-parallel-dev", "wenshu-pocock-workflow")

# The reader of each skill, and how often it is actually opened. A rule
# belongs with its reader.
READER_OF = {
    "sdlc-review": "wenshu-review",
    "wenshu-parallel-dev": "pocock",
    "wenshu-pocock-workflow": "pocock",
}


def shared_tree_reaches(profile: str) -> bool:
    """Does this profile's config name the shared skill tree?

    The shared tree is reached through `skills.external_dirs` in the
    profile's config.yaml. A profile that does not exist, or that does not
    name the tree, does NOT load its skills.
    """
    config = HERMES / "profiles" / profile / "config.yaml"
    if not config.exists():
        return False
    try:
        text = config.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    return str(SHARED_TREE) in text


def skill_paths(skill: str) -> dict[str, Path]:
    """Every carrier of a skill, by profile name.

    A skill in the SHARED tree is carried by every profile (= the shared
    tree is on every profile's `skills.external_dirs`), and one profile's
    own copy SHADOWS it (= the local copy wins).
    """
    found: dict[str, Path] = {}
    shared = SHARED_TREE / skill / "SKILL.md"
    if shared.exists():
        for profile in discover_profiles():
            if shared_tree_reaches(profile):
                found[profile] = shared
    for profile in discover_profiles():
        root = HERMES / "profiles" / profile / "skills"
        if not root.exists():
            continue
        for path in root.rglob("SKILL.md"):
            if path.parent.name == skill:
                found[profile] = path
                break
    return found


def sections(text: str) -> dict[str, str]:
    """A skill's body, split by its `##`/`###` headings.

    Two copies can carry the same headings and different WORDS (= a lesson
    one copy gained and the other did not). Splitting by heading makes that
    difference nameable, so the check can report WHICH section differs and
    not just that something does.
    """
    marks = list(re.finditer(r"^#{2,3} (.+)$", text, re.M))
    out: dict[str, str] = {}
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        out[m.group(1).strip()] = text[m.start():end]
    return out


def frontmatter(text: str) -> dict:
    """The skill's frontmatter, parsed without a YAML dependency."""
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    out: dict[str, str] = {}
    for line in parts[1].splitlines():
        if ":" in line and not line.startswith((" ", "\t", "#")):
            key, _, value = line.partition(":")
            out[key.strip()] = value.strip().strip('"').strip("'")
    return out


def check(skill: str, rule: str | None) -> dict:
    """Every fact about one skill, and whether it is coherent."""
    paths = skill_paths(skill)
    result: dict = {
        "skill": skill,
        "profiles_with_the_skill": sorted(paths),
        # The profiles are READ FROM THE DISK. A hardcoded list asserts
        # facts about profiles that do not exist on this machine (= it named
        # a profile that has no directory) and omits the real ones that lack
        # the skill (= the case this column exists to report).
        "missing_from": [p for p in discover_profiles() if p not in paths],
        "drift": False,
        "wording_drift": False,
        "differing_sections": {},
        "warnings": [],
        "rule_present_in": [],
        "frontmatter_ok": True,
        "description": "",
        "problems": [],
    }
    if not paths:
        result["problems"].append(f"no profile carries a skill named {skill}")
        return result

    bodies: dict[str, str] = {}
    for profile, path in paths.items():
        text = path.read_text(encoding="utf-8", errors="replace")
        bodies[profile] = text
        meta = frontmatter(text)
        if not meta.get("name") or not meta.get("description"):
            result["frontmatter_ok"] = False
            result["problems"].append(f"{profile}: the frontmatter is missing name or description")
        result["description"] = meta.get("description", result["description"])
        if rule and rule in text:
            result["rule_present_in"].append(profile)

    # Drift = the copies do not carry the same RULE MARKERS. Byte equality
    # is the wrong test: a profile's own copy may legitimately carry extra
    # sections (pocock's sdlc-review has the wenshu-specific ones), and
    # what matters is that the reader runs the SAME RULES as the author.
    markers: dict[str, set] = {}
    for profile, text in bodies.items():
        markers[profile] = set(re.findall(r"^#{2,3} (.+)$", text, re.M))
    unique_markers = {frozenset(m) for m in markers.values()}
    if len(unique_markers) > 1:
        result["drift"] = True
        result["problems"].append(
            f"the copies carry different rule headings across {sorted(bodies)} "
            f"(= the reader may run a different rule set than the author wrote)"
        )
    result["headings"] = {k: sorted(v) for k, v in markers.items()}

    # The HEADINGS are not enough. Two copies can carry the same headings and
    # still differ in the WORDS (= a lesson one copy gained and the other
    # did not), and that difference is invisible to a heading comparison.
    # So compare the BODY of every section too, and report which section
    # differs.
    bodies_by_section: dict[str, dict[str, str]] = {}
    for profile, text in bodies.items():
        bodies_by_section[profile] = sections(text)
    all_sections = sorted(
        {name for per in bodies_by_section.values() for name in per}
    )
    differing: dict[str, list[str]] = {}
    for name in all_sections:
        variants = {
            profile: per.get(name, "")
            for profile, per in bodies_by_section.items()
        }
        if len(set(variants.values())) > 1:
            differing[name] = sorted(variants)
    result["differing_sections"] = differing
    if differing:
        # A wording difference is REPORTED but it is not by itself a failure:
        # one copy may legitimately carry extra prose (= a note, a
        # profile-specific aside) while the RULE is the same. What cannot
        # be told apart automatically is "extra prose" from "a lesson one
        # copy gained and the other did not", so the difference is named and
        # a human decides. The exit code is driven by the heading check
        # (= the rule set), and this is the warning that the words differ.
        result["wording_drift"] = True
        result["warnings"].append(
            "these sections differ in their WORDS across "
            f"{sorted(bodies)}: {', '.join(differing)} (= one copy may hold "
            "a lesson the other does not; a heading comparison cannot see it)"
        )

    # The reader must be among the carriers. This is the check that matters
    # most, so it is a PROBLEM (= the tool exits 1), never a note.
    reader = READER_OF.get(skill)
    if reader and reader not in paths:
        result["problems"].append(
            f"the reader of this skill ({reader}) does not carry it (= a rule "
            f"written here is a rule nobody sees)"
        )
    if rule:
        reader = READER_OF.get(skill, reader)
        if reader and reader in paths and rule not in bodies.get(reader, ""):
            result["problems"].append(
                f"the rule {rule!r} is NOT in the reader's copy ({reader})"
            )
    return result


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--skill", default=None)
    ap.add_argument("--rule", default=None)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    skills = [args.skill] if args.skill else list(SHARED_SKILLS)
    results = [check(s, args.rule) for s in skills]

    if args.json:
        # The JSON is the ONLY thing on stdout in this mode: a caller pipes
        # it into json.loads, and a summary line after the array makes that
        # fail with "Extra data". The summary goes to stderr.
        #
        # AND THE EXIT CODE STILL REPORTS THE FAILURES. An early `return 0`
        # here would hand a caller a green light while the tool's own
        # summary says "3 skill(s) need attention" = a gate that cannot
        # fail, which is the exact defect this tool exists to prevent.
        print(json.dumps(results, indent=2))
        _summary(results)
        bad = [r for r in results if r["problems"]]
        return 1 if bad else 0
    else:
        for r in results:
            print(f"=== {r['skill']} ===")
            print(f"  carried by: {', '.join(r['profiles_with_the_skill']) or '(nobody)'}")
            if r["missing_from"]:
                print(f"  missing from: {', '.join(r['missing_from'])}")
            same = not (r["drift"] or r.get("wording_drift"))
            print(f"  copies identical: {'yes' if same else 'no (DRIFT)'}")
            if args.rule:
                print(f"  rule {args.rule!r} in: {', '.join(r['rule_present_in']) or '(nobody)'}")
            if r["description"]:
                print(f"  description: {r['description'][:90]}")
            for p in r["problems"]:
                print(f"  !! {p}")
            for w in r["warnings"]:
                print(f"  ?? {w}")
            print()
    bad = [r for r in results if r["problems"]]
    if bad:
        print(f"{len(bad)} skill(s) need attention")
        return 1
    print("every skill's copies are in step with its reader")
    return 0


def _summary(results: list) -> None:
    """The human summary, on stderr (= stdout carries the JSON alone)."""
    for r in results:
        print(f"=== {r['skill']} ===", file=sys.stderr)
        print(
            f"  carried by: {', '.join(r['profiles_with_the_skill']) or '(nobody)'}",
            file=sys.stderr,
        )
        if r["missing_from"]:
            print(f"  missing from: {', '.join(r['missing_from'])}", file=sys.stderr)
        same = not (r["drift"] or r.get("wording_drift"))
        print(
            f"  copies identical: {'yes' if same else 'no (DRIFT)'}",
            file=sys.stderr,
        )
        for p in r["problems"]:
            print(f"  !! {p}", file=sys.stderr)
        for w in r["warnings"]:
            print(f"  ?? {w}", file=sys.stderr)
    bad = [r for r in results if r["problems"]]
    if bad:
        print(f"{len(bad)} skill(s) need attention", file=sys.stderr)
    else:
        print(
            "every skill's copies are in step with its reader", file=sys.stderr
        )


if __name__ == "__main__":
    sys.exit(main())
