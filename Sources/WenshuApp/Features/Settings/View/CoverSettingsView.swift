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

    /// The provider slugs the user can pick from.
    private var providerSlugs: [String] {
        Provider.all.map(\.slug)
    }

    var body: some View {
        Form {
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
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onChange(of: imageRoute) { _, _ in store.imageRoute = imageRoute }
        .onChange(of: videoRoute) { _, _ in store.videoRoute = videoRoute }
    }

    /// Reads both routes back.
    private func load() {
        imageRoute = store.imageRoute
        videoRoute = store.videoRoute
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SFIcon(kind == .image ? "photo" : "film", style: .inlineSmall, color: IconColor.secondary)
                Text(summary)
                    .font(.body)
                Spacer()
                Button(String(localized: "settings.covers.change")) {
                    isEditing.toggle()
                }
                .buttonStyle(.link)
            }

            if isEditing {
                Picker(String(localized: "settings.covers.provider"), selection: providerBinding) {
                    Text(String(localized: "settings.covers.useMainProvider")).tag("")
                    ForEach(providerSlugs, id: \.self) { slug in
                        Text(slug).tag(slug)
                    }
                }
                .pickerStyle(.menu)

                SecureField(String(localized: "settings.covers.apiKey"), text: $keyDraft)
                    .textFieldStyle(.roundedBorder)

                Button(String(localized: "settings.covers.resetToAutomatic")) {
                    route = route.resetting()
                    keyDraft = ""
                    isEditing = false
                }
                .buttonStyle(.link)
            }
        }
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
            }
        )
    }
}
