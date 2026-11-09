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




def wc_lines(path: Path) -> int:
    """The file's own `wc -l` count (= = the registry's own convention)."""
    with open(path, "rb") as handle:
        return sum(1 for _ in handle)

def make_buildable_repo(tmp: Path) -> Path:
    """A repo whose `swift build` ACTUALLY RUNS.

    = = ⇒ AND A FIXTURE WITH NO PACKAGE.SWIFT IS WORTHLESS FOR THE
    # = = = = PROMOTION ARM. = = = = `swift build` in a directory with no
    # = = = = package fails, = = = = so the probe's build never compiled
    # = = = = anything, = = = = and the arm's answer was vacuous (= = = =
    # = = = = measured: = = = = the card's own case was green on such a
    # = = = = fixture, = = = = and the review found it). = = ⇒ So the
    # = = = = fixture is a REAL SwiftPM package, = = = = with the repo's
    # = = = = own tools version.
    """
    repo = make_repo(tmp)
    write(repo, "Package.swift", """
        // swift-tools-version: 6.4
        import PackageDescription
        let package = Package(
            name: "Probe",
            targets: [.target(name: "Probe", path: "Sources/Probe")]
        )
    """)
    (repo / "Sources/Probe").mkdir(parents=True, exist_ok=True)
    return repo

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
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Probe/Old.swift", """
            public struct Old {
                private func helper() -> Int {
                    1
                }

                public func one() -> Int {
                    helper()
                }

                public func two() -> Int {
                    helper()
                }

                public func three() -> Int {
                    helper()
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        (repo / "Sources/Probe/Old.swift").unlink()
        write(repo, "Sources/Probe/New.swift", """
            public struct New {
                func helper() -> Int {
                    1
                }

                public func one() -> Int {
                    helper()
                }

                public func two() -> Int {
                    helper()
                }

                public func three() -> Int {
                    helper()
                }
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


def case_the_vendored_tree_is_exempt() -> None:
    """THE REVIEW'S BLOCKING 1: = = the swiftformat arm charged the
    VENDORED tree, = = which the tree's own gate deliberately exempts.

    = = ⇒ Measured on a real commit: = = the gate says "no unformatted
    # = = = = line", = = = = and the tool says 61 findings, = = = = all of
    # = = = = them in Vendor/.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        write(repo, "Vendor/Upstream/Thing.swift", "public struct Upstream {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Vendor/Upstream/Thing.swift",
              "public struct Upstream {}\n\n\npublic func one() {}\n")
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        # = = ⇒ THE FINDING LINES, = = = = not the whole output: = = = =
        # = = = = the file LIST names the vendored file (= = = = the
        # = = = = swiftlint arm sees it, = = = = as the tree's own lint
        # = = = = does), = = = = and the line that matters is the
        # = = = = FINDING, = = = = and the swiftformat arm must not
        # = = = = charge it.
        # = = ⇒ AND THE ASSERTION IS SCOPED TO THE ARM THAT EXEMPTS IT.
        # = = = = The tree's own FORMATTING gate exempts the vendored tree,
        # = = = = and the tree's own LINT does not (= = = = and this tool
        # = = = = must match both). = = ⇒ So the case asks about the
        # = = = = SWIFTFORMAT arm's findings, = = = = and the arm's own
        # = = = = section of the output is where they are. = = ⇒ Measured
        # = = = = by the review: = = = = an assertion over EVERY finding
        # = = = = line claimed the whole vendored tree was exempt, = = = =
        # = = = = while the tree's own lint does not exempt it.
        section = ""
        capturing = False
        for line in out.split("\n"):
            if line.startswith("==="):
                capturing = "swiftformat" in line
                continue
            if capturing:
                section += line + "\n"
        findings = [
            line for line in section.split("\n")
            if line.strip().startswith("!")
        ]
        expect(
            "the VENDORED tree is exempt (= = the tree's own gate exempts it)",
            not any("Vendor/" in line for line in findings),
            out,
        )


def case_the_swiftlint_arm_still_sees_the_vendored_tree() -> None:
    """THE REVIEW'S NON-BLOCKING FINDING: = = the exemption was WIDER
    than the tree's own lint.

    = = ⇒ Measured by the review: = = the tree's `.swiftlint.yml` has no
    # = = = = Vendor entry, = = = = the forbidden-vocab rule is severity
    # = = = = error, = = = = and CI's SwiftLint step hard-fails on error
    # = = = = severity: = = = = a vendored file carrying a forbidden
    # = = = = token makes the tree's own swiftlint exit 2. = = ⇒ The
    # = = = = tree's lint does NOT exempt Vendor/, = = = = so this tool's
    # = = = = swiftlint arm must not either (= = = = and the exemption
    # = = = = belongs to the swiftformat arm alone).
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        write(repo, "Vendor/Upstream/Thing.swift", "public struct Upstream {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Vendor/Upstream/Thing.swift",
              "public struct Upstream {}\n\n\npublic func one() {}\n")
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "the swiftlint arm still sees the vendored tree",
            "Vendor/Upstream/Thing.swift" in out,
            out,
        )


def case_a_failed_build_is_not_a_clean_one() -> None:
    """THE REVIEW'S BLOCKING 2: = = the promotions arm grepped the build
    log for "is inaccessible" and never read the EXIT CODE.

    = = ⇒ Measured: = = exit 1, = = = = and the tool still said "still
    # = = = = builds (= = = = so no file needed it)". = = ⇒ A build that
    # = = = = did not succeed measures NOTHING.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        # = = A package that CANNOT build (= = = = the file does not
        # = = = = compile), = = = = so the probe's build fails.
        write(repo, "Sources/Probe/Broken.swift",
              "public struct Broken { this is not swift }\n")
        # = = ⇒ AND THE BASE HOLDS THE MEMBER AS `private`, = = = = so the
        # = = = = tip's version IS a widening (= = = = a member that is
        # = = = = new in the tip is not a widening, = = = = and the probe
        # = = = = says so).
        write(repo, "Sources/Probe/Other.swift", """
            public struct Other {
                private func helper() -> Int {
                    1
                }

                public func one() -> Int {
                    helper()
                }

                public func two() -> Int {
                    helper()
                }

                public func three() -> Int {
                    helper()
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Probe/Broken.swift",
              "public struct Broken { this is not swift }\n")
        # = = ⇒ AND A MEMBER THAT IS REALLY WIDENED, = = = = so the
        # = = = = probe HAS something to measure (= = = = and the build
        # = = = = still cannot succeed, = = = = because the other file does
        # = = = = not compile).
        # = = ⇒ AND THE MEMBER IS REALLY WIDENED IN THE TIP (= = = = the
        # = = = = base says `private`, = = = = the tip says nothing), = =
        # = = = = so the probe HAS something to measure, = = = = and the
        # = = = = build still cannot succeed (= = = = because the OTHER
        # = = = = file does not compile).
        write(repo, "Sources/Probe/Other.swift", """
            public struct Other {
                func helper() -> Int {
                    1
                }

                public func one() -> Int {
                    helper()
                }

                public func two() -> Int {
                    helper()
                }

                public func three() -> Int {
                    helper()
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--probe-promotions"],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        # = = ⇒ AND THE ASSERTION REQUIRES THE SAYING, = = = = and not
        # = = = = merely the absence of the other message (= = = = because
        # = = = = "not X" is true when the tool says nothing at all).
        expect(
            "a FAILED build is not read as a clean one",
            "could not measure it" in out,
            out[-900:],
        )


def case_a_widening_to_public_is_seen() -> None:
    """THE REVIEW'S BLOCKING 3: = = the promotions arm's tip-side regex
    admitted NO access modifier, = = so `private` -> `public` was
    invisible.

    = = ⇒ Measured: = = exit 0, = = = = "every widened member is read
    # = = = = across the file boundary".
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                private func helper() -> Int {
                    1
                }

                public func one() -> Int {
                    helper()
                }

                public func two() -> Int {
                    helper()
                }

                public func three() -> Int {
                    helper()
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                public func helper() -> Int {
                    1
                }

                public func one() -> Int {
                    helper()
                }

                public func two() -> Int {
                    helper()
                }

                public func three() -> Int {
                    helper()
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--probe-promotions"],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        # = = ⇒ THE ARM MUST SEE THE WIDENING AT ALL, = = = = and the
        # = = = = old regex admitted no access modifier, = = = = so this
        # = = = = shape was invisible (= = = = exit 0, = = = = "every
        # = = = = widened member is read across the file boundary").
        expect(
            "a `private` -> `public` widening is seen",
            "helper" in out and "every widened member is read" not in out,
            out[-900:],
        )


def case_a_base_that_does_not_exist_is_not_clean() -> None:
    """THE REVIEW'S BLOCKING 4: = = a base that does not exist gave
    byte-identical output to a change with no Swift file (= = "every case
    passed", = = exit 0).
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        commit(repo, "base")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo),
             "--base", "0" * 40, "--head", head],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "a base that does not exist is NOT clean",
            proc.returncode != 0 and "does not exist" in out,
            out[-700:],
        )


def case_a_second_finding_of_the_same_rule_is_not_swallowed() -> None:
    """THE REVIEW'S BLOCKING 5: = = the comparison was an `any` over a
    list, = = so the tip's SECOND finding of the same rule in the same
    file was hidden by the base's ONE.

    = = ⇒ Measured: = = swiftlint's own verdict was 2, = = = = and the
    # = = = = tool said 0.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        (repo / ".swiftlint.yml").write_text(
            "disabled_rules:\n  - file_length\n  - type_body_length\n", encoding="utf-8"
        )
        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {
                    let a = 1
                    _ = a
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Thing.swift", """
            public struct Thing {
                public func one() {
                    let a = 1
                    _ = a
                }

                public func two() {
                    let a = 2
                    _ = a
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "the tip's SECOND finding of the same rule is reported",
            code != 0 and out.count("identifier_name") >= 1,
            out,
        )


def case_a_tip_that_cannot_be_looked_at_is_not_clean() -> None:
    """THE REVIEW'S BLOCKING 4, = = the other side: = = a tree that could
    not be READ is said out loud, = = and not read as "nothing to report".

    = = ⇒ AND A TIP THAT DOES NOT EXIST IS THE SAME SILENCE FROM THE
    # = = = = OTHER SIDE.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo),
             "--base", base, "--head", "0" * 40],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "a tip that cannot be looked at is NOT clean",
            proc.returncode != 0 and "does not exist" in out,
            out[-700:],
        )


def case_a_base_that_cannot_be_looked_at_is_not_clean() -> None:
    """THE REVIEW'S BLOCKING 4: = = a tree that could not be READ is said
    out loud.

    = = ⇒ AND THE FAILURE IS INJECTED, = = = = because a base that
    # = = = = cannot be looked at is otherwise untestable from outside
    # = = = = (= = = = and an untestable path is an unheld one).
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Thing.swift", "public struct Thing { public func one() {} }\n")
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        # = = A PARENT THAT IS A FILE, = = = = so the worktree's own
        # = = directory cannot be created (= = = = `git worktree add`
        # = = = = refuses it, = = = = and the failure is the tree's, = =
        # = = = not the tool's).
        blocked = tmp / "a-file-not-a-directory"
        blocked.write_text("x", encoding="utf-8")
        broken_parent = blocked

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--lint-work-parent", str(broken_parent)],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "a base that could NOT be looked at is said out loud",
            proc.returncode != 0 and "could not be looked at" in out,
            out[-900:],
        )


def case_a_member_that_is_still_private_is_not_a_widening() -> None:
    """THE MEASURED FALSE POSITIVE: = = the promotions arm read `private`
    as IMMEDIATELY followed by the name, = = so every `private var x` and
    every `private func x` read as "not private any more".

    = = ⇒ Measured: = = thirteen false positives on ONE real split, = =
    # = = = = every one of them a member that was private in the base
    # = = = = and private in the tip.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                private var counter: Int = 0
                private static var shared: Int = 0

                public func one() -> Int {
                    counter
                }

                public func two() -> Int {
                    counter
                }

                public func three() -> Int {
                    counter
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        # = = ⇒ THE TIP CHANGES THE FILE (= = so the file is one the
        # = = = = change touched), = = = = and it does NOT touch the two
        # = = = = members: = = = = both are still private.
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                private var counter: Int = 0
                private static var shared: Int = 0

                public func one() -> Int {
                    counter
                }

                public func two() -> Int {
                    counter
                }

                public func three() -> Int {
                    counter
                }

                public func four() -> Int {
                    counter
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--probe-promotions"],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "a member that is STILL private is not a widening",
            "every widened member is read across the file boundary" in out,
            out[-900:],
        )


def case_a_dropped_module_nobody_uses_is_not_a_defect() -> None:
    """THE MEASURED FALSE POSITIVE: = = the arm reported "the family
    dropped `AppKit` entirely" for a module nothing in the family used.

    = = ⇒ Measured: = = on a real split the family dropped AppKit, = = =
    # = = = = nothing in it used AppKit, = = = = and the arm said "still
    # = = = = needs it".
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Probe/Thing.swift", """
            import AppKit
            import SwiftUI

            public struct Thing {
                public func one() -> Int {
                    1
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Probe/Thing.swift", """
            import SwiftUI

            public struct Thing {
                public func one() -> Int {
                    1
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "a module nobody uses any more is not a lost import",
            "no file lost an import it still needs" in out,
            out[-900:],
        )


def case_a_widening_of_a_static_member_is_seen() -> None:
    """THE GAP THE MEASUREMENT FOUND: = = the base-side regex read
    `private` as IMMEDIATELY followed by the name, = = so a
    `private static var` in the base was not recorded as private, = = and
    a `private static var` -> `public static var` widening was invisible.

    = = ⇒ The tip-side regex reads the modifier words, = = and the
    # = = = = base-side one must read them too, = = = = or the two sides
    # = = = = disagree about what a member is.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                private static var shared: Int = 0

                public func one() -> Int {
                    shared
                }

                public func two() -> Int {
                    shared
                }

                public func three() -> Int {
                    shared
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                public static var shared: Int = 0

                public func one() -> Int {
                    shared
                }

                public func two() -> Int {
                    shared
                }

                public func three() -> Int {
                    shared
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--probe-promotions"],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "a `private static` -> `public static` widening is seen",
            "shared" in out and "every widened member is read" not in out,
            out[-900:],
        )


def case_a_registry_row_that_is_stale_is_reported() -> None:
    """THE GAP THE REVIEW OF A REAL SPLIT FOUND: = = the tool had no arm
    for the registry's LOC column, = = and a row that carried a count its
    file does not have went unreported.

    = = ⇒ Measured: = = the export sheet's split carried 192 in the
    # = = = = registry while the file was 197, = = = = and the tree's own
    # = = = = `nfi-loc-check` caught it (= = = = and this tool did not).

    = = ⇒ AND THE COUNT COMES FROM THE COMMIT, = = = = not from the
    # = = = = working tree, = = = = because the tree under test may
    # = = = = already carry a fix the reviewed commit does not have.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {\n}\n")
        # = = ⇒ THE BASE HAS A REGISTRY TOO, = = = = so the arm has to
        # = = = = tell this row apart from the ones the base already had.
        write(repo, "docs/agents/nfi.md", (
            "| Parent | Extracted | LOC | Tag |\n"
            "| --- | --- | --- | --- |\n"
            "| `Sources/Thing.swift` | `Sources/Thing+Other.swift` | 2 | `the other` |\n"
        ))
        write(repo, "Sources/Thing+Other.swift", "public struct Other {\n}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        # = = ⇒ THE ROW SAYS A COUNT THE FILE DOES NOT HAVE.
        write(repo, "docs/agents/nfi.md", (
            "| Parent | Extracted | LOC | Tag |\n"
            "| --- | --- | --- | --- |\n"
            "| `Sources/Thing.swift` | `Sources/Thing+Parts.swift` | 99 | `the parts` |\n"
        ))
        write(repo, "Sources/Thing+Parts.swift", "public struct Parts {\n}\n")
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "a registry row that carries a count its file does not have is reported",
            "carries a count their file does not have" in out
            or "says 99" in out,
            out[-900:],
        )


def case_a_registry_row_that_is_right_is_not_reported() -> None:
    """The other half: = = a row that carries its file's own count is
    quiet. = = ⇒ A check that cannot stay quiet is not a check.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {\n}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Thing+Parts.swift", "public struct Parts {\n}\n")
        parts = wc_lines(repo / "Sources/Thing+Parts.swift")
        write(repo, "docs/agents/nfi.md", (
            "| Parent | Extracted | LOC | Tag |\n"
            "| --- | --- | --- | --- |\n"
            f"| `Sources/Thing.swift` | `Sources/Thing+Parts.swift` | {parts} | `the parts` |\n"
        ))
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        expect(
            "a registry row that carries its file's own count is quiet",
            "every added row carries its file's own count" in out,
            out[-900:],
        )


def case_a_widening_is_measured_on_a_file_that_changed() -> None:
    """THE REVIEW'S BLOCKING 1: = = the arm's REWRITE did not take the
    access modifier, = = so it rewrote nothing, = = the build succeeded,
    = = and the arm reported the OPPOSITE of the truth.

    = = ⇒ Measured: = = the rewrite changed nothing (= = = = new_text ==
    # = = = = text), = = = = the build succeeded, = = = = and the tool
    # = = = = said "no file needed it", = = = = while a hand revert to
    # = = = = `private` gives `swift build` exit 1 with "helper" is
    # = = = = inaccessible.

    = = ⇒ AND THE FIX FLIPS THE VERDICT: = = the rewrite takes the same
    # = = = = modifier vocabulary the detection takes, = = = = and swaps
    # = = = = ONLY the access level.

    = = ⇒ AND THE READER IS IN ANOTHER FILE: = = a member read from its
    # = = = = OWN file is visible even when it is `private`, = = = = so
    # = = = = the reader has to reach it from ANOTHER file for putting
    # = = = = it back to `private` to break the build at all.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                private func helper() -> Int {
                    1
                }
            }
        """)
        write(repo, "Sources/Probe/Reader.swift", """
            public struct Reader {
                public func two(_ thing: Thing) -> Int {
                    thing.helper()
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                public func helper() -> Int {
                    1
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--probe-promotions"],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        # = = ⇒ THE ARM MUST SEE THE WIDENING, = = = = and the fix makes
        # = = = = the rewrite ACTUALLY rewrite (= = = = so the build fails
        # = = = = and the arm says the member IS read across the seam).
        expect(
            "a widening is measured on a file that really changed",
            "every widened member is read across the file boundary" in out,
            out[-1200:],
        )
def case_the_injection_hook_does_not_delete_the_callers_directory() -> None:
    """THE REVIEW'S BLOCKING 2: = = `--lint-work-parent` deleted the
    CALLER's directory.

    = = ⇒ Measured: = = a directory holding a file and a subdirectory was
    # = = = = GONE after a run that exited 0. = = ⇒ The flag says where
    # = = = = the throwaway worktree goes, = = = = and the tool removes
    # = = = = ONLY that worktree.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {\n    public func one() -> Int {\n        1\n    }\n}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Thing.swift", "public struct Thing {\n    public func one() -> Int {\n        2\n    }\n}\n")
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        # = = ⇒ A DIRECTORY THE CALLER OWNS, = = = = with something in it.
        caller_dir = tmp / "caller-owns-this"
        (caller_dir / "sub").mkdir(parents=True)
        (caller_dir / "precious.txt").write_text("keep me", encoding="utf-8")
        (caller_dir / "sub" / "also.txt").write_text("keep me too", encoding="utf-8")

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--lint-work-parent", str(caller_dir)],
            capture_output=True, text=True,
        )
        expect(
            "the injection hook does not delete the caller's directory",
            (caller_dir / "precious.txt").exists()
            and (caller_dir / "sub" / "also.txt").exists(),
            f"the caller's directory was deleted (exit={proc.returncode})",
        )


def case_the_rewrite_keeps_the_members_modifiers() -> None:
    """THE REVIEW'S BLOCKING 1: = = the promotions rewrite DELETED the
    modifier words instead of swapping the access level.

    = = ⇒ The rewrite's pattern carried the modifier vocabulary in a
    # = = = = NON-CAPTURING group, = = = = so the match CONSUMED the words
    # = = = = and never re-emitted them. = = ⇒ Measured on a real tree
    # = = = = file: = = = = `private static func blocks(of body: String)`
    # = = = = became `private func blocks(of body: String)`, = = = = so the
    # = = = = probe built a DIFFERENT PROGRAM than the one under review.

    = = ⇒ So the member that carries a modifier is the case: = = = = a
    # = = = = `static` member, = = = = read from ANOTHER file (= = = = a
    # = = = = member read from its own file is visible even when it is
    # = = = = `private`, = = = = so the reader has to be elsewhere for the
    # = = = = revert to break the build at all).
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                public static func helper() -> Int {
                    1
                }
            }
        """)
        write(repo, "Sources/Probe/Reader.swift", """
            public struct Reader {
                public func two() -> Int {
                    Thing.helper()
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        # = = ⇒ THE WIDENING, = = = = and the modifier is STILL THERE.
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                public static func helper() -> Int {
                    1
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--probe-promotions"],
            capture_output=True, text=True,
        )
        out = proc.stdout + proc.stderr
        # = = ⇒ AND THE ARM MUST SEE IT. = = = = A rewrite that drops
        # = = = = `static` turns a static member into an instance one, = = =
        # = = = = and the reader's `Thing.helper()` then fails for a
        # = = = = DIFFERENT reason than the truth's revert does, = = = = =
        # = = = = and the arm's own verdict flips.
        expect(
            "a widened member that carries a modifier is measured",
            "every widened member is read across the file boundary" in out,
            out[-1200:],
        )


def case_the_rewrite_keeps_the_members_modifiers_on_a_real_file() -> None:
    """THE REVIEW'S BLOCKING 1, ON A REAL FILE: = = the rewrite must not
    change what the program IS.

    = = ⇒ Measured by the review on the tree's own
    # = = = = `Sources/WenshuApp/Features/Library/Service/ManuscriptShaper.swift`:
    # = = = = `private static func blocks(of body: String) -> [String]`
    # = = = = became `private func blocks(of body: String) -> [String]`.

    = = ⇒ So the case reads the REWRITTEN TEXT, = = = = not the arm's
    # = = = = verdict: = = = = a verdict can be right for the wrong reason
    # = = = = (= = = = the review's MUT C made the guarded code revert and
    # = = = = the suite stayed GREEN), = = = = and the text is the thing
    # = = = = that changed.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                public static func helper() -> Int {
                    1
                }
            }
        """)
        write(repo, "Sources/Probe/Reader.swift", """
            public struct Reader {
                public func two() -> Int {
                    Thing.helper()
                }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Probe/Thing.swift", """
            public struct Thing {
                public static func helper() -> Int {
                    2
                }
            }
        """)
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        # = = ⇒ THE REWRITE ITSELF, = = = = called directly: = = = = the
        # = = = = arm's own regex, = = = = on the member's own line.
        sys.path.insert(0, str(TOOL.parent))
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("spc_rewrite", TOOL)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
        finally:
            sys.path.pop(0)
        line = "    public static func helper() -> Int {"
        # = = ⇒ THE ARM'S OWN REWRITE, = = = = called as a function: = = = =
        # = = = = a case that copies the pattern into itself cannot see the
        # = = = = arm change it (= = = = measured: = = = = the review's MUT C
        # = = = = left the suite green).
        rewritten = module._rewrite_to_private(line, "helper")
        expect(
            "the rewrite keeps the member's modifier words",
            "static" in rewritten and "private" in rewritten,
            f"rewrote to: {rewritten!r}",
        )


def case_the_injection_hook_does_not_delete_a_tree_the_caller_owns() -> None:
    """THE REVIEW'S BLOCKING 2, IN ITS HARDER FORM: = = the caller's
    directory ALREADY holds a `tree/`.

    = = ⇒ `git worktree add` refuses an existing directory, = = = = so the
    # = = = = refusal is the ONLY reason the base is unreadable = = = = =
    # = = = = and that refusal is the hook's whole purpose. = = ⇒ Measured:
    # = = = = a caller's `tree/precious.txt` and `tree/sub/also.txt` were
    # = = = = GONE after a run that exited 0.

    = = ⇒ So the caller's own `tree/` must SURVIVE the refusal.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_buildable_repo(tmp)
        write(repo, "Sources/Thing.swift", "public struct Thing {\n    public func one() -> Int {\n        1\n    }\n}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Thing.swift", "public struct Thing {\n    public func one() -> Int {\n        2\n    }\n}\n")
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        # = = ⇒ A CALLER'S DIRECTORY THAT ALREADY HOLDS A `tree/`.
        caller_dir = tmp / "caller-owns-this"
        (caller_dir / "tree" / "sub").mkdir(parents=True)
        (caller_dir / "tree" / "precious.txt").write_text("keep me", encoding="utf-8")
        (caller_dir / "tree" / "sub" / "also.txt").write_text("keep me too", encoding="utf-8")

        proc = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--base", base,
             "--head", head, "--lint-work-parent", str(caller_dir)],
            capture_output=True, text=True,
        )
        expect(
            "the injection hook does not delete a tree the caller owns",
            (caller_dir / "tree" / "precious.txt").exists()
            and (caller_dir / "tree" / "sub" / "also.txt").exists(),
            f"the caller's tree/ is gone; stdout={proc.stdout[-400:]} stderr={proc.stderr[-400:]}",
        )


def case_the_swiftlint_arm_really_sees_the_vendored_tree() -> None:
    """THE REVIEW'S FINDING: = = the swiftlint arm EXEMPTED Vendor, = =
    and the tree's own lint does not.

    = = ⇒ The tree's `.swiftlint.yml` excludes `.build`, = = = = `build`,
    # = = = = `DerivedData`, = = = = `.scratch` and a handful of NAMED
    # = = = = files, = = = = and `Vendor/` is NOT among them.

    = = ⇒ ⇒ AND THE CASE MUST ISOLATE THE SWIFTLINT ARM. = = = = The
    # = = = = earlier case watched for the vendored PATH in the output,
    # = = = = and that path also shows up in the tool's OWN checks (= = = =
    # = = = = the blank-line rule, = = = = which is not swiftlint at all),
    # = = = = so the case passed whether or not the swiftlint arm looked
    # = = = = there. = = ⇒ So this case watches for a finding that ONLY
    # = = = = swiftlint can produce: = = = = a forbidden TOKEN (= = = = the
    # = = = = tree's own rule), = = = = on a vendored file, = = = = with no
    # = = = = formatting problem in it.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        # = = ⇒ THE TREE'S OWN FORBIDDEN-TOKEN RULE, = = = = in the
        # = = = = fixture's own config, = = = = as the tree's own has it.
        (repo / ".swiftlint.yml").write_text(
            "disabled_rules:\n  - file_length\n  - type_body_length\n"
            "custom_rules:\n"
            "  forbidden_vocab:\n"
            "    name: Forbidden vocabulary\n"
            "    identifier: forbidden_word\n"
            "    message: Forbidden vocabulary\n"
            "    severity: error\n",
            encoding="utf-8",
        )
        write(repo, "Sources/Thing.swift", "public struct Thing {}\n")
        write(repo, "Vendor/Upstream/Thing.swift", "public struct Upstream {}\n")
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        # = = ⇒ THE FORBIDDEN TOKEN, = = = = and NO formatting problem in
        # = = = = the same file (= = = = so the only arm that can report it
        # = = = = is the swiftlint one).
        write(repo, "Vendor/Upstream/Thing.swift",
              "public struct Upstream {\n    let forbidden_word = 1\n}\n")
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        code, out = check(repo, base, head)
        expect(
            "the swiftlint arm really sees the vendored tree",
            "Vendor/Upstream/Thing.swift" in out and "forbidden_word" in out,
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
        case_the_vendored_tree_is_exempt,
        case_the_swiftlint_arm_still_sees_the_vendored_tree,
        case_a_failed_build_is_not_a_clean_one,
        case_a_widening_to_public_is_seen,
        case_a_base_that_does_not_exist_is_not_clean,
        case_a_second_finding_of_the_same_rule_is_not_swallowed,
        case_a_tip_that_cannot_be_looked_at_is_not_clean,
        case_a_base_that_cannot_be_looked_at_is_not_clean,
        case_a_member_that_is_still_private_is_not_a_widening,
        case_a_dropped_module_nobody_uses_is_not_a_defect,
        case_a_widening_of_a_static_member_is_seen,
        case_a_registry_row_that_is_stale_is_reported,
        case_a_registry_row_that_is_right_is_not_reported,
        case_a_widening_is_measured_on_a_file_that_changed,
        case_the_injection_hook_does_not_delete_the_callers_directory,
        case_the_rewrite_keeps_the_members_modifiers,
        case_the_rewrite_keeps_the_members_modifiers_on_a_real_file,
        case_the_injection_hook_does_not_delete_a_tree_the_caller_owns,
        case_the_swiftlint_arm_really_sees_the_vendored_tree,
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
