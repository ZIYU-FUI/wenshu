import SwiftUI

/// The connection screen: pairing, live link, and the states that are
/// not live.
struct ConnectionView: View {
    let store: ConnectionStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLarge) {
            header
            content
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.spacingLarge)
        .navigationTitle("Library")
    }

    private var header: some View {
        Label(title, systemImage: SFIcon.link.rawValue)
            .font(DesignTokens.titleFont)
            .foregroundStyle(DesignTokens.primaryTextColor)
    }

    @ViewBuilder
    private var content: some View {
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

    private var title: String {
        switch store.state {
        case let .connected(companion):
            companion.name
        default:
            "Wenshu"
        }
    }
}
