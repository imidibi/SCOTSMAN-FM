//
//  BANTIndicatorView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//
import SwiftUI

struct BANTIndicatorView: View {
    var opportunity: OpportunityWrapper  // ✅ Uses global OpportunityWrapper
    var onBANTSelected: (BANTType) -> Void

    enum BANTType {
        case budget, authority, need, timing
    }

    var body: some View {
        HStack(spacing: 15) {
            QualificationIcon(iconName: "dollarsign.circle.fill", status: opportunity.budgetStatus)
                .onTapGesture { onBANTSelected(.budget) }
            QualificationIcon(iconName: "person.fill", status: opportunity.authorityStatus)
                .onTapGesture { onBANTSelected(.authority) }
            QualificationIcon(iconName: "exclamationmark.circle.fill", status: opportunity.needStatus)
                .onTapGesture { onBANTSelected(.need) }
            QualificationIcon(iconName: "clock.fill", status: opportunity.timingStatus)
                .onTapGesture { onBANTSelected(.timing) }
        }
    }
}
