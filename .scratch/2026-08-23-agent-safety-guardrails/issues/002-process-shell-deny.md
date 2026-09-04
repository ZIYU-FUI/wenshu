# 002 — ProcessTools.runShell guard (deny all chat-triggered shell)

> Parent spec: `.scratch/2026-08-23-agent-safety-guardrails/spec.md`.
> Depends on: 001.
> 1 commit. Modifies ProcessTools.

## What to build

Block `runShell` from invokeTool path entirely (boss 8/23: 用户不可通过聊天改系统).

Trade-off: any legitimate shell use (e.g. counting files) loses. Mitigation: allow only read-only commands via a separate `runReadOnlyShell` API.

## Implementation outline

```swift
public func runShell(_ command: String, workingDirectory: String? = nil) throws -> ProcessResult {
    throw ProcessToolError.chatShellDenied(command: command)
}
```

Replace existing implementation with the throw. The CLI / devtool bypass route (if needed in future) can use a different API (`runShellViaCLI`).

## Acceptance criteria

- [ ] `ProcessTools.runShell("ls")` throws chatShellDenied
- [ ] `ProcessTools.run(executable: "/bin/ls", arguments: [])` — same treatment
- [ ] swift build + tests pass