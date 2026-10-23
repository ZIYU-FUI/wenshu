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
therefore never have all its dynamic covers filled in one pass. This is why the boss
chose a **manual, per-card** dynamic action rather than an automatic sweep: the user
spends the scarce quota on the cards they actually want animated, one at a time
(decision 5, §5).

---

## 3. Replication design

### 3.1 Two independent watermarks

Each card carries a cover record with two independent states:

```
staticImagePath?     <- static cover    (image quota is ample; fill in one pass)
dynamicVideoPath?    <- dynamic cover   (video quota is scarce; manual per card)
accentHex?
status: .pending | .staticReady | .dynamicReady | .failed
lastAttemptAt / lastError?
```

The static and dynamic pipelines never block each other. A card always has a usable
cover once the static pass completes; the dynamic pass only upgrades it.

### 3.2 Degradation chain

```
no dynamic cover (not requested / quota spent / generation failed)
   -> the card shows its static image, which is always present
   -> hover does nothing special
```

The static image is the floor. There is never a card without a picture once the static
pass has run, so "no video" is a normal state, not an error state.

### 3.3 Image-to-video consistency, and the input-size gate

The dynamic cover is **derived from the static image**, not generated independently.
That is the boss's requirement and it also removes a whole class of problems: the video
cannot disagree with the picture the user already approved.

The mechanism is MiniMax image-to-video: the stored static image becomes the first
frame, so the motion starts from exactly the frame the user saw.

**The input-size gate (measured against the MiniMax i2v spec):** `first_frame_image`
requires the short edge to be **greater than 300 px** and the aspect ratio to be
**between 2:5 and 5:2**. This is why the image size cannot simply be the display size:

| Candidate | Short edge | Aspect | i2v accepts? |
| --- | --- | --- | --- |
| 640x224 (PT-matched 2x ceiling) | 224 | 2.86 | **NO** — short edge too low AND aspect too wide |
| 768x320 (chosen) | 320 | 2.40 | yes |
| 1024x448 | 448 | 2.29 | yes |

**The whole i2v flow was exercised against the live endpoint on 2026-10-22**, with a
real 768x320 banner:

```
POST /v1/video_generation  {model: MiniMax-Hailuo-02, first_frame_image: data:image/jpeg;base64,...,
                            duration: 6, resolution: 768P}
  -> {"task_id": "455060879892746", "base_resp": {"status_code": 0, "status_msg": "success"}}

GET /v1/query/video_generation?task_id=...
  -> status Processing x5, then: status=Success file_id=455060523807035 video_width=1728 video_height=720

GET /v1/files/retrieve?file_id=...
  -> {"file": {"download_url": "..."}}   (9-hour expiry: download immediately)
  -> 670.7 KB mp4
```

The delivered clip is **1728x720 (2.4:1) at 24 fps, 5.88 s** — the aspect follows the
first frame, so the 2.4:1 banner survives the round trip.

**The clip does not loop seamlessly, and that is measured, not assumed.** Sampling six
frames across the clip and comparing them on a 32x32 grayscale grid:

| Comparison | Mean abs difference |
| --- | --- |
| consecutive frames (0 -> 1) | 3.80 |
| consecutive frames (2 -> 3) | 4.61 |
| **first frame vs last frame** | **13.73** (16.57 on a 64-grid) |

So there IS real motion (consecutive frames differ), but the first and last frames
differ by about 5% of full scale, which reads as a visible jump when the clip loops.
The provider was asked for a seamless loop and did not deliver one. **The stored
artifact must therefore be played forward-then-backward** (ping-pong), which doubles
the apparent duration and is guaranteed seamless, OR the clip is cross-faded at the
seam. The cheapest correct choice is ping-pong playback of a single stored file.

**The stored video size.** The provider delivers 670.7 KB. `AVAssetExportSession` with
a custom `AVMutableVideoComposition` (the standard scaling path) produced:

| Output | Size |
| --- | --- |
| provider original 1728x720 | 670.7 KB |
| export 768x320 (MediumQuality) | 500.5 KB |
| export 632x264 (MediumQuality) | 506.3 KB |
| `AVAssetExportPresetLowQuality` (192x80) | 99.9 KB |
| `AVAssetExportPreset640x480` (640x268) | 893.1 KB — LARGER than the original |

The presets are unusable as a size control (the 640x480 preset produced a bigger file
than the source), so a custom composition plus an explicit bitrate is the path.
`AVVideoAverageBitRateKey` on `AVAssetWriterInput` is the lever, and
`AVAssetWriterInput.requestMediaDataWhenReady` is required (appending without that
backpressure throws `A pixel buffer cannot be appended when readyForMoreMediaData is
NO`). At the display size of 768x320 a few hundred KB per dynamic cover is acceptable,
because dynamic covers are per-card and manual (decision 5), so a library accumulates
a handful of them rather than hundreds.

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

### 3A.0 Two platform facts that override the reference implementation

Both were verified by compiling and running a probe on this machine, not by reading
docs.

**(a) macOS has no WebP encoder.** Card Master's cover pipeline ends in
`canvas.convertToBlob({type: 'image/webp'})` (`card-cover.ts:100-103`) because the
browser can encode WebP. The probe result on macOS 27:

```
UTType.webP.identifier = org.webmproject.webp
WebP ENCODE via ImageIO: DESTINATION UNSUPPORTED (no encoder on this macOS)
```

`NSBitmapImageRep.FileType` has no `.webP` case either, so there is no AppKit fallback.
**Wenshu must store HEIC** (Apple-native, and the project is Apple-stack exclusive per
AGENTS §5.1). Measured on the real generated lighthouse cover at quality 0.82:

| Format | 768x320 |
| --- | --- |
| WebP | unsupported |
| **HEIC** | **58.9 KB** |
| JPEG | 112.7 KB |

HEIC at 768x320 is **58.9 KB per cover** — 100 covers cost 5.8 MB. That is the same
order as the existing `cache/chat-uploads` directory (3.5 MB today), so library space is
not a constraint at this size.

**(b) The i2v payload must be JPEG, not HEIC.** MiniMax's `first_frame_image` accepts
JPG / JPEG / PNG / WebP — HEIC is not in the list. The conversion is a decode-reencode
in memory, verified end to end on the real cover:

```
stored HEIC bytes: 58900 (58.9 KB)
decoded back: 768 x 320
i2v JPEG payload bytes: 112742 (112.7 KB)
data URL chars: 150200 (150.2 KB)
```

So the pipeline is: **generate -> crop -> HEIC (stored) -> decode -> JPEG q0.92 ->
base64 data URL -> i2v**. The HEIC file stays the single stored artifact; the JPEG
exists only in memory during the call.

**(c) The stored size must be 768x320, not the display size.** Two independent gates
force it, and both were measured against the live endpoints. The provider requires
512 px on both sides (`invalid params, height must be between [512,2048]`), and the
i2v input gate requires a short edge over 300 px with the aspect within 2:5..5:2
(see §3.3). The PT-matched 2x display ceiling (640x224) fails both. 768x320 passes
both and renders correctly at every card width in the measured range, so one file
serves display, i2v input, and hover poster.

---

## 3A. Boss directives: unified style, PT-sized output, library space, auxiliary-model config

Four directives from the boss, each traced to code before answering.

### 3A.1 The cover area is a wide banner, not a portrait card

Card Master generates a 3:4 portrait (480x640). Wenshu's material-zone card thumbnail is a
**wide banner**. Measured from the layout chain:

| Step | Source | Value |
| --- | --- | --- |
| AssetsPane column width | `LibraryRootView.swift:131-140` | min 240, ideal 300, max 340 PT |
| PreviewPane horizontal padding | `PreviewPane.swift:166` | `spacingModerate` = 12 PT per side |
| Grid column count | `PreviewPane.swift:107` (`twoColumnBreakpoint` = 350) | grid is 216-316 PT, so always 1 column |
| Card width | derived | 216 / 276 / 316 PT |
| Cover height | `PreviewPaneCard.swift:212` | `panelMinHeight` = 100 PT |

So the cover area is **216x100 to 316x100 PT = a 2.16:1 to 3.16:1 banner**. Card Master's
3:4 shape is wrong for wenshu and would be centre-cropped into a letterbox.

### 3A.2 Output size: PT-matched, not oversized

**Everything in this section was measured against the live MiniMax endpoint on
2026-10-22, not read off a doc.** The provider minimum is 512 px on BOTH sides, so the
stored banner is 768x320 — chosen as the smallest shape that (a) clears the provider
minimum, (b) clears the i2v input gate, and (c) covers the widest card at 2x.

Measured request/response matrix (real calls, `image-01`):

| Request | Result |
| --- | --- |
| 752x304 | **REJECTED** — `status_code 2013, invalid params, height must be between [512,2048]` |
| 512x512 | accepted, 141.2 KB |
| **1024x512** | **accepted, 233.9 KB** (the shape actually used) |
| 1280x512 | accepted, 261.8 KB |
| 1536x512 | accepted, 351.4 KB |
| 1024x576 | accepted, 298.3 KB |

The response is always JPEG regardless of the requested format, and `width`/`height`
must both be >= 512. `image-01-live` cannot be used at all: it returns
`image-01-live model does not support width or height parameters`, so the size cannot
be controlled with that model. **The model is `image-01`.**

So the request is 1024x512 (2.0:1) and the crop to 768x320 (2.4:1) happens locally.
The crop is a centre crop, and it was verified visually: the generated lighthouse stayed
fully visible with sky above it, and the composition stayed balanced.

**Stored size, measured on the real generated image** (not a synthetic):

| Artifact | Bytes |
| --- | --- |
| provider 1024x512 JPEG (transient) | 269.2 KB |
| **stored HEIC 768x320 q0.82** | **58.9 KB** |
| i2v payload JPEG 768x320 q0.92 | 112.7 KB |
| i2v payload as a base64 data URL | 150.2 KB |

100 covers cost **5.8 MB**. The whole `.ws` library is 4.4 MB today (26 cards), of
which 420 MB is `WenshuStore.store` and 3.5 MB is `cache/chat-uploads`. So library
space is not a binding constraint at this size.

**Format: HEIC, not WebP.** macOS 27 has no WebP encoder (verified, §3A.0). HEIC is
Apple-native and roughly half of JPEG at the same quality on painterly content.

**Why 768x320 and not 640x224:** the display ceiling for the widest card (316 PT) at 2x
is 632x200, so 640x224 would fit the screen — but the i2v input gate rejects it (short
edge must exceed 300 px, and 224 fails). One stored file serves display, i2v first
frame, and hover poster, so there is no second copy and no extra library cost.

### 3A.3 Unified style: one art-direction prompt for every cover

Card Master's `CARD_ART_DIRECTION_PROMPT` (`card-art-direction.ts:1-10`) is the pattern to
borrow verbatim in structure: a single house-style string prepended to every generation,
so the model describes **what** to draw and never **how** to draw it.

Wenshu's version belongs in one constant, e.g. `CardCoverStyle.artDirectionPrompt`, used
by both the settings pane preview and the batch generator, so a cover generated from the
settings pane looks identical to one generated by the queue.

The style text must be English (AGENTS §1.1 forbids CJK in tracked `.md`; the same rule
applies to prompts the app ships) and must state the wenshu shape, not Card Master's
portrait framing:

```
A wide cinematic banner illustration for a writing-workbench card, 2.8:1 landscape
framing with the subject centered and generous headroom on both sides. Hand-painted
editorial key art, saturated warm color masses, rich midtones, tactile materials,
clear silhouette, confident illustrative finish. Original artwork only: never
imitate an existing franchise, character, logo, or official illustration.
```

The subject description is English-only (Card Master enforces ASCII at
`image-card-cover.ts:55-57`); the per-card description is derived from the card's title
and summary, so a Chinese title is translated into the English concept by the LLM before
the image call, never pasted raw into the prompt.

### 3A.4 Auxiliary-model config: the Hermes pattern

The boss asked for the Hermes separately-configured auxiliary model, in code and in UI.
It exists and is worth copying in structure.

**Hermes contract.** Each side task gets its own routing block under
`auxiliary.<task>` in `config.yaml`:

```yaml
auxiliary:
  vision:
    provider: auto      # "auto" = inherit the main model
    model: ""           # "" = provider default
    base_url: ""
    api_key: ""
  compression:
    provider: auto
    ...
```

- Default block shape: `hermes_cli/config_defaults.py:26` (`_aux(...)` helper builds
  `provider/model/base_url/api_key/timeout/extra_body`).
- Built-in task slots and their order: `hermes_cli/web_server_config.py:551-554`
  (`_AUX_TASK_SLOTS` = vision, compression, skills_hub, approval, mcp, title_generation,
  review, voice_chat, triage_specifier, kanban_decomposer, profile_describer, curator).
- Per-provider curated default: `providers/base.py:143` (`default_aux_model: str`, empty
  = use the main model) and `providers/base.py:166` (`resolve_aux_model(vision:)`, a live
  override hook that returns "" to fall through).
- Resolution ladder: `agent/auxiliary_client.py:785-820` — live catalog match, then
  `resolve_aux_model()`, then `default_aux_model`, then a legacy fallback dict.
- Read-time layering: `agent/auxiliary_task_config.py:44-115`. The key rule is
  `_AUX_ROUTE_KEYS` (`:93-94`): `provider/model/base_url/api_key/api_mode/key_env/
  api_key_env/reasoning_effort` travel as **one unit**. Once a task pins any route field,
  the whole route comes from that task; a provider must never inherit another provider's
  base URL or key. `_layer_over_inherited` (`:97-115`) implements the "reset to auto"
  semantics: `provider: auto` plus empty strings means "follow the base", not "override
  with nothing".
- Hermes CLI UI: `hermes_cli/main_provider_setup.py:230-330` (`_aux_config_menu`, a
  list of tasks each showing its current route, plus a "Reset all to auto" row;
  `_aux_select_for_task` opens a provider+model picker; `_format_aux_current` renders the
  current route as one line).
- Hermes web UI: `web/src/pages/ModelsPage.tsx:596-700` (the "Auxiliary Tasks" modal —
  one row per task, label + hint + current route, a "Change" button per row, and a
  "Reset all to auto" button at the top), with the row metadata in
  `web/src/lib/aux-tasks.ts` and the wire type in `web/src/lib/api-aux.ts`.

**What wenshu already has.** `AuxTask` (`Sources/WenshuApp/App/WenshuAppMain.swift:194-228`)
already enumerates the side tasks (vision, web_extract, compression, approval, mcp,
title_generation, curator), each with a label and an SF Symbol. The models pane renders
them at `SettingView.swift:725-741`.

**What wenshu is missing.** That block is **display-only**: every row shows the literal
string `settings.model.use_main_model` and there is no picker, no persistence, and no
resolver. A repo-wide grep for `AuxTask.` outside the enum declaration returns exactly
one hit — the `ForEach` that renders the rows. So the auxiliary-model concept exists in
wenshu as a UI sketch with no backend. The cover generator is the first task that needs
a real route.

**Design: give wenshu the same shape, Hermes-style.**

1. A `WSCoverServiceConfig` (@Model, additive) with the Hermes field set:
   `provider` (default `"auto"`), `model` (default `""` = provider default),
   `baseUrl` (default `""`), `apiKeyRef` (default `""` = use the provider keychain slot).
2. `"auto"` means **inherit the active provider's key and endpoint** — the same meaning
   Hermes gives it. The cover client then uses `ProviderKeychain.loadKeySync(for:)`.
3. A pinned route sets provider + model + base URL explicitly, and the route travels as
   one unit (no partial inheritance) so a pinned image provider can never inherit the main
   provider's base URL.
4. A separate key is stored in the keychain under its own slot, never plaintext
   (AGENTS §2.6). A separate credential means a separate `Provider` entry or a
   keychain-scoped account id, so the image provider can bill and degrade independently.

**UI: copy the Hermes modal shape into the Settings scene.** The models pane
(`SettingView.swift:676-747`) already has an auxiliary-tasks section; it becomes a
"Card covers" subsection with one row per service:

| Row | Default shown | Picker offers |
| --- | --- | --- |
| Card cover image | `auto (use main model)` | image provider + model + base URL + separate key |
| Card cover video | `auto (use main model)` | video provider + model + base URL + separate key |

Each row: icon + label + hint + the current route on one line + a "Change" button, plus
a "Reset all to auto" action at the top of the section. This is the Hermes
`ModelsPage.tsx:622-690` row layout, rendered as a SwiftUI `Form` section.

**Note on the boss's "the key needs a config item".** A key for the image service does not
exist yet — `ProviderKeychain` holds one slot per `Provider` slug, and wenshu has no
image provider slug. So the settings pane must offer the key as a field, stored through
`ProviderKeychain` (never plaintext). The alternative — reuse the `minimax-cn` slot —
is the `"auto"` default and needs no new key.

---

## 3C. What has landed

ALL NINE tickets are on `main`. The whole cover test suite passes
there: **75 tests across 18 suites**, and `swift build` exits 0.

| Ticket | What it added |
| --- | --- |
| 1 | `WSCardCover` (@Model) + the cover directory and the one card-key function + the HEIC/JPEG codec + the single art-direction constant + the Bearer-auth image call |
| 2 | the atomic four-field route + the route store + the resolver ladder + the two kinds |
| 3 | the generation service + the card's generate / regenerate / remove menu items |
| 4 | `CardCoverView` + the picture drawn in the card's cover slot + all three `Card(` call sites wired |
| 5 | the Covers settings pane + the catalog keys |
| 6 | the image-to-video client + the clip playing forward-then-backward on hover |
| 7 | the batch for the stock + the automatic pass for the new + the policy that separates them |
| 8 | the delete cascade at both chokepoints + the reconciler for the documents deleted outside the app |
| 9 | the automatic pass WIRED + one shared per-card lock + the batch progress + the agent's writes announcing that the library changed |

Five findings came out of the implementation rather than the
research, and each one changed a design:

- **The cover service has its own model namespace.** A route inherits
  the provider and takes the model from the service it routes to. The
  provider profiles describe chat models, and the image endpoint
  answers "model not available" for a chat model.
- **Removing a cover has to take the files the row records**, not just
  the cover's own directory. The row is where the paths live, so a
  file the row points at must not survive the row.
- **The card key function is `nonisolated`.** It is a pure function of
  the card's identity, and the view layer needs it while building a
  card.
- **The automatic pass was DEAD CODE, and the gates could not see it.**
  `CoverAutoTrigger.coverIfNeeded` had no caller anywhere: the switch
  wrote its flag and its timestamp into `UserDefaults`, the settings
  pane read the flag back to draw the toggle, and nothing ever read
  it to MAKE a cover. Both suites passed on a feature that never ran,
  because the policy is a pure function and the batch skips covered
  documents. A control that appears in a UI is not evidence that it
  works; count the runtime consumers, not the controls.
- **The batch and the card menu must share ONE service instance.** The
  per-card lock is a per-instance property, and `live()` returns a
  new instance on every call, so two paths held two lock sets and a
  batch run plus a manual click on the same card each spent an image
  call. One holder (`CoverPaneServices`) now owns the generation
  service every path uses.

A sixth came out of a PEER review: the centre crop was SQUEEZING
the picture rather than cropping it, because it computed the scaled
size and then drew the source straight into the target rectangle. The
crop now scales by the LARGER of the two axis ratios, draws the
scaled picture centred, and clips it, so the subject keeps its shape.

### 3C.1 The cover record is a FILE in the library, not a store row

A seventh finding came out of the app itself, and it changed the
storage design.

**The symptom.** A card's cover appeared when the app started and was
gone after the user switched the directory tree, or scrolled the card
out of sight and back. Nothing was deleted: the picture was on disk
and the record was in the store, and both survived.

**The cause.** `WSPersistenceContainer.current` is
`activeWarehouseContainer ?? shared`, and the app delegate activates
the warehouse container in `applicationDidFinishLaunching` — about
650 ms AFTER the first view render. The measured trace:

```
+0.000s  coverImageURL -> path=... exists=true   container=.../Library/Application Support/WenshuStore.store
+0.652s  coverImageURL -> NO ROW                 container=.../Documents/anbaiqiang.ws/WenshuStore.store
```

The cover's picture was always written to the library
(`<library>/assets/covers/<key>/cover.heic`), while its record was
written to whichever container the app had resolved at that moment.
The two halves of one cover therefore lived in two different places,
and the card could only find a cover whose two halves happened to be
in the same store. Every re-render (a tree switch, a scroll that
recycles the cell) re-read the record, and after the container
flipped the re-read found nothing.

The grid also ran one store fetch per card per render — 3 622
lookups in 1.5 s for a handful of cards.

**The change.** The cover's record is now a file in the library,
beside the picture it describes:

```
<library>/assets/covers/<cardKey>/cover.heic
<library>/assets/covers/<cardKey>/cover.mp4
<library>/assets/covers/<cardKey>/cover.json
```

- The picture's own file decides whether a card has a cover, so the
  record can never disagree with it.
- The record travels with the library, so a copied `.ws` carries its
  covers with it.
- No store is involved, so the container that the app resolves at
  launch cannot matter.
- The lookup is one cached entry per card, and the decoded picture is
  cached by path and mtime, so a card that scrolls out of sight and
  back does not re-read and re-decode.
- `WSCardCover` stays in the schema so a library that already carries
  the table keeps opening. Nothing writes it any more.

## 4. Ticket split

Each ticket runs in its own git worktree created as a board card on `wenshu-par`
(AGENTS §1.12).

| # | Ticket | Deliverable |
| --- | --- | --- |
| 1 | Cover data model + storage | `WSCardCover` (@Model) + `<.ws>/assets/covers/<cardID>/` read/write + the unified art-direction constant + the MiniMax `image_generation` client (Bearer auth, 1024x512 request, 768x320 crop, HEIC encode) |
| 2 | Auxiliary route config | `CoverServiceRoute` (provider / model / base URL / key as ONE unit, Hermes-shaped) + the resolver that honours `"auto"` = inherit the active provider, and that never silently defaults the VIDEO route |
| 3 | Single-card generation | the generate / regenerate / remove actions in the card's context menu + the per-card lock + the "a failed regeneration keeps the old picture" rule |
| 4 | Static cover rendering | the `Card` thumbnail draws the stored HEIC in the 100pt banner slot, asynchronously, falling back to the gradient + symbol |
| 5 | Settings pane | `SettingsPane.covers` + the Hermes-shaped route rows (one per service, with "Change" and "Reset all to auto") + `Localizable.xcstrings` entries |
| 6 | Dynamic cover + hover playback | i2v client (HEIC -> JPEG -> data URL, async task + poll + 9-hour URL download) + `AVPlayer` FORWARD-THEN-BACKWARD playback on hover + the "make dynamic" context-menu item |
| 7 | Batch + automatic | a batch for the documents that already lack a cover, and an automatic path for the documents that appear after the switch was turned on |
| 8 | Cover lifecycle | the cover is a child of its document: deleting the document deletes the cover, plus a reconciler for the covers whose document vanished outside the app |
| 9 | Close the runtime gaps | the automatic pass wired to a real caller + ONE shared per-card lock across the batch and the card menu + the batch progress + the agent's writes announcing that the library changed |

**Do 1-5 first, then 6-9.** The static path is what every card needs; the dynamic path
is a per-card manual upgrade that depends on the static image already existing.

There is no video queue ticket: decision 5 (manual, per card) removed it.

### 4.1 The cover is a child of its document (ticket 8)

The boss's rule: when the user right-clicks a document and deletes it, the
cover goes with it. A cover with no document can never be shown again, so
an orphaned cover is dead weight in the library forever.

The delete cascade has to reach two card kinds, deleted by different code:

- A REFERENCE card is deleted by
  `FileSystemReferenceStore.deleteReference(id:)`
  (`Sources/WenshuApp/Features/Library/Service/FileSystemReferenceStore.swift:284`).
  Every path funnels through it: the sidebar delete
  (`SidebarServiceMutation.swift:303`), the material-zone right-click
  delete (`PreviewPane.swift:225`), the agent's reference-library tool
  (`ReferenceLibraryTool.swift:231`), and the LLM-wiki layer deriver
  (`Sources/WenshuApp/Features/Library/Service/LLMWikiLayerDeriver.swift:90`). The last one matters most: the wiki
  pipeline deletes references with nobody asking, so a cascade hooked
  only into the UI would leak a cover on every wiki rebuild.
- A BOOK-DOC card is deleted by
  `SidebarServiceMutation.deleteBookDoc(id:)`
  (`SidebarServiceMutation.swift:477`), which removes the `.md` file.
  There is no store chokepoint for a book doc.

A reconciler covers what the cascade cannot: a document deleted in
Finder, by a script, or by a git checkout. It compares the cover rows
against the live card set and removes the ones whose card is gone, and
it runs on the library reload that already exists.

The cover KEY is defined once, in ticket one, and it keeps a reference
card and a book card on different keys so one card's picture can never
land on another card. Ticket eight calls that function rather than
re-deriving it: two key functions produce two different keys, and the
symptom is a cover that survives every delete.

### 4.3 The cover service has its OWN model namespace

The route inherits the PROVIDER and takes the MODEL from the service it
routes to. That is not a stylistic choice, and the reason is a
measured failure: the provider profiles in this app describe CHAT
models (`MiniMax-M3`, `MiniMax-M2.7`, ...), and the image endpoint
answers "model not available" for a chat model. So a route that fell
back to the provider's default model list would draw every cover with
a model that cannot draw.

The rule, therefore:

| Route state | Provider | Model |
| --- | --- | --- |
| explicit, model named | the route's | the route's |
| explicit, no model | the route's | the KIND's default |
| auto | the app's current | the KIND's default |
| nothing configured | the default | the KIND's default |

The KIND's default is `image-01` for the image service and NONE for
the video service. The video kind having no default is deliberate: the
video allowance is a handful of clips a day, so a silent default
would spend a scarce quota the user never asked to spend. The video
route fails loudly until it is configured.

This is why the image endpoint's URL is also a per-kind constant
rather than the provider's `defaultBaseURL`: the profile's base URL is
the Anthropic-compatible chat host, and the cover services are
different services on the same domain.

### 4.2 Stock versus incremental (ticket 7)

The boss's rule: a batch action for the documents that are ALREADY in
the library, and automatic for the documents that come later, gated on
one switch.

The boundary between the two is the moment the switch was turned ON.
The policy stores that timestamp, and a document is automatic only if
its creation time is AFTER it. Both card kinds carry a real creation
time: a reference has `let createdAt: Date`
(`Sources/WenshuApp/Features/Library/Model/Reference.swift:241`) and a
book doc has `let createdAt: Date`
(`Sources/WenshuApp/Features/Editor/View/PreviewPaneModels.swift:198`).
The file MODIFICATION time is the wrong signal, because editing an old
document changes it and would make that document look new.

The batch is one card at a time, never a burst, and it can be stopped.
The automatic path never makes a video: the video allowance is a
handful of clips a day, and only the user may spend it.

Every new file must be registered in `docs/agents/nfi.md` (AGENTS §1.7 / §1.11), and the
§7.3 nine-grep sweep must return 0 on modified files.

---

## 5. Decisions required

**Settled by the boss on 2026-10-22:**

1. One unified art-direction prompt for every cover (§3A.3).
2. Output sized to the material-zone cover area in PT, not oversized; library space
   respected (§3A.2, §3A.0).
3. The image-service key gets its own configuration item; the generation model defaults to
   the default model; the user can configure it separately (§3A.4 — Hermes-shaped
   auxiliary route with `"auto"` = inherit).
4. **Quota source:** development uses the `minimax-cn` quota; the shipped build exposes
   the route as a user-configurable item, because the user's own provider is unknown.
   So `"auto"` resolves to the active provider's key during development, and a pinned
   route (provider + model + base URL + its own key) is what a user sets for their own
   account.
5. **The dynamic cover is manually triggered.** The user looks at the static image, and
   if they like it, clicks "make this dynamic". No automatic video generation, no
   background video queue.
6. **The dynamic cover is derived from the static image**, not generated from scratch.
   When there is no video, the static image is what shows. If the user dislikes the
   static image, they regenerate it (refresh / re-run) rather than editing a prompt.
   The target is a gently looping animation, not a cinematic video.

### 5.1 What decision 6 changes in the design

- **No video queue.** The earlier "continue-the-queue" refresh design is dropped. The
  refresh action on a card regenerates the **static image**; a separate "make dynamic"
  action on a card requests the video for that one card.
- **The dynamic cover is a short loop, not a short film.** The boss asked for
  "a looping dynamic picture", explicitly not something elaborate. So the video spec
  is minimal: 6 s, 512P (the cheapest tier MiniMax-Hailuo-02 offers), and the prompt
  asks for a gentle continuous motion so the loop reads as intentional.
- **The clip must actually loop.** A 6 s clip that cuts back to its first frame will
  visibly jump. Two options: (a) ask the model for a seamless loop and accept the
  attempt, or (b) store the clip and play it forward-then-backward, which doubles the
  duration but is guaranteed seamless. The cheap default is (a) with a `loop`
  playback; (b) is the fallback if the first clips look jumpy.
- **The video is stored next to the image**, `<.ws>/assets/covers/<cardID>/`, as a
  compressed file. AVFoundation on this machine offers `AVAssetExportPresetLowQuality`
  and `AVAssetWriter` with `AVVideoCodecType.h264`, so the clip can be re-encoded small
  rather than stored at the provider's delivery bitrate.

### 5.2 The refreshed card actions

Three per-card actions, each with a distinct job:

| Action | What it does | Quota |
| --- | --- | --- |
| **Regenerate cover** | re-runs the static image generation for this card, replacing the stored HEIC | 1 image |
| **Make dynamic** | derives a looping video from the current static image | 1 video (scarce, so it is manual and per card) |
| **Remove cover** | deletes both, returning the card to the icon-on-gradient state | none |

The card context menu already has the right shape for this
(`PreviewPaneCard.swift:395-440`): the "complete" item sits first, then rename, then
delete. The three cover actions join that menu.

### 5.3 Still open

1. **Which key supplies the quota?** Settled for development (`minimax-cn`), still open
   for shipping: reuse the `minimax-cn` keychain slot (the `"auto"` default), or give
   the image service its own credential so it bills and degrades independently? The
   settings pane must offer the key either way.
2. **How is the "make dynamic" prompt authored?** The i2v call needs a text prompt
   describing the motion. Options: (a) a fixed house motion prompt for every card
   (one constant, matching the unified-style decision), or (b) an LLM-written motion
   prompt per card, derived from the card's content the same way the image concept is.
   (b) gives a better result and costs one cheap LLM call; (a) is simpler and free.
   Recommendation: (b), because the static concept is already computed and the motion
   can reuse it.
3. **What does the degraded state look like?** A card with a static image and no video
   simply shows the image on hover (no special state). Recommendation: no badge, no
   pending indicator — the absence of a video is invisible, matching decision 6.

---

## 6. Incidental findings (not part of this feature)

- `ReferenceLibraryImageProvider` searches `worlds/` (`ReferenceLibraryImageProvider.swift:35`, `:65`) but the real folder is `world/` (`BookFolderCatalog.swift:118-119`). Existing markdown `![[embed]]` resolution therefore misses world-folder images.
- `Card.needsCompletion` / `onComplete` (`PreviewPaneCard.swift:120`, `:124`) are never passed by any call site, so the "complete" context-menu item never appears.
