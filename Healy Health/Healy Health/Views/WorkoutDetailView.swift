import SwiftUI

struct WorkoutDetailView: View {
    let routineId: UUID
    var workout: Workout
    @EnvironmentObject var store: RoutineStore
    
    @State private var showingExerciseLibrary = false
    @State private var showingEditWorkout = false
    @State private var editWorkoutName = ""
    @State private var editWorkoutFocus = ""
    
    private var currentWorkout: Workout? {
        store.routines.first(where: { $0.id == routineId })?.workouts.first(where: { $0.id == workout.id })
    }
    
    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)
            
            VStack {
                if let currentWorkout = currentWorkout {
                    if currentWorkout.exercises.isEmpty {
                        Text("No exercises in this workout.")
                            .foregroundColor(.white)
                            .padding()
                    } else {
                        List {
                            ForEach(currentWorkout.exercises) { exercise in
                                NavigationLink(destination: EditExerciseView(
                                    routineId: routineId,
                                    workoutId: workout.id,
                                    exerciseId: exercise.id)
                                ) {
                                    VStack(alignment: .leading) {
                                        Text(exercise.name)
                                            .font(.custom("ChalkboardSE-Regular", size: 18))
                                            .foregroundColor(.black)
                                        Text("\(exercise.targetSets) sets • \(exercise.targetReps) reps")
                                            .font(.custom("ChalkboardSE-Regular", size: 14))
                                            .foregroundColor(Color(white: 0.3))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.white)
                            }
                            .onDelete(perform: deleteExercise)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(currentWorkout?.name ?? "Workout")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        if let currentWorkout = currentWorkout {
                            editWorkoutName = currentWorkout.name
                            editWorkoutFocus = currentWorkout.focus
                            showingEditWorkout = true
                        }
                    }
                    .foregroundColor(.white)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showingExerciseLibrary = true }) {
                    Text("Add Exercise")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .alert("Edit Workout", isPresented: $showingEditWorkout) {
                TextField("Workout Name", text: $editWorkoutName)
                TextField("Focus (e.g. Legs)", text: $editWorkoutFocus)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if !editWorkoutName.isEmpty, let currentRoutine = store.routines.first(where: { $0.id == routineId }),
                       let wIndex = currentRoutine.workouts.firstIndex(where: { $0.id == workout.id }) {
                        var updatedRoutine = currentRoutine
                        updatedRoutine.workouts[wIndex].name = editWorkoutName
                        updatedRoutine.workouts[wIndex].focus = editWorkoutFocus
                        store.updateRoutine(updatedRoutine)
                    }
                }
            }
            .sheet(isPresented: $showingExerciseLibrary) {
                ExerciseSelectionView(onAdd: { newExercise in
                    if let currentRoutine = store.routines.first(where: { $0.id == routineId }),
                       let wIndex = currentRoutine.workouts.firstIndex(where: { $0.id == workout.id }) {
                        var updatedRoutine = currentRoutine
                        updatedRoutine.workouts[wIndex].exercises.append(newExercise)
                        store.updateRoutine(updatedRoutine)
                    }
                })
            }
        }
    }
    
    private func deleteExercise(offsets: IndexSet) {
        if let currentRoutine = store.routines.first(where: { $0.id == routineId }),
           let wIndex = currentRoutine.workouts.firstIndex(where: { $0.id == workout.id }) {
            var updatedRoutine = currentRoutine
            var updatedWorkout = updatedRoutine.workouts[wIndex]
            
            offsets.forEach { index in
                updatedWorkout.exercises.remove(at: index)
            }
            
            updatedRoutine.workouts[wIndex] = updatedWorkout
            store.updateRoutine(updatedRoutine)
        }
    }
}
