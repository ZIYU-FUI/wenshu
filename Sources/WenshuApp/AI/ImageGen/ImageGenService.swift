// ImageGenService.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB '我在让卡片缩略图, 有内容可以显示':
// Image generation orchestrator (= port of Card-master
// `src/ai/infrastructure/ai-service-http.ts` retry + cache write logic).
//
// `ImageGenService` is the single entry point for AI thumbnail
// generation. Caller (EntityIngestion or chat assistant) hands it a
// `Reference`; service picks the configured provider, builds the
// prompt from the reference's title + summary + category, retries
// with the fallback provider on failure, and writes the image data
// to `CacheManager.thumbnailsDirectory/<uuid>.webp`. Updates
// `Reference.coverImageStatus` via the `onStatusUpdate` callback
// (= hook for the SwiftUI view to re-render the placeholder -> cover).
//
// Apple-API-first check: `URLSession.data(for:)` (= async/await).
// No third-party HTTP client. File I/O via Foundation `Data.write`
// + `FileManager.replaceItemAt` (= Apple atomic write canonical).

import Foundation

/// Status callback fired during `ImageGenService.generateThumbnail`.
/// Caller (= `EntityIngestion` or a SwiftUI `@Observable` model) updates
/// `Reference.coverImageStatus` so `ReferenceCardView` re-renders.
typealias ImageGenStatusUpdate = @Sendable (_ status: CoverImageStatus) -> Void

/// Configurable provider chain. Boss Q34 recommendation: DashScope
/// primary, OpenAI fallback. Future: add Apple `ImageCreator`
/// (on-device Stable Diffusion, no API key, no network = local-first
/// fallback).
struct ImageGenProviderChain: Sendable {
    let primary: any ImageGenProvider
    let fallback: any ImageGenProvider?

    init(primary: any ImageGenProvider, fallback: any ImageGenProvider? = nil) {
        self.primary = primary
        self.fallback = fallback
    }
}

/// Orchestrates AI thumbnail generation. Caller invokes
/// `generateThumbnail(for: onStatusUpdate:)` (= async, returns when
/// thumbnail is cached AND `Reference.coverImageStatus == .ready` or
/// `.failed`). UI is updated via the callback during the lifecycle.
@MainActor
final class ImageGenService: Sendable {
    private let chain: ImageGenProviderChain
    private let cacheManager: CacheManager
    private let referenceStore: ReferenceStoring

    init(chain: ImageGenProviderChain, cacheManager: CacheManager, referenceStore: ReferenceStoring) {
        self.chain = chain
        self.cacheManager = cacheManager
        self.referenceStore = referenceStore
    }

    /// Generate and cache a thumbnail for the given reference.
    /// Updates `coverImageStatus` via the callback throughout the
    /// lifecycle (.pending -> .generating -> .ready or .failed).
    ///
    /// Idempotent: if the cache file already exists (= previous run
    /// succeeded), returns immediately with .ready (= no duplicate
    /// API calls).
    func generateThumbnail(for reference: Reference, onStatusUpdate: @escaping ImageGenStatusUpdate) async {
        // 1. If already cached, set .ready and return.
        let cacheURL = cacheManager.thumbnailURL(for: reference.id)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            onStatusUpdate(.ready)
            return
        }

        // 2. Mark pending.
        onStatusUpdate(.pending)
        await updateStatus(.pending, for: reference.id)

        // 3. Skip if no provider has an API key.
        guard chain.primary.hasAPIKey || (chain.fallback?.hasAPIKey ?? false) else {
            onStatusUpdate(.failed)
            await updateStatus(.failed, for: reference.id)
            return
        }

        // 4. Build the prompt.
        let prompt = buildPrompt(for: reference)

        // 5. Try primary, fall back on failure.
        onStatusUpdate(.generating)
        await updateStatus(.generating, for: reference.id)
        let request = ImageGenRequest(prompt: prompt)

        var response: ImageGenResponse? = nil
        var lastErr: ImageGenError? = nil
        if chain.primary.hasAPIKey {
            do {
                response = try await chain.primary.generate(request)
            } catch let err as ImageGenError {
                lastErr = err
            } catch {
                lastErr = .networkFailure(provider: chain.primary.id, underlying: error)
            }
        }
        if response == nil, let fallback = chain.fallback, fallback.hasAPIKey {
            do {
                response = try await fallback.generate(request)
            } catch let err as ImageGenError {
                lastErr = err
            } catch {
                lastErr = .networkFailure(provider: fallback.id, underlying: error)
            }
        }

        guard let imageData = response?.imageData else {
            onStatusUpdate(.failed)
            await updateStatus(.failed, for: reference.id)
            _ = lastErr  // (= translated to UserFacingError in Issue 06)
            return
        }

        // 6. Write to cache + mark ready.
        do {
            try cacheManager.writeThumbnail(imageData, for: reference.id)
        } catch {
            onStatusUpdate(.failed)
            await updateStatus(.failed, for: reference.id)
            return
        }
        onStatusUpdate(.ready)
        await updateStatus(.ready, for: reference.id)
    }

    /// Build the prompt sent to the image gen provider. Uses the
    /// reference's title + summary + entity category for context.
    /// Always English (= image gen providers are trained on English
    /// captions; Chinese captions produce lower-quality output per
    /// boss 8/29 'AI 工作语言 = English for technical prompts').
    private func buildPrompt(for reference: Reference) -> String {
        var parts: [String] = []
        parts.append("An illustration representing: \(reference.title)")
        if !reference.summary.isEmpty {
            parts.append("Context: \(reference.summary)")
        }
        if let category = reference.category {
            parts.append("Category: \(category.displayName)")
        }
        parts.append("Style: ink wash painting with subtle digital refinement, ")
        parts.append("suitable for a Chinese-language book cover thumbnail.")
        return parts.joined(separator: ". ")
    }

    /// Update `Reference.coverImageStatus` by re-loading + writing back.
    /// v0.34 uses the existing `loadReferences` + writeIndex pattern;
    /// future optimization: dedicated `updateCoverImageStatus` API
    /// on `ReferenceStoring` (= Issue 04 followup).
    private func updateStatus(_ status: CoverImageStatus, for id: UUID) async {
        guard var all = try? referenceStore.loadAllReferences(),
              let idx = all.firstIndex(where: { $0.id == id }) else { return }
        all[idx].coverImageStatus = status
        all[idx].updatedAt = .now
        // Write back per layer (== the entity's home layer).
        let layer = all[idx].layer
        do {
            var layerRefs = try referenceStore.loadReferences(layer: layer)
            if let li = layerRefs.firstIndex(where: { $0.id == id }) {
                layerRefs[li].coverImageStatus = status
                layerRefs[li].updatedAt = .now
                // Use replaceReference's index write.
                try writeIndex(layerRefs, layer: layer)
            }
        } catch {
            return  // (= best-effort; surface UI shows whatever the last status was)
        }
    }

    /// v0.34 helper: write the layer's references index atomically.
    /// Mirrors FileSystemReferenceStore.writeIndex (= private method).
    /// Future: extract to ReferenceStoring protocol (= Issue 04).
    private func writeIndex(_ refs: [Reference], layer: ReferenceLayer) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(refs)
        let indexURL = ((referenceStore as? FileSystemReferenceStore)?.referenceLibraryRoot)
            .map { $0.appendingPathComponent("\(layer.directoryName).json") }
        guard let url = indexURL else { return }
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: url)
        }
    }
}