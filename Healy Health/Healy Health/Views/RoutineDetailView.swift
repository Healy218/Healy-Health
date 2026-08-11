import SwiftUI

struct RoutineDetailView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    var routine: Routine

    @State private var showingAddWorkout = false
    @State private var newWorkoutName = ""
    @State private var newWorkoutFocus = ""
    @State private var showingEditRoutine = false
    @State private var editRoutineName = ""
    @State private var pendingWorkoutStartID: UUID?
    @State private var pendingWorkoutDeletionIDs: Set<UUID> = []

    private var theme: AppTheme { themeManager.current }

    private var currentRoutine: Routine? {
        store.routines.first(where: { $0.id == routine.id })
    }

    private var isEditedRoutineNameValid: Bool {
        (try? WorkoutPlanningValidation.routineName(editRoutineName)) != nil
    }

    private var isNewWorkoutNameValid: Bool {
        (try? WorkoutPlanningValidation.workoutName(newWorkoutName)) != nil
    }

    var body: some View {
        ZStack {
            theme.primaryColor.edgesIgnoringSafeArea(.all)

            VStack {
                if let cr = currentRoutine {
                    if cr.workouts.isEmpty {
                        Text("No workouts yet.")
                            .foregroundColor(theme.onPrimaryText)
                            .padding()
                    } else {
                        List {
                            ForEach(cr.workouts) { workout in
                                NavigationLink(destination: WorkoutDetailView(routineId: cr.id, workout: workout)) {
                                    VStack(alignment: .leading) {
                                        Text(workout.name)
                                            .font(AppTypography.chalkboard(20, relativeTo: .title3))
                                            .foregroundColor(theme.rowText)
                                        if !workout.focus.isEmpty {
                                            Text(workout.focus)
                                                .font(AppTypography.chalkboard(14, relativeTo: .subheadline))
                                                .foregroundColor(theme.secondaryRowText)
                                        }
                                        if store.activeRoutineId == cr.id && store.activeWorkoutId == workout.id {
                                            Text("Active Workout")
                                                .font(.caption)
                                                .foregroundColor(theme.accentColor)
                                                .padding(.top, 2)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(workout.name)
                                    .accessibilityValue(workoutAccessibilityValue(for: workout, routineID: cr.id))
                                    .accessibilityHint("Opens the workout. Swipe up or down for actions.")
                                }
                                .listRowBackground(theme.rowBackground)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        requestWorkoutStart(routineID: cr.id, workoutID: workout.id)
                                    } label: { Label("Set Active", systemImage: "star.fill") }
                                    .tint(theme.successColor)
                                }
                        }
                        .onDelete(perform: deleteWorkout)
                        .onMove(perform: moveWorkouts)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(currentRoutine?.name ?? "Routine")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                        .foregroundColor(theme.onPrimaryText)
                    Button("Edit") {
                        editRoutineName = currentRoutine?.name ?? ""
                        showingEditRoutine = true
                    }
                    .foregroundColor(theme.onPrimaryText)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showingAddWorkout = true }) {
                    Text("Add Workout")
                        .font(.headline)
                        .foregroundColor(theme.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.rowBackground)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .alert("Edit Routine Name", isPresented: $showingEditRoutine) {
                TextField("Routine Name", text: $editRoutineName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if let cr = currentRoutine {
                        _ = store.renameRoutine(id: cr.id, name: editRoutineName)
                    }
                }
                .disabled(!isEditedRoutineNameValid)
            }
            .alert("New Workout", isPresented: $showingAddWorkout) {
                TextField("Workout Name", text: $newWorkoutName)
                TextField("Focus (e.g. Push, Pull, Legs)", text: $newWorkoutFocus)
                Button("Cancel", role: .cancel) { newWorkoutName = ""; newWorkoutFocus = "" }
                Button("Add") {
                    if let cr = currentRoutine,
                       case .success = store.addWorkout(
                        routineId: cr.id,
                        name: newWorkoutName,
                        focus: newWorkoutFocus
                       ) {
                        newWorkoutName = ""; newWorkoutFocus = ""
                    }
                }
                .disabled(!isNewWorkoutNameValid)
            }
            .confirmationDialog(
                "Replace Active Session?",
                isPresented: Binding(
                    get: { pendingWorkoutStartID != nil },
                    set: { if !$0 { pendingWorkoutStartID = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Keep Progress and Switch") { replaceActiveSession(discardProgress: false) }
                Button("Reset Progress and Switch", role: .destructive) { replaceActiveSession(discardProgress: true) }
                Button("Cancel", role: .cancel) { pendingWorkoutStartID = nil }
            } message: {
                Text(replacementMessage)
            }
            .confirmationDialog(
                pendingWorkoutDeletionIDs.count == 1 ? "Delete Workout?" : "Delete Workouts?",
                isPresented: Binding(
                    get: { !pendingWorkoutDeletionIDs.isEmpty },
                    set: { if !$0 { pendingWorkoutDeletionIDs = [] } }
                ),
                titleVisibility: .visible
            ) {
                Button(
                    pendingWorkoutDeletionIDs.count == 1 ? "Delete Workout" : "Delete Workouts",
                    role: .destructive,
                    action: deletePendingWorkouts
                )
                Button("Cancel", role: .cancel) { pendingWorkoutDeletionIDs = [] }
            } message: {
                Text("This permanently removes the selected workout and its planned exercises. It can’t be undone.")
            }
        }
    }

    private func deleteWorkout(offsets: IndexSet) {
        if let currentRoutine {
            pendingWorkoutDeletionIDs = Set(offsets.compactMap {
                currentRoutine.workouts.indices.contains($0) ? currentRoutine.workouts[$0].id : nil
            })
        }
    }

    private func deletePendingWorkouts() {
        defer { pendingWorkoutDeletionIDs = [] }
        guard let currentRoutine else { return }
        store.deleteWorkouts(routineId: currentRoutine.id, ids: pendingWorkoutDeletionIDs)
    }

    private func workoutAccessibilityValue(for workout: Workout, routineID: UUID) -> String {
        let focus = workout.focus.isEmpty ? "No focus specified" : workout.focus
        let state = store.activeRoutineId == routineID && store.activeWorkoutId == workout.id
            ? "Active workout"
            : "Not active"
        return "\(focus). \(state)."
    }

    private func moveWorkouts(fromOffsets: IndexSet, toOffset: Int) {
        guard let currentRoutine else { return }
        store.moveWorkouts(
            routineId: currentRoutine.id,
            fromOffsets: fromOffsets,
            toOffset: toOffset
        )
    }

    private func requestWorkoutStart(routineID: UUID, workoutID: UUID) {
        if store.startWorkout(routineId: routineID, workoutId: workoutID) {
            store.selectedTab = 1
        } else {
            pendingWorkoutStartID = workoutID
        }
    }

    private var replacementMessage: String {
        let activeName = store.activeWorkout?.name ?? store.activeRoutine?.name ?? "current session"
        let scope = store.activeRoutineId == routine.id ? "workout" : "routine"
        return "\"\(activeName)\" is still active. Keeping progress preserves its logged sets and workout completion status; resetting this \(scope) clears both. Any active rest timer will stop."
    }

    private func replaceActiveSession(discardProgress: Bool) {
        guard let targetWorkoutID = pendingWorkoutStartID else { return }

        if store.activeRoutineId == routine.id,
           let activeWorkoutID = store.activeSessionWorkoutId {
            store.abandonWorkout(
                routineId: routine.id,
                workoutId: activeWorkoutID,
                discardProgress: discardProgress
            )
        } else if let activeRoutineID = store.activeRoutineId {
            store.abandonRoutine(routineId: activeRoutineID, discardProgress: discardProgress)
        }

        pendingWorkoutStartID = nil
        if store.startWorkout(routineId: routine.id, workoutId: targetWorkoutID) {
            store.selectedTab = 1
        }
    }
}
