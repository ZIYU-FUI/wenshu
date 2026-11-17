//
//  segmented_control_selected_fill.swift
//
//  Measure what fills the SELECTED segment of a segmented control in a
//  KEY window: = the SYSTEM ACCENT (= the theme colour) or a material.
//
//  WHY THIS PROBE EXISTS (= AND WHAT IT CORRECTS)
//    The sibling probe `segmented_control_material.swift` measures the
//    control's own material on an UNSELECTED cell, in a window that is
//    never the key window. = = = That measurement is sound for the
//    question it asks (= does an unselected cell let the layer behind
//    it read through), = = = and it is TRUE. = = = But it cannot answer
//    the question the app's users see, = = and the two questions have
//    different answers: = = = the SELECTED segment, in a key window,
//    paints the SYSTEM ACCENT. = ⇒ So a probe that only ever measured
//    an unselected cell in a non-key window reports "material" about a
//    control whose selected segment is theme-coloured. = = = THAT IS
//    THE GAP THIS PROBE CLOSES.
//
//  HOW IT MEASURES
//    It renders the control in a NON-ACTIVATING `NSPanel` = = = the
//    one AppKit object that can own the key window without activating
//    its application. = ⇒ The measurement reads the state the app's
//    users see (= the key window), = and the operator's own frontmost
//    application is NOT taken. = ⇒ The probe proves THAT claim by
//    PROCESS ID (= `probe_took_foreground`), = not by comparing the
//    frontmost application before and after: = = = another application
//    may take the foreground during the measurement window, = and that
//    is not the probe taking it. = ⇒ The frontmost bundle identifiers
//    are printed too, = so a reader can see what was in front.
//
//    The panel sits off-screen (= at -20000, -20000), = so nothing
//    appears on the operator's display.
//
//  THE VARIABLE IT CHANGES, = AND ONLY THAT ONE
//    The same control, = over the same host layer, = in the same
//    appearance, = with the same cell shape, = is read twice: = once in
//    a window that IS the key window, = and once in a window that is
//    NOT. = ⇒ The two readings differ ONLY by the window's key state, =
//    so the difference between them is what the key state does. = = =
//    And within the key window the probe reads TWO segments: = the
//    selected one, = and an unselected one (= the contrast: = = = so the
//    reading says WHICH surface carries the accent, = = = and not that
//    the whole control is accent-filled).
//
//  THE TRAP IT AVOIDS
//    A CLI `swift` process cannot own a key window in an ordinary
//    `NSWindow`: = measured, `app_active=false` and `window_key=false`,
//    and the accent fill does NOT appear. = ⇒ A probe that reads
//    "no accent" from such a window has measured the wrong state and
//    reports it as the truth. = ⇒ THIS PROBE PRINTS ITS OWN KEY-WINDOW
//    STATE (= `panel_is_key`), = so a run that did not reach the key
//    state is visibly not a measurement of the selected fill.
//
//  AND THE PROBE PROVES ITS OWN NUMBER HAS TEETH
//    The key-window reading is only evidence of an accent fill if the
//    SAME area would read DIFFERENTLY when the accent is not there. =
//    ⇒ So the probe reads the same area three more ways: = with the
//    accent colour painted over it, = in a non-key window, = and on an
//    unselected segment of the same key window. = ⇒ If the readings
//    differ, = the numbers distinguish the states, = and the probe
//    prints all of them.
//
//  THE MEASURED REGION CARRIES NO LABEL INK
//    The cell's label is centred in the segment and is painted white
//    on the accent, = so a region that spans the segment's middle
//    mixes the label's ink into the fill's own colour. = ⇒ The probe
//    reads a strip at a segment's LEADING EDGE, = where the label
//    cannot reach, = and prints that strip's ink count (= the pixels
//    that are white or dark) = = = so a reader can see the strip is
//    label-free rather than take it on trust.
//
//  THE TWO CELL SHAPES
//    A plain `NSSegmentedControl` and a cell that overrides
//    `drawSegment` and calls super (= the shape a strip that draws its
//    own glyphs has). = ⇒ The probe prints one set of readings per
//    shape, = because the shape decides whether the control's own
//    selection painting can be inherited at all.
//
//  THE PARAMETERS THAT DECIDE THE NUMBERS
//    They are printed with the numbers, = because changing one changes
//    the reading:
//
//      host_size_pt             260 x 40
//      control_frame_pt         (10, 6, 240, 28)
//      control_size             .small
//      control_role             .valueSelection
//      control_style            .roundRect
//      border_shape             .capsule
//      segment_distribution     .fillEqually
//      selected_segment         1
//      contrast_segment         2
//      segment_count            3
//      labels                   Tag1 / Tag2 / Tag3
//      host_layer_colour        calibrated (0, 0.55, 0.25)
//      strip_width_pt           8
//      strip_inset_pt           4
//
//  Read-only: the probe renders into memory and prints to stdout. = It
//  creates, moves and deletes no file.
//
//  Usage:
//      swift Tools/wenshu-devtool/probes/segmented_control_selected_fill.swift
//
//  Exit: 0 = the measurement is sound (every arm read its key state),
//  = 3 = a key state was not reached or a region could not be read
//  (= the run measured the wrong state).
//

import AppKit
import Foundation

// MARK: - The parameters that decide the numbers

let hostSize = NSSize(width: 260, height: 40)
let controlFrame = NSRect(x: 10, y: 6, width: 240, height: 28)
let hostLayerColour = NSColor(calibratedRed: 0.0, green: 0.55, blue: 0.25, alpha: 1.0)
let labels = ["Tag1", "Tag2", "Tag3"]
let selectedSegment = 1
let contrastSegment = 2
let segmentCount = 3

/// The measured strip: = a segment's leading edge, = where the centred
/// label cannot reach.
let stripWidth: CGFloat = 8
let stripInset: CGFloat = 4

/// Where the window sits: = off the display.
let offscreenOrigin = NSPoint(x: -20000, y: -20000)

// MARK: - The measurement

/// One pixel of the rendered bitmap.
struct Pixel {
    var r: Int
    var g: Int
    var b: Int
}

/// The rendered bitmap of a view, = and the scale it was rendered at.
struct Bitmap {
    var pixels: [Pixel]
    var width: Int
    var height: Int
    var scale: Int

    func at(_ x: Int, _ y: Int) -> Pixel? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        return pixels[y * width + x]
    }
}

/// What one region reads.
struct Reading {
    var rgb: (Int, Int, Int)
    var colours: Int
    /// The pixels that are near-white (= the label's ink on the accent).
    var whiteInk: Int
    /// The pixels that are near-black (= the label's ink on a light fill).
    var darkInk: Int
    var pixels: Int

    var triple: (Int, Int, Int) {
        rgb
    }
}

/// Render a view into a 2x bitmap and read its pixels.
func render(_ view: NSView) -> Bitmap? {
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    rep.size = view.bounds.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    hostLayerColour.setFill()
    view.bounds.fill()
    NSGraphicsContext.restoreGraphicsState()
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let data = rep.bitmapData else { return nil }

    let rowBytes = rep.bytesPerRow
    let samples = rep.samplesPerPixel
    let width = rep.pixelsWide
    let height = rep.pixelsHigh
    var pixels = [Pixel](repeating: Pixel(r: 0, g: 0, b: 0), count: width * height)
    for y in 0 ..< height {
        for x in 0 ..< width {
            let offset = y * rowBytes + x * samples
            pixels[y * width + x] = Pixel(
                r: Int(data[offset]),
                g: Int(data[offset + 1]),
                b: Int(data[offset + 2])
            )
        }
    }
    return Bitmap(pixels: pixels, width: width, height: height, scale: Int(Double(width) / view.bounds.width))
}

/// Map a view rect (BOTTOM-UP) onto the bitmap's rows (TOP-DOWN).
///
/// = = = THE PROBE MAPS THE ROWS ITSELF: = the bitmap that
/// `cacheDisplay(in:to:)` writes is TOP-DOWN, = while an NSView's
/// coordinates are BOTTOM-UP, = and reading the bitmap's rows with the
/// view's y unchanged reads a band that is MIRRORED vertically. = = =
/// The probe prints the row range it read, = so a reader can check the
/// reading without trusting the mapping.
func bitmapRows(for rect: CGRect, hostHeight: CGFloat, scale: Double) -> Range<Int> {
    let top = Int((hostHeight - rect.origin.y - rect.height) * scale)
    let bottom = Int((hostHeight - rect.origin.y) * scale)
    return top ..< bottom
}

/// The mean colour, the distinct colour count, and the ink counts of
/// the bitmap's rows inside a view rect.
func readRegion(_ bitmap: Bitmap, rect: CGRect, hostHeight: CGFloat) -> Reading? {
    let rows = bitmapRows(for: rect, hostHeight: hostHeight, scale: Double(bitmap.scale))
    let x0 = Int(rect.origin.x * Double(bitmap.scale))
    let x1 = x0 + Int(rect.width * Double(bitmap.scale))
    var r = 0
    var g = 0
    var b = 0
    var count = 0
    var white = 0
    var dark = 0
    var seen = Set<Int>()
    for y in rows {
        for x in x0 ..< x1 {
            guard let pixel = bitmap.at(x, y) else { continue }
            r += pixel.r
            g += pixel.g
            b += pixel.b
            count += 1
            let luminance = pixel.r + pixel.g + pixel.b
            if luminance > 735 {
                white += 1
            }
            if luminance < 200 {
                dark += 1
            }
            seen.insert((pixel.r << 16) | (pixel.g << 8) | pixel.b)
        }
    }
    guard count > 0 else { return nil }
    return Reading(
        rgb: (r / count, g / count, b / count),
        colours: seen.count,
        whiteInk: white,
        darkInk: dark,
        pixels: count
    )
}

/// The colour distance between two triples.
func distance(_ lhs: (Int, Int, Int), _ rhs: (Int, Int, Int)) -> Double {
    let dr = Double(lhs.0 - rhs.0)
    let dg = Double(lhs.1 - rhs.1)
    let db = Double(lhs.2 - rhs.2)
    return (dr * dr + dg * dg + db * db).squareRoot()
}

// MARK: - The control under test

/// A cell that draws its own glyphs and rides on the stock drawing:
/// = the shape a strip that paints a close mark has.
final class SuperCallingCell: NSSegmentedCell {
    override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
        super.drawSegment(segment, inFrame: frame, with: controlView)
    }
}

/// The cell a control carries.
enum CellShape: String {
    case stock
    case superCalling

    var label: String {
        switch self {
        case .stock: return "stock"
        case .superCalling: return "custom-super"
        }
    }

    func makeCell() -> NSSegmentedCell {
        switch self {
        case .stock: return NSSegmentedCell()
        case .superCalling: return SuperCallingCell()
        }
    }
}

/// Build the control the app's strips use: = the same size, style,
/// role and border shape the app's `LabelSegmentedControl` sets.
func makeControl(shape: CellShape) -> NSSegmentedControl {
    let control = NSSegmentedControl(frame: controlFrame)
    control.cell = shape.makeCell()
    control.segmentCount = segmentCount
    control.trackingMode = .selectOne
    control.controlSize = .small
    control.segmentStyle = .roundRect
    control.role = .valueSelection
    control.borderShape = .capsule
    control.segmentDistribution = .fillEqually
    control.selectedSegment = selectedSegment
    for (index, label) in labels.enumerated() {
        control.setLabel(label, forSegment: index)
    }
    return control
}

/// The host view the control sits on: = a saturated layer, = so a
/// translucent surface reads DIFFERENTLY from an opaque one.
func makeHost() -> NSView {
    let host = NSView(frame: NSRect(origin: .zero, size: hostSize))
    host.wantsLayer = true
    host.layer?.backgroundColor = hostLayerColour.cgColor
    return host
}

/// The measured strip of one segment: = its leading edge, = where the
/// centred label cannot reach.
func stripRect(segment: Int) -> CGRect {
    let segmentWidth = controlFrame.width / CGFloat(segmentCount)
    let segmentStart = controlFrame.origin.x + CGFloat(segment) * segmentWidth
    return CGRect(
        x: segmentStart + stripInset,
        y: controlFrame.origin.y + 4,
        width: stripWidth,
        height: controlFrame.height - 8
    )
}

// MARK: - The two window states

/// One arm's readings: = the key window's two segments, = the accent
/// painted over the selected strip, = and the non-key window's read.
struct Arm {
    var keyIsKey: Bool
    var selected: Reading?
    var contrast: Reading?
    var overlay: Reading?
    var nonKeyIsKey: Bool
    var nonKey: Reading?
    var frontmostBefore: String
    var frontmostAfter: String
    /// Whether the PROBE's own process ever became the frontmost
    /// application. = The operator's foreground app can change under the
    /// measurement (= another app can take it), = so that change is not
    /// the probe's doing; = = = the probe taking the foreground is. = ⇒
    /// This compares PROCESS IDs, = not bundle identifiers.
    var probeTookForeground: Bool
}

/// Read the two segments in a window that IS the key window.
func measureKeyWindow(appearance: NSAppearance.Name, shape: CellShape) -> Arm {
    let panel = NSPanel(
        contentRect: NSRect(origin: .zero, size: hostSize),
        styleMask: [.titled, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.setFrameOrigin(offscreenOrigin)
    panel.appearance = NSAppearance(named: appearance)
    let host = makeHost()
    panel.contentView = host
    let control = makeControl(shape: shape)
    host.addSubview(control)

    let frontmostBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
    let frontmostPidBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
    panel.makeKeyAndOrderFront(nil)
    host.layoutSubtreeIfNeeded()
    control.layoutSubtreeIfNeeded()
    panel.displayIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    panel.displayIfNeeded()

    var selected: Reading?
    var contrast: Reading?
    var overlay: Reading?
    if let bitmap = render(host) {
        selected = readRegion(bitmap, rect: stripRect(segment: selectedSegment), hostHeight: hostSize.height)
        contrast = readRegion(bitmap, rect: stripRect(segment: contrastSegment), hostHeight: hostSize.height)

        // The teeth: = = = the SAME area with the accent colour
        // painted over it, = so a reader can see that the key-window
        // reading differs from BOTH the host layer showing through
        // AND the accent itself.
        let cover = NSView(frame: stripRect(segment: selectedSegment))
        cover.wantsLayer = true
        cover.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        host.addSubview(cover)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        overlay = render(host).flatMap {
            readRegion($0, rect: stripRect(segment: selectedSegment), hostHeight: hostSize.height)
        }
        cover.removeFromSuperview()
    }

    let frontmostAfter = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
    let frontmostPidAfter = NSWorkspace.shared.frontmostApplication?.processIdentifier
    let keyIsKey = panel.isKeyWindow
    panel.orderOut(nil)
    // The probe's own process taking the foreground is the ONLY
    // foreground change the probe is responsible for. = ⇒ The
    // invariant compares PIDs: = = = the probe's own PID against the
    // frontmost application's PID, = at both ends of the window.
    let probePid = ProcessInfo.processInfo.processIdentifier
    let probeTookForeground = frontmostPidBefore == probePid || frontmostPidAfter == probePid
    return Arm(
        keyIsKey: keyIsKey,
        selected: selected,
        contrast: contrast,
        overlay: overlay,
        nonKeyIsKey: false,
        nonKey: nil,
        frontmostBefore: frontmostBefore,
        frontmostAfter: frontmostAfter,
        probeTookForeground: probeTookForeground
    )
}

/// Read the SAME area in a window that is NOT the key window: = = =
/// the state the sibling probe measured, = so the two readings can be
/// compared directly.
func measureNonKeyWindow(appearance: NSAppearance.Name, shape: CellShape) -> (isKey: Bool, reading: Reading?) {
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: hostSize),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.setFrameOrigin(offscreenOrigin)
    window.appearance = NSAppearance(named: appearance)
    let host = makeHost()
    window.contentView = host
    let control = makeControl(shape: shape)
    host.addSubview(control)

    window.orderFront(nil)
    host.layoutSubtreeIfNeeded()
    control.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    window.displayIfNeeded()

    let reading = render(host).flatMap {
        readRegion($0, rect: stripRect(segment: selectedSegment), hostHeight: hostSize.height)
    }
    let isKey = window.isKeyWindow
    window.orderOut(nil)
    return (isKey, reading)
}

// MARK: - The report

func gitHead() -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // probes
        .deletingLastPathComponent() // wenshu-devtool
        .deletingLastPathComponent() // Tools
        .deletingLastPathComponent() // the repo root
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["rev-parse", "--short", "HEAD"]
    process.currentDirectoryURL = root
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? "unknown"
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return "unknown"
    }
}

/// Print one region's numbers.
func printRegion(_ name: String, _ reading: Reading?) {
    guard let reading else {
        print("\(name)_rgb: (unread)")
        print("\(name)_colours: 0")
        print("\(name)_white_ink: 0")
        print("\(name)_dark_ink: 0")
        print("\(name)_pixels: 0")
        return
    }
    print("\(name)_rgb: (\(reading.rgb.0), \(reading.rgb.1), \(reading.rgb.2))")
    print("\(name)_colours: \(reading.colours)")
    print("\(name)_white_ink: \(reading.whiteInk)")
    print("\(name)_dark_ink: \(reading.darkInk)")
    print("\(name)_pixels: \(reading.pixels)")
}

let accentColour = NSColor.controlAccentColor.usingColorSpace(.sRGB)
let accent = (
    Int((accentColour?.redComponent ?? 0) * 255),
    Int((accentColour?.greenComponent ?? 0) * 255),
    Int((accentColour?.blueComponent ?? 0) * 255)
)
let backdrop = (
    Int((hostLayerColour.usingColorSpace(.sRGB)?.redComponent ?? 0) * 255),
    Int((hostLayerColour.usingColorSpace(.sRGB)?.greenComponent ?? 0) * 255),
    Int((hostLayerColour.usingColorSpace(.sRGB)?.blueComponent ?? 0) * 255)
)

print("probe: segmented_control_selected_fill")
print("source_commit: \(gitHead())")
print("host_size_pt: \(Int(hostSize.width)) x \(Int(hostSize.height))")
print("control_frame_pt: (\(Int(controlFrame.origin.x)), \(Int(controlFrame.origin.y)), "
    + "\(Int(controlFrame.width)), \(Int(controlFrame.height)))")
print("control_size: small")
print("control_role: valueSelection")
print("control_style: roundRect")
print("border_shape: capsule")
print("segment_distribution: fillEqually")
print("selected_segment: \(selectedSegment)")
print("contrast_segment: \(contrastSegment)")
print("segment_count: \(segmentCount)")
print("labels: \(labels.joined(separator: " / "))")
print("host_layer_colour: calibrated (\(hostLayerColour.redComponent), "
    + "\(hostLayerColour.greenComponent), \(hostLayerColour.blueComponent))")
print("system_accent_rgb: (\(accent.0), \(accent.1), \(accent.2))")
print("host_layer_rgb: (\(backdrop.0), \(backdrop.1), \(backdrop.2))")
print("selected_strip_pt: (\(Int(stripRect(segment: selectedSegment).origin.x)), "
    + "\(Int(stripRect(segment: selectedSegment).origin.y)), "
    + "\(Int(stripRect(segment: selectedSegment).width)), "
    + "\(Int(stripRect(segment: selectedSegment).height)))")
print("contrast_strip_pt: (\(Int(stripRect(segment: contrastSegment).origin.x)), "
    + "\(Int(stripRect(segment: contrastSegment).origin.y)), "
    + "\(Int(stripRect(segment: contrastSegment).width)), "
    + "\(Int(stripRect(segment: contrastSegment).height)))")
print("offscreen_origin_pt: (\(Int(offscreenOrigin.x)), \(Int(offscreenOrigin.y)))")

var sound = true
for (appearanceName, appearance) in [("darkAqua", NSAppearance.Name.darkAqua), ("aqua", .aqua)] {
    for shape in [CellShape.stock, .superCalling] {
        var arm = measureKeyWindow(appearance: appearance, shape: shape)
        let nonKey = measureNonKeyWindow(appearance: appearance, shape: shape)
        arm.nonKeyIsKey = nonKey.isKey
        arm.nonKey = nonKey.reading

        print("")
        print("appearance: \(appearanceName)")
        print("cell_shape: \(shape.label)")
        print("panel_is_key: \(arm.keyIsKey)")
        print("frontmost_before: \(arm.frontmostBefore)")
        print("frontmost_after: \(arm.frontmostAfter)")
        print("probe_took_foreground: \(arm.probeTookForeground)")
        printRegion("key_window_selected_strip", arm.selected)
        printRegion("key_window_contrast_strip", arm.contrast)

        guard arm.keyIsKey, let selected = arm.selected, !arm.probeTookForeground else {
            print("distance_to_system_accent: 0.0")
            print("distance_to_host_layer: 0.0")
            print("fill_is_accent_dominant: false")
            printRegion("teeth_accent_overlay", nil)
            print("non_key_window_is_key: \(arm.nonKeyIsKey)")
            printRegion("non_key_window_selected_strip", nil)
            sound = false
            continue
        }

        // The distances: = = = the reading's own account of WHY it calls
        // the fill an accent fill. = ⇒ A reader who disagrees with the
        // rule changes the rule, = = = not the claim.
        let toAccent = distance(selected.triple, accent)
        let toBackdrop = distance(selected.triple, backdrop)
        print("distance_to_system_accent: \(String(format: "%.1f", toAccent))")
        print("distance_to_host_layer: \(String(format: "%.1f", toBackdrop))")
        print("fill_is_accent_dominant: \(toAccent < toBackdrop)")
        printRegion("teeth_accent_overlay", arm.overlay)
        print("non_key_window_is_key: \(arm.nonKeyIsKey)")
        printRegion("non_key_window_selected_strip", arm.nonKey)
    }
}

exit(sound ? 0 : 3)
