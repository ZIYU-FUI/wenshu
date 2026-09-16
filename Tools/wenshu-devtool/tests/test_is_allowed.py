#!/usr/bin/env python3
"""
test_is_allowed.py - Unit tests for Tools/wenshu-devtool/commit_filter.py is_allowed().

5 match types in is_allowed():
  1. Exact match: path == entry
  2. Suffix match: path ends with '/' + entry
  3. Directory prefix match: entry has '/' + path starts with entry (with optional trailing /)
  4. Basename prefix match: entry is 'Module.method' (= Swift symbol), match if file basename starts with prefix
  5. Glob-style prefix match: entry is prefix ending in '-' or '_', path starts with entry

These tests pin the behavior so refactoring is_safe.
"""
import sys
import os
import unittest

# Add Tools/wenshu-devtool to path so we can import commit_filter
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
COMMIT_FILTER_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, COMMIT_FILTER_DIR)

import commit_filter


class TestExactMatch(unittest.TestCase):
    def test_simple_filename(self):
        self.assertTrue(commit_filter.is_allowed("AGENTS.md"))

    def test_nested_filename(self):
        self.assertTrue(commit_filter.is_allowed(
            "Sources/WenshuApp/AGENTS.md"
        ))

    def test_path_not_in_list(self):
        self.assertFalse(commit_filter.is_allowed("foo.md"))


class TestSuffixMatch(unittest.TestCase):
    """entry 'X' matches path '.../X' (last segment)"""

    def test_suffix_match_directory(self):
        # The single entry 'AGENTS.md' at the root will suffix-match
        # any path that ends with '/AGENTS.md'.
        self.assertTrue(commit_filter.is_allowed("anywhere/AGENTS.md"))

    def test_suffix_match_nested(self):
        self.assertTrue(commit_filter.is_allowed(
            "a/b/c/AGENTS.md"
        ))


class TestDirectoryPrefixMatch(unittest.TestCase):
    """entry ending with '/' or containing '/' matches any path in that directory"""

    def test_trailing_slash_entry(self):
        # '.scratch/2026-08-22-pollution-mitigation/' is an entry
        self.assertTrue(commit_filter.is_allowed(
            ".scratch/2026-08-22-pollution-mitigation/spec.md"
        ))
        self.assertTrue(commit_filter.is_allowed(
            ".scratch/2026-08-22-pollution-mitigation/sub/nested.md"
        ))

    def test_no_trailing_slash(self):
        # '.scratch/reviews/' is an entry
        self.assertTrue(commit_filter.is_allowed(
            ".scratch/reviews/file.md"
        ))

    def test_outside_directory(self):
        self.assertFalse(commit_filter.is_allowed(
            "other/path/file.md"
        ))


class TestBasenamePrefixMatch(unittest.TestCase):
    """entry 'Module.symbol' matches any file whose basename starts with 'Module'"""

    def test_symbol_match(self):
        # 'WenshuVerifier.shortOutputStopSequences' is a symbol entry
        # Match files whose basename (without extension) starts with 'WenshuVerifier'
        self.assertTrue(commit_filter.is_allowed(
            "Sources/WenshuApp/Core/Agent/Connector/WenshuVerifier.swift"
        ))

    def test_no_match(self):
        # 'WenshuVerifier' matches 'WenshuVerifier.swift' but not 'WenshuAgent.swift'
        # Actually wait - it would match 'WenshuVerifier' as a prefix, not a file
        # We want to test that 'WenshuAgent' does NOT match 'WenshuVerifier.X' entry
        self.assertFalse(commit_filter.is_allowed(
            "Sources/WenshuApp/Core/Agent/Connector/WenshuAgent.swift"
        ))


class TestFilenameNotTreatedAsSymbol(unittest.TestCase):
    """'CONTEXT.md' should be treated as a filename (= exact + suffix only),
    not as a symbol prefix (would falsely match 'CONTEXT.md.bak').
    """

    def test_context_md_exact(self):
        self.assertTrue(commit_filter.is_allowed("CONTEXT.md"))

    def test_context_md_suffix(self):
        self.assertTrue(commit_filter.is_allowed("a/CONTEXT.md"))

    def test_context_md_bak_not_matched(self):
        # = 'CONTEXT.md' treated as filename (= not as basename prefix)
        # = 'CONTEXT.md.bak' should NOT match the 'CONTEXT.md' entry
        self.assertFalse(commit_filter.is_allowed("CONTEXT.md.bak"))


class TestGlobPrefixMatch(unittest.TestCase):
    """entry ending in '-' or '_' is treated as a glob prefix"""

    def test_code_review_prefix(self):
        # '.scratch/code-review-' matches '.scratch/code-review-spec-.../...'
        self.assertTrue(commit_filter.is_allowed(
            ".scratch/code-review-spec-8-26-v1-2-0-spec-axis/SPEC-AXIS-REPORT.md"
        ))

    def test_prefix_same_file(self):
        # '.scratch/code-review-' with empty after (= same directory)
        # Actually 'code-review-' is itself a 'filename' (= no '/' after),
        # so this is more of a 'basename' test
        self.assertTrue(commit_filter.is_allowed(
            ".scratch/code-review-something"
        ))

    def test_does_not_match_unrelated(self):
        # 'code-review-' should NOT match 'code-reviews' (no '-' boundary)
        # Actually check: 'code-review-' has trailing '-', so it requires
        # 'code-review-' prefix AND then boundary ('/' or end).
        # '.scratch/code-reviews/foo' would not match.
        self.assertFalse(commit_filter.is_allowed(
            ".scratch/code-reviews/foo.md"
        ))


if __name__ == '__main__':
    unittest.main()
