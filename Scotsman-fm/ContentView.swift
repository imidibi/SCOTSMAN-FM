import SwiftUI
import CoreData
// No import needed — just ensure FollowUpsView.swift is in the same target

struct ContentView: View {
    @AppStorage("disableBubbleAnimation") private var disableBubbleAnimation: Bool = false
    @StateObject private var companyViewModel = CompanyViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                WaterBackgroundView() // ✅ Added Water Background
                if !disableBubbleAnimation {
                    BubbleLayerView() // 🫧 animated bubbles beneath content
                }
                VStack(spacing: 40) {
                    Text("SCOTSMAN.AI")
                        .font(.largeTitle)
                        .bold()
                    
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

// MARK: - Water Background View
struct WaterBackgroundView: View {
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.7)]),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                WaveShape()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 200)
                    .offset(y: -50), alignment: .top
            )
    }
}

// MARK: - Wave Shape
struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height * 0.7))
        path.addCurve(to: CGPoint(x: width, y: height * 0.7),
                      control1: CGPoint(x: width * 0.25, y: height * 0.5),
                      control2: CGPoint(x: width * 0.75, y: height * 0.9))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        
        return path
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
                        Image(systemName: item.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)

                        Text(item.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(width: 180, height: 180)
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .shadow(radius: 5)
                }
            }
        }
    }
}

// MARK: - Bubble Animation
struct Bubble: Identifiable {
    let id = UUID()
    var x: CGFloat
    var size: CGFloat
    var speed: Double
    var yOffset: CGFloat = UIScreen.main.bounds.height
}

struct BubbleLayerView: View {
    @State private var bubbles: [Bubble] = []

    var body: some View {
        ZStack {
            ForEach(bubbles) { bubble in
                Circle()
                    .fill(bubbleColor)
                    .frame(width: bubble.size, height: bubble.size)
                    .position(x: bubble.x, y: bubble.yOffset)
                    .opacity(1.0)
                    .onAppear {
                        withAnimation(.easeOut(duration: bubble.speed)) {
                            if let index = bubbles.firstIndex(where: { $0.id == bubble.id }) {
                                bubbles[index].yOffset = 150 // stop below wave crest
                                bubbles[index].x += CGFloat.random(in: -60...60)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + bubble.speed) {
                            bubbles.removeAll { $0.id == bubble.id }
                        }
                    }
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                let newBubble = Bubble(
                    x: UIScreen.main.bounds.width / 2,
                    size: CGFloat.random(in: 8...18),
                    speed: Double.random(in: 4...7)
                )
                bubbles.append(newBubble)
            }
        }
    }

    private var bubbleColor: Color {
        Color(UIColor { trait in
            switch trait.userInterfaceStyle {
            case .dark:
                // Match top gradient color of the background in dark mode
                return UIColor.systemBlue.withAlphaComponent(0.25)
            default:
                // Match top gradient color of the background in light mode
                return UIColor.white.withAlphaComponent(0.25)
            }
        })
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

                GroupBox(label: Text("🤿 Welcome to SalesDiver").font(.title2).bold()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Our goal is to help you dive into your sales pipeline and to help you qualify and close the treasure therein!")

                        Text("SalesDiver is based on the new or existing companies you want to sell to, the contacts in those companies you will meet and interact with, the services you plan to sell to them, all wrapped up in the opportunities you hope to close.")

                        Text("The odds of closing those opportunities increase the better you qualify those opportunities. Qualification is achieved by asking questions to better understand your position. SalesDiver therefore allows you to create a customized list of questions to ask in your sales meetings to ensure you really understand where you stand.")

                        Text("Qualification is important in not only reflecting where you are, but also in helping you build an action plan to increase your chances of closing the deal. Qualification should not just record what you have achieved to date, but help to actively plan your next steps to raise your chances of winning the opportunity.")
                    }
                    .padding()
                }

                GroupBox(label: Text("🧭 SalesDiver Methodologies").font(.title2).bold()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SalesDiver offers three qualification methodologies, with differing levels of complexity and thoroughness. Those methodologies are:")

                        Text("• BANT – Budget, Authority, Need and Timescale")
                        Text("• MEDDIC – Metrics, Economic Buyer, Decision Maker, Decision Process, Identify Pain, Champion")
                        Text("• SCUBATANK – Solution, Competition, Uniques, Benefits, Authority, Timescale, Action Plan, Need and Kash.")

                        Text("The first two are industry standard methodologies and the third is a SalesDiver special! Please select your preferred methodology in settings (the gear icon).")

                        Text("BANT is very effective for opportunities that have a short deal cycle and which are not overly complex from a decision structure. It is used extensively by SDR’s in the SaaS software and online selling marketplace as it hits to the heart of the matter.")

                        Text("MEDDIC is very good for larger deals with a more complex decision structure and is oriented to digging deep into client pain, identifying it and structuring the proposal around relieving that pain.")

                        Text("SCUBATANK is a further level of refinement and is focused on more competitive deals where understanding the competition, articulating your unique capabilities and benefits, and engaging the client as much as possible through an action plan can drive differentiation.")
                    }
                    .padding()
                }

                GroupBox(label: Text("🔍 The Qualification Process").font(.title2).bold()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SalesDiver offers an icon for each element in these methodologies to allow you to track your progress on each deal. All red shows a totally unqualified deal whereas all green is a deal you should win!")

                        Text("The icons for each qualification area can be red for unqualified, yellow if you are making progress but not yet fully satisfied, and green if you are confident in that item. Be honest and track your progress towards more successfully closed deals. Use the AI recommendation engine if you need some additional guidance!")

                        Text("Happy SalesDiving!")
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

