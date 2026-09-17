"""verify_dead.py — 严格的 Swift dead-code verification 工具

规则:
- 1 file 1 check
- 找 file 里所有 top-level decl (struct/class/enum/extension/let/var/func)
- 对每个 decl 名字, grep 其他 file 的真代码 ref
- 真代码 ref 标准: 不在 comment 行, 不在 own file, 不在 docstring
- 输出 PASS (= alive) 或 FAIL (= dead) + 详情
"""
import subprocess, sys, os, re

def get_decls(file_path):
    """Extract top-level declarations from Swift file.

    Returns list of (kind, name, access_level) tuples. access_level is
    'public' / 'internal' / 'private' (= defaults to internal if none
    specified; = Swift's default access control level).

    The --ui-components mode in __main__ uses access_level to filter
    candidates: private members (= property storage + private helpers)
    are NOT considered 'UI components'; only public/internal types are
    candidate reusable components.
    """
    with open(file_path) as f:
        content = f.read()
    decls = []
    for m in re.finditer(
        r'^(?P<lead>\s*(?:public\s+|private\s+|fileprivate\s+|internal\s+|open\s+|static\s+|final\s+|class\s+|indirect\s+)*)'
        r'(?P<kind>let|var|struct|class|enum|actor|func|extension|protocol|typealias)\s+'
        r'(?P<name>\w+)',
        content, re.MULTILINE
    ):
        kind = m.group('kind')
        name = m.group('name')
        lead = m.group('lead') or ''
        # Determine access level (= leftmost modifier in the lead).
        access = 'internal'  # Swift default
        for mod in ('public', 'open', 'fileprivate', 'private', 'internal'):
            if mod in lead.split():
                access = mod
                break
        # Skip Swift keyword-like names + ultra-common property names
        # (= too generic to be useful for dead-code detection)
        if name in {'View', 'self', 'guard', 'init', 'body', 'return', 'where',
                    'some', 'if', 'else', 'for', 'while', 'do', 'catch', 'in',
                    'as', 'is', 'try', 'await', 'throws', 'throws}',
                    # Common generic property names (= not unique signatures):
                    'value', 'body', 'id', 'name', 'title', 'count', 'index',
                    'data', 'state', 'self', 'tag', 'type', 'kind', 'result',
                    'message', 'error', 'success', 'failure', 'context',
                    'content', 'description', 'enabled', 'visible',
                    # Auto-synthesized protocol witnesses:
                    'hashValue', 'description', 'debugDescription'}:
            continue
        if len(name) < 3:  # too short, false positive risk
            continue
        decls.append((kind, name, access))
    return decls

def has_real_ref(symbol, file_path, scope='Sources/ Tests/', cwd=None):
    """Check if symbol is referenced in real code in scope (excluding own file, comments, docstrings)
    Returns: (external_count, external_refs, internal_count, internal_refs)
    Internal refs (inside the same file) also count as alive for private/internal symbols.
    """
    base = os.path.basename(file_path)
    # Patterns to detect real code references:
    # - .symbol(...) member access
    # - symbol(...) function call
    # - symbol = ... assignment
    # - symbol : ... type annotation
    # - symbol, ... tuple / function arg (e.g. foo(x, symbol, y))
    # - \bsymbol\b alone (= as positional/argument/etc.)
    # Require word boundary before symbol to avoid substring matches.
    patterns = [
        rf'\.{symbol}\b',          # .symbol (member access)
        rf'\b{symbol}\s*\(',       # symbol( (function call)
        rf'\b{symbol}\s*=',         # symbol = (assignment, not ==)
        rf'\b{symbol}\s*:',         # symbol : (type annotation)
        rf'\b{symbol}\b',           # symbol alone (positional / generic ref)
    ]
    # Combined into a single extended regex (BSD grep does not OR multiple
    # positional patterns; = need alternation in one pattern).
    combined = '|'.join(f'({p})' for p in patterns)
    cmd = ['grep', '-rnE', '--include=*.swift', combined]
    if scope:
        cmd += scope.split()
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd).stdout
    external = []
    internal = []
    for line in out.split('\n'):
        if not line: continue
        # Strip leading ./ for grep -rn output
        clean = line.lstrip('./')
        # Find content after 2nd colon (grep -n format: file:line:content)
        parts = clean.split(':', 2)
        if len(parts) < 3: continue
        content = parts[2]
        stripped = content.lstrip()
        if stripped.startswith('//') or stripped.startswith('/*') or stripped.startswith('*'):
            continue
        # Determine if external (different file) or internal (same file)
        is_same_file = f'{base}:' in clean
        # Exclude the declaration line itself (= the type/var/let declaration)
        # We want USES, not definitions
        if is_same_file and stripped.startswith(('public ', 'private ', 'fileprivate ', 'internal ', 'static ', 'final ')):
            decl_starters = ('public ', 'private ', 'fileprivate ', 'internal ',
                              'static ', 'final ', 'let ', 'var ', 'struct ',
                              'class ', 'enum ', 'actor ', 'func ', 'extension ',
                              'protocol ', 'typealias ')
            if any(stripped.startswith(s) for s in decl_starters):
                continue
        if is_same_file:
            internal.append(line)
        else:
            external.append(line)
    return external, internal

def verify_file(file_path, scope='Sources/ Tests/', cwd=None):
    """Run full verification on a file. Returns dict with verdict + details."""
    if not os.path.exists(file_path):
        return {'verdict': 'MISSING', 'details': 'file does not exist'}
    decls = get_decls(file_path)
    if not decls:
        return {'verdict': 'EMPTY', 'details': 'no top-level decls found', 'decls': []}
    findings = []
    for kind, name, access in decls:
        external, internal = has_real_ref(name, file_path, scope, cwd)
        # External refs OR internal refs (private symbols used in same file) = alive
        total_refs = len(external) + len(internal)
        findings.append({
            'kind': kind, 'name': name, 'access': access,
            'ext_count': len(external), 'int_count': len(internal),
            'total_count': total_refs,
            'external': external[:2], 'internal': internal[:2]
        })
    alive = [f for f in findings if f['total_count'] > 0]
    dead = [f for f in findings if f['total_count'] == 0]
    if not dead:
        return {'verdict': 'ALIVE', 'details': f'all {len(findings)} decls have real refs', 'findings': findings}
    elif not alive:
        return {'verdict': 'DEAD', 'details': f'all {len(findings)} decls dead (0 ref)', 'findings': findings}
    else:
        return {'verdict': 'PARTIAL', 'details': f'{len(dead)}/{len(findings)} decls dead', 'findings': findings}

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(
        description='verify-dead.py — strict Swift dead-code verification (= UI-component-aware in --ui-components mode)'
    )
    parser.add_argument('files', nargs='*', help='Swift files to verify (empty = auto-scan UI/ + Views/)')
    parser.add_argument('--scope', default='Sources/ Tests/',
                        help='Grep scope (default: Sources/ Tests/)')
    parser.add_argument('--cwd', default=None,
                        help='Git root for grep scope resolution (default: auto-detect)')
    parser.add_argument('--ui-components', action='store_true',
                        help='UI-component-aware mode: scan all UI files, ignore intra-file '
                             'refs (= a component is alive only if a DIFFERENT file uses it), '
                             'report 0-call-site UI components as UI_DELETE_CANDIDATE.')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Print per-finding details (= by default, only summary)')
    args = parser.parse_args()

    # Default to git root so 'Sources/' / 'Tests/' resolve
    try:
        root = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                               capture_output=True, text=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        root = os.getcwd()
    cwd = args.cwd or root

    # Auto-scan if no files given (= scan UI/ + Views/)
    files_to_check = list(args.files)
    if not files_to_check:
        ui_scan = subprocess.run(
            ['find', 'Sources/WenshuApp/UI', 'Sources/WenshuApp/Views',
             '-name', '*.swift', '-type', 'f'],
            capture_output=True, text=True, cwd=cwd
        ).stdout.strip().split('\n')
        files_to_check = [f for f in ui_scan if f]

    # Run verification per file
    total_alive = 0
    total_dead = 0
    total_partial = 0
    ui_delete_candidates = []  # list of (file, decl_name, decl_kind)

    for f in files_to_check:
        # In --ui-components mode, internal-only refs DON'T count (= the
        # canonical 0-call-site UI component is one that exists but
        # nothing outside its own file uses it).
        result = verify_file(f, scope=args.scope, cwd=cwd)
        verdict = result['verdict']

        if args.ui_components:
            # Re-classify each finding: alive only if EXTERNAL refs exist
            # (= a different file uses this component).
            #
            # Also filter aggressively: only flag candidates that look
            # like actual reusable components. Filtering rules:
            # - access must be public / open / internal (= NOT private
            #   or fileprivate = file-internal helpers)
            # - kind must be struct / enum / class / protocol (= NOT
            #   let / var = property storage; = NOT func = helper; =
            #   these are never 'reusable components' regardless of
            #   caller count)
            # - ext_count must be 0 (= no caller anywhere)
            #
            # Result: only flags TRULY reusable type declarations that
            # have 0 callers (= the v0.30 stub-layer error pattern).
            findings = result.get('findings', [])
            for fnd in findings:
                if fnd['access'] in ('private', 'fileprivate'):
                    continue  # file-internal — not a component
                if fnd['kind'] not in ('struct', 'enum', 'class', 'protocol'):
                    continue  # let/var/func = property storage / helper
                if fnd['ext_count'] == 0:
                    ui_delete_candidates.append((f, fnd['name'], fnd['kind']))

        if verdict == 'ALIVE':
            total_alive += 1
        elif verdict == 'DEAD':
            total_dead += 1
        else:
            total_partial += 1

        if args.verbose or args.ui_components:
            print(f"=== {f} ===")
            print(f"  verdict: {verdict}")
            print(f"  details: {result['details']}")
            for fnd in result.get('findings', []):
                if args.ui_components:
                    # In UI mode, only show ext_count (= the alive-or-not signal)
                    mark = '✓' if fnd['ext_count'] > 0 else '✗'
                    print(f"    {mark} {fnd['kind']:8s} {fnd['name']:30s} ext={fnd['ext_count']:3d} (int={fnd['int_count']:3d})")
                else:
                    mark = '✓' if fnd['total_count'] > 0 else '✗'
                    counts = f"(ext={fnd['ext_count']}, int={fnd['int_count']})"
                    print(f"    {mark} {fnd['kind']:8s} {fnd['name']:30s} {fnd['total_count']:3d} refs {counts}")
            print()

    # Summary
    print("=" * 60)
    print(f"Summary: {len(files_to_check)} files")
    print(f"  ALIVE   (= all decls have real refs):  {total_alive}")
    print(f"  PARTIAL (= some decls dead):            {total_partial}")
    print(f"  DEAD    (= all decls dead):             {total_dead}")

    if args.ui_components:
        print()
        print(f"UI components with 0 EXTERNAL callers (= deletion candidates):")
        if ui_delete_candidates:
            for f, name, kind in ui_delete_candidates:
                print(f"  {f}: {kind} {name}")
            print()
            print(f"  TOTAL: {len(ui_delete_candidates)} deletion candidates")
            print(f"  (= per ADR-0009 'Convention 2: Shared wrapper Views need ≥2 call sites'")
            print(f"   = delete these single-file wrappers; = inline if needed)")
        else:
            print("  (= none found = the NSA framework component catalog is clean)")

