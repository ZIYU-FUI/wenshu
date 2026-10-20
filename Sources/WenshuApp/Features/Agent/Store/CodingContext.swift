//
//  CodingContext.swift
//
//  1:1 port of hermes coding_context.py (= hermes-internal module #2,
// ). Thin adapter — wenshu already has
//  PromptCaching.swift as the canonical coding-context surface, so
//  this module exposes a hermes-aligned API that delegates to it.
//
//  Wenshu-side wins preserved: this is the thin-adapter pattern
//  (= hermes-port = adapter, wenshu-canonical = canonical). CodingContextAggregator
//  reads Swift files from disk and surfaces language + imports + recent edits
//  for downstream prompt assembly.
//

import Foundation

// MARK: - Errors

enum CodingContextError: Error, Sendable, Equatable {
    case fileNotFound(path: String)
    case unsupportedExtension(path: String)
}

extension CodingContextError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Coding context file not found: \(path)"
        case .unsupportedExtension(let path):
            return "Unsupported file extension: \(path)"
        }
    }
}
