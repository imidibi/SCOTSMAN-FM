//import SwiftUI
//
//
//struct MeetingsView: View {
//    @State private var selectedMeeting: MeetingsEntity? = nil
//    
//    let columns = [
//        GridItem(.flexible(), spacing: 20),
//        GridItem(.flexible(), spacing: 20),
//        GridItem(.flexible(), spacing: 20)
//    ]
//    
//    var body: some View {
//        ZStack {
//            WaterBackgroundView() // Apply the WaterBackgroundView for the blue gradient and wave effect
//            
//            VStack(alignment: .leading, spacing: 20) {
//                HStack {
//                    Spacer()
//                    Text("Meetings")
//                        .font(.largeTitle)
//                        .fontWeight(.bold)
//                    Spacer()
//                }
//                .padding(.top, 40)
//
//                LazyVGrid(columns: columns, spacing: 40) {
//                    NavigationLink(destination: PlanMeetingView()) {
//                        MenuButton(icon: "calendar.badge.plus", label: "Plan")
//                    }
//
////                    if let selectedMeeting = selectedMeeting {
////                        NavigationLink(destination: RecordMeetingView(meeting: selectedMeeting)) {
////                            MenuButton(icon: "pencil.and.outline", label: "Record")
////                        }
////                    
////                        MenuButton(icon: "pencil.and.outline", label: "Record")
////                    }
//
//                    NavigationLink(destination: ViewMeetingsView()) {
//                        MenuButton(icon: "doc.text.magnifyingglass", label: "View")
//                    }
//                }
//                .padding(.horizontal)
//                Spacer()
//            }
//        }
//    }
//}
//
//struct MenuButton: View {
//    var icon: String
//    var label: String
//
//    var body: some View {
//        VStack {
//            Image(systemName: icon)
//                .resizable()
//                .scaledToFit()
//                .frame(width: 80, height: 80)
//                .foregroundColor(.blue)
//
//            Text(label)
//                .font(.headline)
//                .foregroundColor(.primary)
//        }
//        .padding()
//        .frame(width: 180, height: 180)
//        .background(Color(.systemGray6))
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}
