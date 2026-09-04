#!/usr/bin/env python3
"""Translate historical CJK comment lines in Sources/WenshuApp/ to English.

v3 strategy (offline-only, safety-hardened, supersedes v1 + v2):

  1. Pre-flight guard: refuse to write any file that already contains
     pollution markers (= ♪ / @SlateView / "If sqlite3 exec" / etc.).
     These markers are the signature of the 2026-09-04 CJK cascade garbage
     event (= race condition + online API rate limit produced mixed
     garbage lines). Once a file is polluted, NEVER overwrite it from
     this script — human must clean it first.

  2. Atomic write: every modified file is written to `<file>.tmp` first,
     then `os.rename(tmp, dst)` replaces the original atomically. If the
     process is killed mid-write, the original file is untouched.

  3. Mark TODO only: if no translation is found in the cache and no
     manual lookup applies, write `[CJK-TRANSLATE: <original first line>]`
     as a marker line ABOVE the block. NEVER write partial / mixed /
     garbage translations.

  4. No online API: all translation comes from the offline cache
     `.scratch/cjk-translation-cache.json` (= 559 entries at last ship)
     plus a small manual lookup table for high-frequency wenshu terms.
     The `argostranslate.translate(text, 'zh', 'en')` offline engine is
     available as a fallback for new CJK that the cache misses.

Hard rules (unchanged from v2):
  - DO NOT touch string literals.
  - DO NOT touch .lproj files.
  - DO NOT touch anything outside Sources/WenshuApp/.
  - DO NOT touch AGENTS.md / CLAUDE.md / README.md / CHANGELOG.md.
  - DO NOT call any online translation API (= no urllib.request).
  - DO NOT introduce any third-party dependency (= argostranslate is
    an existing approved Python runtime dep; nothing new is added).
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCES_ROOT = REPO_ROOT / "Sources" / "WenshuApp"
CACHE_PATH = REPO_ROOT / ".scratch" / "cjk-translation-cache.json"

ANY_CJK_RE = re.compile(r"[\u4e00-\u9fff]")
TRIPLE_QUOTED_RE = re.compile(r'"""[\s\S]*?"""', re.MULTILINE)
DOUBLE_QUOTED_RE = re.compile(r'"(?:[^"\\\n]|\\.)*"')
SINGLE_QUOTED_RE = re.compile(r"'(?:[^'\\\n]|\\.)*'")

# Pollution markers observed during the 2026-09-04 CJK cascade failure.
# These are the signatures of mixed garbage lines (= online API rate limit
# returned a partial response that got stitched onto a real line). If ANY
# of these appear in a file, refuse to write to it (= the file is already
# broken and must be hand-cleaned before this script runs).
POLLUTION_MARKERS = (
    "\u266a",        # ♪
    "@SlateView",
    "@MarkdownView",
    "If sqlite3 exec",
    "If sqlite",
    "SLATE VIEW",
    "<<<",           # garbage truncation marker from rate-limited responses
    ">>>",           # garbage truncation marker
)

# Manual lookup table — substring → English. Longer keys match first.
# Only used when the cache missed entirely AND argostranslate is unavailable.
MANUAL_LOOKUP: list[tuple[str, str]] = [
    ("老板拍", "boss-decision"),
    ("等老板拍", "awaiting boss-decision"),
    ("老板", "boss"),
    ("文枢", "Wenshu"),
    ("中图法", "CLC"),
    ("中国图书馆分类法", "Chinese Library Classification (CLC)"),
    ("液态玻璃", "Liquid Glass"),
]


def file_is_polluted(path: Path) -> bool:
    """Return True if `path` already contains any known pollution marker.

    A polluted file MUST be cleaned by hand before this script writes to it.
    Returning True causes the per-file writer to skip the file entirely.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return False
    return any(marker in text for marker in POLLUTION_MARKERS)


def strip_strings_file(content: str) -> str:
    """Strip ALL string literal contents from a whole file, handling multi-line strings."""
    content = TRIPLE_QUOTED_RE.sub('""', content)
    content = DOUBLE_QUOTED_RE.sub('""', content)
    content = SINGLE_QUOTED_RE.sub("''", content)
    return content


def is_comment_line(stripped_line: str) -> bool:
    """True if the (string-stripped) line is purely a comment or whitespace."""
    s = stripped_line.strip()
    if not s:
        return False
    return s.startswith("//") or s.startswith("/*") or s.startswith("*")


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
        if is_comment_line(stripped) and ANY_CJK_RE.search(stripped):
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


def load_cache() -> dict[str, str]:
    """Load the offline cache. Returns {} on any read / parse error."""
    if not CACHE_PATH.exists():
        return {}
    try:
        return json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        sys.stderr.write(f"translate-cjk-comments: cache load failed ({exc}); starting empty\n")
        return {}


def save_cache(cache: dict[str, str]) -> None:
    """Atomically write the cache back to disk (= tmp + rename)."""
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE_PATH.with_suffix(CACHE_PATH.suffix + ".tmp")
    tmp.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    os.rename(tmp, CACHE_PATH)


def manual_lookup_translate(block_text: str) -> str | None:
    """Apply the manual lookup table to a block. Returns None if no rule
    matched ANY substring (= caller should fall through to TODO marker).
    """
    out = block_text
    matched_any = False
    for src, dst in MANUAL_LOOKUP:
        if src in out:
            out = out.replace(src, dst)
            matched_any = True
    return out if matched_any else None


def argos_translate(text: str) -> str | None:
    """Offline translation via argostranslate. Returns None if the engine
    is unavailable (= no model installed) so the caller can fall through
    to the TODO marker.
    """
    try:
        from argostranslate import translate as argos_translate_module  # noqa: WPS433
    except Exception:
        return None
    try:
        return argos_translate_module.translate(text, "zh", "en")
    except Exception:
        return None


def translate_block(block_text: str, cache: dict[str, str]) -> str | None:
    """Return the English translation for one block of CJK comment content.

    Resolution order:
      1. Cache hit (= full block-text key matches an existing entry).
      2. Manual lookup table (= substring substitution).
      3. argostranslate offline engine (= may return None if unavailable).
      4. None (= caller writes a `[CJK-TRANSLATE: <original>]` marker).
    """
    cache_key = block_text.strip()
    if cache_key and cache_key in cache:
        return cache[cache_key]

    # Manual lookup.
    manual = manual_lookup_translate(block_text)
    if manual is not None:
        cache[cache_key] = manual
        return manual

    # argostranslate fallback.
    argos = argos_translate(block_text)
    if argos is not None and argos.strip():
        cache[cache_key] = argos
        return argos

    # No translation available.
    return None


def split_comment_line(line: str) -> tuple[str, str, str]:
    """Split a comment line into (indent, marker, content)."""
    stripped = line.lstrip(" \t")
    indent = line[: len(line) - len(stripped)]
    for marker in ("///", "//", "/*", "*/", "*"):
        if stripped.startswith(marker):
            content = stripped[len(marker) :]
            return indent, marker, content
    return indent, "", stripped


def translate_block_lines(block_lines: list[str], cache: dict[str, str]) -> list[str]:
    """Translate one block, preserving indentation and comment markers.

    If no translation is found, the block is left untouched but a TODO
    marker line `[CJK-TRANSLATE: <first non-empty line>]` is inserted
    ABOVE the block so a human can find it later.
    """
    parsed = [split_comment_line(ln) for ln in block_lines]
    contents = [p[2].strip() for p in parsed]
    joined = "\n".join(contents)
    translated = translate_block(joined, cache)

    if translated is None:
        # TODO marker — pick the first non-empty line as the human-readable label.
        label = next((c for c in contents if c), contents[0] if contents else "")
        indent = parsed[0][0] if parsed else "    "
        marker_line = f"{indent}// [CJK-TRANSLATE: {label}]"
        return [marker_line, *block_lines]

    translated_contents = translated.split("\n")
    # Pad / truncate so 1:1 mapping holds.
    if len(translated_contents) < len(parsed):
        translated_contents += [""] * (len(parsed) - len(translated_contents))
    elif len(translated_contents) > len(parsed):
        translated_contents = translated_contents[: len(parsed)]

    result = []
    for (indent, marker, _orig), new_content in zip(parsed, translated_contents):
        if marker in ("//", "///"):
            sep = " " if new_content else ""
            result.append(f"{indent}{marker}{sep}{new_content}")
        elif marker:
            result.append(f"{indent}{marker}{new_content}")
        else:
            result.append(f"{indent}{new_content}")
    return result


def atomic_write(path: Path, content: str) -> None:
    """Write `content` to `path` via a tmp file + os.rename (= atomic on POSIX)."""
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    os.rename(tmp, path)


def process_file(path: Path, cache: dict[str, str]) -> dict[str, int]:
    """Process one swift file. Returns counters for the run summary.

    Counters:
      blocks_total = number of CJK blocks found
      blocks_translated = number of blocks that got a translation
      blocks_todo = number of blocks that got a [CJK-TRANSLATE: ...] marker
      skipped_polluted = 1 if the file was skipped due to pollution markers
    """
    if file_is_polluted(path):
        sys.stderr.write(
            f"translate-cjk-comments: SKIPPING polluted file = "
            f"{path.relative_to(REPO_ROOT)} (= hand-clean before re-running)\n"
        )
        return {"blocks_total": 0, "blocks_translated": 0, "blocks_todo": 0, "skipped_polluted": 1}

    blocks = list(find_cjk_blocks(path))
    if not blocks:
        return {"blocks_total": 0, "blocks_translated": 0, "blocks_todo": 0, "skipped_polluted": 0}

    sys.stderr.write(
        f"\n{path.relative_to(REPO_ROOT)}: {len(blocks)} CJK comment block(s)\n"
    )

    content = path.read_text(encoding="utf-8")
    lines = content.split("\n")
    any_changed = False
    translated_count = 0
    todo_count = 0

    # Iterate in reverse so line offsets in `lines` stay valid as we splice.
    for start_line, end_line, block_lines in reversed(blocks):
        new_lines = translate_block_lines(block_lines, cache)
        if new_lines != block_lines:
            # Detect TODO-marker-only change (= block_lines + 1 marker line).
            if (
                len(new_lines) == len(block_lines) + 1
                and new_lines[0].endswith("]")
                and "[CJK-TRANSLATE:" in new_lines[0]
            ):
                todo_count += 1
            else:
                translated_count += 1
            lines[start_line - 1 : end_line] = new_lines
            any_changed = True

    if any_changed:
        new_content = "\n".join(lines)
        # Atomic write — write to .tmp first, then rename. If the script
        # is killed mid-write, the original file is untouched.
        atomic_write(path, new_content)

    return {
        "blocks_total": len(blocks),
        "blocks_translated": translated_count,
        "blocks_todo": todo_count,
        "skipped_polluted": 0,
    }


def main() -> int:
    cache = load_cache()
    sys.stderr.write(
        f"translate-cjk-comments: cache has {len(cache)} entries; pollution markers = {len(POLLUTION_MARKERS)}\n"
    )

    swift_files = sorted(SOURCES_ROOT.rglob("*.swift"))
    sys.stderr.write(f"Found {len(swift_files)} swift files\n")

    totals = {"blocks_total": 0, "blocks_translated": 0, "blocks_todo": 0, "skipped_polluted": 0}

    for f in swift_files:
        try:
            counters = process_file(f, cache)
        except Exception as exc:
            sys.stderr.write(f"  ERR processing {f}: {exc}\n")
            continue
        for k, v in counters.items():
            totals[k] += v

    save_cache(cache)

    sys.stderr.write("\n=== summary ===\n")
    sys.stderr.write(f"files scanned: {len(swift_files)}\n")
    sys.stderr.write(f"blocks found: {totals['blocks_total']}\n")
    sys.stderr.write(f"blocks translated: {totals['blocks_translated']}\n")
    sys.stderr.write(f"blocks marked TODO: {totals['blocks_todo']}\n")
    sys.stderr.write(f"files skipped (polluted): {totals['skipped_polluted']}\n")
    sys.stderr.write(f"cache size: {len(cache)} entries\n")

    # Non-zero exit iff any file was polluted (= caller must clean + re-run).
    return 1 if totals["skipped_polluted"] > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
