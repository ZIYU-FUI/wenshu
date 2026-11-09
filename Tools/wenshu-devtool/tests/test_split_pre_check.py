#!/usr/bin/env python3
"""split_pre_check's own tests, = = and each check has a POSITIVE control.

= = ⇒ A CHECK THAT NOBODY CAN MAKE FAIL IS NOT A CHECK. = = Every case
# = = below builds a real git repo with a real base and a real tip, = =
# = = and runs the tool against it, = = and the case is only green when
# = = the tool says the thing the case is about.

= = ⇒ AND THE CASES ARE THE THREE DEFECTS THE REVIEW FOUND. = = The
# = = tool's own card claimed it "found exactly the defects the review
# = = found", = = and the review MEASURED that it did not: = = it missed
# = = the Foundation removal and the doc comment downgrade, = = and it
# = = reported a clean branch as failed. = = ⇒ So each of those is a case
# = = here, = = and a mutation (the fix is reverted) = = must turn them
# = = red again.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "split_pre_check.py"
FAILURES: list[str] = []


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)


def git(repo: Path, *args: str) -> str:
    proc = run(["git", *args], repo)
    return proc.stdout


def make_repo(tmp: Path) -> Path:
    repo = tmp / "repo"
    repo.mkdir(parents=True)
    git(repo, "init", "-q", "-b", "main")
    git(repo, "config", "user.name", "test")
    git(repo, "config", "user.email", "test@local")
    (repo / "Sources").mkdir()
    (repo / ".swiftlint.yml").write_text(
        "disabled_rules:\n  - file_length\n  - type_body_length\n", encoding="utf-8"
    )
    return repo


def write(repo: Path, rel: str, body: str) -> None:
    """Write a file whose FIRST LINE IS CONTENT.

    = = ⇒ A TEST FILE THAT STARTS WITH A BLANK LINE IS A TEST FOR THE
    # = = BLANK-LINE CHECK, = = and not for the case it is named after.
    # = = = = `textwrap.dedent` leaves the leading newline in place, = =
    # = = and the tool is right to report it. = = ⇒ So the newline goes.
    """
    path = repo / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(body).lstrip("\n"), encoding="utf-8")


def commit(repo: Path, message: str) -> None:
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", message)


def check(repo: Path, base: str, head: str, cwd: Path | None = None) -> tuple[int, str]:
    proc = subprocess.run(
        [
            sys.executable,
            str(TOOL),
            "--repo",
            str(repo),
            "--base",
            base,
            "--head",
            head,
        ],
        capture_output=True,
        text=True,
        cwd=str(cwd) if cwd else None,
    )
    return proc.returncode, proc.stdout + proc.stderr


def expect(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}  {detail[:200]}")
        FAILURES.append(name)


def case_removed_foundation_extension_member() -> None:
    """THE DEFECT THE REVIEW FOUND: = = a file that calls a Foundation
    EXTENSION member and no longer imports Foundation.

    = = ⇒ AND THE BASE ARM MUST BE GREEN: = = the tool's own card
    # = = claimed it caught this, = = and it did not, = = because it
    # = = compared the tree's UNION of imports (= = and 473 files still
    # = = import Foundation).
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", """
            import Foundation

            public struct Thing {
                public func trimmed() -> String {
                    value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                var value: String = "x"
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()

        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func trimmed() -> String {
                    value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                var value: String = "x"
            }
        """)
        commit(repo, "drop the import")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "the removed Foundation import is reported (= = the extension member still needs it)",
            code != 0 and "Foundation" in out and "trimmingCharacters" in out,
            out,
        )

        # = = AND THE BASE ARM: = = the tool's own claim was that it
        # = = found this, = = and it did not. = = So the tool's own
        # = = history must show it. = = (The card is not the evidence, = =
        # = = = the base arm is.)
        expect(
            "the report says the base's file DID import it",
            "DID import it" in out,
            out,
        )


def case_orphan_blank_line() -> None:
    """THE DEFECT: = = deleting an import from the FIRST line leaves the
    blank line behind, = = and `leading_whitespace` is a live rule."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", """
            import Foundation

            public struct Thing {}
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()

        # = = ⇒ AND HERE THE BLANK LINE IS THE POINT, = = so the file is
        # = = written WITHOUT the lstrip (= = the helper strips it, = =
        # = = because a test file must not start with a blank line, = =
        # = = and this one is deliberately about that).
        (repo / "Sources/Thing.swift").write_text(
            "\npublic struct Thing {}\n", encoding="utf-8"
        )
        commit(repo, "leave the blank line")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "the orphan leading blank line is reported",
            code != 0 and "BLANK LINE" in out,
            out,
        )


def case_doc_comment_downgraded() -> None:
    """THE DEFECT: = = a split that RENAMES the parent (= = and deletes
    the base's file) = = hides a `///` that became a `//`.

    = = ⇒ AND THE LINK MUST BE BY DECLARATION: = = the base's file is
    # = = `ChatSessionViewModel.swift` and the tip's is
    # = = `ChatViewModel.swift`, = = = = and the parent's methods moved
    # = = into the siblings, = = = = so a name-based link and an
    # = = overlap-based link both miss it.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Old.swift", """
            /// Old: state management
            public struct Old {
                public func one() {}
                public func two() {}
                public func three() {}
                public var value: Int = 0
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()

        (repo / "Sources/Old.swift").unlink()
        write(repo, "Sources/New.swift", """
            // Old: state management
            public struct New {
                public func one() {}
                public func two() {}
                public func three() {}
                public var value: Int = 0
            }
        """)
        commit(repo, "rename and downgrade the doc comment")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "the `///` that became a `//` is reported (= = the base's file was RENAMED)",
            code != 0 and "doc comment became a plain" in out,
            out,
        )


def case_clean_tree_is_green() -> None:
    """THE COUNTER-CASE: = = a change that breaks nothing must pass."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {}
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()

        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {}
                public func two() {}
            }
        """)
        commit(repo, "add a method")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect("a clean change passes", code == 0, out)


def case_pre_existing_finding_is_not_reported() -> None:
    """A finding that is NOT this change's doing is not a finding.

    = = ⇒ THIS IS THE CASE THE REVIEW MEASURED: = = the tool reported a
    # = = clean branch as failed, = = because swiftlint read NO config
    # = = (= = it resolves `.swiftlint.yml` from the WORKING DIRECTORY),
    # = = and the repo's disabled rules came back to life.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {}
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()

        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {}
                public func two() {}
            }
        """)
        commit(repo, "add a method")
        head = git(repo, "rev-parse", "HEAD").strip()

        # = = The tool runs from ITS OWN directory (= = a scratch dir),
        # = = and it must still read the repo's `.swiftlint.yml`.
        code, out = check(repo, base, head)
        expect(
            "a clean change passes even when the tool runs from elsewhere",
            code == 0 and "file_length" not in out,
            out,
        )


def case_promotion_not_needed_is_reported() -> None:
    """A member the change widened, = = and no file reads."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                private func hidden() -> Int { 1 }
                public func one() -> Int { hidden() }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()

        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                func hidden() -> Int { 1 }
                public func one() -> Int { hidden() }
            }
        """)
        write(repo, "Sources/Other.swift", """
            public struct Other {}
        """)
        commit(repo, "widen it")
        head = git(repo, "rev-parse", "HEAD").strip()

        # = = The promotion arm is opt-in (= = it costs a build), = = so
        # = = this case only asserts the tool does not crash on it.
        proc = subprocess.run(
            [
                sys.executable,
                str(TOOL),
                "--repo",
                str(repo),
                "--base",
                base,
                "--head",
                head,
            ],
            capture_output=True,
            text=True,
        )
        expect(
            "the tool runs on a change that widens a member",
            "Traceback" not in proc.stderr,
            proc.stderr,
        )


def case_the_repos_own_custom_rule_is_loaded() -> None:
    """THE REVIEW'S BLOCKING 1, = = measured on the REAL repo: = = a copy
    of the files carries no config, = = so the repo's OWN custom rule
    (= = the one that catches the forbidden vocabulary) is never loaded,
    and the same forbidden token reports "ok, no finding".

    = = ⇒ The repo's config has a custom rule, = = and the tool runs
    # = = = = swiftlint INSIDE the worktree, = = = = so the rule is there.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        (repo / ".swiftlint.yml").write_text(
            "custom_rules:\n"
            "  forbidden_token:\n"
            "    name: \"Forbidden token\"\n"
            "    regex: 'BADTOKEN'\n"
            "    message: \"the forbidden token is here\"\n"
            "    severity: error\n",
            encoding="utf-8",
        )
        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {
                    let name = "clean"
                    _ = name
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        # = = ⇒ AND THE TOKEN IS INTRODUCED BY THIS CHANGE, = = = = because
        # = = = = a token the base already had is not this change's.
        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {
                    let name = "BADTOKEN"
                    _ = name
                }
                public func two() {}
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "the repo's OWN custom rule is loaded (= = the forbidden token is reported)",
            "forbidden token" in out.lower(),
            out,
        )


def case_removed_import_needs_the_base_to_have_had_it() -> None:
    """A file that names a Foundation member without importing Foundation
    is NOT this change's defect when the base's file did the same.

    = = ⇒ The tree leans on `import SwiftUI` (= = which re-exports
    # = = Foundation), = = and that was true before the change too. = =
    # = = ⇒ So the base arm has to say so.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        # = = ⇒ AND EVERY BODY IS WRITTEN OUT, = = = = because a
        # = = = = single-line body is the tree's OWN swiftformat
        # = = = = violation (= = = = `wrapFunctionBodies`), = = = = and this
        # = = = = case is about the Foundation arm, = = = = not about it.
        write(repo, "Sources/Thing.swift", """
            import SwiftUI

            public struct Thing {
                public func day() -> Date {
                    Date()
                }

                public func other() -> Date {
                    Date()
                }

                public func third() -> Date {
                    Date()
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        # = = ⇒ AND THE TIP'S OWN ADDITION IS SWIFTFORMAT-CLEAN, = = = =
        # = = = = because a single-line body and a missing blank line are
        # = = = = the tree's own violations, = = = = and this case is about
        # = = = = the Foundation arm, = = = = not about them.
        write(repo, "Sources/Thing.swift", """
            import SwiftUI

            public struct Thing {
                public func day() -> Date {
                    Date()
                }

                public func other() -> Date {
                    Date()
                }

                public func third() -> Date {
                    Date()
                }

                public func fourth() -> Date {
                    Date()
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "a file that never imported Foundation is not this change's defect",
            code == 0,
            out,
        )


def case_found_by_declaration_not_by_name() -> None:
    """THE REVIEW'S BLOCKING 3: = = the base's file is RENAMED by the
    split, = = and the link must be by DECLARATION.

    = = ⇒ And the stem link must NOT be enough: = = the tip's file has a
    # = = DIFFERENT stem (= = `New.swift` for the base's `Old.swift`),
    # = = and it holds the base's declarations.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Old.swift", """
            public struct Old {
                public func alpha() {}
                public func beta() {}
                public func gamma() {}
                public var value: Int = 0
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        (repo / "Sources/Old.swift").unlink()
        write(repo, "Sources/New.swift", """
            public struct New {
                public func alpha() {}
                public func beta() {}
                public func gamma() {}
                public var value: Int = 0
            }
        """)
        commit(repo, "rename")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "a renamed file is still linked to its base (= = the split's own family)",
            code == 0 and "Traceback" not in out,
            out,
        )


def case_a_finding_that_moved_is_not_a_new_finding() -> None:
    """A finding that the BASE also had, = = with a different NUMBER in
    it, = = is not a new finding.

    = = ⇒ THIS IS THE REVIEW'S BLOCKING 1, = = the second half: = = a
    # = = = = split's parent is 1125 lines and its tip is 555, = = = = so
    # = = = = the file_length messages differ in the NUMBER they carry, = =
    # = = = = and a comparison that reads the whole message calls the
    # = = = = tip's a new finding.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        (repo / ".swiftlint.yml").write_text(
            "disabled_rules: []\n", encoding="utf-8"
        )
        body = "public struct Thing {\n" + "".join(
            f"    public func f{i}() {{}}\n" for i in range(500)
        ) + "}\n"
        write(repo, "Sources/Thing.swift", body)
        commit(repo, "base: a long file")
        base = git(repo, "rev-parse", "HEAD").strip()

        shorter = "public struct Thing {\n" + "".join(
            f"    public func f{i}() {{}}\n" for i in range(410)
        ) + "}\n"
        (repo / "Sources/Thing.swift").write_text(shorter, encoding="utf-8")
        commit(repo, "tip: a shorter file, = = and still over the limit")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "a file_length finding the BASE also had (= = with another number) is not a new finding",
            code == 0 and "file_length" not in out,
            out,
        )


def case_the_link_needs_the_declarations_and_not_the_name() -> None:
    """THE REVIEW'S BLOCKING 3, = = by its own counter-case: = = a file
    whose NAME says nothing about its origin, = = and whose DECLARATIONS
    say everything.

    = = ⇒ And the file it replaces is GONE from the tip, = = = = so a
    # = = = = lookup by the base's own path finds nothing at all.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Old.swift", """
            /// Old: state management
            public struct Old {
                public func alpha() {}
                public func beta() {}
                public func gamma() {}
                public var value: Int = 0
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        (repo / "Sources/Old.swift").unlink()
        write(repo, "Sources/New.swift", """
            // Old: state management
            public struct New {
                public func alpha() {}
                public func beta() {}
                public func gamma() {}
                public var value: Int = 0
            }
        """)
        commit(repo, "rename and downgrade")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "the renamed file IS linked to its base (= = the downgrade is caught)",
            code != 0 and "doc comment became a plain" in out,
            out,
        )


def case_a_test_file_is_read_and_checked() -> None:
    """THE REVIEW'S BLOCKING 5: = = the tree read `Sources/` only, = = and
    the changed files include `Tests/`.

    = = ⇒ So a change to a TEST file was invisible to every check that
    # = = = = reads the tree, = = = = and the tool reported a finding in
    # = = = = a file it never read. = = ⇒ The case puts a real defect in
    # = = = = a TEST file, = = = = and the tool must find it.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        write(repo, "Tests/ThingTests.swift", """
            /// ThingTests: the suite
            public struct ThingTests {}
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Tests/ThingTests.swift", """
            // ThingTests: the suite
            public struct ThingTests {}
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "a defect in a TEST file is found (= = the tool reads Tests/ too)",
            code != 0 and "doc comment became a plain" in out,
            out,
        )


def case_a_change_with_no_swift_file_is_not_a_crash() -> None:
    """THE REVIEW'S NEW DEFECT 4: = = the tool CRASHED with an IndexError
    on any change touching no Swift file (= = = = including a change of
    two Python files).

    = = ⇒ A tool that crashes says nothing, = = = = and the change it
    # = = = = cannot judge is not a change that passed.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Tools/thing.py", "print('x')\n")
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base, "--head", head],
            capture_output=True, text=True,
        )
        expect(
            "a change with no Swift file does not crash",
            "Traceback" not in proc.stderr and "IndexError" not in proc.stderr,
            proc.stderr[-400:],
        )


def case_a_new_finding_is_not_swallowed_by_an_unrelated_one() -> None:
    """THE REVIEW'S NEW DEFECT 3: = = the base was linted WHOLE, = = so an
    UNRELATED pre-existing finding could swallow a new one in a changed
    file.

    = = ⇒ The comparison is PER FILE, = = = = so a new finding in the
    # = = = = changed file is compared with THAT file's own base, = = = =
    # = = = = and the unrelated one elsewhere cannot hide it.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        # = = The repo's config DISABLES identifier_name (= = the tree's
        # = = own does), = = so this case's config does not, = = and the
        # = = finding is a real one.
        (repo / ".swiftlint.yml").write_text(
            "disabled_rules:\n  - file_length\n  - type_body_length\n", encoding="utf-8"
        )
        # = = An UNRELATED file that carries the SAME rule and the SAME
        # = = message (= = a one-letter variable name).
        write(repo, "Sources/Other.swift", """
            public struct Other {
                public func one() {
                    let a = 1
                    _ = a
                }
            }
        """)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        # = = The CHANGED file grows a finding of the same rule and the
        # = = same message (= = and a per-file comparison has to report
        # = = it, = = because the base's own Thing.swift has none).
        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {
                    let a = 1
                    _ = a
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "a new finding in a changed file is reported (= = not swallowed by an unrelated base finding)",
            code != 0 and "Thing.swift" in out,
            out,
        )


def case_a_split_created_file_is_checked_for_promotions() -> None:
    """THE REVIEW'S BLOCKING 4: = = check 5 skipped a split-created file.

    = = ⇒ The base's file is DELETED, = = = = and the widened member lives
    # = = = = in the file the split created, = = = = so a lookup by path
    # = = = = found nothing and the check said nothing. = = ⇒ The base is
    # = = = = read BY FAMILY.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Old.swift", """
            public struct Old {
                private func helper() -> Int { 1 }
                public func one() -> Int { helper() }
                public func two() -> Int { helper() }
                public func three() -> Int { helper() }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        (repo / "Sources/Old.swift").unlink()
        write(repo, "Sources/New.swift", """
            public struct New {
                func helper() -> Int { 1 }
                public func one() -> Int { helper() }
                public func two() -> Int { helper() }
                public func three() -> Int { helper() }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        # = = The probe arm is opt-in, = = and this is the arm.
        proc = subprocess.run(
            [
                sys.executable,
                str(TOOL),
                "--repo",
                str(repo),
                "--base",
                base,
                "--head",
                head,
                "--probe-promotions",
            ],
            capture_output=True,
            text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "the split-created file IS probed for a widened member",
            "Traceback" not in proc.stderr and "helper" in out,
            out[-800:],
        )


def case_two_consecutive_blank_lines_are_reported() -> None:
    """THE CLASS THE TREE'S OWN FORMATTING GATE CHARGES, = = AND WHICH
    THE TOOL DID NOT SEE.

    = = ⇒ Measured 2026-11-09: = = a helper added with TWO blank lines
    # = = = = before it cost a review card a round, = = = = and the card
    # = = = = claimed the gate exits 0. = = ⇒ The tree's gate runs
    # = = = = SWIFTFORMAT (= = and not swiftlint), = = = = and swiftlint
    # = = = = does not have this rule.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        (repo / "Sources/Thing.swift").write_text(
            "public struct Thing {}\n\n\npublic func one() {}\n", encoding="utf-8"
        )
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        # = = ⇒ AND THE ASSERTION NAMES THE RULE, = = = = and not the
        # = = = = arm's TITLE (= = = = "swiftformat" is in the title of
        # = = = = every run, = = = = so an assertion on it passes even when
        # = = = = the arm does nothing).
        expect(
            "TWO consecutive blank lines are reported (= = the tree's own gate charges them)",
            code != 0 and "consecutiveBlankLines" in out,
            out,
        )


def case_a_single_blank_line_is_not_reported() -> None:
    """THE COUNTER-CASE: = = one blank line is the house style, = = and it
    is not a finding."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        (repo / "Sources/Thing.swift").write_text(
            "public struct Thing {}\n\npublic func one() {}\n", encoding="utf-8"
        )
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "ONE blank line is not a finding",
            code == 0,
            out,
        )


def main() -> int:
    print("split_pre_check: every check has a positive control")
    for case in (
        case_removed_foundation_extension_member,
        case_orphan_blank_line,
        case_doc_comment_downgraded,
        case_clean_tree_is_green,
        case_pre_existing_finding_is_not_reported,
        case_promotion_not_needed_is_reported,
        case_the_repos_own_custom_rule_is_loaded,
        case_removed_import_needs_the_base_to_have_had_it,
        case_found_by_declaration_not_by_name,
        case_a_finding_that_moved_is_not_a_new_finding,
        case_the_link_needs_the_declarations_and_not_the_name,
        case_a_test_file_is_read_and_checked,
        case_a_change_with_no_swift_file_is_not_a_crash,
        case_a_new_finding_is_not_swallowed_by_an_unrelated_one,
        case_a_split_created_file_is_checked_for_promotions,
        case_two_consecutive_blank_lines_are_reported,
        case_a_single_blank_line_is_not_reported,
    ):
        print(f"--- {case.__name__}")
        case()
    print()
    if FAILURES:
        print(f"split_pre_check: {len(FAILURES)} case(s) FAILED: {', '.join(FAILURES)}")
        return 1
    print("split_pre_check: every case passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
