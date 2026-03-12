import SwiftUI

struct WorkoutDetailView: View {
    let routineId: UUID
    var workout: Workout
    @EnvironmentObject var store: RoutineStore

    @State private var showingEditWorkout = false
    @State private var editWorkoutName = ""
    @State private var editWorkoutFocus = ""

    private var currentWorkout: Workout? {
        store.routines.first(where: { $0.id == routineId })?.workouts.first(where: { $0.id == workout.id })
    }

    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)

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
                .foregroundColor(.white)
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
        let exerciseCount = currentWorkout?.exercises.filter { $0.category == category }.count ?? 0

        NavigationLink(destination: CategoryExerciseListView(
            routineId: routineId,
            workoutId: workout.id,
            category: category
        )) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: category.icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .font(.custom("ChalkboardSE-Regular", size: 20))
                        .foregroundColor(.white)
                    Text(exerciseCount == 0 ? "Tap to add exercises" : "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                        .font(.custom("ChalkboardSE-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding()
            .background(Color.white.opacity(0.18))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
