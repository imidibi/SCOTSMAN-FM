//
//  QualificationIcon.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/10/25.
//

import SwiftUI

struct QualificationIcon: View {
    var iconName: String
    var status: Int

    private var color: Color {
        switch status {
        case 0:
            return .red
        case 1:
            return .yellow
        case 2:
            return .green
        default:
            return .gray
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .resizable()
            .frame(width: 40, height: 40)
            .foregroundColor(color)
    }
}
