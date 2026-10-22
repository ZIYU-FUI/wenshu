#!/usr/bin/env python3
"""Measure how deep the front end's parameter drilling is.

Reads every .swift file under a root directory, strips comments and string
literals, finds the SwiftUI view structs, and reports two things:

  DEAD PARAMETERS        a view initializer parameter that the view never reads
  HEAVIEST INITIALIZERS  a construction site that passes the most arguments

A parameter threaded down through call sites and then dropped is invisible at
every call site, so the measurement has to be mechanical. Comments and string
literals are stripped before parsing, because a docblock naming a type reads
exactly like a use of that type to a text scan. The read search spans the
struct plus its extension blocks, because a parameter read only from an
extension is live.

Read-only: the tool reads the source tree and prints to stdout. It never
creates, moves or deletes a file. Standard library only.

Usage:
    python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp
    python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp --top 10
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

# A view struct: `struct Foo: View {` (generic parameters allowed).
VIEW_RE = re.compile(
    r"\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\b\s*(?:<[^<>]*>)?\s*:\s*([^{}]*?)\{"
)

# An extension block: `extension Foo {` (where clauses and conformances allowed).
EXT_RE = re.compile(
    r"\bextension\s+([A-Za-z_][A-Za-z0-9_]*)\b\s*(?:\[[^\]]*\])?\s*"
    r"(?:where\b[^{]*?)?(?::[^{}]*?)?\{"
)

# A stored property declaration at the start of a line.
PROP_RE = re.compile(
    r"^[ \t]*(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:public\s+|internal\s+|private\s+|fileprivate\s+)?"
    r"(?:private\(set\)\s+)?"
    r"(?:static\s+|class\s+|nonisolated\s+)*"
    r"(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(:|=|\{)",
    re.M,
)

# An initializer declaration. The lookbehind rejects `Foo.init(`.
INIT_RE = re.compile(r"(?<![.\w])init\s*\(")

# Property wrappers whose own initializer supplies a default, so the property
# is not a memberwise initializer parameter. Wrappers such as @State, @Binding
# and @Bindable only offer init(wrappedValue:) and stay in the memberwise init.
WRAPPER_RE = re.compile(
    r"@(?:Environment|FocusState|FocusValue|GestureState|Namespace)\b"
)

STATIC_RE = re.compile(r"\b(?:static|class)\b")

IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


# ------------------------------------------------------------------ lexing --


def strip_noise(src: str) -> str:
    """Blank comments and string literals, keeping offsets and line numbers.

    Line comments, nested block comments and string literals (single quoted,
    double quoted, and raw `#\"...\"#`) are replaced by spaces. A type name
    mentioned in a docblock or inside a string never reads as a use of it.
    Every file read in this tool goes through this function.
    """
    out = list(src)
    n = len(src)
    i = 0
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                out[i] = " "
                i += 1
            continue
        if c == "/" and nxt == "*":
            i = _blank_block_comment(src, out, i)
            continue
        if c == "#":
            j = i
            while j < n and src[j] == "#":
                j += 1
            if j < n and src[j] == '"':
                i = _blank_raw_string(src, out, i, j - i)
                continue
            i = j
            continue
        if c == '"':
            i = _blank_quoted(src, out, i, '"')
            continue
        if c == "'":
            i = _blank_quoted(src, out, i, "'")
            continue
        i += 1
    return "".join(out)


def _blank_block_comment(src: str, out: list, i: int) -> int:
    """Blank a block comment, nested block comments included."""
    n = len(src)
    out[i] = out[i + 1] = " "
    i += 2
    depth = 1
    while i < n and depth:
        if src[i] == "/" and i + 1 < n and src[i + 1] == "*":
            depth += 1
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if src[i] == "*" and i + 1 < n and src[i + 1] == "/":
            depth -= 1
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if src[i] != "\n":
            out[i] = " "
        i += 1
    return i


def _blank_quoted(src: str, out: list, i: int, quote: str) -> str:
    """Blank a quoted literal, keeping the escape sequences inside it.

    A Swift string interpolation (\\(expr)) is an EXPRESSION, not literal
    text: the code inside it reads a value. Blanking the whole literal
    would hide that read, and the detector would then report a live
    parameter as dead. So the interpolation's contents are kept and only
    the surrounding literal text is blanked.
    """
    n = len(src)
    triple = quote == '"' and src[i : i + 3] == '"""'
    delim = quote * 3 if triple else quote
    for k in range(i, min(i + len(delim), n)):
        out[k] = " "
    j = i + len(delim)
    while j < n:
        if src[j] == "\\" and j + 1 < n:
            # An interpolation is a backslash followed by '('.
            if src[j + 1] == "(":
                out[j] = " "
                depth = 0
                k = j + 1
                while k < n:
                    if src[k] == "(":
                        depth += 1
                    elif src[k] == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    k += 1
                # Keep the interpolated expression verbatim: it is code.
                for m in range(j + 1, min(k + 1, n)):
                    out[m] = src[m]
                if k < n:
                    out[k] = src[k]
                j = k + 1
                continue
            out[j] = " "
            if src[j + 1] != "\n":
                out[j + 1] = " "
            j += 2
            continue
        if src[j : j + len(delim)] == delim:
            for k in range(j, j + len(delim)):
                out[k] = " "
            return j + len(delim)
        if not triple and src[j] == "\n":
            return j + 1
        if src[j] != "\n":
            out[j] = " "
        j += 1
    return j


def _blank_raw_string(src: str, out: list, i: int, hashes: int) -> int:
    """Blank a raw string literal such as `#\"...\"#`."""
    n = len(src)
    j = i + hashes
    triple = src[j : j + 3] == '"""'
    delim = ('"""' if triple else '"') + "#" * hashes
    for k in range(i, min(j + (3 if triple else 1), n)):
        out[k] = " "
    j = j + (3 if triple else 1)
    while j < n:
        if src[j : j + len(delim)] == delim:
            for k in range(j, j + len(delim)):
                out[k] = " "
            return j + len(delim)
        if src[j] != "\n":
            out[j] = " "
        j += 1
    return j


# ----------------------------------------------------------------- parsing --


def match_brace(src: str, open_idx: int) -> int:
    """Index of the brace closing the one at open_idx."""
    depth = 0
    for i in range(open_idx, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    return len(src) - 1


def match_paren(src: str, open_idx: int) -> int:
    """Index of the parenthesis closing the one at open_idx."""
    depth = 0
    for i in range(open_idx, len(src)):
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1


def depth_map(text: str) -> list:
    """Brace depth in front of every character of text."""
    depths = [0] * (len(text) + 1)
    d = 0
    for i, ch in enumerate(text):
        depths[i] = d
        if ch == "{":
            d += 1
        elif ch == "}":
            d -= 1
    depths[len(text)] = d
    return depths


def split_spans(text: str, base: int = 0) -> list:
    """Split an argument list on its top level commas.

    Returns (start, end) offsets into the original text. Brackets and braces
    hold a comma inside a nested expression. A generic argument list is a
    bracket too, but only when an upper case type name follows the angle.
    """
    spans = []
    depth = 0
    angle = 0
    start = 0
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "<" and depth == 0:
            nxt = text[i + 1] if i + 1 < n else ""
            if nxt.isupper() or nxt == "_":
                angle += 1
        elif ch == ">" and depth == 0 and angle > 0:
            angle -= 1
        if ch == "," and depth == 0 and angle == 0:
            spans.append((base + start, base + i))
            start = i + 1
        i += 1
    if start < n:
        spans.append((base + start, base + n))
    return spans


def line_of(text: str, offset: int) -> int:
    """One based line number of an offset."""
    return text.count("\n", 0, offset) + 1


def parse_views(src: str) -> list:
    """Every view struct in a source file.

    A SwiftUI view is either a `View` or a `ViewModifier`. Both carry
    initializer parameters, and a `ViewModifier` can carry the most of
    them (= the export modifier held 13), so a measurement that only
    recognizes `View` misses the heaviest call sites in the app.
    """
    out = []
    for m in VIEW_RE.finditer(src):
        if not re.search(r"\b(View|ViewModifier)\b", m.group(2)):
            continue
        brace = src.index("{", m.start())
        end = match_brace(src, brace)
        out.append(
            {
                "name": m.group(1),
                "decl_offset": m.start(),
                "line": line_of(src, m.start()),
                "start": brace + 1,
                "end": end,
            }
        )
    return out


def parse_extensions(src: str) -> list:
    """Every extension block in a source file."""
    out = []
    for m in EXT_RE.finditer(src):
        brace = src.index("{", m.start())
        end = match_brace(src, brace)
        out.append({"name": m.group(1), "start": brace + 1, "end": end})
    return out


def classify_decl(text: str, pos: int, sep: str) -> str:
    """'stored', 'defaulted' or 'computed' for a property declaration.

    pos points just past the separator that follows the property name.
    """
    if sep == "=":
        return "defaulted"
    if sep == "{":
        return "computed"
    n = len(text)
    i = pos
    depth = 0
    while i < n:
        ch = text[i]
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif depth == 0:
            if ch == "=":
                return "defaulted"
            if ch == "{":
                return "computed"
            if ch == "\n":
                j = i + 1
                while j < n and text[j] in " \t":
                    j += 1
                if j < n and text[j] not in "|&":
                    return "stored"
                i = j
                continue
        i += 1
    return "stored"


def stored_properties(text: str, depths: list, start: int, end: int) -> list:
    """The stored properties declared directly in a struct body.

    A property declared inside a function body is a local, not a property.
    """
    out = []
    base = depths[start]
    for pm in PROP_RE.finditer(text, start, end):
        if depths[pm.start()] != base:
            continue
        name = pm.group(1)
        nm = re.search(r"\b(?:var|let)\s+" + re.escape(name) + r"\b", pm.group(0))
        if nm:
            offset = pm.start() + nm.start() + nm.group(0).rfind(name)
        else:
            offset = pm.start()
        out.append(
            {
                "name": name,
                "kind": classify_decl(text, pm.end(), pm.group(2)),
                "offset": offset,
                "text": pm.group(0),
            }
        )
    return out


def find_init(text: str, depths: list, start: int, end: int):
    """The explicit initializer of a type, or None.

    An initializer declared at the top level of the struct body or of one of
    its extension blocks. A nested type keeps its own initializer.
    """
    base = depths[start]
    for m in INIT_RE.finditer(text, start, end):
        if depths[m.start()] != base:
            continue
        open_idx = text.index("(", m.end() - 1)
        close = match_paren(text, open_idx)
        if close == -1:
            continue
        j = close + 1
        while j < len(text) and text[j] in " \t\r\n":
            j += 1
        body_end = close
        if j < len(text) and text[j] == "{":
            body_end = match_brace(text, j) + 1
        return {
            "sig_open": open_idx,
            "sig_close": close,
            "body_start": close + 1,
            "body_end": body_end,
        }
    return None


def init_params(text: str, init: dict) -> list:
    """The parameter names of an explicit initializer, with their offsets."""
    out = []
    body = text[init["sig_open"] + 1 : init["sig_close"]]
    for a, b in split_spans(body, init["sig_open"] + 1):
        seg = text[a:b]
        cut = len(seg)
        depth = 0
        for i, ch in enumerate(seg):
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            elif depth == 0 and ch in ":=":
                cut = i
                break
        ids = list(IDENT_RE.finditer(seg[:cut]))
        if not ids:
            continue
        last = ids[-1]
        if last.group(0) == "_":
            continue
        out.append({"name": last.group(0), "offset": a + last.start()})
    return out


def memberwise_params(props: list) -> list:
    """The parameters of the memberwise initializer of a struct.

    A stored property with a default value, a computed property, a static
    property and a property whose wrapper supplies its own default are not
    memberwise initializer parameters.
    """
    out = []
    seen = set()
    for p in props:
        if p["kind"] != "stored":
            continue
        if WRAPPER_RE.search(p["text"]):
            continue
        if STATIC_RE.search(p["text"]):
            continue
        if p["name"] in seen:
            continue
        seen.add(p["name"])
        out.append({"name": p["name"], "offset": p["offset"]})
    return out


# ------------------------------------------------------------ read counting --


def is_label(text: str, offset: int, length: int) -> bool:
    """True when an occurrence is an argument label, not a read of a value.

    An argument label sits in call position: `Card(onClose: value)`. A ternary
    branch (`cond ? a : b`) and a dictionary key are not labels, so only the
    two characters that open a call argument list count.
    """
    j = offset + length
    while j < len(text) and text[j] in " \t":
        j += 1
    if j >= len(text) or text[j] != ":":
        return False
    if j + 1 < len(text) and text[j + 1] == ":":
        return False
    k = offset - 1
    while k >= 0 and text[k] in " \t\r\n":
        k -= 1
    if k < 0:
        return False
    return text[k] in "(,"


def count_reads(name: str, spans: list, srcs: list, excluded: set, ranges: list) -> int:
    """How often a parameter name is read inside the spans of its type.

    A span is the body of the struct plus the body of every extension of the
    same type, in this file and in the other files of the tree. The excluded
    offsets and ranges carry the declaration, the initializer signature and
    the self assignment of the parameter.
    """
    pat = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])")
    reads = 0
    for fidx, start, end in spans:
        text = srcs[fidx]
        for m in pat.finditer(text, start, end):
            offset = m.start()
            if (fidx, offset) in excluded:
                continue
            if any(rf == fidx and ra <= offset < rb for rf, ra, rb in ranges):
                continue
            if is_label(text, offset, len(name)):
                continue
            reads += 1
    return reads


def init_assignments(text: str, init: dict, param: str) -> list:
    """The properties an initializer assigns from a parameter.

    `self.name = param` hands the parameter to the property `name`, so a read
    of `name` anywhere in the type is a read of the parameter. The wrapper
    form `self._name = param` names the same property.
    """
    out = []
    pat = re.compile(
        r"self\s*\.\s*(_?)(" + re.escape(param) + r")\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\b"
    )
    for m in pat.finditer(text, init["body_start"], init["body_end"]):
        if m.group(3) != param:
            continue
        out.append(
            {
                "dest": m.group(2),
                "lhs": m.start(2),
                "rhs": m.start(3),
            }
        )
    return out


# ----------------------------------------------------------------- analysis --


def analyze(root) -> dict:
    """Measure the parameter drilling of every view struct under root."""
    root_path = Path(root)
    files = sorted(root_path.rglob("*.swift"))
    srcs = []
    depths = []
    views = []
    exts = []
    for idx, path in enumerate(files):
        raw = path.read_text(encoding="utf-8", errors="replace")
        src = strip_noise(raw)
        srcs.append(src)
        depths.append(depth_map(src))
        rel = os.path.relpath(str(path), str(root_path))
        for v in parse_views(src):
            v["file"] = idx
            v["path"] = rel
            views.append(v)
        for e in parse_extensions(src):
            e["file"] = idx
            e["path"] = rel
            exts.append(e)

    views_by_name = {}
    for v in views:
        views_by_name.setdefault(v["name"], []).append(v)
    exts_by_name = {}
    for e in exts:
        exts_by_name.setdefault(e["name"], []).append(e)

    report = {"views": {}, "dead": [], "sites": [], "files": len(files)}
    known = set(views_by_name.keys())

    for name in sorted(views_by_name):
        group = views_by_name[name]
        primary = group[0]
        spans = [(v["file"], v["start"], v["end"]) for v in group]
        for e in exts_by_name.get(name, []):
            spans.append((e["file"], e["start"], e["end"]))

        pfile = primary["file"]
        ptext = srcs[pfile]
        props = stored_properties(ptext, depths[pfile], primary["start"], primary["end"])
        prop_offsets = {}
        for p in props:
            prop_offsets.setdefault(p["name"], []).append(p["offset"])

        init = None
        init_file = None
        for fidx, start, end in spans:
            found = find_init(srcs[fidx], depths[fidx], start, end)
            if found:
                init = found
                init_file = fidx
                break

        if init is not None:
            params = init_params(srcs[init_file], init)
        else:
            params = memberwise_params(props)

        report["views"][name] = {
            "params": [p["name"] for p in params],
            "path": primary["path"],
            "line": primary["line"],
            "stored": [p["name"] for p in props],
        }

        for p in params:
            excluded = set()
            ranges = []
            if init is not None:
                ranges.append((init_file, init["sig_open"] + 1, init["sig_close"]))
                for off in prop_offsets.get(p["name"], []):
                    excluded.add((pfile, off))
            else:
                for off in prop_offsets.get(p["name"], []):
                    excluded.add((pfile, off))

            dests = []
            if init is not None:
                for a in init_assignments(srcs[init_file], init, p["name"]):
                    dests.append(a["dest"])
                    excluded.add((init_file, a["lhs"]))
                    excluded.add((init_file, a["rhs"]))

            if dests:
                # The parameter flows into a property: a read of that property
                # anywhere in the type is a read of the parameter.
                reads = 0
                for dest in sorted(set(dests)):
                    for off in prop_offsets.get(dest, []):
                        excluded.add((pfile, off))
                    reads += count_reads(dest, spans, srcs, excluded, ranges)
                reads += count_reads(p["name"], spans, srcs, excluded, ranges)
            else:
                reads = count_reads(p["name"], spans, srcs, excluded, ranges)

            if reads == 0:
                report["dead"].append(
                    {
                        "type": name,
                        "param": p["name"],
                        "path": primary["path"],
                        "line": primary["line"],
                        "declared_line": line_of(srcs[pfile], p["offset"]),
                        "reads": reads,
                    }
                )

    # Construction sites: the arguments a caller must supply.
    for idx, src in enumerate(srcs):
        rel = os.path.relpath(str(files[idx]), str(root_path))
        for m in re.finditer(r"\b([A-Z][A-Za-z0-9_]*)\s*\(", src):
            callee = m.group(1)
            if callee not in known:
                continue
            open_idx = src.index("(", m.end() - 1)
            close = match_paren(src, open_idx)
            if close == -1:
                continue
            args = split_spans(src[open_idx + 1 : close], open_idx + 1)
            report["sites"].append(
                {
                    "type": callee,
                    "args": len(args),
                    "path": rel,
                    "line": line_of(src, open_idx),
                }
            )

    report["dead"].sort(key=lambda d: (d["path"], d["line"], d["type"], d["param"]))
    report["sites"].sort(key=lambda s: (-s["args"], s["path"], s["line"]))
    return report


def print_report(report: dict, top: int) -> None:
    """Print the two report sections."""
    print("DEAD PARAMETERS")
    if not report["dead"]:
        print("(none)")
    for d in report["dead"]:
        print(
            "%s:%d  %s.%s  (declared at line %d, %d reads)"
            % (d["path"], d["line"], d["type"], d["param"], d["declared_line"], d["reads"])
        )
    print()
    print("HEAVIEST INITIALIZERS")
    if not report["sites"]:
        print("(none)")
    for s in report["sites"][:top]:
        print("%s  %d args  %s:%d" % (s["type"], s["args"], s["path"], s["line"]))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Measure the front end's parameter drilling depth."
    )
    parser.add_argument(
        "--root",
        default="Sources/WenshuApp",
        help="root directory of the Swift sources (default: Sources/WenshuApp)",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=20,
        help="how many construction sites the report lists (default: 20)",
    )
    args = parser.parse_args(argv)

    root = Path(args.root)
    if not root.is_dir():
        print("measure-drill: root is not a directory: %s" % root)
        return 2

    report = analyze(root)
    print_report(report, args.top)
    return 0


if __name__ == "__main__":
    sys.exit(main())
