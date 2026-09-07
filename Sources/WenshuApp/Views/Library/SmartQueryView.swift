// SmartQueryView.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Saved-search UI (= FCP Library Smart Collection analogue).
// v0.26 ships a static placeholder UI (= list + add/edit/delete);
// v0.27+ implements the actual search engine that evaluates the
// SmartQuery.queryJSON predicates against the library's entities.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 017.

import SwiftUI

struct SmartQueryView: View {
    /// All known saved searches (= loaded from
    /// <reference-library>/indexes/saved-searches/).
    @State private var queries: [SmartQuery] = []
    @State private var showCreateSheet: Bool = false
    @State private var newQueryName: String = ""

    /// Functional-injection: parent decides where to load/save
    /// (= ticket 019 BookStore @Environment; v0.26 uses a closure
    /// pattern since the storage layer is part of the future
    /// SmartQueryParser + LibraryIndexer work).
    var onLoadAll: (() -> [SmartQuery])?
    var onSave: ((SmartQuery) -> Void)?
    var onDelete: ((UUID) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(WenshuI18n.t("smartquery.tab_label"))
                    .font(.headline)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Label(WenshuI18n.t("auto2.smartqueryview.l37.h49599855"), systemImage: "plus")
                }
                .controlSize(.small)
            }
            .padding()
            Divider()
            if queries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(minWidth: 280, minHeight: 200)
        .onAppear(perform: reload)
        .sheet(isPresented: $showCreateSheet) {
            createSheet
        }
    }

    @ViewBuilder
    private var list: some View {
        List(queries) { query in
            HStack {
                // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical.
                LucideIconSystemFallback("magnifyingglass.circle", size: 18)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(query.name)
                        .font(.headline)
                    Text(WenshuI18n.t("auto.smartqueryview.l66.h44879479"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .contextMenu {
                Button(WenshuI18n.t("auto2.smartqueryview.l73.h22475030"), role: .destructive) {
                    delete(query)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical.
            LucideIconSystemFallback("magnifyingglass.circle", size: 48)
                .foregroundStyle(.tertiary)
            Text(WenshuI18n.t("auto.smartqueryview.l86.h89952862"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(WenshuI18n.t("auto.smartqueryview.l89.h6572603"))
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var createSheet: some View {
        NavigationStack {
            Form {
                Section(WenshuI18n.t("auto2.smartqueryview.l100.h38153477")) {
                    TextField(WenshuI18n.t("auto2.smartqueryview.l101.h43731610"), text: $newQueryName)
                        .textFieldStyle(.roundedBorder)
                }
                Section {
                    Text(WenshuI18n.t("auto2.smartqueryview.l105.h81062794"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            // v0.40 apple-001 HIG absent batch: .navigationTitle +
            // .toolbar (= Apple HIG standard for sheet chrome). The
            // inline HStack { Text + Divider } header was removed.
            .navigationTitle(WenshuI18n.t("smart_query.create.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WenshuI18n.t("auto2.smartqueryview.l117.h19213351")) { showCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(WenshuI18n.t("auto2.smartqueryview.l120.h24989358")) { create() }
                        .disabled(newQueryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 280, idealHeight: 340)
        // POLISH-LIQUIDGLASS-004: New Smart Query modal sheet root
        // uses Apple .glassEffect(.regular) (= macOS 27 Tahoe Liquid
        // Glass; same shape as POLISH-LIQUIDGLASS-001/002/003 that
        // glassed TopBar + Sidebar + Editor chrome + StatusBar).
        // Color.clear provides the glass layer size; the modifier
        // applies the canonical Apple Liquid Glass material. No
        // custom border or shadow (= boss 2026-09-02 hard rule
        // 'every color comes from an Apple API'; .glassEffect already
        // includes the canonical hairline + depth shadow per Apple
        // HIG). Applied AFTER .frame so the glass layer sizes to the
        // sheet's idealWidth: 420 outer rect.
        .background { Color.clear.glassEffect(.regular) }
    }

    // MARK: - Actions

    private func reload() {
        queries = onLoadAll?() ?? []
    }

    private func create() {
        let trimmedName = newQueryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let query = SmartQuery(name: trimmedName)
        onSave?(query)
        showCreateSheet = false
        newQueryName = ""
        reload()
    }

    private func delete(_ query: SmartQuery) {
        onDelete?(query.id)
        reload()
    }
}