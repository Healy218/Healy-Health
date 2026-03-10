import SwiftUI

struct RoutineDetailView: View {
    @EnvironmentObject var store: RoutineStore
    var routine: Routine
    
    @State private var showingAddWorkout = false
    @State private var newWorkoutName = ""
    @State private var newWorkoutFocus = ""
    
    @State private var showingEditRoutine = false
    @State private var editRoutineName = ""
    
    // Compute current routine dynamically to reflect updates
    private var currentRoutine: Routine? {
        store.routines.first(where: { $0.id == routine.id })
    }
    
    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)
            
            VStack {
                if let currentRoutine = currentRoutine {
                    if currentRoutine.workouts.isEmpty {
                        Text("No workouts yet.")
                            .foregroundColor(.white)
                            .padding()
                    } else {
                        List {
                            ForEach(currentRoutine.workouts) { workout in
                                NavigationLink(destination: WorkoutDetailView(routineId: currentRoutine.id, workout: workout)) {
                                    VStack(alignment: .leading) {
                                        Text(workout.name)
                                            .font(.custom("ChalkboardSE-Regular", size: 20))
                                            .foregroundColor(.black)
                                        Text(workout.focus)
                                            .font(.custom("ChalkboardSE-Regular", size: 14))
                                            .foregroundColor(Color(white: 0.3))
                                        
                                        if store.activeRoutineId == currentRoutine.id && store.activeWorkoutId == workout.id {
                                            Text("Active Workout")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .padding(.top, 2)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.white)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        store.activeRoutineId = currentRoutine.id
                                        store.activeWorkoutId = workout.id
                                        store.selectedTab = 1 // Navigate to Workout tab
                                    } label: {
                                        Label("Set Active", systemImage: "star.fill")
                                    }
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
                        if let currentRoutine = currentRoutine {
                            editRoutineName = currentRoutine.name
                            showingEditRoutine = true
                        }
                    }
                    .foregroundColor(.white)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showingAddWorkout = true }) {
                    Text("Add Workout")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
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
                    if !editRoutineName.isEmpty, let currentRoutine = currentRoutine {
                        var updatedRoutine = currentRoutine
                        updatedRoutine.name = editRoutineName
                        store.updateRoutine(updatedRoutine)
                    }
                }
            }
            .alert("New Workout", isPresented: $showingAddWorkout) {
                TextField("Workout Name", text: $newWorkoutName)
                TextField("Focus (e.g. Legs)", text: $newWorkoutFocus)
                Button("Cancel", role: .cancel) {
                    newWorkoutName = ""
                    newWorkoutFocus = ""
                }
                Button("Add") {
                    if !newWorkoutName.isEmpty, let currentRoutine = currentRoutine {
                        var updatedRoutine = currentRoutine
                        let newWorkout = Workout(name: newWorkoutName, focus: newWorkoutFocus, exercises: [])
                        updatedRoutine.workouts.append(newWorkout)
                        store.updateRoutine(updatedRoutine)
                        newWorkoutName = ""
                        newWorkoutFocus = ""
                    }
                }
            }
        }
    }
    
    private func deleteWorkout(offsets: IndexSet) {
        if let currentRoutine = currentRoutine {
            var updatedRoutine = currentRoutine
            offsets.forEach { index in
                updatedRoutine.workouts.remove(at: index)
            }
            store.updateRoutine(updatedRoutine)
        }
    }
}
