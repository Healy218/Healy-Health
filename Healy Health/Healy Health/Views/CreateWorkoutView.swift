import SwiftUI

struct CreateWorkoutView: View {
    @State private var workoutName = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var showExerciseSelection = false
    
    // We'll use this array to temporarily hold the exercises for our custom day
    // Once the user enters the workout, we create a WorkoutDay to pass to the WorkoutDayView.
    @State private var navigateToWorkout = false
    @State private var customWorkoutDay: WorkoutDay?
    
    var isWorkoutValid: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedExercises.isEmpty
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Workout Details").foregroundColor(.white)) {
                    TextField("Workout Name (e.g., Pull Day)", text: $workoutName)
                        .foregroundColor(.black)
                        .listRowBackground(Color.white)
                }
                
                Section(header: Text("Exercises").foregroundColor(.white)) {
                    ForEach(selectedExercises) { exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).font(.headline).foregroundColor(.black)
                            Text("\(exercise.targetSets) sets x \(exercise.targetReps) reps @ \(exercise.weightDisplay)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteExercise)
                    .listRowBackground(Color.white)
                    
                    Button(action: {
                        showExerciseSelection = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                        .foregroundColor(.black)
                    }
                    .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.blue.ignoresSafeArea())
            
            Button(action: {
                startWorkout()
            }) {
                Text("Start Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isWorkoutValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!isWorkoutValid)
            .padding()
        }
        .navigationTitle("Create Workout")
        .sheet(isPresented: $showExerciseSelection) {
            ExerciseSelectionView(onAdd: { newExercise in
                selectedExercises.append(newExercise)
            })
        }
        .navigationDestination(isPresented: $navigateToWorkout) {
            if let customDay = customWorkoutDay, let bindingDay = Binding($customWorkoutDay) {
                // WorkoutDayView expects a Binding to a WorkoutDay.
                WorkoutDayView(day: bindingDay)
            } else {
                Text("Error Loading Workout")
            }
        }
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        selectedExercises.remove(atOffsets: offsets)
    }
    
    private func startWorkout() {
        let day = WorkoutDay(
            id: UUID(),
            dayName: workoutName,
            focus: "Custom Workout",
            exercises: selectedExercises
        )
        WorkoutSchedule.shared.addCustomWorkout(day)
        customWorkoutDay = day
        navigateToWorkout = true
    }
}

#Preview {
    NavigationStack {
        CreateWorkoutView()
    }
}
