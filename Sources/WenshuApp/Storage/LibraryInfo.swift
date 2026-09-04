// LibraryInfo.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Reads the .ws library's Info.plist metadata (= Apple HIG bundle
// pattern). Per spec v5 ticket 018:
// - Bundle.url(<.ws>/Info.plist) reads CFBundlePackageType (= "WSPC")
//   + WSSchemaVersion (= custom key for v0.26 schema versioning)
// - Compares schemaVersion against CURRENT_SCHEMA_VERSION
// - Returns LibraryInfoError.missingInfoPlist if bundle is nil
//   (= user dragged a folder without Info.plist; LibraryBootstrapper
//   will recreate it on next launch)
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 018.

import Foundation

/// Canonical schema version for v0.26 (= must match the WSSchemaVersion
/// key written by LibraryRootView.swift when creating a new .ws).
/// Bump on breaking changes to the .ws directory structure (= spec v5
/// ticket 022 LibraryMigrator triggers when WSSchemaVersion < this).
let CURRENT_SCHEMA_VERSION = 1

/// Library metadata read from the .ws directory's Info.plist.
struct LibraryInfo: Sendable {
    /// Schema version (= from WSSchemaVersion key in Info.plist).
    let schemaVersion: Int
    /// Optional creation timestamp (= from WSPCreatedAt key in
    /// Info.plist, ISO 8601 string).
    let createdAt: Date?

    /// True iff this .ws matches the current wenshu schema.
    var isCurrentSchema: Bool {
        schemaVersion == CURRENT_SCHEMA_VERSION
    }

    /// True iff this .ws is from an older wenshu version (= needs
    /// LibraryMigrator).
    var needsMigration: Bool {
        schemaVersion < CURRENT_SCHEMA_VERSION
    }
}

enum LibraryInfoError: Error, LocalizedError {
    case missingInfoPlist(path: String)
    case malformedInfoPlist(path: String, reason: String)
    case missingSchemaVersionKey(path: String)

    var errorDescription: String? {
        switch self {
        case .missingInfoPlist(let path):
            return "Info.plist not found at \(path). Re-select the .ws directory or run LibraryBootstrapper to recreate it."
        case .malformedInfoPlist(let path, let reason):
            return "Info.plist at \(path) is malformed: \(reason)."
        case .missingSchemaVersionKey(let path):
            return "WSSchemaVersion key missing in Info.plist at \(path). This .ws may be from a corrupted state; re-run LibraryBootstrapper."
        }
    }
}

/// Reads LibraryInfo from a .ws directory's Info.plist.
struct LibraryInfoReader {
    /// Read the library info from the given .ws root URL.
    static func read(from wsRoot: URL) throws -> LibraryInfo {
        let infoPlistURL = wsRoot.appendingPathComponent("Info.plist")
        guard let bundle = Bundle(url: infoPlistURL) else {
            throw LibraryInfoError.missingInfoPlist(path: infoPlistURL.path)
        }
        guard let infoDict = bundle.infoDictionary else {
            throw LibraryInfoError.malformedInfoPlist(
                path: infoPlistURL.path,
                reason: "infoDictionary is nil"
            )
        }
        guard let schemaVersion = infoDict["WSSchemaVersion"] as? Int else {
            throw LibraryInfoError.missingSchemaVersionKey(path: infoPlistURL.path)
        }
        let createdAt: Date?
        if let createdAtString = infoDict["WSPCreatedAt"] as? String {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: createdAtString)
        } else {
            createdAt = nil
        }
        return LibraryInfo(
            schemaVersion: schemaVersion,
            createdAt: createdAt
        )
    }
}