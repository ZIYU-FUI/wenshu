# 03 — entity cards now have thumbnails

**What to build:**

Boss 2026-08-30 OOB '卡片要用我们引入的缩略图的库，加缩略图' = cards
need a thumbnail (= image or icon-based fallback). Pre-fix: cards were
text-only (= title + summary, no visual anchor).

Fix: add 100 PT gradient + 64 PT type icon overlay at top of each card.
Since entities are text-only (= .md bodies with no associated images), use
the EntityType icon (= Lucide icon) as the thumbnail. v0.31+ when entities
get real images, swap to NukeUI's LazyImage.

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `e29ea8459`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### File: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`

- `EntityCard` body extended:
  ```swift
  VStack(spacing: 0) {
      // Thumbnail header
      ZStack {
          LinearGradient(
              colors: [typeColor.opacity(0.6), typeColor.opacity(0.3)],
              startPoint: .topLeading, endPoint: .bottomTrailing
          )
          LucideIcon(entity.entityType.icon, size: 64)
              .foregroundStyle(.white.opacity(0.9))
      }
      .frame(height: 100)
      .clipShape(UnevenRoundedRectangle(corners: [.topLeft, .topRight]))

      // Metadata strip (= [type] + category chip)
      HStack {
          Text("[\(entity.entityType.displayName)]")
              .font(.caption)
              .foregroundStyle(.tint)
          Spacer()
          if let cat = entity.category {
              Text(cat.displayName)
                  .font(.caption)
                  .padding(.horizontal, 8).padding(.vertical, 2)
                  .background(Color.secondary.opacity(0.1))
                  .clipShape(Capsule())
          }
      }
      .padding(.horizontal, 12).padding(.vertical, 8)

      // Title + summary
      Text(entity.title).font(.headline).fontWeight(.semibold)
      if !entity.summary.isEmpty {
          Text(entity.summary).font(.caption).foregroundStyle(.secondary)
      }
  }
  .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
  ```

## Acceptance

- [x] Each card has a thumbnail (= 100 PT gradient + 64 PT type icon)
- [x] Type icon = Lucide (= matches sidebar icon family)
- [x] Gradient uses type's distinguishing color
- [x] Title + summary below thumbnail (= readable)
- [x] Build exit 0
- [x] Screenshot verified: 4 cards each with icon + gradient header

## Out-of-scope

- Real images (= NukeUI LazyImage swap) — deferred to v0.31+ when entities
  get real images (e.g. character portraits, location maps)
