//
//  AIRecommendationManager.swift
//  SalesDiver
//
//  Created by Ian Miller on 6/2/25.
//
import Foundation
import CoreData

struct AIRecommendationManager {
    static func generateSalesRecommendation(for meeting: MeetingsEntity, methodology: String, completion: @escaping (String) -> Void) {
        var summary = ""

        if let questions = meeting.questions as? Set<MeetingQuestionEntity> {
            let answered = questions
                .filter { ($0.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
                .map { "Q: \($0.questionText ?? "")\nA: \($0.answer ?? "")" }
                .joined(separator: "\n\n")
            summary += "Meeting Q&A:\n" + answered + "\n\n"
        }

        if let opportunity = meeting.opportunity {
            let wrapper = OpportunityWrapper(managedObject: opportunity)
            summary += "Qualification Summary:\n"

            switch methodology {
            case "BANT":
                summary += """
                BANT Qualification:
                • Budget: \(wrapper.budgetStatus) — \(wrapper.budgetCommentary)
                • Authority: \(wrapper.authorityStatus) — \(wrapper.authorityCommentary)
                • Need: \(wrapper.needStatus) — \(wrapper.needCommentary)
                • Timing: \(wrapper.timingStatus) — \(wrapper.timingCommentary)
                """
            case "MEDDIC":
                summary += """
                MEDDIC Qualification:
                • Metrics: \(wrapper.metricsStatus) — \(wrapper.metricsCommentary)
                • Economic Buyer: \(wrapper.authorityStatus) — \(wrapper.authorityCommentary)
                • Decision Criteria: \(wrapper.decisionCriteriaStatus) — \(wrapper.decisionCriteriaCommentary)
                • Decision Process: \(wrapper.timingStatus) — \(wrapper.timingCommentary)
                • Identify Pain: \(wrapper.needStatus) — \(wrapper.needCommentary)
                • Champion: \(wrapper.championStatus) — \(wrapper.championCommentary)
                """
            case "SCUBATANK":
                summary += """
                SCUBATANK Qualification:
                • Solution: \(wrapper.solutionStatus) — \(wrapper.solutionCommentary)
                • Competition: \(wrapper.competitionStatus) — \(wrapper.competitionCommentary)
                • Uniques: \(wrapper.uniquesStatus) — \(wrapper.uniquesCommentary)
                • Benefits: \(wrapper.benefitsStatus) — \(wrapper.benefitsCommentary)
                • Authority: \(wrapper.authorityStatus) — \(wrapper.authorityCommentary)
                • Timescale: \(wrapper.timingStatus) — \(wrapper.timingCommentary)
                • Action Plan: \(wrapper.actionPlanStatus) — \(wrapper.actionPlanCommentary)
                • Need: \(wrapper.needStatus) — \(wrapper.needCommentary)
                • Kash: \(wrapper.budgetStatus) — \(wrapper.budgetCommentary)
                """
            default:
                summary += "Unknown methodology."
            }
        }

        let prompt = """
        This data represents the latest sales meeting between a Managed service provider sales person and their prospect, as well as the sales person's latest qualification assessment. Given this, what would be the logical next step for the sales person to do? Please create a recommendation for the sales person for logical next steps. This can include qualifying out of the deal if the qualification status is poor and little progress is being made.

        \(summary)
        """

        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            completion("⚠️ OpenAI API key is not set.")
            return
        }

        let model = UserDefaults.standard.string(forKey: "openAISelectedModel") ?? "gpt-4"

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant for sales strategy in the managed IT services space."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 400
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let data = data,
                   let result = try? JSONDecoder().decode(OpenAIResponse.self, from: data),
                   let message = result.choices.first?.message.content {
                    completion(message.trimmingCharacters(in: .whitespacesAndNewlines))
                } else if let error = error {
                    completion("❌ Request failed: \(error.localizedDescription)")
                } else {
                    completion("⚠️ Failed to retrieve recommendation from OpenAI.")
                }
            }
        }.resume()
    }

    static func generateOpportunityGuidance(for opportunity: OpportunityWrapper, completion: @escaping (String) -> Void) {
        let methodology = UserDefaults.standard.string(forKey: "selectedMethodology") ?? "Unknown"
        var summary = "Qualification Summary:\n"

        switch methodology {
        case "BANT":
            summary += """
            BANT Qualification:
            • Budget: \(opportunity.budgetStatus) — \(opportunity.budgetCommentary)
            • Authority: \(opportunity.authorityStatus) — \(opportunity.authorityCommentary)
            • Need: \(opportunity.needStatus) — \(opportunity.needCommentary)
            • Timing: \(opportunity.timingStatus) — \(opportunity.timingCommentary)
            """
        case "MEDDIC":
            summary += """
            MEDDIC Qualification:
            • Metrics: \(opportunity.metricsStatus) — \(opportunity.metricsCommentary)
            • Economic Buyer: \(opportunity.authorityStatus) — \(opportunity.authorityCommentary)
            • Decision Criteria: \(opportunity.decisionCriteriaStatus) — \(opportunity.decisionCriteriaCommentary)
            • Decision Process: \(opportunity.timingStatus) — \(opportunity.timingCommentary)
            • Identify Pain: \(opportunity.needStatus) — \(opportunity.needCommentary)
            • Champion: \(opportunity.championStatus) — \(opportunity.championCommentary)
            """
        case "SCUBATANK":
            summary += """
            SCUBATANK Qualification:
            • Solution: \(opportunity.solutionStatus) — \(opportunity.solutionCommentary)
            • Competition: \(opportunity.competitionStatus) — \(opportunity.competitionCommentary)
            • Uniques: \(opportunity.uniquesStatus) — \(opportunity.uniquesCommentary)
            • Benefits: \(opportunity.benefitsStatus) — \(opportunity.benefitsCommentary)
            • Authority: \(opportunity.authorityStatus) — \(opportunity.authorityCommentary)
            • Timescale: \(opportunity.timingStatus) — \(opportunity.timingCommentary)
            • Action Plan: \(opportunity.actionPlanStatus) — \(opportunity.actionPlanCommentary)
            • Need: \(opportunity.needStatus) — \(opportunity.needCommentary)
            • Kash: \(opportunity.budgetStatus) — \(opportunity.budgetCommentary)
            """
        default:
            summary += "Unknown methodology."
        }

        let prompt = """
        This data represents the latest sales opportunity and its current qualification status. Based on this data, what would be the logical next step for the sales person? Please provide a recommendation. The sales person is in the managed IT services space.

        \(summary)
        """

        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            completion("⚠️ OpenAI API key is not set.")
            return
        }

        let model = UserDefaults.standard.string(forKey: "openAISelectedModel") ?? "gpt-4"

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant for sales strategy in the managed IT services space."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 400
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let data = data,
                   let result = try? JSONDecoder().decode(OpenAIResponse.self, from: data),
                   let message = result.choices.first?.message.content {
                    completion(message.trimmingCharacters(in: .whitespacesAndNewlines))
                } else if let error = error {
                    completion("❌ Request failed: \(error.localizedDescription)")
                } else {
                    completion("⚠️ Failed to retrieve recommendation from OpenAI.")
                }
            }
        }.resume()
    }

    static func generateCompanyProfile(for company: CompanyWrapper, completion: @escaping (String) -> Void) {
        var companyInfo = """
Please analyze the following company using publicly available information and insights from its website (if known). Organize your findings in these sections:
• Company Summary: What the company does and produces
• Estimated Revenue
• Number of Employees
• Number of Locations
• Potential Challenges (industry trends, economic conditions, competition, etc.)
• Business Opportunities (growth, diversification, efficiency)
• Opportunities for IT to enhance the business

Company Name: \(company.name)
"""

        let website = company.webAddress
        if !website.isEmpty {
            companyInfo += "\nWebsite: \(website)"
        }
        let address = company.address
        if !address.isEmpty {
            companyInfo += "\nLocation: \(address)"
        }

        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            completion("⚠️ OpenAI API key is not set.")
            return
        }

        let model = UserDefaults.standard.string(forKey: "openAISelectedModel") ?? "gpt-4"

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a research assistant helping a Managed Service Provider learn about their client company."],
                ["role": "user", "content": companyInfo]
            ],
            "temperature": 0.7,
            "max_tokens": 500
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let data = data,
                   let result = try? JSONDecoder().decode(OpenAIResponse.self, from: data),
                   let message = result.choices.first?.message.content {
                    completion(message.trimmingCharacters(in: .whitespacesAndNewlines))
                } else if let error = error {
                    completion("❌ Request failed: \(error.localizedDescription)")
                } else {
                    completion("⚠️ Failed to retrieve company profile from OpenAI.")
                }
            }
        }.resume()
    }
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable {
        let message: Message
    }
    struct Message: Codable {
        let content: String
    }
}
