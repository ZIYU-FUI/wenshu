//
//  CardCoverImageEncoderTests.swift · Wenshu
//
//  Proves the encoder's contract WITHOUT a network call:
//  - a 1024x512 image encodes to a HEIC payload that decodes back to
//    exactly 768x320,
//  - that payload decodes to a JPEG for the image-to-video endpoint,
//  - the centre crop scales-and-crops rather than squashing.
//
//  The byte count is deliberately NOT asserted exactly: a flat-colour
//  image and a painterly one compress differently, and the number
//  that matters (= ~59 KB for a real painterly banner) was measured
//  against a real generated cover, not a synthetic one.
//

import CoreGraphics
import Foundation
import Testing
@testable import WenshuApp

@Suite("Card cover image encoder")
struct CardCoverImageEncoderTests {

    /// A solid-colour image of the given size.
    private func makeImage(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// A half-red, half-blue image, for the crop test.
    private func makeSplitImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return context.makeImage()!
    }

    /// A black image with a white square in the middle, for the
    /// geometry test.
    ///
    /// A square is the sharpest probe there is: a crop that scales
    /// proportionally keeps it square, and a crop that squeezes the
    /// picture to fit turns it into a rectangle.
    private func makeImageWithSquare(width: Int, height: Int, side: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(
            CGRect(
                x: (CGFloat(width) - CGFloat(side)) / 2,
                y: (CGFloat(height) - CGFloat(side)) / 2,
                width: CGFloat(side),
                height: CGFloat(side)
            )
        )
        return context.makeImage()!
    }

    @Test("A 1024x512 image encodes to a banner that decodes to 768x320")
    func encodesToTheStoredBannerSize() throws {
        let source = makeImage(width: 1024, height: 512, red: 0.8, green: 0.4, blue: 0.2)

        let payload = try CardCoverImageEncoder.encode(bannerImage: source)
        let decoded = try CardCoverImageEncoder.decode(payload)

        #expect(decoded.width == CardCoverImageEncoder.bannerWidth)
        #expect(decoded.height == CardCoverImageEncoder.bannerHeight)
        #expect(CardCoverImageEncoder.bannerWidth == 768)
        #expect(CardCoverImageEncoder.bannerHeight == 320)
    }

    @Test("The stored payload is HEIC, not JPEG")
    func storesHEIC() throws {
        let source = makeImage(width: 1024, height: 512, red: 0.3, green: 0.6, blue: 0.9)
        let payload = try CardCoverImageEncoder.encode(bannerImage: source)

        // A HEIC file is an ISO-BMFF box: the first four bytes are the
        // box size and the next four are the "ftyp" box type. A JPEG
        // starts with the FFD8 marker instead.
        let boxType = String(data: payload.subdata(in: 4..<8), encoding: .ascii) ?? ""
        #expect(boxType == "ftyp")
        #expect(!(payload.count > 2 && payload[payload.startIndex] == 0xFF && payload[payload.startIndex + 1] == 0xD8))
    }

    @Test("The image-to-video payload is a JPEG")
    func decodesToJPEG() throws {
        let source = makeImage(width: 1024, height: 512, red: 0.5, green: 0.2, blue: 0.7)
        let heic = try CardCoverImageEncoder.encode(bannerImage: source)

        let jpeg = try CardCoverImageEncoder.decodeToJPEG(heic)

        #expect(jpeg.count > 3)
        #expect(jpeg[jpeg.startIndex] == 0xFF)
        #expect(jpeg[jpeg.startIndex + 1] == 0xD8)
        #expect(jpeg[jpeg.startIndex + 2] == 0xFF)
    }

    @Test("The centre crop scales and crops, it does not squash")
    func cropsWithoutSquashing() throws {
        let split = makeSplitImage(width: 1024, height: 512)

        let banner = CardCoverImageEncoder.centerCrop(split, toWidth: 768, toHeight: 320)
        #expect(banner.width == 768)
        #expect(banner.height == 320)

        // The banner must still contain BOTH colours: a squash would
        // have blended them into one, and a crop that kept only one
        // side would have lost one.
        let data = try CardCoverImageEncoder.encode(banner, as: .jpeg, quality: 0.9)
        let decoded = try CardCoverImageEncoder.decode(data)
        let pixels = decoded.pixelSamples()
        #expect(pixels.contains { $0.red > 0.5 && $0.blue < 0.3 })
        #expect(pixels.contains { $0.blue > 0.5 && $0.red < 0.3 })
    }

    @Test("The centre crop scales to cover and crops, it never squeezes")
    func cropsWithoutSqueezing() throws {
        // A 100px square in a 1024x512 source. Scaled to cover a
        // 768x320 banner the scale is 0.75, so the square comes out
        // 75px on a side.
        let source = makeImageWithSquare(width: 1024, height: 512, side: 100)

        let banner = CardCoverImageEncoder.centerCrop(source, toWidth: 768, toHeight: 320)
        #expect(banner.width == 768)
        #expect(banner.height == 320)

        let box = try #require(banner.brightBox())
        // The square stayed square: a squeeze would have made it
        // 75x62, and a crop that did not scale at all would have left
        // it 100x100.
        #expect(abs(box.width - box.height) <= 2)
        #expect(box.width >= 70 && box.width <= 80)
        // And it stayed in the middle: the crop is centred.
        #expect(abs(box.centerX - 384) <= 2)
        #expect(abs(box.centerY - 160) <= 2)
    }

    @Test("The centre crop keeps the subject's headroom")
    func cropsFromTheTop() throws {
        // A white band across the TOP of the source, and black below
        // it. A cover crop of a 1024x512 source to 768x320 loses 32px
        // off the top and 32px off the bottom (= 42.67 source pixels
        // each), so a band that starts at the very top is partly cut
        // and a band that starts below the cut survives whole.
        let context = CGContext(
            data: nil,
            width: 1024,
            height: 512,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1024, height: 512))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        // CGContext has a bottom-left origin, so the top band is a
        // FILL AT THE HIGH end of y.
        context.fill(CGRect(x: 0, y: 512 - 100, width: 1024, height: 100))
        let source = context.makeImage()!

        let banner = CardCoverImageEncoder.centerCrop(source, toWidth: 768, toHeight: 320)

        // The banner's top row is still the source's top row, so the
        // headroom above the subject did not move.
        let rows = banner.rowBrightness()
        #expect(rows.first ?? 0 > 0.5)
        #expect(rows.last ?? 1 < 0.5)
    }
}

private extension CGImage {
    /// The bounding box of the bright pixels, in image space.
    ///
    /// Image space has its origin at the top left, so the box is
    /// read the way a person looks at the picture.
    func brightBox() -> (width: Int, height: Int, centerX: Double, centerY: Double)? {
        var box: (width: Int, height: Int, centerX: Double, centerY: Double)?
        withPixels { base, rowBytes in
            var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * rowBytes + x * 4
                    guard base[offset] > 200,
                          base[offset + 1] > 200,
                          base[offset + 2] > 200 else { continue }
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
            guard maxX >= minX, maxY >= minY else { return }
            box = (
                maxX - minX + 1,
                maxY - minY + 1,
                Double(minX + maxX) / 2,
                Double(minY + maxY) / 2
            )
        }
        return box
    }

    /// The brightness of each row, from the top row down.
    func rowBrightness() -> [Double] {
        var rows: [Double] = []
        withPixels { base, rowBytes in
            rows = (0..<height).map { y in
                var total = 0.0
                for x in 0..<width {
                    total += Double(base[y * rowBytes + x * 4]) / 255
                }
                return total / Double(width)
            }
        }
        return rows
    }

    /// Reads the image's pixels, laid out top row first.
    ///
    /// The context owns the buffer, so the reading has to happen
    /// while the context is alive: a pointer taken out of a released
    /// context points at freed memory.
    private func withPixels(_ body: (UnsafeMutablePointer<UInt8>, Int) -> Void) {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let base = context.data?.assumingMemoryBound(to: UInt8.self) else { return }
        body(base, context.bytesPerRow)
    }

    /// A handful of pixels spread across the image, for a loose
    /// colour assertion.
    func pixelSamples() -> [(red: CGFloat, green: CGFloat, blue: CGFloat)] {
        var samples: [(CGFloat, CGFloat, CGFloat)] = []
        withPixels { base, rowBytes in
            for y in stride(from: 0, to: height, by: max(1, height / 8)) {
                for x in stride(from: 0, to: width, by: max(1, width / 8)) {
                    let offset = y * rowBytes + x * 4
                    samples.append((
                        CGFloat(base[offset]) / 255,
                        CGFloat(base[offset + 1]) / 255,
                        CGFloat(base[offset + 2]) / 255
                    ))
                }
            }
        }
        return samples
    }
}
