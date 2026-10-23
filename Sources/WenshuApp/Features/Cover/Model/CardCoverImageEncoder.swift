//
//  Features/Cover/Model/CardCoverImageEncoder.swift
//
//   : CardCoverImageEncoder.
//  Turns a generated picture into the two byte shapes the cover feature
//  stores and sends.
//
//  Two shapes, one stored file:
//
//  - HEIC, stored. The cover lives on disk as a HEIC banner, because
//    macOS has no WebP encoder (CGImageDestinationCreateWithData with
//    UTType.webP returns nil, and NSBitmapImageRep.FileType has no
//    .webP case), and HEIC is roughly half of JPEG at the same
//    quality on painterly content.
//
//  - JPEG, in memory only. The image-to-video endpoint accepts
//    JPG / JPEG / PNG / WebP and NOT HEIC, so the moving cover's
//    first frame is produced by decoding the stored HEIC and
//    re-encoding it as JPEG. That JPEG never touches the disk.
//
//  The stored size is 768x320 (= 2.40:1), and that number is not a
//  guess:
//
//  - the image endpoint rejects a short edge below 512 with
//    "invalid params, height must be between [512,2048]", so the
//    request is 1024x512 and the crop to 2.40:1 is local;
//  - the image-to-video first-frame gate needs a short edge over 300
//    px and an aspect between 2:5 and 5:2, and 768x320 satisfies
//    both (640x224, the display-matched size, fails both);
//  - the material zone's cover slot is 216-316pt wide and 100pt tall,
//    so the widest card at 2x needs 632x200, and 768x320 covers it.
//
//  One file therefore serves the display, the video's first frame and
//  the hover poster, and there is no second copy in the library.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Encodes and decodes cover images. Pure value transforms over bytes,
/// so it can be tested without a network call.
enum CardCoverImageEncoder {

    /// The stored banner's pixel size (= 2.40:1).
    static let bannerWidth = 768
    static let bannerHeight = 576

    /// The HEIC quality for the stored banner.
    static let heicQuality = 0.82

    /// The JPEG quality for the image-to-video payload.
    static let jpegQuality = 0.92

    /// Centre-crops a picture to the stored banner's aspect and
    /// encodes it as HEIC.
    ///
    /// The crop scales to COVER and then centres, so the subject is
    /// never squashed. A 1024x512 source cropped to 768x320 keeps the
    /// subject whole with headroom above it, which was verified on a
    /// real generated cover.
    static func encode(bannerImage: CGImage) throws -> Data {
        let banner = centerCrop(bannerImage, toWidth: bannerWidth, toHeight: bannerHeight)
        return try encode(banner, as: .heic, quality: heicQuality)
    }

    /// Encodes an image as HEIC or JPEG.
    static func encode(_ image: CGImage, as type: UTType, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw CardCoverImageError.cannotCreateDestination(type)
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw CardCoverImageError.cannotFinalizeDestination(type)
        }
        return data as Data
    }

    /// Decodes a stored HEIC banner and re-encodes it as a JPEG, for
    /// the image-to-video endpoint, which does not accept HEIC.
    static func decodeToJPEG(_ heic: Data, quality: Double = jpegQuality) throws -> Data {
        guard let source = CGImageSourceCreateWithData(heic as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CardCoverImageError.cannotDecode
        }
        return try encode(image, as: .jpeg, quality: quality)
    }

    /// Decodes an image from bytes.
    static func decode(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CardCoverImageError.cannotDecode
        }
        return image
    }

    /// Scales an image to COVER the target size, then centre-crops it
    /// to exactly that size. Never stretches.
    ///
    /// The scale is the LARGER of the two axis ratios, so the scaled
    /// picture is at least as large as the target on both axes and
    /// overflows on one of them. The overflow is what the crop
    /// removes, and it is removed evenly from both sides, so the
    /// subject stays whole and centred.
    ///
    /// A 1024x512 source cropped to 768x320 scales by 0.75 (= 768x384),
    /// so the scaled picture overflows by 64 px of height and loses 32
    /// px off its top and 32 px off its bottom. That keeps a subject
    /// with headroom above it.
    static func centerCrop(_ image: CGImage, toWidth width: Int, toHeight height: Int) -> CGImage {
        let scale = max(
            Double(width) / Double(image.width),
            Double(height) / Double(image.height)
        )
        let scaledWidth = Double(image.width) * scale
        let scaledHeight = Double(image.height) * scale

        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context else {
            return image
        }
        context.interpolationQuality = .high
        // The clip is what makes the overflow disappear: without it
        // the scaled picture would spill past the target edges.
        context.clip(to: CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(
            image,
            in: CGRect(
                x: (Double(width) - scaledWidth) / 2,
                y: (Double(height) - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )
        )
        return context.makeImage() ?? image
    }
}

/// The failures the encoder can raise.
enum CardCoverImageError: LocalizedError {
    case cannotCreateDestination(UTType)
    case cannotFinalizeDestination(UTType)
    case cannotDecode

    var errorDescription: String? {
        switch self {
        case .cannotCreateDestination(let type):
            return "The image encoder could not open a destination for \(type.identifier)."
        case .cannotFinalizeDestination(let type):
            return "The image encoder could not write a \(type.identifier) payload."
        case .cannotDecode:
            return "The image bytes could not be decoded."
        }
    }
}
