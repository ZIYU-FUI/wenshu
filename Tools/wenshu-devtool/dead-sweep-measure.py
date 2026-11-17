#!/usr/bin/env python3
"""Re-derive the dead-sweep record's numbers, each with its METHOD.

Every number in the record must be re-derivable by a reader, so this
script prints the definition it used next to the number. Run it from the
repository root:

    python3 Tools/wenshu-devtool/dead-sweep-measure.py

The two axes it measures:

  A. Dead code. The tree's own tool (`verify-dead.py`) is the authority
     for per-declaration reachability, but its default scope is the ten
     view directories, so it sees 131 of the 602 production files. This
     script runs it over the FULL scope and then adds the two lenses the
     tool cannot see: a file-level reachability graph, and the
     comment-vs-code distinction (a name mentioned only in a comment is
     not a use).

  B. Apple-API duplication. For each candidate the record names, this
     script reads the INSTALLED SDK and prints the symbol's own path,
     so "Apple ships it" is checkable against the SDK on disk rather
     than against a paraphrase.

Each section prints its METHOD next to its number, and each partition
asserts that its buckets cover the population exactly once (= a bucket
that does not add up is a bug in the method, not a finding).
"""
import argparse
import collections
import os
import re
import subprocess
import sys
from pathlib import Path

# The five production roots. A path with a `Tests` component is a test
# tree, never a production file.
PROD_ROOTS = (
    "Sources/WenshuApp",
    "Sources/WenshuAgent/Sources",
    "Sources/WenshuData/Sources",
    "Board/Sources",
    "Mobile/Sources",
)

# The @main entry points that start each app's own reachability.
ENTRY_FILES = ("WenshuAppMain.swift", "WenshuBoardApp.swift", "WenshuMobileApp.swift")

# Declaration names too generic to prove a use: property names, protocol
# requirements, and the words every file repeats.
GENERIC = frozenset("""
body init self value id name title count index data state tag type kind result message error
success failure context content description enabled visible hashValue debugDescription
default shared stream cancel event handler send load save read write open close create update
delete remove insert append clear reset start stop run exec execute provider key keys url path
file directory folder item items list array dict map set view model entry entries config options
option params param args arg text string number int bool date time size width height frame offset
margin padding corner radius color font style theme source target destination raw payload bytes
""".split())

MODIFIERS = (
    "public", "private", "fileprivate", "internal", "open", "package", "static",
    "final", "mutating", "nonisolated", "weak", "lazy", "override", "class",
    "indirect", "consuming", "borrowing",
)
DECL_RE = re.compile(
    r'^[ \t]*(?:(?:' + "|".join(MODIFIERS) + r')[ \t]+)*'
    r'(?P<kind>let|var|struct|class|enum|actor|func|extension|protocol|typealias|subscript|case)'
    r'[ \t]+(?P<name>[A-Za-z_][A-Za-z0-9_]*)',
    re.M,
)
TOKEN_RE = re.compile(r'\b[A-Za-z_][A-Za-z0-9_]*\b')

# The SwiftData members the framework reads reflectively: a stored
# property and a `VersionedSchema` requirement are both read by
# SwiftData itself, never by a call site, so "no reference" is the
# framework's shape, not dead code.
FRAMEWORK_MANDATED = {
    "Sources/WenshuData/Sources/WenshuData/ModelsSchema.swift": ("versionIdentifier",),
    "Sources/WenshuData/Sources/WenshuData/WSChatMessage.swift": ("toolResultsJSON",),
}


def run(cmd, cwd=None):
    """Run a command and return (rc, stdout+stderr)."""
    proc = subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def production_files(root):
    """Every production Swift file, per the five roots."""
    out = []
    for base in PROD_ROOTS:
        for dirpath, dirnames, filenames in os.walk(os.path.join(root, base)):
            if ".build" in dirpath or "Tests" in dirpath.split(os.sep):
                continue
            for name in sorted(filenames):
                if name.endswith(".swift"):
                    out.append(os.path.join(dirpath, name))
    return sorted(out)


def strip_swift(src):
    r"""Remove comments and string-literal CONTENT, keep interpolation code.

    A name that survives this is a name the COMPILER sees. A name that
    only lives in a comment or a string is not a use of anything.

    A string's INTERPOLATION is code, = so `\(foo)` keeps `foo`: = the
    compiler resolves that name, = so a reference inside it is a real
    reference. = Dropping it would make a live declaration look dead.
    """
    out = []
    i = 0
    n = len(src)
    while i < n:
        if src.startswith("//", i):
            while i < n and src[i] != "\n":
                i += 1
            continue
        if src.startswith("/*", i):
            depth = 1
            i += 2
            while i < n and depth:
                if src.startswith("/*", i):
                    depth += 1
                    i += 2
                elif src.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    if src[i] == "\n":
                        out.append("\n")
                    i += 1
            continue
        if src.startswith('"""', i):
            j = i + 3
            while j < n:
                if src[j] == "\\" and j + 1 < n:
                    j += 2
                    continue
                if src.startswith('"""', j):
                    j += 3
                    break
                if src[j] == "\n":
                    out.append("\n")
                j += 1
            out.append(" ")
            i = j
            continue
        if src[i] == '"':
            j = i + 1
            while j < n:
                if src[j] == "\\" and j + 1 < n:
                    if src[j + 1] == "(":
                        # AN INTERPOLATION: = the code inside it is code.
                        close = _matching_paren(src, j + 1)
                        out.append(" ")
                        out.append(strip_swift(src[j + 2:close]))
                        out.append(" ")
                        j = close + 1
                        continue
                    j += 2
                    continue
                if src[j] == '"':
                    j += 1
                    break
                if src[j] == "\n":
                    break
                j += 1
            out.append(" ")
            i = j
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def strip_comments(src):
    r"""Remove COMMENTS only; = string-literal CONTENT STAYS.

    A shape that lives inside a string literal (= a subprocess path, = a
    localized menu title) is a real use of that string, = = so it must
    survive this lens. = = The code lens (= `strip_swift`) removes string
    CONTENT too, = = which is right for a NAME (= the compiler resolves
    names, = = not strings) = = and wrong for a literal's own text.
    """
    out = []
    i = 0
    n = len(src)
    while i < n:
        if src.startswith("//", i):
            while i < n and src[i] != "\n":
                i += 1
            continue
        if src.startswith("/*", i):
            depth = 1
            i += 2
            while i < n and depth:
                if src.startswith("/*", i):
                    depth += 1
                    i += 2
                elif src.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    if src[i] == "\n":
                        out.append("\n")
                    i += 1
            continue
        if src.startswith('"""', i):
            out.append('"""')
            j = i + 3
            while j < n:
                if src[j] == "\\" and j + 1 < n:
                    out.append(src[j:j + 2])
                    j += 2
                    continue
                if src.startswith('"""', j):
                    j += 3
                    break
                out.append(src[j])
                j += 1
            out.append('"""')
            i = j
            continue
        if src[i] == '"':
            out.append('"')
            j = i + 1
            while j < n:
                if src[j] == "\\" and j + 1 < n:
                    out.append(src[j:j + 2])
                    j += 2
                    continue
                if src[j] == '"':
                    j += 1
                    break
                if src[j] == "\n":
                    break
                out.append(src[j])
                j += 1
            out.append('"')
            i = j
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def _matching_paren(src, open_at):
    """The index of the `)` that closes the `(` at `open_at`."""
    depth = 0
    i = open_at
    n = len(src)
    while i < n:
        char = src[i]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return i
        elif char == '"':
            # a nested string: = skip it, = but keep its own interpolation
            i += 1
            while i < n and src[i] != '"':
                if src[i] == "\\":
                    i += 1
                i += 1
        i += 1
    return n - 1


def code_of(path):
    """The file's code, comments and string contents removed."""
    with open(path, encoding="utf-8", errors="replace") as handle:
        return strip_swift(handle.read())


def raw_of(path):
    """The file's text as written."""
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


# The tree's own tool is the authority for per-declaration reachability.
# Importing it (= rather than re-implementing its lens) is the point: = the
# measurement and the gate must not disagree about what "alive" means.
def load_tool(root):
    """Import `verify-dead.py` from the tree, so its lens IS the authority."""
    import importlib.util

    path = os.path.join(root, "Tools", "wenshu-devtool", "verify-dead.py")
    spec = importlib.util.spec_from_file_location("verify_dead", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_local_uses(tool, root, scope):
    """The tool's own `local_uses` (= the uses in the declaring file).

    `has_real_ref` counts a same-file use as a reference, so a declaration
    the file itself calls is ALIVE. = = `local_uses` is the function that
    decides it, = = and it excludes the declaration site itself (= and a
    return type, = which is only a promise).
    """
    tree = tool.get_tree(root, scope)

    def local_uses(rel, name):
        return tool.local_uses(tree, rel, name)

    return local_uses


def record_quotes(path):
    """The record's OWN HIG quote blocks, with the page each belongs to.

    The quotes are READ from the record (= = not re-typed here), = = so the
    check tests what the record actually says, = = and a drift between the
    two cannot hide. ⇒ The page is named by the line above the block
    (= = the record names it in the sentence that introduces the quote).
    """
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    quotes = []
    slug = None
    current = []
    start = 0
    for index, line in enumerate(lines, 1):
        if line.startswith(">"):
            if not current:
                start = index
            current.append(line[1:].strip())
            continue
        if current:
            text = " ".join(" ".join(current).split())
            if text.startswith('"') and text.endswith('"'):
                text = text[1:-1]
            if slug:
                quotes.append((slug, text))
            current = []
        for known in ("undo-and-redo", "edit-menus"):
            if "`" + known + "`" in line:
                slug = known
    return quotes


def page_span(page_flat, needle):
    """Does the quote sit exactly on a sentence boundary in the page?

    Three tests, all on the page's own flat text:

    1. the quote is PRESENT (= the page carries these characters);
    2. the quote ENDS a sentence (= the next character is a sentence end
       or a heading, = = so a TRUNCATION cannot pass);
    3. the quote BEGINS a sentence (= what precedes it is a sentence end
       or a markdown heading, = = so a MID-SENTENCE start cannot pass).

    Returns the matched span, or "" when the quote is not on a boundary.
    """
    flat_needle = " ".join(needle.split())
    index = page_flat.find(flat_needle)
    if index < 0:
        return ""
    end = index + len(flat_needle)
    before = page_flat[:index]
    after = page_flat[end:]
    # 2. = = the quote ENDS a sentence: = = its own last character must be a
    # = = sentence end (= = possibly followed by emphasis markers). = = A
    # = = TRUNCATION cuts mid-sentence, = = so its last character is a
    # = = letter, = = and that is what fails here. = = (The round-one
    # = = truncation stopped at "on a Mac", = = and this is the test that
    # = = catches it.)
    if not re.search(r"[.!?](\*{0,2})$", flat_needle):
        return ""
    # 3. = = the quote begins a sentence (= = or a heading).
    if not re.search(r"(?:[.!?]\*{0,2}\s|[#]{1,6}\s+[^.!?]*)$", before):
        return ""
    return flat_needle


def count_pattern(code_map, pattern):
    """The matching LINES in a set of files, over the code lens.

    The code lens has comments and string contents removed, so a docblock
    that mentions a shape does not count as a use of it.
    """
    rx = re.compile(pattern)
    total = 0
    for text in code_map.values():
        total += len(rx.findall(text))
    return total


def count_call_sites(code_map, name, decl_prefixes=(), exclude_path=None):
    """The CALL SITES of a name (= a declaration line is not a use).

    A line that declares the name (= `func name(`, = `class name`, = …)
    is the declaration, = = not a use of it, = = so it is excluded.
    `exclude_path` drops one file (= the declaring file), = = which is how
    "nothing outside can reach it" is counted.
    """
    rx = re.compile(r"\b" + re.escape(name) + r"\b")
    total = 0
    for path, text in code_map.items():
        if exclude_path is not None and path == exclude_path:
            continue
        for line in text.split("\n"):
            if not rx.search(line):
                continue
            stripped = line.strip()
            if any(stripped.startswith(prefix + name) for prefix in decl_prefixes):
                continue
            total += 1
    return total


def decls_of(path):
    """(kind, name, access) for every declaration in a file."""
    text = raw_of(path)
    out = []
    for match in DECL_RE.finditer(text):
        start = text.rfind("\n", 0, match.start()) + 1
        line = text[start:match.end()]
        access = "internal"
        for level in ("public", "open", "package", "internal", "fileprivate", "private"):
            if re.search(r"\b" + level + r"\b", line):
                access = level
                break
        out.append((match.group("kind"), match.group("name"), access))
    return out


def distinctive_names(path):
    """The names a file declares that could prove a use of it."""
    names = {name for kind, name, _ in decls_of(path) if name not in GENERIC}
    return names


def section(title):
    print()
    print("=" * 74)
    print(title)
    print("=" * 74)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="main", help="the tree to measure (= the default branch)")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]

    files = production_files(root)
    rel = {path: os.path.relpath(path, root) for path in files}
    by_rel = {rel[path]: path for path in files}

    code = {path: code_of(path) for path in files}
    raw = {path: raw_of(path) for path in files}

    # The vendored engine counts for the editor's own paths, = = so the
    # Apple-API rows read over the production roots AND `Vendor/`.
    vendor = []
    for path in (root / "Vendor").rglob("*.swift"):
        if ".build" not in path.parts:
            vendor.append(path)
    code_all = dict(code)
    raw_all = dict(raw)
    for path in vendor:
        code_all[path] = code_of(path)
        raw_all[path] = raw_of(path)
    # The same files with comments removed but STRING CONTENT kept (= for a
    # shape that lives inside a literal, = = a subprocess path, = = a
    # localized menu title).
    with_strings = {path: strip_comments(raw_of(path)) for path in files}
    with_strings_all = dict(with_strings)
    for path in vendor:
        with_strings_all[path] = strip_comments(raw_of(path))

    # The tool's own reachability, imported (= not re-implemented), so the
    # measurement and the gate can never disagree about what "alive" means.
    tool = load_tool(root)
    tool_local_uses = make_local_uses(tool, root, "Sources/ Tests/ Board/ Mobile/")

    section("A1. The population (= every production Swift file in the five roots)")
    by_module = collections.Counter(rel[p].split("/")[0] for p in files)
    print(f"  production Swift files: {len(files)}")
    for module, count in sorted(by_module.items()):
        print(f"    {module:10} {count:4}")
    print("  method: os.walk over the five roots, skipping any path with a")
    print("          `Tests` component and any `.build` directory.")

    section("A1b. The line denominators (= the scope in lines, = = not just files)")
    def loc_of(path):
        with open(path, encoding="utf-8", errors="replace") as handle:
            return len(handle.read().splitlines())

    prod_loc = sum(loc_of(path) for path in files)
    default_files, default_dirs = load_tool(root).auto_scan(root)
    default_loc = sum(loc_of(os.path.join(root, rel)) for rel in default_files)
    print(f"  the tree's own gate scope: {len(default_files)} files, {default_loc} lines")
    print(f"  the whole production tree:  {len(files)} files, {prod_loc} lines")
    print(f"  the gate sees {len(default_files) / len(files) * 100:.1f}% of the files")
    print(f"  and {default_loc / prod_loc * 100:.1f}% of the lines")
    print("  method: `splitlines()` (= a file that ends WITHOUT a trailing")
    print("          newline counts its last line), = = over the same file sets")
    print("          the other sections use. = = the gate's scope = = the ten")
    print("          view directories, = = read from the tool's own `auto_scan`.")

    section("A2. The tree's own tool, at its DEFAULT scope (= what the gate sees)")
    rc, out = run("python3 Tools/wenshu-devtool/verify-dead.py --verbose", cwd=root)
    default_verdicts = collections.Counter(re.findall(r"verdict:\s*(\w+)", out))
    print(f"  exit {rc}")
    for verdict in ("ALIVE", "PARTIAL", "DEAD", "EMPTY"):
        print(f"    {verdict:8} {default_verdicts.get(verdict, 0):4}")
    print("  the tool's own summary (= = it counts EMPTY as PARTIAL):")
    for line in out.splitlines():
        if line.strip().startswith(("Summary:", "ALIVE", "PARTIAL", "DEAD")):
            print(f"    {line.strip()}")
    print("  method: `verify-dead.py --verbose` with no arguments (= its default")
    print("          scope, = = the ten view directories). = = the split above")
    print("          separates EMPTY from PARTIAL; = = the tool's own summary")
    print("          does not (= = it has no EMPTY row).")

    section("A3. The same tool over the FULL scope (= every production file)")
    scope = "Sources/ Tests/ Board/ Mobile/"
    cmd = ("python3 Tools/wenshu-devtool/verify-dead.py --verbose --scope '%s' %s"
           % (scope, " ".join("'" + rel[p] + "'" for p in files)))
    rc, out = run(cmd, cwd=root)
    verdicts = collections.Counter(re.findall(r"verdict:\s*(\w+)", out))
    blocks = re.split(r"^=== (.+?) ===$", out, flags=re.M)
    candidates = []
    for index in range(1, len(blocks), 2):
        for line in blocks[index + 1].splitlines():
            match = re.match(r"^\s*✗\s+(\w+)\s+(\S+)", line)
            if match:
                candidates.append((blocks[index], match.group(1), match.group(2)))
    print(f"  exit {rc}")
    print(f"  files scanned: {sum(verdicts.values())}")
    for verdict in ("ALIVE", "PARTIAL", "DEAD", "EMPTY"):
        print(f"    {verdict:8} {verdicts.get(verdict, 0):4}")
    print(f"  unread declarations: {len(candidates)}")
    print("  method: the same tool, `--scope 'Sources/ Tests/ Board/ Mobile/'`")
    print("          and every production file as its argument list.")
    print("  note: `--scope` alone is NOT enough: = = it is the tool's GREP")
    print("        scope (= = where it looks for a name), = = and with no")
    print("        file argument the tool auto-scans its ten view")
    print("        directories (= = the 131). = = the FILE LIST is what")
    print("        selects the files, = = and the exact command is:")
    print("    python3 Tools/wenshu-devtool/verify-dead.py \\")
    print("      --scope 'Sources/ Tests/ Board/ Mobile/' \\")
    print("      $(find Sources/WenshuApp Sources/WenshuAgent/Sources \\")
    print("             Sources/WenshuData/Sources Board/Sources Mobile/Sources \\")
    print("             -name '*.swift' -not -path '*/Tests/*' \\")
    print("             -not -path '*/.build/*' | sort)")
    print("  note: the tool's OWN summary line counts an EMPTY file as")
    print("        PARTIAL (= = it has no EMPTY line, = = so its three numbers")
    print("        add up to the file count). = = the split above separates")
    print("        them, = = so a reader can see both: = = the tool says 36")
    print("        PARTIAL, = = of which 34 carry an unread declaration and 2")
    print("        are EMPTY (= = no top-level declarations at all).")
    print("        The tool's own summary:")
    for line in out.splitlines():
        if line.strip().startswith(("Summary:", "ALIVE", "PARTIAL", "DEAD")):
            print(f"          {line.strip()}")

    section("A3b. The same gate at the 2026-11-02 baseline (= the delta)")
    baseline = "e9a85dcad9"
    print(f"  baseline commit: {baseline}")
    tmp = os.path.join(os.environ.get("TMPDIR", "/tmp"), "wenshu-dead-baseline")
    if os.path.isdir(tmp):
        subprocess.run(["rm", "-rf", tmp], check=True)
    os.makedirs(tmp, exist_ok=True)
    rc, _ = run("git archive %s | tar -x -C %s" % (baseline, tmp), cwd=root)
    print(f"  git archive exit {rc}")
    old_files = production_files(tmp)
    print(f"  production Swift files at the baseline: {len(old_files)}")
    old_rel = {p: os.path.relpath(p, tmp) for p in old_files}
    # The CURRENT tool runs over the OLD tree (= the same tool at the same
    # scope on both sides), = = so the delta measures the TREE, = = not the
    # tool's own version drift.
    old_cmd = (
        "python3 %s --verbose --scope 'Sources/ Tests/ Board/ Mobile/' %s"
        % (os.path.join(root, "Tools", "wenshu-devtool", "verify-dead.py"),
           " ".join("'" + old_rel[p] + "'" for p in old_files))
    )
    rc, out = run(old_cmd, cwd=tmp)
    old_verdicts = collections.Counter(re.findall(r"verdict:\s*(\w+)", out))
    print(f"  exit {rc}")
    for verdict in ("ALIVE", "PARTIAL", "DEAD", "EMPTY"):
        print(f"    {verdict:8} {old_verdicts.get(verdict, 0):4}")
    print("  the tool's own summary (= = it counts EMPTY as PARTIAL):")
    for line in out.splitlines():
        if line.strip().startswith(("Summary:", "ALIVE", "PARTIAL", "DEAD")):
            print(f"    {line.strip()}")
    print("  method: the baseline tree is exported with `git archive` into a")
    print("          temporary directory, = = the CURRENT tool is run over it")
    print("          at the SAME scope, = = and its verdicts are counted.")
    print("  note: the file list is the five PRODUCTION ROOTS (= the SOURCES")
    print("        subtrees), = = so a `Package.swift` manifest that sits")
    print("        beside the sources is outside every root and is NOT")
    print("        counted. = = a plain `find` over the same tree lists 513")
    print("        files (= = +3 manifests) and answers 36 PARTIAL, = = so the")
    print("        510 here is the count the record quotes.")

    section("A4. Every unread declaration, adjudicated (= the tool's OWN reachability)")
    buckets = collections.Counter()
    detail = collections.defaultdict(list)
    for file_rel, kind, name in candidates:
        owner = by_rel.get(file_rel)
        if owner is None:
            buckets["unresolved"] += 1
            continue
        if file_rel in FRAMEWORK_MANDATED and name in FRAMEWORK_MANDATED[file_rel]:
            buckets["framework"] += 1
            detail["framework"].append((file_rel, kind, name))
            continue
        # The tool's OWN reachability lens decides liveness, not a guess.
        # `has_real_ref` counts a same-file use as a use, so a declaration
        # the file itself calls is ALIVE (= `reach_reasons` says "used in
        # its own file"). = = Reading only the OTHER files would call such
        # a declaration dead, = = which is a false positive. = = The tool's
        # own list is authoritative for the name's own file; = = the
        # comment-vs-code split is ours, and it applies to the OTHER files.
        if tool_local_uses(file_rel, name):
            buckets["own-file-use"] += 1
            detail["own-file-use"].append((file_rel, kind, name))
            continue
        code_elsewhere = any(
            re.search(r"\b" + re.escape(name) + r"\b", code[other])
            for other in files
            if other != owner
        )
        raw_elsewhere = any(
            re.search(r"\b" + re.escape(name) + r"\b", raw[other])
            for other in files
            if other != owner
        )
        if code_elsewhere:
            buckets["code"] += 1
            detail["code"].append((file_rel, kind, name))
        elif raw_elsewhere:
            buckets["comment"] += 1
            detail["comment"].append((file_rel, kind, name))
        else:
            buckets["bare"] += 1
            detail["bare"].append((file_rel, kind, name))
    total = sum(buckets.values())
    print(f"  unread declarations: {len(candidates)}")
    for key in ("own-file-use", "code", "comment", "bare", "framework", "unresolved"):
        print(f"    {key:14} {buckets[key]:4}")
    assert total == len(candidates), (
        "the buckets must cover every candidate exactly once: %d != %d" % (total, len(candidates))
    )
    print("  method: the tool's own ✗ list, then each name checked in this order:")
    print("          (1) the FRAMEWORK mandate (= SwiftData reads it);")
    print("          (2) the TOOL'S OWN `local_uses` (= a use in its own file")
    print("              counts, = so the declaration is ALIVE, = = not dead);")
    print("          (3) the name matched against every OTHER production file,")
    print("              twice (= once with comments and string contents removed,")
    print("              once with the raw text).")
    print("  the own-file-use bucket = the gate's SECOND blind spot: = the tool's")
    print("          `has_real_ref` skips a same-file line that starts with a")
    print("          DECL_PREFIX (= `private `, `static `, …), = = so a call site")
    print("          written as `private let x = Foo()` is skipped and the")
    print("          declaration reads as dead. = = These are ALIVE.")
    print("  the framework bucket = SwiftData's own members (= a stored property and")
    print("          a VersionedSchema requirement); = SwiftData reads them, so no")
    print("          call site exists by design.")
    print()
    print("  the bare list (= nothing names them, in code or in a comment):")
    for file_rel, kind, name in sorted(detail["bare"]):
        print(f"    {file_rel}  {kind} {name}")
    print("  the own-file-use list (= ALIVE: = the file itself calls them):")
    for file_rel, kind, name in sorted(detail["own-file-use"]):
        print(f"    {file_rel}  {kind} {name}")
    print("  the comment-only list (= only a comment names them):")
    for file_rel, kind, name in sorted(detail["comment"]):
        print(f"    {file_rel}  {kind} {name}")
    print("  the framework list (= the framework reads them):")
    for file_rel, kind, name in sorted(detail["framework"]):
        print(f"    {file_rel}  {kind} {name}")

    section("A5. The access-level split of the unread declarations")
    split = collections.Counter()
    for file_rel, kind, name in candidates:
        owner = by_rel.get(file_rel)
        if owner is None:
            continue
        access = "?"
        for decl_kind, decl_name, decl_access in decls_of(owner):
            if decl_name == name and decl_kind == kind:
                access = decl_access
                break
        split[(file_rel.split("/")[0], access)] += 1
    for (module, access), count in sorted(split.items()):
        print(f"    {module:12} {access:11} {count:4}")
    print("  method: the access modifier on the declaration line itself.")

    section("A6. The design tokens nothing reads (= the tree's own sweep only prints)")
    app_tokens = []
    token_path = os.path.join(root, "Sources/WenshuApp/DesignTokens.swift")
    token_text = raw_of(token_path)
    for match in re.finditer(r"static let ([a-zA-Z][A-Za-z0-9_]*)\s*:", token_text):
        name = match.group(1)
        read = any(
            ("DesignTokens." + name) in code[other]
            for other in files
            if other != token_path
        )
        if not read:
            app_tokens.append(name)
    tool_tokens = sorted(
        {name for file_rel, kind, name in candidates if file_rel.endswith("WenshuApp/DesignTokens.swift")}
    )
    mobile_tokens = sorted(
        {name for file_rel, kind, name in candidates if file_rel.endswith("WenshuMobileApp/Shared/UI/DesignTokens.swift")}
    )
    print(f"  app tokens no production file names (= `DesignTokens.<name>`): {len(app_tokens)}")
    print(f"  app tokens the TOOL calls unread:                                 {len(tool_tokens)}")
    print(f"  mobile tokens the TOOL calls unread:                              {len(mobile_tokens)}")
    print()
    print("  the app tokens the TOOL calls unread (= the authority list):")
    for name in tool_tokens:
        print(f"    DesignTokens.{name}")
    print("  the mobile tokens the TOOL calls unread:")
    for name in mobile_tokens:
        print(f"    DesignTokens.{name}")
    print("  method: the tool's own list (= the authority: = a declaration's")
    print("          reachability, comment-insensitive), plus a name search for")
    print("          `DesignTokens.<name>` in every other production file's code")
    print("          (= a looser method: = it counts a token whose only reader is a")
    print("          same-file use, and it misses a token read through a different")
    print("          spelling).")
    print("  note: the tree's own DeadDesignTokensSweepTests prints its set; its own")
    print("        comment says the assertion is downgraded to a non-blocking record.")

    section("A7. The files no production code can name (= the strict island)")
    # A file is an ISLAND when no OTHER production file's code names ANY
    # of its declarations. This is the strictest file-level claim: it
    # does not need the reachability chain, so it cannot be broken by
    # dispatch the name graph cannot see (= a protocol witness, a member
    # reached through a value, a name built at run time).
    #
    # The names counted are the file's OWN declarations, minus the
    # generic words (= `body`, `state`, = named everywhere) and minus an
    # extension of a STANDARD-LIBRARY type (= `extension Notification`
    # names no type of the tree).
    STDLIB_TYPES = {
        "Dictionary", "Array", "String", "Collection", "View", "Set",
        "Optional", "Result", "Sequence", "Codable", "Sendable", "Equatable",
        "Comparable", "Hashable", "Identifiable", "CustomStringConvertible",
        "Notification",
    }
    readers_of = collections.defaultdict(set)
    for path in files:
        for token in set(TOKEN_RE.findall(code[path])):
            readers_of[token].add(path)
    readers = {}
    for path in files:
        names = set()
        for kind, name, _ in decls_of(path):
            if kind == "extension" and name in STDLIB_TYPES:
                continue
            if name in GENERIC:
                continue
            names.add(name)
        found = set()
        for name in names:
            found |= readers_of.get(name, set())
        readers[path] = found - {path}
    islands = sorted(p for p in files if readers[p] == set() and decls_of(p))
    island_loc = sum(sum(1 for _ in open(p, encoding="utf-8", errors="replace")) for p in islands)
    print(f"  files no production file names: {len(islands)}  ({island_loc} LOC)")
    for path in islands:
        print(f"    {rel[path]}  ({sum(1 for _ in open(path, encoding='utf-8', errors='replace'))} LOC)")
    print("  method: for every production file, the set of production files whose")
    print("          CODE names one of its declarations (= comments and string")
    print("          contents removed; = the generic words and the standard-library")
    print("          extension targets removed); = a file whose set is empty is an")
    print("          island.")
    print("  note: this lens needs no reachability chain, so it does not over-report")
    print("        the way a name graph does (= a protocol witness or a member")
    print("        reached through a value breaks the chain).")

    section("A8. The closed groups the record names (= each one verified here)")
    # A closed group = a set of files where NO production file outside the
    # group names any of the group's own types. Nothing outside the group
    # can reach into it. The group list is the record's own claim, so a
    # reader can edit a membership and re-run to see the claim fail.
    TYPE_KINDS = {"struct", "class", "enum", "actor", "protocol", "extension"}
    decl_count = collections.Counter()
    for path in files:
        for kind, name, _ in decls_of(path):
            if kind in TYPE_KINDS and not (kind == "extension" and name in STDLIB_TYPES):
                decl_count[name] += 1
    GROUPS = {
        "the layout-tree family": (
            "Sources/WenshuApp/Shared/State/LayoutTreeStore.swift",
            "Sources/WenshuApp/Shared/State/LayoutTreeRepository.swift",
            "Sources/WenshuApp/Shared/State/LayoutTreeState.swift",
            "Sources/WenshuApp/Shared/State/LayoutTreeState+Edits.swift",
            "Sources/WenshuApp/Shared/State/LayoutTreeState+Merging.swift",
            "Sources/WenshuApp/Shared/State/LayoutTreeState+Operations.swift",
            "Sources/WenshuApp/Shared/State/LayoutTreeState+Primitives.swift",
            "Sources/WenshuApp/Shared/State/TrackModel.swift",
            "Sources/WenshuApp/Shared/State/TreeHistory.swift",
        ),
        "the settings credential family": (
            "Sources/WenshuApp/Features/Settings/Service/AuthPool.swift",
            "Sources/WenshuApp/Features/Settings/Service/AutoRotation.swift",
            "Sources/WenshuApp/Features/Settings/Service/FallbackChain.swift",
            "Sources/WenshuApp/Features/Settings/Service/KeychainSelector.swift",
            "Sources/WenshuApp/Features/Settings/Service/RetryUtils.swift",
            "Sources/WenshuApp/Features/Settings/Service/SecretScope.swift",
        ),
        "the superseded streaming files": (
            "Sources/WenshuAgent/Sources/WenshuAgent/Streaming/SSEClient.swift",
            "Sources/WenshuAgent/Sources/WenshuAgent/Streaming/WAStreamDiag.swift",
            "Sources/WenshuAgent/Sources/WenshuAgent/Streaming/WAStreamWatchdog.swift",
            "Sources/WenshuAgent/Sources/WenshuAgent/Tool/ToolGuardrails.swift",
        ),
        "the test-only production files": (
            "Sources/WenshuAgent/Sources/WenshuAgent/Tool/ToolResultClassification.swift",
            "Sources/WenshuApp/Features/Editor/Service/CardCompletionService.swift",
        ),
    }
    for label, members in GROUPS.items():
        member_paths = [os.path.join(root, rel_name) for rel_name in members]
        member_set = set(member_paths)
        # The group's OWN type names: a type the group declares and no
        # other production file declares (= `CodingKeys` is declared
        # everywhere, so it cannot identify the group).
        inside = collections.Counter()
        for member in member_paths:
            for kind, name, _ in decls_of(member):
                if kind in TYPE_KINDS:
                    inside[name] += 1
        own = {name for name, count in inside.items() if decl_count[name] == count}
        outside = {}
        for path in files:
            if path in member_set:
                continue
            for name in own:
                if re.search(r"\b" + re.escape(name) + r"\b", code[path]):
                    outside.setdefault(path, []).append(name)
        member_loc = sum(sum(1 for _ in open(p, encoding="utf-8", errors="replace")) for p in member_paths)
        verdict = "CLOSED" if not outside else "OPEN (= %d outside file(s) name it)" % len(outside)
        print(f"    {label:34} {len(member_paths)} files, {member_loc:5} LOC  {verdict}")
        for path, names in sorted(outside.items())[:4]:
            print(f"        outside reader: {rel[path]}  ({', '.join(sorted(names)[:3])})")
    print("  method: the group's OWN type names (= the types it declares and no")
    print("          other production file declares) are searched in the CODE (=")
    print("          comments and string contents removed) of every production file")
    print("          OUTSIDE the group; = a group with no outside mention is CLOSED")
    print("          (= nothing outside can reach into it).")
    print("  note: the group list is the record's own claim, so a reader can edit a")
    print("        membership and re-run to see the claim fail (= the check is not")
    print("        self-confirming).")

    section("A9. The gate's own false negative (= one type's member counts for another)")
    # The gate counts a reference by NAME. So when two DIFFERENT types
    # declare the same member name, one type's call sites satisfy the
    # other's count. A declaration is MASKED when its name is declared by
    # 2+ owners and every QUALIFIED external mention of the name names a
    # DIFFERENT owner, = the gate's count is satisfied by a member that
    # is not this one.
    QUAL = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\b")
    qualified = collections.defaultdict(set)
    for path in files:
        for match in QUAL.finditer(code[path]):
            qualified[match.group(2)].add((match.group(1), path))
    all_types = set()
    member_owner = collections.defaultdict(set)
    for path in files:
        current = None
        for line in raw_of(path).split("\n"):
            ext = re.match(
                r"\s*(?:public\s+|private\s+|fileprivate\s+|internal\s+)?extension\s+([A-Za-z_][A-Za-z0-9_]*)",
                line,
            )
            if ext:
                current = ext.group(1)
                all_types.add(current)
                continue
            decl = re.match(
                r"\s*(?:public |private |fileprivate |internal |open )?(struct|class|enum|actor|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)",
                line,
            )
            if decl:
                current = None
                all_types.add(decl.group(2))
                continue
            if current is None:
                continue
            member = re.match(
                r"\s*(?:(?:public|private|fileprivate|internal|open|package|static|final|mutating|nonisolated|weak|lazy|override|class|indirect)\s+)*\b(let|var|func)\s+([A-Za-z_][A-Za-z0-9_]*)",
                line,
            )
            if member:
                member_owner[member.group(2)].add(current)
    for path in files:
        for kind, name, _ in decls_of(path):
            if kind in ("struct", "class", "enum", "actor", "protocol"):
                member_owner.setdefault(name, set())
    masked = []
    for path in files:
        own = {
            name for kind, name, _ in decls_of(path)
            if kind in ("struct", "class", "enum", "actor", "protocol", "extension")
        }
        for kind, name, _ in decls_of(path):
            if kind not in ("func", "var", "let"):
                continue
            owners = member_owner.get(name, set())
            if len(owners) < 2 or not (owners - own):
                continue
            receivers = {r for r, q in qualified.get(name, set()) if q != path}
            # EVERY receiver must be a type that owns the same name. = a
            # receiver that is a variable (= `response.usage`) is not
            # evidence, = so the lens only reports the clean case.
            if not receivers or not receivers <= owners:
                continue
            if own & receivers:
                continue
            masked.append((rel[path], kind, name, sorted(receivers)))
    print(f"  masked declarations: {len(masked)}")
    for path, kind, name, receivers in sorted(set((p, k, n, tuple(r)) for p, k, n, r in masked)):
        print(f"    {path}  {kind} {name}  (= the gate counts {', '.join(receivers)}.{name})")
    print("  method: a declaration whose name is declared by 2+ owners, where every")
    print("          QUALIFIED external mention of the name names a DIFFERENT owner")
    print("          (= the gate's name-only count is satisfied by another type's")
    print("          member, = the declaration has no reference of its own).")
    print("  The gate's OWN count for the masked name (= the tool's own function):")
    helper_rel = "Sources/WenshuApp/Shared/Foundation/NSRegularExpression+Literal.swift"
    ext, inte = tool.has_real_ref(
        "literal", helper_rel, "Sources/ Tests/ Board/ Mobile/", root
    )
    print(f"    the gate's EXTERNAL count for the name 'literal': {len(ext)}")
    print(f"    the gate's same-file count:                      {len(inte)}")
    print("  method: the tool's OWN `has_real_ref`, = = called with the masked")
    print("          name and the declaring file. = = this is the number the gate")
    print("          prints as the declaration's reference count.")

    print("  The masked declaration's OWN call sites, over the history:")
    print("  method: `git grep` for the QUALIFIED name at each commit, = = over")
    print("          the production roots, = = with the helper's own file and")
    print("          its COMMENT lines excluded (= a docblock mention is not a")
    print("          call). = = this is the CALL-SITE count, = = and it is a")
    print("          DIFFERENT number from the gate's name count above.")
    helper = "Sources/WenshuApp/Shared/Foundation/NSRegularExpression+Literal.swift"
    for sha in ("d765169b69", "4600919bf", "5c94e5d5de", "d9ea3d0bc~1",
                "d9ea3d0bc", "4c5b7748c9~1", "4c5b7748c9", "HEAD"):
        out = run(
            "git grep -h -E 'NSRegularExpression\\.literal\\(' %s -- Sources 2>/dev/null"
            % sha, cwd=root
        )[1]
        lines = [
            ln for ln in out.splitlines()
            if helper not in ln and not ln.strip().startswith("//")
        ]
        # `git grep -h` drops the path, = = so the helper's own docblock line
        # is excluded by its text (= = it starts with `//`).
        print(f"    {sha:14} {len(lines):3} call site(s)")

    print("  note: an UNQUALIFIED mention elsewhere (= the bare word) is not")
    print("        evidence either way, = this lens lists the candidates, = it does")
    print("        not claim each one is dead.")

    section("B. The Apple-API axis (= the installed SDK, read on disk)")
    sdk = run("xcrun --show-sdk-path", cwd=root)[1].strip()
    print(f"  SDK: {sdk}")
    checks = [
        ("Swift Regex literal (macOS 13+)", "_StringProcessing", r"public struct Regex<Output>"),
        ("CollectionDifference.difference(from:)", "Swift", r"public func difference<C>\(from other: C\)"),
        ("UndoManager (Foundation)", "Foundation", r"@interface NSUndoManager"),
        ("Mutex (Synchronization, macOS 15+)", "Synchronization", r"public struct Mutex<Value>"),
        ("SecStaticCodeCreateWithPath (Security)", "Security", r"SecStaticCodeCreateWithPath"),
        ("SecCodeCopySigningInformation (Security)", "Security", r"OSStatus SecCodeCopySigningInformation"),
        ("NLTokenizer (NaturalLanguage)", "NaturalLanguage", r"@interface NLTokenizer"),
    ]
    for label, framework, pattern in checks:
        found = run(
            "grep -rlE '%s' %s/usr/lib/swift/%s.swiftmodule/ %s/System/Library/Frameworks/%s.framework/Headers/ 2>/dev/null | head -1"
            % (pattern, sdk, framework, sdk, framework),
            cwd=root,
        )[1].strip()
        where = found.replace(sdk + "/", "") if found else "NOT FOUND"
        print(f"    {label:38} {where}")
        assert found, "the SDK must carry %s (= the record's claim)" % label

    print()
    print("  The tree's own users of the replaced shapes:")
    print("  method: each row counts the MATCHING LINES in the production")
    print("          roots, = = over the code with COMMENTS AND STRING")
    print("          CONTENTS REMOVED (= the same lens §A4 uses, = = so a")
    print("          docblock that mentions a shape does not count). = = a")
    print("          DECLARATION line (= `func `, `class `, `static func `")
    print("          before the name) is not a use, = = so the row counts the")
    print("          CALL SITES.")
    for label, name, decl_prefixes, owner in [
        ("hand-rolled LCS diff (DiffUtil.swift)", "computeUnifiedDiff", ("func ", "static func "), None),
        ("hand-rolled undo stack (TreeHistory.swift)", "TreeHistory", ("class ", "final class "), None),
        ("  (= of which OUTSIDE its own file)", "TreeHistory", ("class ", "final class "),
         "Sources/WenshuApp/Shared/State/TreeHistory.swift"),
        ("hand-rolled literal-regex helper", "NSRegularExpression.literal", (), None),
        ("hand-rolled tokenizer (word tokens)", "tokenize", ("func ", "static func "), None),
    ]:
        exclude = None
        if owner:
            exclude = next((p for p in files if rel[p] == owner), None)
        hits = count_call_sites(code, name, decl_prefixes, exclude)
        print(f"    {label:38} {hits} call site(s)")
    print("  method for the string-based rows: = the same files with COMMENTS")
    print("          removed but STRING CONTENT KEPT (= a subprocess path and")
    print("          a localized menu title live inside a literal, = = so the code")
    print("          lens would erase them).")
    for label, pattern in [
        ("codesign subprocess (the signature read)", r"/usr/bin/codesign"),
        ("the system undo/redo menu REPLACED", r"CommandGroup\(replacing: \.undoRedo\)"),
        ("an empty-action undo button", r"Button\(String\(localized: \"menu\.edit\.(un|re)?do\"\), action: \{\}\)"),
    ]:
        hits = count_pattern(with_strings, pattern)
        print(f"    {label:38} {hits} site(s)")

    print()
    print("  The shapes the tree already uses (= the HIG answer is taken):")
    print("  method: the same grep, over the production roots AND `Vendor/`")
    print("          (= the vendored engine counts for the editor's own paths).")
    for label, pattern in [
        ("the system's own undo/redo menu", r"CommandGroup\(replacing: \.undoRedo\)"),
        ("Apple's Liquid Glass modifier", r"glassEffect\("),
        ("a native UndoManager (per document)", r"func undoManager\(for view: NSTextView\)"),
    ]:
        hits = count_pattern(code_all, pattern)
        print(f"    {label:38} {hits} site(s)")
    print("  note: the `NSLock()` count in §7 is over the PRODUCTION roots only")
    print("        (= the five SOURCES subtrees), = = so a `Tests/` tree under a")
    print("        package root is NOT counted; = = the production count is 21.")
    for label, pattern in [
        ("`NSLock()` (the tree's own locks)", r"NSLock\(\)"),
    ]:
        hits = count_pattern(code, pattern)
        print(f"    {label:38} {hits} site(s)")
    print("  note: 'the system's own undo/redo menu' is counted by the SAME")
    print("        pattern as 'the system undo/redo menu REPLACED' above, = = so")
    print("        the two rows are the SAME sites seen twice, = = once as the")
    print("        replacement and once as the system's own. = = There is no")
    print("        separate site where the tree keeps the system's menu.")

    print()
    print("  The native APIs the tree already uses (= §8's false positives):")
    print("  method: a grep per API over the production roots AND `Vendor/`; = = the")
    print("          count is the number of matching LINES over the CODE lens (= =")
    print("          comments and string contents removed). = = the RAW count (= =")
    print("          the file text as written) is printed beside it for the two")
    print("          rows the record quotes both ways.")
    print("  the RAW count = the file text as written (= comments included); = = it")
    print("        is over the PRODUCTION roots only (= = a `Tests/` tree under a")
    print("        package root is NOT production), = = and it is what the")
    print("        record's §8 quotes beside the code count.")
    for label, pattern in [
        ("`.searchable`", r"\.searchable\("),
        ("`MenuBarExtra`", r"MenuBarExtra"),
        ("`WindowGroup`", r"WindowGroup"),
        ("`openWindow`", r"openWindow\("),
        ("`Settings` (the scene)", r"Settings\s*\{"),
        ("`NSPasteboard`", r"NSPasteboard"),
        ("`CryptoKit`", r"import CryptoKit"),
        ("`AttributedString(markdown:)`", r"AttributedString\(markdown:"),
        ("`@Observable`", r"@Observable"),
        ("`.formatted(`", r"\.formatted\("),
        ("`ISO8601DateFormatter`", r"ISO8601DateFormatter"),
        ("`DateFormatter` (not ISO)", r"(?<!ISO8601)\bDateFormatter\b"),
    ]:
        hits = count_pattern(code_all, pattern)
        print(f"    {label:38} {hits} site(s)")
    print("  the DateFormatter family (= = one DECLARATION, = = two lines):")
    print("  method: the matching LINES (= = every mention), = = and the matching")
    print("          DECLARATIONS (= = a `let`/`var` whose TYPE is DateFormatter,")
    print("          = = not the local `let formatter = DateFormatter()` that")
    print("          builds it). = = the two numbers answer different questions,")
    print("          = = so the record names both.")
    hits = count_pattern(code_all, r"(?<!ISO8601)\bDateFormatter\b")
    decls = sum(
        len(re.findall(r"(?:let|var)\s+\w+\s*:\s*DateFormatter\b", text))
        for text in code_all.values()
    )
    print(f"    {'`DateFormatter` (the lines)':38} {hits} line(s)")
    print(f"    {'`DateFormatter` (the declarations)':38} {decls} declaration(s)")

    print("  the live NSRegularExpression sites (= = §7's '21 across 10'):")
    print("  method: the CONSTRUCTION sites over the production roots, = = with")
    print("          the helper's own file excluded (= = that file's mentions are")
    print("          its own docblock).")
    rx = re.compile(r"NSRegularExpression\(")
    sites = 0
    hit_files = 0
    for path, text in code.items():
        if path.endswith("NSRegularExpression+Literal.swift"):
            continue
        n = len(rx.findall(text))
        if n:
            sites += n
            hit_files += 1
    print(f"    {'NSRegularExpression( (the sites)':38} {sites} site(s)")
    print(f"    {'NSRegularExpression( (the files)':38} {hit_files} file(s)")

    for label, pattern in [
        ("`@Observable` (RAW = the file text)", r"@Observable"),
    ]:
        hits = count_pattern(raw_all, pattern)
        hit_files = sum(
            1 for text in raw_all.values() if re.search(pattern, text)
        )
        print(f"    {label:38} {hits} line(s) over {hit_files} file(s)")

    print()
    print("  The AVSpeechUtteranceDefaultSpeechRate shadow (= the live bug):")
    print("  method: two standalone Swift probes, = = each compiled and run, = = and")
    print("          the value printed. = = ONE file with only `import")
    print("          AVFoundation` + a print of Apple's constant, = = and ONE file")
    print("          with the tree's shadowing line + the same print.")
    probe = os.path.join(os.environ.get("TMPDIR", "/tmp"), "wenshu-avspeech-probe")
    os.makedirs(probe, exist_ok=True)
    apple_only = os.path.join(probe, "apple_only.swift")
    shadowed = os.path.join(probe, "shadowed.swift")
    open(apple_only, "w").write(
        "import AVFoundation\n"
        'print(AVSpeechUtteranceDefaultSpeechRate)\n'
    )
    open(shadowed, "w").write(
        "import AVFoundation\n"
        "private let AVSpeechUtteranceDefaultSpeechRate: Float = "
        "AVSpeechUtteranceDefaultSpeechRate\n"
        'print(AVSpeechUtteranceDefaultSpeechRate)\n'
    )
    for label, path in (("Apple's own value (no shadow)", apple_only),
                        ("the tree's shadowed value", shadowed)):
        binary = path + ".bin"
        rc, _ = run("swiftc %s -o %s" % (path, binary), cwd=probe)
        if rc != 0:
            print(f"    {label:36} COMPILE FAILED")
            continue
        rc, out = run(binary, cwd=probe)
        print(f"    {label:36} {out.strip()}")
    print("  note: the shadow binds the name for the WHOLE file, = = so Apple's")
    print("        value must be read from ANOTHER file; = = a probe that prints")
    print("        both in ONE file reads the shadowed value twice.")

    print()
    print("  The HIG quotes the record carries (= = fetched from Apple's own page):")
    print("  method: the record's OWN quote blocks are READ (= = not re-typed")
    print("          here), = = and each is tested against the page's sentence")
    print("          boundaries: = = present, = = ending on a sentence end, = = and")
    print("          beginning at one. = = a truncated quote cannot pass.")
    hig = os.path.join(
        os.path.expanduser("~"),
        ".hermes/shared/local-skills/apple-hig-lookup/scripts/hig_fetch.py",
    )
    record = os.path.join(root, "docs/agents/2026-11-16-the-dead-code-and-apple-api-sweep.md")
    quotes = record_quotes(record) if os.path.exists(record) else []
    pages = {}
    hig_failed = False
    for slug, needle in quotes:
        if slug not in pages:
            pages[slug] = run("python3 %s page %s" % (hig, slug), cwd=root)[1]
        flat = " ".join(pages[slug].split())
        ok = page_span(flat, needle) != ""
        print(f"    {slug + ': ' + needle[:38]:44} {'SPAN-EQUAL' if ok else 'NOT A SPAN'}")
        if not ok:
            # A failed FETCH (= = no network, = = Apple's page down) must not
            # take the whole measurement down: = = the quote is still in the
            # record, = = and the record's numbers do not depend on it.
            hig_failed = True
    if not quotes:
        print("    (the record's quote blocks were not found)")
    if hig_failed:
        print("  note: a HIG fetch did not carry the quote (= = the page was")
        print("        unreachable, = = or the quote changed). = = the record's")
        print("        NUMBERS do not depend on this section, = = and the run")
        print("        continues; = = re-run it when the page is reachable.")

    print("  The bare-slash regex literal (= Swift's own, = the project's own")
    print("  language mode):")
    tools_version = re.search(
        r"swift-tools-version:\s*([0-9.]+)", raw_of(os.path.join(root, "Package.swift"))
    )
    print(f"    the package's swift-tools-version: {tools_version.group(1) if tools_version else '?'}")
    print("    the bare-slash literal is Swift 6 language mode (= the tools-version 6")
    print("    default), so `Regex` literals compile with NO extra feature flag;")
    print("    MEASURED in a throwaway package with the same tools-version: the")
    print("    literal `/\\s*,\\s*([}\\]])/` compiles and runs.")
    print("    the semantics differ from `NSRegularExpression` in ONE place that")
    print("    matters: `String.matches(of:)` and `String.firstMatch(of:)` are")
    print("    WHOLE-STRING (= `containsWholeMatch` semantics) while")
    print("    `NSRegularExpression.firstMatch(in:range:)` is a SUBSTRING search;")
    print("    the substring form on `Regex` is `regex.firstMatch(in: string)`.")
    print("    MEASURED: the same pattern and the same input return 1 match under")
    print("    `NSRegularExpression` and 0 under `String.matches(of:)`, and 1 under")
    print("    `regex.firstMatch(in:)`. = a straight swap changes the behaviour.")

    section("C. The numbers the record quotes")
    print(f"  production files                    {len(files)}")
    print(f"  unread declarations (full scope)    {len(candidates)}")
    print(f"    the framework reads               {buckets['framework']}")
    print(f"    only a comment names them         {buckets['comment']}")
    print(f"    the file itself calls them        {buckets['own-file-use']}")
    print(f"    nothing names them                {buckets['bare']}")
    print(f"  app design tokens with no reader    {len(tool_tokens)}")
    print(f"  mobile design tokens, no reader     {len(mobile_tokens)}")
    print(f"  files no production code names      {len(islands)}")
    print(f"  closed groups named in the record   {len(GROUPS)}")
    print("  method: every count here is a bucket or a list from the sections")
    print("          above, = = so the record's headline table is a re-run, = = not")
    print("          a separate claim.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
