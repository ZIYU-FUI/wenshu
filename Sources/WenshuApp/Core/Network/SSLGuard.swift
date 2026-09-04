//
//  SSLGuard.swift · Wenshu · HERMES-INTERNAL-004 (2026-09-04)
//
//  1:1 port of hermes ssl_guard.py (= hermes-internal module #4, boss
//  2026-09-04 OOB 'A'). Pre-flight URL validation before any connector
//  (= Anthropic, OpenAI, Gemini, DeepSeek, Ollama, OpenRouter, MiniMax)
//  makes a network call.
//
//  Apple stack policy: URLSession's default cert validation is the strict
//  baseline (= system trust store + revocation + chain). SSLGuard never
//  overrides it implicitly; opt-in is explicit per call.
//

import Foundation

public enum SSLGuard {

    public enum Mode: Sendable, Equatable {
        /// Refuse to connect if the cert is invalid (= default).
        /// Uses URLSession defaults with no overrides.
        case strict

        /// Allow self-signed certificates (= localhost / Ollama).
        /// Caller still gets a URL back; the actual TLS handshake trust
        /// decision is owned by URLSession via custom delegate at the
        /// call site (= guard only validates the URL shape).
        case allowSelfSigned

        /// Explicit bypass for testing. Only use in test code.
        case bypass
    }

    /// Validate the URL shape and trust policy before issuing a connector
    /// call. Returns `.success(URL)` when the URL is OK to use; otherwise
    /// `.failure(SSLGuardError)`.
    public static func validate(url: URL, mode: Mode) -> Result<URL, SSLGuardError> {
        guard let scheme = url.scheme?.lowercased() else {
            return .failure(.insecureURL)
        }
        let isHTTPS = (scheme == "https")
        let isHTTP = (scheme == "http")
        let isLocalhost = Self.isLocalhost(url)

        // Insecure schemes:
        //   - strict: refuse everything except https
        //   - allowSelfSigned: allow http + https, refuse nothing
        //   - bypass: allow anything
        switch mode {
        case .strict:
            guard isHTTPS else { return .failure(.insecureURL) }
            return .success(url)
        case .allowSelfSigned:
            guard isHTTPS || isHTTP else { return .failure(.insecureURL) }
            if isHTTP && !isLocalhost {
                // http:// is only acceptable for localhost / Ollama.
                return .failure(.insecureURL)
            }
            return .success(url)
        case .bypass:
            return .success(url)
        }
    }

    /// Quick hostname check for localhost / loopback addresses (= Ollama
    /// default + local development). Matches ``localhost``, ``127.0.0.1``,
    /// ``::1``, and the special ``*.localhost`` suffix.
    private static func isLocalhost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return true
        }
        if host.hasSuffix(".localhost") {
            return true
        }
        return false
    }
}

public enum SSLGuardError: Error, Sendable, Equatable {
    /// http:// in strict mode, or any non-http(s) scheme.
    case insecureURL
    /// Self-signed certificate encountered (= call site must override).
    case selfSignedCert
    /// Cert chain could not be validated.
    case invalidCertChain
}