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
//      backdrop_rgb            the host layer's own rendered colour
//      backdrop_colours        the distinct colours in that same area
//      control_area_rgb        the mean colour of the control's cells
//      control_area_colours    the distinct colours in that same area
//
//    Every number names the APPEARANCE it was read in, = because the
//    control's own rendering is appearance-dependent, = and a number
//    without its appearance does not describe anything.
//
//  HOW IT MEASURES
//    It renders the control offscreen into a 2x `NSBitmapImageRep` and
//    reads the pixels of two named regions:
//
//      the control's own area   the region (40, 4, 24, 12) PT, = = =
//                               the lower half of the FIRST segment, = =
//                               which carries the label's ink
//      the backdrop beside it    the region (1, 1, 6, 6) PT, = = = the
//                               same host layer, = untouched
//
//    The regions are in POINTS; the bitmap is 2x, = so each point is two
//    pixels. = The names and the geometry are part of the number: = the
//    same measurement over a different region, = or at a different host
//    size, = is a different number.
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
//      labels                   标签1 / 标签2 / 标签3
//      host_layer_colour        calibrated (0, 0.55, 0.25)
//
//  THE TRAP IT AVOIDS
//    A material CONTAINER (= an `NSVisualEffectView` behind the control, =
//    or an `NSGlassEffectView` around it) changes the reading by a factor
//    of three and by appearance, = and in the dark appearance it changes
//    the QUALITATIVE reading too. = So this probe measures the control
//    ALONE: = the control's own material is what the app asks for, = and
//    a container's number would answer a different question.
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

/// The control's own area, in POINTS.
let controlArea = CGRect(x: 40, y: 4, width: 24, height: 12)
/// The host layer beside the control, in POINTS.
let backdropArea = CGRect(x: 1, y: 1, width: 6, height: 6)

let appearances: [(String, NSAppearance.Name)] = [
    ("darkAqua", .darkAqua),
    ("aqua", .aqua),
]

// MARK: - The measurement

struct Reading {
    var rgb: (Int, Int, Int)
    var colours: Int
}

/// Read the mean colour and the distinct colour count of one region of a
/// rendered view.
func readRegion(of view: NSView, rect: CGRect) -> Reading? {
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
    let scale = 2.0
    var r = 0
    var g = 0
    var b = 0
    var count = 0
    var seen = Set<Int>()
    var y = Int(rect.origin.y * scale)
    let yEnd = y + Int(rect.height * scale)
    while y < yEnd {
        var x = Int(rect.origin.x * scale)
        let xEnd = x + Int(rect.width * scale)
        while x < xEnd {
            let offset = y * rowBytes + x * samples
            r += Int(data[offset])
            g += Int(data[offset + 1])
            b += Int(data[offset + 2])
            seen.insert((Int(data[offset]) << 16) | (Int(data[offset + 1]) << 8) | Int(data[offset + 2]))
            count += 1
            x += 1
        }
        y += 1
    }
    guard count > 0 else { return nil }
    return Reading(rgb: (r / count, g / count, b / count), colours: seen.count)
}

/// Render the control alone over the host layer, in one appearance.
func measure(appearance: NSAppearance.Name) -> (control: Reading?, backdrop: Reading?)? {
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

    let controlReading = readRegion(of: host, rect: controlArea)
    let backdropReading = readRegion(of: host, rect: backdropArea)
    window.orderOut(nil)
    return (controlReading, backdropReading)
}

// MARK: - The report

func gitHead() -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // probes
        .deletingLastPathComponent()  // wenshu-devtool
        .deletingLastPathComponent()  // Tools
        .deletingLastPathComponent()  // the repo root
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
print("host_layer_colour: calibrated (\(hostLayerColour.redComponent), "
    + "\(hostLayerColour.greenComponent), \(hostLayerColour.blueComponent))")
print("control_area_pt: (\(Int(controlArea.origin.x)), \(Int(controlArea.origin.y)), "
    + "\(Int(controlArea.width)), \(Int(controlArea.height)))")
print("backdrop_area_pt: (\(Int(backdropArea.origin.x)), \(Int(backdropArea.origin.y)), "
    + "\(Int(backdropArea.width)), \(Int(backdropArea.height)))")

var sound = true
for (name, appearance) in appearances {
    guard let readings = measure(appearance: appearance) else {
        print("appearance: \(name)")
        print("control_area_rgb: (unread)")
        print("control_area_colours: 0")
        print("backdrop_rgb: (unread)")
        print("backdrop_colours: 0")
        sound = false
        continue
    }
    print("appearance: \(name)")
    if let control = readings.control {
        print("control_area_rgb: (\(control.rgb.0), \(control.rgb.1), \(control.rgb.2))")
        print("control_area_colours: \(control.colours)")
    } else {
        print("control_area_rgb: (unread)")
        print("control_area_colours: 0")
        sound = false
    }
    if let backdrop = readings.backdrop {
        print("backdrop_rgb: (\(backdrop.rgb.0), \(backdrop.rgb.1), \(backdrop.rgb.2))")
        print("backdrop_colours: \(backdrop.colours)")
    } else {
        print("backdrop_rgb: (unread)")
        print("backdrop_colours: 0")
        sound = false
    }
}

exit(sound ? 0 : 3)
