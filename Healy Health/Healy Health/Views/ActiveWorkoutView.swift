import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            theme.primaryColor.edgesIgnoringSafeArea(.all)

            if let activeRoutine = store.activeRoutine {
                if let activeWorkout = store.activeWorkout {
                    WorkoutSessionView(routine: activeRoutine, workout: activeWorkout)
                } else {
                    RoutineWorkoutListView(routine: activeRoutine)
                }
            } else {
                VStack {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 80))
                        .foregroundColor(theme.onPrimaryText.opacity(0.5))
                        .padding()
                    Text("No Active Routine")
                        .font(.custom("ChalkboardSE-Regular", size: 24))
                        .bold()
                        .foregroundColor(theme.onPrimaryText)
                    Text("Swipe right on a routine in the Routines tab to start it here.")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(theme.onPrimaryText.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RoutineWorkoutListView: View {
    let routine: Routine
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(routine.name)
                    .font(.custom("ChalkboardSE-Regular", size: 24)).bold().foregroundColor(theme.onPrimaryText)
                Text("Select a workout to begin")
                    .font(.custom("ChalkboardSE-Regular", size: 14)).foregroundColor(theme.onPrimaryText.opacity(0.8))
            }
            .padding().frame(maxWidth: .infinity).background(Color.black.opacity(0.2))

            if routine.workouts.isEmpty {
                Spacer()
                Text("This routine has no workouts yet.\nAdd some in the Routines tab.")
                    .font(.custom("ChalkboardSE-Regular", size: 16))
                    .foregroundColor(theme.onPrimaryText.opacity(0.8))
                    .multilineTextAlignment(.center).padding()
                Spacer()
            } else {
                List {
                    ForEach(routine.workouts) { workout in
                        Button { store.activeWorkoutId = workout.id } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name)
                                        .font(.custom("ChalkboardSE-Regular", size: 20)).foregroundColor(theme.rowText)
                                    Text(workout.focus)
                                        .font(.custom("ChalkboardSE-Regular", size: 14)).foregroundColor(theme.secondaryRowText)
                                    Text("\(workout.exercises.count) exercises")
                                        .font(.custom("ChalkboardSE-Regular", size: 12)).foregroundColor(theme.secondaryRowText)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill").font(.title2).foregroundColor(theme.accentColor)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(theme.rowBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct WorkoutSessionView: View {
    let routine: Routine
    let workout: Workout
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.current }

    private var currentWorkout: Workout? {
        store.activeRoutine?.workouts.first { $0.id == workout.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(routine.name)
                    .font(.custom("ChalkboardSE-Regular", size: 16)).foregroundColor(theme.onPrimaryText.opacity(0.8))
                Text(workout.name)
                    .font(.custom("ChalkboardSE-Regular", size: 24)).bold().foregroundColor(theme.onPrimaryText)
            }
            .padding().frame(maxWidth: .infinity).background(Color.black.opacity(0.2))

            if let cw = currentWorkout {
                if cw.exercises.isEmpty {
                    Spacer()
                    Text("No exercises added yet.")
                        .font(.custom("ChalkboardSE-Regular", size: 18)).foregroundColor(theme.onPrimaryText)
                    Spacer()
                } else {
                    List {
                        ForEach(cw.exercises) { exercise in
                            NavigationLink(destination: ExerciseDetailView(routineId: routine.id, workoutId: cw.id, exerciseId: exercise.id)) {
                                ActiveExerciseRowView(exercise: exercise)
                            }
                            .listRowBackground(theme.rowBackground)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }

            HStack(spacing: 12) {
                Button(action: { store.activeWorkoutId = nil }) {
                    Text("Back to Routine")
                        .font(.custom("ChalkboardSE-Regular", size: 16)).foregroundColor(theme.onPrimaryText)
                        .padding().frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2)).cornerRadius(12)
                }
                Button(action: { store.finishWorkout(routine: routine, workout: workout) }) {
                    Text("Finish Workout")
                        .font(.custom("ChalkboardSE-Regular", size: 16)).bold()
                        .foregroundColor(theme.accentColor)
                        .padding().frame(maxWidth: .infinity)
                        .background(theme.rowBackground).cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

struct ActiveExerciseRowView: View {
    let exercise: Exercise
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.current }
    var setsCompleted: Int { exercise.logs.count }
    var isFullyCompleted: Bool { exercise.isCompleted || (setsCompleted >= exercise.targetSets) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.custom("ChalkboardSE-Regular", size: 18)).foregroundColor(theme.rowText)
                Text("\(setsCompleted)/\(exercise.targetSets) sets completed")
                    .font(.custom("ChalkboardSE-Regular", size: 14)).foregroundColor(theme.secondaryRowText)
            }
            Spacer()
            Image(systemName: isFullyCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isFullyCompleted ? .green : .gray).font(.title2)
        }
        .padding(.vertical, 8)
    }
}
