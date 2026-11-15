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
    @State private var pendingExerciseDeletionIDs: Set<UUID> = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                            .foregroundColor(theme.disabledOnPrimaryText)
                        Text("No \(category.displayName) exercises yet.")
                            .font(AppTypography.chalkboard(18, relativeTo: .headline))
                            .foregroundColor(theme.secondaryOnPrimaryText)
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
                                        .font(AppTypography.chalkboard(18, relativeTo: .headline))
                                        .foregroundColor(theme.rowText)
                                    Text("\(exercise.targetSets) sets • \(exercise.targetReps) reps")
                                        .font(AppTypography.chalkboard(14, relativeTo: .subheadline))
                                        .foregroundColor(theme.secondaryRowText)
                                }
                                .padding(.vertical, 4)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(exercise.name)
                                .accessibilityValue("Target \(exercise.targetSets) sets of \(exercise.targetReps) reps.")
                                .accessibilityHint("Opens the exercise configuration. Swipe up or down to delete this exercise.")
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
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) { exerciseAdditionButtons }
                } else {
                    HStack(spacing: 12) { exerciseAdditionButtons }
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
        .confirmationDialog(
            pendingExerciseDeletionIDs.count == 1 ? "Delete Exercise?" : "Delete Exercises?",
            isPresented: Binding(
                get: { !pendingExerciseDeletionIDs.isEmpty },
                set: { if !$0 { pendingExerciseDeletionIDs = [] } }
            ),
            titleVisibility: .visible
        ) {
            Button(
                pendingExerciseDeletionIDs.count == 1 ? "Delete Exercise" : "Delete Exercises",
                role: .destructive,
                action: deletePendingExercises
            )
            Button("Cancel", role: .cancel) { pendingExerciseDeletionIDs = [] }
        } message: {
            Text("This permanently removes the selected exercise and any logged sets in this workout. It can’t be undone.")
        }
    }

    @ViewBuilder
    private var exerciseAdditionButtons: some View {
        Button(action: { showingAddCustom = true }) {
            Text("+ Custom")
                .font(AppTypography.chalkboard(16, relativeTo: .body))
                .foregroundColor(theme.accentColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.rowBackground)
                .cornerRadius(12)
                .shadow(radius: 5)
        }
        .accessibilityLabel("Add custom exercise")
        .accessibilityHint("Creates a new reusable exercise in the \(category.displayName) category.")
        Button(action: { showingLibrary = true }) {
            Text("Browse Library")
                .font(AppTypography.chalkboard(16, relativeTo: .body))
                .foregroundColor(theme.accentColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.rowBackground)
                .cornerRadius(12)
                .shadow(radius: 5)
        }
        .accessibilityLabel("Browse exercise library")
        .accessibilityHint("Choose an exercise to add to the \(category.displayName) category.")
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
        pendingExerciseDeletionIDs = Set(offsets.compactMap {
            exercises.indices.contains($0) ? exercises[$0].id : nil
        })
    }

    private func deletePendingExercises() {
        defer { pendingExerciseDeletionIDs = [] }
        guard let routine = store.routines.first(where: { $0.id == routineId }),
              let wIndex = routine.workouts.firstIndex(where: { $0.id == workoutId }) else { return }
        let globalIndices = pendingExerciseDeletionIDs
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
