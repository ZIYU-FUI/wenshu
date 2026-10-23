//
//  Features/Cover/Model/CoverImageCache.swift
//
//   : CoverImageCache.
//  The decoded cover pictures the app already holds.
//
//  A lazy grid destroys a card's view when the card scrolls out of
//  sight and builds a new one when it scrolls back. The new view
//  starts with no picture, so without a cache every card that scrolls
//  back reads its file from the disk and decodes it again. The file
//  is small, but the decode is not, and a grid of dozens of cards
//  scrolling is exactly when the app must not do work it has already
//  done.
//
//  The cache is keyed by the file's path AND its size and date, so a
//  regenerated cover (= a new picture at the same path) is decoded
//  again instead of showing the picture it replaced.
//

import AppKit
import Foundation

/// The decoded cover pictures the app already holds.
///
/// `NSCache` is thread-safe, and the cache holds nothing but pictures,
/// so the unchecked conformance is the honest one.
final class CoverImageCache: @unchecked Sendable {

    /// The one cache the app reads cover pictures through.
    static let shared = CoverImageCache()

    private let cache = NSCache<NSString, NSImage>()

    /// The decoded picture for a file, or nil when it is not held.
    func image(for url: URL) -> NSImage? {
        cache.object(forKey: key(for: url) as NSString)
    }

    /// Holds a decoded picture.
    func store(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: key(for: url) as NSString)
    }

    /// Drops the picture held for a file.
    func evict(for url: URL) {
        cache.removeObject(forKey: key(for: url) as NSString)
    }

    /// The cache key for a file.
    ///
    /// The size and the date are part of it, so a file that was
    /// written again is a different picture even though the path is
    /// the same.
    private func key(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(url.path)|\(values?.fileSize ?? 0)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)"
    }
}
