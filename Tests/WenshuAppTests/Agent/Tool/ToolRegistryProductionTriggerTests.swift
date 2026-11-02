//
//  ToolRegistryProductionTriggerTests.swift · Wenshu · production trigger
//
//  One probe per file. The registry is a process-wide singleton, so a
//  second probe in the same file inherits the first one's state and
//  reports a healthy registry even when production is broken.
//
//  What this proves: the app's own install hook registers the whole
//  tool catalogue, and the production chat path hands the model a
//  non-empty schema set.
//
//  What this must not do: touch a `_registryBootstrap` itself. The
//  existing end-to-end suite performs the trigger explicitly, which is
//  why it stayed green while production's own trigger never fired.
//  This probe exercises the production path only.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

@Suite("ToolRegistry production trigger")
struct ToolRegistryProductionTriggerTests {

    /// Upper bound on the wait for the registrations to land.
    ///
    /// This is a safety net against a registration that never happens
    /// (= a hang), NOT the wait's budget: the wait ends as soon as the
    /// registrations land. Each registration is scheduled on a
    /// background task, so the registry fills asynchronously after the
    /// install hook runs, and how long that takes depends on what else
    /// the process is doing. A fixed sleep tuned for an idle run loses
    /// the race under load; waiting on the registration itself does
    /// not.
    private static let settleCeiling: Duration = .seconds(60)

    /// The app's install hook registers the whole catalogue, and the
    /// production chat path hands the model a non-empty schema set.
    @MainActor
    @Test("the app's install hook registers the whole catalogue")
    func productionTriggerRegistersWholeCatalogue() async throws {
        // What the app calls at launch.
        ToolRegistryBootstrap.install()

        // The first read of the shared registry runs the installed hook.
        let registry = ToolRegistry.shared

        // Wait until every catalogue name has landed. A name counts as
        // registered once the trigger fired for it: another suite in
        // this process may deregister its own marker afterwards, and
        // that says nothing about whether the production trigger ran.
        let catalogue = Set(ToolCatalogue.names)
        let landed = await registry.awaitRegistration(
            of: catalogue,
            ceiling: Self.settleCeiling
        )

        let registered = await registry.getAllToolNames()
        print("REGISTERED count=\(registered.count) names=\(registered.joined(separator: ","))")
        let missing = catalogue.subtracting(registered)
        #expect(
            landed,
            "these tools never registered through the production trigger: \(missing.sorted())"
        )

        // The production chat path: the conductor the app installs at
        // launch (= a turn-time provider, no launch-time tool set),
        // wired the way the chat zone wires it.
        let conductor = WenshuConductor(
            connector: nil,
            toolProvider: WenshuConductor.productionToolProvider()
        )
        await conductor.wireBookScopeGuard(
            currentChatBookID: nil,
            bookDirectory: nil
        )
        let scopedTools = await conductor.tools
        let definitions = await registry.getDefinitions(
            toolNames: Set(scopedTools.keys)
        )
        print("SCHEMAS count=\(definitions.count) names=\(definitions.map(\.name).joined(separator: ","))")
        #expect(
            !definitions.isEmpty,
            "the model-facing schema set is empty (= the model can reach no tool)"
        )

        // The turn-time provider is what hands the model the rest of the
        // catalogue (= the scoped set above holds the book tools only).
        let providerTools = await WenshuConductor.productionToolProvider()()
        print("PROVIDER count=\(providerTools.count) names=\(providerTools.keys.sorted().joined(separator: ","))")
        #expect(
            !providerTools.isEmpty,
            "the turn-time provider resolved no tool (= the model reaches no tool outside the book scope)"
        )
    }
}
