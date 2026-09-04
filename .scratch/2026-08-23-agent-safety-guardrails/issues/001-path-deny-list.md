# 001 — Path deny-list helper + FileTools guard

> Parent spec: `.scratch/2026-08-23-agent-safety-guardrails/spec.md`.
> 1 commit. Modifies FileTools + adds test.

## What to build

Add `pathDenied(_ path: String) -> Bool` helper that returns true if path is in deny-list. Use it in `write` and `patch` methods to throw `FileToolError.pathDenied`.

## Deny-list

- `Sources/`
- `Tests/`
- `Package.swift`
- `.scratch/`
- `Tools/wenshu-devtool/`
- `~/.wenshu/` (legacy)
- `~/.hermes/`
- `/etc/`, `/System/`, `/usr/`
- Shell init files (`.zshrc`, `.bashrc`, `.profile`)

## Implementation outline

```swift
public func pathDenied(_ path: String) -> Bool {
    let std = (path as NSString).standardizingPath
    let denyPrefixes = [
        "Sources/", "Tests/", "Package.swift", ".scratch/",
        "Tools/wenshu-devtool/", "/.wenshu/", "/.hermes/",
        "/etc/", "/System/", "/usr/",
    ]
    let denySuffixes = [".zshrc", ".bashrc", ".profile"]
    for prefix in denyPrefixes where std.contains(prefix) { return true }
    for suffix in denySuffixes where std.hasSuffix(suffix) { return true }
    return false
}
```

Guard write / patch:

```swift
public func write(path: String, content: String) throws {
    if pathDenied(path) { throw FileToolError.pathDenied(path: path) }
    // ... existing implementation
}
```

## Acceptance criteria

- [ ] `pathDenied("/Users/x/Sources/foo.swift")` returns true
- [ ] `pathDenied("/tmp/legit.txt")` returns false
- [ ] `pathDenied("/Users/x/.zshrc")` returns true
- [ ] `FileTools.write(path: "/Users/x/Sources/foo.swift", content: "...")` throws pathDenied
- [ ] `FileTools.write(path: "/tmp/legit.txt", content: "...")` succeeds
- [ ] swift build + tests pass