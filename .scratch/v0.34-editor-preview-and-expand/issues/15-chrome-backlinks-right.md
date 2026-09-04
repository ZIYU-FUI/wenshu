# 15: B-15 chrome bottom right = backlinks count

## Boss OOB context

Boss 2026-09-02 (= visual verification post B-14 revert): chrome bottom
status for editor zone (= "字数: 0 / 0%" right field) replaced with
backlinks count. Boss 9/2 OOB clarification: "替换就是右边 (0%) 替换成反链统计;
左边是字数 0, 这个未来要实现真的字数统计".

## What to build

Replace `editorChrome(wordCount:progress:)` with
`editorChrome(wordCount:backlinkCount:)` and right field = "反链 N".
The progress parameter was never wired (= dead code, removed).

TabContentDispatcher holds @State backlinksVM + @State backlinksCount.
On editor zone mount, .task loads backlinks for docId "preview-sample".

## Blocked by

None (= B-14 revert + B-15 follow-up).

## Status

ready-for-agent (= implemented; macOS visual verified)

## Acceptance criteria

- [x] editorChrome(wordCount: Int, backlinkCount: Int)
- [x] chrome bottom right = "反链 \(backlinkCount)"
- [x] chrome bottom left = "字数: \(wordCount)" (unchanged)
- [x] TabContentDispatcher @State backlinksVM + @State backlinksCount
- [x] .task loads backlinks on editor zone mount
- [x] swift build exit 0
- [x] macOS visual verify: editor zone chrome shows "字数: 0 / 反链 0"

## Iron rules applied

- Rule 6: no magic numbers
- Rule 11: @State reactive
- wenshu-apple-api-first: Apple HIG status-bar pattern
- Boss 9/2 'git grep BEFORE patch' rule: applied

## Double-axis review

- [ ] Standards axis: English-only body, 0 forbidden vocab
- [ ] Spec axis: chrome bottom right = backlinks count, left = word count
