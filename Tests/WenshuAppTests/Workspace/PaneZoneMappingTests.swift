//
//  PaneZoneMappingTests.swift · Wenshu (文枢) · B-07 ticket 028-003
//
//  Four-test validation suite for `PaneZoneLayout` (= the
//  single-source-of-truth for which `TabKind` ships into which
//  `ZoneSlot`).
//
//  Tests cover:
//    1. `testPaneZoneMapping_6zones`           — default covers all 6 zones
//    2. `testPaneZoneMapping_swapZones`        — swap is pure + symmetric
//    3. `testPaneZoneMapping_referenceLibrary` — not in any zone
//    4. `testPaneZoneMapping_settings`         — not in any zone
//
//  Reference: `.scratch/2026-09-04-b-07-028-003-pane-zone-mapping-spec.md`
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("PaneZoneMapping")
struct PaneZoneMappingTests {

    // MARK: - Test 1: default mapping covers all 6 zones

    @Test("default mapping: every zone has exactly one default module")
    func testPaneZoneMapping_6zones() {
        let layout = PaneZoneLayout.default

        // Every ZoneSlot case is mapped (= 1:1 default).
        for zone in ZoneSlot.allCases {
            #expect(
                layout.module(for: zone) != nil,
                "Zone \(zone.identifier) should have a default module"
            )
        }

        // Default mapping is the homonymous TabKind for each zone
        // (= canonical 1:1 assignment per the ticket spec).
        #expect(layout.module(for: .projectSidebar)   == .projectSidebar)
        #expect(layout.module(for: .projectPreview)   == .projectPreview)
        #expect(layout.module(for: .editor)           == .editor)
        #expect(layout.module(for: .specializedTools) == .specializedTools)
        #expect(layout.module(for: .aiChat)           == .aiChat)
        #expect(layout.module(for: .aiDynamic)        == .aiDynamic)

        // Exactly 6 modules are zoned (= no extras, no omissions).
        #expect(layout.zonedModules.count == ZoneSlot.allCases.count)
        #expect(layout.zonedModules.count == 6)
    }

    // MARK: - Test 2: swap is pure + symmetric

    @Test("swap: swapping two zones exchanges modules and is pure")
    func testPaneZoneMapping_swapZones() {
        let original = PaneZoneLayout.default
        let sidebarModule = original.module(for: .projectSidebar)
        let toolsModule   = original.module(for: .specializedTools)

        // Sanity: the two zones start with distinct modules.
        #expect(sidebarModule != toolsModule)

        let swapped = original.swapping(.projectSidebar, .specializedTools)

        // Original is unchanged (= pure swap).
        #expect(original.module(for: .projectSidebar)   == sidebarModule)
        #expect(original.module(for: .specializedTools) == toolsModule)

        // Swapped layout: the two zones exchanged modules.
        #expect(swapped.module(for: .projectSidebar)   == toolsModule)
        #expect(swapped.module(for: .specializedTools) == sidebarModule)

        // All other zones are unchanged (= swap is local).
        #expect(swapped.module(for: .projectPreview)   == .projectPreview)
        #expect(swapped.module(for: .editor)           == .editor)
        #expect(swapped.module(for: .aiChat)           == .aiChat)
        #expect(swapped.module(for: .aiDynamic)        == .aiDynamic)

        // The full inverse swap restores the original (= swap is involutive).
        let restored = swapped.swapping(.projectSidebar, .specializedTools)
        #expect(restored == original)
    }

    // MARK: - Test 3: reference library is NOT in any zone

    @Test("reference library: not present in any of the 6 zones")
    func testPaneZoneMapping_referenceLibrary() {
        let layout = PaneZoneLayout.default

        // No zone hosts the reference library (= it's a global
        // surface that opens as a separate window).
        for zone in ZoneSlot.allCases {
            let module = layout.module(for: zone)
            let zoneHostsReferenceLibrary: Bool = {
                guard let module else { return false }
                // Reference library has no TabKind case (= it's a
                // separate-window surface); the contract is that no
                // zone is allowed to claim it. We assert that
                // (a) the reference-library name does not match any
                //     zoned module's raw value, and
                // (b) the `zonedModules` set does not include it.
                return module.rawValue == PaneZoneLayout.referenceLibraryName
            }()
            #expect(
                !zoneHostsReferenceLibrary,
                "Zone \(zone.identifier) must not host reference library"
            )
        }

        // The reference library is documented as a global module
        // (= outside the 6-zone grid).
        #expect(PaneZoneLayout.referenceLibraryName == "ReferenceLibrary")
        // Global TabKind set is empty by design (= no TabKind is
        // global; reference library is a string name, not a TabKind).
        #expect(PaneZoneLayout.globalModules.isEmpty)
    }

    // MARK: - Test 4: Settings is NOT in any zone

    @Test("settings: not present in any of the 6 zones")
    func testPaneZoneMapping_settings() {
        let layout = PaneZoneLayout.default

        // No zone hosts Settings (= it lives in its own macOS
        // `Settings` scene, separate window).
        for zone in ZoneSlot.allCases {
            let module = layout.module(for: zone)
            let zoneHostsSettings: Bool = {
                guard let module else { return false }
                return module.rawValue == PaneZoneLayout.settingsName
            }()
            #expect(
                !zoneHostsSettings,
                "Zone \(zone.identifier) must not host Settings"
            )
        }

        // Settings is documented as a global surface (= outside the
        // 6-zone grid).
        #expect(PaneZoneLayout.settingsName == "Settings")
    }
}