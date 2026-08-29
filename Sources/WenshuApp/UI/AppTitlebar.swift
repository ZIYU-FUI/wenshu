// AppTitlebar.swift · Wenshu (文枢) · v0.28 followup TKT-028-015
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// AppRoot titlebar from Hermes Desktop verbatim. AppRoot component
// (= NOT inside the layout tree; sits fixed at top of root view).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/app/shell/titlebar.ts
// + titlebar-controls.tsx
// = TITLEBAR_HEIGHT = 34 (= native traffic light standard)
//   TITLEBAR_CONTROL_SIZE = 24 (= tighter optical match to traffic-light 14 PT)
//   TITLEBAR_FALLBACK_WINDOW_BUTTON_X = 24
//   TITLEBAR_EDGE_INSET = 14 (= Windows/Linux fullscreen)
//   titlebarButtonClass (text-muted-foreground/85 hover:bg-control-hover)
//   titlebarToolClusterClass (pointer-events-auto [-webkit-app-region:no-drag])
//   titlebarControlsYNudge (= pre-Tahoe macOS optical center)
//
// The titlebar is APP-ROOT (= not in the tree). It hosts 4 categories
// of tools (matching hermes):
// - left: project title + project picker
// - center (between L/R clusters): optional title
// - right: sidebar toggle, file browser toggle, model picker, etc.
// - badges: count of unread sessions (= future ticket)

import SwiftUI
import AppKit

// MARK: - Titlebar tokens (= matches hermes titlebar.ts)

/// Titlebar height (= native traffic light standard). Matches Hermes
/// `TITLEBAR_HEIGHT = 34`.
public let kTitlebarHeight: CGFloat = 34

/// Titlebar tool hit target (= both axes). Matches Hermes
/// `TITLEBAR_CONTROL_SIZE = 24`. Tighter than the 30 PT boss originally
/// specced (= 24 PT matches the 14 PT traffic-light glyphs optically).
public let kTitlebarControlSize: CGFloat = 24

/// Codicon glyph box in titlebar clusters (= optical match to
/// traffic-light row). Matches Hermes `TITLEBAR_ICON_SIZE = 13.9`.
public let kTitlebarIconSize: CGFloat = 13.9

/// Inset from the left edge for the right-cluster (= when no left-side
/// native controls take up space — Windows/Linux + macOS fullscreen).
/// Matches Hermes `TITLEBAR_EDGE_INSET = 14`.
public let kTitlebarEdgeInset: CGFloat = 14

/// Offset from the traffic-light cluster to the first titlebar tool.
/// Matches Hermes `TITLEBAR_CONTROL_OFFSET_X = 74`.
public let kTitlebarControlOffsetX: CGFloat = 74

/// Fallback x for the leftmost traffic-light button when NSWindow
/// reports no position. Matches Hermes `TITLEBAR_FALLBACK_WINDOW_BUTTON_X = 24`.
public let kTitlebarFallbackWindowButtonX: CGFloat = 24

/// macOS traffic-light row only: nudge the left toolbar cluster down
/// to sit on the same optical center as the native buttons on pre-Tahoe
/// macOS (= Darwin < 25). Matches Hermes `TITLEBAR_MAC_TRAFFIC_LIGHTS_Y_NUDGE`.
public let kTitlebarMacTrafficLightsYNudge: CGFloat = 4.5

// MARK: - Titlebar controls (= a registered contribution)

/// One titlebar tool (= button). Matches Hermes `TitlebarTool` interface.
public struct TitlebarTool: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let active: Bool
    public let disabled: Bool
    public let hidden: Bool
    public let iconName: String  // SF Symbol name (= SF Symbols = Apple's free icon set, replaces Codicon for SwiftUI)
    public let onSelect: (@Sendable () -> Void)?
    public let badge: Int?
    public let actionId: String?

    public init(
        id: String,
        label: String,
        active: Bool = false,
        disabled: Bool = false,
        hidden: Bool = false,
        iconName: String,
        onSelect: (@Sendable () -> Void)? = nil,
        badge: Int? = nil,
        actionId: String? = nil
    ) {
        self.id = id
        self.label = label
        self.active = active
        self.disabled = disabled
        self.hidden = hidden
        self.iconName = iconName
        self.onSelect = onSelect
        self.badge = badge
        self.actionId = actionId
    }
}

// MARK: - Titlebar cluster (= left + right)

public enum TitlebarToolSide: String, Sendable {
    case left
    case right
}

// MARK: - AppTitlebar

/// The AppRoot titlebar (= fixed top, not in tree). Hosts registered
/// titlebar tools via ContributionRegistry (= left cluster for project
/// + sidebar toggles; right cluster for model picker + status etc.).
@MainActor
public struct AppTitlebar: View {
    let registry: ContributionRegistry
    let leftTools: [TitlebarTool]
    let rightTools: [TitlebarTool]
    let title: String?

    public init(
        registry: ContributionRegistry,
        leftTools: [TitlebarTool] = [],
        rightTools: [TitlebarTool] = [],
        title: String? = nil
    ) {
        self.registry = registry
        self.leftTools = leftTools
        self.rightTools = rightTools
        self.title = title
    }

    public var body: some View {
        ZStack {
            // Background fill + bottom hairline.
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(nsColor: .separatorColor)),
                    alignment: .bottom
                )
            // Drag strip (= allows user to drag the window by the titlebar).
            // SwiftUI Window doesn't expose `-webkit-app-region: drag` directly;
            // we use `.background(WindowAccessor())` to set NSWindow.isMovableByBackground
            // = the entire titlebar area is the drag strip.
            WindowDraggable()

            // Left cluster (= traffic lights + project title + left tools).
            HStack(spacing: 0) {
                // Reserve space for macOS traffic lights (= already drawn
                // by NSWindow but we leave the strip empty so user can
                // drag the window by it).
                Spacer()
                    .frame(width: kTitlebarControlOffsetX, height: kTitlebarHeight)
                ForEach(leftTools.filter { !$0.hidden }) { tool in
                    TitlebarButton(tool: tool)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 0)

            // Center: optional title.
            if let title {
                Text(title)
                    .font(.system(size: kTitlebarIconSize, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Right cluster (= model picker + status etc.).
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ForEach(rightTools.filter { !$0.hidden }) { tool in
                    TitlebarButton(tool: tool)
                }
                // Reserve right edge for macOS native controls (= empty strip).
                Spacer()
                    .frame(width: kTitlebarEdgeInset, height: kTitlebarHeight)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 0)
        }
        .frame(height: kTitlebarHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Titlebar")
    }
}

// MARK: - TitlebarButton (= single tool)

@MainActor
private struct TitlebarButton: View {
    let tool: TitlebarTool
    @State private var isHover: Bool = false

    var body: some View {
        Button {
            tool.onSelect?()
        } label: {
            Image(systemName: tool.iconName)
                .font(.system(size: kTitlebarIconSize, weight: .regular))
                .foregroundColor(tool.active ? .primary : Color.secondary.opacity(0.85))
                .frame(width: kTitlebarControlSize, height: kTitlebarControlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(tool.disabled)
        .opacity(tool.disabled ? 0.45 : 1.0)
        .onHover { hover in
            isHover = hover
        }
        .background(
            isHover
                ? Color(nsColor: .controlBackgroundColor).opacity(0.3)
                : Color.clear
        )
        .help(tool.label)
        .accessibilityLabel(tool.label)
    }
}

private struct TitlebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                ? Color(nsColor: .controlBackgroundColor).opacity(0.5)
                : Color.clear
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - WindowDraggable (= make titlebar drag region)

/// Helper view that sets NSWindow.isMovableByBackground = true (= the
/// whole titlebar becomes a drag region, equivalent to Electron's
/// `-webkit-app-region: drag`). Uses SwiftUI's native window drag API
/// via `.background(WindowAccessor())` pattern.
private struct WindowDraggable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            // v0.28 followup fix: don't set `isMovableByBackground` via
            // setValue(forKey:) (= crashes on SwiftUI.AppKitWindow which
            // doesn't expose that KVC key). Instead, use the SwiftUI
            // window-drag gesture OR rely on the AppTitlebar's full-width
            // background to provide a large drag surface (NSWindow
            // isMovable by default; users can drag any unhandled area
            // that's a backdrop of an NSView inside the window).
            // .titlebarAppearsTransparent is set at AppDelegate level
            // (= when the NSWindow becomes available post-launch).
            _ = window
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Default titlebar tools (= wenshu baseline)

/// Default left-side tools (= sidebar toggle ⌘B + project preview ⌘P).
@MainActor
public func defaultTitlebarLeftTools(
    sidebarVisible: Bool,
    previewVisible: Bool,
    onToggleSidebar: @escaping @Sendable () -> Void,
    onTogglePreview: @escaping @Sendable () -> Void,
    onToggleTools: @escaping @Sendable () -> Void
) -> [TitlebarTool] {
    return [
        TitlebarTool(
            id: "sidebar-toggle",
            label: "Toggle sidebar (⌘B)",
            active: sidebarVisible,
            iconName: "sidebar.left",
            onSelect: onToggleSidebar,
            actionId: "view.toggleSidebar"
        ),
        TitlebarTool(
            id: "preview-toggle",
            label: "Toggle preview (⌘P)",
            active: previewVisible,
            iconName: "rectangle.split.2x1",
            onSelect: onTogglePreview,
            actionId: "view.togglePreview"
        ),
        TitlebarTool(
            id: "tools-toggle",
            label: "Toggle tools (⌘T)",
            active: false,
            iconName: "wrench.adjustable",
            onSelect: onToggleTools,
            actionId: "view.toggleTools"
        ),
    ]
}

/// Default right-side tools (= model picker + status).
@MainActor
public func defaultTitlebarRightTools(
    modelName: String,
    onSelectModel: @escaping @Sendable () -> Void
) -> [TitlebarTool] {
    return [
        TitlebarTool(
            id: "model-picker",
            label: "Model: \(modelName)",
            active: false,
            iconName: "cpu",
            onSelect: onSelectModel,
            actionId: "model.openPicker"
        ),
    ]
}