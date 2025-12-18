import Foundation
import CoreData
import SwiftUI

class OpportunityViewModel: ObservableObject {
    @AppStorage("selectedMethodology") var currentMethodology: String = "BANT"
    @Published var opportunities: [OpportunityWrapper] = []
    
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .companyName

    // AI Guidance overlay state
//    @Published var showAIGuidanceOverlay: Bool = false
//    @Published var selectedOpportunityForAI: OpportunityWrapper? = nil
    
    enum SortOption {
        case companyName, opportunityName, closeDate
    }
    
    enum OpportunityStatus: Int16 {
        case active = 1, lost = 2, closed = 3
        
        var description: String {
            switch self {
            case .active: return "Active"
            case .lost: return "Lost"
            case .closed: return "Closed"
            }
        }
    }
    
    func statusDescription(for statusCode: Int16) -> String {
        return OpportunityStatus(rawValue: statusCode)?.description ?? "Unknown"
    }
    
    private let context = CoreDataManager.shared.context

    init() {
        fetchOpportunities()
    }

    func fetchOpportunities() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "OpportunityEntity")
        do {
            let fetchedOpportunities = try context.fetch(request)
            self.opportunities = fetchedOpportunities.map { OpportunityWrapper(managedObject: $0) }
        } catch {
            print("❌ Error fetching opportunities: \(error)")
        }
    }

    var filteredOpportunities: [OpportunityWrapper] {
        let filtered = opportunities.filter {
            $0.companyName.lowercased().contains(searchText.lowercased())
        }
        
        switch sortOption {
        case .companyName:
            return filtered.sorted { $0.companyName < $1.companyName }
        case .opportunityName:
            return filtered.sorted { $0.name < $1.name }
        case .closeDate:
            return filtered.sorted { $0.closeDate < $1.closeDate }
        }
    }
    
    func addOpportunity(name: String, closeDate: Date, company: CompanyWrapper, product: ProductWrapper?, probability: Int16, monthlyRevenue: Double, onetimeRevenue: Double, estimatedValue: Double, status: Int16) {
        let entity = NSEntityDescription.entity(forEntityName: "OpportunityEntity", in: context)!
        let newOpportunity = NSManagedObject(entity: entity, insertInto: context)

        newOpportunity.setValue(name, forKey: "name")
        newOpportunity.setValue(closeDate, forKey: "closeDate")
        newOpportunity.setValue(company.managedObject, forKey: "company")
        if let product = product {
            newOpportunity.setValue(product.managedObject, forKey: "product")
        } else {
            newOpportunity.setValue(nil, forKey: "product")
        }
        newOpportunity.setValue(probability, forKey: "probability")
        newOpportunity.setValue(monthlyRevenue, forKey: "monthlyRevenue")
        newOpportunity.setValue(onetimeRevenue, forKey: "onetimeRevenue")
        newOpportunity.setValue(estimatedValue, forKey: "estimatedValue")
        newOpportunity.setValue(status, forKey: "status")

        newOpportunity.setValue(0, forKey: "budgetStatus")
        newOpportunity.setValue(0, forKey: "authorityStatus")
        newOpportunity.setValue(0, forKey: "needStatus")
        newOpportunity.setValue(0, forKey: "timingStatus")
        
        newOpportunity.setValue("", forKey: "budgetCommentary")
        newOpportunity.setValue("", forKey: "authorityCommentary")
        newOpportunity.setValue("", forKey: "needCommentary")
        newOpportunity.setValue("", forKey: "timingCommentary")

        saveData()
    }
    
    func updateOpportunity(opportunity: OpportunityWrapper, name: String, closeDate: Date, probability: Int16, monthlyRevenue: Double, onetimeRevenue: Double, estimatedValue: Double, status: Int16) {
        opportunity.managedObject.setValue(name, forKey: "name")
        opportunity.managedObject.setValue(closeDate, forKey: "closeDate")
        opportunity.managedObject.setValue(probability, forKey: "probability")
        opportunity.managedObject.setValue(monthlyRevenue, forKey: "monthlyRevenue")
        opportunity.managedObject.setValue(onetimeRevenue, forKey: "onetimeRevenue")
        opportunity.managedObject.setValue(estimatedValue, forKey: "estimatedValue")
        opportunity.managedObject.setValue(status, forKey: "status")

        saveData()
    }

    func updateBANT(opportunity: OpportunityWrapper, bantType: BANTIndicatorView.BANTType, status: Int, commentary: String) {
        // Debug logging to help trace the issue
//        print("Debug (updateBANT): Received bantType: \(bantType), status: \(status), commentary: \(commentary)")
        
        switch bantType {
        case .budget:
//            print("Debug (updateBANT): Updating budget qualification.")
            opportunity.managedObject.setValue(status, forKey: "budgetStatus")
            opportunity.managedObject.setValue(commentary, forKey: "budgetCommentary")
        case .authority:
//            print("Debug (updateBANT): Updating authority qualification.")
            opportunity.managedObject.setValue(status, forKey: "authorityStatus")
            opportunity.managedObject.setValue(commentary, forKey: "authorityCommentary")
        case .need:
//            print("Debug (updateBANT): Updating need qualification.")
            opportunity.managedObject.setValue(status, forKey: "needStatus")
            opportunity.managedObject.setValue(commentary, forKey: "needCommentary")
        case .timing:
//            print("Debug (updateBANT): Updating timing qualification.")
            opportunity.managedObject.setValue(status, forKey: "timingStatus")
            opportunity.managedObject.setValue(commentary, forKey: "timingCommentary")
        }
        
//        print("Debug (updateBANT): Update complete. Saving data.")
        saveData()
    }

    func updateMEDDICStatus(for opportunity: OpportunityWrapper, metricType: String, status: Int, commentary: String) {
        switch metricType {
        case "Metrics":
            opportunity.managedObject.setValue(status, forKey: "metricsStatus")
            opportunity.managedObject.setValue(commentary, forKey: "metricsCommentary")
        case "Economic Buyer":
            opportunity.managedObject.setValue(status, forKey: "authorityStatus")
            opportunity.managedObject.setValue(commentary, forKey: "authorityCommentary")

        case "Decision Process":
            opportunity.managedObject.setValue(status, forKey: "timingStatus")
            opportunity.managedObject.setValue(commentary, forKey: "timingCommentary")
        case "Decision Criteria":
            opportunity.managedObject.setValue(status, forKey: "decisionCriteriaStatus")
            opportunity.managedObject.setValue(commentary, forKey: "decisionCriteriaCommentary")
        case "Identify Pain":
            opportunity.managedObject.setValue(status, forKey: "needStatus")
            opportunity.managedObject.setValue(commentary, forKey: "needCommentary")
        case "Champion":
            opportunity.managedObject.setValue(status, forKey: "championStatus")
            opportunity.managedObject.setValue(commentary, forKey: "championCommentary")
        default:
            break
        }
        saveData()
    }

    func getMEDDICStatus(for opportunity: OpportunityWrapper, metricType: String) -> (status: Int, commentary: String) {
        switch metricType {
        case "Metrics":
            return (opportunity.managedObject.value(forKey: "metricsStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "metricsCommentary") as? String ?? "")
        case "Economic Buyer":
            return (opportunity.managedObject.value(forKey: "authorityStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "authorityCommentary") as? String ?? "")
       
        case "Decision Process":
            return (opportunity.managedObject.value(forKey: "timingStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "timingCommentary") as? String ?? "")
        case "Decision Criteria":
            return (opportunity.managedObject.value(forKey: "decisionCriteriaStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "decisionCriteriaCommentary") as? String ?? "")
        case "Identify Pain":
            return (opportunity.managedObject.value(forKey: "needStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "needCommentary") as? String ?? "")
        case "Champion":
            return (opportunity.managedObject.value(forKey: "championStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "championCommentary") as? String ?? "")
        default:
            return (0, "")
        }
    }

    func updateSCUBATANKStatus(for opportunity: OpportunityWrapper, elementType: String, status: Int, commentary: String) {
        // print("Updating SCUBATANK for Opportunity ID: \(opportunity.managedObject.objectID)")
        // print("Element: \(elementType), Status: \(status), Commentary: \(commentary)")
        
        switch elementType {
        case "Solution":
            // print("Updating solution qualification.")
            opportunity.managedObject.setValue(status, forKey: "solutionStatus")
            opportunity.managedObject.setValue(commentary, forKey: "solutionCommentary")
        case "Competition":
            // print("Updating competition qualification.")
            opportunity.managedObject.setValue(status, forKey: "competitionStatus")
            opportunity.managedObject.setValue(commentary, forKey: "competitionCommentary")
        case "Uniques":
            // print("Updating uniques qualification.")
            opportunity.managedObject.setValue(status, forKey: "uniquesStatus")
            opportunity.managedObject.setValue(commentary, forKey: "uniquesCommentary")
        case "Benefits":
            // print("Updating benefits qualification.")
            opportunity.managedObject.setValue(status, forKey: "benefitsStatus")
            opportunity.managedObject.setValue(commentary, forKey: "benefitsCommentary")
        case "Action Plan":
            // print("Updating action plan qualification.")
            opportunity.managedObject.setValue(status, forKey: "actionPlanStatus")
            opportunity.managedObject.setValue(commentary, forKey: "actionPlanCommentary")
        case "Need":
            // print("Updating need qualification.")
            opportunity.managedObject.setValue(status, forKey: "needStatus")
            opportunity.managedObject.setValue(commentary, forKey: "needCommentary")
        case "Authority":
            // print("Updating authority qualification.")
            opportunity.managedObject.setValue(status, forKey: "authorityStatus")
            opportunity.managedObject.setValue(commentary, forKey: "authorityCommentary")
        case "Timescale":
            // print("Updating timescale qualification.")
            opportunity.managedObject.setValue(status, forKey: "timingStatus")
            opportunity.managedObject.setValue(commentary, forKey: "timingCommentary")
        case "Kash":
            // print("Updating Kash qualification.")
            opportunity.managedObject.setValue(status, forKey: "budgetStatus")
            opportunity.managedObject.setValue(commentary, forKey: "budgetCommentary")
        default:
            break
        }
        // print("Update complete. Saving data.")
        saveData()
    }

    func getSCUBATANKStatus(for opportunity: OpportunityWrapper, elementType: String) -> (status: Int, commentary: String) {
        switch elementType {
        case "Solution":
            return (opportunity.managedObject.value(forKey: "solutionStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "solutionCommentary") as? String ?? "")
        case "Competition":
            return (opportunity.managedObject.value(forKey: "competitionStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "competitionCommentary") as? String ?? "")
        case "Uniques":
            return (opportunity.managedObject.value(forKey: "uniquesStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "uniquesCommentary") as? String ?? "")
        case "Benefits":
            return (opportunity.managedObject.value(forKey: "benefitsStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "benefitsCommentary") as? String ?? "")
        case "Action Plan":
            return (opportunity.managedObject.value(forKey: "actionPlanStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "actionPlanCommentary") as? String ?? "")
        case "Kash":
            return (opportunity.managedObject.value(forKey: "budgetStatus") as? Int ?? 0,
                    opportunity.managedObject.value(forKey: "budgetCommentary") as? String ?? "")
        default:
            return (0, "")
        }
    }

    func deleteOpportunity(opportunity: OpportunityWrapper) {
        context.delete(opportunity.managedObject)
        saveData()
    }

    private func saveData() {
        do {
            objectWillChange.send()  // Notify UI observers
            try context.save()
            fetchOpportunities()
        } catch {
            // print("❌ Error saving opportunity: \(error)")
        }
    }
}
