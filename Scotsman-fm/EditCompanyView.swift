//
//  EditCompanyView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI

struct EditCompanyView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: CompanyViewModel
    var company: CompanyWrapper // ✅ Now using CompanyWrapper

    @State private var name: String
    @State private var address: String
    @State private var address2: String
    @State private var city: String
    @State private var state: String
    @State private var zipCode: String
    @State private var mainContact: String
    @State private var webAddress: String
    @State private var companyType: Int

    init(viewModel: CompanyViewModel, company: CompanyWrapper) { // ✅ Expecting CompanyWrapper
        self.viewModel = viewModel
        self.company = company
        _name = State(initialValue: company.name)
        _address = State(initialValue: company.address)
        _address2 = State(initialValue: company.address2)
        _city = State(initialValue: company.city)
        _state = State(initialValue: company.state)
        _zipCode = State(initialValue: company.zipCode)
        _mainContact = State(initialValue: company.mainContact)
        _webAddress = State(initialValue: company.webAddress)
        _companyType = State(initialValue: company.companyType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Company Information")) {
                    TextField("Company Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Address2", text: $address2)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("zipCode", text: $zipCode)
                    TextField("Main Contact", text: $mainContact)
                    TextField("Web Address", text: $webAddress)
                    Picker("Company Type", selection: $companyType) {
                        Text("Customer").tag(1)
                        Text("Lead").tag(2)
                        Text("Prospect").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit Company")
            .toolbar {
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.updateCompany(company: company, name: name, address: address, address2: address2, city: city, state: state, zipCode: zipCode, mainContact: mainContact, webAddress: webAddress, companyType: companyType)
                        dismiss()
                    }
                }
            }
        }
    }
}
