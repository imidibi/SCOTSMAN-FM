//
//  SearchCompanyView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI

struct SearchCompanyView: View {
    var companies: [CompanyWrapper]
    var onSelect: (CompanyWrapper) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss // ✅ Allows manual dismissal

    var filteredCompanies: [CompanyWrapper] {
        searchText.isEmpty ? companies : companies.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredCompanies) { company in
                Button(action: {
                    onSelect(company)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        dismiss()
                    }
                }) {
                    Text(company.name)
                }
            }
            .navigationTitle("Search Company")
            .searchable(text: $searchText, prompt: "Search Companies")
        }
    }
}
