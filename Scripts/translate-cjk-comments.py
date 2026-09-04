#!/usr/bin/env python3
"""Translate historical CJK comment lines in Sources/WenshuApp/ to English.

Strategy:
  1. Walk all .swift files under Sources/WenshuApp/.
  2. For each line, strip string literals (single-line + triple-quoted multi-line)
     to find lines where CJK appears OUTSIDE strings (= comment content).
  3. Translate each CJK comment block via api.mymemory.translated.net
     (free, no auth). Cache results locally to avoid duplicate API calls.
  4. Reconstruct lines preserving the original `//`, indentation, and
     trailing structure. Run a post-processing pass to fix common
     translation-API artifacts (extra spaces around Swift punctuation,
     lowercased acronyms like HIG/PT/PX, etc.).

Hard rules:
  - DO NOT touch string literals.
  - DO NOT touch .lproj files.
  - DO NOT touch anything outside Sources/WenshuApp/.
  - DO NOT touch AGENTS.md / CLAUDE.md / README.md / CHANGELOG.md.
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCES_ROOT = REPO_ROOT / "Sources" / "WenshuApp"
CACHE_PATH = REPO_ROOT / ".scratch" / "cjk-translation-cache.json"

CJK_RE = re.compile(r"[\u4e00-\u9fff]")
TRIPLE_QUOTED_RE = re.compile(r'"""[\s\S]*?"""', re.MULTILINE)
DOUBLE_QUOTED_RE = re.compile(r'"(?:[^"\\\n]|\\.)*"')
SINGLE_QUOTED_RE = re.compile(r"'(?:[^'\\\n]|\\.)*'")


# Pre-substitution: replace a SMALL set of wenshu-specific Chinese jargon
# with English BEFORE sending to the translation API. Substrings are matched
# longest-first to avoid concatenation artifacts like "顶栏" + "复用" → "top bar reuse".
PRE_SUBSTITUTIONS: list[tuple[str, str]] = [
    # Boss quote patterns (T3a vocabulary, expanded)
    ("老板拍", "boss-decision"),
    ("等老板拍", "awaiting boss-decision"),
    ("老板", "boss"),
    # 拍 alone is rare in comments but occurs in "老板 ... 拍 '...'" pattern
    ("拍", "decision"),  # context-specific verb in wenshu commit history
    # Brand / classification terms
    ("文枢", "Wenshu"),
    ("中国图书馆分类法", "Chinese Library Classification (CLC)"),
    ("中图法", "CLC"),
    # Liquid Glass (Apple's macOS 27 design system)
    ("液态玻璃", "Liquid Glass"),
]


# Post-processing fixes for common translation-API artifacts.
# Applied in order; later fixes can undo early ones, so order matters.
POST_FIXES: list[tuple[re.Pattern, str]] = [
    # === Lowercased acronyms the API lowercases ===
    (re.compile(r"\bApple\s+Hig\b"), "Apple HIG"),
    (re.compile(r"\bApple\s+[Aa]pi\b"), "Apple API"),
    (re.compile(r"\bSwift\s+Ui\b"), "SwiftUI"),
    (re.compile(r"\bMark:\s*-"), "MARK: -"),
    (re.compile(r"^//\s*Mark:"), "// MARK:"),
    # === Numeric format ===
    # 1: 1 -> 1:1
    (re.compile(r"(\d+)\s*:\s*(\d+)\b"), r"\1:\2"),
    # v 0.34 -> v0.34
    (re.compile(r"\bv\s+(\d+\.\d+(?:\.\d+)?)\b"), r"v\1"),
    # File.swift: 1234 -> File.swift:1234 (line refs)
    (re.compile(r"(\w+\.swift):\s+(\d+)"), r"\1:\2"),
    # (1234) -> (1234)
    (re.compile(r"\(\s+(\d+)\s+\)"), r"(\1)"),
    # === @ State, @ StateObject -> @State, @StateObject ===
    (re.compile(r"@\s+(State|StateObject|ObservedObject|EnvironmentObject|Published|Binding|Environment|FocusState)\b"), r"@\1"),
    # === # 3, # 1 -> #3, #1 ===
    (re.compile(r"#\s+(\d+)"), r"#\1"),
    # === Drop space between any `.methodName` and `(`
    (re.compile(r"\.(\w+)\s+\("), r".\1("),
    # === Reduce double spaces ===
    (re.compile(r"  +"), " "),
    # === Trim trailing whitespace before newline ===
    (re.compile(r"[ \t]+$"), ""),
]


def strip_strings_file(content: str) -> str:
    """Strip ALL string literal contents from a whole file, handling multi-line strings."""
    content = re.sub(r'"""[\s\S]*?"""', '""', content)
    content = DOUBLE_QUOTED_RE.sub('""', content)
    content = SINGLE_QUOTED_RE.sub("''", content)
    return content


def is_comment_line(stripped_line: str) -> bool:
    """True if the (string-stripped) line is purely a comment or whitespace."""
    s = stripped_line.strip()
    if not s:
        return False
    return (
        s.startswith("//")
        or s.startswith("/*")
        or s.startswith("*")
    )


def find_cjk_blocks(file_path: Path):
    """Yield (start_line, end_line, [original_lines]) for each consecutive
    run of comment lines that contain CJK outside of string literals.

    Lines are 1-indexed.
    """
    content = file_path.read_text(encoding="utf-8")
    lines = content.split("\n")
    stripped_content = strip_strings_file(content)
    stripped_lines = stripped_content.split("\n")
    n = len(lines)

    i = 0
    while i < n:
        stripped = stripped_lines[i] if i < len(stripped_lines) else ""
        if is_comment_line(stripped) and CJK_RE.search(stripped):
            j = i
            while j < n:
                s = stripped_lines[j] if j < len(stripped_lines) else ""
                if is_comment_line(s):
                    j += 1
                else:
                    break
            block_lines = lines[i:j]
            yield (i + 1, j, block_lines)
            i = j
        else:
            i += 1


class Translator:
    """Translate zh->en via api.mymemory.translated.net, with on-disk cache."""

    def __init__(self, cache_path: Path):
        self.cache_path = cache_path
        self.cache: dict[str, str] = {}
        if cache_path.exists():
            try:
                self.cache = json.loads(cache_path.read_text(encoding="utf-8"))
            except Exception:
                self.cache = {}

    def save(self):
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)
        self.cache_path.write_text(
            json.dumps(self.cache, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _translate_remote(self, text: str) -> str | None:
        """Translate one chunk. Returns None on failure."""
        url = (
            "https://api.mymemory.translated.net/get?q="
            + urllib.parse.quote(text)
            + "&langpair=zh-CN|en-US"
        )
        for attempt in range(3):
            try:
                with urllib.request.urlopen(url, timeout=60) as r:
                    data = json.load(r)
                if data.get("responseStatus") != 200:
                    raise RuntimeError(f"status={data.get('responseStatus')}")
                out = data["responseData"]["translatedText"]
                # Decode HTML entities if the API returned them (= common when
                # input contains apostrophes, quotes, or accented chars).
                out = (
                    out.replace("&#39;", "'")
                       .replace("&quot;", '"')
                       .replace("&amp;", "&")
                       .replace("&lt;", "<")
                       .replace("&gt;", ">")
                       .replace("&#10;", "\n")
                       .replace("&#13;", "\r")
                )
                if "PLEASE SELECT" in out.upper() or "INVALID" in out.upper() or "QUERY LENGTH LIMIT" in out.upper():
                    raise RuntimeError(f"bad response: {out[:80]}")
                return out
            except Exception as e:
                sys.stderr.write(f"  translate attempt {attempt + 1} failed: {e}\n")
                time.sleep(2 + attempt * 2)
        return None

    def translate_lines(self, lines: list[str]) -> list[str]:
        """Translate a list of pre-stripped comment-content lines.

        Returns a parallel list of translated strings. On failure for any
        chunk, falls back to per-line translation.
        """
        if not lines:
            return []
        # Build chunks of <= 380 chars total, <= 6 lines each.
        chunks: list[list[int]] = []
        current_chunk: list[int] = []
        current_size = 0
        for i, ln in enumerate(lines):
            line_size = len(ln.encode("utf-8")) + 1
            if current_chunk and (
                current_size + line_size > 380 or len(current_chunk) >= 6
            ):
                chunks.append(current_chunk)
                current_chunk = []
                current_size = 0
            current_chunk.append(i)
            current_size += line_size
        if current_chunk:
            chunks.append(current_chunk)

        result = list(lines)
        for chunk in chunks:
            chunk_text = "\n".join(lines[i] for i in chunk)
            translated = self._translate_remote(chunk_text)
            if translated is None:
                sys.stderr.write(f"  chunk of {len(chunk)} lines: translation failed, falling back to per-line\n")
                for idx in chunk:
                    r = self._translate_remote(lines[idx])
                    if r is not None:
                        result[idx] = r
                continue
            translated_lines = translated.split("\n")
            if len(translated_lines) == len(chunk):
                for idx, tr in zip(chunk, translated_lines):
                    result[idx] = tr
            elif len(translated_lines) < len(chunk):
                # Some lines were merged. Per-line fallback for ALL lines in chunk.
                sys.stderr.write(f"  chunk of {len(chunk)} lines: got {len(translated_lines)}, per-line fallback\n")
                for idx in chunk:
                    r = self._translate_remote(lines[idx])
                    if r is not None:
                        result[idx] = r
            else:
                # More lines than input — merge extras into last line
                head = translated_lines[: len(chunk) - 1]
                tail = " ".join(translated_lines[len(chunk) - 1 :])
                for idx, tr in zip(chunk[:-1], head):
                    result[idx] = tr
                result[chunk[-1]] = tail
                sys.stderr.write(f"  chunk of {len(chunk)} lines: got {len(translated_lines)}, merged extras\n")
        return result

    def translate(self, text: str) -> str:
        """Translate text; return the original on persistent failure.

        For multi-line input (= a comment block), uses batched translation
        for speed.
        """
        cache_key = text.strip()
        if not cache_key:
            return text
        if cache_key in self.cache:
            return self.cache[cache_key]
        # Apply pre-substitutions to make the API output cleaner.
        pre = text
        for src, dst in PRE_SUBSTITUTIONS:
            pre = pre.replace(src, dst)
        # Split into lines and translate in batches.
        lines = pre.split("\n")
        translated_lines = self.translate_lines(lines)
        translated = "\n".join(translated_lines)
        # Apply post-fixes to repair common API artifacts.
        for pat, repl in POST_FIXES:
            translated = pat.sub(repl, translated)
        self.cache[cache_key] = translated
        return translated


def split_comment_line(line: str) -> tuple[str, str, str]:
    """Split a comment line into (indent, marker, content)."""
    stripped = line.lstrip(" \t")
    indent = line[: len(line) - len(stripped)]
    for marker in ("///", "//", "/*", "*/", "*"):
        if stripped.startswith(marker):
            content = stripped[len(marker):]
            return indent, marker, content
    return indent, "", stripped


def translate_block_lines(block_lines: list[str], translator: Translator) -> list[str]:
    """Translate a list of comment lines, preserving indentation and markers."""
    parsed = [split_comment_line(ln) for ln in block_lines]
    contents = [p[2].strip() for p in parsed]
    joined = "\n".join(contents)
    translated = translator.translate(joined)
    translated_contents = translated.split("\n")
    if len(translated_contents) < len(parsed):
        translated_contents += [""] * (len(parsed) - len(translated_contents))
    elif len(translated_contents) > len(parsed):
        translated_contents = translated_contents[: len(parsed)]
    result = []
    for (indent, marker, _orig_content), new_content in zip(parsed, translated_contents):
        if marker in ("//", "///"):
            sep = " " if new_content else ""
            result.append(f"{indent}{marker}{sep}{new_content}")
        elif marker:
            result.append(f"{indent}{marker}{new_content}")
        else:
            result.append(f"{indent}{new_content}")
    return result


def main():
    cache_path = CACHE_PATH
    translator = Translator(cache_path)
    swift_files = sorted(SOURCES_ROOT.rglob("*.swift"))
    sys.stderr.write(f"Found {len(swift_files)} swift files\n")

    modified_files = []
    total_blocks = 0
    total_lines_changed = 0

    for f in swift_files:
        try:
            blocks = list(find_cjk_blocks(f))
        except Exception as e:
            sys.stderr.write(f"  ERR parsing {f}: {e}\n")
            continue
        if not blocks:
            continue
        sys.stderr.write(f"\n{f.relative_to(REPO_ROOT)}: {len(blocks)} CJK comment block(s)\n")

        content = f.read_text(encoding="utf-8")
        lines = content.split("\n")
        any_changed = False
        for start_line, end_line, block_lines in reversed(blocks):
            translated_lines = translate_block_lines(block_lines, translator)
            if translated_lines != block_lines:
                lines[start_line - 1 : end_line] = translated_lines
                any_changed = True
                total_lines_changed += end_line - start_line + 1
            else:
                sys.stderr.write(f"  block at L{start_line}-{end_line}: UNCHANGED\n")
            total_blocks += 1

        if any_changed:
            new_content = "\n".join(lines)
            f.write_text(new_content, encoding="utf-8")
            modified_files.append(f)
        translator.save()

    translator.save()
    sys.stderr.write(f"\n=== summary ===\n")
    sys.stderr.write(f"files modified: {len(modified_files)}\n")
    sys.stderr.write(f"blocks processed: {total_blocks}\n")
    sys.stderr.write(f"lines changed: {total_lines_changed}\n")
    for f in modified_files:
        sys.stderr.write(f"  {f.relative_to(REPO_ROOT)}\n")


if __name__ == "__main__":
    main()
