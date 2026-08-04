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
                                        store.startWorkout(routineId: cr.id, workoutId: workout.id)
                                        store.selectedTab = 1
                                    } label: { Label("Set Active", systemImage: "star.fill") }
                                    .tint(.green)
                                }
                            }
                            .onDelete(perform: deleteWorkout)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(currentRoutine?.name ?? "Routine")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
}
