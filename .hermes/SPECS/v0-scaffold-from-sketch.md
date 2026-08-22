# SPEC v0-scaffold-from-sketch (Wenshu homepage 6-zone layout)

> Data source: Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` · page `文枢` · Artboard `首页`
> Unit: PX (老板 8/18 corrected, on macOS 27 1x 1 PT = 1 PX, no retina scaling)
> Truth read: `mcp__sketch__run_code` recursive dump of 47 layer frames (2026-08-18)
> Artboard overall dimensions: 3840 × 1968 PX

## 0. Unit declaration (老板 8/18)

- All design values = **PX** (pixels)
- On Apple macOS 27 1x devices, 1 PT = 1 PX (no retina scaling factor involved)
- Implementation lands 1:1 in PX, no PT conversion
- Drag splitter = 2 PX thick (= 1 PT, 老板 8/18 拍 "after conversion, they should all be 1 PT thick")

## 1. Top-level structure (Artboard = `首页`)

| Zone ID | Name | Frame (PX) | Color |
|---------|------|------------|------|
| Z-TITLE | Title bar | 0,0,1920,38 | #393939 solid |
| Z-NOVEL | Novel management area | 0,39,1920,472 | Transparent (children fill individually) |
| Z-CHAT  | Chat management area | 0,512,1920,472 | Transparent (children fill individually) |

## 2. Title bar (Z-TITLE)

- ShapePath, 3840×76 PX, #393939 solid
- No traffic lights (Sketch design is a pure color block, not system window chrome)

## 3. Novel management area (Z-NOVEL · 0,78,3840,944) — 3 columns

| Zone ID | Name | Frame (PX) | Content |
|---------|------|------------|------|
| Z-N-PROJ | Project management | 0,0,1516,944 | Top bar + sidebar + preview area + 3 blue rectangles |
| Z-N-EDIT | Editor   | 1518,0,1514,944 | Top bar + background + body area + bottom bar |
| Z-N-TOOL | Dedicated tools | 3034,0,806,944 | Top bar + function area + bottom bar |

### 3.1 Project management (Z-N-PROJ · 0,0,1516,944)

| Sub-zone | Name | Frame (relative) | Color |
|---------|------|-------------|------|
|  | Project management top bar | 0,0,1516,58 | #202020 |
|  | Project management sidebar | 0,60,400,884 | #202020 |
|  | Project management preview area | 402,60,1114,824 | Transparent container |
| └ | Preview area top bar | 0,0,1114,58 | #202020 |
| └ | Function area | 0,60,1114,764 | #202020 |
| └ | Preview area bottom bar | 0,826,1114,58 | #202020 |
|  | Rectangle (#4a60b2) | 22,10,38,38 | #4a60b2 |
|  | Rectangle 2 | 82,10,38,38 | #4a60b2 |
|  | Rectangle 3 | 142,10,38,38 | #4a60b2 |

**3 blue rectangles = future ICON button placeholders** (老板 8/18 answered Q3):
- 60 PX equal spacing (22/82/142), 38×38 PX, #4a60b2
- At implementation do not render the 3 rectangles themselves; only reserve 142+38=180 PX wide placeholder space
- Top bar content layout reserves "front 180 PX as ICON area"; drop the actual ICON design in directly when finished

### 3.2 Editor (Z-N-EDIT · 1518,0,1514,944)

| Sub-zone | Name | Frame (relative) | Color |
|---------|------|-------------|------|
|  | Editor top bar | 0,0,1514,58 | #202020 |
|  | Editor background | 0,60,1514,824 | #202020 |
|  | Editor body area | 20,64,1474,818 | #ffffff 55% opacity (alpha 0x8c) |
|  | Editor bottom bar | 0,886,1514,58 | #202020 |

**Two-layer design** (老板 8/18 answered Q2): outer #202020 editor background + inner #ffffff 55% body area. The 4 PX inset (background y=60~884, body y=64~882) is an intentional visual inset to make the reading area smaller than the entire editor area by one ring, establishing hierarchy. Do not remove.

### 3.3 Dedicated tools (Z-N-TOOL · 3034,0,806,944)

| Sub-zone | Name | Frame (relative) | Color |
|---------|------|-------------|------|
|  | Dedicated tools top bar | 0,0,806,58 | #202020 |
|  | Dedicated tools function area | 0,60,806,824 | #202020 |
|  | Dedicated tools bottom bar | 0,886,806,58 | #202020 |

## 4. Chat management area (Z-CHAT · 0,1024,3840,944) — 1 top bar + 2 columns

| Zone ID | Name | Frame (PX) | Color |
|---------|------|------------|------|
| Z-C-TOP | Chat management area top bar | 0,0,3840,60 | #333333 |
| Z-C-CHAT | Chat area | 0,62,3032,882 | Transparent |
| Z-C-DYN | Dynamic area | 3034,62,806,882 | Transparent |

### 4.1 Chat area (Z-C-CHAT · 0,62,3032,882)

| Sub-zone | Name | Frame (relative) | Color |
|---------|------|-------------|------|
|  | Chat area sidebar | 0,0,400,818 | #202020 |
|  | Chat area sidebar bottom bar | 0,820,400,62 | #202020 |
|  | Chat area conversation area | 402,0,2630,882 | #202020 |
|  | Chat area input box | 422,724,2590,94 | #4a60b2 |

Input box = #4a60b2 blue (same color as the blue rectangles in project management top bar).

### 4.2 Dynamic area (Z-C-DYN · 3034,62,806,882)

| Sub-zone | Name | Frame (relative) | Color |
|---------|------|-------------|------|
|  | Dynamic area function area | 0,0,806,818 | #1e1e1e |
|  | Dynamic area bottom bar | 0,820,806,62 | #202020 |

Note: the function area #1e1e1e is slightly darker than the other areas' #202020.

## 5. 13 splitter truth source (Artboard global PX, 老板 8/18 拍板 all in place)

老板 8/18 拍 "two drag splitters are missing from the landing, non-draggable splitters are all missing". All landed.

### 5.1 6 drag splitters (老板 8/18 拍 2 PX thick ≡ 1 PT, 6 PT hit area, 1 PT black line visual)

| ID | id (Sketch) | x | y | w | h | Function |
|----|-------------|---|---|---|---|------|
| D1 | 143A756D | 400 | 138 | 2 | 884 | Project management sidebar / preview |
| D2 | 6134E008 | 1516 | 78 | 2 | 944 | Project management / editor |
| D3 | 91DAAC15 | 3032 | 78 | 2 | 944 | Editor / dedicated tools |
| D4 | DC78C7F3 | 400 | 1086 | 2 | 882 | Chat sidebar / chat conversation |
| D5 | 869171D1 | 3032 | 1086 | 2 | 882 | Chat conversation / dynamic area |
| D6 | 1363CC24 | 0 | 1022 | 3840 | 2 | Horizontal novel management / chat management |

**D4 / D5 deviation** (老板 8/18 corrected, image truth source fixed to design intent):
- Sketch image truth source sub-group frame=(x:400 y:1008) + parent ChatManagementZone y=1024 + child ChatRegion y=62 = **actual 2094** (exceeds Artboard 1968 by 126 PX)
- Design landing point y=1086 (hugs just below D6 horizontal drag splitter, fits inside the 882 screen)
- 老板 8/18 拍 "two drag splitters are missing from the landing" → land at 1086 per design intent

### 5.2 7 non-draggable splitters (NSColor.separatorColor 1 PX, SwiftUI Divider / Color.frame)

| ID | id (Sketch) | x | y | w | h | Function |
|----|-------------|---|---|---|---|------|
| S1 | 3BD407CA | 0 | 76 | 3840 | 2 | Title bar bottom → 老板 2026-08-19 ticket 005 change: title bar uses macOS .windowStyle(.titleBar) 52 PT unified chrome, macOS chrome auto-includes separator (gray background meets dark zone), no longer hand-written splitter (no replacement implementation after Canvas redraw was deleted) |
| S2 | CFDCDAEC | 0 | 136 | 3840 | 2 | Novel management area top bar bottom (across full band) |
| S3 | FA73EB21 | 402 | 334 | 1114 | 2 | Preview area top bar bottom |
| S4 | 685B018D | 402 | 1906 | 3032 | 2 | Chat sidebar bottom bar bottom (crosses D5 drag splitter visual) |
| S5 | 3AD21B74 | 0 | 1084 | 3840 | 2 | Chat management area top bar bottom |
| S6 | 18620717 | 0 | 1904 | 400 | 2 | Project management bottom bar bottom |
| S7 | 1FC20946 | 3034 | 1904 | 806 | 2 | Dedicated tools bottom bar bottom |

**S4 deviation** (老板 8/18 corrected, image truth source fixed to design intent):
- Sketch image truth source sub-group frame=(x:402 y=962) + parent 1024 + child 62 = **actual 2048** (exceeds Artboard 1968 by 80 PX)
- Design landing point y=1906 (project bottom bar bottom position 1904 + 2 PX top = across chat area sidebar bottom bar + dynamic area bottom bar visual line)

## 6. Color palette (design truth source)

| Role | Color value | Where it appears |
|------|------|---------|
| Main title bar gray | #393939 | Title bar |
| Chat top bar gray | #333333 | Chat management area top bar |
| Content area base | #202020 | All top bars / bottom bars / function areas / sidebars / editor background / conversation area |
| Dynamic area base | #1e1e1e | Dynamic area function area |
| Editor body area | #ffffff 55% alpha | Editor body area |
| Accent blue | #4a60b2 | Input box, project management top bar 3 rectangles |
| Drag splitter | #000000 2PX | 6 splitters |

## 7. 老板 拍板 (8/18 all answered)

- Title bar #393939 vs. chat top bar #333333 color difference = intentional hierarchy distinction (Q4 拍 yes)
- Drag splitter 2 PX thickness = original design value; first restore at 2 PX, adjust later if the line looks too thick (Q5 拍 yes + 老板 8/18: "3840,1890 is my actual screenshot, I should have a 2K screen. First restore per my image, then check whether the line is thick enough")
- Editor body 4 PX inset = intentional two-layer design (Q2 拍 yes)
- 3 blue rectangles = future ICON placeholder, implementation does not render them, only reserves space (Q3 拍 yes)
- Drag splitter D4/D5 + splitter S4 = Sketch image sub-layer typo out of Artboard bounds, land per design intent (Q1 my own derivation + 老板 8/18 correction)

## 8. Implementation constraints (老板 8/18)

- **macOS-only** (`.macOS(.v27)` single target)
- No hardcoded RGB/size/corner/opacity → use Apple Semantic (`Color(.controlBackgroundColor)` / `Material` / `.background(.ultraThinMaterial)` etc.) but retain design color values as fallback (because the design has specific color value requirements)
- Unit 1 PX = 1 PT (macOS 27 1x), no scaling
- Any "universal reserved point" / iOS / iPadOS / Catalyst adaptation = dead code = delete
- When screen resolution is less than 3840×1968, scale proportionally (AppDelegate scales proportionally to maxW/maxH, no distortion)

## 9. Implementation path (v0.07.0 landing state)

- Truth data source: `mcp__sketch__run_code` recursive dump of 47 layer frames
- Files:
  - `Sources/WenshuApp/App.swift` — 6-zone layout shell (老板 Sketch truth source) + LayoutTokens 18 ratio operators
  - `Sources/WenshuApp/DesignTokens.swift` — Apple Semantic Color 5 tokens (titleBar/zoneSurface/dynamicZoneSurface/accentBlue/splitterLine)
  - `Sources/WenshuApp/LayoutShellViewModel.swift` — 5-offset drag state + 6 zone ratio computation (added in v0.10.1 + v0.10.3)
  - `Sources/WenshuApp/Views/Layout/NativeSplitter.swift` — 6 drag splitters (NativeSplitterView NSView, 1 PT intrinsicContentSize)
- Self-check: WS_SCREENSHOT=1 swift run WenshuApp → /tmp/wenshu-selfshot.png, 6 zones + 13 splitters in place
- Screen scaling: AppDelegate scales 3840×1968 proportionally to 2K screen visible area; internally scales per ratio operator