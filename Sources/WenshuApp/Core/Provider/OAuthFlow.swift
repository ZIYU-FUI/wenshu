//
//  OAuthFlow.swift · Wenshu · v0.36 ticket 012 sub-step 4
//
//  OAuth 2.0 authorization code flow + refresh_token grant for LLM providers
//  (= thin adapter over URLSession + JSONSerialization; Apple Foundation
//  only per wenshu §11 hard rule).
//
//  Per ADR-0008 + §11.3 wenshu-side wins: this is a thin layer over the
//  existing ProviderKeychain (= where OAuth tokens are persisted). The
//  actual token storage = ProviderKeychainMetadata (= ticket 012
//  sub-step 1 + 2).
//
//  Per AGENTS.md §11 + §11.2: wenshu is a writing tool, not an LLM platform.
//  OAuth flows here are FOR the user's own credentials (= BYOK) — not for
//  reselling tokens. After the user completes OAuth once, the refresh
//  token rotates silently in the background. No user-visible OAuth screen
//  beyond the standard browser redirect.
//
//  v0.36 sub-step 4 of 5 for ticket 012.
//

import Foundation

/// OAuth 2.0 flow state for a single provider.
/// One instance per (user, provider) pair; lives across multiple
/// authorization attempts (= uses refresh token to silently rotate).
public actor OAuthFlow {

    public let provider: Provider
    public let authorizationEndpoint: URL
    public let tokenEndpoint: URL
    public let redirectURI: URL
    public let clientID: String
    public let scopes: [String]
    private let session: URLSession

    public init(
        provider: Provider,
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        redirectURI: URL,
        clientID: String,
        scopes: [String],
        session: URLSession = .shared
    ) {
        self.provider = provider
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.redirectURI = redirectURI
        self.clientID = clientID
        self.scopes = scopes
        self.session = session
    }

    /// Generate the user-facing authorization URL.
    /// User opens this URL in their browser, completes OAuth, gets
    /// redirected back to redirectURI with `code` query parameter.
    public func authorizationURL(state: String, codeChallenge: String) -> URL {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            // PKCE (RFC 7636) — prevents authorization code interception.
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components?.url ?? authorizationEndpoint
    }

    /// Exchange authorization code for access + refresh tokens.
    /// Returns ProviderKeychainMetadata (= persisted by caller via
    /// ProviderKeychain.saveMetadata).
    public func exchangeCodeForTokens(
        code: String,
        codeVerifier: String
    ) async throws -> ProviderKeychainMetadata {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI.absoluteString)",
            "client_id=\(clientID)",
            "code_verifier=\(codeVerifier)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw OAuthError.httpStatus(httpResponse.statusCode)
        }
        return try parseTokenResponse(data)
    }

    /// Use refresh token to silently rotate access token (= happens in
    /// background after access token expires; user does not see this).
    public func refreshTokens(refreshToken: String) async throws -> ProviderKeychainMetadata {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(clientID)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw OAuthError.httpStatus(httpResponse.statusCode)
        }
        return try parseTokenResponse(data)
    }

    // MARK: - Private helpers

    private func parseTokenResponse(_ data: Data) throws -> ProviderKeychainMetadata {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthError.invalidJSON
        }
        let accessToken = json["access_token"] as? String
        let refreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? Double
        let expiresAt = expiresIn.map { Date(timeIntervalSinceNow: $0) }
        let scope = json["scope"] as? String
        let scopes = scope?.split(separator: " ").map(String.init) ?? []

        return ProviderKeychainMetadata(
            expiresAt: expiresAt,
            oauthRefreshToken: refreshToken,
            oauthAccessToken: accessToken,
            oauthScopes: scopes,
            rotatedAt: Date()
        )
    }

    // MARK: - PKCE helpers (= RFC 7636)

    /// Generate a cryptographically-random PKCE code_verifier (= 43-128 chars).
    public static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    /// Compute PKCE code_challenge from code_verifier (= SHA256 + base64url).
    public static func codeChallenge(for verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { buffer in
            CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64URLEncodedString()
    }
}

/// OAuth-specific errors (= separate from LLMConnectorError for clarity).
public enum OAuthError: Error, LocalizedError {
    case invalidResponse
    case invalidJSON
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
            case .invalidResponse: return "OAuth server returned invalid response"
            case .invalidJSON: return "OAuth server returned malformed JSON"
            case .httpStatus(let code): return "OAuth server returned HTTP \(code)"
        }
    }
}

// MARK: - Data base64url helper (= RFC 4648 §5)

extension Data {
    /// Base64 URL-safe encoding (= no padding, + → -, / → _).
    fileprivate func base64URLEncodedString() -> String {
        var base64 = self.base64EncodedString()
        base64 = base64.replacingOccurrences(of: "+", with: "-")
        base64 = base64.replacingOccurrences(of: "/", with: "_")
        base64 = base64.replacingOccurrences(of: "=", with: "")
        return base64
    }
}

// SHA256 import (= Apple CommonCrypto; pure C, no external dep)
import CommonCrypto