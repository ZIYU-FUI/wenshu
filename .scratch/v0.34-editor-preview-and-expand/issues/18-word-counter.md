# 18: B-18 wire WordCounter to chrome bottom-bar left

## Boss OOB context

Boss 2026-09-02: '现在用的, 这个编辑器, 是否自带字数统计'. Apple SwiftUI TextEditor has NO built-in word count. wenshu's WordCounter (= v0.19) was already implemented but not wired.

## What to build

1. AppState.editorWordCount (= new property)
2. EditorPlaceholder @Environment + delegates via onWordCountChange
3. EditorEditContent .onChange → WordCounter.count(draft).charactersNoSpaces
4. TabContentDispatcher chrome left reads AppState.editorWordCount

## Blocked by

None.

## Status

ready-for-agent (= implemented; visual verified)
