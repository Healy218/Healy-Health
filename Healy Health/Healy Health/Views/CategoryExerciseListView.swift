import SwiftUI

/// Shows exercises for one category (e.g. Stretch) within a specific workout.
struct CategoryExerciseListView: View {
    let routineId: UUID
    let workoutId: UUID
    let category: ExerciseCategory

    @EnvironmentObject var store: RoutineStore
    @State private var showingAddCustom = false
    @State private var showingLibrary = false

    private var currentWorkout: Workout? {
        store.routines.first(where: { $0.id == routineId })?.workouts.first(where: { $0.id == workoutId })
    }

    private var exercises: [Exercise] {
        currentWorkout?.exercises.filter { $0.category == category } ?? []
    }

    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)

            VStack {
                if exercises.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No \(category.displayName) exercises yet.")
                            .font(.custom("ChalkboardSE-Regular", size: 18))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(exercises) { exercise in
                            NavigationLink(destination: EditExerciseView(
                                routineId: routineId,
                                workoutId: workoutId,
                                exerciseId: exercise.id
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.custom("ChalkboardSE-Regular", size: 18))
                                        .foregroundColor(.black)
                                    Text("\(exercise.targetSets) sets • \(exercise.targetReps) reps")
                                        .font(.custom("ChalkboardSE-Regular", size: 14))
                                        .foregroundColor(Color(white: 0.4))
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
        .navigationTitle(category.displayName)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(action: { showingAddCustom = true }) {
                    Text("+ Custom")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                Button(action: { showingLibrary = true }) {
                    Text("Browse Library")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .sheet(isPresented: $showingAddCustom) {
            AddCustomExerciseView(presetCategory: category, onAdd: { newExercise in
                appendExercise(newExercise)
            })
        }
        .sheet(isPresented: $showingLibrary) {
            ExerciseSelectionView(presetCategory: category, onAdd: { newExercise in
                appendExercise(newExercise)
            })
        }
    }

    private func appendExercise(_ exercise: Exercise) {
        guard let routine = store.routines.first(where: { $0.id == routineId }),
              let wIndex = routine.workouts.firstIndex(where: { $0.id == workoutId }) else { return }
        var updated = routine
        updated.workouts[wIndex].exercises.append(exercise)
        store.updateRoutine(updated)
    }

    private func deleteExercise(offsets: IndexSet) {
        guard let routine = store.routines.first(where: { $0.id == routineId }),
              let wIndex = routine.workouts.firstIndex(where: { $0.id == workoutId }) else { return }

        // Map offsets in the filtered list back to global indices
        let globalIndices = offsets
            .map { exercises[$0].id }
            .compactMap { id in routine.workouts[wIndex].exercises.firstIndex(where: { $0.id == id }) }

        var updated = routine
        for i in globalIndices.sorted(by: >) {
            updated.workouts[wIndex].exercises.remove(at: i)
        }
        store.updateRoutine(updated)
    }
}
