import SwiftUI

struct MainScheduleView: View {
    @ObservedObject var scheduleData = WorkoutSchedule.shared
    
    // Convert a CompletedWorkout back into a WorkoutDay so we can run it again
    private func workoutDay(from completed: CompletedWorkout) -> WorkoutDay {
        // We reset the 'isCompleted' flag and clear the logs on the exercises
        // so that the user can do this workout afresh.
        let resetExercises = completed.exercises.map { exercise in
            var freshExercise = exercise
            freshExercise.isCompleted = false
            freshExercise.logs.removeAll()
            return freshExercise
        }
        
        return WorkoutDay(
            id: UUID(), // new ID so it doesn't conflict
            dayName: completed.dayName,
            focus: completed.focus,
            exercises: resetExercises
        )
    }
    
    // We bind to computed properties to allow navigation links to work with the generated WorkoutDays
    // However, NavigationLink to a binding requires the items to be in a State/Observed array.
    // For the recent workouts, we'll map them to a State array on appear.
    @State private var recentDays: [WorkoutDay] = []
    
    var body: some View {
        List {
            if !recentDays.isEmpty {
                Section(header: Text("Recent Workouts").foregroundColor(.white)) {
                    ForEach($recentDays) { $day in
                        NavigationLink(destination: WorkoutDayView(day: $day)) {
                            VStack(alignment: .leading) {
                                Text(day.dayName)
                                    .font(.headline)
                                    .foregroundColor(.black)
                                Text(day.focus)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white)
                    }
                }
            } else {
                Section(header: Text("Recent Workouts").foregroundColor(.white)) {
                    Text("No recent workouts completed.")
                        .foregroundColor(.gray)
                        .listRowBackground(Color.white)
                }
            }
            
            if !scheduleData.customWorkouts.isEmpty {
                // Determine the last 3 newly made workouts (reversed so most recent creation, if appended, is first or last)
                // Assuming append means last = newest. We want the 3 newest.
                let newestCustomWorkouts = Array(scheduleData.customWorkouts.suffix(3).reversed())
                
                Section(header: Text("Newly Made Workouts").foregroundColor(.white)) {
                    // Because we reverse and slice, binding directly from indices is complex.
                    // We can just rely on indices of the observed object.
                    // The easiest and safest way in SwiftUI is generating bindings safely:
                    ForEach(newestCustomWorkouts) { recentCustom in
                        if let index = scheduleData.customWorkouts.firstIndex(where: { $0.id == recentCustom.id }) {
                            NavigationLink(destination: WorkoutDayView(day: $scheduleData.customWorkouts[index])) {
                                VStack(alignment: .leading) {
                                    Text(recentCustom.dayName)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    Text("\(recentCustom.exercises.count) Exercises")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.white)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.ignoresSafeArea())
        .navigationTitle("Workout")
        .onAppear {
            updateRecentDays()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func updateRecentDays() {
        // Take the up to 3 most recently completed workouts
        let recents = scheduleData.completedWorkouts.prefix(3)
        recentDays = recents.map { workoutDay(from: $0) }
    }
}

#Preview {
    NavigationView {
        MainScheduleView()
    }
}
