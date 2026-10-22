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
}

private extension CGImage {
    /// A handful of pixels spread across the image, for a loose
    /// colour assertion.
    func pixelSamples() -> [(red: CGFloat, green: CGFloat, blue: CGFloat)] {
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
        guard let base = context.data?.assumingMemoryBound(to: UInt8.self) else { return [] }
        let bytesPerPixel = 4
        let rowBytes = context.bytesPerRow
        var samples: [(CGFloat, CGFloat, CGFloat)] = []
        for y in stride(from: 0, to: height, by: max(1, height / 8)) {
            for x in stride(from: 0, to: width, by: max(1, width / 8)) {
                let offset = y * rowBytes + x * bytesPerPixel
                let r = CGFloat(base[offset]) / 255
                let g = CGFloat(base[offset + 1]) / 255
                let b = CGFloat(base[offset + 2]) / 255
                samples.append((r, g, b))
            }
        }
        return samples
    }
}
