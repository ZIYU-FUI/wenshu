# v0.34 Thumbnail Generation Revert Note

## TL;DR

Boss 2026-09-04 OOB rollback: the AI thumbnail + readiness check work from
v0.34 Issue 02 + Issue 05 (= port of the card-master `image-generation-protocol.ts`
investigation) was deemed too visually intrusive for the current visual baseline
(= red-boxed banner + always-placeholder card cover when no API key configured).
Reverted via 2 clean git reverts. Code is fully preserved in git history for
future re-implementation.

## Reverts

| Commit  | What |
|---|---|
| 62e0abf73 | Revert "feat(wenshu): v0.34 -- startup readiness check (Issue 05)" |
| b4e54fb4f | Revert "feat(wenshu): v0.34 -- AI thumbnail generation (Issue 02)" |

## Source commits (preserved in git history)

| Commit  | What |
|---|---|
| 60f3b92ee | feat(wenshu): v0.34 -- startup readiness check (Issue 05) |
| 9c3a317aa | feat(wenshu): v0.34 -- AI thumbnail generation (Issue 02) |

## Files affected (post-revert)

Deleted (= 6 files):

- Sources/WenshuApp/AI/ImageGen/ImageGenProtocol.swift
- Sources/WenshuApp/AI/ImageGen/ImageGenService.swift
- Sources/WenshuApp/AI/ImageGen/DashScopeImageGenAdapter.swift
- Sources/WenshuApp/AI/ImageGen/OpenAIImageGenAdapter.swift
- Sources/WenshuApp/AI/WenshuReadinessCheck.swift
- Sources/WenshuApp/AI/ReadinessBanner.swift

Reverted (= 4 files, 791 deletions net):

- Sources/WenshuApp/Domain/Reference.swift
  (= drop `coverImageStatus` Codable field; reverts to 4-state model)
- Sources/WenshuApp/Domain/EntityIngestion.swift
  (= drop `imageGenService` field + thumbnail `Task.detached` + `referenceWithStatus` helper)
- Sources/WenshuApp/Storage/CacheManager.swift
  (= drop `writeThumbnail` + thumbnail cache paths)
- Sources/WenshuApp/App.swift
  (= drop `.safeAreaInset` readiness banner + `.task` readiness call)

## Conflict resolution

The 2nd revert (= `9c3a317aa`) hit a content conflict on
`Sources/WenshuApp/Domain/EntityIngestion.swift` because a later
unrelated commit (= v0.34 Issue 04 `WikiEntityPreflight`) modified the
same lines. Resolution: kept the preflight block (= Issue 04 = unrelated
to thumbnail), dropped the thumbnail block. Net result: `EntityIngestion.ingest`
now runs preflight then saves synchronously, with no fire-and-forget thumbnail.

## How to restore (= when boss reopens the feature)

Method A (= cleanest, single revert of these 2 reverts):

    git revert b4e54fb4f 62e0abf73

Method B (= fresh cherry-pick, useful if the source commits have bit-rotted
against newer main):

    git cherry-pick 9c3a317aa 60f3b92ee

## Build verification

    bash Scripts/build-app.sh
    # => exit 0, "Build complete! (85.93秒)"

The 2 warnings shown in the build log are pre-existing in
`NewLibraryOutlineView.swift` (= "case will never be executed" on
`.referenceCategory, .referenceLibraryRoot` switch cases; unrelated to
this revert).

## Future ticket scaffold (= when boss reopens)

Recommended next-ticket scope (= to avoid the same visual regression):

1. Re-introduce the 4 ImageGen files + 2 Readiness files via cherry-pick.
2. Re-implement readiness banner ONLY behind an explicit Settings toggle
   (= "Show AI configuration warnings at launch" = default OFF).
3. Defer card-cover auto-generation to explicit user action
   (= right-click "Generate cover image" = no fire-and-forget at ingest).
4. Keep `<.ws>/cache/thumbnails/` size cap strict (= 30 KB / image, JPEG q=0.7).
