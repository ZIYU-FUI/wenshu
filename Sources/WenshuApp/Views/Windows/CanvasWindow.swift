//
// Sources/WenshuApp/Views/Windows/_FILE_.swift
//
//  Independent Canvas window (= JSONCanvasCodec 1:1 renderer).
//
// Per the multi-window pattern:
//  build an MVP independent Canvas window (= renders + edits a
//  .canvas file using the existing JSONCanvasCodec codepath).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        + Apple HIG `.windowResizability(.contentSize)` (= the
//        same shape as kanban + todo windows).
//    S3 (single source of truth for canvas decode): the view
//        delegates JSON parse + serialize to JSONCanvasCodec; = the
//        view never touches Codable directly.

import SwiftUI
import UniformTypeIdentifiers

/// Independent dedicated window (= the multi-window MVP):
/// The save-back wiring lives in the follow-on surface.
///  the read-only gap).
///
/// Renders + edits + saves a JSON Canvas document (= the
/// `JSONCanvasCodec` spec = https://jsoncanvas.org/spec/1.0).
/// File is selected via `.fileImporter` and saved via
/// `.fileExporter` (= Apple HIG canonical open / save surface).
@MainActor
struct CanvasWindow: View {

    @State private var document: CanvasDocument?
    @State private var draft: String = ""
    @State private var importerVisible: Bool = false
    @State private var exporterVisible: Bool = false
    @State private var loadedURL: URL?
    @State private var errorText: String?

    init() {}

    var body: some View {
        NavigationStack {
            contentBody
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            importerVisible = true
                        } label: {
                            Label {
                                Text(WenshuI18n.t("canvas.open"))
                            } icon: {
                                Image(systemName: "folder")
                            }
                        }
                    }
                    //                     // save-back toolbar button. Disabled when no
                    // document is loaded (= no in-memory state to
                    // persist).
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            exporterVisible = true
                        } label: {
                            Label {
                                Text(WenshuI18n.t("canvas.save"))
                            } icon: {
                                Image(systemName: "square.and.arrow.down")
                            }
                        }
                        .disabled(document == nil)
                    }
                }
                .fileImporter(
                    isPresented: $importerVisible,
                    allowedContentTypes: [.json],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImporter(result)
                }
                .fileExporter(
                    isPresented: $exporterVisible,
                    document: document.map { CanvasDocumentFile(document: $0) },
                    contentType: .json,
                    defaultFilename: loadedURL?.deletingPathExtension().lastPathComponent ?? "canvas"
                ) { result in
                    handleFileExporter(result)
                }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    @ViewBuilder
    private var contentBody: some View {
        if let document {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                Text(String(format: WenshuI18n.t("canvas.nodes.count"), document.nodes.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                ForEach(document.nodes) { node in
                    CanvasNodeRow(node: node)
                }
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(DesignTokens.spacingModerate)
        } else {
            EmptyStateView(
                icon: "rectangle.3.group",
                title: WenshuI18n.t("canvas.empty.title"),
                body: WenshuI18n.t("canvas.empty.body")
            )
        }
    }

    private func handleFileImporter(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONCanvasCodec.decode(data)
                document = decoded
                loadedURL = url
                errorText = nil
            } catch {
                errorText = String(describing: error)
            }
        case .failure(let error):
            errorText = String(describing: error)
        }
    }

    private func handleFileExporter(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            loadedURL = url
            errorText = nil
        case .failure(let error):
            errorText = String(describing: error)
        }
    }
}

/// Apple HIG `.fileExporter` requires a `FileDocument` wrapper;
/// = CanvasDocument is plain Codable, so we wrap it here so the
/// save-back path can call JSONCanvasCodec.encode (= SSOT on the
/// codec; = the view never touches Codable directly).
private struct CanvasDocumentFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let document: CanvasDocument

    init(document: CanvasDocument) {
        self.document = document
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.document = try JSONCanvasCodec.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONCanvasCodec.encode(document)
        return FileWrapper(regularFileWithContents: data)
    }
}

/// One canvas node row (= shows id + type + label).
/// Kept internal (= no other view needs this layout).
private struct CanvasNodeRow: View {
    let node: CanvasNode

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(node.label ?? node.id)
                    .font(.body)
                Spacer()
                Text(node.type.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let text = node.text {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DesignTokens.spacingCaption)
    }
}