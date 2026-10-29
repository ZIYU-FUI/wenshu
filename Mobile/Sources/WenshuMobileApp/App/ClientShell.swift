import SwiftUI

/// The shell the client draws.
///
/// A phone gets the tab bar it expects, with a stack in each tab. A
/// width that earns more gets the split view the wide screen wants.
/// The choice is a pure function of the width, so the phone case and
/// the iPad case are both proven without a device.
enum ClientShellLayout: Equatable, Sendable {
    /// The tab bar, one tab per destination.
    case tabBar
    /// The split view: a sidebar of destinations and a detail.
    case splitView

    /// The shell an adaptive layout earns.
    ///
    /// The width picks the shape. The foldable-native API refines how
    /// the columns are drawn, not which shell the client draws, so
    /// both sides of that availability gate take the same shell.
    static func layout(for adaptiveLayout: AdaptiveLayout) -> ClientShellLayout {
        switch adaptiveLayout.shape {
        case .stack: .tabBar
        case .split: .splitView
        }
    }
}

/// The destinations the shell offers.
///
/// The product has two: the library the Mac sends, and the Mac this
/// device links to. A new top-level destination arrives here.
enum ClientDestination: String, CaseIterable, Hashable, Sendable {
    /// The library the Mac sends.
    case library
    /// The Mac this device links to.
    case connect

    /// The title the destination carries.
    var title: String {
        switch self {
        case .library: "Library"
        case .connect: "Connect"
        }
    }

    /// The symbol the destination carries.
    var symbol: SFIcon {
        switch self {
        case .library: .library
        case .connect: .link
        }
    }
}

/// The shell of the client.
///
/// The compact width draws the tab bar, with a stack in each tab, so a
/// screen pushes onto a stack and carries the navigation bar's title.
/// The regular width draws the split view, with the destinations in the
/// sidebar and the chosen destination in the detail.
///
/// The chrome is the system's: the tab bar is `TabView`'s, the titles
/// are the navigation bar's, the empty state is Apple's. The client
/// draws none of them itself.
struct ClientShell: View {
    /// The link state the shell shows.
    let store: ConnectionStore

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The chosen destination.
    ///
    /// The library is the one a person opens the app for, so it is the
    /// one the shell starts on, and the tab bar shows it selected.
    @State private var selection: ClientDestination? = .library

    var body: some View {
        glassLayer
    }

    /// The shell inside the container that shares one glass layer.
    ///
    /// The glass surfaces of one screen belong to one layer, so the
    /// container holds them. The system offers the container from iOS 26
    /// on; below that the shell draws on its own.
    @ViewBuilder
    private var glassLayer: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer {
                shell
            }
        } else {
            shell
        }
    }

    /// The shell the current width earns.
    @ViewBuilder
    private var shell: some View {
        switch layout {
        case .tabBar:
            tabBar
        case .splitView:
            splitView
        }
    }

    /// The shell the current width earns.
    ///
    /// The container that draws the columns reads the same width, so
    /// the two agree about the shape.
    private var layout: ClientShellLayout {
        ClientShellLayout.layout(for: AdaptiveLayout.decide(
            sizeClass: horizontalSizeClass,
            foldableNativeAvailable: AdaptiveLayout.foldableNativeAvailable
        ))
    }

    /// The phone shell: a tab bar, with a stack in each tab.
    ///
    /// The tab bar is `TabView`'s own, so the app draws no bar of its
    /// own, and the stack in each tab is the one a screen pushes onto.
    private var tabBar: some View {
        TabView(selection: $selection) {
            ForEach(ClientDestination.allCases, id: \.self) { destination in
                Tab(value: destination) {
                    NavigationStack {
                        destinationContent(for: destination)
                    }
                } label: {
                    Label(destination.title, systemImage: destination.symbol.rawValue)
                }
            }
        }
    }

    /// The wide shell: the split view, with the destinations in the
    /// sidebar and the chosen destination in the detail.
    ///
    /// The container holds the columns and the foldable refinement; the
    /// shell holds the choice, so the phone case is one named type with
    /// a test.
    private var splitView: some View {
        AdaptiveLayoutContainer(
            compact: tabBar,
            sidebar: destinationSidebar,
            detail: destinationDetail
        )
    }

    /// The destinations, in the sidebar the regular width earns.
    ///
    /// A phone never draws this: the compact width takes the tab bar.
    private var destinationSidebar: some View {
        List(selection: $selection) {
            ForEach(ClientDestination.allCases, id: \.self) { destination in
                Label(destination.title, systemImage: destination.symbol.rawValue)
                    .tag(destination)
            }
        }
        .navigationTitle("Wenshu")
    }

    /// The chosen destination, in the detail.
    ///
    /// The stack is keyed on the destination, so a screen one
    /// destination pushed does not sit over the next one.
    private var destinationDetail: some View {
        NavigationStack {
            destinationContent(for: chosenDestination)
        }
        .id(chosenDestination)
    }

    /// The destination the detail shows.
    private var chosenDestination: ClientDestination {
        selection ?? .library
    }

    /// The content a destination draws.
    @ViewBuilder
    private func destinationContent(for destination: ClientDestination) -> some View {
        switch destination {
        case .library:
            LibraryOutlineView(link: store)
        case .connect:
            ConnectionListView(store: store)
        }
    }
}
