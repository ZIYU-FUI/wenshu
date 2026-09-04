#!/usr/bin/env python3
"""Translate historical CJK comment lines in Sources/WenshuApp/ to English.

v2 strategy (offline-only, cache + manual lookup):

  1. Load pre-translated cache from .scratch/cjk-translation-cache.json.
     Filter out garbage entries (heuristic: contains '♪' or starts with '@'
     or 'SQLITE' / 'sqlite3' / 'If sqlite').
  2. Walk all .swift files under Sources/WenshuApp/.
  3. Group consecutive CJK-comment lines into blocks (separated by blank
     lines or non-CJK lines).
  4. For each block:
     a) Exact-match against the cache (full multi-line block).
     b) Else try the longest matching cache substring.
     c) Else apply manual lookup table for common wenshu terms.
     d) Else leave the CJK unchanged and mark a TODO marker above the
        block: `// [CJK-TRANSLATE: <first line of block>]`.
  5. Rules to avoid noise:
     - Skip blocks with CJK<3 chars total.
     - Skip blocks where CJK is <50% of visible content.
     - Skip blocks without a // comment marker outside string literals.
     - Never modify string literal contents.

Hard rules:
  - DO NOT touch string literals.
  - DO NOT touch any file outside Sources/WenshuApp/.
  - DO NOT call any online translation API.
  - DO NOT change source code (= only comment content).
  - DO NOT introduce any third-party dependency.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCES_ROOT = REPO_ROOT / "Sources" / "WenshuApp"
CACHE_PATH = REPO_ROOT / ".scratch" / "cjk-translation-cache.json"
LOG_PATH = REPO_ROOT / ".scratch" / "cjk-v2-run.log"

ANY_CJK_RE = re.compile(r"[\u4e00-\u9fff]")
LINE_STRING_RE = re.compile(r'"(?:[^"\\\n]|\\.)*"')

# Manual lookup table — substring → English. Longer keys match first.
# Only used when the cache missed entirely. Applied per-block; the result
# is one English line per CJK line (joined with blank lines for blank
# separators).
MANUAL_LOOKUP: list[tuple[str, str]] = [
    # Boss OOB phrases (T3a vocabulary, expanded)
    ("等老板拍板", "awaiting boss decision"),
    ("等老板拍", "awaiting boss decision"),
    ("等老板确认", "awaiting boss confirmation"),
    ("等老板", "awaiting boss"),
    ("老板拍板", "boss decision"),
    ("老板拍", "boss decision"),
    ("不归 ANAN 管", "not ANAN's concern"),
    ("不归ANAN管", "not ANAN's concern"),
    ("拍一下", "give the go-ahead"),
    ("确认下", "confirm"),
    # Common wenshu terms
    ("文枢", "Wenshu"),
    ("待办", "todo"),
    ("需求", "requirement"),
    ("应该", "should"),
    ("建议", "recommend"),
    ("考虑", "consider"),
    ("可能", "might"),
    ("也许", "perhaps"),
    ("可以", "can"),
    ("老板", "boss"),
    ("拍板", "decision"),
    ("确认", "confirm"),
]


def is_garbage(translation: str) -> bool:
    """Heuristic: detect translation-API artifacts."""
    if "♪" in translation:
        return True
    if translation.startswith("@") and len(translation) > 1 and translation[1].isalpha():
        return True
    if translation.startswith(("SQLITE", "sqlite3", "If sqlite", "SQL ")):
        return True
    return False


def load_cache() -> dict[str, str]:
    """Load and filter the cache. Returns {cjk: english} with garbage removed."""
    if not CACHE_PATH.exists():
        return {}
    with open(CACHE_PATH, encoding="utf-8") as fh:
        raw = json.load(fh)
    filtered: dict[str, str] = {}
    for k, v in raw.items():
        if not isinstance(v, str):
            continue
        if is_garbage(v):
            continue
        if ANY_CJK_RE.search(v):
            continue
        if not v.strip():
            continue
        filtered[k] = v.strip()
    return filtered


def strip_string_literals(line: str) -> str:
    """Remove string literal content from a line, returning only the non-string parts."""
    return LINE_STRING_RE.sub('""', line)


def is_cjk_line(line: str) -> bool:
    """True if line has any CJK char (anywhere, including strings — we filter later)."""
    return bool(ANY_CJK_RE.search(line))


def cjk_ratio(line: str) -> float:
    """Return the fraction of CJK characters in the visible (non-string) content."""
    visible = strip_string_literals(line)
    cjk = sum(1 for c in visible if 0x4E00 <= ord(c) <= 0x9FFF)
    visible_chars = sum(1 for c in visible if not c.isspace())
    if visible_chars == 0:
        return 0.0
    return cjk / visible_chars


def has_comment_marker(line: str) -> bool:
    """True if line has // outside string literals."""
    return "//" in strip_string_literals(line)


def should_translate_line(line: str) -> bool:
    """Decide if a line should be considered for translation.

    Returns False if:
      - CJK count < 3 (noise)
      - CJK ratio of visible content < 50%
      - No // comment marker outside strings
      - Line is already a TODO marker from a previous run
    """
    if not is_cjk_line(line):
        return False
    # Skip existing TODO markers
    if "[CJK-TRANSLATE]" in line:
        return False
    visible = strip_string_literals(line)
    cjk = sum(1 for c in visible if 0x4E00 <= ord(c) <= 0x9FFF)
    if cjk < 3:
        return False
    if cjk_ratio(line) < 0.5:
        return False
    if not has_comment_marker(line):
        return False
    return True


def manual_translate(cjk_block: str) -> str | None:
    """Apply manual lookup to a multi-line block. Returns English or None."""
    # Sort by length descending so longer phrases match first.
    sorted_pairs = sorted(MANUAL_LOOKUP, key=lambda x: -len(x[0]))
    out_lines: list[str] = []
    applied = False
    for line in cjk_block.split("\n"):
        # Find the comment portion
        if "//" not in line:
            out_lines.append(line)
            continue
        idx = line.index("//")
        indent = line[:idx]
        comment = line[idx + 2 :]
        new_comment = comment
        for cjk, en in sorted_pairs:
            if cjk and cjk in new_comment:
                new_comment = new_comment.replace(cjk, en)
                applied = True
        # Collapse whitespace
        new_comment = re.sub(r"\s+", " ", new_comment).strip()
        if ANY_CJK_RE.search(new_comment):
            # Still has CJK → manual didn't cover it
            return None
        out_lines.append(f"{indent}// {new_comment}")
    if not applied:
        return None
    return "\n".join(out_lines)


def find_block_in_cache(block: str, cache: dict[str, str]) -> str | None:
    """Try to find this block in the cache. Returns English translation or None.

    Strategy:
      1) Exact match.
      2) Longest cache key that is a substring of the block.
    """
    if block in cache:
        return cache[block]
    best_key = None
    best_len = 0
    for k in cache:
        if k in block and len(k) > best_len:
            best_key = k
            best_len = len(k)
    if best_key is None:
        return None
    en = cache[best_key]
    if ANY_CJK_RE.search(en):
        return None
    # Replace only the matched key inside the block, leave other text alone.
    return block.replace(best_key, en)


def group_blocks(lines: list[str]) -> list[tuple[int, int, list[int]]]:
    """Group consecutive CJK-translatable lines into blocks.

    A block is a maximal contiguous run of indices where should_translate_line
    is True. Blank lines and non-translatable lines break the block.

    Returns list of (start_idx, end_idx_exclusive, line_indices).
    """
    blocks: list[tuple[int, int, list[int]]] = []
    current: list[int] = []
    for i, line in enumerate(lines):
        if should_translate_line(line):
            current.append(i)
        else:
            if current:
                blocks.append((current[0], current[-1] + 1, current))
                current = []
    if current:
        blocks.append((current[0], current[-1] + 1, current))
    return blocks


def strip_old_todo_markers(lines: list[str]) -> tuple[list[str], int]:
    """Remove leftover TODO markers from a previous failed run.

    Old format: `// [CJK-TRANSLATE: <CJK text>] // awaiting manual translation`
    These have no value — the original CJK lines they pointed to are still
    in the file (the previous run added the marker ABOVE the original line
    without replacing it).

    Strategy:
      - If the next line(s) are real CJK comments that the marker refers to,
        delete only the marker line(s).
      - Otherwise delete the marker line(s) too (orphan).
    """
    out: list[str] = []
    removed = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        if re.match(r"^\s*//\s*\[CJK-TRANSLATE:", line):
            # Find the original CJK line right after this marker.
            j = i + 1
            while j < len(lines) and re.match(r"^\s*//\s*\[CJK-TRANSLATE:", lines[j]):
                j += 1
            # Drop markers [i:j]
            removed += j - i
            i = j
            continue
        out.append(line)
        i += 1
    return out, removed


def process_file(path: Path, cache: dict[str, str]) -> dict[str, int]:
    """Process one Swift file. Returns stats dict."""
    stats = {"cache": 0, "manual": 0, "todo": 0, "skipped": 0, "unchanged": 0, "blocks": 0, "old_markers_removed": 0}
    with open(path, encoding="utf-8") as fh:
        original_lines = fh.readlines()

    # Pre-pass: strip old TODO markers from a previous run.
    cleaned_lines, n_removed = strip_old_todo_markers(original_lines)
    stats["old_markers_removed"] = n_removed
    if n_removed > 0:
        original_lines = cleaned_lines

    blocks = group_blocks(original_lines)
    if not blocks:
        if n_removed > 0:
            with open(path, "w", encoding="utf-8") as fh:
                fh.writelines(original_lines)
        return stats

    new_lines: list[str] = list(original_lines)
    # Process blocks in reverse so indices stay valid as we splice.
    for start, end, indices in reversed(blocks):
        block_text = "\n".join(original_lines[i].rstrip("\n") for i in indices)
        en = find_block_in_cache(block_text, cache)
        if en is not None:
            # Split English block into same number of lines as CJK block.
            en_lines = en.split("\n")
            if len(en_lines) == len(indices):
                for i, idx in enumerate(indices):
                    new_lines[idx] = en_lines[i] + "\n"
                stats["cache"] += len(indices)
                stats["blocks"] += 1
                continue
            # Length mismatch — fall back to manual TODO to be safe.

        manual = manual_translate(block_text)
        if manual is not None:
            en_lines = manual.split("\n")
            if len(en_lines) == len(indices):
                for i, idx in enumerate(indices):
                    new_lines[idx] = en_lines[i] + "\n"
                stats["manual"] += len(indices)
                stats["blocks"] += 1
                continue

        # Mark TODO above the block — preserve original CJK lines untouched.
        stats["todo"] += len(indices)
        stats["blocks"] += 1
        first_line = original_lines[indices[0]]
        indent = first_line[: len(first_line) - len(first_line.lstrip())]
        todo = (
            f"{indent}// [CJK-TRANSLATE] {len(indices)} line(s) awaiting manual translation "
            f"(see git blame for original CJK text)\n"
        )
        new_lines.insert(start, todo)

    if new_lines != original_lines:
        with open(path, "w", encoding="utf-8") as fh:
            fh.writelines(new_lines)

    return stats


def main() -> int:
    cache = load_cache()
    log_lines = [
        f"Cache entries (filtered): {len(cache)}",
        f"Sources root: {SOURCES_ROOT}",
        "",
    ]
    totals = {
        "cache": 0,
        "manual": 0,
        "todo": 0,
        "old_markers_removed": 0,
        "files_changed": 0,
    }

    swift_files = sorted(SOURCES_ROOT.rglob("*.swift"))
    log_lines.append(f"Swift files scanned: {len(swift_files)}")
    log_lines.append("")

    for path in swift_files:
        stats = process_file(path, cache)
        any_action = stats["cache"] + stats["manual"] + stats["todo"] + stats["old_markers_removed"]
        if any_action:
            totals["files_changed"] += 1
            log_lines.append(
                f"{path.relative_to(REPO_ROOT)}: "
                f"cache={stats['cache']} manual={stats['manual']} "
                f"todo={stats['todo']} old_markers_removed={stats['old_markers_removed']} "
                f"blocks={stats['blocks']}"
            )
        for k in ("cache", "manual", "todo", "old_markers_removed"):
            totals[k] += stats[k]

    log_lines.append("")
    log_lines.append("=== TOTALS ===")
    log_lines.append(f"Files changed: {totals['files_changed']}")
    log_lines.append(f"Translated via cache:  {totals['cache']}")
    log_lines.append(f"Translated via manual: {totals['manual']}")
    log_lines.append(f"Marked TODO:           {totals['todo']}")
    log_lines.append(f"Old markers removed:   {totals['old_markers_removed']}")

    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_PATH, "w", encoding="utf-8") as fh:
        fh.write("\n".join(log_lines) + "\n")

    print("\n".join(log_lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())