//
//  VisionTools.swift · Wenshu · v0.18 ticket 10 (hermes replica)
//
//  本地 vision 工具 (复刻 hermes vision_analyze 真值).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现" + "不符合文枢定位的可以复刻".
//
//  wenshu 定位 = SwiftUI 桌面写作 app. VisionTools 写作用 (图片分析 / 文字识别 / 图像特征).
//  Apple HIG 真值: Vision framework (VNRecognizeTextRequest / VNGenerateImageFeaturePrintRequest / VNClassifyImageRequest).
//

import Foundation
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(AppKit)
import AppKit
#endif

/// 文字识别结果真值 (hermes vision_analyze text 字段)
public struct VisionTextResult: Equatable, Sendable {
    public let text: String
    public let confidence: Float
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// 图像分类结果真值 (hermes vision_analyze classifications 字段)
public struct VisionClassification: Equatable, Sendable {
    public let identifier: String
    public let confidence: Float

    public init(identifier: String, confidence: Float) {
        self.identifier = identifier
        self.confidence = confidence
    }
}

/// VisionTools: 本地 vision 工具 (Vision framework 真值)
public struct VisionTools: Sendable {
    public init() {}

    /// recognizeText: 图像文字识别真值 (VNRecognizeTextRequest)
    public func recognizeText(imagePath: String) async throws -> [VisionTextResult] {
        #if canImport(Vision) && canImport(AppKit)
        guard let image = NSImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionToolsError.imageLoadFailed(path: imagePath)
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let results = observations.compactMap { obs -> VisionTextResult? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return VisionTextResult(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: obs.boundingBox
                    )
                }
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
        #else
        throw VisionToolsError.platformNotSupported
        #endif
    }

    /// classify: 图像分类真值 (VNClassifyImageRequest)
    public func classify(imagePath: String, limit: Int = 5) async throws -> [VisionClassification] {
        #if canImport(Vision) && canImport(AppKit)
        guard let image = NSImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionToolsError.imageLoadFailed(path: imagePath)
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let results = observations.prefix(limit).map {
                    VisionClassification(identifier: $0.identifier, confidence: $0.confidence)
                }
                continuation.resume(returning: Array(results))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
        #else
        throw VisionToolsError.platformNotSupported
        #endif
    }
}

public enum VisionToolsError: Error {
    case imageLoadFailed(path: String)
    case platformNotSupported
}