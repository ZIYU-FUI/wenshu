#!/usr/bin/env python3
"""
B-03 commit body English-only msg-filter.

Used as `git filter-branch --msg-filter` argument (= reads commit message
from stdin, writes transformed message to stdout). Per boss 2026-09-14 OOB:
"we are still in development, not even v0.1" = no psychological barrier.

Policy:
1. PRESERVE verbatim any CJK characters inside `'...'` / `"..."` / `` `...` ``
   quotes (= bilingual boss OOB reference; = the source of truth for downstream
   LLM/agent tooling that reads commit history).
2. TRANSLATE CJK narrative outside quotes (= AGENTS.md L5-L6 English-only hard
   rule; = the 28 truly-narrative CJK lines per 2026-09-14 audit).
3. PRESERVE subject (= first line) UNCHANGED — only body lines are translated.

Translation table (= 28 narrative-CJK lines per audit). Keys are exact
substring matches; values are the English replacement. Lines without a key
match are left as-is (= preserves commit subject and any inline gloss already
present).
"""

import sys
import re

# 28-row translation table (= 2026-09-14 audit)
# Substring → English replacement
TRANSLATIONS = [
    # UI label inline references
    ("占位符 | 情节线", "placeholder | plot thread"),
    ("4th tab after 伏笔 / 占位符 / Long-Form", "4th tab after foreshadowing / placeholder / Long-Form"),
    ("* 6 tab: 提供方 API | 模型 | Agent | Memory | Skills)",
     "* 6 tabs: Provider API | Model | Agent | Memory | Skills)"),
    # Boss 9/7 follow-up subjects (translation)
    ("Boss real-device test (2026-09-07) follow-up: 你整体测一下对比",
     "Boss real-device test (2026-09-07) follow-up: test the whole thing end-to-end and compare"),
    ("Boss real-device test (2026-09-07) follow-up: 拼音首字母搜索,",
     "Boss real-device test (2026-09-07) follow-up: pinyin initial-letter search,"),
    ("Boss real-device test (2026-09-07) follow-up: 编辑器的字号设计,",
     "Boss real-device test (2026-09-07) follow-up: editor font-size design,"),
    ("Boss real-device test (2026-09-07) follow-up: 你仔细对比一下,",
     "Boss real-device test (2026-09-07) follow-up: compare carefully,"),
    ("Boss real-device test (2026-09-07) follow-up: 编辑模式也一样, 左",
     "Boss real-device test (2026-09-07) follow-up: edit mode too, left"),
    ("Boss real-device test (2026-09-07) follow-up: 内间距改反了, 原本",
     "Boss real-device test (2026-09-07) follow-up: inner padding reversed; originally"),
    ("Boss real-device test (2026-09-07) follow-up: 图一向图二修改, 包",
     "Boss real-device test (2026-09-07) follow-up: image-1 → image-2 edits, includes"),
    # Q1-Q8 boss拍 subjects (boss拍 = boss ratification; = 保留 OOB keyword)
    ("Q5 boss拍 = rename State/Workspace* symbols to LayoutTree*. Slice 2",
     "Q5 boss ratification: rename State/Workspace* symbols to LayoutTree*. Slice 2"),
    ("Q5 boss拍 = rename State/Workspace* symbols to LayoutTree* per",
     "Q5 boss ratification: rename State/Workspace* symbols to LayoutTree* per"),
    ("Q6 boss拍 refresh ComponentIndex.md to surface the 9 single-file",
     "Q6 boss ratification: refresh ComponentIndex.md to surface the 9 single-file"),
    ("Q2 boss拍 split WorkspaceView. Slice 9 bundles the last 2",
     "Q2 boss ratification: split WorkspaceView. Slice 9 bundles the last 2"),
    ("Q2 boss拍 split WorkspaceView. After slice 7 (= EditorPreview",
     "Q2 boss ratification: split WorkspaceView. After slice 7 (= EditorPreview"),
    ("Q2 boss拍 split WorkspaceView. After slice 6 (= EditorExpandShrink",
     "Q2 boss ratification: split WorkspaceView. After slice 6 (= EditorExpandShrink"),
    ("Q2 boss拍 split WorkspaceView. After slice 5 (= PreviewSortMenuButton".replace("拍", "ratification"),
     "Q2 boss ratification: split WorkspaceView. After slice 5 (= PreviewSortMenuButton"),
    ("Q2 boss拍 split WorkspaceView. After slice 4 (= EditModeBadge".replace("拍", "ratification"),
     "Q2 boss ratification: split WorkspaceView. After slice 4 (= EditModeBadge"),
    ("Q2 boss拍 split WorkspaceView. After slice 3 (= ParagraphAIToolbarButtons".replace("拍", "ratification"),
     "Q2 boss ratification: split WorkspaceView. After slice 3 (= ParagraphAIToolbarButtons"),
    ("Q2 boss拍 split WorkspaceView. After slice 2 (= FormatToolbarButtons".replace("拍", "ratification"),
     "Q2 boss ratification: split WorkspaceView. After slice 2 (= FormatToolbarButtons"),
    ("Q2 boss拍 split WorkspaceView. Slice 1 = delegate".replace("拍", "ratification"),
     "Q2 boss ratification: split WorkspaceView. Slice 1 = delegate"),
    ("Q8 boss拍 YES batch 1 = top-5 highest-frequency Tier-2 sites from",
     "Q8 boss ratification YES batch 1 = top-5 highest-frequency Tier-2 sites from"),
    ("Q4 boss拍 incremental reconciliation of WenshuLibrary / BookStore",
     "Q4 boss ratification: incremental reconciliation of WenshuLibrary / BookStore"),
    ("Q3 boss拍 surgical separation of editor state responsibilities. The",
     "Q3 boss ratification: surgical separation of editor state responsibilities. The"),
    ("Q2 boss拍 split WorkspaceView. First slice = remove the".replace("拍", "ratification"),
     "Q2 boss ratification: split WorkspaceView. First slice = remove the"),
    ("Q1 boss拍 split App.swift. After slice 1 (= WenshuAppDelegate),".replace("拍", "ratification"),
     "Q1 boss ratification: split App.swift. After slice 1 (= WenshuAppDelegate),"),
    # Other narrative fragments
    ("Pre-existing fix follow-up (= 老板 cadence 1 = fix pre-existing tests).",
     "Pre-existing fix follow-up (= boss cadence 1 = fix pre-existing tests)."),
    ("git grep: regionSelectionBackground\\|RegionSelectionBackgroundStyle()' Sources/ Tests/ = 0 外部调用方",
     "git grep: regionSelectionBackground\\|RegionSelectionBackgroundStyle()' Sources/ Tests/ = 0 external callers"),
]


def transform(msg: str) -> str:
    """Apply translation table to a commit message.

    Strategy:
    1. Preserve the SUBJECT (= first line) unchanged (= git subjects are
       not translated by this script; = only body is rewritten).
    2. For all subsequent lines (= subject continuation lines + body),
       apply the translation table (= 28 narrative CJK lines per audit).

    This handles both cases:
    - Subject on one line + body separated by blank line (common case)
    - Subject spanning multiple lines (= continuation lines treated as body)
    """
    if not msg:
        return msg
    lines = msg.split("\n")
    # Subject = first line; everything else = subject continuation + body
    out_lines = [lines[0]]  # subject untouched
    for line in lines[1:]:
        out_line = line
        for src, dst in TRANSLATIONS:
            if src in out_line:
                out_line = out_line.replace(src, dst)
        out_lines.append(out_line)
    return "\n".join(out_lines)


def main() -> None:
    msg = sys.stdin.read()
    sys.stdout.write(transform(msg))


if __name__ == "__main__":
    main()
