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

    private var isEditedWorkoutNameValid: Bool {
        (try? WorkoutPlanningValidation.workoutName(editWorkoutName)) != nil
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
                _ = store.updateWorkoutDetails(
                    routineId: routineId,
                    workoutId: workout.id,
                    name: editWorkoutName,
                    focus: editWorkoutFocus
                )
            }
            .disabled(!isEditedWorkoutNameValid)
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
                        .font(AppTypography.chalkboard(20, relativeTo: .title3))
                        .foregroundColor(theme.onPrimaryText)
                    Text(count == 0 ? "Tap to add exercises" : "\(count) exercise\(count == 1 ? "" : "s")")
                        .font(AppTypography.chalkboard(14, relativeTo: .subheadline))
                        .foregroundColor(theme.secondaryOnPrimaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(theme.secondaryOnPrimaryText)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding()
            .background(theme.onPrimaryText.opacity(0.12))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
