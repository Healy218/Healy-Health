import SwiftUI

struct WorkoutDayView: View {
    @State var day: WorkoutDay
    
    @State private var showTimer = false
    
    var body: some View {
        List {
            Section(header: Text(day.focus)) {
                ForEach($day.exercises) { $exercise in
                    ExerciseRowView(exercise: $exercise)
                }
            }
        }
        .navigationTitle(day.dayName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showTimer.toggle() }) {
                    Image(systemName: "timer")
                }
            }
        }
        .sheet(isPresented: $showTimer) {
            RestTimerView()
                .presentationDetents([.height(250)])
        }
        // In a real app with persistence, we'd save changes here or use a ViewModel
    }
}

#Preview {
    NavigationView {
        WorkoutDayView(day: WorkoutSchedule.shared.fullSchedule[0])
    }
}
