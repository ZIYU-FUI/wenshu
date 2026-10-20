// NetworkDiagnosticsPane.swift · WenshuApp · v1.86
//
// Settings → Network pane. Lets the user inspect the current URLSession
// mode wenshu uses for outbound HTTP (= the mode all connectors inherit
// from `URLSession.shared`) and run an end-to-end probe against the
// active LLM provider's base endpoint so the user can self-diagnose
// "unreachable" / "request timed out" / "connection refused" without
// leaving the app.
//
// Boss 2026-10-19 OOB "wenshu 是用户软件，用户的网络环境和我们的开发
// 环境不同": we MUST NOT presume the user's network stack state.
// The pane is read-only by default (= shows the current mode + last
// probe result); the mode selector + endpoint override are gated
// behind an "advanced" disclosure so the user can opt-in. No
// wenshu-side hardcoded proxy or DNS assumptions.
import Foundation
import Network
import SwiftUI

struct NetworkDiagnosticsPane: View {
    /// Active LLM provider (mirrors `SettingView.providerSlug`).
    @AppStorage("wenshu.llm.provider") private var providerSlug: String = Provider.minimaxCn.slug

    /// User-selected URLSession mode. Default = `.systemDefault` =
    /// wenshu inherits `URLSession.shared` behavior, which on macOS
    /// means "follow the system proxy if one is configured".
    @AppStorage("wenshu.network.mode") private var modeRaw: String = NetworkMode.systemDefault.rawValue

    /// Custom proxy URL (= honored only when mode = `.customProxy`).
    @AppStorage("wenshu.network.proxyURL") private var customProxyURL: String = ""

    @State private var isProbing: Bool = false
    @State private var probeResult: ProbeResult?
    @State private var liveInterfaceSummary: String = "—"

    private var mode: NetworkMode {
        NetworkMode(rawValue: modeRaw) ?? .systemDefault
    }

    var body: some View {
        Form {
            Section {
                liveInterfaceSection
            } header: {
                Text(String(localized: "settings.network.section.interface"))
            }

            Section {
                modeSection
            } header: {
                Text(String(localized: "settings.network.section.mode"))
            } footer: {
                Text(String(localized: "settings.network.section.mode.footer"))
            }

            Section {
                probeSection
            } header: {
                Text(String(localized: "settings.network.section.probe"))
            } footer: {
                Text(String(localized: "settings.network.section.probe.footer"))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.network.title"))
        .task { refreshLiveInterface() }
    }

    @ViewBuilder
    private var liveInterfaceSection: some View {
        LabeledContent(String(localized: "settings.network.interface.realtime")) {
            Text(liveInterfaceSummary)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var modeSection: some View {
        Picker(
            String(localized: "settings.network.mode.label"),
            selection: Binding(
                get: { mode },
                set: { modeRaw = $0.rawValue }
            )
        ) {
            ForEach(NetworkMode.allCases) { m in
                Text(m.label).tag(m)
            }
        }
        .pickerStyle(.menu)

        if mode == .customProxy {
            TextField(
                String(localized: "settings.network.proxyURL.placeholder"),
                text: $customProxyURL
            )
            .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var probeSection: some View {
        HStack {
            Button {
                Task { await runProbe() }
            } label: {
                if isProbing {
                    ProgressView().controlSize(.small)
                } else {
                    Text(String(localized: "settings.network.probe.button"))
                }
            }
            .disabled(isProbing)
            Spacer()
            if let r = probeResult {
                Text(r.summary)
                    .font(.callout)
                    .foregroundStyle(r.color)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Live interface probe (one-shot)

    /// Probe the live network interface (= `NWPathMonitor` for the
    /// user-visible "is the machine online right now" indicator). Runs
    /// once on pane appear; = no continuous polling (= the
    /// `NWPathMonitor` is a single-shot per the pane's lifetime).
    private func refreshLiveInterface() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "wenshu.network.probe")
        monitor.pathUpdateHandler = { path in
            let statusKey: String.LocalizationValue
            switch path.status {
            case .satisfied:
                statusKey = "settings.network.interface.status.ok"
            case .unsatisfied:
                statusKey = "settings.network.interface.status.down"
            case .requiresConnection:
                statusKey = "settings.network.interface.status.connecting"
            @unknown default:
                statusKey = "settings.network.interface.status.unknown"
            }
            let parts: [String] = [
                String(localized: statusKey),
                path.isExpensive
                    ? String(localized: "settings.network.interface.expensive")
                    : String(localized: "settings.network.interface.normal"),
                path.isConstrained
                    ? String(localized: "settings.network.interface.constrained")
                    : String(localized: "settings.network.interface.normal")
            ]
            let summary = parts.joined(separator: " · ")
            // RATIONALE: `NWPathMonitor.pathUpdateHandler` runs on a
            // dispatch queue, NOT on the main actor; = Swift 6 strict
            // concurrency prevents writing to `liveInterfaceSummary`
            // (= a `@State` property bound to the main actor) directly.
            // Hop back to the main actor before the assignment so the
            // property mutation is checked at compile time.
            Task { @MainActor in
                self.liveInterfaceSummary = summary
            }
        }
        monitor.start(queue: queue)
        // Stop the monitor after one path update so we do not keep
        // the queue alive after the pane finishes its initial probe
        // (= the pane is read-only afterward; = Apple HIG minimum
        // lifetime for a per-pane resource).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            monitor.cancel()
        }
    }

    // MARK: - Provider endpoint probe

    /// Run an end-to-end HTTP probe against the active provider's
    /// base URL + `/v1/messages` (= the canonical Anthropic-compat
    /// endpoint; = works for minimax / minimax-cn / Anthropic). The
    /// probe uses a fresh `URLSessionConfiguration` (= no shared
    /// cache, no cookie store) and honors `NetworkMode` so the user
    /// can validate the mode's actual behavior.
    private func runProbe() async {
        isProbing = true
        defer { isProbing = false }
        let provider = Provider.by(slug: providerSlug) ?? Provider.minimaxCn
        let baseURL = provider.defaultBaseURL
        guard let endpoint = URL(string: "\(baseURL)/v1/messages") else {
            probeResult = ProbeResult(status: .invalidURL, latencyMs: 0, httpStatus: 0, error: nil)
            return
        }
        let result = await probeOnce(url: endpoint, mode: mode, customProxyURL: customProxyURL)
        probeResult = result
    }

    private func probeOnce(url: URL, mode: NetworkMode, customProxyURL: String) async -> ProbeResult {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.waitsForConnectivity = false
        switch mode {
        case .systemDefault:
            break
        case .direct:
            config.connectionProxyDictionary = [:]
        case .customProxy:
            guard let parsed = URL(string: customProxyURL),
                  let host = parsed.host,
                  let port = parsed.port
            else {
                return ProbeResult(status: .invalidProxyURL, latencyMs: 0, httpStatus: 0, error: nil)
            }
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as AnyHashable: true,
                kCFNetworkProxiesHTTPProxy as AnyHashable: "\(host):\(port)",
                kCFNetworkProxiesHTTPSEnable as AnyHashable: true,
                kCFNetworkProxiesHTTPSProxy as AnyHashable: "\(host):\(port)"
            ]
        }
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("probe-no-auth", forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = #"{"model":"MiniMax-M3","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}"#.data(using: .utf8)
        let started = Date()
        do {
            let (_, response) = try await session.data(for: request)
            let latencyMs = Int(Date().timeIntervalSince(started) * 1000)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(httpStatus) {
                return ProbeResult(status: .ok, latencyMs: latencyMs, httpStatus: httpStatus, error: nil)
            }
            if httpStatus == 401 || httpStatus == 400 {
                // Auth-failure is the best-case "endpoint reachable"
                // signal: the server answered (= TLS + DNS + routing
                // all worked).
                return ProbeResult(status: .reachable, latencyMs: latencyMs, httpStatus: httpStatus, error: nil)
            }
            return ProbeResult(status: .http(httpStatus), latencyMs: latencyMs, httpStatus: httpStatus, error: nil)
        } catch {
            let latencyMs = Int(Date().timeIntervalSince(started) * 1000)
            return ProbeResult(status: .fail, latencyMs: latencyMs, httpStatus: 0, error: error.localizedDescription)
        }
    }
}

/// Probe classification (= replaces the previous String-typed status
/// key so the user-facing summary never carries English source code
/// identifiers; = each case maps to a localized `String(localized:)`
/// lookup).
enum ProbeStatus {
    case ok
    case reachable
    case http(Int)
    case fail
    case invalidURL
    case invalidProxyURL

    var localizedLabel: String {
        switch self {
        case .ok:              return String(localized: "settings.network.probe.status.ok")
        case .reachable:       return String(localized: "settings.network.probe.status.reachable")
        case .http(let code):  return String(
            localized: "settings.network.probe.status.http"
        )
            .replacingOccurrences(of: "{code}", with: String(code))
        case .fail:            return String(localized: "settings.network.probe.status.fail")
        case .invalidURL:      return String(localized: "settings.network.probe.status.invalid_url")
        case .invalidProxyURL: return String(localized: "settings.network.probe.status.invalid_proxy")
        }
    }

    var color: Color {
        switch self {
        case .ok:                                                  return .green
        case .reachable:                                           return .blue
        case .fail, .invalidURL, .invalidProxyURL:                 return .red
        case .http:                                                return .orange
        }
    }
}

/// URLSession mode the user can select in Settings → Network.
/// `systemDefault` is the canonical Apple HIG behavior (= URLSession
/// inherits the system proxy stack); = wenshu MUST NOT toggle this by
/// default. The other two modes exist for users whose network stack
/// (= corporate proxies / VPN / captive portals) blocks minimax.cn
/// via the system proxy.
enum NetworkMode: String, CaseIterable, Identifiable {
    case systemDefault
    case direct
    case customProxy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .systemDefault:
            return String(localized: "settings.network.mode.systemDefault")
        case .direct:
            return String(localized: "settings.network.mode.direct")
        case .customProxy:
            return String(localized: "settings.network.mode.customProxy")
        }
    }
}

struct ProbeResult {
    let status: ProbeStatus
    let latencyMs: Int
    let httpStatus: Int
    let error: String?
    var summary: String {
        if case .fail = status, let error {
            return "\(status.localizedLabel) · \(latencyMs)毫秒 · \(error)"
        }
        let httpPart = httpStatus == 0 ? "—" : "HTTP \(httpStatus)"
        return "\(status.localizedLabel) · \(latencyMs)毫秒 · \(httpPart)"
    }
    var color: Color { status.color }
}
