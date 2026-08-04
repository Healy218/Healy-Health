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
                        .font(.custom("ChalkboardSE-Regular", size: 24)).bold()
                        .foregroundColor(theme.onPrimaryText)
                    Text("Swipe right on a routine in the Routines tab to start it here.")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(theme.onPrimaryText.opacity(0.8))
                        .multilineTextAlignment(.center).padding()
                }
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Routine workout list

struct RoutineWorkoutListView: View {
    let routine: Routine
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showFinishDialog = false

    private var theme: AppTheme { themeManager.current }
    private var allDone: Bool {
        !routine.workouts.isEmpty && routine.workouts.allSatisfy { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(routine.name)
                    .font(.custom("ChalkboardSE-Regular", size: 24)).bold()
                    .foregroundColor(theme.onPrimaryText)
                Text(allDone ? "All workouts complete!" : "Select a workout to begin")
                    .font(.custom("ChalkboardSE-Regular", size: 14))
                    .foregroundColor(theme.onPrimaryText.opacity(0.8))
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
                        Button {
                            if !workout.isCompleted {
                                store.startWorkout(routineId: routine.id, workoutId: workout.id)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name)
                                        .font(.custom("ChalkboardSE-Regular", size: 20))
                                        .foregroundColor(workout.isCompleted ? theme.secondaryRowText : theme.rowText)
                                        .strikethrough(workout.isCompleted, color: theme.secondaryRowText)
                                    Text(workout.focus)
                                        .font(.custom("ChalkboardSE-Regular", size: 14))
                                        .foregroundColor(theme.secondaryRowText)
                                    Text("\(workout.exercises.count) exercises")
                                        .font(.custom("ChalkboardSE-Regular", size: 12))
                                        .foregroundColor(theme.secondaryRowText)
                                }
                                Spacer()
                                Image(systemName: workout.isCompleted ? "checkmark.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(workout.isCompleted ? .green : theme.accentColor)
                            }
                            .padding(.vertical, 8)
                            .opacity(workout.isCompleted ? 0.6 : 1.0)
                        }
                        .disabled(workout.isCompleted)
                        .listRowBackground(theme.rowBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }

            // Complete Routine button — only shown when all workouts are done
            if allDone {
                Button(action: { showFinishDialog = true }) {
                    Text("Complete Routine")
                        .font(.custom("ChalkboardSE-Regular", size: 18)).bold()
                        .foregroundColor(theme.accentColor)
                        .padding().frame(maxWidth: .infinity)
                        .background(theme.rowBackground).cornerRadius(14)
                }
                .padding()
            }
        }
        .confirmationDialog("Routine Complete!", isPresented: $showFinishDialog, titleVisibility: .visible) {
            Button("Repeat Next Week") { store.finishRoutine(startNew: false) }
            Button("Choose New Routine") { store.finishRoutine(startNew: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every workout in \"\(routine.name)\" is done. What would you like to do?")
        }
    }
}

// MARK: - Active workout session

struct WorkoutSessionView: View {
    let routine: Routine
    let workout: Workout
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showUnloggedWorkConfirmation = false
    @State private var completionErrorMessage: String?

    private var theme: AppTheme { themeManager.current }

    private var currentWorkout: Workout? {
        store.activeRoutine?.workouts.first { $0.id == workout.id }
    }

    private var unloggedExercises: [Exercise] {
        currentWorkout?.exercises.filter { $0.logs.isEmpty } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(routine.name)
                    .font(.custom("ChalkboardSE-Regular", size: 16))
                    .foregroundColor(theme.onPrimaryText.opacity(0.8))
                Text(currentWorkout?.name ?? workout.name)
                    .font(.custom("ChalkboardSE-Regular", size: 24)).bold()
                    .foregroundColor(theme.onPrimaryText)
            }
            .padding().frame(maxWidth: .infinity).background(Color.black.opacity(0.2))

            if let cw = currentWorkout {
                if cw.exercises.isEmpty {
                    Spacer()
                    Text("No exercises added yet.")
                        .font(.custom("ChalkboardSE-Regular", size: 18))
                        .foregroundColor(theme.onPrimaryText)
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
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(theme.onPrimaryText)
                        .padding().frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2)).cornerRadius(12)
                }
                Button(action: requestWorkoutCompletion) {
                    Text("Finish Workout")
                        .font(.custom("ChalkboardSE-Regular", size: 16)).bold()
                        .foregroundColor(theme.accentColor)
                        .padding().frame(maxWidth: .infinity)
                        .background(theme.rowBackground).cornerRadius(12)
                }
                .disabled(currentWorkout?.isCompleted != false)
            }
            .padding()
        }
        .confirmationDialog(
            "Finish With Unlogged Exercises?",
            isPresented: $showUnloggedWorkConfirmation,
            titleVisibility: .visible
        ) {
            Button("Finish Anyway", role: .destructive, action: finishWorkout)
            Button("Keep Logging", role: .cancel) {}
        } message: {
            Text(unloggedWorkMessage)
        }
        .alert("Couldn’t Finish Workout", isPresented: Binding(
            get: { completionErrorMessage != nil },
            set: { if !$0 { completionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { completionErrorMessage = nil }
        } message: {
            Text(completionErrorMessage ?? "")
        }
    }

    private var unloggedWorkMessage: String {
        let names = unloggedExercises.map(\.name)
        guard !names.isEmpty else { return "" }
        let exerciseLabel = names.count == 1 ? "exercise has" : "exercises have"
        return "\(names.count) planned \(exerciseLabel) no logged sets: \(names.joined(separator: ", ")). Finish anyway?"
    }

    private func requestWorkoutCompletion() {
        if unloggedExercises.isEmpty {
            finishWorkout()
        } else {
            showUnloggedWorkConfirmation = true
        }
    }

    private func finishWorkout() {
        switch store.finishWorkout(routineId: routine.id, workoutId: workout.id) {
        case .success:
            break
        case .failure(let error):
            completionErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Exercise row in active workout

struct ActiveExerciseRowView: View {
    let exercise: Exercise
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.current }
    var setsCompleted: Int { exercise.logs.count }
    var isFullyCompleted: Bool { exercise.isCompleted || setsCompleted >= exercise.targetSets }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.custom("ChalkboardSE-Regular", size: 18))
                    .foregroundColor(theme.rowText)
                Text("\(exercise.targetReps) reps")
                    .font(.custom("ChalkboardSE-Regular", size: 13))
                    .foregroundColor(theme.secondaryRowText)
                Text("\(setsCompleted)/\(exercise.targetSets) sets completed")
                    .font(.custom("ChalkboardSE-Regular", size: 13))
                    .foregroundColor(theme.secondaryRowText)
            }
            Spacer()
            Image(systemName: isFullyCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isFullyCompleted ? .green : .gray)
                .font(.title2)
        }
        .padding(.vertical, 8)
    }
}
