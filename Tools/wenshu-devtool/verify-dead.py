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
    """Extract top-level declarations from Swift file"""
    with open(file_path) as f:
        content = f.read()
    decls = []
    for m in re.finditer(
        r'^\s*(?:public\s+|private\s+|fileprivate\s+|internal\s+|open\s+)*'
        r'(?:static\s+|final\s+|class\s+|indirect\s+)*'
        r'(let|var|struct|class|enum|actor|func|extension|protocol|typealias)\s+(\w+)',
        content, re.MULTILINE
    ):
        kind = m.group(1)
        name = m.group(2)
        if name in {'View', 'self', 'guard', 'init', 'body', 'return', 'where', 'some', 'if', 'else', 'for', 'while', 'do', 'catch', 'in', 'as', 'is', 'try', 'await', 'throws'}:
            continue
        if len(name) < 3:  # too short, false positive risk
            continue
        decls.append((kind, name))
    return decls

def has_real_ref(symbol, file_path, scope='Sources/ Tests/', cwd=None):
    """Check if symbol is referenced in real code in scope (excluding own file, comments, docstrings)"""
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
    real = []
    for line in out.split('\n'):
        if not line: continue
        # Strip leading ./ for grep -rn output
        clean = line.lstrip('./')
        if f'{base}:' in clean: continue  # own file
        # Find content after 2nd colon (grep -n format: file:line:content)
        parts = clean.split(':', 2)
        if len(parts) < 3: continue
        content = parts[2]
        stripped = content.lstrip()
        if stripped.startswith('//') or stripped.startswith('/*') or stripped.startswith('*'):
            continue
        real.append(line)
    return real

def verify_file(file_path, scope='Sources/ Tests/', cwd=None):
    """Run full verification on a file. Returns dict with verdict + details."""
    if not os.path.exists(file_path):
        return {'verdict': 'MISSING', 'details': 'file does not exist'}
    decls = get_decls(file_path)
    if not decls:
        return {'verdict': 'EMPTY', 'details': 'no top-level decls found', 'decls': []}
    findings = []
    for kind, name in decls:
        refs = has_real_ref(name, file_path, scope, cwd)
        findings.append({'kind': kind, 'name': name, 'ref_count': len(refs), 'refs': refs[:3]})
    alive = [f for f in findings if f['ref_count'] > 0]
    dead = [f for f in findings if f['ref_count'] == 0]
    if not dead:
        return {'verdict': 'ALIVE', 'details': f'all {len(findings)} decls have real refs', 'findings': findings}
    elif not alive:
        return {'verdict': 'DEAD', 'details': f'all {len(findings)} decls dead (0 ref)', 'findings': findings}
    else:
        return {'verdict': 'PARTIAL', 'details': f'{len(dead)}/{len(findings)} decls dead', 'findings': findings}

if __name__ == '__main__':
    # Default to git root so 'Sources/' / 'Tests/' resolve
    try:
        root = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                               capture_output=True, text=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        root = os.getcwd()
    for f in sys.argv[1:]:
        result = verify_file(f, cwd=root)
        print(f"=== {f} ===")
        print(f"  verdict: {result['verdict']}")
        print(f"  details: {result['details']}")
        for fnd in result.get('findings', []):
            mark = '✓' if fnd['ref_count'] > 0 else '✗'
            print(f"    {mark} {fnd['kind']:8s} {fnd['name']:30s} {fnd['ref_count']:2d} refs")
        print()
