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


def case_swiftlint_uses_the_under_test_repo_config() -> None:
    """THE REVIEW'S BLOCKING 1: = = swiftlint resolves `.swiftlint.yml`
    from the WORKING DIRECTORY, = = and not from the tree it is given.

    = = ⇒ So the case puts a rule the repo DISABLES into the file it
    # = = checks, = = and the rule is only silent if the tool passed the
    # = = repo's own config. = = And the case runs the tool from a
    # = = directory whose own config DISABLES NOTHING, = = = = so a tool
    # = = that let swiftlint find its own config reads the rule.

    = = ⇒ AND THE COUNTER-CASE: = = the same rule in a repo whose config
    # = = does not disable it IS reported.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        repo = make_repo(tmp)
        # = = The repo DISABLES the rule.
        (repo / ".swiftlint.yml").write_text(
            "disabled_rules:\n  - file_length\n", encoding="utf-8"
        )
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
        commit(repo, "tip")
        head = git(repo, "rev-parse", "HEAD").strip()

        # = = A LONG file: = = over the rule's limit.
        long_body = "public struct Thing {\n" + "".join(
            f"    public func f{i}() {{}}\n" for i in range(500)
        ) + "}\n"
        (repo / "Sources/Thing.swift").write_text(long_body, encoding="utf-8")
        commit(repo, "a long file")
        long_head = git(repo, "rev-parse", "HEAD").strip()

        # = = ⇒ THE TOOL RUNS FROM A DIRECTORY WITH NO `.swiftlint.yml`,
        # = = = = because that is the situation the review measured: = =
        # = = = = a run from elsewhere read no config, = = = = and the
        # = = = = repo's disabled rules came back to life. = = ⇒ So the
        # = = = = cwd here has no config of its own, = = = = and only the
        # = = = = tool's own handling of the under-test repo's config can
        # = = = = keep the rule disabled.
        elsewhere = tmp / "elsewhere"
        elsewhere.mkdir()
        code, out = check(repo, base, long_head, cwd=elsewhere)
        expect(
            "the under-test repo's OWN swiftlint config is used (= = its disabled rules stay disabled)",
            "file_length" not in out,
            out,
        )

        # = = AND THE COUNTER-CASE: = = a repo that does NOT disable it.
        repo2 = make_repo(tmp / "b")
        (repo2 / ".swiftlint.yml").write_text(
            "disabled_rules: []\n", encoding="utf-8"
        )
        write(repo2, "Sources/Thing.swift", "public struct Thing {}\n")
        commit(repo2, "base")
        b2 = git(repo2, "rev-parse", "HEAD").strip()
        (repo2 / "Sources/Thing.swift").write_text(long_body, encoding="utf-8")
        commit(repo2, "tip")
        h2 = git(repo2, "rev-parse", "HEAD").strip()
        code2, out2 = check(repo2, b2, h2, cwd=elsewhere)
        expect(
            "a repo that does NOT disable the rule reports it (= = the rule is really running)",
            code2 != 0 and "file_length" in out2,
            out2,
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
        write(repo, "Sources/Thing.swift", """
            import SwiftUI

            public struct Thing {
                public func day() -> Date { Date() }
                public func other() -> Date { Date() }
                public func third() -> Date { Date() }
            }
        """)
        commit(repo, "base")
        base = git(repo, "rev-parse", "HEAD").strip()
        write(repo, "Sources/Thing.swift", """
            import SwiftUI

            public struct Thing {
                public func day() -> Date { Date() }
                public func other() -> Date { Date() }
                public func third() -> Date { Date() }
                public func fourth() -> Date { Date() }
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


def main() -> int:
    print("split_pre_check: every check has a positive control")
    for case in (
        case_removed_foundation_extension_member,
        case_orphan_blank_line,
        case_doc_comment_downgraded,
        case_clean_tree_is_green,
        case_pre_existing_finding_is_not_reported,
        case_promotion_not_needed_is_reported,
        case_swiftlint_uses_the_under_test_repo_config,
        case_removed_import_needs_the_base_to_have_had_it,
        case_found_by_declaration_not_by_name,
        case_a_finding_that_moved_is_not_a_new_finding,
        case_the_link_needs_the_declarations_and_not_the_name,
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
