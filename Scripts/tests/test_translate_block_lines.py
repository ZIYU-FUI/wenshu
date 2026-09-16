#!/usr/bin/env python3
"""test_translate_block_lines.py - Unit tests for Scripts/translate-cjk-comments.py.

Pins the 3 internal helpers' behavior + the orchestrating
translate_block_lines function. Behavior preserved 100% after refactor.
"""
import sys
import os
import unittest

# Add Scripts/ to path so we can import the module
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPTS_DIR)

# Skip the import-time SOURCES_ROOT computation by faking that the script
# can be imported. (translate-cjk-comments.py has top-level constants that
# depend on the file's path; importing from tests/ would compute the wrong
# root. We exec the source in a controlled namespace instead.)
import importlib.util
spec = importlib.util.spec_from_file_location(
    "translate_cjk_comments",
    os.path.join(SCRIPTS_DIR, "translate-cjk-comments.py"),
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestSplitCommentLine(unittest.TestCase):
    """split_comment_line is used internally by translate_block_lines."""

    def test_double_slash(self):
        # 4 spaces of indent + '// foo' → ('    ', '//', 'foo')
        self.assertEqual(
            mod.split_comment_line("    // foo"),
            ("    ", "//", " foo"),
        )

    def test_triple_slash_doc(self):
        # '/// bar' is a doc comment
        self.assertEqual(
            mod.split_comment_line("/// bar"),
            ("", "///", " bar"),
        )

    def test_block_comment(self):
        # '/* hi */' is a block comment
        self.assertEqual(
            mod.split_comment_line("    /* hi */"),
            ("    ", "/*", " hi */"),
        )

    def test_no_comment(self):
        # 'plain text' has no comment marker
        result = mod.split_comment_line("plain text")
        self.assertEqual(result[0], "")
        self.assertEqual(result[1], "")
        self.assertEqual(result[2], "plain text")


class TestBuildTodoMarker(unittest.TestCase):
    def test_first_non_empty_line(self):
        # First non-empty line is 'first cjk' = the label
        parsed = [("    ", "//", " first cjk"), ("    ", "//", " second")]
        result = mod._build_todo_marker(parsed, ["    // first cjk", "    // second"])
        # The marker is inserted ABOVE the original block (= 3 lines total).
        self.assertEqual(len(result), 3)
        self.assertTrue(result[0].startswith("    // [CJK-TRANSLATE:"))
        self.assertIn("first cjk", result[0])

    def test_indent_preserved(self):
        parsed = [("        ", "///", " doc text")]
        result = mod._build_todo_marker(parsed, ["        /// doc text"])
        self.assertTrue(result[0].startswith("        // [CJK-TRANSLATE:"))

    def test_fallback_to_first_line(self):
        # All lines empty → use first line as label (= empty)
        parsed = [("    ", "//", "")]
        result = mod._build_todo_marker(parsed, ["    //"])
        # Marker line still emitted, label = '' (= second arg to next())
        self.assertTrue(result[0].startswith("    // [CJK-TRANSLATE:"))


class TestPadToMatch(unittest.TestCase):
    def test_pad_with_empty(self):
        result = mod._pad_to_match("a\nb", 4)
        self.assertEqual(result, ["a", "b", "", ""])

    def test_truncate(self):
        result = mod._pad_to_match("a\nb\nc\nd", 2)
        self.assertEqual(result, ["a", "b"])

    def test_exact(self):
        result = mod._pad_to_match("a\nb", 2)
        self.assertEqual(result, ["a", "b"])


class TestReconstructLine(unittest.TestCase):
    def test_double_slash_with_content(self):
        # 4 spaces, //, ' foo' → 4 spaces + // + space + 'foo'
        self.assertEqual(
            mod._reconstruct_line(("    ", "//", " foo"), "translated text"),
            "    // translated text",
        )

    def test_double_slash_empty_content(self):
        # 4 spaces, //, ' foo' → 4 spaces + // + '' (no trailing space)
        self.assertEqual(
            mod._reconstruct_line(("    ", "//", " foo"), ""),
            "    //",
        )

    def test_triple_slash(self):
        self.assertEqual(
            mod._reconstruct_line(("", "///", " bar"), "doc"),
            "/// doc",
        )

    def test_block_comment(self):
        # No space added after /*
        self.assertEqual(
            mod._reconstruct_line(("    ", "/*", " hi"), "block content"),
            "    /*block content",
        )


class TestTranslateBlockLines(unittest.TestCase):
    """End-to-end test of the orchestrating function."""

    def test_no_translation_emits_todo(self):
        # Mock argos + manual lookup = no translation found → TODO marker emitted
        original_argos = mod.argos_translate
        original_manual = mod.manual_lookup_translate
        mod.argos_translate = lambda text: None  # argos unavailable
        mod.manual_lookup_translate = lambda text: None  # no manual match
        try:
            block = ["    // 第一行 cjk", "    // 第二行"]
            result = mod.translate_block_lines(block, cache={})
            # Should have 1 extra TODO marker line + original 2 lines
            self.assertEqual(len(result), 3)
            self.assertTrue(result[0].startswith("    // [CJK-TRANSLATE:"))
            self.assertEqual(result[1:], block)
        finally:
            mod.argos_translate = original_argos
            mod.manual_lookup_translate = original_manual

    def test_argos_translation_used(self):
        # argos provides translation → no TODO marker, just 2 translated lines
        original_argos = mod.argos_translate
        # argos_translate is called with joined content. If it returns a string,
        # the result is split back into lines.
        mod.argos_translate = lambda text: "First line EN\nSecond line EN" if text else None
        try:
            block = ["    // 第一行 cjk", "    // 第二行"]
            result = mod.translate_block_lines(block, cache={})
            self.assertEqual(len(result), 2)
            self.assertIn("EN", result[0])
            self.assertIn("EN", result[1])
        finally:
            mod.argos_translate = original_argos


if __name__ == '__main__':
    unittest.main()
