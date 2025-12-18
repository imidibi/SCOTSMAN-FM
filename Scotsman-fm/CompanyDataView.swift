//
//  CompanyDataView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI
import CoreData
import MapKit

// Codable wrapper for AI profile cache
struct CodableAIProfileCacheItem: Codable {
    let text: String
    let date: Date
}

// MARK: - Company Row View
struct CompanyRowView: View {
    let company: CompanyWrapper
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMap: () -> Void
    let onWeb: () -> Void
    let onAIProfile: () -> Void

    private func colorForCompanyType(_ type: Int) -> Color {
        switch type {
        case 1: return .green      // Customer
        case 2: return .yellow     // Lead
        case 3: return .blue       // Prospect
        default: return .gray
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                // ✅ Tap on Name to Open EditCompanyView
                Button(action: onEdit) {
                    Text(company.name)
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                Text(company.address)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if !company.address2.isEmpty {
                    Text(company.address2)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Text("\(company.city), \(company.state) \(company.zipCode)")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if !company.mainContact.isEmpty {
                    Text("Contact: \(company.mainContact)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                Text("Type: \(company.companyTypeDescription)")
                    .font(.subheadline)
                    .foregroundColor(colorForCompanyType(company.companyType))
            }
            .padding()

            Spacer()

            // 📍 Apple Maps Button
            Button(action: onMap) {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            if !company.webAddress.isEmpty {
                Button(action: onWeb) {
                    Image(systemName: "globe")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }

            // 🧠 AI Company Profile Button
            Button(action: onAIProfile) {
                Image(systemName: "person.crop.rectangle")
                    .foregroundColor(.purple)
            }
            .buttonStyle(.plain)
        }
    }
}

struct CompanyDataView: View {
    // ────────────────────────────────────────────────────────── State
    @ObservedObject var viewModel: CompanyViewModel
    @State private var isShowingAddSheet       = false
    @State private var selectedCompany: CompanyWrapper?
    @State private var searchText              = ""
    @State private var showAlert               = false
    @State private var isShowingAIProfile      = false
    @State private var aiProfileText           = ""
    @AppStorage("aiProfileCache") private var aiProfileCacheData = Data()
    @State private var aiProfileCache: [String:(text: String, date: Date)] = [:]

    // 🔍 Filtered Companies
    private var filteredCompanies: [CompanyWrapper] {
        guard !searchText.isEmpty else { return viewModel.companies }
        let query = searchText.lowercased()
        return viewModel.companies.filter { $0.name.lowercased().contains(query) }
    }

    // ────────────────────────────────────────────────────────── View
    var body: some View {
        NavigationStack {
            VStack {
                // 🔍 Search Bar
                HStack {
                    TextField("Search Companies", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing)
                    .opacity(searchText.isEmpty ? 0 : 1)
                }
                .padding(.top)

                // 📝 Company list (refactored so the compiler is happy)
                List {
                    ForEach(filteredCompanies, id: \.name) { company in
                        makeRow(for: company)
                    }
                    .onDelete(perform: deleteCompany)
                }
            }
            .navigationTitle("Companies")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title)
                    }
                }
            }
            // ───────── Sheets / Alerts / Side‑effects
            .sheet(item: $selectedCompany) { company in
                EditCompanyView(viewModel: viewModel, company: company)
            }
            .sheet(isPresented: $isShowingAddSheet,
                   onDismiss: { viewModel.fetchCompanies() }) {
                AddCompanyView(viewModel: viewModel)
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title:  Text("Error"),
                    message:Text(viewModel.deletionErrorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK")) {
                        viewModel.deletionErrorMessage = nil
                    }
                )
            }
            .onChange(of: viewModel.deletionErrorMessage) { _, newValue in
                showAlert = (newValue != nil)
            }
            .sheet(isPresented: $isShowingAIProfile) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI Company Profile")
                            .font(.title).bold()

                        if let cached = aiProfileCache.first(where: { $0.value.text == aiProfileText }) {
                            Button("Update Profile") {
                                let companyName = cached.key
                                guard let company = viewModel.companies.first(where: { $0.name == companyName }) else { return }
                            

                                aiProfileText = "Loading…"

                                AIRecommendationManager.generateCompanyProfile(for: company) { result in
                                    DispatchQueue.main.async {
                                        aiProfileCache[company.name] = (result, Date())
                                        encodeCache()
                                        aiProfileText = result
                                    }
                                }
                            }
                            .padding()

                            Text("Last updated: \(cached.value.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.bottom, 4)
                        }

                        Text(aiProfileText)
                            .font(.body)
                            .padding()

                        Spacer()
                    }
                    .padding()
                }
            }
            .onAppear {
                if let decoded = try? JSONDecoder().decode([String: CodableAIProfileCacheItem].self,
                                                           from: aiProfileCacheData) {
                    aiProfileCache = decoded.mapValues { ($0.text, $0.date) }
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────── Helpers

    /// Small factory to keep the `List` body tiny (prevents compiler time‑outs).
    @ViewBuilder
    private func makeRow(for company: CompanyWrapper) -> some View {
        CompanyRowView(
            company: company,
            onEdit:      { selectedCompany = company },
            onDelete:    { deleteCompany(withName: company.name) },
            onMap:       { openInAppleMaps(company: company) },
            onWeb:       {
                if let url = URL(string: company.webAddress.prependingHTTPIfNeeded()) {
                    UIApplication.shared.open(url)
                }
            },
            onAIProfile: { fetchAIProfile(for: company) }
        )
        .contextMenu {
            Button(role: .destructive) {
                deleteCompany(withName: company.name)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Original *IndexSet*‑based delete (called by swipe‑to‑delete).
    private func deleteCompany(at offsets: IndexSet) {
        offsets.forEach { idx in
            let company = filteredCompanies[idx]
            viewModel.deleteCompany(company: company)
        }
        // Refresh after a short delay so Core Data finishes first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.fetchCompanies()
        }
    }

    /// Convenience when you already have the company name.
    private func deleteCompany(withName name: String) {
        if let idx = filteredCompanies.firstIndex(where: { $0.name == name }) {
            deleteCompany(at: IndexSet(integer: idx))
        }
    }

    /// Opens the company address in Apple Maps.
    private func openInAppleMaps(company: CompanyWrapper) {
        let addressString = "\(company.address) \(company.city), \(company.state) \(company.zipCode)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(addressString)") {
            UIApplication.shared.open(url)
        }
    }

    /// Retrieves an AI profile, using the cache when possible.
    private func fetchAIProfile(for company: CompanyWrapper) {
        if let cached = aiProfileCache[company.name] {
            aiProfileText      = cached.text
            isShowingAIProfile = true
            return
        }

        aiProfileText      = "Loading…"
        isShowingAIProfile = true

        AIRecommendationManager.generateCompanyProfile(for: company) { result in
            DispatchQueue.main.async {
                aiProfileCache[company.name] = (result, Date())
                encodeCache()
                aiProfileText = result
            }
        }
    }

    /// Serialises the in‑memory cache back to `@AppStorage`.
    private func encodeCache() {
        let codable = aiProfileCache.mapValues { CodableAIProfileCacheItem(text: $0.text,
                                                                           date: $0.date) }
        if let encoded = try? JSONEncoder().encode(codable) {
            aiProfileCacheData = encoded
        }
    }
}

// MARK: - Tiny utilities (keep the main code clean)

private extension String {
    /// Prepends “https://” if the string does not already start with “http”.
    func prependingHTTPIfNeeded() -> String {
        lowercased().hasPrefix("http") ? self : "https://" + self
    }
}

////
////  CompanyDataView.swift
////  iPadtester
////
////  Created by Ian Miller on 2/15/25.
////
//
//import SwiftUI
//import CoreData
//import MapKit
//
//// Codable wrapper for AI profile cache
//struct CodableAIProfileCacheItem: Codable {
//    let text: String
//    let date: Date
//}
//
//
//// MARK: - Company Row View
//struct CompanyRowView: View {
//    let company: CompanyWrapper
//    let onEdit: () -> Void
//    let onDelete: () -> Void
//    let onMap: () -> Void
//    let onWeb: () -> Void
//    let onAIProfile: () -> Void
//
//    private func colorForCompanyType(_ type: Int) -> Color {
//        switch type {
//        case 1:
//            return .green // Customer
//        case 2:
//            return .yellow // Lead
//        case 3:
//            return .blue // Prospect
//        default:
//            return .gray
//        }
//    }
//
//    var body: some View {
//        HStack {
//            VStack(alignment: .leading) {
//                // ✅ Tap on Name to Open EditCompanyView
//                Button(action: { onEdit() }) {
//                    Text(company.name)
//                        .font(.headline)
//                        .foregroundColor(.blue)
//                }
//
//                Text(company.address)
//                    .font(.subheadline)
//                    .foregroundColor(.gray)
//
//                if !company.address2.isEmpty { // ✅ Skip address2 if blank
//                    Text(company.address2)
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                }
//
//                Text("\(company.city), \(company.state) \(company.zipCode)")
//                    .font(.subheadline)
//                    .foregroundColor(.gray)
//
//                if !company.mainContact.isEmpty {
//                    Text("Contact: \(company.mainContact)")
//                        .font(.subheadline)
//                        .foregroundColor(.blue)
//                }
//
//                Text("Type: \(company.companyTypeDescription)")
//                    .font(.subheadline)
//                    .foregroundColor(colorForCompanyType(company.companyType))
//            }
//            .padding()
//
//            Spacer()
//
//            // 📍 Apple Maps Button
//            Button(action: { onMap() }) {
//                Image(systemName: "map.fill")
//                    .foregroundColor(.blue)
//            }
//            .buttonStyle(PlainButtonStyle())
//
//            if !company.webAddress.isEmpty {
//                Button(action: { onWeb() }) {
//                    Image(systemName: "globe")
//                        .foregroundColor(.green)
//                }
//                .buttonStyle(PlainButtonStyle())
//            }
//
//            // 🧠 AI Company Profile Button
//            Button(action: { onAIProfile() }) {
//                Image(systemName: "person.crop.rectangle")
//                    .foregroundColor(.purple)
//            }
//            .buttonStyle(PlainButtonStyle())
//        }
//    }
//}
//
//struct CompanyDataView: View {
//    @ObservedObject var viewModel: CompanyViewModel
//    @State private var isShowingAddSheet = false
//    @State private var selectedCompany: CompanyWrapper?
//    @State private var searchText: String = ""  // ✅ Search state
//    @State private var showAlert = false // Add state to trigger the alert
//    @State private var isShowingAIProfile = false
//    @State private var aiProfileText: String = ""
//    @AppStorage("aiProfileCache") private var aiProfileCacheData: Data = Data()
//    @State private var aiProfileCache: [String: (text: String, date: Date)] = [:]
//
//    private let aiCompanyProfilePrompt = """
//    Provide a plain, factual profile of the company named %@ without any greeting or conversational tone. Respond with only the core information. Please detail their line of business, main competitors, business challenges in their sector, their main growth opportunities, and ways IT can assist in their growth and success.
//    """
//
//    // 🔍 Filtered Companies
//    var filteredCompanies: [CompanyWrapper] {
//        if searchText.isEmpty {
//            return viewModel.companies
//        }
//
//        var filtered: [CompanyWrapper] = []
//        let query = searchText.lowercased()
//
//        for company in viewModel.companies {
//            if company.name.lowercased().contains(query) {
//                filtered.append(company)
//            }
//        }
//
//        return filtered
//    }
//
//    var body: some View {
//        NavigationStack {
//            VStack {
//                // 🔍 Search Bar
//                HStack {
//                    TextField("Search Companies", text: $searchText)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                        .padding(.horizontal)
//
//                    Button(action: { searchText = "" }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .foregroundColor(.gray)
//                    }
//                    .padding(.trailing)
//                    .opacity(searchText.isEmpty ? 0 : 1)  // Hide if no search text
//                }
//                .padding(.top)
//
//                List {
//                    ForEach(filteredCompanies.indices, id: \.self) { index in
//                        let company = filteredCompanies[index]
//                        CompanyRowView(
//                            company: company,
//                            onEdit: { selectedCompany = company },
//                            onDelete: { deleteCompany(at: IndexSet(integer: index)) },
//                            onMap: { openInAppleMaps(company: company) },
//                            onWeb: {
//                                if !company.webAddress.isEmpty,
//                                   let url = URL(string: company.webAddress.starts(with: "http") ? company.webAddress : "https://\(company.webAddress)") {
//                                    UIApplication.shared.open(url)
//                                }
//                            },
//                            onAIProfile: { fetchAIProfile(for: company) }
//                        )
//                        .contextMenu {
//                            Button(role: .destructive) {
//                                deleteCompany(at: IndexSet(integer: index))
//                            } label: {
//                                Label("Delete", systemImage: "trash")
//                            }
//                        }
//                    }
//                    .onDelete(perform: deleteCompany)
//                }
//            }
//            .navigationTitle("Companies")
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button(action: { isShowingAddSheet = true }) {
//                        Image(systemName: "plus.circle.fill")
//                            .font(.title)
//                    }
//                }
//            }
//            .sheet(item: $selectedCompany) { company in
//                EditCompanyView(viewModel: viewModel, company: company) // ✅ Opens EditCompanyView
//            }
//            .sheet(isPresented: $isShowingAddSheet, onDismiss: {
//                viewModel.fetchCompanies()
//            }) {
//                AddCompanyView(viewModel: viewModel)
//            }
//            .alert(isPresented: $showAlert) { // Display alert if there's an error message
//                Alert(
//                    title: Text("Error"),
//                    message: Text(viewModel.deletionErrorMessage ?? "Unknown error"),
//                    dismissButton: .default(Text("OK")) {
//                        viewModel.deletionErrorMessage = nil // Clear the message after showing
//                    }
//                )
//            }
//            .onChange(of: viewModel.deletionErrorMessage) {
//                if viewModel.deletionErrorMessage != nil {
//                    showAlert = true
//                }
//            }
//            .sheet(isPresented: $isShowingAIProfile) {
//                ScrollView {
//                    VStack(alignment: .leading, spacing: 16) {
//                        Text("AI Company Profile")
//                            .font(.title)
//                            .bold()
//                        if let cached = aiProfileCache.first(where: { $0.value.text == aiProfileText }) {
//                            Button("Update Profile") {
//                                guard let cachedCompanyName = cached.key else { return }
//                                guard let company = viewModel.companies.first(where: { $0.name == cachedCompanyName }) else { return }
//
//                                aiProfileText = "Loading..."
//
//                                let promptBase = """
//                                Provide a plain, factual profile of the company named %@ without any greeting or conversational tone. Respond with only the core information. Please detail their line of business, main competitors, business challenges in their sector, their main growth opportunities, and ways IT can assist in their growth and success.
//                                """
//                                let finalPrompt = String(format: promptBase, company.name)
//
//                                AIRecommendationManager.generateCompanyProfile(for: company, prompt: finalPrompt) { result in
//                                    DispatchQueue.main.async {
//                                        aiProfileCache[company.name] = (result, Date())
//                                        let codableCache = aiProfileCache.mapValues { CodableAIProfileCacheItem(text: $0.text, date: $0.date) }
//                                        if let encoded = try? JSONEncoder().encode(codableCache) {
//                                            aiProfileCacheData = encoded
//                                        }
//                                        aiProfileText = result
//                                    }
//                                }
//                            }
//                            .padding()
//
//                            let date = cached.value.date
//                            Text("Last updated: \(date.formatted(date: .abbreviated, time: .shortened))")
//                                .font(.caption)
//                                .foregroundColor(.gray)
//                                .padding(.bottom, 4)
//                        }
//                        Text(aiProfileText)
//                            .font(.body)
//                            .padding()
//                        Spacer()
//                    }
//                    .padding()
//                }
//            }
//            .onAppear {
//                if let decoded = try? JSONDecoder().decode([String: CodableAIProfileCacheItem].self, from: aiProfileCacheData) {
//                    aiProfileCache = decoded.mapValues { ($0.text, $0.date) }
//                }
//            }
//        }
//    }
//
//    private func deleteCompany(at offsets: IndexSet) {
//        offsets.forEach { index in
//            let company = filteredCompanies[index]
//            viewModel.deleteCompany(company: company)
//        }
//
//        // ✅ Always refresh after deletion to reflect Core Data state
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            viewModel.fetchCompanies()
//        }
//    }
//
//    private func colorForCompanyType(_ type: Int) -> Color {
//        switch type {
//        case 1:
//            return .green // Customer
//        case 2:
//            return .yellow // Lead
//        case 3:
//            return .blue // Prospect
//        default:
//            return .gray
//        }
//    }
//
//    // ✅ Function to Open in Apple Maps
//    private func openInAppleMaps(company: CompanyWrapper) {
//        let addressString = "\(company.address) \(company.city), \(company.state) \(company.zipCode)"
//            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
//        
//        if let url = URL(string: "http://maps.apple.com/?q=\(addressString)") {
//            UIApplication.shared.open(url)
//        }
//    }
//    
//    private func fetchAIProfile(for company: CompanyWrapper) {
//        let cacheKey = company.name
//
//        if let cached = aiProfileCache[cacheKey] {
//            aiProfileText = cached.text
//            isShowingAIProfile = true
//            return
//        }
//
//        aiProfileText = "Loading..."
//        isShowingAIProfile = true
//
//        let promptBase = """
//        Provide a plain, factual profile of the company named %@ without any greeting or conversational tone. Respond with only the core information. Please detail their line of business, main competitors, business challenges in their sector, their main growth opportunities, and ways IT can assist in their growth and success.
//        """
//        let finalPrompt = String(format: promptBase, company.name)
//
//        AIRecommendationManager.generateCompanyProfile(for: company, prompt: finalPrompt) { result in
//            DispatchQueue.main.async {
//                aiProfileCache[company.name] = (result, Date())
//                let codableCache = aiProfileCache.mapValues { CodableAIProfileCacheItem(text: $0.text, date: $0.date) }
//                if let encoded = try? JSONEncoder().encode(codableCache) {
//                    aiProfileCacheData = encoded
//                }
//                aiProfileText = result
//            }
//        }
//    }
//}
