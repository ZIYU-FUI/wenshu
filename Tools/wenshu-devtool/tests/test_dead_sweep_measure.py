#!/usr/bin/env python3
r"""test_dead_sweep_measure.py - the dead-sweep measurement's own test suite.

Every case runs on a FIXTURE written to a temporary directory, so the
tests stay valid when the real tree changes.

The cases are the things the sweep's own lenses got wrong while they were
being written:

  1. a string interpolation's CODE is code (= a name inside \(...) is a
     use, = not a string's contents).
  2. a name in a COMMENT is not a use (= and a name in a string literal is
     not a use either).
  3. a declaration with no modifier is a declaration (= `struct Foo` is
     read, = not only `public struct Foo`).
  4. a member of a standard-library type (= `extension Notification`) does
     not identify the file that holds it.
  5. a generic name (= `body`, = `state`) is named everywhere, = so it
     cannot prove a use.
  6. the MASKED lens: = one type's member name satisfies another type's
     reference count (= the false negative the sweep found in the tree's
     own gate).

Run:  python3 Tools/wenshu-devtool/tests/test_dead_sweep_measure.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import re
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "dead-sweep-measure.py"


def load_tool():
    """Import dead-sweep-measure.py as a module, whatever its directory is."""
    spec = importlib.util.spec_from_file_location("dead_sweep_measure", TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_tree(files: dict) -> str:
    """Write a fixture tree and return its root."""
    root = Path(tempfile.mkdtemp(prefix="dead-sweep-fixture-"))
    for rel, source in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
    return str(root)


class Failure(Exception):
    """One case failed."""


def check(label: str, condition: bool, detail: str = "") -> None:
    if not condition:
        raise Failure(f"{label}: {detail}")


def case_interpolation_code_is_code(tool) -> None:
    """A name inside a string interpolation is a USE, not string contents."""
    source = 'let message = "the file is \\(fileName) now"\n'
    code = tool.strip_swift(source)
    check(
        "interpolation",
        "fileName" in code,
        f"the interpolation's code was stripped: {code!r}",
    )
    # the string's OWN text is removed
    check(
        "interpolation",
        "the file is" not in code,
        f"the string's contents survived: {code!r}",
    )


def case_comment_is_not_a_use(tool) -> None:
    """A name in a comment is not a use; = a name in a string is not one."""
    source = (
        "// Widget is used here\n"
        'let other = "Widget appears in this string"\n'
    )
    code = tool.strip_swift(source)
    check(
        "comment",
        "Widget" not in code,
        f"a comment or a string counted as a use: {code!r}",
    )


def case_unmodified_declaration_is_read(tool) -> None:
    """`struct Foo` is a declaration, = not only `public struct Foo`."""
    root = write_tree(
        {
            "Sources/WenshuApp/Unmod.swift": "struct PlainType {\n    var x = 1\n}\n",
        }
    )
    names = {name for _, name, _ in tool.decls_of(root + "/Sources/WenshuApp/Unmod.swift")}
    check(
        "unmodified decl",
        "PlainType" in names,
        f"the unmodified struct was not read: {sorted(names)}",
    )


def case_stdlib_extension_does_not_identify(tool) -> None:
    """`extension Notification` names no type of the tree, = so it cannot."""
    source = (
        "extension Notification {\n"
        "    static let wenshuThing = Notification.Name(\"x\")\n"
        "}\n"
    )
    # the decls of the file, read through the tool's own reader
    root = write_tree({"Sources/WenshuApp/Ext.swift": source})
    decls = tool.decls_of(root + "/Sources/WenshuApp/Ext.swift")
    kinds = {name: kind for kind, name, _ in decls}
    check(
        "stdlib extension",
        kinds.get("Notification") == "extension",
        f"the extension target was not read as an extension: {kinds}",
    )


def case_generic_name_is_not_proof(tool) -> None:
    """A generic name (= `body`) is named everywhere, = so it proves nothing."""
    generic = tool.GENERIC if hasattr(tool, "GENERIC") else set()
    check("generic", "body" in generic, "the generic list lost `body`")
    check("generic", "state" in generic, "the generic list lost `state`")


def case_masked_lens(tool) -> None:
    """One type's member name satisfies another type's reference count."""
    # Two files, = each declaring a member with the SAME name on a
    # DIFFERENT type, = and the only call site names the second one.
    root = write_tree(
        {
            "Sources/WenshuApp/First.swift": (
                "extension FirstType {\n"
                "    static func shared() -> FirstType { FirstType() }\n"
                "}\n"
            ),
            "Sources/WenshuApp/Second.swift": (
                "extension SecondType {\n"
                "    static func shared() -> SecondType { SecondType() }\n"
                "}\n"
            ),
            "Sources/WenshuApp/Caller.swift": "let x = SecondType.shared()\n",
        }
    )
    files = tool.production_files(root)
    owners = {}
    for path in files:
        for kind, name, _ in tool.decls_of(path):
            owners.setdefault(name, set()).add(path)
    check(
        "masked lens",
        len(owners.get("shared", set())) == 2,
        f"the two owners were not seen: {owners.get('shared')}",
    )
    # the first file's member is named only by the second type's call site
    first = [p for p in files if p.endswith("First.swift")][0]
    receivers = set()
    for path in files:
        for match in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*shared\b", tool.code_of(path)):
            receivers.add(match.group(1))
    check(
        "masked lens",
        "SecondType" in receivers and "FirstType" not in receivers,
        f"the receivers were not read: {receivers}",
    )
    check(
        "masked lens",
        first not in {p for p in files if p.endswith("Caller.swift")},
        "the fixture is wrong",
    )


def case_production_files_skips_tests(tool) -> None:
    """A test file is never counted as production."""
    root = write_tree(
        {
            "Sources/WenshuApp/Prod.swift": "let a = 1\n",
            "Tests/WenshuAppTests/ProdTests.swift": "let b = 2\n",
            "Sources/WenshuApp/.build/x.swift": "let c = 3\n",
        }
    )
    files = tool.production_files(root)
    rel = [p.replace(root + "/", "") for p in files]
    check("production files", "Sources/WenshuApp/Prod.swift" in rel, f"{rel}")
    check("production files", not any("Tests/" in p for p in rel), f"{rel}")
    check("production files", not any(".build" in p for p in rel), f"{rel}")


def case_call_sites_exclude_the_declaration(tool) -> None:
    """A declaration line is not a use of itself (= the call-site count).

    The tree's own `DiffUtil` has ONE definition and TWO call sites; = =
    a count that includes the definition over-reports by one.
    """
    root = write_tree(
        {
            "Sources/WenshuApp/Diff.swift": (
                "func computeUnifiedDiff(old: String) -> String { old }\n"
            ),
            "Sources/WenshuApp/Caller.swift": (
                "let a = computeUnifiedDiff(old: \"x\")\n"
            ),
        }
    )
    files = tool.production_files(root)
    code = {p: tool.code_of(p) for p in files}
    sites = tool.count_call_sites(code, "computeUnifiedDiff", ("func ", "static func "))
    check("call sites", sites == 1, f"expected 1 call site, got {sites}")
    with_def = tool.count_call_sites(code, "computeUnifiedDiff", ())
    check("call sites", with_def == 2, f"expected 2 lines, got {with_def}")


def case_the_declaring_file_can_be_excluded(tool) -> None:
    """Nothing outside the declaring file reaches it (= the TreeHistory case).

    The tree's `TreeHistory` is called three times INSIDE its own file and
    zero times outside, = = so "no outside caller" is a different fact from
    "no caller".
    """
    root = write_tree(
        {
            "Sources/WenshuApp/TreeHistory.swift": (
                "final class TreeHistory {\n"
                "    init(cap: Int = TreeHistory.defaultCap) {}\n"
                "    static let defaultCap = 10\n"
                "    var history: TreeHistory? { nil }\n"
                "    func copy() -> TreeHistory { history! }\n"
                "}\n"
            ),
            "Sources/WenshuApp/Other.swift": "let b = 1\n",
        }
    )
    files = tool.production_files(root)
    code = {p: tool.code_of(p) for p in files}
    owner = [p for p in files if p.endswith("TreeHistory.swift")][0]
    inside = tool.count_call_sites(code, "TreeHistory", ("class ", "final class "))
    outside = tool.count_call_sites(
        code, "TreeHistory", ("class ", "final class "), exclude_path=owner
    )
    check("outside callers", inside == 3, f"expected 3 inside, got {inside}")
    check("outside callers", "final class TreeHistory" not in
          [ln for p in files for ln in tool.code_of(p).split("\n") if "TreeHistory" in ln
           and ln.strip().startswith("final class")],
          "the fixture is wrong")
    check("outside callers", outside == 0, f"expected 0 outside, got {outside}")


def case_string_content_survives_the_comments_lens(tool) -> None:
    """A shape inside a string literal survives the comments-only lens.

    The subprocess path (`/usr/bin/codesign`) and the localized menu title
    live inside literals, = = so the code lens (= which erases string
    content) would read them as zero sites.
    """
    source = (
        'let path = "/usr/bin/codesign"\n'
        "// a comment mentioning /usr/bin/codesign\n"
        'Button(String(localized: "menu.edit.undo"), action: {})\n'
    )
    with_strings = tool.strip_comments(source)
    check("string content", "/usr/bin/codesign" in with_strings, "the literal was erased")
    check("string content", "menu.edit.undo" in with_strings, "the literal was erased")
    check("string content", "codesign" not in tool.strip_swift(source), "the code lens kept it")
    check("string content", "comment mentioning" not in with_strings, "the comment stayed")


def case_hig_quote_must_be_a_sentence_span(tool) -> None:
    """A HIG quote must land on a sentence boundary (= not a truncation).

    The round-one quote stopped at "on a Mac", = = so the test is that the
    quote's OWN last character is a sentence end, = = and that it begins
    at one.
    """
    page = (
        "## Best practices **Prefer the system-provided edit menu.** People are "
        "familiar with the contents and behavior of the system-provided "
        "component, so creating a custom menu that presents the same commands "
        "is redundant and likely to be confusing. For a list of standard edit "
        "menu commands, see the reference."
    )
    flat = " ".join(page.split())
    whole = (
        "**Prefer the system-provided edit menu.** People are familiar with "
        "the contents and behavior of the system-provided component, so "
        "creating a custom menu that presents the same commands is redundant "
        "and likely to be confusing."
    )
    truncated = whole[:-1]
    check("hig quote", tool.page_span(flat, whole) != "", "the whole quote was rejected")
    check("hig quote", tool.page_span(flat, truncated) == "", "a truncation passed")
    # = = a quote that starts mid-sentence is rejected too
    mid = "People are familiar with the contents and behavior"
    check("hig quote", tool.page_span(flat, mid) == "", "a mid-sentence quote passed")


CASES = [
    ("interpolation code is code", case_interpolation_code_is_code),
    ("a comment is not a use", case_comment_is_not_a_use),
    ("an unmodified declaration is read", case_unmodified_declaration_is_read),
    ("a stdlib extension does not identify", case_stdlib_extension_does_not_identify),
    ("a generic name is not proof", case_generic_name_is_not_proof),
    ("the masked lens sees two owners", case_masked_lens),
    ("production files skip the tests", case_production_files_skips_tests),
    ("a declaration is not a call site", case_call_sites_exclude_the_declaration),
    ("the declaring file can be excluded", case_the_declaring_file_can_be_excluded),
    ("string content survives the comments lens", case_string_content_survives_the_comments_lens),
    ("a HIG quote is a sentence span", case_hig_quote_must_be_a_sentence_span),
]


def main() -> int:
    tool = load_tool()
    failed = []
    for label, case in CASES:
        try:
            case(tool)
        except Failure as error:
            failed.append(str(error))
            print(f"FAIL  {label}: {error}")
        except Exception as error:  # noqa: BLE001 - a crash is a failure
            failed.append(f"{label}: {error}")
            print(f"ERROR {label}: {error}")
        else:
            print(f"ok    {label}")
    if failed:
        print(f"\n{len(failed)} case(s) failed")
        return 1
    print(f"\nall {len(CASES)} case(s) passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
