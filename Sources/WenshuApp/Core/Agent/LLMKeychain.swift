//
//  LLMKeychain.swift · Wenshu · v0.21 ticket 03 (LLM Keychain 集成, 老板 2026-08-21 拍)
//
//  CLAUDE.md L42 项目基线: LLM key 存 macOS Keychain, 不入文件 / log / commit.
//  Apple Security framework 真值 (keychain_services 真值).
//

import Foundation
import Security

public enum LLMKeychainError: Error, LocalizedError {
    case keychainStatus(OSStatus)
    case invalidKeyFormat

    public var errorDescription: String? {
        switch self {
        case .keychainStatus(let status):
            return "Keychain 操作失败 (status=\(status))"
        case .invalidKeyFormat:
            return "LLM key 格式无效"
        }
    }
}

/// LLMKeychain: Apple Security framework keychain 真值 (macOS Keychain)。
/// kSecClassGenericPassword + kSecAttrService="com.wenshu.app.minimax"。
/// v0.21 ticket 03 (LLM Keychain 集成)。
public actor LLMKeychain {
    public static let service = "com.wenshu.app.minimax"
    public static let account = "minimax.cn.api.key"

    public static let shared = LLMKeychain()

    private init() {}

    /// sync wrapper: 在 init 等 sync context 读 Keychain
    public static func loadKeySync() -> String? {
        ProviderKeychain.loadKeySync(for: .minimaxCn)
    }

    /// 保存 LLM key 到 macOS Keychain (替换已存在)
    public func saveKey(_ key: String) throws {
        guard !key.isEmpty else {
            throw LLMKeychainError.invalidKeyFormat
        }
        let keyData = Data(key.utf8)
        // 先删除旧 key (避免 errSecDuplicateItem)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 保存新 key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw LLMKeychainError.keychainStatus(status)
        }
    }

    /// 从 macOS Keychain 加载 LLM key, 不存在返 nil
    public func loadKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw LLMKeychainError.keychainStatus(status)
        }
        guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            throw LLMKeychainError.invalidKeyFormat
        }
        return key
    }

    /// 从 macOS Keychain 删除 LLM key
    public func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LLMKeychainError.keychainStatus(status)
        }
    }
}