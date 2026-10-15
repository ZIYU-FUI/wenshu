//
//  Persistence/WSOutlineEntry.swift
//
//  SwiftData @Model for the v2.3 outline-entry schema. One row
//  per OutlineEntry (= high-level story structure = volume /
//  chapter / scene / beat).
//
//  Per boss 2026-10-05 OOB ' 8' (= complete the FileSystem*Store →
//  SwiftData migration). This is commit 4 of #8.
//
//  Apple HIG canonical pattern: OutlineEntry metadata (= id,
//  bookID, title, summary, parent, order, createdAt, updatedAt)
//  lives as typed SwiftData columns. The body markdown stays on
//  the filesystem at <bookDir>/outlines/<uuid>.md (= too large for
//  a relational row; = the filesystem is the canonical source
//  for body content, matching the WSOutlineDocument pattern).

import Foundation
import SwiftData

@Model
public final class WSOutlineEntry {
    @Attribute(.unique) public var id: UUID
    public var bookID: UUID
    public var title: String
    public var summary: String
    /// FK to parent WSOutlineEntry (= nil for high-volume).
    public var parent: UUID?
    public var order_: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        bookID: UUID,
        title: String,
        summary: String = "",
        parent: UUID? = nil,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookID = bookID
        self.title = title
        self.summary = summary
        self.parent = parent
        self.order_ = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}