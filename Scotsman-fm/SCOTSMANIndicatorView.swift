//
//  SCOTSMANIndicatorView.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/10/25.
//

import SwiftUI

enum SCOTSMANType: String, CaseIterable {
    case solution = "Solution"
    case competition = "Competition"
    case originality = "Originality"
    case timescale = "Timescale"
    case size = "Size"
    case money = "Money"
    case authority = "Authority"
    case need = "Need"
}

struct SCOTSMANIndicatorView: View {
    var opportunity: OpportunityWrapper
    var onSCOTSMANSelected: (SCOTSMANType) -> Void

    var body: some View {
        let solutionStatus = opportunity.solutionStatus
        let competitionStatus = opportunity.competitionStatus

        // NOTE: These currently map to existing OpportunityWrapper fields.
        // We'll rename/realign the underlying stored fields in OpportunityWrapper next.
        let originalityStatus = opportunity.uniquesStatus
        let timescaleStatus = opportunity.timingStatus
        let sizeStatus = opportunity.benefitsStatus
        let moneyStatus = opportunity.budgetStatus
        let authorityStatus = opportunity.authorityStatus
        let needStatus = opportunity.needStatus

        return HStack(spacing: 15) {
            QualificationIcon(iconName: "lightbulb.fill", status: solutionStatus)
                .onTapGesture { onSCOTSMANSelected(.solution) }

            QualificationIcon(iconName: "flag.fill", status: competitionStatus)
                .onTapGesture { onSCOTSMANSelected(.competition) }

            QualificationIcon(iconName: "sparkles", status: originalityStatus)
                .onTapGesture { onSCOTSMANSelected(.originality) }

            QualificationIcon(iconName: "clock.fill", status: timescaleStatus)
                .onTapGesture { onSCOTSMANSelected(.timescale) }

            QualificationIcon(iconName: "ruler", status: sizeStatus)
                .onTapGesture { onSCOTSMANSelected(.size) }

            QualificationIcon(iconName: "dollarsign.circle.fill", status: moneyStatus)
                .onTapGesture { onSCOTSMANSelected(.money) }

            QualificationIcon(iconName: "person.fill", status: authorityStatus)
                .onTapGesture { onSCOTSMANSelected(.authority) }

            QualificationIcon(iconName: "exclamationmark.circle.fill", status: needStatus)
                .onTapGesture { onSCOTSMANSelected(.need) }
        }
    }
}
