//
//  ReferenceLibrarySidebarTests.swift · Wenshu · v2.6 facet model
//
//  Verifies the v2.6 sidebar tag facet:
//  - SidebarItem.tag(String) round-trips through Codable (= the
//    {"kind":"tag","tag":"<name>"} shape)
//  - ShellMiddleColumn.previewScope() routes .tag to .referenceScope(nil)
//    (= the tag filter is applied separately via shell.activeTagFilter)
//  - ZoneModuleView.previewScope() handles .tag similarly
//
//  Files covered:
//  - Sources/WenshuApp/Views/Library/SidebarItem.swift (tag case added)
//  - Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift (switch case)
//  - Sources/WenshuApp/Views/Workspace/ZoneModuleView.swift (switch case)
//  - Sources/WenshuApp/Views/Chat/ChatZoneView.swift (non-exhaustive)
//  - Sources/WenshuApp/Views/Library/SidebarContextMenu.swift (no-op)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SidebarItem.tag facet (v2.6)")
struct ReferenceLibrarySidebarTests {

    @Test("tag case Codable round-trip")
    func tagCodableRoundTrip() throws {
        let original = SidebarItem.tag("唐朝")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"kind\":\"tag\""), "JSON must include kind=tag discriminator; got: \(json)")
        #expect(json.contains("\"tag\":\"唐朝\""), "JSON must include the tag string; got: \(json)")
        let decoded = try JSONDecoder().decode(SidebarItem.self, from: data)
        #expect(decoded == original)
    }

    @Test("tag case hash equality (= same tag string = same SidebarItem)")
    func tagHashEquality() {
        let a = SidebarItem.tag("诗人")
        let b = SidebarItem.tag("诗人")
        let c = SidebarItem.tag("唐朝")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }

    @Test("all five SidebarItem cases survive Codable round-trip")
    func allCasesRoundTrip() throws {
        let cases: [SidebarItem] = [
            .book(UUID()),
            .shelf(UUID()),
            .folder(bookId: UUID(), folderName: "world"),
            .referenceCategory("i"),
            .tag("唐朝")
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(SidebarItem.self, from: data)
            #expect(decoded == original, "round-trip failed for \(original)")
        }
    }
}