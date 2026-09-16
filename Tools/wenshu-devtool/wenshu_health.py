#!/usr/bin/env python3
"""
wenshu_health.py - Comprehensive health check, not just dead code.

Categories:
  1. Dead code (via verify-dead.py) — symbol-level verification
  2. Risk hotspots (via repowise risk --target) — bug-prone files, 1-owner
  3. Health worst files (via repowise health --refactoring-targets)
  4. Mechanical refactoring opportunities (high-confidence extract_method)
  5. Code duplication (top duplicated line blocks)
  6. Test gap (files with high_nloc but no paired test)
  7. Maintenance debt (TODO/FIXME/HACK counts in non-.scratch files)

Usage:
  python3 Tools/wenshu-devtool/wenshu_health.py --report /path/to/health.json
  python3 Tools/wenshu-devtool/wenshu_health.py --section dead-code
"""
import argparse
import os
import subprocess
import sys
from collections import Counter
from pathlib import Path

WENSHU_ROOT = Path("/Volumes/ANAN/Engineering/wenshu")
SOURCES = WENSHU_ROOT / "Sources" / "WenshuApp"
TESTS = WENSHU_ROOT / "Tests" / "WenshuAppTests"

def run_cmd(cmd, cwd=WENSHU_ROOT):
    """Run shell command and return stdout"""
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(cwd))
    return r.stdout

def dead_code_section(verbose=False):
    """Run verify-dead.py on all Swift files in Sources/.
    Identify files where ALL top-level decls are dead (= file itself dead).
    """
    import importlib.util
    spec_path = WENSHU_ROOT / "Tools" / "wenshu-devtool" / "verify-dead.py"
    spec = importlib.util.spec_from_file_location("vd", str(spec_path))
    vd = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(vd)

    dead_files = []
    partially_dead = []
    for f in sorted(SOURCES.rglob("*.swift")):
        rel = f.relative_to(WENSHU_ROOT)
        if str(rel).endswith("/IconStyles.swift"):  # already deleted
            continue
        result = vd.verify_file(str(rel), cwd=str(WENSHU_ROOT))
        if result['verdict'] == 'DEAD':
            dead_files.append({
                'file': str(rel),
                'details': result['details'],
                'findings': result['findings'],
            })
        elif result['verdict'] == 'PARTIAL':
            dead = [f for f in result['findings'] if f['total_count'] == 0]
            if dead and len(dead) < len(result['findings']):
                partially_dead.append({
                    'file': str(rel),
                    'dead_count': len(dead),
                    'alive_count': len(result['findings']) - len(dead),
                    'dead': [f['name'] for f in dead],
                })
    return {
        'summary': f'{len(dead_files)} fully-dead + {len(partially_dead)} partial files',
        'dead_files': dead_files,
        'partially_dead': partially_dead,
    }

def risk_hotspots_section(limit=10):
    """Find files with bug-prone history + 1-owner concentration.
    Heuristic: parse `git log --format=...` for files with multiple fix commits.
    """
    # Use repowise risk --target per file (= expensive; limit to top suspects)
    # For now: use repowise health --refactoring-targets output to find hotspots
    output = run_cmd([
        'env', '-u', 'all_proxy', '-u', 'http_proxy', '-u', 'https_proxy',
        '-u', 'SOCKS_PROXY', '-u', 'SOCKS5_PROXY', '-u', 'HTTP_PROXY',
        '-u', 'HTTPS_PROXY', '-u', 'ALL_PROXY',
        'repowise', 'health', '--refactoring-targets', '--scope', 'production',
        '--format', 'json'
    ])
    import json
    # Skip repowise's own log lines (= those that start with timestamp)
    json_start = output.find('{')
    if json_start == -1:
        return {'error': 'no JSON in repowise output', 'raw': output[:500]}
    try:
        data = json.loads(output[json_start:])
        targets = data.get('targets', [])
        return {'top_targets': targets[:limit], 'total': len(targets)}
    except (json.JSONDecodeError, KeyError) as e:
        return {'error': str(e), 'raw': output[:500]}

def test_gap_section(limit=20):
    """Find production files with high NLOC but no paired test file."""
    gaps = []
    for f in sorted(SOURCES.rglob("*.swift")):
        basename = f.stem
        # Common pairing: Foo.swift -> FooTests.swift in Tests/
        test_candidates = [
            TESTS / "Views" / f"{basename}Tests.swift",
            TESTS / "Agent" / f"{basename}Tests.swift",
            TESTS / "Core" / "Agent" / "Connector" / f"{basename}Tests.swift",
            TESTS / "Core" / "Agent" / "Tool" / f"{basename}Tests.swift",
            TESTS / "Core" / "Agent" / "Conversation" / f"{basename}Tests.swift",
            TESTS / "Core" / "Memory" / f"{basename}Tests.swift",
            TESTS / "Core" / "Provider" / f"{basename}Tests.swift",
            TESTS / "Core" / "Foundation" / f"{basename}Tests.swift",
            TESTS / "Core" / "Registry" / f"{basename}Tests.swift",
            TESTS / "Persistence" / f"{basename}Tests.swift",
            TESTS / "Storage" / f"{basename}Tests.swift",
            TESTS / "UI" / f"{basename}Tests.swift",
            TESTS / "UI" / "Memory" / f"{basename}Tests.swift",
            TESTS / "Domain" / f"{basename}Tests.swift",
            TESTS / f"{basename}Tests.swift",
        ]
        if not any(t.exists() for t in test_candidates):
            nloc = sum(1 for _ in f.open())
            if nloc > 200:  # only flag large files
                gaps.append({'file': str(f.relative_to(WENSHU_ROOT)), 'nloc': nloc})
    return {
        'total_gaps': len(gaps),
        'top_by_nloc': sorted(gaps, key=lambda x: -x['nloc'])[:limit],
    }

def maintenance_debt_section():
    """Count TODO/FIXME/HACK/XXX in production code (exclude .scratch/).

    Heuristic: only count tokens that are FOLLOWED BY a space + a non-letter
    (= avoids matching identifier names like TODO_SCHEMA, FIXME_LIST, etc.)
    AND not inside a string literal / regex / comment triple (= "([^"]*" / #"..."#).
    We approximate by requiring the marker to be preceded by "//" + optional
    space (i.e. it's a line comment, not code).
    """
    patterns = ['TODO', 'FIXME', 'HACK', 'XXX', 'TECH DEBT']
    debt = {p: 0 for p in patterns}
    files_with_debt = []
    for f in SOURCES.rglob("*.swift"):
        if '.scratch' in str(f):
            continue
        # Per-line match: only when marker is in a single-line // comment
        # (= not inside a string literal, regex, or /// doc comment).
        text = f.read_text()
        for line_no, line in enumerate(text.splitlines(), 1):
            # Strip string literals (rough — handles "..." and #"..."#)
            stripped = line
            # Remove quoted string content (best-effort, doesn't handle escapes)
            import re
            stripped = re.sub(r'#?\"(?:[^\"\\]|\\.)*\"', '', stripped)
            # Now check if the (stripped) line has a // comment that contains
            # the marker at a word boundary.
            comment_match = re.search(r'//.*$', stripped)
            if not comment_match:
                continue
            comment_text = comment_match.group(0)
            for p in patterns:
                if re.search(rf'\b{p}\b', comment_text):
                    debt[p] += 1
                    files_with_debt.append((str(f.relative_to(WENSHU_ROOT)), p, line_no))
    return {
        'counts': debt,
        'top_files': sorted(files_with_debt, key=lambda x: x[1])[:20],
    }

def single_owner_files_section(min_commits=3):
    """Find production files owned by 1 person (bus factor risk)."""
    risky = []
    for f in sorted(SOURCES.rglob("*.swift")):
        rel = str(f.relative_to(WENSHU_ROOT))
        # git log --format to count authors
        out = run_cmd(['git', 'log', '--format=%ae', '--', rel])
        authors = set(line.strip() for line in out.split('\n') if line.strip())
        if len(authors) == 1 and len(out.split('\n')) >= min_commits:
            risky.append({
                'file': rel,
                'commit_count': len(out.split('\n')) - 1,  # last empty
                'owner': list(authors)[0].split('@')[0],
            })
    return sorted(risky, key=lambda x: -x['commit_count'])[:20]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--section', choices=['all', 'dead-code', 'risk', 'test-gap', 'debt', 'owner'])
    args = ap.parse_args()

    sections = {
        'dead-code': dead_code_section,
        'risk': risk_hotspots_section,
        'test-gap': test_gap_section,
        'debt': maintenance_debt_section,
        'owner': single_owner_files_section,
    }
    if args.section in ('all', None):
        for name, fn in sections.items():
            print(f"=== {name} ===")
            import json
            print(json.dumps(fn(), indent=2, default=str))
            print()
    else:
        import json
        print(json.dumps(sections[args.section](), indent=2, default=str))

if __name__ == '__main__':
    main()
