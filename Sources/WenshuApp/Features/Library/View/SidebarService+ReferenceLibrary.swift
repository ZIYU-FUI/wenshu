//
//  SidebarService+ReferenceLibrary.swift
//
//  The reference library's browse surface: the tag rows the tree draws
//  under the library root, and the stable ids those rows carry.
//
//  Why: the projection is a cluster of static functions over the
//  reference model, and it reads none of the service's instance
//  state, so it is its own file and the service's own file was over
//  the file-size cap.
//

import Foundation

extension SidebarService {
    // MARK: - The tag rows

    /// Build the reference library's rows: one row per tag.
    ///
    /// The surface is ONE level (= the tag cloud): = the library root's
    /// children are the tags, = and every tag is a leaf (= no row under
    /// it, = so a click on it scopes the grid to that tag).
    ///
    /// ⇒ ⇒ ⇒ The library's own categories (= the 22 CLC buckets) are
    /// NOT a second level: = a category row was a grouping the tree
    /// rebuilt from the classifier's answer on every reload (= so the
    /// rows moved when the selection changed), = and the tag cloud is
    /// the surface the user asked for.
    ///
    /// The count = how many documents carry the tag, = counted over the
    /// entities layer only (= the layer the material zone's grid shows:
    /// = a count the user can check against what he sees is the only
    /// count worth showing).
    ///
    /// The order = the most carried tag first, = then the tag string
    /// (= a stable order, = so the rows do not move between launches).
    static func tagRows(for references: [Reference]) -> [SidebarNode] {
        var counts: [String: Int] = [:]
        for reference in references where reference.layer == .layerEntities {
            for tag in reference.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
            .map { tag, count in
                SidebarNode(
                    id: stableReferenceTagId(tag),
                    kind: .tag,
                    title: tag,
                    subtitle: String(
                        localized: "assets.count.label",
                        defaultValue: "\(count) items"
                    ),
                    systemImage: "tag",
                    children: nil,
                    routingKey: tag
                )
            }
    }

    /// Stable UUID for a sidebar tag row.
    ///
    /// The same tag string yields the same row identity while the app
    /// runs (= the tree is rebuilt on every reload, = and the row must
    /// keep its identity across that rebuild). = The persisted selection
    /// names the tag string itself (= `SidebarItem.tag`), = so the
    /// selection survives a relaunch whatever the id is.
    ///
    /// Its own namespace (= "wenshu.sidebar.reftag.") keeps the tag rows
    /// apart from the folder rows in any persisted value.
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
