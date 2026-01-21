//
//  HubSpotAuthManager.swift
//  SCOTSMAN-FM
//
//  Created by Ian Miller on 1/7/26.
//

import Foundation
import AuthenticationServices
import CryptoKit
import OSLog
import UIKit

struct HubSpotCompanyDetails {
    let id: String
    let name: String
    let address1: String?
    let address2: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let lifecycleStage: String?
}

@MainActor
final class HubSpotAuthManager: NSObject, ObservableObject {
    /// Singleton used as an app-wide EnvironmentObject.
    static let shared = HubSpotAuthManager()

    // MARK: - Configure these
    private let clientId = "679b7eef-9591-46e0-abbf-ff79166e830e"

    // DEV / POC ONLY — do NOT ship this in production
    private let clientSecret = "908c5f0e-3a83-47f0-8bd5-cbd2b2ed7a88"

    private let httpsRedirectUri = "https://www.salesdiver.net/hubspot/oauth/callback"
    private let appCallbackScheme = "salesdiver"
    private let appCallbackHost = "hubspot"

    private let scopes = [
        "crm.objects.deals.read",
        "crm.objects.deals.write",
        "crm.objects.companies.read",
        "crm.objects.contacts.read"
    ]

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var lastSyncAt: Date? = nil
    @Published private(set) var lastAuthorizeURL: String = ""

    private let logger = Logger(subsystem: "com.salesdiver.scotsman-fm", category: "HubSpot")

    var lastSyncDescription: String {
        guard let lastSyncAt else { return "Last sync: never" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return "Last sync: \(f.string(from: lastSyncAt))"
    }

    private var currentState: String?
    private var codeVerifier: String?
    private var authSession: ASWebAuthenticationSession?

    private let tokenStore = HubSpotTokenStore()

    override private init() {
        super.init()
        refreshConnectionState()
    }

    /// Re-reads persisted tokens and refreshes `isConnected`.
    func refreshConnectionState() {
        // Consider connected if we have either refresh OR access token stored.
        let connected = (tokenStore.refreshToken != nil) || (tokenStore.accessToken != nil)
        self.isConnected = connected
    }

    func startOAuth() {
        let verifier = Self.randomURLSafeString(length: 64)
        let challenge = Self.pkceChallenge(from: verifier)
        let state = Self.randomURLSafeString(length: 32)

        self.codeVerifier = verifier
        self.currentState = state

        let scopeString = scopes.joined(separator: " ")

        var comps = URLComponents(string: "https://app.hubspot.com/oauth/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: httpsRedirectUri),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scopeString),
            .init(name: "state", value: state),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = comps.url else { return }
        self.lastAuthorizeURL = authURL.absoluteString
        logger.info("HubSpot authorize URL: \(self.lastAuthorizeURL, privacy: .public)")

        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: appCallbackScheme) { [weak self] callbackURL, error in
            if let error {
                print("HubSpot OAuth cancelled/failed: \(error)")
                return
            }
            guard let callbackURL else { return }
            self?.handleOpenURL(callbackURL)
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }

    func handleOpenURL(_ url: URL) {
        guard url.scheme == appCallbackScheme else { return }
        guard url.host == appCallbackHost else { return }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value
        let state = comps?.queryItems?.first(where: { $0.name == "state" })?.value

        guard let code, let state, state == currentState else {
            print("HubSpot OAuth callback missing code/state or state mismatch")
            return
        }
        guard let verifier = codeVerifier else {
            print("Missing PKCE code_verifier")
            return
        }

        Task {
            do {
                try await exchangeCodeForTokens(code: code, codeVerifier: verifier)
                await MainActor.run { self.refreshConnectionState() }
            } catch {
                print("Token exchange failed: \(error)")
            }
        }
    }

    func disconnect() {
        tokenStore.clear()
        isConnected = false
    }

    // MARK: - Deal search

    func searchDeals(query: String, limit: Int) async throws -> [HubSpotDealSummary] {
        let accessToken = try await ensureAccessToken()
        let client = HubSpotAPIClient(accessToken: accessToken)
        let deals = try await client.searchDeals(query: query, limit: limit)

        return deals.map { deal in
            let name = deal.properties?["dealname"]?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return HubSpotDealSummary(id: deal.id, name: (name?.isEmpty == false) ? name! : "(Unnamed deal)")
        }
    }
    
    public func fetchDealSummaries(limit: Int) async throws -> [HubSpotDealSummary] {
        let accessToken = try await ensureAccessToken()
        let client = HubSpotAPIClient(accessToken: accessToken)
        let deals = try await client.listDeals(limit: limit)

        return deals.map { deal in
            let name = deal.properties?["dealname"]?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return HubSpotDealSummary(id: deal.id, name: (name?.isEmpty == false) ? name! : "(Unnamed deal)")
        }
    }
    
    public func fetchCompanyDetailsForDeal(dealID: String) async throws -> HubSpotCompanyDetails? {
        let accessToken = try await ensureAccessToken()
        
        // 1) Get associated company IDs for the deal
        let assocURLString = "https://api.hubapi.com/crm/v4/objects/deals/\(dealID)/associations/companies"
        let assocData = try await getData(from: assocURLString, accessToken: accessToken)
        
        struct AssociationsResponse: Decodable {
            struct Result: Decodable {
                let toObjectId: String
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    // HubSpot may return numeric IDs; support both number and string
                    if let intValue = try? container.decode(Int64.self, forKey: .toObjectId) {
                        self.toObjectId = String(intValue)
                    } else if let stringValue = try? container.decode(String.self, forKey: .toObjectId) {
                        self.toObjectId = stringValue
                    } else {
                        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int64 for toObjectId"))
                    }
                }
                private enum CodingKeys: String, CodingKey { case toObjectId }
            }
            let results: [Result]
        }
        
        let associations = try JSONDecoder().decode(AssociationsResponse.self, from: assocData)
        let companyID = associations.results.first?.toObjectId
        logger.info("HubSpot associations for deal \(dealID, privacy: .public): fetched companyID=\(companyID ?? "nil", privacy: .public)")
        guard let firstCompanyId = companyID else {
            return nil
        }
        
        // 2) Fetch company record details
        let companyURLString = "https://api.hubapi.com/crm/v3/objects/companies/\(firstCompanyId)?properties=name,address,address2,city,state,zip,lifecyclestage"
        let companyData = try await getData(from: companyURLString, accessToken: accessToken)
        
        struct CompanyResponse: Decodable {
            struct Properties: Decodable {
                let name: String?
                let address: String?
                let address2: String?
                let city: String?
                let state: String?
                let zip: String?
                let lifecyclestage: String?
            }
            let id: String
            let properties: Properties
        }
        
        let company = try JSONDecoder().decode(CompanyResponse.self, from: companyData)
        let props = company.properties
        
        let name = (props.name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false) ? props.name! : "(Unnamed company)"
        logger.info("HubSpot company details: name=\(name, privacy: .public), city=\(props.city ?? "", privacy: .public), state=\(props.state ?? "", privacy: .public), zip=\(props.zip ?? "", privacy: .public), lifecyclestage=\(props.lifecyclestage ?? "", privacy: .public)")
        
        return HubSpotCompanyDetails(
            id: company.id,
            name: name,
            address1: props.address,
            address2: props.address2,
            city: props.city,
            state: props.state,
            postalCode: props.zip,
            lifecycleStage: props.lifecyclestage
        )
    }
    
    public func searchCompanyDetailsByName(name: String) async throws -> HubSpotCompanyDetails? {
        let accessToken = try await ensureAccessToken()

        let urlString = "https://api.hubapi.com/crm/v3/objects/companies/search"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "filterGroups": [[
                "filters": [[
                    "propertyName": "name",
                    "operator": "CONTAINS_TOKEN",
                    "value": name
                ]]
            ]],
            "properties": ["name","address","address2","city","state","zip"],
            "limit": 1
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HubSpotError.httpError(data: data)
        }

        struct SearchResponse: Decodable {
            struct Result: Decodable {
                let id: String
                struct Properties: Decodable {
                    let name: String?
                    let address: String?
                    let address2: String?
                    let city: String?
                    let state: String?
                    let zip: String?
                }
                let properties: Properties
            }
            let results: [Result]
        }

        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard let firstResult = response.results.first else {
            logger.info("HubSpot company search by name \"\(name, privacy: .public)\": no match found")
            return nil
        }

        let props = firstResult.properties
        let trimmedName = (props.name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false) ? props.name! : "(Unnamed company)"
        logger.info("HubSpot company search by name \"\(name, privacy: .public)\": matched company name \"\(trimmedName, privacy: .public)\"")

        return HubSpotCompanyDetails(
            id: firstResult.id,
            name: trimmedName,
            address1: props.address,
            address2: props.address2,
            city: props.city,
            state: props.state,
            postalCode: props.zip,
            lifecycleStage: nil
        )
    }

    func importDealsPlaceholder(dealIDs: [String]) async throws {
        await MainActor.run { self.lastSyncAt = Date() }
        logger.info("HubSpot placeholder import for deal count: \(dealIDs.count, privacy: .public)")
    }
    
    public func syncDealsNow() async {
        lastSyncAt = Date()
        logger.info("HubSpot syncDealsNow called, updated lastSyncAt to current date")
    }

    // MARK: - OAuth token exchange/refresh

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws {
        var req = URLRequest(url: URL(string: "https://api.hubapi.com/oauth/v1/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": httpsRedirectUri,
            "code": code,
            "code_verifier": codeVerifier
        ]
        req.httpBody = Self.formURLEncoded(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HubSpotError.httpError(data: data)
        }

        let token = try JSONDecoder().decode(HubSpotTokenResponse.self, from: data)
        tokenStore.save(token)
    }

    private func refreshTokens(refreshToken: String) async throws {
        var req = URLRequest(url: URL(string: "https://api.hubapi.com/oauth/v1/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken
        ]
        req.httpBody = Self.formURLEncoded(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HubSpotError.httpError(data: data)
        }

        let token = try JSONDecoder().decode(HubSpotTokenResponse.self, from: data)
        tokenStore.save(token)
    }

    private func ensureAccessToken() async throws -> String {
        if let access = tokenStore.accessToken,
           let exp = tokenStore.accessTokenExpiresAt,
           exp > Date().addingTimeInterval(60) {
            return access
        }
        guard let refresh = tokenStore.refreshToken else {
            throw HubSpotError.notConnected
        }
        try await refreshTokens(refreshToken: refresh)
        guard let access = tokenStore.accessToken else {
            throw HubSpotError.notConnected
        }
        return access
    }
    
    private func getData(from urlString: String, accessToken: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HubSpotError.httpError(data: data)
        }
        return data
    }
    
    private func authorizedPostJSON<T: Encodable>(url: URL, accessToken: String, body: T) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HubSpotError.httpError(data: data)
        }
        return data
    }

    // MARK: - Helpers

    private static func randomURLSafeString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    private static func pkceChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    private static func formURLEncoded(_ dict: [String: String]) -> Data {
        let str = dict
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
            }
            .joined(separator: "&")
        return Data(str.utf8)
    }
}

extension HubSpotAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-" )
            .replacingOccurrences(of: "/", with: "_" )
            .replacingOccurrences(of: "=", with: "" )
    }
}

