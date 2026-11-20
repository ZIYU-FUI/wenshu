//
//  segmented_control_segment_frames.swift
//
//  Measure the native segmented control's per-segment geometry and its
//  per-segment DRAWING HOOKS, = so a per-tab close button can be drawn
//  where the tab actually is.
//
//  WHAT IT MEASURES
//
//    draw_segment_calls     how many times the cell's per-segment
//                           interior hook fired, = and with which frames
//    control_draw_calls     how many times the control's own draw(_:)
//                           fired (= = = whether the control is
//                           layer-backed, = = = which decides whether a
//                           subclass can paint over it)
//    segment_frame_<n>      the frame the cell was given for segment n
//    segment_tracking       the frame the cell reports for tracking
//
//  WHY IT MEASURES
//
//    A Safari-style close X lives INSIDE the tab, = so it has to be
//    drawn where the tab is, = and it has to be drawn by ONE view
//    (= the control itself, = because N sibling buttons in a ForEach is
//    the shape that crashed this app). = ⇒ Two things must be known
//    before that can be written: = = = which hook paints a segment's
//    interior on macOS 27, = = = and what frame that segment owns.
//
//  THE PARAMETERS THAT DECIDE THE NUMBER
//
//    host_size_pt             260 x 40
//    control_frame_pt         (10, 6, 240, 28)
//    control_size             .small
//    control_role             .valueSelection
//    control_style            .roundRect
//    segment_distribution     .fillEqually
//    labels                   the three CJK labels the probe builds below
//
//  Read-only: the probe renders into memory and prints to stdout. = It
//  creates, moves and deletes no file.
//
//  Usage:
//      swift Tools/wenshu-devtool/probes/segmented_control_segment_frames.swift
//
//  Exit: 0 = the measurement is sound, 3 = the control drew no segment.
//

import AppKit
import Foundation

// MARK: - The parameters that decide the number

let hostSize = NSSize(width: 260, height: 40)
let controlFrame = NSRect(x: 10, y: 6, width: 240, height: 28)
let labels = ["标签1", "标签2", "标签3"]

// MARK: - The probes

/// A cell that records the per-segment interior hook's calls, = and
/// paints a MARKER in the segment's interior (= the question the hook
/// has to answer before anything is drawn in it: = = = does a drawing
/// made here REACH THE PIXELS, = or does the control's own bezel
/// cover it?).
final class RecordingCell: NSSegmentedCell {
    var segmentCalls: [(Int, NSRect)] = []
    var markerSegment = -1

    override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
        segmentCalls.append((segment, frame))
        super.drawSegment(segment, inFrame: frame, with: controlView)
        guard segment == markerSegment else { return }
        let marker = NSRect(
            x: frame.maxX - 14,
            y: frame.minY + 4,
            width: 10,
            height: 10
        )
        NSColor.systemRed.setFill()
        marker.fill()
    }
}

/// A control that records its own draw(_:) calls (= = = the layer-baking
/// question: = if the control is layer-backed, = a subclass's draw(_:)
/// override is never called, = and the X would have to be a subview
/// instead).
final class RecordingControl: NSSegmentedControl {
    var drawCalls = 0

    override func draw(_ dirtyRect: NSRect) {
        drawCalls += 1
        super.draw(dirtyRect)
    }
}

// MARK: - The measurement

func render(_ view: NSView) {
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    rep.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: rep)
}

func measure() -> (RecordingControl, RecordingCell, NSWindow)? {
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: hostSize),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.setFrameOrigin(NSPoint(x: -20000, y: -20000))

    let host = NSView(frame: NSRect(origin: .zero, size: hostSize))
    window.contentView = host

    let control = RecordingControl(frame: controlFrame)
    let cell = RecordingCell()
    control.cell = cell
    control.segmentCount = labels.count
    control.segmentDistribution = .fillEqually
    control.trackingMode = .selectOne
    control.controlSize = .small
    control.segmentStyle = .roundRect
    control.role = .valueSelection
    for (index, label) in labels.enumerated() {
        control.setLabel(label, forSegment: index)
    }
    host.addSubview(control)

    window.orderFront(nil)
    host.layoutSubtreeIfNeeded()
    control.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    render(host)
    window.orderOut(nil)
    return (control, cell, window)
}

// MARK: - The report

print("probe: segmented_control_segment_frames")
print("host_size_pt: \(Int(hostSize.width)) x \(Int(hostSize.height))")
print("control_frame_pt: (\(Int(controlFrame.origin.x)), \(Int(controlFrame.origin.y)), "
    + "\(Int(controlFrame.width)), \(Int(controlFrame.height)))")
print("control_size: small")
print("control_role: valueSelection")
print("control_style: roundRect")
print("segment_distribution: fillEqually")

guard let (control, cell, _) = measure() else {
    print("draw_segment_calls: 0")
    print("control_draw_calls: 0")
    exit(3)
}

print("draw_segment_calls: \(cell.segmentCalls.count)")
print("control_draw_calls: \(control.drawCalls)")
print("control_is_layer_backed: \(control.layer != nil)")
print("control_bounds: (\(Int(control.bounds.origin.x)), \(Int(control.bounds.origin.y)), "
    + "\(Int(control.bounds.width)), \(Int(control.bounds.height)))")
for (segment, frame) in cell.segmentCalls {
    print("segment_frame_\(segment): (\(Int(frame.origin.x)), \(Int(frame.origin.y)), "
        + "\(Int(frame.width)), \(Int(frame.height)))")
}

// The cell's own frames ARE the geometry: = there is no public
// tracking-rect API on a segmented cell, = so the frame the draw hook
// is given is where the segment really is.

// MARK: - Does a drawing made in the hook REACH THE PIXELS?

/// The count of the marker's pixels in a rendered bitmap.
func countMarkerPixels(_ view: NSView) -> Int {
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return -1 }
    rep.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let data = rep.bitmapData else { return -1 }
    var count = 0
    for y in 0 ..< rep.pixelsHigh {
        for x in 0 ..< rep.pixelsWide {
            let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
            let r = Int(data[offset])
            let g = Int(data[offset + 1])
            let b = Int(data[offset + 2])
            if r > 180, g < 90, b < 90 {
                count += 1
            }
        }
    }
    return count
}

if let (control, cell, window) = measure() {
    cell.markerSegment = 1
    control.needsDisplay = true
    window.displayIfNeeded()
    let markerPixels = countMarkerPixels(control)
    print("marker_pixels: \(markerPixels)")
    print("marker_reaches_the_pixels: \(markerPixels > 0)")
}

exit(cell.segmentCalls.isEmpty ? 3 : 0)
