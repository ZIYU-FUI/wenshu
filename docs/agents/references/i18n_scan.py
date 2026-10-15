#!/usr/bin/env python3
# docs/agents/references/i18n_scan.py
#
# i18n missing-key scan for wenshu (= the silent machine-key-leak bug
# fix verification). Detects Swift call sites that reference a
# Localizable.xcstrings key that does not exist in the catalog.
#
# Usage:
#   python3 docs/agents/references/i18n_scan.py /Volumes/ANAN/Engineering/wenshu
#
# Exits 1 (= gate) if any missing keys are found (= a future pre-commit
# hook could call this to prevent regressions). The script matches the
# logic of `~/.hermes/profiles/pocock/skills/wenshu-app-build-pipeline/
# references/i18n-missing-key-scan.sh` but reads the .xcstrings
# catalog (= the wenshu project uses one source-of-truth file for all
# locales; = not per-locale .lproj/Localizable.strings files).
#
# Key detection regex:
#   String\(localized:\s+"([^"]+)"      -- the canonical Swift i18n
#   String(localized: "key", defaultValue: "fallback")
#
# Template-key filter:
#   The scan filters out keys that look like templates (= literal
#   `<action>` or literal `\(rawValue)` etc = Swift code that
#   cannot be matched against a real catalog entry). These are
#   the few remaining unfixed 'missing' keys (= 2 in 2026-10-15).

import os
import re
import sys


def collect_swift_keys(root: str) -> set[str]:
    """Walk Sources/WenshuApp/ for String(localized: \"...\") keys."""
    keys = set()
    for dirpath, _, files in os.walk(os.path.join(root, "Sources", "WenshuApp")):
        for f in files:
            if not f.endswith(".swift"):
                continue
            full = os.path.join(dirpath, f)
            try:
                text = open(full).read()
            except (OSError, UnicodeDecodeError):
                continue
            for m in re.finditer(r'String\(localized:\s+"([^"]+)"', text):
                keys.add(m.group(1))
    return keys


def collect_xcstrings_keys(root: str) -> set[str]:
    """Read Sources/WenshuApp/Resources/Localizable.xcstrings and
    extract the top-level key names. The .xcstrings file is JSON
    with a "strings": { "key": { ... } } shape."""
    path = os.path.join(
        root, "Sources", "WenshuApp", "Resources", "Localizable.xcstrings"
    )
    if not os.path.isfile(path):
        return set()
    text = open(path).read()
    # Top-level string keys: "strings": { "<key>": { ... }, ... }
    # Match the key before ": {" (= the key after "strings": { or
    # after the previous key's closing brace + comma).
    # Use a regex that matches only the string-name fields (= a-zA-Z0-9._-).
    return set(re.findall(r'"([a-zA-Z0-9._-]+)"\s*:\s*\{', text))


def filter_template_keys(keys: set[str]) -> set[str]:
    """Filter out keys that look like Swift code templates (= literal
    angle brackets in the key, or literal Swift string interpolation
    syntax in the key). These are not real i18n keys."""
    return {
        k for k in keys
        if "<" not in k and "\\(" not in k
    }


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    swift_keys = filter_template_keys(collect_swift_keys(root))
    catalog_keys = collect_xcstrings_keys(root)
    missing = swift_keys - catalog_keys
    if missing:
        print(f"i18n_scan: FAIL ({len(missing)} missing keys)")
        print()
        for k in sorted(missing):
            print(f"  {k}")
        return 1
    print(
        f"i18n_scan: PASS "
        f"({len(swift_keys)} Swift keys all present in catalog)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
