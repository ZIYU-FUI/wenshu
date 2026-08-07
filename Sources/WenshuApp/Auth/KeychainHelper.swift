import Foundation
import Security

public enum KeychainError: Error, Sendable {
    case unexpectedStatus(OSStatus)
}

public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()
    private let service = "com.wenshu.llm"
    private let account = "minimax-api-key"

    private init() {}

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    public func saveKey(_ key: String) throws {
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data(key.utf8)] as CFDictionary)
            guard update == errSecSuccess else { throw KeychainError.unexpectedStatus(update) }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func loadKey() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func deleteKey() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
