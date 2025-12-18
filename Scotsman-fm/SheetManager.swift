//
//  SheetManager.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI

class SheetManager: ObservableObject {
    @Published var activeSheet: SheetType?

    enum SheetType: Identifiable { // ✅ Conform to Identifiable
        case companySearch, productSearch

        var id: String { // ✅ Unique ID for SwiftUI
            switch self {
            case .companySearch: return "companySearch"
            case .productSearch: return "productSearch"
            }
        }
    }

    func showCompanySearch() {
        DispatchQueue.main.async { [weak self] in
            self?.activeSheet = .companySearch
        }
    }

    func showProductSearch() {
        DispatchQueue.main.async { [weak self] in
            self?.activeSheet = .productSearch
        }
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.activeSheet = nil
        }
    }
}
