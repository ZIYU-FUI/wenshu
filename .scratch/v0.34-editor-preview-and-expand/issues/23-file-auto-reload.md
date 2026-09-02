# 23: B-23 editor zone auto-reload on external file changes (= DispatchSource)

## Boss OOB context

Boss 2026-09-02 OOB (= `既然是文件会自动刷新。那就不用接 llm, 自动刷新展示即可`). When the agent (= or any external process: git pull, another app, terminal `echo > file.md`) writes to the open document, wenshu's editor should automatically reload and display the new content (= like Apple TextEdit / Pages / Xcode).

## What to build

Wire `DispatchSource.makeFileSystemObjectSource` (= Apple HIG file-watcher pattern) on `documentPath` to detect external writes. When triggered:

  - If `draft == originalBody` (= user is NOT editing = clean state):
    - Silently reload the file content into `draft` AND `originalBody`.
    - No notification (= clean state = user has nothing to lose).
  - If `draft != originalBody` (= user IS editing = dirty state):
    - Save current `draft` to `<doc>.local-wenshu-conflict-<unix-timestamp>.md`
      (= save the user's in-progress edits before clobbering).
    - Reload the file into `draft` AND `originalBody`.
    - Post a notification (.notification-center local toast or in-chrome
      inline alert) "文件已更新, 你的编辑已保存到 <file>.local-wenshu-conflict-..."

## Architecture

- File watcher state owned by `EditorPlaceholder` (= view-local; tied to
  the current documentPath). When documentPath changes (= user opens
  a different doc), tear down the old watcher and start a new one.
- DispatchSource on the FILE DESCRIPTOR (not the path; = survives renames
  = Apple HIG canonical pattern).
- Watch flag: `.write | .extend | .delete | .rename` (= cover all
  filesystem events that could change the file's content).
- Cleanup in `onDisappear` + when documentPath changes.

## Blocked by

None (= uses standard Apple Foundation API; = no third-party deps).

## Status

ready-for-agent

## Acceptance criteria

- [ ] EditorPlaceholder has a DispatchSource watcher on documentPath
- [ ] On .write event: reload file content
- [ ] On dirty state during reload: save to `.local-wenshu-conflict-...` first
- [ ] On clean state: silent reload, no notification
- [ ] On dirty state: post notification "文件已更新..."
- [ ] Watcher torn down on documentPath change + onDisappear
- [ ] Build exit 0
- [ ] macOS visual verify: edit file via terminal, see editor auto-update

## Iron rules applied

- Rule 8: stays inside WindowGroup scene tree (= DispatchSource = Foundation API; no new NSWindow)
- Rule 11: @State for watcher handle (= reactive on documentPath change; auto-cancels on disappear)
- wenshu-apple-api-first: DispatchSource = Apple standard file-watcher
- AGENTS.md hard rule: English-only commit body; 0 forbidden vocab

## Double-axis review

- [ ] Standards axis: AGENTS.md hard rules + 11 iron rules + ComponentIndex consistency
- [ ] Spec axis: Apple TextEdit / Pages auto-reload behavior matches
