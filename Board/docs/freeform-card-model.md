# Apple Freeform — Card Model Teardown

Date: 2026-11-02
Target: `/System/Applications/Freeform.app`, version **5.0** (build 656.1.2), bundle id `com.apple.freeform`, localized name `无边记` (zh_CN) / `無邊記` (zh_TW).
Why: the boss plans card-based chapter organization and a content generation view in Wenshu, and wants both references read before any of it is built. Freeform is the reference for the **Apple-canonical answer**: it is Apple's own board app, and its model is what an Apple board looks like.
Status: reference teardown. Read out of the installed app and the installed SDK (`MacOSX27.2.sdk`); no Wenshu code in this document.

Its sibling: `milanote-card-model.md` (a third-party board app = the reference for the data model). The synthesis that turns both into a client is `board-plan.md`.

## 1. Method and evidence grade

Measured against a real account, one workspace, one board.

| Evidence | How | Grade |
| --- | --- | --- |
| Element envelope, field names, live values | `GET /api/boards?loadAncestors=true&ids=1TRVcg19Es2pe6` | measured |
| Type registry, property paths, enums, action names | static read of the app's own JS bundles (26 chunks, 9.2 MB) | measured |
| Toolbar palette, preferences text | `locales-en-f9788f827ce4-modern.js` (the app's own English strings) | measured |
| View-layer component contract | `propTypes` of the element component in `main-…-modern.js` | measured |
| Canvas layout semantics, ordering key | live values across 32 elements | measured |
| Per-type rendering, drag mechanics, animation | not inspected | not measured |

Auth: `POST /api/auth/login` with `{"email","password"}` returns `{"token","userId"}`. Every later call carries `authorization: Bearer <token>`. No AWS WAF challenge on the JSON API from a plain client, even though the web app loads `static.milanote.com/awswaf/…/challenge.compact.js`.

Reproduction: see §17.

## 2. The second reference: Apple Freeform

`/System/Applications/Freeform.app`, version **5.0** (build 656.1.2), bundle id `com.apple.freeform`, localized name `无边记` (zh_CN) / `無邊記` (zh_TW).

### 15.1 What Apple ships as a document type

Freeform declares two exported UTIs, both **composite packages**, not flat files:

| UTI | Extension | Conforms to |
| --- | --- | --- |
| `com.apple.freeform.board` | `board` | `public.data`, `public.composite-content` |
| `com.apple.freeform.folder` | `folder` | `public.data`, `public.composite-content` |

Two consequences:

- **Apple's own "board" is a package on disk** — the same shape as Wenshu's `.ws` package (AGENTS.md §3.1, `WSPC`). A board-as-package is not a Wenshu invention; it is Apple's.
- **No public `UTType` constant exists** for either. `UniformTypeIdentifiers` exposes no `freeform` identifier in the SDK, so Wenshu would have to declare the UTI itself to read them. And the *package layout* inside `com.apple.freeform.board` is not public API — Apple documents no format for it. **Reading or writing a Freeform board is therefore not a safe v1 claim** (§17).

### 15.2 No automation surface

- No `.sdef`, `NSAppleScriptEnabled` not declared ⇒ **Freeform has no AppleScript dictionary**.
- `NSUserActivityTypes` = `com.apple.freeform.viewModelItemHandoff`, `com.apple.freeform.viewModelDrag` ⇒ it publishes handoff and drag activities, not a scripting API.
- `AppIntents` is linked and activities such as `com.apple.Freeform.folderCreated` exist, but no public intent surface was found in the app bundle.

So Freeform cannot be driven programmatically by a third-party app the way Milanote's REST API can. The two references are not substitutable: **Milanote gives a data model, Freeform gives an interaction vocabulary and a package precedent.**

### 15.3 Freeform's element vocabulary

From Freeform's own binary strings: `StickyNote` / `Sticky`, `Shape`, `TextBox`, `Table`, `Media`, `Drawing`, `Link`, `File`, `SystemSymbol`.

Compare with Milanote's 19 element types. Freeform's vocabulary is **smaller and Apple-shaped**: a sticky note is a card, a shape is a vector, a text box is text, a media item is a photo/video/scan/file, a drawing is PencilKit ink. There is no column, no ordered list, no nested board, no comment thread, no clone.

### 15.4 What Freeform links (= how Apple builds it)

`PencilKit` (ink), `PaperKit` + `PDFKit` (scanned documents), `CoreTransferable` (drag and drop), `AppIntents`, `UniformTypeIdentifiers`, `Symbols`, `CloudKit` + `CloudDocs` + `CloudSharing` + `CoreDataUI` (shared boards), `RealityFoundation` + `RealityKit` + `Metal` + `MetalKit` (3D objects), `Vision` + `VisionKitCore`, `TranslationUIServices`, `PhotosUI` + `PhotosFormats` + `ImageIO`, `QuickLookUI` + `QuickLookThumbnailing`, `CoreSpotlight`, `LinkPresentation`, `CoreText`, `CryptoKit`, `StoreKit`, `SwiftUI`, `AppKit`.

Plus two **system-private** frameworks that are not in the SDK: `AppImageGenerationModel` and `AppImageGenerationUI`. Freeform's image generation is therefore not something Wenshu can copy — but Apple ships a public equivalent (§16).

### 2.5 Freeform's official surface is App Intents, not a file format

`/System/Applications/Freeform.app/Contents/Resources/Metadata.appintents/extract.actionsdata` (86,800 bytes, `toolsVersion 27A200c`, `version 3.0`) is the machine-readable App Intents metadata. It is the authoritative statement of what Apple lets a third party do to a Freeform board. Parsed, it yields **19 intents**, one board entity, and ten enums.

**Intents** (`Freeform.<identifier>`, all gated on `FeatureFlag Freeform/AppIntents`):

| Intent | What it does |
| --- | --- |
| `CRLCreateBoardIntent` | create a board |
| `CRLOpenBoardIntent` | open one |
| `CRLRenameBoardIntent` | rename one |
| `CRLUpdateBoardIntent` | update one's title |
| `CRLDeleteBoardIntent` | delete one |
| `CRLAddItemToBoardIntent` | **add an item** (= the current one) |
| `CRLInsertFilesToBoardIntent` | insert files |
| `CRLInsertPhotosToBoardIntent` | insert photos |
| `CRLInsertShapeToBoardIntent` | insert a shape |
| `CRLInsertTextToBoardIntent` | insert a text box |
| `CRLInsertURLToBoardIntent` | insert a link |
| `CRLChangeBoardCanvasGridIntent` | show/hide the **dot grid** |
| `CRLChangeBoardObjectConnectorsIntent` | show/hide the **object connectors** (= the lines between objects) |
| `CRLChangeSelectionColorIntent` | fill colour of the selection |
| `CRLChangeSelectionFontSizeIntent` / `_FontStyleIntent` | font size / style |
| `CRLResizeSelectionFontIntent` (+ `_v2`) | resize the selected text |
| `CRLUtilitiesIntent` | the internal one (= board id, **export a board to a local `.freeform` file**, import a sideloaded board, share, accept a share, stop sharing) |

`CRLAddStickyNoteToBoardIntent` and `CRLAddTextToBoardIntent` exist but carry `deprecationMetadata` = *"This app intent is scheduled to be deleted"*, replaced by `CRLAddItemToBoardIntent`.

**`CRLAddItemToBoardIntent`** — the one that matters:

| Parameter | Type | Required |
| --- | --- | --- |
| `target` | `CRLBoardEntity` | yes |
| `itemType` | `CRLCanvasItemType` | no |
| `text` | `String` | no |
| `mediaItems` | `[IntentFile]` (`public.item`) | yes |
| `url` | `URL` | no |

`openAppWhenRun: false` — **the intent runs without bringing Freeform forward**. Output is a `CRLBoardEntity`. It also declares an assistant-defined schema in the `whiteboard` domain (`CreateCanvasItemIntent`).

**`CRLCanvasItemType`** — Apple's own item taxonomy, ten cases:

`circle`, `line`, `roundedRectangle`, `square`, `stickyNote`, `star`, `textBox`, `triangle`, `url`, `media`

**`CRLBoardEntity`** — the board as an assistant entity: `title`, `creationDate` (Spotlight `contentCreationDate`), `lastModificationDate` (Spotlight `contentModificationDate`), `isFavorite`, `isCanvasDotGridEnabled`, `isConnectorModeEnabled`. System protocols: `URLRepresentable`, `Syncable`, `AssistantEntity`, `Indexed`. Exportable as a CloudKit sharing container (`com.apple.cloudkit.sharingsupport.container`).

**The remaining enums** are a ready-made design vocabulary: `CRLShapeTypeEnum` (circle, line, roundedRectangle, square, star, triangle), `CRLColorEnum` (black, blue, gray, green, orange, purple, red, yellow), `CRLFontSizeEnum` (10, 12, 14, 18, 24, 36, 48, 72, 96, 144), `CRLFontStyleEnum` (bold, italic, underline, strikethrough), `CRLLineEndTypeEntity` (11 arrow/circle/square shapes + none), `CRLLineRoutingTypeEntity` (`quadratic` = curved, `orthogonal` = right-angle), `CRLSizeChangeOperation`, `CRLVisibilityOperation` (show/hide/toggle), `CRLFavoriteOperation`.

### 2.6 What Freeform is built on, read out of the binary

The `CRL` prefix marks Apple's internal classes:

| Area | Classes |
| --- | --- |
| Canvas | `CRLCanvas`, `CRLCanvasRep`, `CRLCanvasLayout`, `CRLCanvasElementInfo`, `CRLCanvasInfoGeometry`, `CRLCanvasLayer`, `CRLCanvasKnob` (= the resize handles), `CRLCanvasEditor`, `CRLCanvasRenderable`, `CRLCanvasGuideController`, `CRLInteractiveCanvasController`, `CRLMacCanvasViewController` |
| Board | `CRLBoard`, `CRLBoardItemImporter`, `BoardItems`, `BoardItem` |
| Shapes | `CRLShapeLayout`, `CRLShapeRep`, `CRLShapeLibrary`, `CRLShapeLibrarian*` (= an Apple shape catalog with categories and keywords) |
| Ink | `CRLFreehandDrawingToolkitUIState`, `CRLFreehandDrawingRep`, `CRLFreehandDrawingTracker`, `CRLFreehandDrawingToolFillAndLegacyStroke`, `CRLFreehandDrawingToolPixelEraser`, **`CRLPKDrawingProvider`** (= the PencilKit seam) |
| Export | `CRLCanvasExporter`, `CRLCLExport`, `CRLCLShapeExporter`, `CRLCLStrokeExporter`, `CRLCLFillExporter`, `CRLUSDExporterItem`, `CRLUSDExporterRequest` (= 3D boards export as USD) |
| Sync | `CRLCloudKitShareNameHelper`, `CRLAcceptCloudKitShareAttempt`, and a sync engine that fetches "record zone changes from CloudKit" |

**The model is flat**: a board holds a list of items, each item carries geometry (`CRLCanvasInfoGeometry`) and layout (`CRLCanvasLayout`). There is no tree and no ordered list. The board's own flags (`isCanvasDotGridEnabled`, `isConnectorModeEnabled`) are board-level, the way Milanote's `showGrid` and `connectWithLines` are preferences.

**Persistence is CloudKit record zones**, not a published file format: the sync engine works in "record change sets" and "record zone changes", and the group's container is empty on a machine that has never opened a board. The `.freeform` package is produced by the `exportBoard` utility operation, and its layout is not documented.

## 3. The Apple canonical answer

Checked in the installed SDK (`MacOSX27.2.sdk`), because the rule is to quote a signature that exists, not one remembered.

| Need | Canonical symbol | Verified fact |
| --- | --- | --- |
| Drawing data | `PencilKit.PKDrawing` | `public struct PKDrawing : Sendable`, `@available(iOS 13.0, macOS 10.15, *)`; `PKStroke`, `PKInk`, `PKInkingTool`, `PKEraserTool`, `PKLassoTool`; `PKDrawing.draw(in:frame:from:darkUserInterfaceStyle:) async` |
| Drawing view | **none on macOS** | There is **no public `PKCanvasView`** in the macOS SDK — the only occurrence is a doc comment in `PKTool.h` ("An interaction behavior for a PKCanvasView"). macOS gets the data model, not the canvas. |
| Canvas view | `SwiftUICore.Canvas` | `nonisolated public struct Canvas<Symbols> : ~Sendable where Symbols : SwiftUICore::View`; `SwiftUICore.GraphicsContext`; `SwiftUICore.ImageRenderer` |
| Image generation | `ImagePlayground` | `@MainActor public func imagePlaygroundSheet(isPresented: Binding<Bool>, concepts: [ImagePlaygroundConcept] = [], sourceImage: Image? = nil, onCompletion: @escaping (URL) -> Void, onCancellation: (() -> Void)? = nil) -> some View` (macOS 15.1+) |
| Image generation, programmatic | `ImagePlayground.ImageCreator` | `@available(iOS 18.4, macOS 15.4, *)` **and deprecated in 27.0**: "Use ImagePlaygroundViewController or imagePlaygroundSheet." `public init() async throws`; `images(for:style:limit:) -> some AsyncSequence<CreatedImage, any Error>`; `CreatedImage.cgImage` |
| Card grid | `SwiftUI.LazyVGrid`, `SwiftUI.Grid` | present in the SDK |
| Ordered list with reorder | `SwiftUI.List` + `.onMove` | present in the SDK |
| Drag and drop | `.draggable` / `.dropDestination` + `Transferable` | present in the SDK |
| Rich text | `SwiftUI.TextEditor` | `nonisolated public struct TextEditor : SwiftUICore.View` |
| Table | `SwiftUI.Table` | present in the SDK |
| Board as a package | Wenshu `.ws` / `WSPC` | already the shape; matches `com.apple.freeform.board` |

Wenshu's floor is `platforms: [.macOS(.v27)]` (Package.swift), so every row above is available with no availability gate — except where noted.

### 16.1 The consequence for the content generation view

`ImageCreator` is the programmatic path and it is **deprecated on Wenshu's own floor**. So the canonical route is the sheet (SwiftUI) or `ImagePlaygroundViewController` (AppKit), and the generated image arrives as a **file URL** (`onCompletion: @escaping (URL) -> Void`), not as a `CGImage`.

That is a design decision with consequences, not a detail: a generation view that produces several candidate images has to write them to disk (or to the app's own storage) before it can attach them to a card. A card image is then a **file reference**, like Milanote's `content.image.regular` / `.thumb` URL ladder and `content.file.url`.

### 16.2 What Apple does not ship

- **No ordered-list board.** Freeform is canvas-only. The card-based chapter organization Milanote models has no Apple equivalent — Wenshu's chapter list is Wenshu's own design, and the Apple-canonical container for it is `List` + `.onMove` (or `LazyVGrid` for a board view), not a free canvas.
- **No canvas view on macOS.** If Wenshu ever wants a Freeform-like ink surface, it hand-rolls it on `SwiftUICore.Canvas` and stores `PKDrawing` data. That is a real cost and it is why §17 says the canvas regime is out of v1 scope.
- **No public Freeform file format.** The UTI is declared, the package layout is not documented.

