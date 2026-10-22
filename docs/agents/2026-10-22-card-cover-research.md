# Card Cover Generation — Reference Audit and Wenshu Replication Plan

Research date: 2026-10-22
Reference: `LYiHub/Card-master-browser-extension-public` (commit as cloned 2026-10-22)
Target: `/Volumes/ANAN/Engineering/wenshu` (branch `main`, clean at `e89362efe`)

---

## 1. Reference implementation: what Card Master actually does

### 1.1 Headline findings

| Question | Answer | Evidence |
| --- | --- | --- |
| AI cover generation? | Yes. OpenAI Images protocol + Alibaba DashScope | `src/ai/infrastructure/openai-images-adapter.ts`, `dashscope-images-adapter.ts` |
| AI video cover generation? | **No.** Zero hits for `video_generation`/`hailuo`/`t2v`/`i2v`/`sora`/`veo`/`kling`/`runway` (all matches were false positives on `refreshes`/`referenced`/`axis`/`sponsor`) | Dynamic covers are **user-uploaded video files**, never generated |
| Regenerate / refresh button? | **No.** Two buttons only: upload a file, or generate from a hand-typed prompt | `src/features/userscript-deck/ManageBoard.tsx:531-577` |
| Hover makes it dynamic? | Yes, but only in the Global Library deck, not in the material grid | `GlobalLibraryWorkbench.tsx:319` |

**Three of the four requested capabilities do not exist in the reference.** The dynamic-generation path has no upstream implementation to copy; it must be built against the MiniMax video API directly.

### 1.2 Image generation pipeline

```
LLM tool `generate_userscript_cover`
  params: target_script_id / expected_revision / visual_concept (English only)
  assistant-tools.ts:583-599
       |
       v
assistant-service.ts:588-624  generateUserscriptCover()
  - revision check first (rejects if script source changed)
       |
       v
ai-services.ts:133-141  generateCardCover(visualConcept)
       |
       v
image-card-cover.ts:103-182  ImageCardCoverGenerator.generate()
  - buildCardCoverPrompt()      prepends the house art direction
  - POST {baseUrl}/images/generations
      body = { model, prompt, n:1, size:"720x960", quality:"low", output_format:"webp" }
  - response: b64_json OR url (url must pass isSecureServiceUrl)
  - optimizeUserscriptCoverImage()
       |
       v
card-cover.ts:121-141  crop -> WebP -> accent colour
  - userscriptCoverCropRect()  centre-crop to strict 3:4 (480x640)
  - canvas.convertToBlob({type:'image/webp', quality:0.82})
  - deriveCardAccentFromImageSource()
       |
       v
script.presentation = { accent, media:{kind:'image', image:dataUrl} }
  -> chrome.storage.local, key 'card-master.library.v1'
```

### 1.3 Constants (verified in source)

| Constant | Value | Location |
| --- | --- | --- |
| Cover dimensions | 480 x 640 (strict 3:4) | `card-cover.ts:9-10` |
| Generation request size | `720x960` | `image-card-cover.ts:18` |
| Generation quality | `low` | `image-card-cover.ts:74` |
| Output format | `webp` | `image-card-cover.ts:75` |
| WebP encode quality | 0.82 | `card-cover.ts:101` |
| Prompt length cap | 2000 chars | `card-cover.ts:11` |
| Image dataUrl cap | 2 MB | `types.ts:72` |
| Video dataUrl cap | 28 MB | `types.ts:73` |
| Upload file cap | 20 MB | `card-cover.ts:12` |
| OpenAI protocol default model | `gpt-image-2` | `image-generation.ts:1` |
| DashScope default model | `qwen-image-3.0` | `dashscope-images-adapter.ts:44` |
| Default base URLs | `https://api.openai.com/v1` / `https://dashscope.aliyuncs.com` | adapters |

### 1.4 Art direction prompt (the transferable part)

`card-art-direction.ts:1-10` — one house style for every cover. The style name in the
source is bilingual; only the English half is reproduced here:

```
Bright Whimsical Hand-Painted Fantasy Trading-Card Key Art
Create original bright whimsical hand-painted fantasy trading-card key art with
playful tavern-card-game energy; never imitate an existing franchise, character,
card frame, logo or official illustration.
Use broad painterly brushwork, saturated warm color masses, rich midtones,
tactile painted materials, lively fantasy worldbuilding and a confident
illustrative finish.
```

Design rule: the LLM describes **what** to draw (`visual_concept`, forced ASCII by
`image-card-cover.ts:55-57`); the house style is injected server-side. Manual
prompts may opt out of style injection.

### 1.5 Dynamic cover mechanics

`prepareUserscriptCoverMedia()` (`card-cover.ts:175-204`) on an uploaded video:
1. offscreen `<video>` element extracts the first frame -> same crop/WebP/accent path -> `poster`
2. the video bytes become a data URL -> `video`

Media shape (`types.ts:106-120`):

```ts
media: { kind: 'image', image: dataUrl }
 | { kind: 'video', video: dataUrl, poster: dataUrl }
```

Playback chain (`GlobalLibraryWorkbench.tsx:319`):

```tsx
<CardFace
  playing={visible && (selected || hovered || focused)}   // hover drives playback
  loadMedia={visible}                                       // offscreen cards do not load
  preloadFrame
/>
```

`ManagerCardFace.tsx:229-243` renders
`<video poster={posterImageUrl} muted loop playsInline preload={loadMedia ? 'auto' : 'none'}>`.
`shouldPlay` (`ManagerCardFace.tsx:83-89`) ANDs six conditions: media kind, `loadMedia`,
`enabled`, `lockPhase == 'unlocked'`, `playing`, `pageVisible`.

**This is the model for "static by default, dynamic on hover": the poster image is the
resting state; the video element is only mounted when playback conditions are met.**

### 1.6 Accent derivation (optional)

`card-accent.ts:127-222`: 48x64 downsample -> RGB to Oklab -> bucket by (hue 24 bins,
lightness 5 bins, chroma 4 bins) -> per-pixel weight = alpha x lightness x chroma x
edge -> pick the top-scoring bucket -> normalise L to [0.67,0.77], C to [0.085,0.18] ->
sRGB hex. Used for the card border / glow (`useCardAccent.ts`, `ManagerCardInteraction.tsx:328`).

### 1.7 Storage and settings

- Cover lives on the script record: `script.presentation`, persisted to
  `chrome.storage.local` under `card-master.library.v1`
  (`src/userscript/application/storage-keys.ts:1`, `script-repository.ts:164-170`).
- AI service config: `card-master.ai-services.v1` in `storage.local`
  (`ai-services-config.ts:20`), fields = credentialSource (model-service | independent),
  protocol, baseUrl, model, apiKey (`ai/domain/types.ts:47-56`).
- WebDAV sync carries the library through `SyncProjection`
  (`src/sync/projection.ts:79-83` -> `repository.list()`), so covers travel with the library.

---

## 2. Wenshu target state (verified)

### 2.1 Card rendering

`Sources/WenshuApp/Features/Editor/View/PreviewPaneCard.swift:190-212` — the current thumbnail:

```swift
ZStack {
    LinearGradient(colors: [.accentColor.opacity(DesignTokens.accentTintOpacityHero),
                             Color(nsColor: .quaternaryLabelColor)], ...)
    Image(systemName: source.iconName)
        .resizable().aspectRatio(contentMode: .fit)
        .frame(width: 64, height: 64)
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(.tint.opacity(0.85))
}
.frame(height: DesignTokens.panelMinHeight)   // 100 PT
.clipShape(UnevenRoundedRectangle(...))
```

Line 32 of the same file already anticipates the change: *"when entities get real
images, NukeUI's LazyImage will replace the type icon"*.

Hover state already exists: `@State private var isHovered` (`:135`) + `.onHover { isHovered = $0 }` (`:327`).

### 2.2 Data model — both card sources are value types

| Type | Location | Nature |
| --- | --- | --- |
| `CardSource` | `PreviewPaneCard.swift:55-107` | enum: `.reference(Reference)` / `.bookDoc(BookDoc)` |
| `Reference` | `Features/Library/Model/Reference.swift:85` | plain `struct`, Codable/Hashable/Sendable — **not** a SwiftData model. `CodingKeys` are fixed at `:161-166`; `init(from:)` `:168`, `encode(to:)` `:204`, memberwise `init` `:244` |
| `BookDoc` | `Features/Editor/View/PreviewPaneModels.swift:174` | plain `struct`, **reconstructed from disk on every grid load** (`PreviewPaneOps.swift:84-171`); id = UUID v5 over bookId+folderName+fileName |

Neither can carry a cover path today. `BookDoc` in particular cannot hold stored state
at all — it is rebuilt by a filesystem scan, so a cover reference must be derived from
the path (a filename convention) or read from a sidecar.

### 2.3 Where persistence lives

The data layer is the local SPM package `Sources/WenshuData/` (ADR-0016). There is no
`Sources/WenshuApp/Persistence/` directory.

23 model files in `Sources/WenshuData/Sources/WenshuData/`. The relevant one:

```swift
@Model
public final class WSAttachment {          // WSAttachment.swift:24-44
    @Attribute(.unique) public var id: String
    public var parentKind: String          // polymorphic discriminator
    public var parentID: String
    public var filename: String
    public var mimeType: String
    public var sizeBytes: Int
    public var data: Data?                 // inline blob
    public var externalPath: String?        // filesystem path
    public var createdAt: Date
}
```

`data` and `externalPath` are mutually exclusive. `WSAttachment` already has the exact
shape a cover record needs (polymorphic owner + inline-or-external payload), though it
was designed for chat attachments.

`WSReference` (`WSReference.swift:18-47`) is the SwiftData twin of the `Reference` struct;
bridging lives in `FileSystemReferenceStore.makeRow` (`:358`) and `toReference` (`:381`).

**Store location: the SwiftData store lives inside the `.ws` warehouse**, not in
Application Support — `makeContainerForWarehouse` (`Container.swift:270-273`) puts it at
`<.ws>/WenshuStore.store`, confirmed on disk at
`~/Documents/anbaiqiang.ws/WenshuStore.store`. So cover metadata and cover binaries
both belong to the library and travel with it.

### 2.4 Migration posture — additive is free

`Container.swift:120-127` states the policy explicitly:

> *"Implicit lightweight init: SwiftData handles additive schema changes (= new optional
> properties, new @Model classes, new optional relationships) without any
> `SchemaMigrationPlan`. The current V1/V2 schema pair holds the same 29 @Model class
> set (= additive placeholder; = no real schema delta yet), so a plan would only produce
> duplicate-version checksums."*

`ModelsSchemaV1.models` (`ModelsSchema.swift:45-86`) is the versioned snapshot; a new
`@Model` class means appending to that array. **No `SchemaMigrationPlan` is required
for a new model class or a new optional field.** A plan only becomes necessary for a
rename, a type change, or a cardinality flip.

### 2.5 On-disk library layout

```
<wsRoot>/
  Info.plist                        CFBundlePackageType = "WSPC"
  WenshuStore.store                 SwiftData store (in-warehouse)
  shelves/<shelf>/books/<book>/
      world/ characters/ outlines/ chapters/
      drafts/ ideas/ sessions/ foreshadowing/ placeholders/
  reference-library/{raw,entities,abstracts,indexes}/
  references/<uuid>.md              single-file truth location for a reference
  cache/chat-uploads/               existing binary-on-disk convention
  assets/                           exists, currently unused
  backups/
```

Book folder names come from `BookFolderCatalog` (`BookFolderCatalog.swift:115`, 9 folders;
`allBookFolders` at `:307`).

### 2.6 Capability gaps

| Need | Status | Evidence |
| --- | --- | --- |
| Cover binary storage | Ready | `<.ws>/assets/` exists and is unused (`LibraryRootView.swift:361`); `cache/chat-uploads/` is the existing binary convention (`LiveChatRepository.swift:145-164`) |
| Cover metadata | Available | `WSAttachment` polymorphic owner + `data`/`externalPath` split (`WSAttachment.swift:24-44`) |
| Atomic binary write | Exists | `BookChapterFileSystem.atomicWrite(_:to:)` (`BookChapterFileSystem.swift:137-149`) — tmp + move + `fsync`. Duplicated in 4 other files |
| Image loading | Absent | NukeUI = 0 hits repo-wide (only named in a comment). `ChatMessageAttachmentPreview.swift:63-75` uses `NSImage(contentsOfFile:)` + `Image(nsImage:)` |
| Video playback | Absent | AVKit = 0 hits. Only `AVFoundation` for TTS (`AVMediaTools.swift:8-11`) |
| Settings pane | Exists | `SettingsPane` (`SettingView.swift:40-64`); adding a case touches 3 switch sites, `paneForRaw` (`:201`) needs no edit |
| LLM tool registration | Exists | `ToolRegistry.shared.registerTool(...)` + `ToolRegistrySchema` (`ToolSchema.swift:66-104`). **A new tool must also be added to `ToolCatalogue.all` (`ToolCatalogue.swift:50-80`) or it is never exposed to the model** |
| Provider key | Exists | `ConnectorCredentials.resolve(for:)` (`ConnectorCredentials.swift:52`) -> `ProviderKeychain.loadKeySync(for:)` (`ProviderKeychain.swift:517`) |
| Non-LLM provider HTTP | Exists | `ProviderFetcher.fetchLiveModelIds` (`ProviderFetcher.swift:26-57`) — URLSession + header switch on `provider.authHeader` + JSON parse |
| Image/video generation code | Absent | grep `image_generation\|dalle\|stable-diffusion\|video_generation\|image-01\|text2image` across `Sources/` = 0 hits. Greenfield |

### 2.7 MiniMax endpoints — probed live with an invalid key

Every endpoint returns an auth error rather than 404, which proves the route exists.

| Endpoint | Probe result |
| --- | --- |
| `POST api.minimaxi.com/v1/image_generation` | 200 + `base_resp.status_code 1004` |
| `POST api.minimaxi.com/v2/video_generation` | 401 + `authorized_error` |
| `GET api.minimaxi.com/v2/query/video_generation/{task_id}` | 401 |
| `POST api.minimaxi.com/v1/video_generation` | 200 + 1004 (Hailuo series) |
| `GET api.minimaxi.com/v1/query/video_generation?task_id=` | 200 + 1004 -> returns `file_id` |
| `GET api.minimaxi.com/v1/files/retrieve?file_id=` | 200 + 1004 |

**Authentication differs from the LLM path.** wenshu's `minimax-cn` provider uses
`authHeader: .xApiKey` (`BuiltInProviders.swift:121-135`), but the image and video
endpoints authenticate with `Authorization: Bearer <key>`. The probe evidence is the
endpoint's own error text, which names the header it wants:

> `login fail: Please carry the API secret key in the 'Authorization' field of the request header`

A probe sending `x-api-key` returns that same message, so the cover client cannot reuse
`provider.authHeader` blindly and must set `Authorization: Bearer` explicitly.

**Video download URLs expire 9 hours** (MiniMax docs) — the file must be written to disk
as soon as the task succeeds.

### 2.8 The quota constraint that drives the design

MiniMax Token Plan tiers (cross-checked across public sources):

| Tier | Images/day | Videos/day |
| --- | --- | --- |
| Plus | 50 | 0 |
| Max | — | **2** |
| Ultra | 800 | **5** |

Images are plentiful; videos are 2–5 per day. A material zone with dozens of cards can
therefore never have all its dynamic covers filled in one pass. **This is the reason the
refresh button must exist**, and it must be a *continue-the-queue* action, not a
*regenerate-one* action.

---

## 3. Replication design

### 3.1 Two independent watermarks

Each card carries a cover record with two independent states:

```
staticImagePath?     <- static cover    (image quota is ample; fill in one pass)
dynamicVideoPath?    <- dynamic cover   (video quota is scarce; fill in over days)
staticPosterPath?    <- first frame, shown while the video is not playing
accentHex?
status: .pending | .staticReady | .dynamicReady | .failed
lastAttemptAt / lastError?
```

The static and dynamic pipelines never block each other. A card always has a usable
cover once the static pass completes; the dynamic pass only upgrades it.

### 3.2 Degradation chain

```
video quota exhausted / generation failed
   -> card keeps its static cover + poster frame
   -> hover plays the poster if a video exists, otherwise nothing changes
```

Dynamic covers are progressive enhancement, never a hard dependency. If tomorrow's
quota is spent, today's static covers all still work.

### 3.3 Image-to-video consistency

Generate the static image first, then feed it as `first_frame` to the video endpoint
(MiniMax `i2v`: `content: [{type:"text"}, {type:"image_url", role:"first_frame"}]`).
The video then matches the static frame, so the hover transition has no jump, and one
text description covers both passes.

### 3.4 Settings pane

Add `case covers` to `SettingsPane` (`SettingView.swift:40-64`). Three required edits:
the enum case, the `icon` switch (`:53-63`), `localizedPaneTitle` (`:230-240`), and
`paneBody` (`:215-226`). `paneForRaw` (`:201`) needs no edit — its `default:` branch
already resolves any new raw value. The sidebar renders the icon through
`SFIcon(pane.icon, style: .sidebar, color: IconColor.secondary)` (`:162`), so the Tahoe
squircle treatment comes for free.

Pane content:

- **Master switch** — auto-generate card covers (off disables every generate action).
- **Cover types** — static (image) and dynamic (video) as two independent checkboxes.
- **Strategy** — trigger (on card creation / manual / both), video duration 6s, 768P,
  aspect ratio 3:4 (matches MiniMax's `aspect_ratio: "3:4"` and the card thumbnail).
- **Service config** — base URL and model override; the key comes from
  `ProviderKeychain` for `minimax-cn` but is sent as `Authorization: Bearer`.
- **Queue panel** — pending count, completed count, estimated quota remaining,
  "start filling" and "refresh" buttons.

New strings go in `Localizable.xcstrings` (`settings.pane.covers` + labels) with both
`en` and `zh-Hans` `stringUnit` entries, matching the shape of `settings.pane.appearance`.

### 3.5 UI placement

| Element | Location | Shape |
| --- | --- | --- |
| Cover thumbnail | replace the `ZStack` content in `PreviewPaneCard.swift:190-212` | render the image when a cover exists, otherwise keep the gradient + icon |
| Hover becomes dynamic | reuse `isHovered` (`:135`, `:327`) | drive `AVPlayer.play()` / `pause()` on change |
| Per-card refresh | the existing `.contextMenu` (`:395-440`) | add a "regenerate cover" item alongside the existing rename/delete/complete entries. Note `needsCompletion` / `onComplete` (`:120`, `:124`) are **never passed** by any of the three `Card(` call sites (`PreviewPaneGrids.swift:27`, `:268`, `:327`) — a new callback must be wired at all three |
| Global refresh | settings pane + the assets-zone footer | `AssetsPane.swift:215-233` already has a `ChromeBottomFooter` |

### 3.6 Technical decisions

**Image loading — no NukeUI.** AGENTS §5.5 requires a ticket plus boss sign-off for a
new dependency, and §5.1 restricts `Sources/WenshuApp/**` to Apple frameworks. Covers are
local files, so `NSImage(contentsOfFile:)` plus a small cache is sufficient. The
precedent is `ChatMessageAttachmentPreview.swift:63-75`.

**Video playback — `AVPlayer` + `AVPlayerLayer`** behind a `UIViewRepresentable`, not
SwiftUI's `VideoPlayer` (which brings its own transport controls that do not belong on a
card). `AVKit` would be the project's first `AVKit` import; `AVFoundation` is already in
use. No `Package.swift` change is needed — system frameworks are imported behind
`#if canImport` guards (`AVMediaTools.swift:8-11`). The view must live in
`Sources/WenshuApp/` because the `WenshuAgent` package holds no SwiftUI.

**Storage — inside the `.ws` warehouse.** The SwiftData store already lives at
`<.ws>/WenshuStore.store`, and `<.ws>/assets/` exists and is unused. Cover binaries go
to `<.ws>/assets/covers/<cardID>/`; the metadata goes in a `WSAttachment`-shaped row
(or a new `WSCardCover` model — additive, so no migration plan).

**Tool wiring — register in two places.** `ToolRegistry.shared.registerTool` for the
handler, and `ToolCatalogue.all` (`ToolCatalogue.swift:71-73`, the media block) for
exposure. Omitting the second leaves the tool invisible to the model. The `media`
category preset already exists (`ToolExposure.swift:165-170`).

**Path guard.** Any path the tool writes must live under `ActiveLibrary.path`, or
`ToolExecutor.defaultPathGuardValidator` (`ToolExecutor.swift:162-168`) rejects the call.

---

## 4. Ticket split

Each ticket runs in its own git worktree created as a board card on `wenshu-par`
(AGENTS §1.12).

| # | Ticket | Deliverable |
| --- | --- | --- |
| 1 | Cover data model + storage | `WSCardCover` (or `WSAttachment` reuse) + `<.ws>/assets/covers/` read/write + additive schema append to `ModelsSchemaV1.models` |
| 2 | Image generation service | MiniMax `image_generation` client (Bearer auth) + crop/WebP encoding + queue scheduler |
| 3 | Static cover rendering | replace the `Card` thumbnail + image load + per-card regenerate menu item wired at all 3 `Card(` call sites |
| 4 | Settings pane | `SettingsPane.covers` + switches + service config + `Localizable.xcstrings` entries |
| 5 | Video generation + hover playback | MiniMax video client (async task + poll + 9-hour URL download) + `AVPlayer` hover playback |
| 6 | Refresh button + queue progress | queue top-up logic + footer button + settings progress panel |

**Do 1-4 first (static closure), then 5-6 (dynamic).** Static quota is ample and the
value is immediate; the dynamic path is a long chain (async task, polling, video encode,
hover playback) with no upstream implementation to copy.

Every new file must be registered in `docs/agents/nfi.md` (AGENTS §1.7 / §1.11), and the
§7.3 nine-grep sweep must return 0 on modified files.

---

## 5. Decisions required

1. **Which key supplies the quota?** Reuse the existing `minimax-cn` keychain entry, or
   add a separate image/video service credential? Reuse is simpler; a separate entry
   bills and degrades independently.
2. **When does a dynamic cover get queued?** On every new card (burns the scarce quota),
   or only for cards the user marks (conserves it)? The second matches a 2-5/day reality.
3. **What does the degraded state look like?** Silent, with a progress number in the
   footer; or a visible "pending" badge on the card? Recommendation: silent + footer
   progress, so the card grid stays calm.

---

## 6. Incidental findings (not part of this feature)

- `ReferenceLibraryImageProvider` searches `worlds/` (`ReferenceLibraryImageProvider.swift:35`, `:65`) but the real folder is `world/` (`BookFolderCatalog.swift:118-119`). Existing markdown `![[embed]]` resolution therefore misses world-folder images.
- `Card.needsCompletion` / `onComplete` (`PreviewPaneCard.swift:120`, `:124`) are never passed by any call site, so the "complete" context-menu item never appears.
