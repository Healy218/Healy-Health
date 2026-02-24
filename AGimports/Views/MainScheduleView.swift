import SwiftUI

struct MainScheduleView: View {
    // In a real app, this would be an @StateObject ViewModel
    let schedule = WorkoutSchedule.shared.fullSchedule
    
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        List {
            Section(header: Text("Weekly Schedule")) {
                ForEach(schedule) { day in
                    NavigationLink(destination: WorkoutDayView(day: day)) {
                        VStack(alignment: .leading) {
                            Text(day.dayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(day.focus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Healy Health")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if let url = ExportManager.shared.generateJSONData() {
                        exportURL = url
                        showShareSheet = true
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
}

#Preview {
    NavigationView {
        MainScheduleView()
    }
}
