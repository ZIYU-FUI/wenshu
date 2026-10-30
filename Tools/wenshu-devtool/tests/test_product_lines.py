"""The product-lines declaration, and the two lines it declares.

WHY THIS SUITE EXISTS

The mobile client used to live in a sibling repository, so every gate
carried its own constants and the two copies drifted. The client now
lives in this repo under `Mobile/`, so there is ONE copy of every tool
and TWO product lines to declare. This suite pins the declaration and
the two facts that broke when the client moved:

1. A path in a card body is relative to its PACKAGE, so the two lines
   must measure the same work the same way.
2. The package boundary of EVERY line counts (= a card that writes the
   mobile package is as deep a change as one that writes a desktop
   package).

Run: python3 Tools/wenshu-devtool/tests/test_product_lines.py
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    if got == want:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}\n        got:  {got!r}\n        want: {want!r}")
        FAILURES.append(name)


def load(name: str):
    path = Path(__file__).resolve().parent.parent / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    # Register it before executing: a dataclass whose field annotation is
    # a forward reference looks the module up in sys.modules.
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


pl = load("product_lines")

# The two lines, and their boards.
check("the repo carries two product lines", len(pl.PRODUCT_LINES), 2)
check(
    "the boards are the desktop board and the mobile board",
    pl.BOARDS,
    ("wenshu-par", "wenshu-mob-par"),
)
check("the default board is the desktop board", pl.DEFAULT_BOARD, "wenshu-par")

# A path in a card body belongs to the line whose package it is in.
check(
    "a desktop path belongs to the desktop line",
    pl.line_of("Sources/WenshuApp/App/ClientShell.swift").name,
    "desktop",
)
check(
    "a mobile path belongs to the mobile line",
    pl.line_of("Sources/WenshuMobileApp/App/ClientShell.swift").name,
    "mobile",
)
check(
    "a mobile kit path belongs to the mobile line",
    pl.line_of("Sources/WenshuMobileKit/Companion/LinkCommand.swift").name,
    "mobile",
)
check(
    "a path that names neither line belongs to neither",
    pl.line_of("Tools/wenshu-devtool/ticket_tier.py"),
    None,
)

# THE BUG THIS FIXES: the same six files must measure as TWO areas on
# both lines. With the `Mobile/` prefix left on, the area cut fell
# through to the file-level branch and the same work measured SIX.
MOBILE_SIX = [
    "Sources/WenshuMobileApp/Features/Library/Model/LibraryItem.swift",
    "Sources/WenshuMobileApp/Features/Library/Service/LibraryStore.swift",
    "Sources/WenshuMobileApp/Features/Library/View/ChapterReaderView.swift",
    "Sources/WenshuMobileApp/Features/Connection/Model/PairingCode.swift",
    "Sources/WenshuMobileApp/Features/Connection/Service/ConnectionStore.swift",
    "Sources/WenshuMobileApp/App/ClientShell.swift",
]
DESKTOP_SIX = [
    "Sources/WenshuApp/Features/Library/Model/LibraryItem.swift",
    "Sources/WenshuApp/Features/Library/Service/LibraryStore.swift",
    "Sources/WenshuApp/Features/Library/View/ChapterReaderView.swift",
    "Sources/WenshuApp/Features/Connection/Model/PairingCode.swift",
    "Sources/WenshuApp/Features/Connection/Service/ConnectionStore.swift",
    "Sources/WenshuApp/App/ClientShell.swift",
]
check(
    "the same six files measure as two areas on the mobile line",
    sorted(pl.areas_of(MOBILE_SIX)),
    ["Sources/WenshuMobileApp/App", "Sources/WenshuMobileApp/Features"],
)
check(
    "the same six files measure as two areas on the desktop line",
    sorted(pl.areas_of(DESKTOP_SIX)),
    ["Sources/WenshuApp/App", "Sources/WenshuApp/Features"],
)
check(
    "the repo-relative form measures the same as the package-relative form",
    sorted(pl.areas_of(["Mobile/" + p for p in MOBILE_SIX])),
    sorted(pl.areas_of(MOBILE_SIX)),
)

# The two forms of one file are the same file.
check(
    "the repo-relative form of a mobile path strips to its package form",
    pl.package_relative("Mobile/Sources/WenshuMobileApp/App/ClientShell.swift"),
    "Sources/WenshuMobileApp/App/ClientShell.swift",
)
check(
    "a package-relative path is left alone",
    pl.package_relative("Sources/WenshuMobileApp/App/ClientShell.swift"),
    "Sources/WenshuMobileApp/App/ClientShell.swift",
)
check(
    "the package form of a mobile path resolves back to the repo",
    pl.repo_relative("Sources/WenshuMobileApp/App/ClientShell.swift"),
    "Mobile/Sources/WenshuMobileApp/App/ClientShell.swift",
)
check(
    "the repo form of a desktop path is itself",
    pl.repo_relative("Sources/WenshuApp/App/ClientShell.swift"),
    "Sources/WenshuApp/App/ClientShell.swift",
)

# Sources and tests, on both lines.
check("a mobile source file is a source", pl.is_source(MOBILE_SIX[0]), True)
check("a desktop source file is a source", pl.is_source(DESKTOP_SIX[0]), True)
check(
    "a mobile test file is a test",
    pl.is_test("Tests/WenshuMobileTests/ClientShellTests.swift"),
    True,
)
check(
    "a nested test target is a test, not a source",
    pl.is_test("Sources/WenshuAgent/Tests/WenshuAgentTests/ConductorSessionScopeTests.swift"),
    True,
)
check(
    "a nested test target is not a source",
    pl.is_source("Sources/WenshuAgent/Tests/WenshuAgentTests/ConductorSessionScopeTests.swift"),
    False,
)

# THE SECOND BUG THIS FIXES: the package boundary of every line counts.
# On the desktop-only copy, a card writing the mobile package was rated
# T2 with the reason "no deep-work signal", because the boundary list
# knew only the desktop packages.
check(
    "the mobile package is a package boundary",
    pl.is_package_boundary("Sources/WenshuMobileKit/Companion/LinkCommand.swift"),
    True,
)
check(
    "the desktop package is a package boundary",
    pl.is_package_boundary("Sources/WenshuAgent/Core/Agent/Agent.swift"),
    True,
)
check(
    "the mobile app facade is not a package boundary",
    pl.is_package_boundary("Sources/WenshuMobileApp/App/ClientShell.swift"),
    False,
)
check(
    "the desktop app facade is not a package boundary",
    pl.is_package_boundary("Sources/WenshuApp/App/ClientShell.swift"),
    False,
)

# The path shape a card writes in.
check(
    "a mobile card path is recognised",
    bool(pl.PATH_RE.findall("write `Sources/WenshuMobileApp/App/ClientShell.swift`")),
    True,
)
check(
    "the repo-relative mobile path is recognised",
    bool(pl.PATH_RE.findall("write `Mobile/Sources/WenshuMobileApp/App/ClientShell.swift`")),
    True,
)
check(
    "a desktop card path is recognised",
    bool(pl.PATH_RE.findall("write `Sources/WenshuApp/App/ClientShell.swift`")),
    True,
)
check(
    "the repo-relative mobile path is recognised IN FULL",
    pl.PATH_RE.findall("write `Mobile/Sources/WenshuMobileApp/App/ClientShell.swift`"),
    ["Mobile/Sources/WenshuMobileApp/App/ClientShell.swift"],
)

# The board database of each line.
check(
    "the desktop board's database is the desktop board's",
    pl.board_db("wenshu-par").endswith("wenshu-par/kanban.db"),
    True,
)
check(
    "the mobile board's database is the mobile board's",
    pl.board_db("wenshu-mob-par").endswith("wenshu-mob-par/kanban.db"),
    True,
)

print()
if FAILURES:
    print(f"product_lines: {len(FAILURES)} case(s) FAILED")
    for name in FAILURES:
        print(f"  - {name}")
    sys.exit(1)
print("product_lines: every case passed")
