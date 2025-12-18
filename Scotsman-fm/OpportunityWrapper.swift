import Foundation
import CoreData

class OpportunityWrapper: ObservableObject, Identifiable {
    @Published var managedObject: NSManagedObject

    init(managedObject: NSManagedObject) {
        self.managedObject = managedObject
    }

    var id: NSManagedObjectID { managedObject.objectID }

    // ✅ Use "name" for Opportunity
    var name: String {
        managedObject.value(forKey: "name") as? String ?? "Unnamed Opportunity"
    }

    var closeDate: Date {
        managedObject.value(forKey: "closeDate") as? Date ?? Date()
    }

    // ✅ Use "name" from associated CompanyEntity
    var companyName: String {
        (managedObject.value(forKey: "company") as? NSManagedObject)?
            .value(forKey: "name") as? String ?? "Unknown Company"
    }

    // ✅ Use "name" from associated ProductEntity
    var productName: String {
        (managedObject.value(forKey: "product") as? NSManagedObject)?
            .value(forKey: "name") as? String ?? "Unknown Product"
    }

    var probability: Int {
        managedObject.value(forKey: "probability") as? Int ?? 0
    }

    var monthlyRevenue: Double {
        managedObject.value(forKey: "monthlyRevenue") as? Double ?? 0.0
    }

    var onetimeRevenue: Double {
        managedObject.value(forKey: "onetimeRevenue") as? Double ?? 0.0
    }

    var estimatedValue: Double {
        managedObject.value(forKey: "estimatedValue") as? Double ?? 0.0
    }

    // ✅ BANT Qualification Status
    var budgetStatus: Int {
        managedObject.value(forKey: "budgetStatus") as? Int ?? 0
    }

    var authorityStatus: Int {
        managedObject.value(forKey: "authorityStatus") as? Int ?? 0
    }

    var needStatus: Int {
        managedObject.value(forKey: "needStatus") as? Int ?? 0
    }

    var timingStatus: Int {
        managedObject.value(forKey: "timingStatus") as? Int ?? 0
    }

    // ✅ BANT Qualification Commentary
    var budgetCommentary: String {
        managedObject.value(forKey: "budgetCommentary") as? String ?? ""
    }

    var authorityCommentary: String {
        managedObject.value(forKey: "authorityCommentary") as? String ?? ""
    }

    var needCommentary: String {
        managedObject.value(forKey: "needCommentary") as? String ?? ""
    }

    var timingCommentary: String {
        managedObject.value(forKey: "timingCommentary") as? String ?? ""
    }

    // ✅ MEDDIC Qualification Status
    var metricsStatus: Int {
        managedObject.value(forKey: "metricsStatus") as? Int ?? 0
    }

    var decisionCriteriaStatus: Int {
        managedObject.value(forKey: "decisionCriteriaStatus") as? Int ?? 0
    }

    var championStatus: Int {
        managedObject.value(forKey: "championStatus") as? Int ?? 0
    }

    // ✅ MEDDIC Qualification Commentary
    var metricsCommentary: String {
        managedObject.value(forKey: "metricsCommentary") as? String ?? ""
    }

    var decisionCriteriaCommentary: String {
        managedObject.value(forKey: "decisionCriteriaCommentary") as? String ?? ""
    }

    var championCommentary: String {
        managedObject.value(forKey: "championCommentary") as? String ?? ""
    }

    // ✅ MEDDIC Qualification Status (mapped to BANT fields)
    var economicBuyerStatus: Int { authorityStatus }
    var identifyPainStatus: Int { needStatus }
    var decisionProcessStatus: Int { timingStatus }

    // ✅ MEDDIC Qualification Commentary (mapped to BANT fields)
    var economicBuyerCommentary: String { authorityCommentary }
    var identifyPainCommentary: String { needCommentary }
    var decisionProcessCommentary: String { timingCommentary }

    // ✅ SCUBATANK Qualification Status
    var solutionStatus: Int {
        let value = managedObject.value(forKey: "solutionStatus") as? Int ?? 0
        // print("Accessing solutionStatus: \(value)")
        return value
    }

    var competitionStatus: Int {
        let value = managedObject.value(forKey: "competitionStatus") as? Int ?? 0
        // print("Accessing competitionStatus: \(value)")
        return value
    }

    var uniquesStatus: Int {
        let value = managedObject.value(forKey: "uniquesStatus") as? Int ?? 0
        // print("Accessing uniquesStatus: \(value)")
        return value
    }

    var benefitsStatus: Int {
        let value = managedObject.value(forKey: "benefitsStatus") as? Int ?? 0
        // print("Accessing benefitsStatus: \(value)")
        return value
    }

    var actionPlanStatus: Int {
        let value = managedObject.value(forKey: "actionPlanStatus") as? Int ?? 0
        // print("Accessing actionPlanStatus: \(value)")
        return value
    }

    // ✅ SCUBATANK Qualification Commentary
    var solutionCommentary: String {
        managedObject.value(forKey: "solutionCommentary") as? String ?? ""
    }

    var competitionCommentary: String {
        managedObject.value(forKey: "competitionCommentary") as? String ?? ""
    }

    var uniquesCommentary: String {
        managedObject.value(forKey: "uniquesCommentary") as? String ?? ""
    }

    var benefitsCommentary: String {
        managedObject.value(forKey: "benefitsCommentary") as? String ?? ""
    }

    var actionPlanCommentary: String {
        managedObject.value(forKey: "actionPlanCommentary") as? String ?? ""
    }

    // Expose status value from OpportunityEntity (1: Active, 2: Lost, 3: Closed)
    var status: Int16 {
        let value = managedObject.value(forKey: "status") as? Int16 ?? 0
        // Only allow 1 (Active), 2 (Lost), or 3 (Closed)
        switch value {
        case 1, 2, 3:
            return value
        default:
            return 1 // Default to Active if out of range
        }
    }
}
