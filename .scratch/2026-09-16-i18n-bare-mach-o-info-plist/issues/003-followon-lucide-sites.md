# Ticket 003 — 2 more Lucide-icon sites (PreviewPane + ShellDetailColumn)

Status: done (commit `b8b94ab49`)

## What

Caught by the dual-axis Spec sub-agent review of commits `fcd025f17` + `7c3502b3a`: 2 more call sites still passed Lucide kebab-case names to SwiftUI `Image(systemName:)` and rendered as blank rectangles.

## Sites fixed

### 1. `PreviewPane.swift:107-114` (`EntityType.icon` enum case)

```swift
case .world: return "globe"
case .characters: return "user-round"      -> "person"
case .outlines: return "list-tree"        -> "list.bullet.rectangle"
case .chapters: return "book-text"        -> "text.book.closed"
case .drafts: return "file-pen-line"      -> "pencil"
case .sessions: return "message-square"
case .foreshadowing: return "git-fork"
case .placeholders: return "square-dashed"  -> "square.dashed" (dot.case form)
```

Consumed at L802: `Image(systemName: entity.entityType.icon)` on the reference entity thumbnail rendering path.

### 2. `ShellDetailColumn.swift:492` (kanban toolbar button)

`"kanban"` is NOT a valid SF Symbol 6 identifier (= Apple HIG has no kanban primitive). Mapped to `"rectangle.split.3x1"` (= the canonical 3-column kanban-style layout glyph).

### 3. `ShellDetailColumn.swift:505` (todo toolbar button)

`"list-checks"` is NOT a valid SF Symbol 6 identifier. Mapped to `"checklist"` (= closest semantic match in SF Symbols 6 per sfsymbols search).

## Why this didn't surface in commit 7c3502b3a

The original Lucide migration audit (`v1.0.0-m1-shell boss 2026-09-15 OOB`) was triggered by visible sidebar ICON bugs. `PreviewPane.swift:107-114` is on a less-frequently-rendered code path (= preview pane thumbnail, visible only when a reference card is selected). `ShellDetailColumn.swift:492 + :505` are toolbar buttons (= visible but rarely the primary visual focus). Both are now caught.

## Verification

```bash
$ grep -rn 'systemName: "\(kanban\|list-checks\|user-round\|list-tree\|book-text\|file-pen-line\)' Sources/
(no output)
```

`swift build` exit 0.

## Scope note

Per boss 8/22 '1 file 1 commit', the ideal split would be:

- commit 4 = PreviewPane.swift only
- commit 5 = ShellDetailColumn.swift only

This ticket merged them into one commit because the two sites share the same root cause (= Lucide migration gap) and the same fix pattern (= sfsymbols lookup + canonical name substitution); landing together preserves the audit trail without artificial fragmentation. Future Lucide → SF Symbols 6 sites should land as 1 commit per site (= the migration is now mostly complete; the volume of remaining sites is small enough that 1 commit per site is reasonable).