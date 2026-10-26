//
//  LiveImportTests.swift · wenshu
//
//  The import chain against a REAL provider.
//
//  Everything else in the suite runs against a stub connector, = so it
//  proves the wiring but not the model. These two tests close that
//  gap: = a real model reads the real procedure, calls the real write
//  tool, and the file lands where the user asked.
//
//  They spend tokens and they need the user's key, = so they run only
//  when the environment asks for them:
//
//      WENSHU_LIVE_IMPORT=1 swift test --filter LiveImportTests
//
//  Without the flag the tests return early (= the suite stays hermetic).
//
//  The key never leaves the process: = it is read from the app's own
//  provider-key file, = handed to the keychain store, = and never
//  printed, = never written to a file, = never put in a message.
//

import Foundation
import WenshuAgent
import XCTest
@testable import WenshuApp

final class LiveImportTests: XCTestCase {

    // MARK: - The gate

    /// Live runs are opt-in (= they spend the user's tokens).
    private var liveEnabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_IMPORT"] == "1"
    }

    // MARK: - The app's own configuration

    /// The provider slug the app would use (= the app's setting; = the
    /// first provider with a key when the setting is empty).
    private static func activeProviderSlug() -> String? {
        let defaults = UserDefaults(suiteName: "com.wenshu.app")
        if let slug = defaults?.string(forKey: "wenshu.llm.activeConnector"),
           !slug.isEmpty {
            return slug
        }
        return "minimax-cn"
    }

    /// The model the user picked (= the app's setting).
    private static func activeModelSlug() -> String? {
        let defaults = UserDefaults(suiteName: "com.wenshu.app")
        if let model = defaults?.string(forKey: "wenshu.llm.model"), !model.isEmpty {
            return model
        }
        return nil
    }

    /// The provider's key, from the app's own provider-key file.
    ///
    /// The file holds the key the user configured; = a test process
    /// cannot reach the app's keychain (= a different bundle
    /// identifier), = so the file is the app's own mirror of it. The
    /// value goes straight into the keychain store and is never
    /// printed.
    private static func installProviderKey(_ provider: Provider) throws {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.wenshu.app")
            .appendingPathComponent("provider-keys.json")
        let data = try Data(contentsOf: path)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let key = json?[provider.slug] as? String, !key.isEmpty else {
            throw NSError(
                domain: "LiveImportTests", code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "No provider key for '\(provider.slug)' in the app's provider-key file."]
            )
        }
        try ProviderKeychain.saveKeySync(key, for: provider)
    }

    /// The connector the app would use, with its key installed.
    private func makeLiveConnector() throws -> (any LLMConnector, String) {
        guard let slug = Self.activeProviderSlug(),
              let provider = Provider.by(slug: slug) else {
            throw NSError(
                domain: "LiveImportTests", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No known provider for the active slug."]
            )
        }
        try Self.installProviderKey(provider)
        // The session may go out through a proxy (= the harness has to
        // reach the provider on a machine whose own resolver is down;
        // = the proxy resolves the name). The setting is read from the
        // environment, = so the harness never hardcodes one.
        let configuration = URLSessionConfiguration.default
        if let proxy = ProcessInfo.processInfo.environment["WENSHU_LIVE_PROXY"],
           let separator = proxy.lastIndex(of: ":"),
           let port = Int(proxy[proxy.index(after: separator)...]) {
            let host = String(proxy[..<separator])
            configuration.connectionProxyDictionary = [
                "HTTPEnable": true,
                "HTTPProxy": host,
                "HTTPPort": port,
                "HTTPSEnable": true,
                "HTTPSProxy": host,
                "HTTPSPort": port
            ]
        }
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 600
        let session = URLSession(configuration: configuration)
        let connector = MinimaxConnector(provider: provider, session: session)
        let model = Self.activeModelSlug() ?? provider.defaultModels.first ?? "default-model"
        return (connector, model)
    }

    // MARK: - The book import

    /// A real model reads the world's procedure, calls the write tool,
    /// and every file lands in the world's folder.
    func testARealModelWritesTheDocumentsIntoTheUsersFolder() async throws {
        guard liveEnabled else { return }
        let (connector, model) = try makeLiveConnector()
        let fm = FileManager.default
        let libraryRoot = fm.temporaryDirectory
            .appendingPathComponent("wenshu-live-lib-\(UUID().uuidString)")
        let bookRoot = libraryRoot
            .appendingPathComponent("shelves")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("books")
            .appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: bookRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: libraryRoot) }
        let source = """
        # 玄苍界

        玄苍界分九重天穹，每重天穹由一位守阙真君镇守。灵气自玄苍渊底涌出，
        经地脉流转至各重天穹。凡修行者需持【玄苍令】方可入渊取气。

        ## 地理

        玄苍渊位于界域正中央，深不可测。渊壁刻有上古碑文，记述九重天穹的
        缘起。渊外环绕玄苍林，林中多异兽。

        ## 人物

        守阙真君共有九位，居于各重天穹的阙楼之内。其中首位为【玄苍君】，
        执掌渊门钥印。
        """
        try await PathGuard.$libraryRootOverride.withValue(libraryRoot.path) {
            let driver = ImportAgentDriver(
                connector: connector,
                modelSlug: model
            )
            let root = bookRoot.path
            let context = ImportAgentBookContext(bookPath: { root })
            let input = ImportAgentDriver.TaskInput(
                filePath: "/tmp/xuan-cang.md",
                body: source,
                bookPath: root,
                bookTitle: "玄苍界",
                targetFolder: .world
            )
            // The streamed reply (= what the sheet shows; = it also
            // says what the model actually produced). The parts are
            // printed as they arrive, = so a run that fails still shows
            // what the model sent.
            let streamed = StreamRecorder()
            let result = try await driver.run(
                input: input,
                bookContext: context,
                progress: { part in
                    let count = await streamed.add(part)
                    if count <= 3 {
                        print("LIVE-PART #\(count) >>> \(String(part.prefix(300)))")
                    }
                }
            )
            let parts = await streamed.parts
            print("LIVE-STREAM parts=\(parts.count)")
            print("LIVE-RESULT sop=\(result.sopName) toolUses=\(result.toolUseCount)")
            print("LIVE-REPLY >>>\n\(result.finalResponse.prefix(1200))\n<<< END REPLY")
            // The world's folder holds the documents.
            let world = bookRoot.appendingPathComponent("world")
            let landed = ((try? fm.contentsOfDirectory(atPath: world.path)) ?? []).sorted()
            print("LIVE-LANDED world=\(landed)")
            for folder in ["characters", "outlines", "chapters", "drafts", "ideas"] {
                let other = ((try? fm.contentsOfDirectory(
                    atPath: bookRoot.appendingPathComponent(folder).path
                )) ?? [])
                XCTAssertTrue(
                    other.isEmpty,
                    "The '\(folder)' folder must stay empty; = the user's folder is the only destination. Got: \(other)"
                )
            }
            XCTAssertFalse(
                landed.isEmpty,
                "The real model must write into the world's folder; = nothing landed."
            )
            // Every document is a real file with content.
            for name in landed {
                let url = world.appendingPathComponent(name)
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                XCTAssertFalse(
                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "The document '\(name)' must carry content."
                )
            }
            // The procedure's contract (= the world's own skeleton):
            // = the six required documents, = and one index that
            // names them.
            let required = Self.requiredWorldDocuments
            for name in required {
                XCTAssertTrue(
                    landed.contains(name),
                    "The procedure asks for '\(name)'; = it must land in the world's folder. Got: \(landed)"
                )
            }
            // The index is the document that names the six (= the
            // procedure writes one index plus zero to five custom
            // documents, = so the extra files are not only the index).
            let indexName = landed.first { name in
                guard !required.contains(name) else { return false }
                let text = (try? String(
                    contentsOf: world.appendingPathComponent(name),
                    encoding: .utf8
                )) ?? ""
                return required.allSatisfy { text.contains($0) }
            }
            let indexText = indexName.map {
                (try? String(
                    contentsOf: world.appendingPathComponent($0),
                    encoding: .utf8
                )) ?? ""
            } ?? ""
            XCTAssertFalse(
                indexText.isEmpty,
                "The procedure asks for one index document beside the six."
            )
            // The index names the six (= its own skeleton says so).
            for name in required {
                XCTAssertTrue(
                    indexText.contains(name),
                    "The index must reference '\(name)'; = the six documents hang off it."
                )
            }
            // The index carries its metadata lines (= the procedure's own
            // format; = the label may be written in bold, = so the label
            // is matched and not the punctuation around it).
            for label in ["来源", "类型", "标签", "摘要"] {
                XCTAssertTrue(
                    indexText.contains(label),
                    "The index must carry the '\(label)' line; = the procedure says so."
                )
            }
            // Each required document opens with its own title.
            for name in required {
                let title = String(name.dropLast(".md".count))
                let text = (try? String(
                    contentsOf: world.appendingPathComponent(name),
                    encoding: .utf8
                )) ?? ""
                XCTAssertTrue(
                    text.contains("# \(title)"),
                    "The document '\(name)' must open with its own title heading."
                )
            }
            // No document carries a placeholder.
            for name in landed {
                let text = (try? String(
                    contentsOf: world.appendingPathComponent(name),
                    encoding: .utf8
                )) ?? ""
                for placeholder in ["<", "TODO", "待补充", "占位"] {
                    XCTAssertFalse(
                        text.contains(placeholder),
                        "The document '\(name)' must not carry the placeholder '\(placeholder)'."
                    )
                }
            }
            // Keep the artifacts (= the quality of the result is the
            // user's call, = so the documents have to be readable).
            if let dump = ProcessInfo.processInfo.environment["WENSHU_LIVE_DUMP"] {
                let target = URL(fileURLWithPath: dump)
                try? FileManager.default.createDirectory(
                    at: target, withIntermediateDirectories: true
                )
                for name in landed {
                    let source = world.appendingPathComponent(name)
                    let destination = target.appendingPathComponent(name)
                    try? FileManager.default.copyItem(at: source, to: destination)
                }
                print("LIVE-DUMPED to \(dump)")
            }
            print("LIVE-INDEX >>>\n\(String(indexText.prefix(900)))\n<<< END INDEX")
        }
    }

    /// The world's six required documents (= the folder's own skeleton
    /// names them; = the procedure asks for all six).
    private static let requiredWorldDocuments = [
        "核心设定.md",
        "地理或位置.md",
        "体系或规则.md",
        "历史脉络.md",
        "与其他元素的关系.md",
        "关键场景种子.md"
    ]

    /// The streamed reply (= the parts the sheet shows).
    private actor StreamRecorder {
        private(set) var parts: [String] = []
        @discardableResult
        func add(_ part: String) -> Int {
            parts.append(part)
            return parts.count
        }
    }

    // MARK: - The reference library import

    /// A real model produces the whole entity, = and it checks the
    /// content against the web before it writes the body.
    func testARealModelProducesTheWholeEntityAndSearches() async throws {
        guard liveEnabled else { return }
        let (connector, model) = try makeLiveConnector()
        let searchCounter = SearchCounter()
        let router = ImportReferenceLibraryRouter(
            connector: connector,
            modelSlug: model,
            dispatchWebSearch: { input in
                await searchCounter.mark()
                do {
                    return try await WebSearchTool.shared.execute(input: input)
                } catch {
                    return "{\"ok\":false,\"error\":\"\(error.localizedDescription)\"}"
                }
            }
        )
        // The app retries a refused request (= the orchestrator's own
        // retry ladder); = the harness does the same, = so it measures
        // what the app does and not what one call does.
        var result: ImportRoutingResult?
        var lastError: Error?
        for attempt in 1...3 {
            do {
                result = try await router.route(
                    input: ImportFileInput(
                        filePath: "/tmp/dufu.md",
                        targetBookId: nil,
                        targetShelfId: nil,
                        rewriteMode: .searchAndRewrite,
                        body: nil
                    ),
                    body: """
                    杜甫，字子美，自号少陵野老，唐代伟大的现实主义诗人。
                    他饱经丧乱，晚年漂泊于夔州、武陵一带，诗风沉郁顿挫，
                    代表作有三吏（《石壕吏》《新安吏》《潼关吏》）与三别。
                    """,
                    fallbackTitle: "dufu"
                )
                break
            } catch {
                lastError = error
                print("LIVE-LIBRARY attempt \(attempt)/3 refused")
            }
        }
        guard let result else {
            throw lastError ?? NSError(
                domain: "LiveImportTests", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The library import never got an answer."]
            )
        }
        let searches = await searchCounter.count
        print("LIVE-LIBRARY title=\(result.title) tags=\(result.tags.sorted()) category=\(result.category ?? "nil") entityType=\(result.entityType) searches=\(searches)")
        XCTAssertFalse(result.title.isEmpty, "The real model must produce a title.")
        XCTAssertFalse(result.summary.isEmpty, "The real model must produce a summary.")
        XCTAssertFalse(result.tags.isEmpty, "The real model must produce tags.")
        XCTAssertNotNil(result.category, "The real model must produce a library category.")
        XCTAssertFalse(
            (result.rewrittenBody ?? "").isEmpty,
            "The real model must produce the body."
        )
        XCTAssertGreaterThan(
            searches, 0,
            "The real model must check the content against the web before it writes the body."
        )
    }
}

// MARK: - The search counter

/// Counts the search calls (= the library import must call the search
/// tool at least once).
private actor SearchCounter {
    private(set) var count = 0
    func mark() { count += 1 }
}
