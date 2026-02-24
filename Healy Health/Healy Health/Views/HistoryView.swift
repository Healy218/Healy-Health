import SwiftUI

struct HistoryView: View {
    @ObservedObject var scheduleData = WorkoutSchedule.shared
    
    @State private var showShareSheet = false
    @State private var exportURL: URL?

    var body: some View {
        List {
            if scheduleData.completedWorkouts.isEmpty {
                Text("No completed workouts yet.")
                    .foregroundColor(.gray)
                    .listRowBackground(Color.white)
            } else {
                ForEach(scheduleData.completedWorkouts) { workout in
                    NavigationLink(destination: HistoryDetailView(workout: workout)) {
                        VStack(alignment: .leading) {
                            Text(workout.date.formatted(date: .long, time: .omitted))
                                .font(.headline)
                                .foregroundColor(.black)
                            Text(workout.dayName)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.ignoresSafeArea())
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if let url = ExportManager.shared.generateJSONData() {
                        exportURL = url
                        showShareSheet = true
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
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
        HistoryView()
    }
}
