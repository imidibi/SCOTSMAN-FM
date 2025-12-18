//
//  MEDDICIndicatorView.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/10/25.
//




import SwiftUI

enum MEDDICType: String, CaseIterable {
    case metrics = "Metrics"
    case economicBuyer = "Economic Buyer"
    case identifyPain = "Identify Pain"
    case decisionProcess = "Decision Process"
    case decisionCriteria = "Decision Criteria"
    case champion = "Champion"
}

struct MEDDICIndicatorView: View {
    var opportunity: OpportunityWrapper
    var onMEDDICSelected: (MEDDICType) -> Void

    var body: some View {
        HStack(spacing: 15) {
            QualificationIcon(iconName: "dollarsign.circle.fill", status: opportunity.metricsStatus)
                .onTapGesture { onMEDDICSelected(.metrics) }
            QualificationIcon(iconName: "person.fill", status: opportunity.authorityStatus)
                .onTapGesture { onMEDDICSelected(.economicBuyer) }
            QualificationIcon(iconName: "clock.fill", status: opportunity.timingStatus)
                .onTapGesture { onMEDDICSelected(.decisionProcess) }
            QualificationIcon(iconName: "checkmark.circle.fill", status: opportunity.decisionCriteriaStatus)
                .onTapGesture { onMEDDICSelected(.decisionCriteria) }
            QualificationIcon(iconName: "exclamationmark.circle.fill", status: opportunity.needStatus)
                .onTapGesture { onMEDDICSelected(.identifyPain) }
            QualificationIcon(iconName: "star.circle.fill", status: opportunity.championStatus)
                .onTapGesture { onMEDDICSelected(.champion) }
        }
    }
}
