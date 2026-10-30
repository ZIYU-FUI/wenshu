"""The product lines this repo carries, declared ONCE.

WHY THIS FILE EXISTS

The mobile client used to live in a sibling repository, so every gate had
its own copy of the tool and its own copy of the constants that name the
product line: `REPO`, the board slug, the source roots, the package
paths. Keeping two copies honest cost a card every time a rule changed
(the review-gate fix this week was one card on the desktop and another to
port it), and the two copies drifted: the mobile copy knew
`Sources/WenshuMobileKit/` and the desktop copy knew
`Sources/WenshuAgent/`, and a rule that read one of them was silently
wrong in the other repo.

The client now lives in this repo, under `Mobile/`, as a second SwiftPM
package beside the desktop one. So there is ONE repository, ONE copy of
every tool, and TWO product lines to declare. This module is that
declaration. Every tool that needs to know "where does a source file
live" or "which board is this card on" reads it HERE, so a rule that
names a path names it in the vocabulary both lines share.

THE TWO LINES

    desktop   Sources/ + Tests/        board wenshu-par
    mobile    Mobile/Sources/ + Mobile/Tests/   board wenshu-mob-par

A PATH IN A CARD BODY IS RELATIVE TO ITS PACKAGE

The two lines are two SwiftPM packages in one repo, and a card names a
file inside the package it works in. So a mobile card says
`Sources/WenshuMobileApp/Features/Library/Model/LibraryItem.swift` and
the desktop card says
`Sources/WenshuApp/Features/Library/Model/LibraryItem.swift`. The card's
path is NOT repo-relative: the same repo-relative file is
`Mobile/Sources/WenshuMobileApp/...` and
`Sources/WenshuApp/...`.

That is why the gates strip the package prefix before they measure a
path. Measured 2026-10-30: with the `Mobile/` prefix left on, the same
six files measured SIX areas instead of TWO, because the area cut
(`path[:3]`) fell through to the file-level branch on the extra
directory ⇒ every mobile card priced as a T3 it did not earn.

So: `package_relative(path)` is the function every measuring rule calls
first. It answers "which line is this path in, and what does it look
like inside that line" — and after it, both lines look the same.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class ProductLine:
    """One product line's layout inside this repo."""

    name: str
    # The board slug its cards live on.
    board: str
    # The repo-relative directory the line's package sits in (= "" for the
    # desktop line, whose package is the repo root).
    root: str
    # The repo-relative source and test roots, as prefixes.
    source_roots: tuple[str, ...]
    test_roots: tuple[str, ...]
    # The line's package boundaries, relative to the PACKAGE (= so the
    # mobile line's boundary reads `Sources/WenshuMobileKit/`, not
    # `Mobile/Sources/...`). A card names its files inside the package,
    # so this is the form the comparison sees.
    package_paths: tuple[str, ...]
    # The line's own source directories, relative to the package root.
    # A card names its files with these, so a path that starts with one
    # belongs to this line.
    source_dirs: tuple[str, ...] = field(default=())

    def matches(self, path: str) -> bool:
        """Whether a card-named path belongs to this line."""
        if self.source_dirs:
            return any(path.startswith(d) for d in self.source_dirs)
        return any(path.startswith(r) for r in self.source_roots)


# The desktop line: the repo root IS the package.
DESKTOP = ProductLine(
    name="desktop",
    board="wenshu-par",
    root="",
    source_roots=("Sources/",),
    test_roots=("Tests/",),
    package_paths=(
        "Sources/WenshuAgent/",
        "Sources/WenshuData/",
    ),
    source_dirs=(
        "Sources/WenshuApp/",
        "Sources/WenshuAgent/",
        "Sources/WenshuData/",
    ),
)

# The mobile line: its package sits under Mobile/, one directory deep.
MOBILE = ProductLine(
    name="mobile",
    board="wenshu-mob-par",
    root="Mobile/",
    source_roots=("Mobile/Sources/",),
    test_roots=("Mobile/Tests/",),
    package_paths=(
        "Sources/WenshuMobileKit/",
    ),
    source_dirs=(
        "Sources/WenshuMobileApp/",
        "Sources/WenshuMobileKit/",
    ),
)

PRODUCT_LINES: tuple[ProductLine, ...] = (DESKTOP, MOBILE)

# The boards the repo carries, in the order a sweep visits them.
BOARDS: tuple[str, ...] = tuple(line.board for line in PRODUCT_LINES)

# The default board (= the one a tool reads when the caller names none).
DEFAULT_BOARD = DESKTOP.board


def line_of(path: str) -> "ProductLine | None":
    """The line a card-named path belongs to, or None when it names neither.

    A card names its files inside its own package, so the test is on the
    line's OWN source directories (= `Sources/WenshuMobileApp/...` for the
    mobile line), not on the repo-relative roots (= `Mobile/Sources/`),
    because a card never writes the repo-relative form.
    """
    for line in PRODUCT_LINES:
        if line.matches(path):
            return line
    return None


def package_relative(path: str) -> str:
    """The path as it reads INSIDE its package, whatever the line.

    A mobile card names `Sources/WenshuMobileApp/Features/...` and the
    desktop card names `Sources/WenshuApp/Features/...`. Both are already
    package-relative, so this returns them unchanged.

    A path written repo-relative (`Mobile/Sources/WenshuMobileApp/...`)
    has the line's root on it, and that root is dropped so the two forms
    of one file measure the same.

    A path that names no line is returned unchanged: an unknown path must
    not be silently rewritten into a known one.
    """
    if path.startswith(MOBILE.root) and path not in (MOBILE.root,):
        return path[len(MOBILE.root):]
    return path


def repo_relative(path: str) -> str:
    """The path as it reads in the REPO, whatever the line.

    The inverse of `package_relative`: a mobile card's
    `Sources/WenshuMobileApp/Features/...` becomes
    `Mobile/Sources/WenshuMobileApp/Features/...`.

    This is the form a file check needs (= does the file the card names
    exist where the card says it does), and the form the `.gitattributes`
    merge-driver lookup needs (= the driver is keyed on the repo path).
    """
    line = line_of(path)
    if line is None or not line.root:
        return path
    return line.root + path


def is_source(path: str) -> bool:
    """Whether a path is a source file of some line.

    A path under `Sources/` IS a source, INCLUDING a nested test target
    (= `Sources/WenshuAgent/Tests/WenshuAgentTests/...`): the tier has
    always counted it as one, and the tier's measured numbers must not
    move when the measurement changes where it READS its inputs from.
    Excluding it here would quietly re-rate every card that names one.

    The path is read as it reads INSIDE its package, so the mobile line's
    files count as sources exactly as the desktop line's do.
    """
    relative = package_relative(path)
    return relative.startswith("Sources/") and path.endswith(".swift")


def is_test(path: str) -> bool:
    """Whether a path is a test file of some line.

    A TEST FILE IS A PATH WITH A `Tests/` SEGMENT, not a path that starts
    with `Tests/`: the packages nest their test target inside the package
    (= `Sources/WenshuAgent/Tests/WenshuAgentTests/...`), so a rule that
    tests the prefix misses them.
    """
    return "/Tests/" in f"/{package_relative(path)}" and path.endswith(".swift")


def is_package_boundary(path: str) -> bool:
    """Whether a card that writes this path changes a package boundary.

    The boundary is the line's OWN package list, so a line that adds a
    package declares it here once and every rule that asks this question
    sees it.
    """
    relative = package_relative(path)
    for line in PRODUCT_LINES:
        if any(relative.startswith(p) for p in line.package_paths):
            return True
    return False


def area_of(path: str) -> str:
    """The area (= a directory) a file lives in, inside its package.

    An area is a DIRECTORY, so the file's name never becomes one. The cut
    is three segments deep from the package root (= `Sources/WenshuApp/
    Features` for the desktop line, `Sources/WenshuMobileApp/Features`
    for the mobile line), so the two lines measure the same work the same
    way.

    A path with fewer directories than the cut used to fall through to
    the file path itself, so ONE test file counted as its own area and a
    five-file card measured five areas = a T3 it did not earn.
    """
    relative = package_relative(path)
    parts = relative.split("/")
    if (relative.startswith("Sources/") or "/Tests/" in f"/{relative}") and len(parts) > 2:
        # Drop the file's name, so the deepest segment is a directory.
        directory = "/".join(parts[:-1])
        return "/".join(directory.split("/")[:3])
    if relative.startswith(("Tools/", "Scripts/", "docs/")):
        return parts[0]
    return relative


def areas_of(paths) -> set[str]:
    """The distinct areas the given files live in."""
    return {area_of(p) for p in paths}


def source_paths(paths) -> list[str]:
    """The source files among the given paths."""
    return sorted(p for p in paths if is_source(p))


def test_paths(paths) -> list[str]:
    """The test files among the given paths."""
    return sorted(p for p in paths if is_test(p))


def home_candidates() -> tuple[Path, ...]:
    """The Hermes homes that may hold the boards, most specific first.

    ``HERMES_HOME`` points at the PROFILE's directory, not at the home
    that holds the boards, and a profile's own copy of the boards does
    not exist (= ``<profile>/kanban`` is absent). So the profile is
    tried first, the home above it second (= a profile's home is
    ``<root>/profiles/<name>``, so the root is two levels up), and the
    shared home last. Getting this wrong is not a slow path, it is a
    WRONG path: the gate then reads no board at all and reports an
    agreement it never verified.
    """
    candidates: list[Path] = []
    env = os.environ.get("HERMES_HOME")
    if env:
        home = Path(env).expanduser()
        candidates.append(home)
        if home.parent.name == "profiles":
            candidates.append(home.parent.parent)
    candidates.append(Path.home() / ".hermes")
    return tuple(candidates)


def boards_dir() -> str:
    """Where the board databases live.

    The first candidate that actually HOLDS a boards directory wins,
    because the profile's own directory never does.
    """
    override = os.environ.get("HERMES_KANBAN_BOARDS")
    if override:
        return override
    candidates = [home / "kanban" / "boards" for home in home_candidates()]
    for candidate in candidates:
        if candidate.is_dir():
            return str(candidate)
    # No candidate holds a boards directory: name the shared home's, so
    # the caller reports the path it looked for.
    return str(candidates[-1])


def board_db(board: str = DEFAULT_BOARD) -> str:
    """The database file of one board.

    The board's own file decides, so a board that lives under one home
    is found even when another home is the active profile's.
    """
    candidates = [
        home / "kanban" / "boards" / board / "kanban.db"
        for home in home_candidates()
    ]
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    return str(candidates[-1])


# A path the tools must recognise as a file they can measure. The mobile
# line's paths start with `Sources/` (= inside the package) so they read
# the same as the desktop's, and the repo-relative form
# (`Mobile/Sources/...`) is recognised too, because a card that names a
# file by its repo path is naming a real file.
PATH_RE = re.compile(
    r"(?:Sources|Tests|Tools|docs|Scripts)/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+"
    r"|Mobile/(?:Sources|Tests)/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+"
    r"|(?:AGENTS|Package|CHANGELOG|OOB|CONTEXT|README)\.md"
    r"|Package\.(?:swift|resolved)"
    r"|\.(?:swiftlint\.yml|swift-format)"
)
