//
//  chat_bubble_metrics.swift
//
//  Measure the user's own chat bubble: the width its fill paints and the
//  corner radius its shape paints, both read from rendered pixels.
//
//  WHAT IT MEASURES
//    The outgoing (= the user's own) message bubble of the chat column.
//
//      painted_width_pt    the points of the host width the bubble's fill
//                          covers
//      painted_height_pt   the points the bubble's fill covers vertically
//      corner_radius_pt    the radius of the bubble's corner arc
//
//  HOW IT MEASURES
//    It renders the production chain around the subject text into an
//    offscreen NSHostingView at the reference host width, then reads the
//    pixels of the rendered fill. The production tokens (spacingModerate,
//    controlHeightLarge) are parsed out of DesignTokens.swift and the
//    production shape rule (radius = min(height / 2, controlHeightLarge / 2))
//    is reproduced from ChatSurfaceShape.swift, so a token change moves the
//    number instead of leaving a stale one behind.
//
//    The corner radius is fitted, not guessed: the boundary pixels of the
//    top-left and top-right corners are collected and a circle is fitted to
//    them (Kasa). The same fit runs on a reference shape of a known radius
//    every time, and the reference result is printed next to the bubble's,
//    so a reader can see the fit was calibrated on this run.
//
//  THE TRAP IT AVOIDS
//    A rounded shape touches its top edge only at its apex, so the first
//    painted pixel of the top row is NOT the corner's tangent: reading the
//    radius that way under-reads it by the shape's own curvature. The fit
//    uses the whole arc instead.
//
//    The production fill is an appearance-dependent semantic colour that
//    collapses into the panel behind it in the dark appearance, so a probe
//    cannot find the bubble's pixels in a screenshot of the app. The probe
//    therefore paints the production SHAPE in a colour it can recognise and
//    measures the geometry, which the fill colour does not affect.
//
//    The bubble's background is painted after .frame(maxWidth: .infinity),
//    so the fill covers the whole chat column and not the text's width.
//    Reading the text's width answers a different question; the probe
//    reports both the fill's width and the subject's own inked width.
//
//  Read-only: the probe reads the app's source files, renders into memory
//  and prints to stdout. It creates, moves and deletes no file.
//
//  Usage:
//      swift Tools/wenshu-devtool/probes/chat_bubble_metrics.swift "Hi"
//      swift Tools/wenshu-devtool/probes/chat_bubble_metrics.swift "Hi" 900
//
//  Exit: 0 = the measurement is sound, 2 = the production source does not
//  match what this probe reproduces (no number is reported; a stale number
//  is worse than none), 3 = the fill was not found in the rendered pixels.
//

import AppKit
import SwiftUI

// MARK: - Reference constants

/// Host width (PT) the measurement is taken at. The bubble's fill spans the
/// width the chat column offers it, so the host width is part of the number.
let referenceHostWidth: CGFloat = 723

/// Host height (PT). The bubble's own height comes from its content.
let referenceHostHeight: CGFloat = 160

/// The colour the probe paints the production shape in, so the filled
/// pixels can be found in the rendered bitmap.
let detectorColor = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)

/// Radius of the reference shape the fit is calibrated against every run.
let calibrationRadius: CGFloat = 10

// MARK: - Production source reading

/// The app's source files this probe measures against.
struct ProductionSource {
    let root: URL
    let designTokens: String
    let surfaceShape: String
    let messageView: String

    /// The repository root, derived from this file's own path (= the probe
    /// lives inside the repository, so the path is known at compile time).
    static func locate() -> ProductionSource? {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let tokens = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let shape = root.appendingPathComponent("Sources/WenshuApp/Features/Chat/View/ChatSurfaceShape.swift")
        let message = root.appendingPathComponent("Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift")
        guard let tokensText = try? String(contentsOf: tokens, encoding: .utf8),
              let shapeText = try? String(contentsOf: shape, encoding: .utf8),
              let messageText = try? String(contentsOf: message, encoding: .utf8)
        else { return nil }
        return ProductionSource(root: root, designTokens: tokensText, surfaceShape: shapeText, messageView: messageText)
    }

    /// The value of a `static let <name>: CGFloat = <number>` token.
    func token(_ name: String) -> Double? {
        let pattern = "static\\s+let\\s+\(name)\\s*:\\s*CGFloat\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let text = designTokens as NSString
        let range = NSRange(location: 0, length: text.length)
        guard let match = expression.firstMatch(in: designTokens, range: range),
              match.numberOfRanges > 1
        else { return nil }
        return Double(text.substring(with: match.range(at: 1)))
    }

    /// The commit the measured sources sit at.
    var commit: String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path, "rev-parse", "--short=12", "HEAD"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return "unknown" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "unknown" : text
    }
}

/// Whitespace collapsed to single spaces, so a source fragment can be found
/// whatever line the author wrapped it onto.
func normalized(_ text: String) -> String {
    text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
}

/// The fragments the probe reproduces, each with the file it is read from.
func sourceChecks(_ source: ProductionSource) -> [(name: String, ok: Bool)] {
    let tokens = normalized(source.designTokens)
    let shape = normalized(source.surfaceShape)
    let message = normalized(source.messageView)
    return [
        ("DesignTokens.spacingModerate", tokens.contains("static let spacingModerate: CGFloat =")),
        ("DesignTokens.controlHeightLarge", tokens.contains("static let controlHeightLarge: CGFloat =")),
        ("ChatSurfaceShape radius rule", shape.contains("let radius = min(rect.height / 2, maxCorner)")),
        ("ChatSurfaceShape corner cap", shape.contains("maxCorner = DesignTokens.controlHeightLarge / 2")),
        ("ChatMessageView padding", message.contains(".padding(.horizontal, DesignTokens.spacingModerate)")),
        ("ChatMessageView frame", message.contains(".frame(maxWidth: .infinity, minHeight: DesignTokens.controlHeightLarge, alignment: .leading)")),
        ("ChatMessageView background", message.contains(".background( ChatSurfaceShape()") && message.contains(".fill(Color(nsColor: ChatUserBubblePalette.surface))")),
    ]
}

// MARK: - The bubble under measurement

/// The production chain of the user's own bubble, reproduced from
/// ChatMessageView.swift's UserGlassCardModifier.
struct BubbleUnderTest: View {
    let subject: String
    let horizontalPadding: CGFloat
    let restingHeight: CGFloat
    let cornerCap: CGFloat

    var body: some View {
        Text(subject)
            // The ink measurement must not depend on the machine's
            // appearance, so the subject is painted black here. The glyph
            // extent does not depend on the colour.
            .foregroundStyle(Color.black)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: restingHeight, alignment: .leading)
            .background(
                ProductionSurfaceShape(cornerCap: cornerCap)
                    .fill(Color(nsColor: detectorColor))
            )
    }
}

/// The production shape of ChatSurfaceShape.swift: the radius tracks half
/// the height up to the cap, so a resting surface reads as a capsule.
struct ProductionSurfaceShape: Shape {
    let cornerCap: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: min(rect.height / 2, cornerCap))
    }
}

/// The reference shape the radius fit is calibrated against.
struct ReferenceShape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: calibrationRadius, style: .circular)
            .fill(Color(nsColor: detectorColor))
            .frame(width: 200, height: 60)
    }
}

// MARK: - Rendering

/// A rendered bitmap, top row first.
struct Bitmap {
    var width: Int
    var height: Int
    var scale: Double
    var rgba: [UInt8]

    func coverage(x: Int, y: Int) -> Double {
        1.0 - Double(rgba[(y * width + x) * 4 + 2]) / 255.0
    }

    func isInk(x: Int, y: Int) -> Bool {
        rgba[(y * width + x) * 4] < 200
    }

    /// Sub-pixel x where the fill's coverage crosses one half, scanning in
    /// from the left edge.
    func leftEdge(row: Int) -> Double? {
        var x = 0
        while x < width, coverage(x: x, y: row) < 0.5 { x += 1 }
        guard x < width else { return nil }
        guard x > 0 else { return Double(x) }
        let before = coverage(x: x - 1, y: row)
        let after = coverage(x: x, y: row)
        guard after > before else { return Double(x) }
        return Double(x - 1) + (0.5 - before) / (after - before)
    }

    /// Sub-pixel x where the fill's coverage crosses one half, scanning in
    /// from the right edge.
    func rightEdge(row: Int) -> Double? {
        var x = width - 1
        while x >= 0, coverage(x: x, y: row) < 0.5 { x -= 1 }
        guard x >= 0 else { return nil }
        guard x < width - 1 else { return Double(x) }
        let inside = coverage(x: x, y: row)
        let outside = coverage(x: x + 1, y: row)
        guard inside > outside else { return Double(x) }
        return Double(x) + (inside - 0.5) / (inside - outside)
    }

    /// Sub-pixel y where the fill's coverage crosses one half, scanning in
    /// from the top edge.
    func topEdge(column: Int) -> Double? {
        var y = 0
        while y < height, coverage(x: column, y: y) < 0.5 { y += 1 }
        guard y < height else { return nil }
        guard y > 0 else { return Double(y) }
        let before = coverage(x: column, y: y - 1)
        let after = coverage(x: column, y: y)
        guard after > before else { return Double(y) }
        return Double(y - 1) + (0.5 - before) / (after - before)
    }

    /// Sub-pixel y where the fill's coverage crosses one half, scanning in
    /// from the bottom edge.
    func bottomEdge(column: Int) -> Double? {
        var y = height - 1
        while y >= 0, coverage(x: column, y: y) < 0.5 { y -= 1 }
        guard y >= 0 else { return nil }
        guard y < height - 1 else { return Double(y) }
        let inside = coverage(x: column, y: y)
        let outside = coverage(x: column, y: y + 1)
        guard inside > outside else { return Double(y) }
        return Double(y) + (inside - 0.5) / (inside - outside)
    }
}

/// Render a view offscreen and return its bitmap.
@MainActor
func render(_ view: some View, width: CGFloat, height: CGFloat) -> Bitmap? {
    let host = NSHostingView(rootView: AnyView(ZStack {
        // An opaque backdrop, so a pixel that is not the fill reads as
        // empty. A transparent backdrop reads as covered everywhere.
        Color.white
        view
    }))
    host.frame = NSRect(x: 0, y: 0, width: width, height: height)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    host.layoutSubtreeIfNeeded()

    // The bitmap is drawn FIRST and the image is read AFTER, because the
    // CGImage of a bitmap rep is a view of that rep's buffer: reading it
    // before the draw yields the rep's blank contents.
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
    host.cacheDisplay(in: host.bounds, to: rep)
    guard let image = rep.cgImage else { return nil }

    let pixelWidth = image.width
    let pixelHeight = image.height
    var pixels = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
    guard let context = CGContext(
        data: &pixels,
        width: pixelWidth,
        height: pixelHeight,
        bitsPerComponent: 8,
        bytesPerRow: pixelWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

    // Core Graphics rows run bottom up; the probe reads top down.
    var flipped = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
    for row in 0..<pixelHeight {
        let source = (pixelHeight - 1 - row) * pixelWidth * 4
        let target = row * pixelWidth * 4
        flipped[target ..< target + pixelWidth * 4] = pixels[source ..< source + pixelWidth * 4]
    }
    return Bitmap(
        width: pixelWidth,
        height: pixelHeight,
        scale: Double(pixelWidth) / Double(width),
        rgba: flipped
    )
}

// MARK: - Geometry

/// The measured box of the painted fill, in pixels.
struct PaintedBox {
    var left: Double
    var right: Double
    var top: Double
    var bottom: Double
}

/// The painted box of the fill, with sub-pixel edges.
func paintedBox(_ bitmap: Bitmap) -> PaintedBox? {
    var left = Double.infinity
    var right = -Double.infinity
    var top = Double.infinity
    var bottom = -Double.infinity
    for row in 0..<bitmap.height {
        if let edge = bitmap.leftEdge(row: row) {
            left = min(left, edge)
            right = max(right, bitmap.rightEdge(row: row) ?? edge)
        }
    }
    for column in 0..<bitmap.width {
        if let edge = bitmap.topEdge(column: column) {
            top = min(top, edge)
            bottom = max(bottom, bitmap.bottomEdge(column: column) ?? edge)
        }
    }
    guard left.isFinite, right.isFinite, top.isFinite, bottom.isFinite, right > left else { return nil }
    return PaintedBox(left: left, right: right, top: top, bottom: bottom)
}

/// Fit a circle to points and return its radius.
func fitRadius(_ points: [(Double, Double)]) -> Double? {
    guard points.count >= 3 else { return nil }
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0, sumYY = 0.0
    var sumXXX = 0.0, sumXYY = 0.0, sumXXY = 0.0, sumYYY = 0.0
    for (x, y) in points {
        sumX += x; sumY += y; sumXY += x * y
        sumXX += x * x; sumYY += y * y
        sumXXX += x * x * x; sumXYY += x * y * y
        sumXXY += x * x * y; sumYYY += y * y * y
    }
    let count = Double(points.count)
    let rightHand = [-sumXXX - sumXYY, -sumXXY - sumYYY, -sumXX - sumYY]
    let matrix: [[Double]] = [
        [sumXX, sumXY, sumX],
        [sumXY, sumYY, sumY],
        [sumX, sumY, count],
    ]
    guard let solution = solve(matrix: matrix, rightHand: rightHand) else { return nil }
    let centerX = -solution[0] / 2
    let centerY = -solution[1] / 2
    let squared = centerX * centerX + centerY * centerY - solution[2]
    guard squared > 0 else { return nil }
    return sqrt(squared)
}

/// Solve a three by three system by Gaussian elimination.
func solve(matrix: [[Double]], rightHand: [Double]) -> [Double]? {
    var rows = matrix
    var values = rightHand
    for pivot in 0..<3 {
        var best = pivot
        for row in pivot..<3 where abs(rows[row][pivot]) > abs(rows[best][pivot]) {
            best = row
        }
        guard abs(rows[best][pivot]) > 1e-9 else { return nil }
        rows.swapAt(pivot, best)
        values.swapAt(pivot, best)
        for row in (pivot + 1)..<3 {
            let factor = rows[row][pivot] / rows[pivot][pivot]
            for column in pivot..<3 {
                rows[row][column] -= factor * rows[pivot][column]
            }
            values[row] -= factor * values[pivot]
        }
    }
    var solution = [Double](repeating: 0, count: 3)
    for row in stride(from: 2, through: 0, by: -1) {
        var sum = values[row]
        for column in (row + 1)..<3 {
            sum -= rows[row][column] * solution[column]
        }
        solution[row] = sum / rows[row][row]
    }
    return solution
}

/// The corner radius of the painted fill, in points, fitted to the arc.
func cornerRadius(_ bitmap: Bitmap, box: PaintedBox) -> Double? {
    let topRow = Int(box.top.rounded(.down))
    let height = Int((box.bottom - box.top).rounded(.up))
    let reach = max(2, height / 2)

    var leftPoints: [(Double, Double)] = []
    var rightPoints: [(Double, Double)] = []
    for row in topRow...(topRow + reach) where row < bitmap.height {
        guard let left = bitmap.leftEdge(row: row), let right = bitmap.rightEdge(row: row) else { continue }
        // A row whose edge sits on the vertical side is not on the arc.
        if left - box.left > 0.5 { leftPoints.append((left, Double(row))) }
        if box.right - right > 0.5 { rightPoints.append((right, Double(row))) }
    }
    let leftRadius = fitRadius(leftPoints)
    let rightRadius = fitRadius(rightPoints)
    guard let leftRadius, let rightRadius else { return leftRadius ?? rightRadius }
    return (leftRadius + rightRadius) / 2
}

/// The width of the subject's own ink, in points.
func inkWidth(_ bitmap: Bitmap) -> Double {
    var minX = Int.max
    var maxX = -1
    for y in 0..<bitmap.height {
        for x in 0..<bitmap.width where bitmap.isInk(x: x, y: y) {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
        }
    }
    guard maxX >= minX else { return 0 }
    return Double(maxX - minX + 1) / bitmap.scale
}

// MARK: - Run

@MainActor
func run(subject: String, hostWidth: CGFloat) -> Int {
    guard let source = ProductionSource.locate() else {
        print("source_check: NOT-CHECKED (the app's source files were not found)")
        print("no number is reported: a number that cannot be tied to the source is worse than none")
        return 2
    }
    let checks = sourceChecks(source)
    let failed = checks.filter { !$0.ok }
    for check in checks {
        print("source_check: \(check.ok ? "ok" : "MISMATCH") \(check.name)")
    }
    if !failed.isEmpty {
        print("no number is reported: the production source no longer matches what this probe reproduces")
        return 2
    }

    guard let padding = source.token("spacingModerate"),
          let restingHeight = source.token("controlHeightLarge")
    else {
        print("source_check: MISMATCH (the production tokens could not be read)")
        return 2
    }
    let cornerCap = restingHeight / 2

    let bubble = BubbleUnderTest(
        subject: subject,
        horizontalPadding: CGFloat(padding),
        restingHeight: CGFloat(restingHeight),
        cornerCap: CGFloat(cornerCap)
    )
    guard let bitmap = render(bubble, width: hostWidth, height: referenceHostHeight),
          let box = paintedBox(bitmap)
    else {
        print("the fill was not found in the rendered pixels")
        return 3
    }
    guard let radiusPixels = cornerRadius(bitmap, box: box) else {
        print("the corner arc could not be fitted")
        return 3
    }

    // The same fit, on a shape of a known radius, so the reader can see the
    // fit was calibrated on this run.
    var calibration = 0.0
    if let reference = render(ReferenceShape(), width: 300, height: 120),
       let referenceBox = paintedBox(reference),
       let referenceRadius = cornerRadius(reference, box: referenceBox) {
        calibration = referenceRadius / reference.scale
    }

    let paintedWidth = (box.right - box.left) / bitmap.scale
    let paintedHeight = (box.bottom - box.top) / bitmap.scale
    let radius = radiusPixels / bitmap.scale
    let ruleRadius = min(paintedHeight / 2, cornerCap)

    print("probe: chat_bubble_metrics")
    print("subject: \(subject)")
    print("host_width_pt: \(format(Double(hostWidth)))")
    print("painted_width_pt: \(format(paintedWidth))")
    print("painted_height_pt: \(format(paintedHeight))")
    print("corner_radius_pt: \(format(radius))")
    print("shape_rule_radius_pt: \(format(ruleRadius))")
    print("subject_ink_width_pt: \(format(inkWidth(bitmap)))")
    print("calibration_radius_pt: \(format(Double(calibrationRadius)))")
    print("calibration_measured_pt: \(format(calibration))")
    print("source_commit: \(source.commit)")
    return 0
}

func format(_ value: Double) -> String {
    String(format: "%.1f", value)
}

// MARK: - Entry

let arguments = CommandLine.arguments
let subject = arguments.count > 1 ? arguments[1] : "Hi"
let hostWidth = arguments.count > 2 ? (CGFloat(Double(arguments[2]) ?? Double(referenceHostWidth))) : referenceHostWidth
exit(MainActor.assumeIsolated { Int32(run(subject: subject, hostWidth: hostWidth)) })
