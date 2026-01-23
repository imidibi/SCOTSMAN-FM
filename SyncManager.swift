import Foundation
import CoreData

final class SyncManager {
    static let shared = SyncManager()

    private let context: NSManagedObjectContext

    private init(context: NSManagedObjectContext = CoreDataManager.shared.context) {
        self.context = context
    }

    // MARK: - Connectivity
    private func isHubSpotConnected(_ hubSpotAuth: HubSpotAuthManager) async -> Bool {
        return await MainActor.run { hubSpotAuth.isConnected }
    }

    // MARK: - Public API

    /// Call this on app startup to reconcile local data with HubSpot.
    /// The caller must pass an instance of HubSpotAuthManager that is already authenticated.
    func syncAllOnStartup(hubSpotAuth: HubSpotAuthManager) async {
        return
    }

    /// Call this after local changes are saved to push/pull the latest single opportunity.
    func syncOpportunity(_ opportunity: OpportunityEntity, hubSpotAuth: HubSpotAuthManager) async {
        guard await isHubSpotConnected(hubSpotAuth) else { return }
        guard let hubspotID = opportunity.value(forKey: "hubspotID") as? String, !hubspotID.isEmpty else {
            return
        }
        do {
            // Fetch remote deal details
            if let remote = try await hubSpotAuth.fetchDealDetails(dealID: hubspotID) {
                try await reconcile(opportunity: opportunity, withRemoteDeal: remote, hubSpotAuth: hubSpotAuth)
            }
        } catch {
            // print("Sync opportunity failed: \(error)")
        }
    }

    /// Call this after local changes are saved to push/pull the latest single company.
    func syncCompany(_ company: CompanyEntity, hubSpotAuth: HubSpotAuthManager) async {
        return
    }

    // MARK: - Bulk sync

    private func syncAllOpportunities(hubSpotAuth: HubSpotAuthManager) async {
        return
    }

    private func syncAllCompanies(hubSpotAuth: HubSpotAuthManager) async {
        return
    }

    // MARK: - Reconciliation

    private func reconcile(opportunity: OpportunityEntity, withRemoteDeal remote: [String: Any], hubSpotAuth: HubSpotAuthManager) async throws {
        let remoteLastModified = parseHubSpotLastModified(remote["hs_lastmodifieddate"] as? String)
        let localLastModified = opportunity.value(forKey: "lastModified") as? Date

        // Decide direction based on timestamps (default to pull if remote is newer or local is nil)
        let shouldPullFromRemote = (remoteLastModified ?? .distantFuture) > (localLastModified ?? .distantPast)

        if shouldPullFromRemote {
            // Pull: overwrite local with remote
            applyRemoteDeal(remote, to: opportunity)
            opportunity.setValue(remoteLastModified, forKey: "lastModified")
            saveContext()
        } else {
            // Push: update HubSpot with local fields
            // TODO: Implement hubSpotAuth.updateDeal(dealID:payload:) to push local changes upstream.
            // let payload = makeDealUpdatePayload(from: opportunity)
            // try await hubSpotAuth.updateDeal(dealID: opportunity.hubspotIDString, payload: payload)
        }
    }

    private func reconcile(company: CompanyEntity, withRemoteCompany remote: HubSpotCompanyDetails, hubSpotAuth: HubSpotAuthManager) async throws {
        let remoteLastModified: Date? = nil // TODO: Add lastModified to HubSpotCompanyDetails if available
        let localLastModified = company.value(forKey: "lastModified") as? Date

        let shouldPullFromRemote = (remoteLastModified ?? .distantFuture) > (localLastModified ?? .distantPast)

        if shouldPullFromRemote {
            applyRemoteCompany(remote, to: company)
            if let last = remoteLastModified { company.setValue(last, forKey: "lastModified") }
            saveContext()
        } else {
            // Push: update HubSpot with local company fields
            // TODO: Implement hubSpotAuth.updateCompany(companyID:payload:)
            // let payload = makeCompanyUpdatePayload(from: company)
            // try await hubSpotAuth.updateCompany(companyID: company.hubspotIDString, payload: payload)
        }
    }

    // MARK: - Apply remote to local

    private func applyRemoteDeal(_ remote: [String: Any], to opportunity: OpportunityEntity) {
        print("[Sync] Remote deal keys:", Array(remote.keys))
        print("[Sync] Top-level forecast_category =", remote["forecast_category"] ?? "nil")
        if let idAny = remote["id"], let idString = idAny as? String {
            opportunity.setValue(idString, forKey: "hubspotID")
        }
        if let props = remote["properties"] as? [String: Any] {
            print("[Sync] Deal properties keys:", Array(props.keys))
            print("[Sync] Deal properties.closedate =", props["closedate"] ?? "nil")
            print("[Sync] Deal properties.hs_forecast_category =", props["hs_forecast_category"] ?? "nil")

            if let name = props["dealname"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                opportunity.name = name
            }
            if let amountString = props["amount"] as? String {
                opportunity.estimatedValue = parseHubSpotAmount(amountString)
            } else if let amountStringTop = remote["amount"] as? String {
                opportunity.estimatedValue = parseHubSpotAmount(amountStringTop)
            }
            // Close date: prefer ISO 8601 parsing first, then numeric fallback
            if let closeAny = props["closedate"] {
                let parsedISO = parseISO8601Date(closeAny)
                let parsedEpoch = parseHubSpotCloseDateFlexible(closeAny)
                print("[Sync] Closedate parse results -> ISO:", parsedISO as Any, "Epoch:", parsedEpoch as Any)
                if let date = parsedISO ?? parsedEpoch {
                    opportunity.closeDate = date
                }
            } else if let closeAnyTop = remote["closedate"] {
                if let date = parseISO8601Date(closeAnyTop) ?? parseHubSpotCloseDateFlexible(closeAnyTop) {
                    opportunity.closeDate = date
                }
            }
        } else {
            // Fallback to existing top-level handling
            if let name = remote["dealname"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                opportunity.name = name
            }
            if let amountString = remote["amount"] as? String {
                opportunity.estimatedValue = parseHubSpotAmount(amountString)
            }
            print("[Sync] Top-level closedate =", remote["closedate"] ?? "nil")
            if let closeRaw = extractRawValue(from: remote, key: "closedate") {
                let parsedISO = parseISO8601Date(closeRaw)
                let parsedEpoch = parseHubSpotCloseDateFlexible(closeRaw)
                print("[Sync] Top-level closedate parse results -> ISO:", parsedISO as Any, "Epoch:", parsedEpoch as Any)
                if let closeDate = parsedISO ?? parsedEpoch {
                    opportunity.closeDate = closeDate
                }
            }
        }
        // Forecast category: prefer forecast_category (v3), fallback to hs_forecast_category
        if let props = remote["properties"] as? [String: Any] {
            if let fc = props["forecast_category"] as? String, let normalized = normalizeForecastCategory(fc) {
                opportunity.setValue(mapHubSpotForecastCategory(normalized), forKey: "forecastCategory")
            } else if let fcHS = props["hs_forecast_category"] as? String, let normalized = normalizeForecastCategory(fcHS) {
                opportunity.setValue(mapHubSpotForecastCategory(normalized), forKey: "forecastCategory")
            }
        } else if let fc = extractString(from: remote, key: "forecast_category"), let normalized = normalizeForecastCategory(fc) {
            opportunity.setValue(mapHubSpotForecastCategory(normalized), forKey: "forecastCategory")
        } else if let fcHS = extractString(from: remote, key: "hs_forecast_category"), let normalized = normalizeForecastCategory(fcHS) {
            opportunity.setValue(mapHubSpotForecastCategory(normalized), forKey: "forecastCategory")
        }
        else if let stage = remote["dealstage"] as? String {
            // Fallback: derive forecast from dealstage
            opportunity.setValue(mapDealStageToForecast(stage), forKey: "forecastCategory")
        }
    }

    private func applyRemoteCompany(_ remote: HubSpotCompanyDetails, to company: CompanyEntity) {
        let nameValue: String? = remote.name
        if let name = nameValue, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            company.name = name
        }
        let address1Value: String? = remote.address1
        if let v = address1Value { company.address = v }
        let address2Value: String? = remote.address2
        if let v = address2Value { company.address2 = v }
        let cityValue: String? = remote.city
        if let v = cityValue { company.city = v }
        let stateValue: String? = remote.state
        if let v = stateValue { company.state = v }
        let postalCodeValue: String? = remote.postalCode
        if let v = postalCodeValue { company.zipCode = v }
        if let stage = remote.lifecycleStage?.lowercased() {
            switch stage {
            case "opportunity": company.companyType = 3
            case "customer": company.companyType = 1
            default: break
            }
        }
        company.setValue(remote.id, forKey: "hubspotID")
    }

    // MARK: - Payload builders (TODO for push)

    private func makeDealUpdatePayload(from opportunity: OpportunityEntity) -> [String: Any] {
        var payload: [String: Any] = [:]
        if let name = opportunity.name { payload["dealname"] = name }
        payload["amount"] = String(opportunity.estimatedValue)
        if let closeDate = opportunity.closeDate { payload["closedate"] = String(Int(closeDate.timeIntervalSince1970 * 1000)) }
        // Reverse map forecast category
        payload["hs_forecast_category"] = reverseMapForecastCategory(Int(opportunity.value(forKey: "forecastCategory") as? Int16 ?? 0))
        return payload
    }

    private func makeCompanyUpdatePayload(from company: CompanyEntity) -> [String: Any] {
        var payload: [String: Any] = [:]
        if let name = company.name { payload["name"] = name }
        if let v = company.address { payload["address"] = v }
        if let v = company.address2 { payload["address2"] = v }
        if let v = company.city { payload["city"] = v }
        if let v = company.state { payload["state"] = v }
        if let v = company.zipCode { payload["zip"] = v }
        return payload
    }

    // MARK: - Helpers (duplicated minimal mapping to keep this file standalone)

    private func mapHubSpotForecastCategory(_ value: String?) -> Int16 {
        switch value?.lowercased() {
        case "pipeline": return 1
        case "bestcase": return 2
        case "mostlikely": return 2 // Map to best case unless you want a distinct code
        case "commit": return 3
        case "closed", "closedwon": return 4
        case "omitted": fallthrough
        default: return 0
        }
    }

    private func reverseMapForecastCategory(_ code: Int) -> String {
        switch code {
        case 1: return "pipeline"
        case 2: return "bestcase"
        case 3: return "commit"
        case 4: return "closed"
        default: return "omitted"
        }
    }
    
    private func mapDealStageToForecast(_ stage: String) -> Int16 {
        let s = stage.lowercased()
        if s.contains("closedwon") { return 4 }      // closed
        if s.contains("contract") || s.contains("decision") { return 3 } // commit
        if s.contains("qualified") || s.contains("proposal") { return 2 } // best case / most likely
        return 1 // pipeline by default
    }

    private func extractString(from remote: [String: Any], key: String) -> String? {
        // Try top-level string
        if let s = remote[key] as? String { return s }
        // Try top-level nested value object
        if let dict = remote[key] as? [String: Any], let s = dict["value"] as? String { return s }
        // Try properties[key] as string
        if let props = remote["properties"] as? [String: Any], let s = props[key] as? String { return s }
        // Try properties[key].value as string
        if let props = remote["properties"] as? [String: Any],
           let dict = props[key] as? [String: Any],
           let s = dict["value"] as? String {
            return s
        }
        return nil
    }

    private func extractRawValue(from remote: [String: Any], key: String) -> Any? {
        // Try top-level
        if let v = remote[key] { return v }
        // Try top-level nested value object
        if let dict = remote[key] as? [String: Any], let v = dict["value"] { return v }
        // Try properties[key]
        if let props = remote["properties"] as? [String: Any], let v = props[key] { return v }
        // Try properties[key].value
        if let props = remote["properties"] as? [String: Any],
           let dict = props[key] as? [String: Any],
           let v = dict["value"] {
            return v
        }
        return nil
    }
    
    private func normalizeForecastCategory(_ value: String?) -> String? {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        // Normalize casing and remove separators like spaces/underscores to handle variants like
        // "Best Case", "best_case", etc.
        let lower = v.lowercased()
        let compact = lower.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "_", with: "")
        return compact
    }

    private func parseHubSpotAmount(_ value: String?) -> Double {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return 0 }
        return Double(value) ?? 0
    }

    private func parseHubSpotCloseDate(_ value: String?) -> Date? {
        guard let value = value, let ms = Double(value) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }
    
    private func parseHubSpotCloseDateFlexible(_ value: Any?) -> Date? {
        // Accept String or numeric values (seconds or milliseconds since epoch)
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let number = Double(trimmed) else { return nil }
            return dateFromEpochFlexible(number)
        } else if let n = value as? NSNumber {
            return dateFromEpochFlexible(n.doubleValue)
        } else if let d = value as? Double {
            return dateFromEpochFlexible(d)
        } else if let i = value as? Int {
            return dateFromEpochFlexible(Double(i))
        }
        return nil
    }

    private func parseISO8601Date(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()

        // Try with fractional seconds first (e.g., 2026-01-25T00:00:00.000Z)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: s) { return d }

        // Then try without fractional seconds (e.g., 2026-01-25T00:00:00Z)
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: s) { return d }

        // Fallbacks for common ISO variants (with/without Z, with offsets)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        ]
        for p in patterns {
            df.dateFormat = p
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    private func dateFromEpochFlexible(_ raw: Double) -> Date {
        // Heuristic: values > 10^12 are milliseconds; else treat as seconds
        if raw > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: raw / 1000.0)
        } else {
            return Date(timeIntervalSince1970: raw)
        }
    }

    private func parseHubSpotLastModified(_ value: String?) -> Date? {
        guard let value = value, let ms = Double(value) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }

    private func saveContext() {
        do { try context.save() } catch { /* print("Save error: \(error)") */ }
    }
}

