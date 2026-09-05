// PaneVisibleContext.swift · Wenshu · v0.28 followup TKT-028-013
//
// Boss 2026-08-29 OOB 'verbatim port from hermes app' = port the SwiftUI
// environment values for pane visibility / lifecycle / group from
// Hermes Desktop verbatim. These let nested panes subscribe to
// visibility / lifecycle / group-key without prop-drilling.
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/pane-visibility.ts
// = PaneVisibleContext + PaneLifecycleContext + PaneGroupContext +
//   hiddenPaneProps() + queryAllVisible() + queryVisible() +
//   isElementInHiddenPane() + NO_PANE_GROUP sentinel.

import Foundation
import SwiftUI

/// Group key (= layout zone id) for a pane rendered inside a tab stack.
/// State that should be PER-ZONE rather than per-window/per-tab keys
/// off this (= composer pop-out, etc.). Follows a pane dragged between
/// zones because the provider is the zone that renders it.
public typealias PaneGroupKey = String

/// Fallback group key for a surface rendered OUTSIDE the layout tree
/// (= secondary windows, plain routes). One bucket, since there are
/// no sibling zones there to tell apart.
public let kNoPaneGroup: PaneGroupKey = "window"

// MARK: - Visibility (= visible | hidden)

/// SwiftUI Environment value: true if the current pane is on-screen
/// (= visible tab in active stack). False for inactive tabs in a
/// keep-alive stack (= layout box preserved, content hidden).
private struct PaneVisibleEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    public var paneVisible: Bool {
        get { self[PaneVisibleEnvironmentKey.self] }
        set { self[PaneVisibleEnvironmentKey.self] = newValue }
    }
}

/// SwiftUI View modifier to provide pane visibility. Use in
/// `TreeGroup` (= layout zone) to scope descendants.
public struct PaneVisibleContext: View {
    let visible: Bool
    let content: AnyView
    public init<V: View>(visible: Bool, @ViewBuilder content: () -> V) {
        self.visible = visible
        self.content = AnyView(content())
    }
    public var body: some View {
        content.environment(\.paneVisible, visible)
    }
}

// MARK: - Lifecycle (= visible | hot-hidden | parked)

private struct PaneLifecycleEnvironmentKey: EnvironmentKey {
    static let defaultValue: PaneLifecycle = .visible
}

extension EnvironmentValues {
    public var paneLifecycle: PaneLifecycle {
        get { self[PaneLifecycleEnvironmentKey.self] }
        set { self[PaneLifecycleEnvironmentKey.self] = newValue }
    }
}

public struct PaneLifecycleContext: View {
    let lifecycle: PaneLifecycle
    let content: AnyView
    public init<V: View>(lifecycle: PaneLifecycle, @ViewBuilder content: () -> V) {
        self.lifecycle = lifecycle
        self.content = AnyView(content())
    }
    public var body: some View {
        content.environment(\.paneLifecycle, lifecycle)
    }
}

// MARK: - Group (= which zone the pane is in)

private struct PaneGroupEnvironmentKey: EnvironmentKey {
    static let defaultValue: PaneGroupKey = kNoPaneGroup
}

extension EnvironmentValues {
    public var paneGroup: PaneGroupKey {
        get { self[PaneGroupEnvironmentKey.self] }
        set { self[PaneGroupEnvironmentKey.self] = newValue }
    }
}

public struct PaneGroupContext: View {
    let groupId: PaneGroupKey
    let content: AnyView
    public init<V: View>(groupId: PaneGroupKey, @ViewBuilder content: () -> V) {
        self.groupId = groupId
        self.content = AnyView(content())
    }
    public var body: some View {
        content.environment(\.paneGroup, groupId)
    }
}

// MARK: - Hidden pane marker (= matches hermes `hiddenPaneProps`)

/// The DOM attribute name that marks a keep-alive hidden pane. Wenshu
/// uses this on the SwiftUI View via `.accessibilityHidden(true)` +
/// `.opacity(0)` (= equivalent to `visibility: hidden` in DOM =
/// preserves layout box but hides content).
public let kPaneHiddenAccessibilityTrait: String = "pane-hidden"

/// Modifier that marks a pane layer as kept-alive but hidden. The
/// layout box is preserved (= scroll positions survive a tab round-trip).
public struct HiddenPane: ViewModifier {
    let hidden: Bool
    public func body(content: Content) -> some View {
        content
            .opacity(hidden ? 0 : 1)
            .accessibilityHidden(hidden)
            .allowsHitTesting(!hidden)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isImage)
            .accessibilityLabel(kPaneHiddenAccessibilityTrait)
    }
}

extension View {
    /// Mark this view as a kept-alive hidden pane (= `visibility: hidden`
    /// equivalent: layout box preserved, content hidden).
    public func hiddenPane(_ hidden: Bool) -> some View {
        modifier(HiddenPane(hidden: hidden))
    }
}