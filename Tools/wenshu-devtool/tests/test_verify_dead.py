#!/usr/bin/env python3
"""test_verify_dead.py — the dead-code checker's own test suite.

Every case runs on a FIXTURE written to a temporary directory, so proving
the checker fails never means breaking the real tree.

The cases are the five things the checker got wrong:

  1. the auto-scan looks in directories that do not exist => it scans zero
     files and reports the tree clean (= the gate passes over an empty
     sweep). A fixture view directory with one Swift file in it must be
     found, and the directory must be named.
  2. a type whose members are read in another file is LIVE, even when its
     name appears in no other file (= the WordCount shape).
  3. a type that is the RETURN TYPE of a function another file calls is
     LIVE (= the WikiLinkNavigationResult shape). The same type is DEAD
     when nothing calls that function (= a promise is not a use).
  4. a type with NO reader anywhere is still a deletion candidate, and the
     checker still exits non-zero for it.
  5. the shapes of the real tree's live types stay alive.

Run:  python3 Tools/wenshu-devtool/tests/test_verify_dead.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / 'verify-dead.py'

# The candidate lines the checker prints under the deletion-candidate
# header: "  <path>: <kind> <Name>".
CANDIDATE_RE = re.compile(r'^  \S+: (?:struct|enum|class|protocol) (\w+)$')

# The per-declaration lines the checker prints in verbose mode:
# "    ✓ struct   Name    (ext=0, int=2) <why it is alive>".
FINDING_RE = re.compile(
    r'^    [✓✗] (\w+)\s+(\w+)\s+\(ext=\d+, int=\d+\)\s*(.*)$')


# --------------------------------------------------------------- fixtures

# A type whose members another file reads. The name never appears in the
# reader (= the WordCount shape from the real tree).
WORD_COUNT = """
import Foundation

struct WordCount: Equatable, Sendable {
    let charactersNoSpaces: Int
}

enum WordCounter {
    static func count(_ content: String) -> WordCount {
        WordCount(charactersNoSpaces: content.count)
    }
}
"""

# The reader: the type's name never appears here.
WORD_COUNT_READER = """
import Foundation

func editorWordCount() -> Int {
    WordCounter.count("draft").charactersNoSpaces
}
"""

# A type that is the return type of a function. The function is never
# called inside its own file (= the WikiLinkNavigationResult shape).
NAVIGATION_RESULT = """
import Foundation

struct WikiLinkNavigationResult: Equatable, Sendable {
    let body: String
}

func navigate(to name: String) -> WikiLinkNavigationResult? {
    nil
}
"""

# The caller: the type's name never appears here.
NAVIGATION_CALLER = """
import Foundation

func openWikiLink(name: String) {
    if let result = navigate(to: name) {
        print(result.body)
    }
}
"""

# A type nothing reaches.
ORPHAN = """
import Foundation

struct OrphanPayload {
    let payload: String
}
"""

# A type used only by the file that owns it (= the inspector shape: the
# three inspector types of the real tree are read by their own view).
OWNED_BY_OWN_FILE = """
import Foundation

struct InspectorStatusSelection: Identifiable, Equatable {
    let id: String
}

struct InspectorStatusView {
    var selection: InspectorStatusSelection?
}
"""

# The host of a view (= the owner of the view). It sits outside the
# scanned directories, so the scan still counts the view file alone, and
# the view stays alive because this file reads it.
VIEW_HOST = """
import SwiftUI

struct DemoHost {
    var view: DemoView {
        DemoView()
    }
}
"""

# The host of the inspector view (= the reader that keeps the view alive).
INSPECTOR_HOST = """
import SwiftUI

struct EditorHost {
    var inspector: InspectorStatusView {
        InspectorStatusView()
    }
}
"""


# --------------------------------------------------------------- helpers

def run_tool(root: Path, *args: str) -> tuple[int, str]:
    """Run the checker on a fixture tree. Returns (returncode, output)."""
    result = subprocess.run(
        [sys.executable, str(TOOL), '--ui-components', '--cwd', str(root),
         *args],
        capture_output=True, text=True, cwd=str(root))
    return result.returncode, result.stdout + result.stderr


def candidates(output: str) -> list[str]:
    """The deletion candidates the checker reported (= the type names)."""
    names = []
    in_section = False
    for line in output.splitlines():
        if 'deletion candidates' in line:
            in_section = True
            continue
        if not in_section:
            continue
        match = CANDIDATE_RE.match(line)
        if match:
            names.append(match.group(1))
    return names


def finding(output: str, name: str) -> str:
    """The line the checker printed for one declaration (= '' if none)."""
    for line in output.splitlines():
        match = FINDING_RE.match(line)
        if match and match.group(2) == name:
            return line
    return ''


def reason(output: str, name: str) -> str:
    """Why the checker called one declaration alive (= '' if it did not)."""
    line = finding(output, name)
    match = FINDING_RE.match(line)
    return match.group(3) if match else ''


# --------------------------------------------------------------- cases

def case_1_auto_scan_finds_the_real_tree():
    """The auto-scan scans the view directories, not an empty sweep.

    The old auto-scan looked in Sources/WenshuApp/UI and
    Sources/WenshuApp/Views, which do not exist: it scanned zero files
    and printed "none found = the catalog is clean".
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        view = root / 'Sources/WenshuApp/Features/Demo/View'
        view.mkdir(parents=True)
        (view / 'DemoView.swift').write_text(
            'import SwiftUI\n\n'
            'struct DemoView: View {\n'
            '    var body: some View {\n'
            '        Text("demo")\n'
            '    }\n'
            '}\n', encoding='utf-8')
        host = root / 'Sources/WenshuApp/Features/Demo/Service'
        host.mkdir(parents=True)
        (host / 'DemoHost.swift').write_text(VIEW_HOST, encoding='utf-8')
        code, out = run_tool(root)
        ok = ('Summary: 1 files' in out
              and 'Sources/WenshuApp/Features/Demo/View' in out
              and code == 0)
        return ok, (f'expected 1 scanned file and the directory named, '
                    f'exit 0; got exit={code}:\n{out}')


def case_2_member_read_in_another_file_is_alive():
    """A type whose members another file reads is live.

    Its name appears in no other file, so a name match alone reads it as
    unreachable.
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        view = root / 'Sources/WenshuApp/Features/Editor/View'
        view.mkdir(parents=True)
        (view / 'WordCounter.swift').write_text(WORD_COUNT, encoding='utf-8')
        (view / 'EditorView.swift').write_text(WORD_COUNT_READER,
                                               encoding='utf-8')
        code, out = run_tool(root, '--verbose')
        named = 'WordCount' not in candidates(out)
        why = reason(out, 'WordCount')
        member = '.charactersNoSpaces' in why
        ok = named and member and code == 0
        return ok, (f'expected WordCount alive with a member-read reason, '
                    f'candidates={candidates(out)} reason={why!r} '
                    f'exit={code}')


def case_3_return_type_of_a_called_function_is_alive():
    """A type that is the return type of a called function is live.

    The same type is dead when nothing calls that function: the promise
    is not a use.
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        view = root / 'Sources/WenshuApp/Features/Editor/View'
        view.mkdir(parents=True)
        (view / 'EditorActions.swift').write_text(NAVIGATION_RESULT,
                                                  encoding='utf-8')
        (view / 'EditorView.swift').write_text(NAVIGATION_CALLER,
                                               encoding='utf-8')
        code, out = run_tool(root, '--verbose')
        not_flagged = 'WikiLinkNavigationResult' not in candidates(out)
        why = reason(out, 'WikiLinkNavigationResult')
        returned = 'returned by' in why
        ok = not_flagged and returned and code == 0
        detail = (f'expected WikiLinkNavigationResult alive with a '
                  f'return-type reason, candidates={candidates(out)} '
                  f'reason={why!r} exit={code}')

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        view = root / 'Sources/WenshuApp/Features/Editor/View'
        view.mkdir(parents=True)
        (view / 'EditorActions.swift').write_text(NAVIGATION_RESULT,
                                                  encoding='utf-8')
        code2, out2 = run_tool(root, '--verbose')
        flagged = 'WikiLinkNavigationResult' in candidates(out2)
        ok = ok and flagged and code2 != 0
        detail += (f' | without a caller it must be flagged, '
                   f'candidates={candidates(out2)} exit={code2}')
    return ok, detail


def case_4_type_with_no_reader_is_still_reported():
    """A type with no reader anywhere is still a deletion candidate.

    The direction the fix must not lose: a check that stops reporting
    anything passes the first command trivially.
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        view = root / 'Sources/WenshuApp/Features/Editor/View'
        view.mkdir(parents=True)
        (view / 'OrphanView.swift').write_text(ORPHAN, encoding='utf-8')
        code, out = run_tool(root)
        flagged = 'OrphanPayload' in candidates(out)
        ok = flagged and code != 0
        return ok, (f'expected OrphanPayload reported with a non-zero exit, '
                    f'candidates={candidates(out)} exit={code}')


def case_5_the_live_shapes_stay_alive():
    """The shapes of the real tree's live types stay alive.

    The real tree's seven live types are reached three ways: a member read
    in another file, a value returned by a function another file calls, and
    a type read by the file that owns it. All three must stay alive, and
    the checker must exit 0 over them.
    """
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        view = root / 'Sources/WenshuApp/Features/Editor/View'
        view.mkdir(parents=True)
        (view / 'WordCounter.swift').write_text(WORD_COUNT, encoding='utf-8')
        (view / 'EditorActions.swift').write_text(NAVIGATION_RESULT,
                                                  encoding='utf-8')
        (view / 'EditorView.swift').write_text(
            WORD_COUNT_READER + NAVIGATION_CALLER, encoding='utf-8')
        (view / 'InspectorStatusView.swift').write_text(OWNED_BY_OWN_FILE,
                                                        encoding='utf-8')
        host = root / 'Sources/WenshuApp/Features/Editor/Service'
        host.mkdir(parents=True)
        (host / 'EditorHost.swift').write_text(INSPECTOR_HOST,
                                                encoding='utf-8')
        code, out = run_tool(root, '--verbose')
        flagged = candidates(out)
        ok = not flagged and code == 0
        return ok, (f'expected no deletion candidate and exit 0, '
                    f'candidates={flagged} exit={code}')


CASES = [
    ('the auto-scan finds the real tree',
     case_1_auto_scan_finds_the_real_tree),
    ('a member read in another file is alive',
     case_2_member_read_in_another_file_is_alive),
    ('a return type of a called function is alive',
     case_3_return_type_of_a_called_function_is_alive),
    ('a type with no reader is still reported',
     case_4_type_with_no_reader_is_still_reported),
    ('the live shapes stay alive',
     case_5_the_live_shapes_stay_alive),
]


def main() -> int:
    passed = 0
    failed = 0
    for name, case in CASES:
        try:
            ok, detail = case()
        except Exception as exc:  # a case that raises is a failure, not a crash
            ok, detail = False, f'raised {type(exc).__name__}: {exc}'
        if ok:
            passed += 1
            print(f'PASS  {name}')
        else:
            failed += 1
            print(f'FAIL  {name}: {detail}')
    print(f'{passed} passed, {failed} failed, {len(CASES)} total')
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
