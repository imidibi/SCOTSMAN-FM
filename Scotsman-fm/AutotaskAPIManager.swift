import Foundation

class AutotaskAPIManager {
    private let apiSemaphore = DispatchSemaphore(value: 3)
    static let shared = AutotaskAPIManager()
    
    private init() {}
    
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: queue)
    }()
    
    private func getAutotaskCredentials() -> (String, String, String)? {
        let apiUsername = UserDefaults.standard.string(forKey: "autotaskAPIUsername") ?? ""
        let apiSecret = UserDefaults.standard.string(forKey: "autotaskAPISecret") ?? ""
        let apiTrackingID = UserDefaults.standard.string(forKey: "autotaskAPITrackingID") ?? ""
        
        guard !apiUsername.isEmpty, !apiSecret.isEmpty, !apiTrackingID.isEmpty else {
            return nil
        }
        return (apiUsername, apiSecret, apiTrackingID)
    }
    
    func searchCompanies(query: String, completion: @escaping ([(Int, String)]) -> Void) {
        guard UserDefaults.standard.bool(forKey: "autotaskEnabled") else {
            // print("🔴 Autotask integration is disabled.")
            completion([])
            return
        }
        
        guard let (apiUsername, apiSecret, apiTrackingID) = getAutotaskCredentials() else {
            // print("🔴 Authentication failed: API credentials missing")
            completion([])
            return
        }
        
        let apiBaseURL = "https://webservices24.autotask.net/ATServicesRest/V1.0/Companies/query"
        var request = URLRequest(url: URL(string: apiBaseURL)!)
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "MaxRecords": 50,
            "IncludeFields": ["id", "companyName"],
            "Filter": [[
                "op": "like",
                "field": "companyName",
                "value": "\(query)%",
                "udf": false,
                "items": []
            ]]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            request.httpBody = jsonData
            // print("📤 Sending Company Search Request: \(apiBaseURL)")
            // print("📄 Request Body: \(String(data: jsonData, encoding: .utf8) ?? "Invalid JSON")")
        } catch {
            // print("🔴 Failed to encode request body: \(error.localizedDescription)")
            completion([])
            return
        }
        
        apiSemaphore.wait()
        session.dataTask(with: request) { data, response, error in
            if error != nil {
                // print("🔴 API Request Error: \(error?.localizedDescription ?? "")")
                self.apiSemaphore.signal()
                completion([])
                return
            }
            
            _ = response as? HTTPURLResponse
            
            guard let data = data else {
                // print("🔴 No data received from API")
                self.apiSemaphore.signal()
                completion([])
                return
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                // print("📥 Raw API Response: \(jsonResponse ?? [:])")
                
                if let companies = jsonResponse?["items"] as? [[String: Any]] {
                    let companyData = companies.compactMap { company -> (Int, String)? in
                        if let id = company["id"] as? Int,
                           let name = company["companyName"] as? String {
                            return (id, name)
                        }
                        return nil
                    }
                    // print("✅ Parsed Companies: \(companyData)")
                    self.apiSemaphore.signal()
                    completion(companyData)
                } else {
                    // print("⚠️ No companies found in response")
                    self.apiSemaphore.signal()
                    completion([])
                }
            } catch {
                // print("🔴 JSON Parsing Error: \(error.localizedDescription)")
                self.apiSemaphore.signal()
                completion([])
            }
        }.resume()
    }
    
    func searchContacts(companyID: Int, completion: @escaping ([(Int, String, String)]) -> Void) {
        guard UserDefaults.standard.bool(forKey: "autotaskEnabled"),
              let (apiUsername, apiSecret, apiTrackingID) = getAutotaskCredentials() else {
            completion([])
            return
        }
        
        let apiBaseURL = "https://webservices24.autotask.net/ATServicesRest/V1.0/Contacts/query"
        var request = URLRequest(url: URL(string: apiBaseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        
        let requestBody: [String: Any] = [
            "MaxRecords": 500,
            "IncludeFields": ["id", "firstName", "lastName"],
            "Filter": [
                ["op": "eq", "field": "CompanyID", "value": companyID],
                ["op": "gt", "field": "id", "value": 0]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            request.httpBody = jsonData
        } catch {
            // print("JSON encoding error: \(error.localizedDescription)")
            completion([])
            return
        }
        
        apiSemaphore.wait()
        session.dataTask(with: request) { data, response, error in
            if error != nil {
                self.apiSemaphore.signal()
                completion([])
                return
            }
            
            guard let data = data else {
                // print("No data received from API")
                self.apiSemaphore.signal()
                completion([])
                return
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let contactsArray = jsonResponse?["items"] as? [[String: Any]] else {
                    // print("No 'items' in response")
                    self.apiSemaphore.signal()
                    completion([])
                    return
                }
                
                let contacts = contactsArray.compactMap { contact -> (Int, String, String)? in
                    guard let id = contact["id"] as? Int,
                          let firstName = contact["firstName"] as? String,
                          let lastName = contact["lastName"] as? String else {
                        return nil
                    }
                    return (id, firstName, lastName)
                }
                
                self.apiSemaphore.signal()
                completion(contacts)
            } catch {
                // print("JSON parsing error: \(error.localizedDescription)")
                self.apiSemaphore.signal()
                completion([])
            }
        }.resume()
    }
    
    func searchContactsGET(companyID: Int, completion: @escaping ([(Int, String)]) -> Void) {
        guard UserDefaults.standard.bool(forKey: "autotaskEnabled") else {
            // print("Autotask integration is disabled.")
            completion([])
            return
        }
        
        guard let (apiUsername, apiSecret, apiTrackingID) = getAutotaskCredentials() else {
            // print("Authentication failed: API credentials missing")
            completion([])
            return
        }
        
        // Build the query JSON as per Autotask support recommendations.
        let queryJson: [String: Any] = [
            "filter": [
                ["op": "eq", "field": "CompanyID", "value": companyID],
                ["op": "gt", "field": "id", "value": 0]
            ]
        ]
        
        // Convert the query JSON to a string and URL-encode it.
        guard let jsonData = try? JSONSerialization.data(withJSONObject: queryJson, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encodedQuery = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            // print("Error encoding query JSON")
            completion([])
            return
        }
        
        let urlString = "https://webservices24.autotask.net/atservicesrest/v1.0/Contacts/query?search=\(encodedQuery)"
        guard let url = URL(string: urlString) else {
            // print("Invalid URL: \(urlString)")
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        
        // print("Performing GET request: \(urlString)")
        
        apiSemaphore.wait()
        session.dataTask(with: request) { data, response, error in
            if error != nil {
                // print("API Request Error: \(error?.localizedDescription ?? "")")
                self.apiSemaphore.signal()
                completion([])
                return
            }
            
            _ = response as? HTTPURLResponse
            
            guard let data = data else {
                // print("No data received from API")
                self.apiSemaphore.signal()
                completion([])
                return
            }
            
            // print("Full Raw Response: \(String(data: data, encoding: .utf8) ?? \"Invalid JSON\")")
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let contacts = jsonResponse["items"] as? [[String: Any]] {
                    let contactData = contacts.compactMap { contact -> (Int, String)? in
                        guard let id = contact["id"] as? Int,
                              let firstName = contact["firstName"] as? String,
                              let lastName = contact["lastName"] as? String,
                              let returnedCompanyID = contact["companyID"] as? Int else {
                            return nil
                        }
                        if returnedCompanyID != companyID {
                            return nil
                        }
                        return (id, "\(firstName) \(lastName)")
                    }
                    // print("Filtered Contacts: \(contactData)")
                    self.apiSemaphore.signal()
                    completion(contactData)
                } else {
                    // print("No contacts found in response")
                    self.apiSemaphore.signal()
                    completion([])
                }
            } catch {
                // print("JSON Parsing Error: \(error.localizedDescription)")
                self.apiSemaphore.signal()
                completion([])
            }
        }.resume()
    }
    func getAllCompanies(completion: @escaping ([(Int, String)]) -> Void) {
        guard UserDefaults.standard.bool(forKey: "autotaskEnabled") else {
            // print("Autotask integration is disabled.")
            completion([])
            return
        }
        
        guard let (apiUsername, apiSecret, apiTrackingID) = getAutotaskCredentials() else {
            // print("Authentication failed: API credentials missing")
            completion([])
            return
        }
        
        let urlString = "https://webservices24.autotask.net/atservicesrest/v1.0/Companies/query?search=%7B%22filter%22:[%7B%22op%22:%22exist%22,%22field%22:%22id%22%7D]%7D"
        guard let url = URL(string: urlString) else {
            // print("Invalid URL")
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        
        apiSemaphore.wait()
        session.dataTask(with: request) { data, response, error in
            if error != nil {
                // print("API Request Error: \(error?.localizedDescription ?? "")")
                self.apiSemaphore.signal()
                completion([])
                return
            }
            
            guard let data = data else {
                // print("No data received from API")
                self.apiSemaphore.signal()
                completion([])
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = jsonResponse["items"] as? [[String: Any]] {
                    let companies = items.compactMap { item -> (Int, String)? in
                        if let id = item["id"] as? Int,
                           let name = item["companyName"] as? String {
                            return (id, name)
                        }
                        return nil
                    }
                    self.apiSemaphore.signal()
                    completion(companies)
                } else {
                    self.apiSemaphore.signal()
                    completion([])
                }
            } catch {
                // print("JSON Parsing Error: \(error.localizedDescription)")
                self.apiSemaphore.signal()
                completion([])
            }
        }.resume()
    }
    
    func searchContactsFromBody(_ requestBody: [String: Any], completion: @escaping ([(Int, String, String)]) -> Void) {
        guard let url = URL(string: "https://webservices24.autotask.net/ATServicesRest/V1.0/Contacts/query") else {
            // print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        guard let (apiUsername, apiSecret, apiTrackingID) = getAutotaskCredentials() else {
            // print("❌ Missing Autotask credentials")
            completion([])
            return
        }
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var modifiedRequestBody = requestBody
        modifiedRequestBody["IncludeFields"] = ["id", "firstName", "lastName"]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: modifiedRequestBody, options: [])
        } catch {
            // print("❌ Failed to encode request body: \(error.localizedDescription)")
            completion([])
            return
        }
        
        apiSemaphore.wait()
        session.dataTask(with: request) { data, response, error in
            if error != nil {
                self.apiSemaphore.signal()
                completion([])
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                self.apiSemaphore.signal()
                completion([])
                return
            }

            let contacts: [(Int, String, String)] = items.compactMap {
                guard let id = $0["id"] as? Int,
                      let firstName = $0["firstName"] as? String,
                      let lastName = $0["lastName"] as? String else { return nil }
                return (id, firstName, lastName)
            }

            self.apiSemaphore.signal()
            completion(contacts)
        }.resume()
    }
    func searchFullContactDetail(_ requestBody: [String: Any], completion: @escaping ([(firstName: String, lastName: String, email: String, phone: String, title: String)]) -> Void) {
        guard let url = URL(string: "https://webservices24.autotask.net/ATServicesRest/V1.0/Contacts/query"),
              let (apiUsername, apiSecret, apiTrackingID) = getAutotaskCredentials() else {
            // print("❌ Invalid URL or missing credentials")
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            // print("❌ Failed to encode request body: \(error)")
            completion([])
            return
        }

        apiSemaphore.wait()
        session.dataTask(with: request) { data, response, error in
            if error != nil {
                self.apiSemaphore.signal()
                completion([])
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                self.apiSemaphore.signal()
                completion([])
                return
            }

            let contacts = items.compactMap { item -> (firstName: String, lastName: String, email: String, phone: String, title: String)? in
                guard let firstName = item["firstName"] as? String,
                      let lastName = item["lastName"] as? String else {
                    return nil
                }
                let email = item["emailAddress"] as? String ?? ""
                let phone = item["phone"] as? String ?? ""
                let title = item["title"] as? String ?? ""
                return (firstName, lastName, email, phone, title)
            }

            self.apiSemaphore.signal()
            completion(contacts)
        }.resume()
    }
    func searchOpportunitiesFromBody(_ requestBody: [String: Any], completion: @escaping ([(Int, String, Int?, Double?, Double?, Int?, Date?)]) -> Void) {
        guard let url = URL(string: "https://webservices24.autotask.net/ATServicesRest/V1.0/Opportunities/query") else {
            // print("❌ Invalid URL for Opportunities API")
            return
        }

        // print("📡 Sending Opportunities API Request to URL: \(url)")
        // print("📄 Request Body: \(requestBody)")
        
        var modifiedRequestBody = requestBody
        modifiedRequestBody["IncludeFields"] = ["id", "title", "amount", "probability", "monthlyRevenue", "onetimeRevenue", "status", "projectedCloseDate"]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let (apiUsername, apiSecret, apiTrackingID) = getAutotaskCredentials() else {
            // print("❌ Missing Autotask credentials")
            completion([])
            return
        }
        
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: modifiedRequestBody, options: [])
        } catch {
            // print("❌ Failed to encode request body: \(error.localizedDescription)")
            completion([])
            return
        }
        
        apiSemaphore.wait()
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                self.apiSemaphore.signal()
                completion([])
                return
            }

            guard let data = data else {
                self.apiSemaphore.signal()
                completion([])
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let items = json["items"] as? [[String: Any]] {

                    let opportunities = items.compactMap { item -> (Int, String, Int?, Double?, Double?, Int?, Date?)? in
                        if let id = item["id"] as? Int,
                           let title = item["title"] as? String,
                           let status = item["status"] as? Int,
                           (1...3).contains(status) {
                            let probability = item["probability"] as? Int
                            let monthlyRevenue = item["monthlyRevenue"] as? Double
                            let onetimeRevenue = item["onetimeRevenue"] as? Double
                            let projectedCloseDateString = item["projectedCloseDate"] as? String
                            let formatter = ISO8601DateFormatter()
                            let projectedCloseDate = projectedCloseDateString.flatMap { formatter.date(from: $0) }
                            return (id, title, probability, monthlyRevenue, onetimeRevenue, status, projectedCloseDate)
                        }
                        return nil
                    }
                    self.apiSemaphore.signal()
                    completion(opportunities)
                } else {
                    self.apiSemaphore.signal()
                    completion([])
                }
            } catch {
                self.apiSemaphore.signal()
                completion([])
            }
        }.resume()
    }
    func searchProductsFromBody(_ requestBody: [String: Any], completion: @escaping ([(Int, String, String, String, String, Double, Double, String, Date?, Date?)]) -> Void) {
        guard let url = URL(string: "https://webservices24.autotask.net/ATServicesRest/V1.0/Products/query") else {
            // print("❌ Invalid Autotask URL for products.")
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(UserDefaults.standard.string(forKey: "autotaskAPIUsername") ?? "", forHTTPHeaderField: "UserName")
        request.setValue(UserDefaults.standard.string(forKey: "autotaskAPISecret") ?? "", forHTTPHeaderField: "Secret")
        request.setValue(UserDefaults.standard.string(forKey: "autotaskAPITrackingID") ?? "", forHTTPHeaderField: "ApiIntegrationCode")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            // print("❌ Failed to serialize request body.")
            completion([])
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion([])
                return
            }

            guard let data = data,
                  let responseObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let items = responseObject["items"] as? [[String: Any]] else {
                completion([])
                return
            }

            let formatter = ISO8601DateFormatter()
            let products: [(Int, String, String, String, String, Double, Double, String, Date?, Date?)] = items.compactMap { item in
                guard let id = item["id"] as? Int,
                      let name = item["name"] as? String else { return nil }

                let type = item["type"] as? String ?? ""
                let description = item["description"] as? String ?? ""
                let units = item["unitName"] as? String ?? ""
                let unitPrice = item["unitPrice"] as? Double ?? 0.0
                let unitCost = item["unitCost"] as? Double ?? 0.0
                let benefits = item["benefits"] as? String ?? ""
                let lastModified = (item["lastModified"] as? String).flatMap { formatter.date(from: $0) }
                let lastActive = (item["autotaskLastActivityDate"] as? String).flatMap { formatter.date(from: $0) }

                return (id, name, type, description, units, unitPrice, unitCost, benefits, lastModified, lastActive)
            }

            DispatchQueue.main.async {
                completion(products)
            }
        }

        task.resume()
    }
    func searchServicesFromBody(_ requestBody: [String: Any], completion: @escaping ([(Int, String, String, Double, Double, String, String, Date?)]) -> Void) {
        let url = URL(string: "https://webservices24.autotask.net/ATServicesRest/V1.0/Services/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(UserDefaults.standard.string(forKey: "autotaskAPIUsername") ?? "", forHTTPHeaderField: "UserName")
        request.setValue(UserDefaults.standard.string(forKey: "autotaskAPISecret") ?? "", forHTTPHeaderField: "Secret")
        request.setValue(UserDefaults.standard.string(forKey: "autotaskAPITrackingID") ?? "", forHTTPHeaderField: "ApiIntegrationCode")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            // Print API URL and request body
            // print("📡 Sending Service API Request to URL: \(url)")
            // if let bodyData = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
            //    let bodyString = String(data: bodyData, encoding: .utf8) {
            //     print("📤 Request Body:\n\(bodyString)")
            // }
        } catch {
            // print("❌ Failed to encode request body: \(error.localizedDescription)")
            completion([])
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion([])
                return
            }

            guard let data = data else {
                completion([])
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                completion([])
                return
            }

            let services: [(Int, String, String, Double, Double, String, String, Date?)] = items.compactMap { item in
                guard let id = item["id"] as? Int,
                      let name = item["name"] as? String,
                      let description = item["description"] as? String,
                      let _ = item["invoiceDescription"] as? String,
                      let unitCost = item["unitCost"] as? Double,
                      let unitPrice = item["unitPrice"] as? Double,
                      let sku = item["sku"] as? String,
                      let catalogNumber = item["catalogNumberPartNumber"] as? String else {
                    return nil
                }

                let lastModified = (item["lastModifiedDate"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
                return (id, name, description, unitCost, unitPrice, sku, catalogNumber, lastModified)
            }

            completion(services)
        }.resume()
    }

    /// Fetches full company details for a specific company ID, including address and company type.
    /// - Parameters:
    ///   - companyID: The ID of the company to fetch.
    ///   - completion: Completion handler with an array of tuples containing company details.
    func fetchFullCompanyDetails(companyID: Int, completion: @escaping ([(Int, String?, String?, String?, String?, String?, String?, Int?)]) -> Void) {
        guard let url = URL(string: "https://webservices24.autotask.net/ATServicesRest/V1.0/Companies/query"),
              let (apiUsername, apiSecret, apiTrackingID) = getAutotaskCredentials() else {
            // print("❌ Invalid URL or missing credentials")
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "MaxRecords": 1,
            "IncludeFields": [
                "id", "companyName", "address1", "address2", "city", "state", "postalCode", "webAddress", "companyType"
            ],
            "Filter": [[
                "op": "eq",
                "field": "id",
                "value": companyID
            ]]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            // print("❌ Failed to encode request body: \(error)")
            completion([])
            return
        }

        apiSemaphore.wait()
        session.dataTask(with: request) { data, response, error in
            if error != nil {
                self.apiSemaphore.signal()
                completion([])
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]],
                  let item = items.first,
                  let id = item["id"] as? Int else {
                self.apiSemaphore.signal()
                completion([])
                return
            }

            let address1 = item["address1"] as? String
            let address2 = item["address2"] as? String
            let city = item["city"] as? String
            let state = item["state"] as? String
            let zip = item["postalCode"] as? String
            let web = item["webAddress"] as? String
            let companyType = item["companyType"] as? Int

            self.apiSemaphore.signal()
            completion([(id, address1, address2, city, state, zip, web, companyType)])
        }.resume()
    }
}
