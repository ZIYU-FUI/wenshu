//
//  segmented_control_material.swift
//
//  Measure the native segmented control's own material: whether the
//  control's cells paint an opaque fill of their own, or let the layer
//  behind them read through.
//
//  WHAT IT MEASURES
//    The cells of a native `NSSegmentedControl` over a saturated host
//    layer, and the host layer beside the control:
//
//      drawn_band_pt         the rows where the control actually paints
//      cell_area_rgb         the mean colour of the control's own cell
//      cell_area_colours     the distinct colours in that same area
//      backdrop_rgb          the host layer's own rendered colour
//      backdrop_colours      the distinct colours in that same area
//      opaque_area_rgb       the SAME area, with an opaque fill painted
//                            over it (= what an opaque cell would read)
//
//    Every number names the APPEARANCE it was read in, = because the
//    control's own rendering is appearance-dependent, = and a number
//    without its appearance does not describe anything.
//
//  HOW IT MEASURES
//    It renders the control offscreen into a 2x `NSBitmapImageRep` and
//    reads the pixels of named regions.
//
//  THE TRAP IT AVOIDS (= AND IT FELL INTO IT ONCE)
//    The bitmap that `cacheDisplay(in:to:)` writes is TOP-DOWN, = while
//    an NSView's coordinates are BOTTOM-UP. = Reading the bitmap's rows
//    with the view's y unchanged reads a band that is MIRRORED
//    vertically: = the region lands partly on the drawn cell and partly
//    on the bare host above it, = and the mean of those two is a number
//    that looks plausible and proves nothing. = ⇒ This probe MAPS the
//    view's rect onto the bitmap's rows:
//
//        bitmap_row = (hostHeight - (y + height)) * scale ... (height - y) * scale
//
//    = and it PRINTS the row range it read, = so a reader can check the
//    reading without trusting the mapping.
//
//  AND THE PROBE PROVES ITS OWN NUMBER HAS TEETH
//    A mean colour that is green-dominant is only evidence of a
//    translucent cell if the same region would read DIFFERENTLY when
//    the cell painted an opaque fill. = ⇒ So the probe reads every
//    region twice: = once as the control draws it, = and once with an
//    opaque grey fill painted over the same pixels (= what an opaque
//    cell would do to them). = ⇒ If the two readings differ, = the
//    number distinguishes the two cases; = and the probe prints both.
//
//  THE PARAMETERS THAT DECIDE THE NUMBER
//    They are printed with the numbers, = because changing one changes
//    the reading:
//
//      host_size_pt             260 x 40
//      control_frame_pt         (10, 6, 240, 28)
//      control_size             .small
//      control_role             .valueSelection
//      control_style            .roundRect
//      selected_segment         1
//      measured_segment         0
//      labels                   标签1 / 标签2 / 标签3
//      host_layer_colour        calibrated (0, 0.55, 0.25)
//
//  THE TRAP IT DOES NOT FALL INTO
//    A material CONTAINER (= an `NSVisualEffectView` behind the control, =
//    or an `NSGlassEffectView` around it) changes the reading by a factor
//    of three, = and by appearance, = and in the dark appearance it
//    changes the QUALITATIVE reading too. = So this probe measures the
//    control ALONE: = the control's own material is what the app asks
//    for, = and a container's number would answer a different question.
//
//  Read-only: the probe renders into memory and prints to stdout. = It
//  creates, moves and deletes no file.
//
//  Usage:
//      swift Tools/wenshu-devtool/probes/segmented_control_material.swift
//
//  Exit: 0 = the measurement is sound, 3 = the control's own area could
//  not be read from the rendered pixels.
//

import AppKit
import Foundation

// MARK: - The parameters that decide the number

let hostSize = NSSize(width: 260, height: 40)
let controlFrame = NSRect(x: 10, y: 6, width: 240, height: 28)
let hostLayerColour = NSColor(calibratedRed: 0.0, green: 0.55, blue: 0.25, alpha: 1.0)
let labels = ["标签1", "标签2", "标签3"]
let selectedSegment = 1
let measuredSegment = 0

/// The opacity control's fill: = what an opaque cell would paint.
let opaqueFill = NSColor(calibratedWhite: 0.5, alpha: 1.0)

// MARK: - The measurement

struct Reading {
    var rgb: (Int, Int, Int)
    var colours: Int
}

/// One pixel of the rendered bitmap.
struct Pixel {
    var r: Int
    var g: Int
    var b: Int
}

/// The rendered bitmap of a view, and the scale it was rendered at.
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

/// Render a view into a 2x bitmap and read its pixels.
func render(_ view: NSView) -> Bitmap? {
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    rep.size = view.bounds.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.black.setFill()
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
func bitmapRows(for rect: CGRect, hostHeight: CGFloat, scale: Double) -> Range<Int> {
    let top = Int((hostHeight - rect.origin.y - rect.height) * scale)
    let bottom = Int((hostHeight - rect.origin.y) * scale)
    return top ..< bottom
}

/// The mean colour and the distinct colour count of the bitmap's rows
/// inside a view rect.
func readRegion(_ bitmap: Bitmap, rect: CGRect, hostHeight: CGFloat) -> Reading? {
    let rows = bitmapRows(for: rect, hostHeight: hostHeight, scale: Double(bitmap.scale))
    let x0 = Int(rect.origin.x * Double(bitmap.scale))
    let x1 = x0 + Int(rect.width * Double(bitmap.scale))
    var r = 0
    var g = 0
    var b = 0
    var count = 0
    var seen = Set<Int>()
    for y in rows {
        for x in x0 ..< x1 {
            guard let pixel = bitmap.at(x, y) else { continue }
            r += pixel.r
            g += pixel.g
            b += pixel.b
            seen.insert((pixel.r << 16) | (pixel.g << 8) | pixel.b)
            count += 1
        }
    }
    guard count > 0 else { return nil }
    return Reading(rgb: (r / count, g / count, b / count), colours: seen.count)
}

/// The rows of the bitmap where the control paints something, = = = the
/// rows whose pixels differ from the bare host layer.
func drawnBand(_ bitmap: Bitmap, xRange: Range<Int>, host: Pixel) -> Range<Int>? {
    var first = -1
    var last = -1
    for y in 0 ..< bitmap.height {
        var painted = false
        for x in xRange {
            guard let pixel = bitmap.at(x, y) else { continue }
            if abs(pixel.r - host.r) > 2 || abs(pixel.g - host.g) > 2 || abs(pixel.b - host.b) > 2 {
                painted = true
                break
            }
        }
        if painted {
            if first < 0 {
                first = y
            }
            last = y
        }
    }
    guard first >= 0 else { return nil }
    return first ..< (last + 1)
}

/// Cover a view rect with an opaque fill (= what an opaque cell would
/// do to the pixels under it). = The cover is a LAYER-BACKED SUBVIEW, =
/// so the rendering path is the same one the control itself uses, = and
/// no graphics context has to be faked.
func coverOpaque(_ view: NSView, rect: CGRect) {
    let cover = NSView(frame: rect)
    cover.wantsLayer = true
    cover.layer?.backgroundColor = opaqueFill.cgColor
    view.addSubview(cover)
}

/// What one appearance's measurement came to.
struct Measurement {
    var band: Range<Int>
    var cell: Reading?
    var backdrop: Reading?
    var opaque: Reading?
    var cellRect: CGRect
}

/// Render the control alone over the host layer, in one appearance.
func measure(appearance: NSAppearance.Name) -> Measurement? {
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: hostSize),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
    window.appearance = NSAppearance(named: appearance)

    let host = NSView(frame: NSRect(origin: .zero, size: hostSize))
    host.wantsLayer = true
    host.layer?.backgroundColor = hostLayerColour.cgColor
    window.contentView = host

    let control = NSSegmentedControl()
    control.segmentCount = labels.count
    control.trackingMode = .selectOne
    control.controlSize = .small
    control.segmentStyle = .roundRect
    control.role = .valueSelection
    control.selectedSegment = selectedSegment
    for (index, label) in labels.enumerated() {
        control.setLabel(label, forSegment: index)
    }
    host.addSubview(control)
    control.frame = controlFrame

    window.orderFront(nil)
    host.layoutSubtreeIfNeeded()
    control.layoutSubtreeIfNeeded()
    window.displayIfNeeded()

    // The bare host colour, = = = measured where the control is NOT.
    let backdropRect = CGRect(x: 1, y: 1, width: 6, height: 6)
    guard let first = render(host), let hostPixel = first.at(2, first.height - 2) else {
        window.orderOut(nil)
        return nil
    }

    // The measured segment's x range, = = = in the bitmap's pixels.
    let segmentWidth = controlFrame.width / CGFloat(labels.count)
    let segmentRect = CGRect(
        x: controlFrame.origin.x + CGFloat(measuredSegment) * segmentWidth,
        y: controlFrame.origin.y,
        width: segmentWidth,
        height: controlFrame.height
    )
    let x0 = Int(segmentRect.origin.x * Double(first.scale))
    let x1 = x0 + Int(segmentRect.width * Double(first.scale))
    guard let band = drawnBand(first, xRange: x0 ..< x1, host: hostPixel) else {
        window.orderOut(nil)
        return nil
    }

    // The measured area: = = = the band's middle, = = = in POINTS, = =
    // = = = and wholly inside the band.
    let bandHeightPoints = CGFloat(band.count) / CGFloat(first.scale)
    let bandTopPoints = hostSize.height - CGFloat(band.upperBound) / CGFloat(first.scale)
    let measuredHeight = min(12.0, bandHeightPoints - 4)
    let measuredRect = CGRect(
        x: segmentRect.origin.x + segmentWidth / 2 - 12,
        y: bandTopPoints + (bandHeightPoints - measuredHeight) / 2,
        width: 24,
        height: measuredHeight
    )

    let backdrop = readRegion(first, rect: backdropRect, hostHeight: hostSize.height)
    let cell = readRegion(first, rect: measuredRect, hostHeight: hostSize.height)

    // The opacity control: = = = the SAME area, = = = with an opaque
    // fill painted over it.
    coverOpaque(host, rect: measuredRect)
    host.layoutSubtreeIfNeeded()
    let opaque = render(host).flatMap { readRegion($0, rect: measuredRect, hostHeight: hostSize.height) }

    window.orderOut(nil)
    return Measurement(
        band: band,
        cell: cell,
        backdrop: backdrop,
        opaque: opaque,
        cellRect: measuredRect
    )
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

print("probe: segmented_control_material")
print("source_commit: \(gitHead())")
print("host_size_pt: \(Int(hostSize.width)) x \(Int(hostSize.height))")
print("control_frame_pt: (\(Int(controlFrame.origin.x)), \(Int(controlFrame.origin.y)), "
    + "\(Int(controlFrame.width)), \(Int(controlFrame.height)))")
print("control_size: small")
print("control_role: valueSelection")
print("control_style: roundRect")
print("selected_segment: \(selectedSegment)")
print("measured_segment: \(measuredSegment)")
print("host_layer_colour: calibrated (\(hostLayerColour.redComponent), "
    + "\(hostLayerColour.greenComponent), \(hostLayerColour.blueComponent))")
print("opaque_control_colour: calibrated white (\(opaqueFill.whiteComponent))")

var sound = true
for (name, appearance) in [("darkAqua", NSAppearance.Name.darkAqua), ("aqua", .aqua)] {
    guard let measurement = measure(appearance: appearance) else {
        print("appearance: \(name)")
        print("drawn_band_pt: (unread)")
        print("cell_area_pt: (unread)")
        print("cell_area_rgb: (unread)")
        print("cell_area_colours: 0")
        print("backdrop_rgb: (unread)")
        print("backdrop_colours: 0")
        print("opaque_area_rgb: (unread)")
        sound = false
        continue
    }
    let rect = measurement.cellRect
    let band = measurement.band
    print("appearance: \(name)")
    print("drawn_band_pt: (\(Int(hostSize.height - CGFloat(band.upperBound) / 2)), "
        + "\(Int(hostSize.height - CGFloat(band.lowerBound) / 2)))")
    print("cell_area_pt: (\(Int(rect.origin.x)), \(Int(rect.origin.y)), "
        + "\(Int(rect.width)), \(Int(rect.height)))")
    if let cell = measurement.cell {
        print("cell_area_rgb: (\(cell.rgb.0), \(cell.rgb.1), \(cell.rgb.2))")
        print("cell_area_colours: \(cell.colours)")
    } else {
        print("cell_area_rgb: (unread)")
        print("cell_area_colours: 0")
        sound = false
    }
    if let backdrop = measurement.backdrop {
        print("backdrop_rgb: (\(backdrop.rgb.0), \(backdrop.rgb.1), \(backdrop.rgb.2))")
        print("backdrop_colours: \(backdrop.colours)")
    } else {
        print("backdrop_rgb: (unread)")
        print("backdrop_colours: 0")
        sound = false
    }
    if let opaque = measurement.opaque {
        print("opaque_area_rgb: (\(opaque.rgb.0), \(opaque.rgb.1), \(opaque.rgb.2))")
        print("opaque_area_colours: \(opaque.colours)")
    } else {
        print("opaque_area_rgb: (unread)")
        sound = false
    }
}

exit(sound ? 0 : 3)
