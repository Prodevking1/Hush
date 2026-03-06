import Foundation
import Security

/// Simple helper for reading/writing data in the macOS Keychain.
enum KeychainHelper {
    private static let serviceName = "com.hush.app"

    /// Save data to the Keychain for a given key.
    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Log.error("Keychain save failed for '\(key)': \(status)")
        }
        return status == errSecSuccess
    }

    /// Read data from the Keychain for a given key.
    static func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    /// Delete a Keychain item for a given key.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Convenience

    /// Save a string value.
    @discardableResult
    static func saveString(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    /// Read a string value.
    static func readString(key: String) -> String? {
        guard let data = read(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Save a Date value.
    @discardableResult
    static func saveDate(key: String, date: Date) -> Bool {
        let timestamp = String(date.timeIntervalSince1970)
        return saveString(key: key, value: timestamp)
    }

    /// Read a Date value.
    static func readDate(key: String) -> Date? {
        guard let str = readString(key: key),
              let interval = TimeInterval(str) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}
