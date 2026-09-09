//
// JSONCanvasCodec.swift · Wenshu · v0.19 ticket 13 (Obsidian replica, do first)
// 2026-08-19 evening Obsidian A + ', '.
//
// JSON Canvas fileformat 1:1 (https://jsoncanvas.org/spec/1.0, open MIT).
// Apple HIG: Codable .canvas file (nodes[] + edges[]).
// Obsidian / SilverBullet / .
//

import Foundation

// MARK: - Node

/// JSON Canvas node (1:1 spec https://jsoncanvas.org/spec/1.0 §nodes)
/// - id: unique identifier
/// - type: text / file / link (spec §node-types)
/// - x / y / width / height: +
/// - text: type=text
/// - file: type=file (vault path)
/// - url: type=link
/// - label:, show
/// - color: (1-6 / hex)
public struct CanvasNode: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var type: NodeType
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var text: String?
    public var file: String?
    public var url: String?
    public var label: String?
    public var color: String?

    public enum NodeType: String, Codable, Sendable {
        case text
        case file
        case link
    }

    public init(id: String, type: NodeType, x: Double, y: Double, width: Double, height: Double, text: String? = nil, file: String? = nil, url: String? = nil, label: String? = nil, color: String? = nil) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
        self.file = file
        self.url = url
        self.label = label
        self.color = color
    }
}

// MARK: - Edge

/// JSON Canvas edge (1:1 spec §edges)
/// - id: unique
/// - fromNode / toNode: node id
/// - fromSide / toSide: top / right / bottom / left / none ()
/// - fromEnd / toEnd: none / arrow ()
/// - label:
/// - color:
public struct CanvasEdge: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var fromNode: String
    public var toNode: String
    public var fromSide: Side?
    public var toSide: Side?
    public var fromEnd: End?
    public var toEnd: End?
    public var label: String?
    public var color: String?

    public enum Side: String, Codable, Sendable {
        case top, right, bottom, left, none
    }

    public enum End: String, Codable, Sendable {
        case none, arrow
    }

    public init(id: String, fromNode: String, toNode: String, fromSide: Side? = nil, toSide: Side? = nil, fromEnd: End? = nil, toEnd: End? = nil, label: String? = nil, color: String? = nil) {
        self.id = id
        self.fromNode = fromNode
        self.toNode = toNode
        self.fromSide = fromSide
        self.toSide = toSide
        self.fromEnd = fromEnd
        self.toEnd = toEnd
        self.label = label
        self.color = color
    }
}

// MARK: - Document

/// JSON Canvas document (spec §document)
public struct CanvasDocument: Codable, Equatable, Sendable {
    public var nodes: [CanvasNode]
    public var edges: [CanvasEdge]

    public init(nodes: [CanvasNode] = [], edges: [CanvasEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
}

// MARK: - Codec

/// JSONCanvasCodec: 1:1 decode JSON Canvas file (.canvas)
/// Apple HIG: Foundation JSONEncoder/JSONDecoder, snake_case spec
public enum JSONCanvasCodec {
    public enum CodecError: Error, Equatable {
        case encodingFailed(String)
        case decodingFailed(String)
    }

    /// encoding CanvasDocument → Data (.canvas file)
    public static func encode(_ document: CanvasDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]  // Obsidian output
        do {
            return try encoder.encode(document)
        } catch {
            throw CodecError.encodingFailed("\(error)")
        }
    }

    /// decode Data → CanvasDocument
    public static func decode(_ data: Data) throws -> CanvasDocument {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CanvasDocument.self, from: data)
        } catch {
            throw CodecError.decodingFailed("\(error)")
        }
    }

    /// Decoding from String
    public static func decode(_ string: String) throws -> CanvasDocument {
        guard let data = string.data(using: .utf8) else {
            throw CodecError.decodingFailed("not utf8")
        }
        return try decode(data)
    }

    /// Encoding to String
    public static func encodeToString(_ document: CanvasDocument) throws -> String {
        let data = try encode(document)
        guard let s = String(data: data, encoding: .utf8) else {
            throw CodecError.encodingFailed("not utf8")
        }
        return s
    }
}
