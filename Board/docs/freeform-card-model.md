# Apple Freeform — Card Model Teardown

Date: 2026-11-02
Target: `/System/Applications/Freeform.app`, version **5.0** (build 656.1.2), bundle id `com.apple.freeform`. The app ships localized names; on this machine it runs Chinese-localized, which is why the menus in §5.3 were read in Chinese.
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

`/System/Applications/Freeform.app`, version **5.0** (build 656.1.2), bundle id `com.apple.freeform`. The app ships localized names; on this machine it runs Chinese-localized, which is why the menus in §5.3 were read in Chinese.

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

## 5. The running app: what it holds and what it measures

### 5.1 A Freeform board has no local file

The app had never run on this machine (its container held exactly one file, the
container metadata plist). Launched in the background it immediately showed
**85 boards**, all of them real and all of them synced from iCloud — and after
the launch the container still held **one file**.

| Fact | Consequence |
| --- | --- |
| 85 boards, none of them local | The board list and the boards live in CloudKit; the container is not a cache of them. |
| The container stays empty | There is no local board file to inspect, on any board. |
| macOS Freeform never writes a `.board` | See §5.4: the format is an **import** format on macOS. |

### 5.2 What the running app measures

Measured on a real board (a service-architecture diagram), at the zoom the app
had stored for it (25%):

| Measurement | Value | How |
| --- | --- | --- |
| The dot grid | **74.1 pt** in world units | The dot period measured off the screenshot by autocorrelation (20 image px, correlation 0.983); the capture is 1.0798 image px per point (1568 px for a 1452 pt window); 20 / 1.0798 / 0.25 |
| The item sizes | **130×51 pt** (×28), **80×29** (×19), **116×29** (×8), **283×51** (×4), **98×29** (×3) | 62 `AXLayoutItem` frames are screen points, so the world size is the frame / 0.25 |
| The horizontal pitch between adjacent boxes | **151 pt**, exactly (world x = 0, 151, 302, 453) | the same frames |

The sizes are quantized and the pitch is exact, which is the signature of a
snapped layout: the items sit on a lattice, and the lattice is what a replica
has to reproduce, not the individual boxes.

The zoom control is an `AXMenuButton` whose value is the percentage (25% here),
flanked by `Zoom Out` and `Zoom In` and a fit button (a star in a
square). **The zoom is a menu of levels, not a free field** — which is the
other half of the §4.5 finding that a fast pinch snaps the scale.

The three canvas toggles are toolbar buttons, and their help strings say what
they do: `Grid` (help "hide the dot grid"), `Connector` (help "show connectors to
connect objects easily"), `Show Scene Navigator`.

### 5.3 The whole command surface, read out of the live app

The app runs Chinese-localized on this machine; the items below are Apple's own
English names for the same commands, and the live tree also carries each
item's action identifier (`_NS:1121`, `didTriggerSubscriptionManagementMenuItem`,
...), which is language independent.

| Menu | Items |
| --- | --- |
| Insert | Sticky Note, Shapes, Text Box, Table, Draw, Line, Line with Arrow, Connector, Browse Media, Photo or Video, Link, Import from iPhone or iPad, Choose File |
| Shapes (submenu) | Rectangle, Rounded Rectangle, Oval, Triangle, Right Triangle, Arrow, Double Arrow, Diamond, Speech Bubble |
| Format | Font, Text, Indent, Shape and Line, Table, Image, Draw, Shadow, Corner Radius, Loop, Copy Style, Paste Style, Save as Insert Style, Use Light Background, Show Color |
| Arrange | Bring Forward, Bring to Front, Send Backward, Send to Back, Align Objects, Distribute Objects, Lock, Unlock, Move Object to Board, Group, Ungroup, Force Aspect Ratio |
| View | Icon View, List View, Sort By, Use Groups, Show Content Center, **Show Connectors**, **Hide Grid**, **Snap to Grid Guides**, **Zoom Scene**, Hide Collaboration Activity, Hide Tab Bar, Show All Tabs, Show Sidebar, Enter Full Screen |
| File | New Board, New Folder, New Folder with Selected Items, New Tab, New Window, Close, Close All, Delete, Duplicate, Add to Favorites, **Export Board as PDF…**, **Export Scene as PDF…**, **Share…**, Manage Shared Boards…, Print Board…, Print Scene… |

The four canvas-mode switches are **Show Connectors / Hide Grid / Snap to Grid Guides
/ Zoom Scene** — the same four the model in §4 names: the connector, the grid,
the guides, and the zoom.

### 5.4 The `.board` package: an import format on macOS, and that is the whole answer

| Evidence | Says |
| --- | --- |
| The UTI is declared: `com.apple.freeform.board`, a package conforming to `public.data` + `public.composite-content`, extension `.board` | The format exists and is a package, not a file |
| The binary carries `Open Freeform Board`, `Create New Freeform Board`, `com.apple.freeform.boardLibrary`, and `.boardIdentifierMustBeOwnerForCreation` | The app **opens** and **creates from** a `.board`, and the file carries an identifier whose creator must be the owner |
| The File menu has **no** export-to-`.board` item | It offers Export Board as PDF…, Export Scene as PDF…, Share…, Print Board… and Print Scene…, and nothing else |

**So on macOS a `.board` is what Freeform opens and creates from, and not
something it writes.** The export path iOS has (the share sheet's "Export as
Freeform Board") is not in the macOS menus, and no board on this machine has a
local file either (§5.1).

⇒ **The package format cannot be sampled from the macOS app at all.** A sample
would have to come from an iOS export or from the format's producer. The client
does not need it (ADR-0034's sibling rule: no freeform file format), so this is
a **closed question**, not a gap — and the honest thing to record is why it
cannot be closed by measurement on this platform.

### 5.5 The accessibility surface of a canvas item

- Each canvas item is one `AXLayoutItem` whose label is `<text>, <shape>`
  (e.g. "<text>, Rectangle"), with an `AXTextArea` child carrying the item's text.
- Its actions are `crlaxrotateclockwise` and `crlaxrotatecounterclockwise`,
  plus "show formatting options" and "edit text".
- The zoom, the connector and the grid are `AXButton` / `AXMenuButton` with
  Chinese help strings, and the tree exposes the whole menu bar with its
  action identifiers (`_NS:1121`, `didTriggerSubscriptionManagementMenuItem`,
  …).
- ⇒ An accessible replica has to expose the item as one object with an
  editable text child and named rotate actions — the same shape the reference
  does.

### 5.6 What could not be driven, and why

The canvas's floating controls (the zoom −/+, the zoom level, the grid toggle,
the connector toggle, the share button) **do not respond to background input**:
a background mouse event posts successfully and changes nothing, and an
AXPress reports success and changes nothing. The app is not the key
application, and Freeform's canvas overlay handles its own events.

`focus_app` is refused by the driver itself ("no reviewed risk classification"),
and foreground delivery needs the operator's approval.

⇒ The measurements in §5.2 are the ones that need no input: the geometry, the
menus, the accessibility surface. The interactive behaviours — the zoom
ladder's actual levels, the snap while dragging, the connector's magnet
behaviour — remain **measured from the model in §4, not from the running app**.

## 6. The method-level map

### 6.1 How it was built, and why it was needed

Freeform's canvas classes are **Swift with an Objective-C face**. The
Objective-C metadata in the Mach-O carries every method's implementation
pointer, and the selector behind that pointer is a chained pointer whose low
32 bits are an offset **from the image base (0x100000000)** — into the
image's own `__TEXT`, not into the shared cache. Resolving that gives, for
every method:

> (class, selector, Objective-C type encoding, entry point)

**955 classes, 21,580 methods, 1,762 of them geometry-relevant.**

The binary is stripped, so no symbol carries the class names: Ghidra's
function manager names the implementations `FUN_xxxxxxxx`, and a filter on the
name finds nothing. The map above is what makes the bodies reachable at all
— the decompiler is then addressed by the entry point.

### 6.2 The geometry classes

| Class | Methods | What it is |
| --- | --- | --- |
| `CRLCanvasInfoGeometry` | 47 | the geometry of one item: position, size, angle, two flips |
| `CRLCanvasMutableInfoGeometry` | 10 | the mutable half of the geometry |
| `CRLCanvasAbstractLayout` | 68 | the layout tree: the chain to the root, the clip, the cull |
| `CRLCanvasGuideController` | 66 | the snapping controller |
| `CRLCanvasAlignmentGuide` | 25 | one guide |
| `CRLCanvasSpacing` | 14 | a spacing guide |
| `CRLCanvasLayer` | 60 | the viewport layer |
| `CRLCanvasZoomTracker` | 17 | the zoom gesture |
| `CRLCanvasAutoscroll` | 25 | the edge autoscroll |

### 6.3 The entry points that matter

| What | Selector and signature |
| --- | --- |
| **The snap** | `snapRectToGuides:forKnobTag:snapSize:` → `CGPoint` (the snap delta, not the snapped rect) |
| **The snap, with a knob tag** | `snapRectToGuides:forKnobTag:` |
| **The guides** | `showGuidesAlignedWithRect:shouldRenderX:shouldRenderY:` |
| **The sizing guides** | `showSizingGuideUIForRep:matchingWidth:matchingHeight:` |
| **The snap threshold** | `snapDistanceToUseForGuides` → `double` |
| **The snap ceiling** | `p_maxSnapForSnapDistance:` |
| **The zoom** | `zoomWithScale:velocity:locationInView:phase:` — the phase is an enum, so the gesture has stages |
| **The zoom's end** | `p_finishZoomWithFinalScaleFactor:contentOffset:` |
| **The autoscroll's step** | `p_unscaledDeltaForCount:` → `CGPoint` |
| **The autoscroll's decision** | `p_autoscrollIfPossibleWithDelta:` |
| **The geometry** | `initWithPosition:size:widthValid:heightValid:horizontalFlip:verticalFlip:` |
| **A guide** | `initWithGeneratingObjectUnscaledRect:edge:` and `initWithType:offset:` |
| **A guide's hit test** | `canBeSnappedToByEdge:ofFrame:inVisibleUnscaledRect:` |
| **A spacing guide** | `initWithGuideType:withSpacingRect:forFrame:andFrame:` |

Three of these are worth naming out, because they are the answers to questions
the earlier sections only hinted at:

- **The snap returns a delta, not a position.** `snapRectToGuides:...` returns
  a `CGPoint`, so the caller applies the offset. The snapping is therefore a
  pure function of the rect, the guides and the knob tag, and the knob tag is
  what tells it which edge or handle is being dragged.
- **The zoom gesture has phases.** `zoomWithScale:velocity:locationInView:phase:`
  takes a phase enum and a velocity, and there is a separate
  `p_finishZoomWithFinalScaleFactor:contentOffset:` for the end of the
  gesture. The scale is committed at the end, which is the same live-edit
  discipline as the layout (§4.3).
- **The autoscroll is in unscaled units.** `p_unscaledDeltaForCount:` returns
  an unscaled `CGPoint`, so the autoscroll step does not change with the
  zoom.

### 6.4 The one gap in this map, and how it was closed

The dot-grid classes (`CRLCanvasDotGridLayer`, `CRLCanvasDotGridBackground`,
`CRLCanvasDotGridLayerImageStorage`) appear in the class-name strings but
carry **no Objective-C methods**: they are Swift classes with no
Objective-C face, so their implementations are not in the Objective-C
metadata and the map above does not reach them.

They were reached anyway, and §8.1 has the result. The route is that a
Swift class's **names** are plain text in the binary's reflection strings,
and a Swift global constant can be exposed to Objective-C — so
`kCRLUnscaledSpacingBetweenDotCenters` appears in the map after all, as a
method that returns `25.0`. The lesson is narrower than "the map is
complete": **the map covers the Objective-C surface, and a class with no
Objective-C surface needs a different route.**
## 7. The method bodies

512 of the mapped methods were decompiled (all 512 succeeded). The bodies are
readable because the decompiler renders every Objective-C message as a named
call, so a body reads as a message flow.

### 7.1 The geometry is derived, not stored

`CRLCanvasInfoGeometry` stores three things — `_position`, `_size`, `_flags` —
and everything else is computed:

| Selector | What the body does |
| --- | --- |
| `boundsBeforeRotation` | `position` → `size` → `CGRectWithOriginAndSize` |
| `center` | `boundsBeforeRotation` → `NSCenterOfRect` |
| `transform` | `boundsBeforeRotation` → `transformBasedOnRect:` |

⇒ **An item's transform is a function of its rect, not a fourth stored
value.** A replica that stores a transform has to keep it consistent with the
rect; the reference never has to.

The convenience initialiser shows the defaults:
`initWithPosition:size:` forwards to
`initWithPosition:size:widthValid:heightValid:horizontalFlip:verticalFlip:angle:`
with **widthValid = 1, heightValid = 1, horizontalFlip = 0, verticalFlip = 0** —
the size is valid by default and there is no flip.

### 7.2 The snap distance is 7 points

`snapDistanceToUseForGuides` returns **7.0**, unless the canvas background has
an alignment provider, in which case the background's value is asked for
instead. The body reads:

```
if (isCanvasBackgroundAlignmentSnappingEnabled) {
    if (canvasBackground.alignmentProvider == nil) return 7.0;
    return alignmentProvider.<ask>(1.0);
}
return 7.0;
```

⇒ **The reference's snap threshold is 7 pt in world units**, and it is
overridable by whatever owns the canvas background. That is a number a
replica can copy outright, and it is the kind of number that is impossible to
guess.

### 7.3 The autoscroll's step is 60 units, time-scaled and eased

`p_unscaledDeltaForCount:` is the autoscroll's per-tick step, and the body has
three constants in it:

```
step = 60.0;                                  // the base step
if (target responds to maximumAutoscrollDeltaForCount:) {
    step = target.maximumAutoscrollDeltaForCount(count);   // the target may override
}
step = (long)(step * ((now - lastTick) / interval));        // scaled by the elapsed time
if (count <= 0x18) {
    step = (long)((1.0f / (0x1a - count)) * (float)step);  // divided by (26 - count)
}
```

⇒ The autoscroll's base step is **60 unscaled units per tick**, the step
**scales with the elapsed time** so the motion is not frame-dependent, and it
is **divided by (26 − count)** so the ramp eases as the tick count grows. The
target may override the base step entirely.

### 7.4 The zoom is a phase machine over an affine transform

`zoomWithScale:velocity:locationInView:phase:` is the longest body in the
canvas, and its shape is:

```
cancelPreviousPerformRequestsWithTarget:selector:object:
controller → enclosingScrollView → canvasView
… setAffineTransform: …
… setDynamicTransform: …
associatedBackgroundLayer → …
… affineTransform …
… timeIntervalSinceReferenceDate …
viewScale ×3 …
```

⇒ The zoom **cancels the previous in-flight work**, then reads the canvas
view and the enclosing scroll view, applies an **affine transform** to the
canvas view, applies a **dynamic transform** to the background layer, and
reads the current `viewScale` three times over (the ladder's neighbours).
The `phase` enum is what chooses between the branches, which is how a fast
pinch and a slow pinch take different paths without two code paths.

### 7.5 The snap itself is a C function

`snapRectToGuides:forKnobTag:snapSize:` returns a `CGPoint` — **the delta, not
the snapped rect** — and the body is a single call into a private C function
with the rect's origin and a row of flags. So the snapping arithmetic is not
in Objective-C at all, and the Objective-C layer is only the entry point and
the guide bookkeeping.

## 8. The dot grid, the snap tolerance, and the positioning engine

The dot-grid classes carry no Objective-C face, so the earlier map missed
them. Their **names** are plain text in the binary's Swift reflection
strings, though, and one of those names turned out to be the constant that
settles the grid question.

### 8.1 The dot spacing is 25 points, and it is unscaled

`CRLCanvasDotGridLayer` exposes its spacing constant as a method, and the
body is one line:

```c
double CRLCanvasDotGridLayer::kCRLUnscaledSpacingBetweenDotCenters()
{
  return 25.0;
}
```

⇒ **The distance between dot centres is 25 points, in unscaled (world)
coordinates.** The name says "unscaled" on purpose: the dot grid does not
change spacing as the canvas zooms. The dots themselves grow
(`scaledDotDiameter`), so the grid stays put in the world and only its
rendering scales.

The grid measured in the running app had a period of **20 image pixels at
25% zoom**, which is 80 world points — about **3.2 dot centres**. The
source-level fact is the 25; the ratio is an observation, and the gap
between the two is that the visible grid is not the same thing as the dot
spacing. What the source settles, and the measurement cannot, is that the
dot spacing itself is fixed in world coordinates: the constant is unscaled,
so a zoom changes the rendered size of a dot and nothing about the
distance between them. The 80-versus-25 ratio is consistent with a visible
grid drawn every third or fourth dot, and the binary's own
`min-unit-grid-%.3f-%.3f` / `mid-unit-grid-%.3f-%.3f` /
`max-unit-grid-%.3f-%.3f` format strings say the unit grid comes in three
tiers — so the exact multiple is a tier, not a constant, and which tier the
canvas sits in is the open detail.

The rest of the dot grid's surface, from the same name dump:

| What | The name |
| --- | --- |
| The spacing constant | `kCRLUnscaledSpacingBetweenDotCenters` |
| The dot's rendered size | `scaledDotDiameter` |
| The dot count | `columnAndRowCountOfDots` |
| The first dot's offset | `leftAndTopScaledOffsetToCenterOfFirstDot` |
| The grid spacing, per section | `p_gridSpacingForSection:` |
| The preferred grid spacing | `p_preferredGridSpacingForSection:` |
| The per-board visibility | `isCanvasDotGridEnabled`, `setCanvasDotGridVisible(_:)` |
| The menu | `Show/Hide Dot Grid` |

⇒ **The dot grid's visibility is per board**, not per user and not global —
the string `State of the dot grid for a board (shown or hidden)` says so
plainly. A replica that puts the toggle in app settings would be wrong.

### 8.2 The snap tolerance scales with the zoom, through a tanh

`p_maxSnapForSnapDistance:` is the ceiling on how far a card may be pulled
before it snaps, and its body is:

```c
double CRLCanvasGuideController::p_maxSnapForSnapDistance(double snapDistance)
{
    float t = (float)(viewScale - 1.0);
    return snapDistance / (tanhf(t) + 1.0);
}
```

⇒ **The tolerance is the base distance divided by `tanh(viewScale − 1) + 1`.**
With the base distance of 7 pt from §7.2:

| Zoom | `tanh(scale − 1)` | Max snap |
| --- | --- | --- |
| 25% | −0.635 | **19.2 pt** |
| 100% | 0 | **7.0 pt** |
| 400% | 0.995 | **3.5 pt** |

⇒ **Zoomed out, the tolerance is nearly three times the base; zoomed in, it
is half.** The reason is the same in both directions: a fixed world distance
shrinks on screen as you zoom out, so a tolerance that felt right at 100%
would snap to nothing at 25%, and a tolerance that felt right at 25% would
snap to everything at 400%. The curve is `tanh` because it has to be smooth
at 100% and bounded at both ends.

### 8.3 The positioning engine is a C function, like Milanote's

`CRLBoardItemPositioner` is Freeform's counterpart to Milanote's collision
engine, and it has the same shape: the Objective-C layer is a thin wrapper
and the algorithm is in a private C function.

| Selector | What the body does |
| --- | --- |
| `positionBoardItems:` | one call into a private C function with the items |
| `boundsByFittingBoardItem:` | `visibleBoundsForPositioning` |
| `i_boundsForPositioningBoardItem:` | the item's own bounds |
| `canvasBoundsOfBoardItem:` | the item's bounds in canvas space |
| `positionOffset` | the offset the positioner applied |
| `initWithCanvasEditor:targetCenter:validGeometry:` | the positioner's target |

⇒ **Both references keep their collision engine out of Objective-C.** For a
replica this is the cheapest possible outcome: the algorithm can live in
plain Swift with no bridging at all, and the Objective-C surface stays a
single entry point. The difference between the two is not the algorithm but
the unit — Milanote's works in **grid units** (§18.3 of the Milanote
document), Freeform's works against **visible bounds for positioning**.

The positioner's own vocabulary is the clearest statement of what Freeform's
collision engine actually does — 29 methods, of which these are the load
bearing ones:

| Selector | What it says |
| --- | --- |
| `p_infos:collideWithRect:orTargetCenter:` | the collision test — do these items collide with this rect, or with this target centre |
| `p_hasAnyCollisionForIndividualInfos:currentTotalFrame:…` | the collision check, against the running total frame |
| `pPinnedCenter:andSize:toBounds:` | the solve — **pin a centre and a size into bounds** |
| `p_applyFramesToBoardItems:withDelta:` | the commit — apply the solved frames |
| `avoidCollisions` / `setAvoidCollisions:` | collisions are **optional**, not automatic |
| `clampToVisibleBounds` | the clamp to the visible rectangle is also a separate switch |
| `shouldPreserveRelativePositions` | a third switch: keep the items' relative positions |
| `boardItemsToIgnoreForCollisions` | a per-item exclusion list |
| `useOriginalPositions` | ignore the solved positions entirely |
| `resizeItemsToFitContainer:` | the fit variant |
| `positionBoardItemsSpatially:icc:spatialBaseTransform:…` | the spatial variant, with the inter-item spacing context |

⇒ **Freeform's positioning is: detect collisions, then pin the item's centre
and size into the visible bounds, then apply the result.** Three independent
switches (`avoidCollisions`, `clampToVisibleBounds`,
`shouldPreserveRelativePositions`) mean a caller can ask for any subset of
those behaviours.

⇒ **The two references solve the same problem with different shapes.**
Milanote quantises to a grid and cascades neighbours into a column.
Freeform detects a collision and pins the item's centre into the bounds. A
replica that wants Milanote's behaviour of a card nudging its neighbours
cannot get it from Freeform, and vice versa — this is the one place where
copying one reference means deliberately not copying the other.

### 8.4 The drag-time snap starts from the alignment frame

`snapRectForDynamicDragWithOffset:` is one line:

```c
CGRect CRLCanvasRep::snapRectForDynamicDragWithOffset(CGPoint offset)
{
    CGRect r = layout.alignmentFrameInRoot;
    return CGRectOffset(r, offset.x, offset.y);
}
```

⇒ **The drag snap starts from the item's alignment frame in the root, and
offsets it.** The alignment frame — not the raw bounds — is the thing that
snaps, which is what makes a card's *text* line up with a neighbour's *text*
rather than their boxes.

## 9. The layout node, in full

`CRLCanvasLayout` is the base class of the layout tree, and all **214 of its
methods** were decompiled. This is the richest single source in the
reference: it is the shape a canvas's layout layer has to have.

A caveat that applies to every body in this section: the Objective-C method
is a thin wrapper and the arithmetic lives in a private C or Swift function
(`FUN_1013…`). What is visible here is the **protocol** — which calls happen
in which order, which state is read and written — not the arithmetic
itself.

### 9.1 What every layout node must provide

| The node answers | The selector |
| --- | --- |
| Its own geometry | `pureGeometry` |
| The same, in the root's space | `pureGeometryInRoot` |
| The same, in its parent's space | `pureGeometryInParent` |
| Its transform | `pureTransformInRoot`, `originalPureTransformInRoot` |
| Its transform in model space | `layoutTransformInInfoSpace` |
| Its angle, for the inspector | `inspectorGeometry`, `inspectorGeometryAngleInDegrees`, `canInspectGeometry` |
| The rectangle to cull by | `frameForCulling`, `frameForCullingWithBaseFrame` |
| The rectangle to partition by | `frameForPartitioning` |
| Its place in the draw order | `orderedBefore` |
| Its children | `childInfosForChildLayouts`, `updateChildrenFromInfo` |
| The guides it offers | `additionalGuides`, `shouldProvideSizingGuides`, `shouldDisplayGuides` |
| The path that clips its connections | `pathForClippingConnectionLines`, `wrapPath` |
| Its ancestors | `rootLayout`, `parent`, `layoutController` |

⇒ **A layout node is not a rectangle.** It is a rectangle plus a place in
the draw order, a set of guides it offers, a set of children it owns, a
culling rectangle, a clipping path, and its place in the dependency graph.
A replica that models a canvas item as `{x, y, w, h}` will not have enough
state to reproduce any of this.

### 9.2 The coordinate spaces

There are four, and they are not interchangeable:

| Space | What it is |
| --- | --- |
| **natural** | the item's own space, before any transform — `convertNaturalPointFromUnscaledCanvas`, `convertNaturalPointToUnscaledCanvas` |
| **pure** | the untransformed geometry — `pureGeometry`, `pureTransformInRoot` |
| **info** | the persisted model — `layoutTransformInInfoSpace`, `infoGeometryForCommiting…` |
| **root** | the canvas — `pureGeometryInRoot`, `frameForCulling` |

And `pureGeometryInRoot` is literally **the pure geometry run through the
parent's transform chain** — one private call, one answer:

```c
ID CRLCanvasLayout::pureGeometryInRoot() {
    return FUN_1013ed720(self, pureGeometry());
}
```

⇒ **The root space is computed by composing, never by storing.** The layout
tree keeps no world-space copy of its items.

### 9.3 Live edit is a per-gesture triple

Every manipulation has the same three beats, and each gesture has its own
family of them:

| Gesture | Begin | Take | End |
| --- | --- | --- | --- |
| Drag | `beginDrag` | `dragBy`, `dragByUnscaled` | `endDrag` |
| Rotate | `beginRotate` | `takeRotationFromTracker` | `endRotate` |
| Resize | `beginResize` | `takeSizeFromTracker`, `resizeWithTransform` | `endResize` |
| Free transform | `beginFreeTransformWithTracker` | `takeFreeTransformFromTracker` | `endFreeTransform` |
| Any | `beginDynamicOperationWithRealTimeCommands` | — | `endDynamicOperation` |

And the commit geometry is **per gesture**:
`finalInfoGeometryForResize`, `finalInfoGeometryForFreeTransform`, and the
general `infoGeometryForCommitingAnchorHintAtEndOfDynamicOperation`.

`endDynamicOperation` is the commit point, and its whole body is three
stores:

```c
assert(mBaseGeometry != nil);      // "…foreDynamicOperation"
mBaseGeometry = 0;
mLayoutState = 0;
mIsInRealTimeDynamicOperation = 0;
```

⇒ **Live edit is three pieces of state on the layout**: the geometry
captured at the start, the layout state, and the real-time flag. The commit
is clearing them. A replica that keeps the drag's transient geometry in a
separate "drag state" object has the same shape; a replica that mutates the
persisted geometry during the drag does not.

### 9.4 The dependency graph crosses the tree

`dependentLayouts` is the interesting one:

```c
result = parent's dependents that depend on me
       + the canvas controller's board items that depend on me
```

⇒ **A layout depends on more than its own children.** It depends on its
**parent's** dependents, and on **board items registered with the canvas
controller** — items that are not its descendants at all.

So the invalidation graph is **not** the layout tree. It is a second graph,
laid over the tree, and a replica that assumes "invalidate the subtree"
will get the wrong answer the moment an item depends on something that is
not its ancestor. The graph has three shapes of edge: `dependentLayouts`,
`bidirectionalSizeDependentLayouts` (size dependencies that go both ways),
and `reliedOnLayouts` (one-way). `dependentLayoutsForDrag` is a separate
narrower graph for the duration of a drag.

### 9.5 The magnets live on the layout, in local space

Connection-line attachment points are the layout's own business:

| The magnet | The selector |
| --- | --- |
| North, east, south, west | `cardinalNorthPosition`, `cardinalEastPosition`, `cardinalSouthPosition`, `cardinalWestPosition` |
| The centre for a new connection | `centerForConnecting` |
| The centre for a rotation | `centerForRotation` |
| Edge and floating magnets | `adjustEdgeMagnetPosition`, `adjustFloatingMagnetPosition` |
| The custom magnet set | `adjustCustomMagnetPositions`, `shouldBringCardinalMagnetsInward` |
| Normalised positions | `convertNormalizedPositionFromLayoutToPureGeometry` |
| The hull around them | `convexHullPath`, `getIntersectionsForTestPath` |

And `cardinalNorthPosition` shows where they are stored:

```c
CGPoint CRLCanvasLayout::cardinalNorthPosition() {
    CGAffineTransform t = geometry ? geometry.transform : identity;
    CGPoint p = mCardinalNorthPosition;      // stored, local
    return apply(t, p);
}
```

⇒ **The magnet positions are stored in the item's local space and transformed
to the canvas on demand.** They are not world coordinates, and they are not
recomputed when the item moves — the item's transform moves them.

### 9.6 What is fully mapped now

| Class | Mapped |
| --- | --- |
| `CRLCanvasLayout` | **214 / 214** |
| `CRLCanvasRepAccessibility` | **170 / 170** |
| `CRLImageRep` | **228 / 228** |
| `CRLShapeRep` | **158 / 158** |
| `CRLMacCanvasViewController` | **183 / 183** |
| `CRLCanvasRep` | 258 / 423 |
| `CRLInteractiveCanvasController` | 282 / 529 |
| `CRLWPRep` | 255 / 313 |
| `CRLMacCanvasZoomMagnificationGestureRecognizer` | 187 / 243 |

⇒ **2,415 method bodies in total — 11.2% of the 21,580 reachable
Objective-C methods.** The classes that hold the geometry, the guides, the
snapping, the autoscroll, the zoom and the positioning are at 100%. What is
left is the item-type-specific surface (text, shapes, media) and the
controller plumbing, which is the part a replica does not need to copy.
