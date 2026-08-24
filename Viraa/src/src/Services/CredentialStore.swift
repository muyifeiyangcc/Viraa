import Foundation
import Security
import CryptoKit

final class CredentialStore {
    static let shared = CredentialStore()
    private let service = "app.myfy.test.viraa.credentials"
    private init() {}

    func set(password: String, for userID: String) -> Bool {
        let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let digest = hash(password: password, salt: salt)
        let payload = salt + digest
        delete(userID: userID)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: userID,
                                    kSecValueData as String: payload,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func verify(password: String, for userID: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: userID,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let payload = item as? Data, payload.count == 64 else { return false }
        let salt = payload.prefix(32), expected = payload.suffix(32)
        return Data(hash(password: password, salt: Data(salt))) == Data(expected)
    }

    func contains(userID: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: userID,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func delete(userID: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: userID]
        SecItemDelete(query as CFDictionary)
    }

    private func hash(password: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(password.utf8)))
    }
}
