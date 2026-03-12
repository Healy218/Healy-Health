import SwiftUI

struct WorkoutDetailView: View {
    let routineId: UUID
    var workout: Workout
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingEditWorkout = false
    @State private var editWorkoutName = ""
    @State private var editWorkoutFocus = ""

    private var theme: AppTheme { themeManager.current }

    private var currentWorkout: Workout? {
        store.routines.first(where: { $0.id == routineId })?.workouts.first(where: { $0.id == workout.id })
    }

    var body: some View {
        ZStack {
            theme.primaryColor.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        categoryCard(category)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(currentWorkout?.name ?? "Workout")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    if let cw = currentWorkout {
                        editWorkoutName = cw.name
                        editWorkoutFocus = cw.focus
                        showingEditWorkout = true
                    }
                }
                .foregroundColor(theme.onPrimaryText)
            }
        }
        .alert("Edit Workout", isPresented: $showingEditWorkout) {
            TextField("Workout Name", text: $editWorkoutName)
            TextField("Focus (e.g. Legs)", text: $editWorkoutFocus)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                guard !editWorkoutName.isEmpty,
                      let routine = store.routines.first(where: { $0.id == routineId }),
                      let wIndex = routine.workouts.firstIndex(where: { $0.id == workout.id }) else { return }
                var updated = routine
                updated.workouts[wIndex].name = editWorkoutName
                updated.workouts[wIndex].focus = editWorkoutFocus
                store.updateRoutine(updated)
            }
        }
    }

    @ViewBuilder
    private func categoryCard(_ category: ExerciseCategory) -> some View {
        let count = currentWorkout?.exercises.filter { $0.category == category }.count ?? 0

        NavigationLink(destination: CategoryExerciseListView(
            routineId: routineId, workoutId: workout.id, category: category
        )) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(theme.onPrimaryText.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: category.icon)
                        .font(.system(size: 22))
                        .foregroundColor(theme.onPrimaryText)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .font(.custom("ChalkboardSE-Regular", size: 20))
                        .foregroundColor(theme.onPrimaryText)
                    Text(count == 0 ? "Tap to add exercises" : "\(count) exercise\(count == 1 ? "" : "s")")
                        .font(.custom("ChalkboardSE-Regular", size: 14))
                        .foregroundColor(theme.onPrimaryText.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(theme.onPrimaryText.opacity(0.6))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding()
            .background(theme.onPrimaryText.opacity(0.12))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
