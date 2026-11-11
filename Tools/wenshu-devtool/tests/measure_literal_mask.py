#!/usr/bin/env python3
"""MEASURE THE MASKING'S REACH, = = = = AND WHETHER THE ARM'S READ
# = = = = DEPENDS ON A LITERAL'S TEXT.

= = ⇒ THE ARM READS CODE, = = = = and a literal's content is DATA. = = =
# = = = = So the member set a file yields must NOT change when the text of
# = = = = one of its literals changes. = = ⇒ And the mask is what decides
# = = = = what the arm reads, = = = = so the mask's shape is this card's
# = = = = subject.

= = ⇒ ⇒ AND THE VARIANT MUST KEEP THE FILE'S SHAPE. = = = = Every
# = = = = literal's DATA is replaced with other text of the SAME length,
# = = = = and the newlines are kept (= = = = = = the arm says which line a
# = = = = declaration is on), = = = = and no quote, = = = = no brace and no
# = = = = backslash are introduced (= = = = = so the literal's own
# = = = = boundaries, = = = = and the file's brace balance, = = = = = are
# = = = = the original's).

= = ⇒ ⇒ ⇒ AND THE DATA IS THE LITERAL'S, = = = = = = NOT THE CODE'S. = =
# = = = = = = An interpolation's EXPRESSION is code (= = = = = = = = = the
# = = = = = = arm reads it), = = = = = = = and a literal's TEXT is data
# = = = = = = (= = = = = = = = = and the arm must not read it). = = ⇒ So
# = = = = = = the variant changes the DATA, = = = = = = = and the
# = = = # = = = # = interpolation's code stays byte for byte.

= = ⇒ ⇒ ⇒ ⇒ AND THE READER IS THIS SCRIPT'S OWN. = = = = = = It is NOT
# = = = = # = = = # = = the tool's, = = = = # = = = # = = and that is the
# = = = # = = = # = = POINT: = = = = # = = = # = = = a variant built by
# = = = # = = = # = = the tool's OWN reader can only change the text the
# = = = # = = = # = = tool already sees, = = = = # = = = # = = so a shape
# = = = # = = = # = = the tool gets WRONG is a shape the measurement cannot
# = = = # = = = # = = reach (= = = = # = = = # = = = = = and the
# = = = # = = = # = = measurement would call it green). = = ⇒ This reader
# = = = # = = = # = = is the blind spot's MIRROR, = = = = # = = = # = = =
# = = = # = = = # = = and the disagreement between the two is printed.

= = ⇒ ⇒ ⇒ ⇒ ⇒ AND THE BEFORE ARM IS THIS TREE'S OWN BASE. = = = = = = The
# = = = = # = = = # = = = mask before this card is in this tree's HISTORY
# = = = = # = = = # = = = (= = = = # = = = # = = = and its member read is
# = = = = # = = = # = = = # = = = byte-identical to the one here), = = = =
# = = = # = = = # = = = # = = = so the BEFORE figure is this tree's own
# = = = # = = = # = = = # = = = base, = = = = # = = = # = = = and it runs
# = = = # = = = # = = = # = = = from a CLONE (= = = = # = = = # = = = = =
# = = = # = = = # = = = # = = = = = a clone has the history).

= = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE TREE IS THE ONE THIS SCRIPT LIVES IN. = = = = = =
# = = = = # = = = # = = = = = The repository and the tool default to THIS
# = = = = # = = = # = = = # = = = script's own tree (= = = = # = = = # = =
# = = = # = = = # = = = # = = = = = and the tool beside it), = = = = = = =
# = = = # = = = # = = = # = = = # = = = so the figures are the figures of
# = = = # = = = # = = = # = = = # = = = the tree being certified, = = = = =
# = = = # = = = # = = = # = = = # = = and the CWD is not an input.
"""
from __future__ import annotations

import argparse
import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

# = = ⇒ THE BASE THIS CARD IS BASED ON. = = = = The commit whose mask this
# = = = = card replaces (= = = = = and whose sha is in this tree's history,
# = = = = = = = = = = so the before arm runs from a clone). = = ⇒ It is a
# = = = = constant and not an argument's default guess, = = = = = = = = =
# = = = = = and the card's body names it.
BASE_SHA = "225366259bbaaf86ad44895bf9fafb3fe3eaa644"


# = = ⇒ THIS SCRIPT'S OWN LITERAL READER. = = = = = = It is a separate
# = = = = = = implementation from the tool's, = = = = = = on purpose (= =
# = = = = = = the tool's scanner is the thing under test). = = ⇒ It reports
# = = = = = = every literal's SPAN, = = = = = = and every literal's DATA
# = = = = = = (= = = = = = the text that is not an interpolation's code).

class Reader:
    """The literals in a text, = = = = and the DATA each one holds."""

    def __init__(self, text: str):
        self.text = text
        self.size = len(text)
        self.spans: list[tuple[int, int]] = []
        self.data: list[tuple[int, int]] = []

    # ---------- the readers ----------

    def block_end(self, index: int) -> int:
        """The index just past the `*/` that closes the block comment.

        = = ⇒ AND `index` POINTS AT THE `/*`. = = = = = = = = = = The depth
        # = = = # = = = # = = counts it, = = = = = = = = = = so a nested
        # = = = # = = = # = = one closes with its own `*/` (= = = = = = = =
        # = = = # = = = # = = and Swift's block comments do nest).
        """
        depth = 0
        cursor = index
        while cursor < self.size:
            if self.text.startswith("/*", cursor):
                depth += 1
                cursor += 2
                continue
            if self.text.startswith("*/", cursor):
                depth -= 1
                cursor += 2
                if depth == 0:
                    return cursor
                continue
            cursor += 1
        return self.size

    def literal(self, quote_at: int, hashes: int, span_start: int,
                report: bool = True) -> int:
        """The literal whose FIRST QUOTE is at `quote_at`, = = = = and the
        DATA it holds.

        = = ⇒ AND THE DATA IS SPLIT AT EVERY INTERPOLATION. = = = = The
        # = = = # = = = # = expression inside `\\(…)` is code, = = = = = = so
        # = = = # = = = # = it is not data (= = = = = = = = = and it is byte
        # = = = # = = = # = for byte in the variant).

        = = ⇒ ⇒ AND THE SPAN STARTS AT THE DELIMITER. = = = = = = The
        # = = = # = = = # = = tool's own reader starts a raw literal's span at
        # = = = # = = = # = = its `#`, = = = = = = = = = and this one does
        # = = = # = = = # = = the same (= = = = = = = = = so the two can be
        # = = = # = = = # = = compared, = = = = = = = = = and a disagreement
        # = = = # = = = # = = is a finding).
        """
        text = self.text
        multi = text.startswith('"""', quote_at)
        cursor = quote_at + (3 if multi else 1)
        data_start = cursor
        while cursor < self.size:
            char = text[cursor]
            if char == "\\":
                if hashes == 0:
                    if text[cursor + 1:cursor + 2] == "(":
                        stop = self.interpolation(cursor + 1)
                        self.data.append((data_start, cursor))
                        data_start = stop
                        cursor = stop
                        continue
                    # = = ⇒ THE ESCAPE IS NOT DATA. = = = = = = = = = = and
                    # = = ⇒ ⇒ ⇒ neither is the character it escapes. = = =
                    # = = ⇒ ⇒ ⇒ ⇒ = = = = = = = = = The escape carries
                    # = = ⇒ ⇒ ⇒ ⇒ ⇒ meaning, = = = = = = = = = = and a
                    # = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ variant that dropped it could change
                    # = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ where the literal ENDS. = = = = = =
                    # = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ = = So the data range stops before
                    # = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ = = it, = = = = = = = = = and it
                    # = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ = = starts again after it.
                    self.data.append((data_start, cursor))
                    cursor += 2
                    data_start = cursor
                    continue
                if (text[cursor + 1:cursor + 1 + hashes] == "#" * hashes
                        and text[cursor + 1 + hashes:cursor + 2 + hashes] == "("):
                    stop = self.interpolation(cursor + 1 + hashes)
                    self.data.append((data_start, cursor))
                    data_start = stop
                    cursor = stop
                    continue
                cursor += 1
                continue
            if char == '"':
                if multi:
                    if (text.startswith('"""', cursor)
                            and text[cursor + 3:cursor + 3 + hashes] == "#" * hashes):
                        end = cursor + 3 + hashes
                        self.data.append((data_start, cursor))
                        if report:
                            self.spans.append((span_start, end))
                        return end
                    cursor += 1
                    continue
                after = cursor + 1
                if text[after:after + hashes] == "#" * hashes:
                    self.data.append((data_start, cursor))
                    if report:
                        self.spans.append((span_start, after + hashes))
                    return after + hashes
                cursor += 1
                continue
            if char == "\n" and not multi:
                break
            cursor += 1
        end = min(cursor, self.size)
        self.data.append((data_start, end))
        if report:
            self.spans.append((span_start, end))
        return end

    def interpolation(self, index: int) -> int:
        """The index just past the `)` that closes the interpolation.

        = = ⇒ AND THE INTERPOLATION IS CODE. = = = = So the scan reads
        # = = = # = = = # = through it: = = = = # = = = # = = a literal in it
        # = = = # = = = # = = is a literal (= = = = # = = = # = = = = and
        # = = = # = = = # = = its own text is data), = = = = # = = = # = =
        # = = = # = = = # = = and a comment in it is a comment.
        """
        text = self.text
        depth = 1
        cursor = index + 1
        while cursor < self.size:
            char = text[cursor]
            if char == "(":
                depth += 1
                cursor += 1
                continue
            if char == ")":
                depth -= 1
                cursor += 1
                if depth == 0:
                    return cursor
                continue
            if char == "/" and text.startswith("//", cursor):
                stop = text.find("\n", cursor)
                cursor = self.size if stop < 0 else stop
                continue
            if char == "/" and text.startswith("/*", cursor):
                cursor = self.block_end(cursor)
                continue
            if char == "#":
                hashes = 0
                while cursor + hashes < self.size and text[cursor + hashes] == "#":
                    hashes += 1
                if cursor + hashes < self.size and text[cursor + hashes] == '"':
                    cursor = self.literal(cursor + hashes, hashes, cursor,
                                         report=False)
                    continue
                cursor += 1
                continue
            if char == '"':
                cursor = self.literal(cursor, 0, cursor, report=False)
                continue
            cursor += 1
        return self.size

    def run(self) -> "Reader":
        """Every literal in the text, = = = = and every literal's DATA."""
        text = self.text
        index = 0
        while index < self.size:
            char = text[index]
            if char == "/" and text.startswith("//", index):
                stop = text.find("\n", index)
                index = self.size if stop < 0 else stop
                continue
            if char == "/" and text.startswith("/*", index):
                index = self.block_end(index)
                continue
            hashes = 0
            while index + hashes < self.size and text[index + hashes] == "#":
                hashes += 1
            if index + hashes < self.size and text[index + hashes] == '"':
                index = self.literal(index + hashes, hashes, index)
                continue
            if char == '"':
                index = self.literal(index, 0, index)
                continue
            index += 1
        return self


def read_literals(text: str) -> tuple[list[tuple[int, int]],
                                      list[tuple[int, int]]]:
    """(spans, data ranges) for every literal in `text`."""
    reader = Reader(text).run()
    return reader.spans, reader.data


def variant(text: str, data: list[tuple[int, int]]) -> str:
    """The text, = = = = with every literal's DATA changed.

    = = ⇒ AND ONLY THE DATA. = = = = The interpolation's code, = = = = = = =
    # = = = = = = the literal's delimiters, = = = = = = the file's line count,
    # = = = = = = its length, = = = = = = and its brace balance: = = = = = =
    # = = = # = = = # = of them are the original's.
    """
    if not data:
        return text
    out = list(text)
    for start, end in data:
        for index in range(max(start, 0), min(end, len(out))):
            if out[index] != "\n":
                out[index] = "y"
    return "".join(out)


def members(module, text: str) -> set[tuple[str, str, bool, int]]:
    """The member set the tool reads, = = = = with the LINE included.

    = = ⇒ AND THE LINE IS PART OF IT. = = = = The arm rewrites the line a
    # = = = = declaration is on, = = = = so a member that MOVED to another
    # = = = # = = = # = line is a different member (= = = = = = = = = and a
    # = = = # = = = # = mask that dropped a line would move it).
    """
    return {(owner, name, private, line)
            for owner, name, private, line in module.scoped_members(text)}


def load(path: Path, name: str):
    """The tool at `path`, = = = = or a LOUD failure.

    = = ⇒ AND A LOUD FAILURE IS THE POINT. = = = = The old script's
    # = = = = `AttributeError` was a traceback (= = = = = = and the exit code
    # = = = # = = = # = = was 1, = = = # = = = # = = and the figure was never
    # = = = # = = = # = = printed). = = ⇒ A number nobody can read is not a
    # = = = # = = = # = = figure, = = = # = = = # = = so the failure says
    # = = = # = = = # = = what is wrong and where.
    """
    if not path.is_file():
        print(f"=== the tool is missing: {path}", file=sys.stderr)
        raise SystemExit(2)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as error:                       # noqa: BLE001
        print(f"=== the tool could not be loaded: {path} ({error})",
              file=sys.stderr)
        raise SystemExit(2) from error
    if not hasattr(module, "scoped_members"):
        print(f"=== the tool has no member read: {path}", file=sys.stderr)
        raise SystemExit(2)
    return module


def base_tool(repo: Path, sha: str, name: str):
    """The tool at `sha`, = = = = from this tree's own history."""
    proc = subprocess.run(["git", "show", f"{sha}:Tools/wenshu-devtool/"
                                           "split_pre_check.py"],
                          cwd=str(repo), capture_output=True, text=True)
    if proc.returncode != 0:
        print(f"=== the base tool could not be read: {sha} in {repo} "
              f"({proc.stderr.strip()})", file=sys.stderr)
        raise SystemExit(2)
    handle = tempfile.NamedTemporaryFile("w", suffix=".py", delete=False)
    try:
        handle.write(proc.stdout)
        handle.close()
        return load(Path(handle.name), name)
    finally:
        Path(handle.name).unlink(missing_ok=True)


def swift_files(repo: Path, ref: str) -> list[str]:
    """The Swift files at `ref`, = = = = by their path."""
    proc = subprocess.run(["git", "ls-tree", "-r", "--name-only", ref],
                          cwd=str(repo), capture_output=True, text=True,
                          check=True)
    return [name for name in proc.stdout.split() if name.endswith(".swift")]


def read_tree(repo: Path, sha: str) -> dict[str, str]:
    """The Swift files at `sha`, = = = = by their path.

    = = ⇒ ONE `git cat-file --batch` FOR THE WHOLE TREE. = = = = = = = = = The
    window walks 300 commits, = = = = = = = = = and each one needs TWO trees,
    = = = = = = = = = = so a per-file `git show` = = = = = = = = = = = spawns
    a process per (commit, file) pair (= = = = = = = = = = = = = = = = = = =
    ~840,000 of them, = = = = = = = = = = = = = = = = = = = = and the window
    cannot finish inside a review's runtime). = = = = = = = = = = = = = = = =
    = = ⇒ ⇒ ⇒ The figures are THE SAME. = = = = = = = = = = = = = = = = = The
    text is the text, = = = = = = = = = = = = = = = = = = and only the number
    of processes changes.
    """
    names = subprocess.run(["git", "ls-tree", "-r", "--name-only", sha],
                           cwd=str(repo), capture_output=True,
                           text=True, check=True).stdout.split()
    swift = [n for n in names if n.endswith(".swift")]
    proc = subprocess.run(["git", "cat-file", "--batch"], cwd=str(repo),
                          input=("\n".join(f"{sha}:{n}" for n in swift)
                                 + "\n").encode(), capture_output=True)
    out: dict[str, str] = {}
    data = proc.stdout
    pos = 0
    for n in swift:
        nl = data.find(b"\n", pos)
        if nl < 0:
            break
        header = data[pos:nl]
        if b"missing" in header:
            pos = nl + 1
            continue
        size = int(header.split()[-1])
        start = nl + 1
        out[n] = data[start:start + size].decode("utf-8", "replace")
        pos = start + size + 1
    return out


def tree_wide(repo: Path, tool, before) -> tuple[int, int, int]:
    """(moved with this tool, moved with the base, the files that disagree).

    = = ⇒ AND EVERY SWIFT FILE AT THE TREE'S HEAD. = = = = Not a window's
    # = = = # = = = # = = commit pairs: = = = = = = = = the figure the card
    # = = = # = = = # = = states is the TREE's figure.
    """
    moved = 0
    moved_base = 0
    disagree = 0
    for path, text in read_tree(repo, "HEAD").items():
        if not text:
            continue
        spans, data = read_literals(text)
        if not spans:
            continue
        other = variant(text, data)
        if other == text:
            continue
        if members(tool, text) != members(tool, other):
            moved += 1
        if before is not None and members(before, text) != members(before, other):
            moved_base += 1
        if hasattr(tool, "literal_spans") and set(tool.literal_spans(text)) != set(spans):
            disagree += 1
    return moved, moved_base, disagree


def window(repo: Path, tool, before, count: int) -> tuple[int, int]:
    """(moved with this tool, moved with the base) over the window."""
    log = subprocess.run(["git", "log", "--format=%H %P", f"-{count}"],
                         cwd=str(repo), capture_output=True, text=True,
                         check=True).stdout.split("\n")
    pairs = []
    for line in log:
        fields = line.split()
        if len(fields) >= 2:
            pairs.append((fields[0], fields[1]))
    moved = 0
    moved_base = 0
    for tip, parent in pairs:
        tree = read_tree(repo, tip)
        base = read_tree(repo, parent)
        for path, text in tree.items():
            if not text:
                continue
            old = base.get(path, "")
            if old and old == text:
                continue
            _spans, data = read_literals(text)
            if not data:
                continue
            other = variant(text, data)
            if other == text:
                continue
            if members(tool, text) != members(tool, other):
                moved += 1
            if before is not None and members(before, text) != members(before, other):
                moved_base += 1
    return moved, moved_base


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=None,
                        help="the repository to measure (= = the tree this "
                             "script lives in)")
    parser.add_argument("--tool", default=None,
                        help="the tool to measure (= = the tree's own copy)")
    parser.add_argument("--base", default=BASE_SHA,
                        help="the sha of the BEFORE arm (= = this tree's own "
                             "base)")
    parser.add_argument("--window", type=int, default=300,
                        help="how many commits of the first parent to walk")
    parser.add_argument("--tree-wide", action="store_true",
                        help="measure every Swift file at the tree's HEAD")
    args = parser.parse_args()

    # = = ⇒ THE TREE THIS SCRIPT LIVES IN, = = = = and the tool beside it.
    # = = = = = = So the CWD is not an input, = = = = = = and the figures
    # = = = = = = are the figures of the tree being certified.
    here = Path(__file__).resolve()
    repo = Path(args.repo).resolve() if args.repo else here.parents[3]
    tool_path = Path(args.tool).resolve() if args.tool else (
        repo / "Tools/wenshu-devtool/split_pre_check.py")
    tool = load(tool_path, "this_tool")

    before = None
    if args.base:
        before = base_tool(repo, args.base, "base_tool")

    print(f"=== the tree: {repo}")
    print(f"=== the tool: {tool_path}")
    print(f"=== the before arm: {args.base}")

    if not args.tree_wide:
        moved_window, moved_window_base = window(repo, tool, before,
                                                  args.window)
    else:
        moved_window, moved_window_base = 0, 0
    moved, moved_base, disagree = tree_wide(repo, tool, before)

    # = = ⇒ THE FOUR FIGURES, = = = = grouped by the arm that produced
    # = = ⇒ ⇒ them (= = = = = = = = = = the new mask's two, = = = = = = =
    # = = ⇒ ⇒ ⇒ and the old mask's two). = = = = = = = = = = And the first
    # = = ⇒ ⇒ ⇒ ⇒ two are ZERO, = = = = = = = = = = because that is the
    # = = ⇒ ⇒ ⇒ ⇒ ⇒ invariant this card holds.
    print(f"=== the NEW mask (= = this card's):")
    if not args.tree_wide:
        print(f"===   the window figure ({args.window} commits): {moved_window}")
    print(f"===   the tree-wide figure (every Swift file at HEAD): {moved}")
    print("=== = = = = 0 = = = = = is the invariant this card holds")
    if before is not None:
        print(f"=== the BASE's mask (= = the before arm):")
        if not args.tree_wide:
            print(f"===   the window figure ({args.window} commits): "
                  f"{moved_window_base}")
        print(f"===   the tree-wide figure (every Swift file at HEAD): "
              f"{moved_base}")
    if hasattr(tool, "literal_spans"):
        print(f"=== the files where this script's reader and the tool's own "
              f"reader DISAGREE: {disagree}")
    return 0 if (moved == 0 and moved_window == 0) else 1


if __name__ == "__main__":
    sys.exit(main())
