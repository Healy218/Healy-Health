import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingRoutineOverview = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            theme.primaryColor.edgesIgnoringSafeArea(.all)

            if let activeRoutine = store.activeRoutine {
                if let activeWorkout = store.activeWorkout, !showingRoutineOverview {
                    WorkoutSessionView(
                        routine: activeRoutine,
                        workout: activeWorkout,
                        showingRoutineOverview: $showingRoutineOverview
                    )
                } else {
                    RoutineWorkoutListView(
                        routine: activeRoutine,
                        resumeActiveWorkout: { showingRoutineOverview = false }
                    )
                }
            } else {
                VStack {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 80))
                        .foregroundColor(theme.onPrimaryText.opacity(0.5))
                        .accessibilityHidden(true)
                        .padding()
                    Text("No Active Routine")
                        .font(AppTypography.chalkboard(24, relativeTo: .title2)).bold()
                        .foregroundColor(theme.onPrimaryText)
                    Text("Swipe right on a routine in the Routines tab to start it here.")
                        .font(AppTypography.chalkboard(16, relativeTo: .body))
                        .foregroundColor(theme.onPrimaryText.opacity(0.8))
                        .multilineTextAlignment(.center).padding()
                }
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.activeWorkoutId) { _ in
            showingRoutineOverview = false
        }
    }
}

// MARK: - Routine workout list

struct RoutineWorkoutListView: View {
    let routine: Routine
    let resumeActiveWorkout: () -> Void
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showFinishDialog = false
    @State private var showAbandonDialog = false
    @State private var pendingWorkoutStartID: UUID?

    private var theme: AppTheme { themeManager.current }
    private var allDone: Bool {
        !routine.workouts.isEmpty && routine.workouts.allSatisfy { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(routine.name)
                    .font(AppTypography.chalkboard(24, relativeTo: .title2)).bold()
                    .foregroundColor(theme.onPrimaryText)
                Text(allDone ? "All workouts complete!" : "Select a workout to begin")
                    .font(AppTypography.chalkboard(14, relativeTo: .subheadline))
                    .foregroundColor(theme.onPrimaryText.opacity(0.8))
            }
            .padding().frame(maxWidth: .infinity).background(Color.black.opacity(0.2))

            if routine.workouts.isEmpty {
                Spacer()
                Text("This routine has no workouts yet.\nAdd some in the Routines tab.")
                    .font(AppTypography.chalkboard(16, relativeTo: .body))
                    .foregroundColor(theme.onPrimaryText.opacity(0.8))
                    .multilineTextAlignment(.center).padding()
                Spacer()
            } else {
                List {
                    ForEach(routine.workouts) { workout in
                        Button {
                            requestWorkoutStart(workout.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name)
                                        .font(AppTypography.chalkboard(20, relativeTo: .title3))
                                        .foregroundColor(workout.isCompleted ? theme.secondaryRowText : theme.rowText)
                                        .strikethrough(workout.isCompleted, color: theme.secondaryRowText)
                                    Text(workout.focus)
                                        .font(AppTypography.chalkboard(14, relativeTo: .subheadline))
                                        .foregroundColor(theme.secondaryRowText)
                                    Text("\(workout.exercises.count) exercises")
                                        .font(AppTypography.chalkboard(12, relativeTo: .caption))
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
                        .accessibilityLabel(workout.name)
                        .accessibilityValue(workoutAccessibilityValue(for: workout))
                        .accessibilityHint(workout.isCompleted ? "Workout complete." : "Starts this workout.")
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
                        .font(AppTypography.chalkboard(18, relativeTo: .headline)).bold()
                        .foregroundColor(theme.accentColor)
                        .padding().frame(maxWidth: .infinity)
                        .background(theme.rowBackground).cornerRadius(14)
                }
                .padding()
            } else {
                Button(action: { showAbandonDialog = true }) {
                    Text("Abandon Routine")
                        .font(AppTypography.chalkboard(16, relativeTo: .body))
                        .foregroundColor(.red)
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
        .confirmationDialog("Abandon Routine?", isPresented: $showAbandonDialog, titleVisibility: .visible) {
            Button("Keep Progress and End Routine") {
                store.abandonRoutine(routineId: routine.id, discardProgress: false)
            }
            Button("Reset Routine Progress", role: .destructive) {
                store.abandonRoutine(routineId: routine.id, discardProgress: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keeping progress leaves logged sets and workout completion status available when you resume. Resetting clears every logged set and completion status in this routine. Any active rest timer will stop.")
        }
        .confirmationDialog(
            "Switch Active Workout?",
            isPresented: Binding(
                get: { pendingWorkoutStartID != nil },
                set: { if !$0 { pendingWorkoutStartID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Keep Partial Logs and Switch") { replaceActiveWorkout(discardProgress: false) }
            Button("Discard Partial Logs and Switch", role: .destructive) { replaceActiveWorkout(discardProgress: true) }
            Button("Cancel", role: .cancel) { pendingWorkoutStartID = nil }
        } message: {
            Text("Your active workout is still in progress. Keeping partial logs lets you resume or correct them later. Discarding clears its logged sets and completion status. Any active rest timer will stop.")
        }
    }

    private func requestWorkoutStart(_ workoutID: UUID) {
        guard let workout = routine.workouts.first(where: { $0.id == workoutID }),
              !workout.isCompleted else { return }

        if store.activeWorkoutId == workoutID {
            resumeActiveWorkout()
        } else if store.startWorkout(routineId: routine.id, workoutId: workoutID) {
            resumeActiveWorkout()
        } else {
            pendingWorkoutStartID = workoutID
        }
    }

    private func workoutAccessibilityValue(for workout: Workout) -> String {
        let focus = workout.focus.isEmpty ? "No focus specified" : workout.focus
        let completion = workout.isCompleted ? "Complete" : "Not started"
        return "\(focus). \(workout.exercises.count) exercises. \(completion)."
    }

    private func replaceActiveWorkout(discardProgress: Bool) {
        guard let targetWorkoutID = pendingWorkoutStartID,
              let activeWorkoutID = store.activeSessionWorkoutId else { return }

        store.abandonWorkout(
            routineId: routine.id,
            workoutId: activeWorkoutID,
            discardProgress: discardProgress
        )
        pendingWorkoutStartID = nil
        if store.startWorkout(routineId: routine.id, workoutId: targetWorkoutID) {
            resumeActiveWorkout()
        }
    }
}

// MARK: - Active workout session

struct WorkoutSessionView: View {
    let routine: Routine
    let workout: Workout
    @Binding var showingRoutineOverview: Bool
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showUnloggedWorkConfirmation = false
    @State private var showAbandonWorkoutConfirmation = false
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
                    .font(AppTypography.chalkboard(16, relativeTo: .body))
                    .foregroundColor(theme.onPrimaryText.opacity(0.8))
                Text(currentWorkout?.name ?? workout.name)
                    .font(AppTypography.chalkboard(24, relativeTo: .title2)).bold()
                    .foregroundColor(theme.onPrimaryText)
            }
            .padding().frame(maxWidth: .infinity).background(Color.black.opacity(0.2))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active workout")
            .accessibilityValue("\(routine.name), \(currentWorkout?.name ?? workout.name)")

            if let cw = currentWorkout {
                if cw.exercises.isEmpty {
                    Spacer()
                    Text("No exercises added yet.")
                        .font(AppTypography.chalkboard(18, relativeTo: .headline))
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

            ViewThatFits(in: .horizontal) {
                workoutActions(axis: .horizontal)
                workoutActions(axis: .vertical)
            }
            .padding()

            Button(action: { showAbandonWorkoutConfirmation = true }) {
                Text("Abandon Workout")
                    .font(AppTypography.chalkboard(16, relativeTo: .body))
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
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
        .confirmationDialog(
            "Abandon Workout?",
            isPresented: $showAbandonWorkoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Keep Partial Logs") {
                store.abandonWorkout(routineId: routine.id, workoutId: workout.id, discardProgress: false)
            }
            Button("Discard Partial Logs", role: .destructive) {
                store.abandonWorkout(routineId: routine.id, workoutId: workout.id, discardProgress: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout will not be added to history. Keeping partial logs lets you resume or correct them later. Discarding clears its logged sets and completion status. Any active rest timer will stop.")
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

    @ViewBuilder
    private func workoutActions(axis: Axis) -> some View {
        if axis == .horizontal {
            HStack(spacing: 12) {
                workoutActionButtons
            }
        } else {
            VStack(spacing: 12) {
                workoutActionButtons
            }
        }
    }

    @ViewBuilder
    private var workoutActionButtons: some View {
        Button(action: { showingRoutineOverview = true }) {
            Text("Back to Routine")
                .font(AppTypography.chalkboard(16, relativeTo: .body))
                .foregroundColor(theme.onPrimaryText)
                .padding().frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.2)).cornerRadius(12)
        }
        .accessibilityHint("Returns to this routine’s workout list.")
        Button(action: requestWorkoutCompletion) {
            Text("Finish Workout")
                .font(AppTypography.chalkboard(16, relativeTo: .body)).bold()
                .foregroundColor(theme.accentColor)
                .padding().frame(maxWidth: .infinity)
                .background(theme.rowBackground).cornerRadius(12)
        }
        .accessibilityHint("Completes this workout and adds it to your history.")
        .disabled(currentWorkout?.isCompleted != false)
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
                    .font(AppTypography.chalkboard(18, relativeTo: .headline))
                    .foregroundColor(theme.rowText)
                Text("\(exercise.targetReps) reps")
                    .font(AppTypography.chalkboard(13, relativeTo: .footnote))
                    .foregroundColor(theme.secondaryRowText)
                Text("\(setsCompleted)/\(exercise.targetSets) sets completed")
                    .font(AppTypography.chalkboard(13, relativeTo: .footnote))
                    .foregroundColor(theme.secondaryRowText)
            }
            Spacer()
            Image(systemName: isFullyCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isFullyCompleted ? .green : .gray)
                .font(.title2)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exercise.name)
        .accessibilityValue("Target \(exercise.targetSets) sets of \(exercise.targetReps) reps. \(setsCompleted) of \(exercise.targetSets) sets completed. \(isFullyCompleted ? "Complete" : "In progress").")
        .accessibilityHint("Opens set logging for \(exercise.name).")
    }
}
