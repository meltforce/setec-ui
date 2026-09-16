import Foundation
import Security

/// Generic-password items in the login keychain, scoped to this app's bundle
/// identifier as the service. Secrets never go to `UserDefaults`.
enum Keychain {
    static let service = Bundle.main.bundleIdentifier ?? "org.meltforce.app"

    enum Failure: LocalizedError {
        case status(OSStatus)
        case encoding

        var errorDescription: String? {
            switch self {
            case let .status(code):
                let message = SecCopyErrorMessageString(code, nil) as String? ?? "OSStatus \(code)"
                return "Keychain: \(message)"
            case .encoding:
                return "Keychain: value is not valid UTF-8"
            }
        }
    }

    static func read(key: String) throws -> String? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
                throw Failure.encoding
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw Failure.status(status)
        }
    }

    static func write(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { throw Failure.encoding }
        let query = baseQuery(key: key)
        let attributes: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            status = SecItemAdd(insert as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Failure.status(status) }
    }

    static func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.status(status) }
    }

    private static func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
