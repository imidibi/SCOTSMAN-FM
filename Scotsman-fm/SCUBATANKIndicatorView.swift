//
//  SCUBATANKIndicatorView.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/10/25.
//

import SwiftUI

enum SCUBATANKType: String, CaseIterable {
    case solution = "Solution"
    case competition = "Competition"
    case uniques = "Uniques"
    case benefits = "Benefits"
    case authority = "Authority"
    case timescale = "Timescale"
    case actionPlan = "Action Plan"
    case need = "Need"
    case kash = "Kash"
}

struct SCUBATANKIndicatorView: View {
    var opportunity: OpportunityWrapper
    var onSCUBATANKSelected: (SCUBATANKType) -> Void

    var body: some View {
        let solutionStatus = opportunity.solutionStatus
        // print("Rendering Solution - Status: \(solutionStatus)")

        let competitionStatus = opportunity.competitionStatus
        // print("Rendering Competition - Status: \(competitionStatus)")

        let uniquesStatus = opportunity.uniquesStatus
        // print("Rendering Uniques - Status: \(uniquesStatus)")

        let benefitsStatus = opportunity.benefitsStatus
        // print("Rendering Benefits - Status: \(benefitsStatus)")

        let authorityStatus = opportunity.authorityStatus
        // print("Rendering Authority - Status: \(authorityStatus)")

        let timescaleStatus = opportunity.timingStatus
        // print("Rendering Timescale - Status: \(timescaleStatus)")

        let actionPlanStatus = opportunity.actionPlanStatus
        // print("Rendering Action Plan - Status: \(actionPlanStatus)")

        let needStatus = opportunity.needStatus
        // print("Rendering Need - Status: \(needStatus)")

        let kashStatus = opportunity.budgetStatus
        // print("Rendering Kash - Status: \(kashStatus)")

        return HStack(spacing: 15) {
            QualificationIcon(iconName: "lightbulb.fill", status: solutionStatus)
                .onTapGesture { onSCUBATANKSelected(.solution) }

            QualificationIcon(iconName: "flag.fill", status: competitionStatus)
                .onTapGesture { onSCUBATANKSelected(.competition) }

            QualificationIcon(iconName: "star.circle.fill", status: uniquesStatus)
                .onTapGesture { onSCUBATANKSelected(.uniques) }

            QualificationIcon(iconName: "gift.fill", status: benefitsStatus)
                .onTapGesture { onSCUBATANKSelected(.benefits) }

            QualificationIcon(iconName: "person.fill", status: authorityStatus)
                .onTapGesture { onSCUBATANKSelected(.authority) }

            QualificationIcon(iconName: "clock.fill", status: timescaleStatus)
                .onTapGesture { onSCUBATANKSelected(.timescale) }

            QualificationIcon(iconName: "checkmark.circle.fill", status: actionPlanStatus)
                .onTapGesture { onSCUBATANKSelected(.actionPlan) }

            QualificationIcon(iconName: "exclamationmark.circle.fill", status: needStatus)
                .onTapGesture { onSCUBATANKSelected(.need) }

            QualificationIcon(iconName: "dollarsign.circle.fill", status: kashStatus)
                .onTapGesture { onSCUBATANKSelected(.kash) }
        }
    }
}
