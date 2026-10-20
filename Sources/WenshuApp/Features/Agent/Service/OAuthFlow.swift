// OAuthFlow.swift
//
// OAuth 2.0 authorization code flow + `refresh_token` grant for LLM
// providers (= thin adapter over `URLSession` + `JSONSerialization`;
// Apple Foundation only).
//
// Per ADR-0008 + §11.3 wenshu-side wins: this is a thin layer over
// the existing `ProviderKeychain` (= where OAuth tokens are
// persisted). The actual token storage = `ProviderKeychainMetadata`
// (= the canonical persistence layer).
//
// Per AGENTS.md §11 + §11.2: wenshu is a writing tool, not an LLM
// platform. OAuth flows here are FOR the user's own credentials
// (= BYOK) — not for reselling tokens. After the user completes
// OAuth once, the refresh token rotates silently in the background.
// No user-visible OAuth screen beyond the standard browser redirect.

import Foundation

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
import WenshuAgent

