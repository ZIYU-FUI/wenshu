//
//  SidebarService+ReferenceLibrary.swift
//
//  The reference library's own classification: how a reference buckets
//  into a category, how the two-level tag tree is built, and the stable
//  ids the tree's rows carry.
//
//  Why: the classification is a cluster of static functions and
//  constants over the reference model, and it reads none of the
//  service's instance state, so it is its own file and the service's
//  own file was over the file-size cap.
//
import Foundation

extension SidebarService {
    // MARK: - reference library auto-classification

    // (= (see OOB.md #2026-09-22) OOB ''). Group references into CLC top-level categories
    // for the sidebar tree (= project the 22-bucket CLC taxonomy onto the
    // reference library's display). Bucket key = the EntityCategory.directoryName
    // (= "a" / "b" / ... / "" for official categories; "" for legacy references
    // whose category is nil).

    // MARK: - The two-level tag tree

    /// Build the reference library's rows: one row per library category
    /// that has at least one tag, and under each, the tags that belong to
    /// it.
    ///
    /// The entity documents are NOT drawn (= only the categories and the
    /// tags are; = the tree stays a browse surface).
    ///
    /// A tag belongs to exactly one category. Where the references that
    /// carry a tag disagree about the category, the category more of them
    /// give wins; a tie goes to the category that comes first in the
    /// library's own category order. The catch-all category comes last.
    static func groupedTagRows(for references: [Reference]) -> [SidebarNode] {
        // The tag's count = how many references carry it.
        var tagCounts: [String: Int] = [:]
        // How many references put each tag under each category.
        var votes: [String: [String: Int]] = [:]
        for reference in references {
            let bucket = bucketKey(for: reference)
            for tag in reference.tags {
                tagCounts[tag, default: 0] += 1
                votes[tag, default: [:]][bucket, default: 0] += 1
            }
        }
        guard !tagCounts.isEmpty else { return [] }

        // The tag's category = the one the most references give; a tie
        // goes to the category that comes first in the library's own
        // order. The catch-all counts as the last one.
        var tagBucket: [String: String] = [:]
        for (tag, byBucket) in votes {
            let winner = byBucket.max { lhs, rhs in
                let lhsCount = lhs.value
                let rhsCount = rhs.value
                if lhsCount != rhsCount {
                    return lhsCount < rhsCount
                }
                return bucketOrder(lhs.key) > bucketOrder(rhs.key)
            }?.key
            if let winner {
                tagBucket[tag] = winner
            }
        }

        // The tags of each bucket, in the order the flat list used: the
        // most carried tag first, then the tag string.
        var tagsByBucket: [String: [String]] = [:]
        for tag in tagBucket.keys.sorted() {
            guard let bucket = tagBucket[tag] else { continue }
            tagsByBucket[bucket, default: []].append(tag)
        }
        for bucket in tagsByBucket.keys {
            tagsByBucket[bucket]?.sort { lhs, rhs in
                let lhsCount = tagCounts[lhs] ?? 0
                let rhsCount = tagCounts[rhs] ?? 0
                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }
                return lhs < rhs
            }
        }

        // The categories in the library's own order, the catch-all last.
        // The sort key comes from the existing helper (= the library's own
        // category order; = the catch-all's key sorts after every letter).
        let buckets = tagsByBucket.keys.sorted { categorySortKey($0) < categorySortKey($1) }
        return buckets.compactMap { bucket -> SidebarNode? in
            guard let tags = tagsByBucket[bucket], !tags.isEmpty else { return nil }
            let tagNodes = tags.map { tag in
                SidebarNode(
                    id: stableReferenceTagId(tag),
                    kind: .tag,
                    title: tag,
                    subtitle: String(
                        localized: "assets.count.label",
                        defaultValue: "\(tagCounts[tag] ?? 0) items"
                    ),
                    systemImage: "tag",
                    children: nil,
                    routingKey: tag
                )
            }
            if let category = EntityCategoryFromDirectoryName(bucket) {
                return SidebarNode(
                    id: stableReferenceCategoryId(bucket),
                    kind: .referenceCategory,
                    title: category.displayName,
                    subtitle: nil,
                    systemImage: category.icon,
                    children: tagNodes,
                    routingKey: bucket
                )
            }
            // The catch-all row (= the references no category claims). It
            // has no category behind it, so it carries its own routing
            // key instead of a directory name.
            return SidebarNode(
                id: stableReferenceCategoryId(bucket),
                kind: .referenceCategory,
                title: String(localized: "sidebar.reference_library.unclassified.title"),
                subtitle: nil,
                systemImage: "tray.full",
                children: tagNodes,
                routingKey: Self.unclassifiedRoutingKey
            )
        }
    }

    /// The routing key of the catch-all category row.
    ///
    /// The catch-all row has no category behind it, so the category route
    /// (= a directory name that resolves back to a category) cannot carry
    /// it. Its own key keeps the preview pane from resolving it to a
    /// category it does not have.
    static let unclassifiedRoutingKey = "__unclassified__"

    /// The bucket a reference belongs to.
    ///
    /// A reference that carries a category uses it. A reference that
    /// carries none falls back to the classifier's keyword pass, so its
    /// tags land under a real category rather than under the catch-all.
    /// A reference the keyword pass cannot place either lands under the
    /// catch-all, so it stays browsable.
    private static func bucketKey(for reference: Reference) -> String {
        if let category = reference.category {
            return category.directoryName
        }
        let keyword = EntityClassifier().keywordClassify(
            title: reference.title,
            summary: reference.summary,
            body: ""
        )
        if keyword.confidence > 0 {
            return keyword.category.directoryName
        }
        // The reference no category claims. The existing helper maps it to
        // the same catch-all key this card uses.
        return referenceCategoryKey(for: reference)
    }

    /// The catch-all bucket's key (= the references no category claims).
    ///
    /// The key is a CJK literal in the source; = the row's TITLE comes
    /// from the catalog instead (= the key is the routing key, not
    /// something the user reads).
    private static let unclassifiedBucketKey = "\u{672A}\u{5206}\u{7C7B}"

    /// The order a bucket's rows appear in (= the library's own category
    /// order, the catch-all last).
    private static func bucketOrder(_ key: String) -> Int {
        if key == unclassifiedBucketKey {
            return Int.max
        }
        guard let category = EntityCategoryFromDirectoryName(key) else { return Int.max - 1 }
        return categoryOrderIndex(category)
    }

    /// The position of a category in the library's own category order.
    private static func categoryOrderIndex(_ category: EntityCategory) -> Int {
        EntityCategory.allCases.firstIndex(of: category) ?? Int.max - 1
    }

    /// Map a Reference to its sidebar-bucket key.
    /// references always have a category (= assigned by
    /// EntityClassifier on save). Legacy imports have nil
    /// (= still seen in the wild on existing user libraries);
    /// those bucket under a synthetic '' label so they
    /// stay browsable rather than disappearing.
    private static func referenceCategoryKey(for ref: Reference) -> String {
        if let category = ref.category {
            return category.directoryName
        }
        return "未分类"
    }

    /// Sort the sidebar buckets in CLC canonical order (= A, B,
    /// C, ..., Z), with the synthetic '' bucket pushed to
    /// the end (= the official categories are the primary
    /// structure; the unclassified bucket is the cleanup-pending
    /// tail). Returns a sort key that Dictionary.sorted(by:)
    /// can compare directly.
    private static func categorySortKey(_ key: String) -> String {
        if key == "未分类" {
            return "~"
        } // '~' = ASCII 0x7E = sorts after letters (= A-Z = 0x41-0x5A)
        return key
    }

    /// Map a directoryName back to the EntityCategory. Returns
    /// nil for the synthetic '' bucket (= no
    /// EntityCategory corresponds) and for any unrecognized
    /// key (= forward-compatible with future CLC categories
    /// = the existing 22 cases cover CLC 5th edition
    /// simplified; future expansion would add new enum cases).
    private static func EntityCategoryFromDirectoryName(_ name: String) -> EntityCategory? {
        // EntityCategory.directoryName returns the lowercase rawValue for the official 22
        // cases (= .a → "a", .i → "i", etc.) and "" for .z.
        // EntityCategory(rawValue:) is case-sensitive — so we case-fold the
        // input for the lookup. The official raw values are uppercase letters,
        // so uppercase folding restores the canonical form before lookup.
        let upper = name.uppercased()
        return EntityCategory(rawValue: upper)
    }

    /// Stable UUID for a sidebar category row (= same key →
    /// same UUID across launches; = selection state survives
    /// reload). Distinct from stableFolderId because category
    /// rows live under a different parent (= the synthetic
    /// Reference-Library root) and the ID namespace is
    /// separate (= "wenshu.sidebar.refcat." vs
    /// "wenshu.sidebar.folder.").
    private static func stableReferenceCategoryId(_ key: String) -> UUID {
        let raw = "wenshu.sidebar.refcat.\(key)"
        var hasher = Hasher()
        hasher.combine(raw)
        let hash = hasher.finalize()
        let bytes = withUnsafeBytes(of: hash.bigEndian) { Array($0) }
        var uuidBytes = Array(bytes)
        while uuidBytes.count < 16 {
            uuidBytes.append(0)
        }
        uuidBytes = Array(uuidBytes.prefix(16))
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        let u = uuidBytes.map { String(format: "%02x", $0) }.joined()
        let formatted = "\(u.prefix(8))-\(u.dropFirst(8).prefix(4))-\(u.dropFirst(12).prefix(4))-\(u.dropFirst(16).prefix(4))-\(u.dropFirst(20).prefix(12))"
        return UUID(uuidString: formatted) ?? UUID()
    }

    /// Stable UUID for a sidebar tag row.
    /// Same tag string yields the same UUID across launches,
    /// so the persisted sidebarSelection survives reload.
    /// Distinct ID namespace from stableReferenceCategoryId
    /// (= "wenshu.sidebar.reftag." vs "wenshu.sidebar.refcat.")
    /// so the tag rows never collide with the legacy
    /// rows in any persisted selection.
    private static func stableReferenceTagId(_ tag: String) -> UUID {
        let raw = "wenshu.sidebar.reftag.\(tag)"
        var hasher = Hasher()
        hasher.combine(raw)
        let hash = hasher.finalize()
        let bytes = withUnsafeBytes(of: hash.bigEndian) { Array($0) }
        var uuidBytes = Array(bytes)
        while uuidBytes.count < 16 {
            uuidBytes.append(0)
        }
        uuidBytes = Array(uuidBytes.prefix(16))
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        let u = uuidBytes.map { String(format: "%02x", $0) }.joined()
        let formatted = "\(u.prefix(8))-\(u.dropFirst(8).prefix(4))-\(u.dropFirst(12).prefix(4))-\(u.dropFirst(16).prefix(4))-\(u.dropFirst(20).prefix(12))"
        return UUID(uuidString: formatted) ?? UUID()
    }
}
