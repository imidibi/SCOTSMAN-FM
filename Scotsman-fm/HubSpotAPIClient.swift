//
//  HubSpotAPIClient.swift
//  SCOTSMAN-FM
//
//  Created by Ian Miller on 1/7/26.
//
import Foundation

struct HubSpotDealListResponse: Codable {
    let results: [HubSpotDeal]
}

struct HubSpotDeal: Codable, Hashable {
    let id: String
    let properties: [String: String]?
}

final class HubSpotAPIClient {
    private let accessToken: String

    init(accessToken: String) { self.accessToken = accessToken }

    func listDeals(limit: Int) async throws -> [HubSpotDeal] {
        var comps = URLComponents(string: "https://api.hubapi.com/crm/v3/objects/deals")!
        comps.queryItems = [.init(name: "limit", value: String(limit))]

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HubSpotError.httpError(data: data)
        }
        let decoded = try JSONDecoder().decode(HubSpotDealListResponse.self, from: data)
        return decoded.results
    }

    func searchDeals(query: String, limit: Int) async throws -> [HubSpotDeal] {
        let url = URL(string: "https://api.hubapi.com/crm/v3/objects/deals/search")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct SearchBody: Codable {
            let query: String
            let limit: Int
            let properties: [String]
        }

        let body = SearchBody(
            query: query,
            limit: limit,
            properties: ["dealname", "amount", "closedate", "dealstage"]
        )

        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HubSpotError.httpError(data: data)
        }

        let decoded = try JSONDecoder().decode(HubSpotDealListResponse.self, from: data)
        return decoded.results
    }
}
