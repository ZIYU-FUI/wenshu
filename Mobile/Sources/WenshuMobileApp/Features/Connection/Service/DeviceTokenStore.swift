import Foundation
import Security

/// Where the device token the Mac returns is kept.
///
/// The token is a credential, so it lives in the Keychain and never in
/// UserDefaults: a preference file is a plain plist that every process
/// on the device can read.
struct DeviceTokenStore: Sendable {
    private let service: String
    private let account: String

    init(service: String = "com.wenshu.mobile.device-token", account: String = "device-token") {
        self.service = service
        self.account = account
    }

    /// Keep the token the Mac returned, replacing the one before it.
    func save(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(
                baseQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw DeviceTokenStoreError.unexpectedStatus(updateStatus)
            }
        default:
            throw DeviceTokenStoreError.unexpectedStatus(status)
        }
    }

    /// The token from the last pairing, if this device is still paired.
    func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else {
            return nil
        }
        guard let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Forget the token: this device is not paired any more.
    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// Why the Keychain refused the token.
enum DeviceTokenStoreError: Error, Sendable {
    case unexpectedStatus(OSStatus)
}
