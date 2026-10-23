//
//  Features/Settings/View/CoverSettingsView.swift
//
//   : CoverSettingsView.
//  The settings pane for the cover art services.
//
//  Two rows: one for the service that DRAWS a cover and one for the
//  service that animates it. Each row is the same view, so the two
//  cannot drift apart.
//
//  The shape is the Hermes auxiliary-model settings: a row per task,
//  the current target in the middle, a "Change" control, and a
//  "reset to automatic" control that puts the route back to
//  inheriting.
//
//  Two rules the pane enforces, because both are mistakes a user
//  makes easily:
//
//  - Changing the PROVIDER clears the model, the endpoint and the
//    key, because they belonged to the old provider. The route is
//    one unit.
//  - The video row carries a note about the allowance, because the
//    video quota is a handful of clips a day and only the user may
//    spend it.
//

import SwiftUI
import WenshuAgent

/// The settings pane for the cover art services.
struct CoverSettingsView: View {

    /// The store the two routes live in.
    @State private var store = CoverServiceRouteStore()

    /// The image route.
    @State private var imageRoute = CoverServiceRoute.auto(for: .image)

    /// The video route.
    @State private var videoRoute = CoverServiceRoute.auto(for: .video)

    /// Whether new documents get a cover on their own.
    @State private var isAutoCoverEnabled = false

    /// Where the automatic-cover switch lives.
    private let autoStore = CoverAutoCoverStore()

    /// The provider slugs the user can pick from.
    ///
    /// ONLY the services the app can speak: the cover feature talks
    /// one protocol per service, and a service outside the list would
    /// be called with a request it does not understand. At 1.0 that
    /// is MiniMax; each service the app learns to speak joins the
    /// list on its own card.
    private var providerSlugs: [String] {
        Provider.all
            .map(\.slug)
            .filter { CoverProviderCapability.coverProtocolProviders.contains($0) }
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    String(localized: "settings.covers.autoGenerate"),
                    isOn: $isAutoCoverEnabled
                )
            } footer: {
                // The switch is a MOMENT, not a flag: turning it on
                // stamps the time, and the documents that are already
                // in the library stay with the batch.
                Text(String(localized: "settings.covers.autoGenerateCaption"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                CoverRouteRow(
                    kind: .image,
                    route: $imageRoute,
                    providerSlugs: providerSlugs
                )
            } header: {
                Text(String(localized: "settings.covers.imageService"))
            } footer: {
                Text(String(localized: "settings.covers.imageServiceCaption"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                CoverRouteRow(
                    kind: .video,
                    route: $videoRoute,
                    providerSlugs: providerSlugs
                )
            } header: {
                Text(String(localized: "settings.covers.videoService"))
            } footer: {
                // The video allowance is scarce, and the user needs to
                // know that a moving cover is their call, not the
                // app's.
                Text(String(localized: "settings.covers.videoQuotaNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                // Which protocol the app speaks. It speaks ONE (= the
                // MiniMax cover endpoints), and the user chooses the
                // service here, so the honest thing is to say it.
                Text(String(localized: "settings.covers.protocolNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onChange(of: imageRoute) { _, _ in store.imageRoute = imageRoute }
        .onChange(of: videoRoute) { _, _ in store.videoRoute = videoRoute }
        .onChange(of: isAutoCoverEnabled) { _, isOn in
            // Turning the switch ON stamps the moment, so the
            // documents already in the library stay with the batch.
            if isOn {
                autoStore.enable()
            } else {
                autoStore.disable()
            }
        }
    }

    /// Reads both routes and the switch back.
    private func load() {
        imageRoute = store.imageRoute
        videoRoute = store.videoRoute
        isAutoCoverEnabled = autoStore.policy.isEnabled
    }
}

/// One route row: the current target, a "Change" control, and a
/// "reset to automatic" control.
struct CoverRouteRow: View {

    /// Which service this row points at.
    let kind: CoverServiceKind

    /// The route this row edits.
    @Binding var route: CoverServiceRoute

    /// The provider slugs the user can pick from.
    let providerSlugs: [String]

    /// The provider picker and the key field, revealed when the user
    /// has moved off "automatic".
    @State private var isEditing = false

    /// The key the user typed, held separately so the route is only
    /// replaced when the user commits.
    @State private var keyDraft = ""

    /// The model the user typed, held the same way (= the route is
    /// replaced as one unit, and the model belongs to the provider).
    @State private var modelDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SFIcon(kind == .image ? "photo" : "film", style: .inlineSmall, color: IconColor.secondary)
                Text(summary)
                    .font(.body)
                Spacer()
                Button(String(localized: "settings.covers.change")) {
                    isEditing.toggle()
                    if isEditing {
                        modelDraft = route.model ?? ""
                    }
                }
                .buttonStyle(.link)
            }

            // The protocol note. The app speaks ONE cover protocol
            // (= MiniMax's image and video endpoints), and a service
            // of the user's own is called as it is: so a service that
            // speaks another protocol says so here, before a cover
            // is drawn, instead of the service's own error saying it
            // later.
            if !CoverProviderCapability.speaksCoverProtocol(baseURL: route.baseURL) {
                Text(String(localized: "settings.covers.foreignEndpointNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The mode note. The endpoint serves the
            // first-and-last-frame mode for one video model only, and a
            // route that names another one loses the seamless loop
            // silently, so the row says what the user would otherwise
            // only find out by watching the seam jump.
            if kind == .video && !CoverVideoGenerator.servesFirstAndLastFrame(route) {
                Text(String(localized: "settings.covers.videoNoSeamlessLoop"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isEditing {
                Picker(String(localized: "settings.covers.provider"), selection: providerBinding) {
                    Text(String(localized: "settings.covers.useMainProvider")).tag("")
                    ForEach(providerSlugs, id: \.self) { slug in
                        Text(slug).tag(slug)
                    }
                }
                .pickerStyle(.menu)

                TextField(String(localized: "settings.covers.model"), text: $modelDraft)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                SecureField(String(localized: "settings.covers.apiKey"), text: $keyDraft)
                    .textFieldStyle(.roundedBorder)

                Button(String(localized: "settings.covers.save")) {
                    commit()
                }
                .buttonStyle(.link)

                Button(String(localized: "settings.covers.resetToAutomatic")) {
                    route = route.resetting()
                    keyDraft = ""
                    modelDraft = ""
                    isEditing = false
                }
                .buttonStyle(.link)
            }
        }
    }

    /// Writes the route the user typed.
    ///
    /// The route is replaced as ONE unit: the provider, the model and
    /// the key belong together, and a route whose provider changed
    /// while its model did not is a broken route. So the commit
    /// writes all three at once.
    ///
    /// The MODEL is what makes a video route resolve at all (= the
    /// video kind has no default model, on purpose), and the KEY was
    /// typed but never written before this, so a user who set a key
    /// for a service got the provider's own key instead.
    private func commit() {
        let provider = route.providerSlug
        let model = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        route = route.replacing(
            providerSlug: provider,
            model: model.isEmpty ? nil : model,
            baseURL: route.baseURL,
            apiKey: key.isEmpty ? nil : key
        )
    }

    /// What the row shows: the current target, in one line.
    private var summary: String {
        if route.isAuto {
            return String(localized: "settings.covers.useMainProvider")
        }
        let provider = route.providerSlug ?? String(localized: "settings.covers.useMainProvider")
        if let model = route.model {
            return "\(provider) · \(model)"
        }
        return provider
    }

    /// The provider picker.
    ///
    /// Choosing a provider REPLACES the whole route: the model, the
    /// endpoint and the key belonged to the old provider, and keeping
    /// any of them would be a broken route. That is why the picker
    /// writes the route and not a single field.
    private var providerBinding: Binding<String> {
        Binding(
            get: { route.providerSlug ?? "" },
            set: { slug in
                if slug.isEmpty {
                    route = route.resetting()
                    keyDraft = ""
                    return
                }
                route = route.replacing(
                    providerSlug: slug,
                    model: nil,
                    baseURL: nil,
                    apiKey: nil
                )
                keyDraft = ""
                modelDraft = ""
            }
        )
    }
}
