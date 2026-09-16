# Ticket 002 — sidebar folder ICON Lucide → SF Symbols 6

Status: done (commit `7c3502b3a`)

## What

Replace the 5 Lucide kebab-case icon names in `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:1158-1166` `standardFolderNames` with verified SF Symbols 6 dot.case names.

## Why

`v1.0.0-m1-shell boss 2026-09-15 OOB 'remove Lucide, use SF Symbols 6'` removed the third-party `bring-shrubbery/lucide-swift` dependency and replaced most `LucideIcon(...)` callsites with `Image(systemName: ...)`. The `standardFolderNames` tuple literal was missed because it bypasses the per-entity fallback helpers (`lucideFallbackForBookIcon` in `Book.swift:192` and `lucideFallbackForShelfIcon` in `Bookshelf.swift:106`).

Result: SwiftUI's `Image(systemName: "user-round")` etc. cannot resolve the Lucide kebab-case name to any Apple SF Symbol and falls back to a placeholder rectangle glyph.

## Mapping

| folder | Lucide (kebab-case, NOT valid SF Symbols 6) | SF Symbols 6 (verified via sfsymbols) |
|---|---|---|
| worldview | `globe` | `globe` (already correct = same name in both) |
| characters | `user-round` | `person` |
| outlines | `list-tree` | `list.bullet.rectangle` |
| chapters | `book-text` | `text.book.closed` |
| drafts | `file-pen-line` | `pencil` |

Verified via `/Applications/SF Symbols Beta.app/Contents/Executables/sfsymbols search <name>` 2026-09-16.

## How

Diff is limited to L1158-L1166 of `NewLibraryOutlineView.swift`. The 5-tuple literal `standardFolderNames` is consumed at L1096 (`Image(systemName: folder.icon)`); no other call sites need migration because the folder row renders via this single label.

## Verification

- `swift build` = exit 0
- live screenshot from the session shows the 5 folder rows rendering real SF Symbols 6 glyphs
- `grep -rn 'systemName:.*\(user-round\|list-tree\|book-text\|file-pen-line\)' Sources/` = 0 hits post-fix (excluding the dead `PreviewPane.swift:107-114` site which is a follow-on)