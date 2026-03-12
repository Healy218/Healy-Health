import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject var store: RoutineStore
    @State private var showingAddRoutine = false
    @State private var newRoutineName = ""
    
    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)
            
            VStack {
                if store.routines.isEmpty {
                    Text("No routines yet.")
                        .foregroundColor(.white)
                        .padding()
                } else {
                    List {
                        ForEach(store.routines) { routine in
                            NavigationLink(destination: RoutineDetailView(routine: routine)) {
                                VStack(alignment: .leading) {
                                    Text(routine.name)
                                        .font(.custom("ChalkboardSE-Regular", size: 20))
                                        .foregroundColor(.black)
                                    Text("\(routine.workouts.count) Workout\(routine.workouts.count == 1 ? "" : "s")")
                                        .font(.custom("ChalkboardSE-Regular", size: 14))
                                        .foregroundColor(Color(white: 0.3))
                                    
                                    if store.activeRoutineId == routine.id {
                                        Text("Active Routine")
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
                                    store.activeRoutineId = routine.id
                                    store.activeWorkoutId = nil // Reset since we're selecting the whole routine
                                    store.selectedTab = 1 // Navigate to Workout tab
                                } label: {
                                    Label("Start", systemImage: "star.fill")
                                }
                                .tint(.green)
                            }
                        }
                        .onDelete(perform: deleteRoutine)
                    }
                    .scrollContentBackground(.hidden) // Removes default List background
                }
            }
            .navigationTitle("Your Routines")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .foregroundColor(.white)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showingAddRoutine = true }) {
                    Text("Add Routine")
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
            .alert("New Routine", isPresented: $showingAddRoutine) {
                TextField("Routine Name", text: $newRoutineName)
                Button("Cancel", role: .cancel) {
                    newRoutineName = ""
                }
                Button("Add") {
                    if !newRoutineName.isEmpty {
                        let newRoutine = Routine(name: newRoutineName, workouts: [])
                        store.addRoutine(newRoutine)
                        newRoutineName = ""
                    }
                }
            }
        }
    }
    
    private func deleteRoutine(offsets: IndexSet) {
        offsets.forEach { index in
            let routine = store.routines[index]
            store.deleteRoutine(routine)
        }
    }
}
