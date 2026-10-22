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
| 752x304 | 304 | 2.47 | yes |
| 1024x448 | 448 | 2.29 | yes |

So the stored static image must be **752x304**, not the 640x224 the display alone would
need. That one file then serves three jobs: it is the rendered cover, it is the i2v
first frame, and it is the hover poster. Storing a separate downscaled copy for display
would double the library footprint for no visible gain.

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
AGENTS §5.1). Measured on a painterly synthetic image at quality 0.82:

| Format | 640x224 | 752x304 | 1024x448 |
| --- | --- | --- | --- |
| WebP | unsupported | unsupported | unsupported |
| **HEIC** | **16.8 KB** | **26.4 KB** | 52.0 KB |
| JPEG | 29.0 KB | 47.0 KB | 93.3 KB |

HEIC at 752x304 is **26.4 KB per cover** — 100 covers cost 2.6 MB. That is the same
order as the existing `cache/chat-uploads` directory (3.5 MB today), so library space is
not a constraint at this size.

**(b) The i2v payload must be JPEG, not HEIC.** MiniMax's `first_frame_image` accepts
JPG / JPEG / PNG / WebP — HEIC is not in the list. The conversion is a decode-reencode
in memory, verified end to end:

```
stored HEIC bytes: 27455 (26.8 KB)
decoded back: 752 x 304
i2v JPEG payload bytes: 53615 (52.4 KB)
data URL chars: 72627
```

So the pipeline is: **generate -> crop -> HEIC (stored) -> decode -> JPEG q0.92 ->
base64 data URL -> i2v**. The HEIC file stays the single stored artifact; the JPEG
exists only in memory during the call.

**(c) The stored size must be 752x304, not the display size.** The i2v input gate
requires short edge > 300 px and aspect within 2:5..5:2 (see §3.3). The PT-matched
2x display ceiling (640x224) fails both. 752x304 passes both and renders correctly at
every card width in the measured range, so one file serves display, i2v input, and
hover poster.

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

Retina needs 2x the PT size. The widest cover is 316 PT, so the display ceiling is
**632 x 200 px**. MiniMax `image-01` supports `width`/`height` directly (the API
reference lists 512-2048 px per side, multiples of 8, `image-01` only), so the request
can be sized to the target rather than to a preset aspect ratio.

**The stored size is 752x304, not 640x224.** The display alone would take 640x224, but
the i2v input gate (§3.3) rejects anything with a short edge of 300 px or less, and
752x304 also lands inside the 2:5..5:2 aspect window. One file, three uses: display,
i2v first frame, hover poster.

| Option | Pixels | HEIC per cover | 100 cards |
| --- | --- | --- | --- |
| 640x224 (display-only; rejected by i2v) | 143k | 16.8 KB | 1.7 MB |
| **752x304 (chosen)** | 229k | **26.4 KB** | **2.6 MB** |
| 1024x448 | 459k | 52.0 KB | 5.2 MB |
| 1344x576 (MiniMax 21:9 preset) | 774k | ~90 KB | 9.0 MB |

**Library-space context, measured:** the whole `.ws` library is 4.4 MB today
(26 cards), of which 420 MB is `WenshuStore.store` and 3.5 MB is `cache/chat-uploads`.
The reference and book markdown are 0.2 MB combined. At 26.4 KB per cover, 100 covers
add 2.6 MB — less than the chat-upload cache already in the library, so space is not a
binding constraint at this size.

**Format: HEIC, not WebP.** macOS 27 has no WebP encoder (verified, §3A.0). HEIC is
Apple-native and 40% smaller than JPEG at the same quality on painterly content
(26.4 KB vs 47.0 KB at 752x304).

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

## 4. Ticket split

Each ticket runs in its own git worktree created as a board card on `wenshu-par`
(AGENTS §1.12).

| # | Ticket | Deliverable |
| --- | --- | --- |
| 1 | Cover data model + storage | `WSCardCover` (or `WSAttachment` reuse) + `<.ws>/assets/covers/<cardID>/` read/write + additive schema append to `ModelsSchemaV1.models` |
| 2 | Auxiliary route config | `WSCoverServiceConfig` (@Model, Hermes-shaped fields) + the resolver that honours `"auto"` = inherit the active provider |
| 3 | Image generation service | MiniMax `image_generation` client (Bearer auth) + **752x304** output + HEIC encode + the unified art-direction prompt constant |
| 4 | Static cover rendering | replace the `Card` thumbnail + HEIC load + the "regenerate cover" / "remove cover" context-menu items, wired at all 3 `Card(` call sites |
| 5 | Settings pane | `SettingsPane.covers` + switches + the Hermes-shaped auxiliary route rows (one per service, with "Change" and "Reset all to auto") + `Localizable.xcstrings` entries |
| 6 | Dynamic cover + hover playback | i2v client (HEIC -> JPEG -> data URL, async task + poll + 9-hour URL download) + compact re-encode + `AVPlayer` loop playback on hover + the "make dynamic" context-menu item |
| 7 | Batch static generation | generate covers for the cards that lack one, with the per-card progress the boss sees in the assets zone |

**Do 1-5 first, then 6-7.** The static path is what every card needs; the dynamic path
is a per-card manual upgrade that depends on the static image already existing.

There is no video queue ticket: decision 5 (manual, per card) removed it.

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
