import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddRoutine = false
    @State private var newRoutineName = ""
    @State private var pendingRoutineStartID: UUID?

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            theme.primaryColor.edgesIgnoringSafeArea(.all)

            VStack {
                if store.routines.isEmpty {
                    Text("No routines yet.")
                        .foregroundColor(theme.onPrimaryText)
                        .padding()
                } else {
                    List {
                        ForEach(store.routines) { routine in
                            NavigationLink(destination: RoutineDetailView(routine: routine)) {
                                VStack(alignment: .leading) {
                                    Text(routine.name)
                                        .font(.custom("ChalkboardSE-Regular", size: 20))
                                        .foregroundColor(theme.rowText)
                                    Text("\(routine.workouts.count) Workout\(routine.workouts.count == 1 ? "" : "s")")
                                        .font(.custom("ChalkboardSE-Regular", size: 14))
                                        .foregroundColor(theme.secondaryRowText)
                                    if store.activeRoutineId == routine.id {
                                        Text("Active Routine")
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
                                        requestRoutineStart(routine.id)
                                    } label: {
                                        Label("Start", systemImage: "star.fill")
                                    }
                                .tint(.green)
                            }
                        }
                        .onDelete(perform: deleteRoutine)
                        .onMove(perform: moveRoutines)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showingAddRoutine = true }) {
                    Text("Add Routine")
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
            .alert("New Routine", isPresented: $showingAddRoutine) {
                TextField("Routine Name", text: $newRoutineName)
                Button("Cancel", role: .cancel) { newRoutineName = "" }
                Button("Add") {
                    if !newRoutineName.isEmpty {
                        store.addRoutine(Routine(name: newRoutineName, workouts: []))
                        newRoutineName = ""
                    }
                }
            }
        }
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton().foregroundColor(theme.onPrimaryText)
            }
        }
        .confirmationDialog(
            replacementTitle,
            isPresented: Binding(
                get: { pendingRoutineStartID != nil },
                set: { if !$0 { pendingRoutineStartID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Keep Progress and Switch") { replaceActiveSession(discardProgress: false) }
            Button("Reset Progress and Switch", role: .destructive) { replaceActiveSession(discardProgress: true) }
            Button("Cancel", role: .cancel) { pendingRoutineStartID = nil }
        } message: {
            Text(replacementMessage)
        }
    }

    private func deleteRoutine(offsets: IndexSet) {
        let routineIDs = Set(offsets.compactMap { store.routines.indices.contains($0) ? store.routines[$0].id : nil })
        store.deleteRoutines(ids: routineIDs)
    }

    private func moveRoutines(fromOffsets: IndexSet, toOffset: Int) {
        store.moveRoutines(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    private func requestRoutineStart(_ routineID: UUID) {
        if store.startRoutine(routineId: routineID) {
            store.selectedTab = 1
        } else {
            pendingRoutineStartID = routineID
        }
    }

    private var replacementTitle: String {
        if store.activeRoutineId == pendingRoutineStartID, store.activeSessionWorkoutId != nil {
            return "Leave Active Workout?"
        }
        return "Switch Active Routine?"
    }

    private var replacementMessage: String {
        let activeName = store.activeWorkout?.name ?? store.activeRoutine?.name ?? "current session"
        return "\"\(activeName)\" is still active. Keeping progress preserves its logged sets and workout completion status; resetting progress clears both. Any active rest timer will stop."
    }

    private func replaceActiveSession(discardProgress: Bool) {
        guard let targetRoutineID = pendingRoutineStartID else { return }

        if store.activeRoutineId == targetRoutineID,
           let activeWorkoutID = store.activeSessionWorkoutId {
            store.abandonWorkout(
                routineId: targetRoutineID,
                workoutId: activeWorkoutID,
                discardProgress: discardProgress
            )
        } else if let activeRoutineID = store.activeRoutineId {
            store.abandonRoutine(routineId: activeRoutineID, discardProgress: discardProgress)
        }

        pendingRoutineStartID = nil
        if store.startRoutine(routineId: targetRoutineID) {
            store.selectedTab = 1
        }
    }
}
