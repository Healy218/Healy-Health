import SwiftUI

struct WorkoutDayView: View {
    @Binding var day: WorkoutDay
    
    @State private var showTimer = false
    @State private var selectedExerciseId: UUID?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Hidden Navigation Link for programmatic navigation
            // Logic handled by .navigationDestination modifier below
            
            List {
                Section(header: Text(day.focus).foregroundColor(.white)) {
                    ForEach($day.exercises) { $exercise in
                        Button(action: {
                            selectedExerciseId = exercise.id
                        }) {
                            ExerciseRowView(exercise: $exercise)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(Color.white)
                    }
                }
                
                if day.exercises.allSatisfy({ $0.isCompleted }) {
                    Section {
                        Button(action: {
                            WorkoutSchedule.shared.finishWorkout(day: day)
                            dismiss()
                        }) {
                            Text("Finish Workout")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.blue.ignoresSafeArea())
        .navigationTitle(day.dayName)
        // Add modern navigation destination
        .navigationDestination(isPresented: Binding(
            get: { selectedExerciseId != nil },
            set: { if !$0 { selectedExerciseId = nil } }
        )) {
            if let selectedId = selectedExerciseId,
               let index = day.exercises.firstIndex(where: { $0.id == selectedId }) {
                ExerciseDetailView(exercise: $day.exercises[index], onSave: WorkoutSchedule.shared.saveSchedule)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showTimer.toggle() }) {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(Circle())
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
        WorkoutDayView(day: .constant(WorkoutSchedule.shared.fullSchedule[0]))
    }
}
