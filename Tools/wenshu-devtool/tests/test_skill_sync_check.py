#!/usr/bin/env python3
"""test_skill_sync_check.py — the skill-sync checker's own test suite.

The checker reads the REAL skill tree, so the cases run on a FIXTURE tree:
a temporary .hermes with a shared tree and per-profile skills. That proves
the checker's verdicts without depending on how the real skills happen to
look today.

The cases are the ways a rule can be written and still not reach its reader:

  1. a skill in the shared tree is carried by EVERY profile.
  2. a profile's own copy SHADOWS the shared tree's copy.
  3. a skill carried by nobody is reported as missing.
  4. two profiles holding DIFFERENT rule headings = drift.
  5. two profiles holding the SAME rule headings = no drift (a profile's
     copy may legitimately carry extra prose; the headings are the rules).
  6. the rule is reported present only in the copies that carry it.
  7. the reader missing the skill is reported (= a rule nobody sees).
  8. a broken frontmatter (no description) is reported.
  9. a skill whose reader does not carry it is reported.

Run:  python3 Tools/wenshu-devtool/tests/test_skill_sync_check.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import json
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "skill_sync_check.py"

spec = importlib.util.spec_from_file_location("skill_sync_check", TOOL)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    if got == want:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        FAILURES.append(name)


def write_skill(root: Path, relative: str, body: str) -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)
    return path


def skill_md(name: str, description: str, headings: list[str]) -> str:
    text = f"---\nname: {name}\ndescription: {description}\n---\n\n"
    for h in headings:
        text += f"## {h}\n\nbody of {h}\n\n"
    return text


def write_config(root: Path, profile: str, names_shared_tree: bool = True) -> None:
    """A profile's config.yaml. The shared tree is reached through
    `skills.external_dirs`, so a profile loads it only when it names it."""
    cfg = root / "profiles" / profile / "config.yaml"
    cfg.parent.mkdir(parents=True, exist_ok=True)
    shared = str(root / "shared" / "wenshu-skills") if names_shared_tree else "/elsewhere"
    cfg.write_text(f"skills:\n  external_dirs:\n    - {shared}\n")


def make_tree(root: Path) -> None:
    """A fixture tree: a shared skill and two profile copies.

    Every profile here names the shared tree in its config.yaml, because
    that is how the real tree is wired (= the profiles' `external_dirs`).
    """
    write_skill(
        root / "shared" / "wenshu-skills" / "shared-skill",
        "SKILL.md",
        skill_md("shared-skill", "a shared skill", ["Rule One", "Rule Two"]),
    )
    write_skill(
        root / "profiles" / "pocock" / "skills" / "devops" / "own-skill",
        "SKILL.md",
        skill_md("own-skill", "the author's skill", ["Rule A", "Rule B"]),
    )
    write_skill(
        root / "profiles" / "wenshu-review" / "skills" / "devops" / "own-skill",
        "SKILL.md",
        skill_md("own-skill", "the author's skill", ["Rule A", "Rule B"]),
    )
    write_config(root, "pocock")
    write_config(root, "wenshu-review")


def case_1_shared_tree_is_carried_by_every_profile() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        paths = mod.skill_paths("shared-skill")
        check(
            "every profile carries it",
            sorted(paths),
            ["pocock", "wenshu-review"],
        )


def case_2_local_copy_shadows_the_shared_tree() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        write_skill(
            root / "profiles" / "pocock" / "skills" / "shared-skill",
            "SKILL.md",
            skill_md("shared-skill", "the LOCAL copy wins", ["Local Rule"]),
        )
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        paths = mod.skill_paths("shared-skill")
        check(
            "pocock reads its own copy",
            str(paths["pocock"]),
            str(
                root / "profiles" / "pocock" / "skills" / "shared-skill" / "SKILL.md"
            ),
        )
        # the shared tree's path ends .../shared/wenshu-skills/<skill>/SKILL.md
        check(
            "the reviewer still reads the shared tree",
            str(paths["wenshu-review"]),
            str(root / "shared" / "wenshu-skills" / "shared-skill" / "SKILL.md"),
        )


def case_3_skill_carried_by_nobody_is_reported() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        result = mod.check("no-such-skill", None)
        check("no carriers", result["profiles_with_the_skill"], [])
        check("reported", bool(result["problems"]), True)


def case_4_different_headings_are_drift() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        write_skill(
            root / "profiles" / "wenshu-review" / "skills" / "devops" / "own-skill",
            "SKILL.md",
            skill_md("own-skill", "an OLDER copy", ["Rule A"]),
        )
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        result = mod.check("own-skill", None)
        check("drift detected", result["drift"], True)


def case_5_same_headings_are_not_drift() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        write_skill(
            root / "profiles" / "wenshu-review" / "skills" / "devops" / "own-skill",
            "SKILL.md",
            skill_md("own-skill", "same rules, more prose", ["Rule A", "Rule B"])
            + "\\n\\nextra prose that is not a rule heading\\n",
        )
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        result = mod.check("own-skill", None)
        check("the rule set is the same", result["drift"], False)
        check("the wording difference is reported", result["wording_drift"], True)
        check("it is a warning, not a failure", result["problems"], [])


def case_6_rule_reported_only_where_it_is() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        write_skill(
            root / "profiles" / "wenshu-review" / "skills" / "devops" / "own-skill",
            "SKILL.md",
            skill_md("own-skill", "the reader's copy", ["Rule A", "THE RULE"]),
        )
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        result = mod.check("own-skill", "THE RULE")
        check("rule in the reader only", result["rule_present_in"], ["wenshu-review"])


def case_7_reader_without_the_skill_is_reported() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        mod.READER_OF = {"own-skill": "wenshu-dev"}
        result = mod.check("own-skill", None)
        check(
            "the reader is reported",
            any("wenshu-dev" in p for p in result["problems"]),
            True,
        )


def case_8_broken_frontmatter_is_reported() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        write_skill(
            root / "profiles" / "pocock" / "skills" / "devops" / "own-skill",
            "SKILL.md",
            "---\nname: own-skill\n---\n\n## Rule A\n\nbody\n",
        )
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        result = mod.check("own-skill", None)
        check("frontmatter reported", result["frontmatter_ok"], False)


def case_9_frontmatter_parses_without_yaml() -> None:
    meta = mod.frontmatter(
        "---\nname: sdlc-review\ndescription: Review Kanban handoffs.\n---\n\n## A\n"
    )
    check("name", meta.get("name"), "sdlc-review")
    check("description", meta.get("description"), "Review Kanban handoffs.")


def case_10_json_mode_keeps_stdout_pure() -> None:
    """The reviewer found this: a summary line after the JSON array makes
    json.loads fail with 'Extra data'."""
    import io
    import contextlib

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        mod.READER_OF = {"own-skill": "wenshu-review"}
        out = io.StringIO()
        err = io.StringIO()
        argv = sys.argv
        sys.argv = ["skill_sync_check.py", "--json", "--skill", "own-skill"]
        try:
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = mod.main()
        finally:
            sys.argv = argv
        payload = out.getvalue()
        parsed = json.loads(payload)
        check("stdout is pure JSON", isinstance(parsed, list), True)
        check("the summary went to stderr", "=== own-skill ===" in err.getvalue(), True)
        check("stdout holds only the JSON", payload.strip().startswith("["), True)


def case_11_a_profile_that_does_not_exist_is_not_reported() -> None:
    """The reviewer found this: a hardcoded profile list asserts facts about
    profiles that have no directory."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        found = mod.discover_profiles()
        check("only real profiles", "wenshu-dev" in found, False)
        check("the real ones are found", "pocock" in found, True)


def case_12_the_reader_missing_the_skill_is_a_failure() -> None:
    """The reviewer found this: the tool false-greened when the reader held
    no copy (= it printed 'missing from' and still exited 0)."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        # the reader holds nothing: its local copy goes, and no profile's
        # config names the shared tree
        shutil.rmtree(root / "profiles" / "wenshu-review" / "skills" / "devops" / "own-skill")
        write_config(root, "pocock", names_shared_tree=False)
        write_config(root, "wenshu-review", names_shared_tree=False)
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        mod.READER_OF = {"own-skill": "wenshu-review"}
        result = mod.check("own-skill", None)
        check(
            "the reader is reported as missing",
            any("wenshu-review" in p for p in result["problems"]),
            True,
        )


def case_13_shared_tree_needs_the_profile_to_name_it() -> None:
    """A profile loads the shared tree only if its config names it."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        make_tree(root)
        # pocock's config names the tree; the reviewer's does not, and the
        # reviewer holds no local copy of its own
        write_config(root, "pocock", names_shared_tree=True)
        write_config(root, "wenshu-review", names_shared_tree=False)
        shutil.rmtree(root / "profiles" / "wenshu-review" / "skills" / "devops" / "own-skill")
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        check("pocock reaches the tree", mod.shared_tree_reaches("pocock"), True)
        check("the reviewer does not", mod.shared_tree_reaches("wenshu-review"), False)
        paths = mod.skill_paths("own-skill")
        check("pocock is carried", "pocock" in paths, True)
        check("the reviewer is not", "wenshu-review" in paths, False)


def case_14_a_wording_difference_is_drift() -> None:
    """Two copies can carry the SAME headings and different WORDS (= a lesson
    one copy gained and the other did not). A heading comparison cannot see
    it, so the checker compares the body of every section too."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / ".hermes"
        for profile in ("pocock", "wenshu-review"):
            write_skill(
                root / "profiles" / profile / "skills" / "devops" / "own-skill",
                "SKILL.md",
                skill_md("own-skill", "the skill", ["Same Heading"])
                + "the shared words\n",
            )
            write_config(root, profile, names_shared_tree=False)
        # the reader gains one line
        reader = root / "profiles" / "wenshu-review" / "skills" / "devops" / "own-skill" / "SKILL.md"
        reader.write_text(reader.read_text() + "an extra lesson only the reader has\n")
        mod.HERMES = root
        mod.SHARED_TREE = root / "shared" / "wenshu-skills"
        mod.READER_OF = {}
        result = mod.check("own-skill", None)
        check("the wording difference is reported", result["wording_drift"], True)
        check(
            "the differing section is named",
            "Same Heading" in result["differing_sections"],
            True,
        )
        check("a warning is raised", bool(result["warnings"]), True)


def main() -> int:
    cases = [
        case_1_shared_tree_is_carried_by_every_profile,
        case_2_local_copy_shadows_the_shared_tree,
        case_3_skill_carried_by_nobody_is_reported,
        case_4_different_headings_are_drift,
        case_5_same_headings_are_not_drift,
        case_6_rule_reported_only_where_it_is,
        case_7_reader_without_the_skill_is_reported,
        case_8_broken_frontmatter_is_reported,
        case_9_frontmatter_parses_without_yaml,
        case_10_json_mode_keeps_stdout_pure,
        case_11_a_profile_that_does_not_exist_is_not_reported,
        case_12_the_reader_missing_the_skill_is_a_failure,
        case_13_shared_tree_needs_the_profile_to_name_it,
        case_14_a_wording_difference_is_drift,
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
