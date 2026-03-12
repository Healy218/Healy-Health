import SwiftUI

struct EditExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    let routineId: UUID
    let workoutId: UUID
    let exerciseId: UUID

    @State private var targetSets: String = ""
    @State private var targetReps: String = ""
    @State private var startingWeight: String = ""

    private var theme: AppTheme { themeManager.current }

    private var currentExercise: Exercise? {
        store.routines.first(where: { $0.id == routineId })?
            .workouts.first(where: { $0.id == workoutId })?
            .exercises.first(where: { $0.id == exerciseId })
    }

    var isFormValid: Bool { Int(targetSets) != nil && Double(startingWeight) != nil && !targetReps.isEmpty }

    var body: some View {
        Form {
            if let exercise = currentExercise {
                Section(header: Text("Configuration for \(exercise.name)").foregroundColor(theme.onPrimaryText)) {
                    HStack {
                        Text("Target Sets").foregroundColor(theme.rowText)
                        Spacer()
                        TextField("e.g. 3", text: $targetSets).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                    }.listRowBackground(theme.rowBackground)

                    HStack {
                        Text("Target Reps").foregroundColor(theme.rowText)
                        Spacer()
                        TextField("e.g. 8-12", text: $targetReps).multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                    }.listRowBackground(theme.rowBackground)

                    HStack {
                        Text("Starting Weight (lbs)").foregroundColor(theme.rowText)
                        Spacer()
                        TextField("e.g. 135.0", text: $startingWeight).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                    }.listRowBackground(theme.rowBackground)
                }

                Button(action: {
                    if let sets = Int(targetSets), let weight = Double(startingWeight),
                       let rIndex = store.routines.firstIndex(where: { $0.id == routineId }),
                       let wIndex = store.routines[rIndex].workouts.firstIndex(where: { $0.id == workoutId }),
                       let eIndex = store.routines[rIndex].workouts[wIndex].exercises.firstIndex(where: { $0.id == exerciseId }) {
                        var updated = store.routines[rIndex]
                        updated.workouts[wIndex].exercises[eIndex].targetSets = sets
                        updated.workouts[wIndex].exercises[eIndex].targetReps = targetReps
                        updated.workouts[wIndex].exercises[eIndex].currentWeight = weight
                        store.updateRoutine(updated)
                        dismiss()
                    }
                }) {
                    Text("Save Changes")
                        .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                        .background(isFormValid ? theme.primaryColor : Color.gray).cornerRadius(10)
                }
                .disabled(!isFormValid)
                .padding(.vertical)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.primaryColor.ignoresSafeArea())
        .navigationTitle("Edit Exercise")
        .onAppear {
            if let ex = currentExercise {
                targetSets = "\(ex.targetSets)"
                targetReps = ex.targetReps
                startingWeight = "\(ex.currentWeight)"
            }
        }
    }
}
