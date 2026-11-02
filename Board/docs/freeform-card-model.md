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

### 3.1 The infinite canvas: the pieces, and the product Apple does not ship

The question "Apple has not opened it, so can we write one" was answered by
reading the SDK, not by remembering it.

| Piece | Symbol | Verified fact |
| --- | --- | --- |
| The drawing surface | `SwiftUICore.Canvas` | `nonisolated public struct Canvas<Symbols> : ~Sendable where Symbols : SwiftUICore::View`; `init(opaque:colorMode:rendersAsynchronously:renderer:symbols:)`; the renderer receives `inout GraphicsContext` and `CGSize`. It is a drawing surface, not a pan-and-zoom plane. |
| The zoom gesture | `MagnifyGesture` | `nonisolated public struct MagnifyGesture : SwiftUICore.Gesture, ~Swift::Sendable`; `Value.magnification: CGFloat`, `Value.time: Date` |
| The pan gesture | `DragGesture` | `public struct DragGesture : SwiftUICore.Gesture, ~Swift::Sendable` |
| The viewport | `ScrollGeometry` | `public struct ScrollGeometry : Swift::Equatable, Swift::Sendable` with `contentOffset`, `contentSize`, `contentInsets`, `containerSize`, `visibleRect`; read by `onScrollGeometryChange(for:of:action:)` |
| The layer order | `zIndex(_:)` | `nonisolated public func zIndex(_ value: Swift::Double) -> some SwiftUICore.View` |
| The offscreen composite | `drawingGroup(opaque:colorMode:)` | `nonisolated public func drawingGroup(opaque: Swift::Bool = false, colorMode: SwiftUICore.ColorRenderingMode = .nonLinear) -> some SwiftUICore.View` |
| **The infinite canvas** | **none** | There is no public infinite-canvas view on macOS, and macOS 27 adds none: the only 2025+ canvas-shaped symbols in `SwiftUICore` are visionOS's `onWorldRecenter` and `WorldScalingBehavior`, which are not macOS. |

**What Freeform does with the pieces.** Freeform links Metal and PencilKit
(§2.6) and builds its canvas out of private `CRL*` classes —
`CRLCanvasItemView`, `CRLCanvasView` — with `CRLPKDrawingProvider` supplying
the ink. None of that is public, so none of it can be borrowed; only the
vocabulary can.

**So the client writes it**, and the write is this shape:

1. A world coordinate space and a viewport that maps it to the screen: a
   scale and an offset (`BoardViewport`).
2. The items placed in the world, and the world layer scaled and offset as one
   transform, so the items keep their positions relative to each other and
   SwiftUI hit tests them in the transformed space for free.
3. The zoom **computed, not applied**: a zoom that keeps the world point under
   the anchor under the anchor (`zoomed(to:about:)`).
4. The cull: an item off screen is neither drawn nor hit tested
   (`visibleWorldRect(in:)`, `isVisible(_:in:)`).
5. The dot grid drawn in world space, so it scales with the board (`Canvas`
   plus `GraphicsContext`).

The arithmetic is a pure function, so it is proven by tests that need no
window, and the whole view is proven by an offscreen `ImageRenderer` render: a
bitmap, with no window and no human in it.

**Still not borrowed:** the collision reflow, the locked position, the 3D drag
effects, the connector mode.

### 16.1 The consequence for the content generation view

`ImageCreator` is the programmatic path and it is **deprecated on Wenshu's own floor**. So the canonical route is the sheet (SwiftUI) or `ImagePlaygroundViewController` (AppKit), and the generated image arrives as a **file URL** (`onCompletion: @escaping (URL) -> Void`), not as a `CGImage`.

That is a design decision with consequences, not a detail: a generation view that produces several candidate images has to write them to disk (or to the app's own storage) before it can attach them to a card. A card image is then a **file reference**, like Milanote's `content.image.regular` / `.thumb` URL ladder and `content.file.url`.

### 16.2 What Apple does not ship

- **No ordered-list board.** Freeform is canvas-only. The card-based chapter organization Milanote models has no Apple equivalent — Wenshu's chapter list is Wenshu's own design, and the Apple-canonical container for it is `List` + `.onMove` (or `LazyVGrid` for a board view), not a free canvas.
- **No canvas view on macOS.** If Wenshu ever wants a Freeform-like ink surface, it hand-rolls it on `SwiftUICore.Canvas` and stores `PKDrawing` data. That is a real cost and it is why §17 says the canvas regime is out of v1 scope.
- **No public Freeform file format.** The UTI is declared, the package layout is not documented.

## 4. The canvas implementation, read out of the binary

### 4.1 The method, and why it is cheap

Freeform is Objective-C, so its class metadata is in the Mach-O. The whole
canvas vocabulary is recoverable without a decompiler:

```bash
lipo -thin arm64e /System/Applications/Freeform.app/Contents/MacOS/Freeform -output ff.arm64e
otool -oV ff.arm64e > ff.objc.txt        # 0.24 s, 19 MB, 422,590 lines
```

`otool -oV` prints the class names, the **ivar names** and the **property
names** as text, so no pointer chasing is needed for the model. What it does
not print is the selector behind a relative method list (those selectors live
in the dyld shared cache), so the method bodies are out of reach here and the
decompiler route is the only one for them — Ghidra did not finish importing
this 57 MB binary inside its 900 s deadline.

What came out: **959 `CRL*` classes, 94 of them `CRLCanvas*`, 3,320 ivars and
4,634 properties.**

### 4.2 The geometry of one item

`CRLCanvasInfoGeometry` is the geometry of a canvas item, and it is small:

| | |
| --- | --- |
| ivars | `_position` (CGPoint), `_size` (CGSize), `_flags` (a bit field) |
| properties | `position`, `size`, `widthValid`, `heightValid`, `horizontalFlip`, `verticalFlip`, `angle`, `boundsBeforeRotation`, `center`, `transform`, `transformWithoutFlips`, `transformedBounds`, `transformedBoundsOrigin`, `fullTransform`, `allValuesValidNumbers` |

So an item is **a position, a size, an angle and two flip flags**, plus the
transforms derived from them. There is no scale and no matrix in the item
itself: the transform is computed.

### 4.3 The canvas is a layout tree, and a live edit is not a write

`CRLCanvasAbstractLayout` is the tree node, and the property list is the
design:

| Group | Properties |
| --- | --- |
| The chain to the world | `geometry`, `transform`, `frame`, `geometryInParent`, `transformInParent`, `frameInParent`, `geometryInRoot`, `transformInRoot`, `frameInRoot`, `clipRect`, `alignmentFrame`, `alignmentFrameInParent`, `alignmentFrameInRoot` |
| The tree | `parent`, `root`, `children`, `visibleGeometries`, `isAxisAlignedUnflippedInRoot`, `providesGuidesForChildLayouts`, `exclusivelyProvidesGuidesForChildLayouts` |
| The cull | `frameForCulling`, `frameForCullingInRoot`, `shouldBeIncludedInParentFrameForCulling` |
| The live edit | `interimPositionX`, `interimPositionY`, `lastInterimPosition`, `alignmentFrameOriginForFixingInterimPosition`, `shouldSnapWhileResizing` |
| Capabilities | `supportsRotation`, `supportsFlipping`, `supportsCalloutAttributes` |

`CRLCanvasLayout` is the concrete node, and it carries the answer to the drag
question:

| | |
| --- | --- |
| the committed geometry | `info`, `originalGeometry`, `originalTransformInRoot`, `originalPureGeometry`, `pureGeometryInRoot` |
| the live geometry | `dynamicGeometry`, `freeTransformState`, `isInRealTimeDynamicOperation`, `isBeingTransformed`, `isBeingManipulated` |
| the commit | `infoGeometryForCommitingAnchorHintAtEndOfDynamicOperation` |
| the dependency graph | `dependentLayouts`, `dependentLayoutsForDrag`, `bidirectionalSizeDependentLayouts`, `reliedOnLayouts` |

**A manipulation keeps a dynamic geometry beside the committed one, and only
the committed one is written.** The commit happens at the end of the operation
(`...ForCommitingAnchorHintAtEndOfDynamicOperation`), and the original is
restored if the operation is abandoned. Milanote does the same thing with
`ELEMENT_EDIT_START` / `ELEMENT_EDIT_COMPLETE` (the other teardown §11.4).

Two consequences for a replica:

- The live manipulation is **client state**, so a drag does not write the
  library. This is what makes an infinite canvas compatible with one library,
  one writer.
- The tree means a nested item's position is **relative to its parent**, with
  `frameInRoot` as the absolute answer. A flat list of world coordinates
  cannot express a group that moves with its parent.

### 4.4 The snapping system is six independent guides

`CRLCanvasGuideController` is the snap controller, and its switches are the
feature list:

```
shouldAlignToSizingGuides      shouldAlignToSpacingGuides
shouldAlignEdges               shouldAlignCenters
shouldSnapToGrid               shouldAlignEdgesToTemplateGuides
shouldUseHapticFeedbackWhenSnapping
snapDistanceToUseForGuides     guideColor / defaultGuideColor
```

Its state keeps the generated guides apart by kind: `_verticalSpacings`,
`_horizontalSpacings`, `_verticalSizingGuides`, `_alignmentFrameInRootByLayout`,
plus `_didJustSnapInX` / `_didJustSnapInY` (so the client can tell a snap from
a free move).

`CRLCanvasAlignmentGuide` is one guide: `renderable`, `start`, `end`,
`guideType`, `infinite`, `snapsToMin`, `snapsToMid`, `snapsToMax`.

So snapping is **not one behaviour but six**, each independently switchable,
and a guide can bind to an item's minimum, middle or maximum edge.

### 4.5 The zoom model: the scale is a view concern, and it snaps

`CRLCanvasLayer` is the viewport:

```
viewScale, unscaledSize, unscaledContentCenter,
minimumPinchViewScale, maximumPinchViewScale,
allowsPinchZoom, showsScaleFeedback, infinite,
contentInset, centeredInScrollView, horizontallyCenteredInScrollView, verticallyCenteredInScrollView
```

Three facts worth copying:

- **The model is stored in unscaled units.** `unscaledSize` and
  `unscaledContentCenter` are the content; `viewScale` is the view. The
  client's `BoardViewport` (a scale and an offset) is the same split.
- **`infinite` is a property of the layer**, so "the canvas is infinite" is a
  mode, not a metaphor.
- The zoom bounds are `minimumPinchViewScale` / `maximumPinchViewScale`, and
  the scale is pinned to a ladder rather than free.

`CRLCanvasZoomTracker` is where the pinning lives:

```
fastPinchSnapsViewScale, slowPinchSnapsViewScale, currentlySnappingViewScale,
gestureIsFastPinch, animateTransform, visibleUnscaledBoundsAtEndOfZoom,
alwaysUsesTranslationSprings
```

**A fast pinch snaps the view scale to the ladder; a slow pinch is continuous.**
The tracker knows which one is happening (`gestureIsFastPinch`) and animates
the snap (`currentlySnappingViewScale`, `animateTransform`). A replica that
only does continuous zoom will feel different in the hand, and this is why.

### 4.6 Autoscroll, connectors, and the data/view split

- **`CRLCanvasAutoscroll`**: `target`, `unscaledAutoscrollPoint`,
  `adjustedUnscaledAutoscrollPoint`, `lastAutoscrollDelta`, `directions`,
  `repeatInterval`, `count`, `unscaledDistancePastVisibleRect`,
  `unscaledInset`. Dragging near an edge scrolls the world, and the
  distances are in **unscaled** units, so the threshold is zoom-independent.
- **`CRLConnectionLineAbstractLayout`** is the connector, and it is a layout
  like any other: `connectedFrom`, `connectedTo`, `connectedFromInfo`,
  `temporaryConnectedFromInfo`, `validLine`, `headMagnetType`,
  `tailMagnetType`, `headMagnetNormalizedPosition`,
  `tailMagnetNormalizedPosition`, `headMagnetCanvasPosition`,
  `tailMagnetCanvasPosition`, `clipHead`, `clipTail`, `headClipT`,
  `tailClipT`, `magnetsAdjusted`. A connector's endpoint binds to a
  **normalized position** on another item's edge, and the line is clipped at
  the target.
- **`CRLBoardItemLayout`** is the seam between the data and the view: it
  holds `boardItem`, `hasAlpha` and `geometry`. **The item is the data; the
  layout is its positioned view.** The two are separate objects, which is why
  a drag can change the layout without touching the item.
- **`CRLBoardItemEditor`** enumerates what a selection can be asked to do:
  `selectedObjectsSupportingFill`, `...Stroke`, `...Shadow`,
  `...Reflection`, `...Opacity`, `...Rotation`, `...Resize`,
  `...ShrinkTextToFit`, `...CalloutAttributes`, `...Attribution`,
  `...FreehandAnimations`, `...TextInset`, `...Endpoints`,
  `...ConnectionLineAttributes`, `...SmartShapeAttributes`, and
  `anyLayoutHasUnlockedAspectRatio`. That list is the item feature surface.

### 4.7 PencilKit on macOS: the exact position

The earlier reading of this teardown said the drawing view is not public on
macOS. The precise statement, after reading the SDK and the binary:

| Fact | Evidence |
| --- | --- |
| `PKCanvasView` **exists and is exported** on macOS | `PencilKit.tbd`: `objc-classes: [ PKCanvasView, ... ]` |
| Apple **ships no header** for it on macOS | the SDK's PencilKit `Headers/` has no `PKCanvasView.h`, and `PencilKit.h` line 11 `#import`s `<PencilKit/PKCanvasView.h>` — a file the SDK does not contain |
| The macOS **Swift interface** does not expose it | `PencilKit.swiftmodule/arm64e-apple-macos.swiftinterface` declares `PKDrawing`, `PKStroke`, `PKStrokePath`, `PKStrokePoint`, `PKInk`, `PKInkingTool`, `PKEraserTool`, `PKLassoTool`, `PKTool`, `PKStrokeRecognizer`, `EraserType`, `InkType`, `Stride`, `RenderState`, `SearchResult`, `ConvertedBezierPoint`, `InterpolatedSlice` — and no `PKCanvasView` |
| Freeform **uses it anyway** | the binary carries `$__lazy_storage_$_pencilKitCanvasView` |

So the class is reachable at runtime and unreachable from a compiling app
without hand-declaring a private interface. The client does not take that
route (it is a private API dependency), and the public macOS PencilKit still
gives it what it needs:

```
PKDrawing.dataRepresentation()
PKDrawing.imageFromRect(_:scale:)      → NSImage on macOS
PKDrawing.drawingByApplyingTransform(_:)
PKDrawing.drawingByAppendingStrokes(_:)
PKDrawing.drawingByErasingStrokePath(_:mask:transform:)   (macOS 27)
```

**The ink layer is therefore buildable on public API**: `PKDrawing` for the
data, `imageFromRect:scale:` to rasterise, and the strokes drawn on a
`SwiftUICore.Canvas` with the client's own gesture handling.

### 4.8 What is still not dug

- The `.board` package format. The app has never run on this machine (its
  container is empty), so no board exists to inspect, and the archiving code
  is Swift (`$__lazy_storage_$_taskForArchivingBoardItems`) rather than
  Objective-C, so it is not in the class dump.
- The method bodies. The selectors behind the relative method lists live in
  the dyld shared cache; Ghidra did not finish this binary inside its
  deadline.
- The live behaviour: no board was created, so nothing was measured in the
  running app.
