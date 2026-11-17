import Foundation
import Security

protocol TokenStore: Sendable {
    func load() -> String?
    func save(_ token: String) throws
    func delete()
}

struct KeychainStore: TokenStore {
    var service = "com.nokobar.token"
    var account = "noko-personal-access-token"

    struct KeychainError: Error { let status: OSStatus }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> String? {
        var q = baseQuery
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) throws {
        delete()
        var q = baseQuery
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
