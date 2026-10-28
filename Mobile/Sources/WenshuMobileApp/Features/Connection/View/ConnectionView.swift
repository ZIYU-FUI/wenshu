import SwiftUI

/// The connection screen: pairing, live link, and the states that are
/// not live.
///
/// The screen is pushed onto the tab's stack, so the navigation bar
/// carries its title and the back affordance, and the state sits on a
/// card the system shapes.
struct ConnectionView: View {
    let store: ConnectionStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLarge) {
            header
            card
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.spacingLarge)
        .navigationTitle("Connection")
    }

    /// The name of the link, above the state card.
    private var header: some View {
        Label(title, systemImage: SFIcon.link.rawValue)
            .font(DesignTokens.titleFont)
            .foregroundStyle(DesignTokens.primaryTextColor)
    }

    /// The name the link carries, or the product's own name while the
    /// device is not linked.
    private var title: String {
        switch store.state {
        case let .connected(companion):
            companion.name
        default:
            "Wenshu"
        }
    }

    /// The state of the link, on the system's own material.
    private var card: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMedium) {
            state
        }
        .padding(DesignTokens.spacingLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: ContainerRelativeShape())
    }

    @ViewBuilder
    private var state: some View {
        switch store.state {
        case .idle:
            SFIcon.stateEmpty
                .font(DesignTokens.glyphFont)
                .foregroundStyle(DesignTokens.secondaryTextColor)
            Text("No Mac is paired yet.")
                .font(DesignTokens.bodyFont)
        case let .pairing(code):
            ProgressView("Pairing with code \(code.value)")
                .font(DesignTokens.bodyFont)
        case let .connected(companion):
            Label(companion.name, systemImage: SFIcon.stateOnline.rawValue)
                .font(DesignTokens.bodyFont)
            Text("Revision \(companion.revision)")
                .font(DesignTokens.captionFont)
                .foregroundStyle(DesignTokens.secondaryTextColor)
        case let .offline(reason):
            SFIcon.stateOffline
                .font(DesignTokens.glyphFont)
                .foregroundStyle(DesignTokens.secondaryTextColor)
            Text(reason)
                .font(DesignTokens.bodyFont)
        case let .refused(reason):
            SFIcon.stateError
                .font(DesignTokens.glyphFont)
                .foregroundStyle(DesignTokens.errorColor)
            Text(reason)
                .font(DesignTokens.bodyFont)
        }
    }
}
