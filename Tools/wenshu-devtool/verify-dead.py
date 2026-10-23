#!/usr/bin/env python3
"""verify-dead.py — strict Swift dead-code verification for the wenshu tree.

What it reports:
- one verdict per Swift file: ALIVE (= every declaration has a reader),
  PARTIAL (= some declaration has none) or DEAD (= no declaration has one).
- in --ui-components mode: the declarations no file can reach
  (= deletion candidates), plus the reason every other declaration is alive.

Reachability, not a name match. A declaration is alive when a reader
exists:
- another file names it on a line that is not a comment (= that file
  depends on the declaration, in code or in a test that reads the
  source text),
- another file reads one of its members (= ".memberName"),
- another file calls a function whose return type is the declaration
  (= the value flows out of the declaring file),
- its own file uses it (= a constructor call, a stored property, a static
  member access, a parameter type).

Two refinements keep the rule honest:
- a name that only ever appears as a return type ('-> Foo') is a promise,
  not a use: the function may never be called, so the declaration stays
  unreachable until a caller exists,
- a member read counts only when that member name belongs to this
  declaration alone (= '.title' on another type proves nothing).

A declaration with no reader anywhere is a deletion candidate.

Run:
    python3 Tools/wenshu-devtool/verify-dead.py --ui-components
    python3 Tools/wenshu-devtool/verify-dead.py --ui-components --verbose \
        Sources/WenshuApp/Features/Editor/Service/WordCounter.swift
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

# The scope every reference search covers: all Swift files under Sources/
# and Tests/. A scope directory that does not exist is skipped.
SCOPE_DEFAULT = 'Sources/ Tests/'

# The directories that hold the views today: ten Features/<Name>/View
# directories plus Shared/UI. A glob that matches nothing is skipped, so
# a moved directory never breaks the scan.
VIEW_GLOBS = ('Sources/WenshuApp/Features/*/View', 'Sources/WenshuApp/Shared/UI')

# Declaration names too generic to prove a use: they are property names
# and protocol requirements, not the name of a reachable component.
GENERIC_NAMES = frozenset({
    'View', 'self', 'guard', 'init', 'body', 'return', 'where', 'some',
    'if', 'else', 'for', 'while', 'do', 'catch', 'in', 'as', 'is', 'try',
    'await', 'throws', 'value', 'id', 'name', 'title', 'count', 'index',
    'data', 'state', 'tag', 'type', 'kind', 'result', 'message', 'error',
    'success', 'failure', 'context', 'content', 'description', 'enabled',
    'visible', 'hashValue', 'debugDescription',
})

# A declaration that carries no access modifier is internal (= Swift's
# default access control level).
ACCESS_MODIFIERS = ('public', 'open', 'fileprivate', 'private', 'internal')

# A same-file line that starts with one of these declares something; it
# is not a use of the name it mentions.
DECL_PREFIXES = ('public ', 'private ', 'fileprivate ', 'internal ',
                 'static ', 'final ')

# The keywords that introduce a declaration: the name right after one of
# them is the declared name, not a use of that name.
DECL_KEYWORDS = frozenset({
    'struct', 'enum', 'class', 'actor', 'protocol', 'extension',
    'typealias', 'func', 'let', 'var', 'case',
})

DECL_RE = re.compile(
    r'^(?P<lead>\s*(?:public\s+|private\s+|fileprivate\s+|internal\s+|open\s+'
    r'|static\s+|final\s+|class\s+|indirect\s+)*)'
    r'(?P<kind>let|var|struct|class|enum|actor|func|extension|protocol'
    r'|typealias)\s+'
    r'(?P<name>\w+)', re.MULTILINE)

TOKEN_RE = re.compile(r'\w+', re.UNICODE)
LAST_WORD_RE = re.compile(r'(\w+)$')
TYPE_RE = re.compile(r'\b(struct|enum|class|actor|protocol|extension)\s+'
                     r'([A-Za-z_]\w*)')
FUNC_RE = re.compile(r'\bfunc\s+([A-Za-z_]\w*)')
MEMBER_RE = re.compile(r'\b(let|var|case|func|typealias|subscript)\s+'
                       r'([A-Za-z_]\w*)')
TYPE_NOISE = r'\b(some|any|Self|where|throws|rethrows|async|each)\b'


# --------------------------------------------------------------- decls

def get_decls(file_path, base=None):
    """Extract top-level declarations from a Swift file.

    Returns list of (kind, name, access_level) tuples. access_level is
    'public' / 'internal' / 'private' (= defaults to internal if none
    specified; = Swift's default access control level).

    The --ui-components mode in __main__ uses access_level to filter
    candidates: private members (= property storage + private helpers)
    are NOT considered 'UI components'; only public/internal types are
    candidate reusable components.
    """
    path = Path(file_path)
    if base is not None and not path.is_absolute():
        path = Path(base) / path
    content = path.read_text(encoding='utf-8', errors='replace')
    decls = []
    for m in DECL_RE.finditer(content):
        kind = m.group('kind')
        name = m.group('name')
        lead = m.group('lead') or ''
        access = 'internal'
        for mod in ACCESS_MODIFIERS:
            if mod in lead.split():
                access = mod
                break
        if name in GENERIC_NAMES:
            continue
        if len(name) < 3:
            continue
        decls.append((kind, name, access))
    return decls


# --------------------------------------------------------------- lexing

def strip_comments_and_strings(text):
    """Blank out comments and string literals, preserving every offset.

    Brace counting and declaration scanning need the code without the
    noise: a '}' inside a string literal must not close a type body, and
    a name inside a comment must not read as a use.
    """
    out = list(text)
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            j = n if j < 0 else j
            _blank(out, i, j)
            i = j
        elif ch == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            _blank(out, i, j)
            i = j
        elif text.startswith('"""', i):
            j = text.find('"""', i + 3)
            j = n if j < 0 else j + 3
            _blank(out, i, j)
            i = j
        elif ch == '#' and text.startswith('#"', i):
            j = text.find('"#', i + 2)
            j = n if j < 0 else j + 2
            _blank(out, i, j)
            i = j
        elif ch == '"':
            j = i + 1
            while j < n:
                if text[j] == '\\':
                    j += 2
                    continue
                if text[j] == '"':
                    j += 1
                    break
                if text[j] == '\n':
                    break
                j += 1
            _blank(out, i, min(j, n))
            i = j
        else:
            i += 1
    return ''.join(out)


def _blank(out, start, end):
    for k in range(start, min(end, len(out))):
        if out[k] != '\n':
            out[k] = ' '


def match_brace(code, open_index):
    """Index of the '}' that closes the '{' at open_index (= -1 if none)."""
    depth = 0
    for i in range(open_index, len(code)):
        c = code[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
    return -1


def match_paren(code, open_index):
    """Index of the ')' that closes the '(' at open_index (= -1 if none)."""
    depth = 0
    for i in range(open_index, len(code)):
        c = code[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


def is_return_position(prefix):
    """True when a name at this point is only a return type.

    '-> T', '-> T?', '-> [T]', '-> (T, U)' and '-> some T' all name a
    type the caller may never receive.
    """
    p = prefix.rstrip()
    while p:
        if p.endswith('[') or p.endswith('('):
            p = p[:-1].rstrip()
            continue
        stripped = re.sub(r'\b(some|any)$', '', p).rstrip()
        if stripped != p:
            p = stripped
            continue
        break
    return p.endswith('->')


def last_word(prefix):
    """The last identifier of a code prefix (= the keyword before it)."""
    m = LAST_WORD_RE.search(prefix.rstrip())
    return m.group(1) if m else ''


def type_names_in(text):
    """The identifiers a return type expression names."""
    cleaned = re.sub(TYPE_NOISE, ' ', text)
    return TOKEN_RE.findall(cleaned)


# --------------------------------------------------------------- the tree

def _is_comment_line(line):
    s = line.lstrip()
    return s.startswith('//') or s.startswith('/*') or s.startswith('*')


class SourceFile:
    """One Swift file: its text, its lines, and its code."""

    __slots__ = ('rel', 'text', 'lines', 'comment_lines', 'basename', '_code')

    def __init__(self, rel, text):
        self.rel = rel
        self.text = text
        self.lines = text.split('\n')
        self.comment_lines = [_is_comment_line(line) for line in self.lines]
        self.basename = os.path.basename(rel)
        self._code = None

    @property
    def code(self):
        """The file without comments and string literals (= built once)."""
        if self._code is None:
            self._code = strip_comments_and_strings(self.text)
        return self._code

    def code_lines(self):
        """The code lines, comment lines blanked out."""
        return self.code.split('\n')


class SourceTree:
    """Every Swift file in scope, indexed once.

    The index answers the questions the checker asks per symbol: which
    files mention the name, which files read it as a member ('.memberName'),
    and which declarations own a member name.
    """

    def __init__(self, cwd, scope):
        self.cwd = str(cwd)
        self.scope = scope
        self.files = []
        self.by_rel = {}
        self.name_files = {}
        self.code_name_files = {}
        self.code_member_files = {}
        self._structures = {}
        self._owner_map = None
        self._build()

    def _build(self):
        seen = set()
        for root in self.scope.split():
            base = Path(self.cwd) / root
            if not base.exists():
                continue
            for path in sorted(base.rglob('*.swift')):
                rel = str(path.relative_to(self.cwd))
                if rel in seen:
                    continue
                seen.add(rel)
                text = path.read_text(encoding='utf-8', errors='replace')
                sf = SourceFile(rel, text)
                self.files.append(sf)
                self.by_rel[rel] = sf
        for sf in self.files:
            for index, line in enumerate(sf.lines):
                if sf.comment_lines[index]:
                    continue
                for m in TOKEN_RE.finditer(line):
                    name = m.group(0)
                    self.name_files.setdefault(name, set()).add(sf.rel)
        for sf in self.files:
            for line in sf.code_lines():
                if not line.strip():
                    continue
                for m in TOKEN_RE.finditer(line):
                    name = m.group(0)
                    self.code_name_files.setdefault(name, set()).add(sf.rel)
                    prefix = line[:m.start()].rstrip()
                    if prefix.endswith('.'):
                        self.code_member_files.setdefault(name, set()).add(sf.rel)

    def structure(self, rel):
        """The parsed shape of one file (= types, functions, members)."""
        if rel not in self._structures:
            self._structures[rel] = FileStructure(self.by_rel[rel])
        return self._structures[rel]

    def files_with_name(self, name):
        """The files whose code mentions a name."""
        return self.name_files.get(name, set())

    def code_files_with_name(self, name):
        """The files whose CODE mentions a name (no comment, no string)."""
        return self.code_name_files.get(name, set())

    def code_files_reading_member(self, name):
        """The files whose CODE reads '.name'."""
        return self.code_member_files.get(name, set())

    def member_owners(self, member):
        """The declarations that own a member name (= the type that has it).

        A member read proves a reader only when the member name belongs
        to one declaration: '.title' on some other type proves nothing
        about the type that also has a 'title'.
        """
        if self._owner_map is None:
            owners = {}
            for sf in self.files:
                structure = self.structure(sf.rel)
                for t in structure.types:
                    for name in structure.members_of(t['name']):
                        owners.setdefault(name, set()).add((sf.rel, t['name']))
            self._owner_map = owners
        return self._owner_map.get(member, set())


class FileStructure:
    """The types, functions and members of one Swift file."""

    def __init__(self, sf):
        self.sf = sf
        self.code = sf.code
        self.types = []
        self.funcs = []
        self._parse()

    def _parse(self):
        code = self.code
        for m in TYPE_RE.finditer(code):
            body_open = code.find('{', m.end())
            if body_open < 0:
                continue
            body_close = match_brace(code, body_open)
            self.types.append({
                'kind': m.group(1),
                'name': m.group(2),
                'start': m.start(),
                'body_open': body_open,
                'body_close': body_close,
            })
        for m in FUNC_RE.finditer(code):
            paren_open = code.find('(', m.end())
            if paren_open < 0:
                continue
            paren_close = match_paren(code, paren_open)
            if paren_close < 0:
                continue
            arrow = code.find('->', paren_close)
            if arrow < 0:
                continue
            between = code[paren_close:arrow]
            if '{' in between or 'func' in between:
                continue
            body_open = code.find('{', arrow)
            tail = code[arrow + 2:body_open if body_open > 0 else len(code)]
            tail = tail.split('\n')[0]
            self.funcs.append({
                'name': m.group(1),
                'offset': m.start(),
                'returns': type_names_in(tail),
                'owner': self._owner_of(m.start()),
                'is_static': self._is_static(m.start()),
            })

    def _is_static(self, offset):
        """True when the function is a static member of its owner."""
        line_start = self.code.rfind('\n', 0, offset) + 1
        prefix = self.code[line_start:offset]
        return 'static' in prefix.split()

    def _owner_of(self, offset):
        owner = None
        for t in self.types:
            if t['body_open'] <= offset and (t['body_close'] < 0
                                             or offset <= t['body_close']):
                if owner is None or t['body_open'] > owner['body_open']:
                    owner = t
        return owner['name'] if owner else None

    def members_of(self, type_name):
        """The member names declared directly in one type."""
        for t in self.types:
            if t['name'] != type_name:
                continue
            end = t['body_close'] if t['body_close'] > 0 else len(self.code)
            body = self.code[t['body_open'] + 1:end]
            return self._direct_members(body)
        return set()

    @staticmethod
    def _direct_members(body):
        """The declarations a type owns (= at the type's own level).

        A local variable inside a nested function belongs to that
        function, not to the type: counting it here would give two
        declarations the same member name, and the member-read signal
        (= '.member' read in another file) would never fire.
        """
        depths = [0] * (len(body) + 1)
        depth = 0
        for i, ch in enumerate(body):
            depths[i] = depth
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
        members = set()
        for m in MEMBER_RE.finditer(body):
            if depths[m.start()] == 0:
                members.add(m.group(2))
        return members


# --------------------------------------------------------------- scope

_TREES = {}


def get_tree(cwd, scope):
    """The scope index, built once per (cwd, scope)."""
    key = (str(cwd), scope)
    if key not in _TREES:
        _TREES[key] = SourceTree(cwd, scope)
    return _TREES[key]


def _relative(file_path, cwd):
    path = Path(file_path)
    if path.is_absolute():
        try:
            return str(path.relative_to(cwd))
        except ValueError:
            return str(path)
    return str(path)


def has_real_ref(symbol, file_path, scope=SCOPE_DEFAULT, cwd=None):
    """Check if symbol is referenced in real code in scope.

    Returns (external, internal): the matching lines in other files and
    in the file that declares the symbol. Comment lines never count, and
    a same-file declaration line is not a use of its own name.
    """
    tree = get_tree(cwd or os.getcwd(), scope)
    own = _relative(file_path, tree.cwd)
    rx = re.compile(r'\b' + re.escape(symbol) + r'\b')
    external = []
    internal = []
    for rel in tree.files_with_name(symbol):
        sf = tree.by_rel[rel]
        same_file = rel == own
        for index, line in enumerate(sf.lines):
            if sf.comment_lines[index]:
                continue
            if not rx.search(line):
                continue
            if same_file and line.lstrip().startswith(DECL_PREFIXES):
                continue
            entry = f'{rel}:{index + 1}:{line.strip()[:120]}'
            (internal if same_file else external).append(entry)
    return external, internal


# --------------------------------------------------------------- reach

def local_uses(tree, rel, name):
    """The places the file uses the name (= not merely declares it).

    A declaration site ('struct Foo', 'case foo') is the name itself, and
    a return type ('-> Foo') is only a promise: the function may never be
    called, so the declaration stays unreachable until a caller exists.
    Every other mention counts: a constructor call, a static member
    access, a stored property of that type, a parameter of that type.
    """
    sf = tree.by_rel.get(rel)
    if sf is None:
        return []
    rx = re.compile(r'\b' + re.escape(name) + r'\b')
    uses = []
    for index, line in enumerate(sf.code_lines()):
        for m in rx.finditer(line):
            prefix = line[:m.start()].rstrip()
            if is_return_position(prefix):
                continue
            if last_word(prefix) in DECL_KEYWORDS:
                continue
            uses.append(f'{rel}:{index + 1}:{line.strip()[:120]}')
    return uses


def reach_reasons(tree, rel, name):
    """Why a declaration is alive (= the readers that reach it).

    Returns the list of reasons; an empty list means nothing reaches the
    declaration, so it is a deletion candidate.
    """
    reasons = []
    sf = tree.by_rel.get(rel)
    if sf is None:
        return reasons

    # The external-name signal is the same one ext_count reports: the
    # name appears on a non-comment line of another file (= that file
    # depends on the declaration, in code or in a test that reads the
    # source text). Using a narrower signal here would contradict the
    # count the tool prints next to the verdict.
    others = tree.files_with_name(name) - {rel}
    if others:
        reasons.append(f'named in {len(others)} other file(s)')

    uses = local_uses(tree, rel, name)
    if uses:
        reasons.append(f'used in its own file ({len(uses)} site(s))')

    for member in sorted(tree.structure(rel).members_of(name)):
        if member in GENERIC_NAMES or len(member) < 3:
            continue
        owners = tree.member_owners(member)
        if owners and owners != {(rel, name)}:
            continue  # another declaration owns this member name too
        readers = tree.code_files_reading_member(member) - {rel}
        if readers:
            reasons.append(f'member .{member} read in another file')
            break

    for producer in producers_of(tree, rel, name):
        if called_elsewhere(tree, producer, rel):
            owner = producer['owner']
            label = f'{owner}.{producer["name"]}()' if owner \
                else producer['name'] + '()'
            reasons.append(f'returned by {label} and called elsewhere')
            break

    return reasons


def producers_of(tree, rel, name):
    """The functions whose return type names this declaration.

    Only the declaring file can hold one: a return type in another file
    would already name the declaration there (= that file names it).
    """
    out = []
    for func in tree.structure(rel).funcs:
        if name in func['returns']:
            out.append({'file': rel, 'name': func['name'],
                        'owner': func['owner']})
    return out


def called_elsewhere(tree, producer, own_rel):
    """True when another file calls the producer function.

    A static member is called through its owner ('Owner.count()'); an
    instance method through any receiver ('.count()'); a top-level
    function by its bare name.
    """
    name = producer['name']
    owner = producer['owner']
    if owner and producer.get('is_static'):
        candidates = tree.code_files_with_name(owner)
        pattern = r'\b' + re.escape(owner) + r'\s*\.\s*' + re.escape(name)
    elif owner:
        candidates = tree.code_files_with_name(name)
        pattern = r'\.\s*' + re.escape(name) + r'\s*\('
    else:
        candidates = tree.code_files_with_name(name)
        pattern = r'(?<![\w.])' + re.escape(name) + r'\s*\('
    rx = re.compile(pattern)
    for rel in candidates:
        if rel == own_rel:
            continue
        sf = tree.by_rel[rel]
        for index, line in enumerate(sf.lines):
            if sf.comment_lines[index]:
                continue
            if rx.search(line):
                return True
    return False


# --------------------------------------------------------------- verdict

def verify_file(file_path, scope=SCOPE_DEFAULT, cwd=None, reach=False):
    """Run full verification on a file. Returns dict with verdict + details.

    reach=True adds the reachability reasons to every type finding
    (= what the --ui-components mode reports).
    """
    tree = get_tree(cwd or os.getcwd(), scope)
    rel = _relative(file_path, tree.cwd)
    if rel not in tree.by_rel:
        path = Path(file_path)
        if not path.is_absolute():
            path = Path(tree.cwd) / path
        if not path.exists():
            return {'verdict': 'MISSING', 'details': 'file does not exist'}
    decls = get_decls(file_path, base=tree.cwd)
    if not decls:
        return {'verdict': 'EMPTY', 'details': 'no top-level decls found',
                'decls': []}
    findings: list[dict] = []
    for kind, name, access in decls:
        external, internal = has_real_ref(name, rel, scope, tree.cwd)
        total_refs = len(external) + len(internal)
        finding = {
            'kind': kind, 'name': name, 'access': access,
            'ext_count': len(external), 'int_count': len(internal),
            'total_count': total_refs,
            'external': external[:2], 'internal': internal[:2],
        }
        if reach and kind in ('struct', 'enum', 'class', 'protocol'):
            finding['reasons'] = reach_reasons(tree, rel, name)
        findings.append(finding)
    alive = [f for f in findings if f['total_count'] > 0]
    dead = [f for f in findings if f['total_count'] == 0]
    if not dead:
        return {'verdict': 'ALIVE',
                'details': f'all {len(findings)} decls have real refs',
                'findings': findings}
    elif not alive:
        return {'verdict': 'DEAD',
                'details': f'all {len(findings)} decls dead (0 ref)',
                'findings': findings}
    else:
        return {'verdict': 'PARTIAL',
                'details': f'{len(dead)}/{len(findings)} decls dead',
                'findings': findings}


# --------------------------------------------------------------- auto-scan

def auto_scan(cwd):
    """The Swift files under the view directories (= the real tree).

    Returns (files, directories): the files to check and the
    directories they came from. A glob that matches nothing is skipped,
    so a moved directory never breaks the scan.
    """
    files = []
    directories = []
    for pattern in VIEW_GLOBS:
        for directory in sorted(Path(cwd).glob(pattern)):
            if not directory.is_dir():
                continue
            directories.append(str(directory.relative_to(cwd)))
            for path in sorted(directory.rglob('*.swift')):
                files.append(str(path.relative_to(cwd)))
    return files, directories


# --------------------------------------------------------------- main

def main(argv=None):
    parser = argparse.ArgumentParser(
        description='verify-dead.py — strict Swift dead-code verification '
                    '(= UI-component-aware in --ui-components mode)')
    parser.add_argument('files', nargs='*',
                        help='Swift files to verify (empty = auto-scan the '
                             'view directories)')
    parser.add_argument('--scope', default=SCOPE_DEFAULT,
                        help='Grep scope (default: Sources/ Tests/)')
    parser.add_argument('--cwd', default=None,
                        help='Git root for scope resolution '
                             '(default: auto-detect)')
    parser.add_argument('--ui-components', action='store_true',
                        help='UI-component-aware mode: scan the view '
                             'directories and report the components no '
                             'file can reach (= UI_DELETE_CANDIDATE).')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Print per-finding details (= by default, only '
                             'summary)')
    args = parser.parse_args(argv)

    try:
        root = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                              capture_output=True, text=True,
                              check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        root = os.getcwd()
    cwd = args.cwd or root

    scanned_dirs = []
    files_to_check = list(args.files)
    if not files_to_check:
        files_to_check, scanned_dirs = auto_scan(cwd)
        if not files_to_check:
            print("No Swift file found under the view directories "
                  f"({', '.join(VIEW_GLOBS)}).", file=sys.stderr)
            print("The scan covered nothing, so it proves nothing.", 
                  file=sys.stderr)
            return 2

    total_alive = 0
    total_dead = 0
    total_partial = 0
    ui_delete_candidates = []

    for f in files_to_check:
        result = verify_file(f, scope=args.scope, cwd=cwd,
                             reach=args.ui_components)
        verdict = result['verdict']

        if args.ui_components:
            for fnd in result.get('findings', []):
                if fnd['access'] in ('private', 'fileprivate'):
                    continue
                if fnd['kind'] not in ('struct', 'enum', 'class', 'protocol'):
                    continue
                if not fnd.get('reasons'):
                    ui_delete_candidates.append((f, fnd['name'], fnd['kind']))

        if verdict == 'ALIVE':
            total_alive += 1
        elif verdict == 'DEAD':
            total_dead += 1
        else:
            total_partial += 1

        if args.verbose:
            print(f"=== {f} ===")
            print(f"  verdict: {verdict}")
            print(f"  details: {result['details']}")
            for fnd in result.get('findings', []):
                counts = f"(ext={fnd['ext_count']}, int={fnd['int_count']})"
                if 'reasons' in fnd:
                    reasons = fnd['reasons']
                    if reasons:
                        mark = '✓'
                        detail = '; '.join(reasons)
                    else:
                        mark = '✗'
                        detail = 'no reader in any file'
                    print(f"    {mark} {fnd['kind']:8s} {fnd['name']:30s} "
                          f"{counts} {detail}")
                else:
                    mark = '✓' if fnd['total_count'] > 0 else '✗'
                    print(f"    {mark} {fnd['kind']:8s} {fnd['name']:30s} "
                          f"{fnd['total_count']:3d} refs {counts}")
            print()

    print("=" * 60)
    print(f"Summary: {len(files_to_check)} files")
    if scanned_dirs:
        print(f"  Scanned directories ({len(scanned_dirs)}):")
        for directory in scanned_dirs:
            print(f"    {directory}")
    print(f"  ALIVE   (= all decls have real refs):  {total_alive}")
    print(f"  PARTIAL (= some decls dead):            {total_partial}")
    print(f"  DEAD    (= all decls dead):             {total_dead}")

    if args.ui_components:
        print()
        print("UI components with no reader in any file (= deletion "
              "candidates):")
        if ui_delete_candidates:
            for f, name, kind in ui_delete_candidates:
                print(f"  {f}: {kind} {name}")
            print()
            print(f"  TOTAL: {len(ui_delete_candidates)} deletion candidates")
            print("  (= every candidate needs a hand check before it is "
                  "deleted: = a type with no member read anywhere)")
            return 1
        print("  (= none found = every component in scope is reachable)")

    return 1 if total_dead else 0


if __name__ == '__main__':
    sys.exit(main())
