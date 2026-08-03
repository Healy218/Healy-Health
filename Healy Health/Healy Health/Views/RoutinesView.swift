import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddRoutine = false
    @State private var newRoutineName = ""

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
                                    store.activeRoutineId = routine.id
                                    store.activeWorkoutId = nil
                                    store.selectedTab = 1
                                } label: {
                                    Label("Start", systemImage: "star.fill")
                                }
                                .tint(.green)
                            }
                        }
                        .onDelete(perform: deleteRoutine)
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
    }

    private func deleteRoutine(offsets: IndexSet) {
        let routineIDs = Set(offsets.compactMap { store.routines.indices.contains($0) ? store.routines[$0].id : nil })
        store.deleteRoutines(ids: routineIDs)
    }
}
