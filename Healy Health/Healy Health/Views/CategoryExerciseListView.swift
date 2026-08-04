import SwiftUI

struct CategoryExerciseListView: View {
    let routineId: UUID
    let workoutId: UUID
    let category: ExerciseCategory

    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddCustom = false
    @State private var showingLibrary = false
    @State private var addExerciseErrorMessage: String?

    private var theme: AppTheme { themeManager.current }

    private var currentWorkout: Workout? {
        store.routines.first(where: { $0.id == routineId })?.workouts.first(where: { $0.id == workoutId })
    }
    private var exercises: [Exercise] {
        currentWorkout?.exercises.filter { $0.category == category } ?? []
    }

    var body: some View {
        ZStack {
            theme.primaryColor.edgesIgnoringSafeArea(.all)

            VStack {
                if exercises.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.system(size: 40))
                            .foregroundColor(theme.onPrimaryText.opacity(0.5))
                        Text("No \(category.displayName) exercises yet.")
                            .font(.custom("ChalkboardSE-Regular", size: 18))
                            .foregroundColor(theme.onPrimaryText.opacity(0.8))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(exercises) { exercise in
                            NavigationLink(destination: EditExerciseView(
                                routineId: routineId, workoutId: workoutId, exerciseId: exercise.id
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.custom("ChalkboardSE-Regular", size: 18))
                                        .foregroundColor(theme.rowText)
                                    Text("\(exercise.targetSets) sets • \(exercise.targetReps) reps")
                                        .font(.custom("ChalkboardSE-Regular", size: 14))
                                        .foregroundColor(theme.secondaryRowText)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(theme.rowBackground)
                        }
                        .onDelete(perform: deleteExercise)
                        .onMove(perform: moveExercises)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(category.displayName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .foregroundColor(theme.onPrimaryText)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(action: { showingAddCustom = true }) {
                    Text("+ Custom")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(theme.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.rowBackground)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                Button(action: { showingLibrary = true }) {
                    Text("Browse Library")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(theme.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.rowBackground)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .sheet(isPresented: $showingAddCustom) {
            AddCustomExerciseView(
                presetCategory: category,
                isNameInUse: { name in
                    currentWorkout.map {
                        WorkoutPlanningValidation.hasDuplicateExerciseName(name, in: $0.exercises)
                    } ?? false
                },
                onAdd: appendExercise
            )
        }
        .sheet(isPresented: $showingLibrary) {
            ExerciseSelectionView(presetCategory: category, onAdd: appendExercise)
        }
        .alert("Can’t Add Exercise", isPresented: Binding(
            get: { addExerciseErrorMessage != nil },
            set: { if !$0 { addExerciseErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { addExerciseErrorMessage = nil }
        } message: {
            Text(addExerciseErrorMessage ?? "")
        }
    }

    private func appendExercise(_ exercise: Exercise) {
        if case .failure(let error) = store.addExercise(
            routineId: routineId,
            workoutId: workoutId,
            exercise: exercise
        ) {
            addExerciseErrorMessage = error.localizedDescription
        }
    }

    private func deleteExercise(offsets: IndexSet) {
        guard let routine = store.routines.first(where: { $0.id == routineId }),
              let wIndex = routine.workouts.firstIndex(where: { $0.id == workoutId }) else { return }
        let globalIndices = offsets.map { exercises[$0].id }
            .compactMap { id in routine.workouts[wIndex].exercises.firstIndex(where: { $0.id == id }) }
        var updated = routine
        for i in globalIndices.sorted(by: >) { updated.workouts[wIndex].exercises.remove(at: i) }
        store.updateRoutine(updated)
    }

    private func moveExercises(fromOffsets: IndexSet, toOffset: Int) {
        store.moveExercises(
            routineId: routineId,
            workoutId: workoutId,
            orderedExerciseIDs: exercises.map(\.id),
            fromOffsets: fromOffsets,
            toOffset: toOffset
        )
    }
}
