//
//  HubSpotTokenStore.swift
//  SCOTSMAN-FM
//
//  Created by Ian Miller on 1/7/26.
//

import Foundation
import Security

struct HubSpotTokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

enum HubSpotError: Error {
    case notConnected
    case httpError(data: Data)
}

final class HubSpotTokenStore {
    private let service = "com.salesdiver.hubspot"
    private let accessKey = "access_token"
    private let refreshKey = "refresh_token"
    private let expiresKey = "access_expires_at"

    var accessToken: String? { read(accessKey) }
    var refreshToken: String? { read(refreshKey) }

    var accessTokenExpiresAt: Date? {
        guard let s = read(expiresKey), let t = TimeInterval(s) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    var hasValidRefreshToken: Bool { refreshToken != nil }

    func save(_ token: HubSpotTokenResponse) {
        write(token.access_token, for: accessKey)
        if let refresh = token.refresh_token { write(refresh, for: refreshKey) }
        let exp = Date().addingTimeInterval(TimeInterval(token.expires_in))
        write(String(exp.timeIntervalSince1970), for: expiresKey)
    }

    func clear() {
        delete(accessKey)
        delete(refreshKey)
        delete(expiresKey)
    }

    private func write(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        let add: [String: Any] = query.merging([kSecValueData as String: data]) { $1 }
        SecItemAdd(add as CFDictionary, nil)
    }

    private func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
