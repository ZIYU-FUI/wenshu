# 003 — WenshuConductor.invokeTool allowlist

> Parent spec: `.scratch/2026-08-23-agent-safety-guardrails/spec.md`.
> Depends on: 001 + 002.
> 1 commit. Modifies WenshuConductor.

## What to build

`invokeTool(name:input:)` adds a tool-level allowlist (in addition to path guards from 001):

| Tool name | Allowed ops |
|---|---|
| `file` | `read`, `list`, `search` (NOT `write`, `patch`) |
| `process` | NONE (boss 8/23: deny all) |
| `web` | `extract` (read-only HTTP GET) |
| `vision` | `recognizeText` (image OCR, read-only) |
| `av` | `speak` (text-to-speech, user-triggered) |

`input` parsing extracts the op from a string format like `"read:/path/to/file"` or `"write:/path"`. For now (MVP), single-op string format.

## Implementation outline

```swift
public func invokeTool(name: String, input: String) async -> String {
    // Split input into op + arg: "read:./Sources/foo.swift" or "extract:https://..."
    let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    let op = parts.first.map(String.init) ?? ""
    let arg = parts.count > 1 ? String(parts[1]) : ""
    
    switch name {
    case "file":
        guard ["read", "list", "search"].contains(op) else {
            return "(tool blocked: file.\(op) is in deny-list — boss 8/23 拍)"
        }
        // delegate to FileTools
    case "process":
        return "(tool blocked: process is deny-all — boss 8/23 拍)"
    case "web":
        // delegate to WebTools.extract
    ...
    }
}
```

## Acceptance criteria

- [ ] `invokeTool(name: "file", input: "read:./legit.txt")` succeeds
- [ ] `invokeTool(name: "file", input: "write:./Sources/foo.swift")` returns blocked message
- [ ] `invokeTool(name: "process", input: "ls")` returns blocked message
- [ ] `invokeTool(name: "web", input: "extract:https://example.com")` still works
- [ ] swift build + tests pass