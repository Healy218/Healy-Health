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

    private var theme: AppTheme { themeManager.current }

    private var currentRoutine: Routine? {
        store.routines.first(where: { $0.id == routine.id })
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
                                            .font(.custom("ChalkboardSE-Regular", size: 20))
                                            .foregroundColor(theme.rowText)
                                        if !workout.focus.isEmpty {
                                            Text(workout.focus)
                                                .font(.custom("ChalkboardSE-Regular", size: 14))
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
                                }
                                .listRowBackground(theme.rowBackground)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        requestWorkoutStart(routineID: cr.id, workoutID: workout.id)
                                    } label: { Label("Set Active", systemImage: "star.fill") }
                                    .tint(.green)
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
                    if !editRoutineName.isEmpty, let cr = currentRoutine {
                        var updated = cr; updated.name = editRoutineName
                        store.updateRoutine(updated)
                    }
                }
            }
            .alert("New Workout", isPresented: $showingAddWorkout) {
                TextField("Workout Name", text: $newWorkoutName)
                TextField("Focus (e.g. Push, Pull, Legs)", text: $newWorkoutFocus)
                Button("Cancel", role: .cancel) { newWorkoutName = ""; newWorkoutFocus = "" }
                Button("Add") {
                    if !newWorkoutName.isEmpty, let cr = currentRoutine {
                        var updated = cr
                        updated.workouts.append(Workout(name: newWorkoutName, focus: newWorkoutFocus, exercises: []))
                        store.updateRoutine(updated)
                        newWorkoutName = ""; newWorkoutFocus = ""
                    }
                }
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
        }
    }

    private func deleteWorkout(offsets: IndexSet) {
        if let currentRoutine {
            let workoutIDs = Set(offsets.compactMap {
                currentRoutine.workouts.indices.contains($0) ? currentRoutine.workouts[$0].id : nil
            })
            store.deleteWorkouts(routineId: currentRoutine.id, ids: workoutIDs)
        }
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
