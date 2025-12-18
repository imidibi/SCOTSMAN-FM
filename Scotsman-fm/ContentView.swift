import SwiftUI
import CoreData
// No import needed — just ensure FollowUpsView.swift is in the same target

struct ContentView: View {
    @StateObject private var companyViewModel = CompanyViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackgroundView()
                VStack(spacing: 40) {
                    BrandHeaderView()
                        .padding(.top, 20)
                    
                    GridView(companyViewModel: companyViewModel)

                    Spacer()
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: HelpView()) {
                            Image(systemName: "questionmark.circle")
                                .imageScale(.large)
                                .padding(5)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView(companyViewModel: companyViewModel)) {
                            Image(systemName: "gearshape.fill")
                                .imageScale(.large)
                                .padding(5)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Brand Background
struct BrandBackgroundView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.black, Color.black.opacity(0.92)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Brand Colors
enum BrandColors {
    static let red = Color(red: 0.90, green: 0.12, blue: 0.17)
    static let green = Color(red: 0.20, green: 0.74, blue: 0.33)
    static let yellow = Color(red: 0.98, green: 0.76, blue: 0.18)
    static let tile = Color(white: 0.12)
    static let tileBorder = Color.white.opacity(0.10)
    static let textSecondary = Color.white.opacity(0.75)
}

// MARK: - Brand Header
struct BrandHeaderView: View {
    private let logoImage: UIImage? = UIImage(named: "SCOTSMAN_RAG_logo")

    var body: some View {
        VStack(spacing: 14) {
            if let logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 520)
                    .padding(.horizontal)
            } else {
                // Fallback if the logo asset isn't present yet
                Text("SCOTSMAN")
                    .font(.system(size: 42, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .tracking(4)
            }

            Text("Field Manual")
                .font(.headline)
                .foregroundColor(BrandColors.textSecondary)
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Grid Menu View
struct GridView: View {
    let companyViewModel: CompanyViewModel

    struct MenuItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let destination: () -> AnyView
    }

    private func makeMenuItems() -> [MenuItem] {
        [
            MenuItem(name: "Companies", icon: "building.2.fill") { AnyView(CompanyDataView(viewModel: companyViewModel)) },
            MenuItem(name: "Services", icon: "desktopcomputer") { AnyView(ProductDataView()) },
            MenuItem(name: "Opportunities", icon: "chart.bar.fill") { AnyView(OpportunityDataView()) },
            MenuItem(name: "Contacts", icon: "person.2.fill") { AnyView(ContactsView()) },
            MenuItem(name: "Meetings", icon: "calendar.badge.clock") { AnyView(ViewMeetingsView()) },
            MenuItem(name: "Follow Ups", icon: "checkmark.circle.fill") { AnyView(FollowUpsView()) },
            MenuItem(name: "Assessment Builder", icon: "square.and.pencil") { AnyView(AssessmentsHubView()) },
            MenuItem(name: "Questions", icon: "questionmark.circle.fill") { AnyView(QuestionsView()) },
            MenuItem(name: "Client Assessments", icon: "checklist") { AnyView(ClientAssessmentsHubView()) }
        ]
    }

    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        let items = makeMenuItems()
        LazyVGrid(columns: columns, spacing: 40) {
            ForEach(items) { item in
                NavigationLink(destination: item.destination()) {
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [BrandColors.red.opacity(0.9), BrandColors.green.opacity(0.9), BrandColors.yellow.opacity(0.9)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 92, height: 92)

                            Image(systemName: item.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 42, height: 42)
                                .foregroundColor(.black.opacity(0.85))
                        }

                        Text(item.name)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .frame(width: 180, height: 180)
                    .background(BrandColors.tile)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(BrandColors.tileBorder, lineWidth: 1)
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
                }
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: - Help View
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                GroupBox(label: Text("🤿 Welcome to SCOTSMAN").font(.title2).bold()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Our goal is to help you dive into your sales pipeline and to help you qualify and close the treasure therein!")

                        Text("SCOTSMAN is based on the new or existing companies you want to sell to, the contacts in those companies you will meet and interact with, the services you plan to sell to them, all wrapped up in the opportunities you hope to close.")

                        Text("The odds of closing those opportunities increase the better you qualify those opportunities. Qualification is achieved by asking questions to better understand your position. SCOTSMAN therefore allows you to create a customized list of questions to ask in your sales meetings to ensure you really understand where you stand.")

                        Text("Qualification is important in not only reflecting where you are, but also in helping you build an action plan to increase your chances of closing the deal. Qualification should not just record what you have achieved to date, but help to actively plan your next steps to raise your chances of winning the opportunity.")
                    }
                    .padding()
                }

                GroupBox(label: Text("🧭 SCOTSMAN Methodologies").font(.title2).bold()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SCOTSMAN offers three qualification methodologies, with differing levels of complexity and thoroughness. Those methodologies are:")

                        Text("• BANT – Budget, Authority, Need and Timescale")
                        Text("• MEDDIC – Metrics, Economic Buyer, Decision Maker, Decision Process, Identify Pain, Champion")
                        Text("• SCOTSMAN – Solution, Competition, Originality, Timescale, Size, Money, Authority, Need")

                        Text("The first two are industry standard methodologies and the third is the recommended and most complete methodology - SCOTSMAN! Please select your preferred methodology in settings (the gear icon).")

                        Text("BANT is very effective for opportunities that have a short deal cycle and which are not overly complex from a decision structure. It is used extensively by SDR’s in the SaaS software and online selling marketplace as it hits to the heart of the matter.")

                        Text("MEDDIC is very good for larger deals with a more complex decision structure and is oriented to digging deep into client pain, identifying it and structuring the proposal around relieving that pain.")

                        Text("SCOTSMAN is a further level of refinement and is focused on more competitive deals where understanding the competition, articulating your originality, and validating size, money, and authority can drive differentiation.")
                    }
                    .padding()
                }

                GroupBox(label: Text("🔍 The Qualification Process").font(.title2).bold()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SalesDiver offers an icon for each element in these methodologies to allow you to track your progress on each deal. All red shows a totally unqualified deal whereas all green is a deal you should win!")

                        Text("The icons for each qualification area can be red for unqualified, yellow if you are making progress but not yet fully satisfied, and green if you are confident in that item. Be honest and track your progress towards more successfully closed deals. Use the AI recommendation engine if you need some additional guidance!")

                        Text("Happy Selling!")
                            .font(.headline)
                            .padding(.top)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Help")
    }
}
