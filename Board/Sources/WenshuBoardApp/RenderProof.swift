//
//  RenderProof.swift
//  WenshuBoard
//
//  Renders the canvas offscreen.
//
//  A canvas is a geometry claim: "this card lands at this pixel". A window
//  proves nothing about a claim like that, because a human's eye cannot
//  measure a pixel. `ImageRenderer` renders the same view tree into a bitmap
//  with no window and no human, so the claim can be looked at and diffed.
//

import AppKit
import SwiftUI
import WenshuBoardKit

enum RenderProof {

    /// The output directory, if the process was asked for one.
    static func requestedDirectory() -> String? {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--render-proof"),
              flag + 1 < arguments.count else { return nil }
        return arguments[flag + 1]
    }

    /// How many bitmaps a successful run writes.
    static let expectedBitmaps = 2

    /// Renders the canvas at two viewports and writes both bitmaps.
    ///
    /// - Returns: the number of bitmaps written. A proof that cannot fail is
    ///   not a proof: the caller exits non-zero when the count is short, so a
    ///   run that produced nothing is distinguishable from a passing one.
    @MainActor
    static func write(to directory: String) -> Int {
        let cases: [(name: String, viewport: BoardViewport)] = [
            ("canvas-1x", BoardViewport(scale: 1, offset: CGPoint(x: 60, y: 40))),
            ("canvas-zoom", BoardViewport(scale: 1.6, offset: CGPoint(x: -40, y: -20))),
        ]
        var written = 0
        for testCase in cases {
            let canvas = BoardCanvasView(
                elements: BoardCanvasDemo.elements,
                viewport: testCase.viewport
            )
            .frame(width: 900, height: 560)

            let renderer = ImageRenderer(content: canvas)
            renderer.scale = 2

            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write(Data("render failed: \(testCase.name)\n".utf8))
                continue
            }
            let path = URL(fileURLWithPath: directory).appendingPathComponent("\(testCase.name).png")
            do {
                try png.write(to: path)
                print("rendered \(path.path)")
                written += 1
            } catch {
                FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
            }
        }
        return written
    }
}
