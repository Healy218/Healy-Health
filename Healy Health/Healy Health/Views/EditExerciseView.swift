import SwiftUI

struct EditExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: RoutineStore
    
    let routineId: UUID
    let workoutId: UUID
    let exerciseId: UUID
    
    @State private var targetSets: String = ""
    @State private var targetReps: String = ""
    @State private var startingWeight: String = ""
    
    private var currentExercise: Exercise? {
        if let routine = store.routines.first(where: { $0.id == routineId }),
           let workout = routine.workouts.first(where: { $0.id == workoutId }),
           let exercise = workout.exercises.first(where: { $0.id == exerciseId }) {
            return exercise
        }
        return nil
    }
    
    var isFormValid: Bool {
        Int(targetSets) != nil && Double(startingWeight) != nil && !targetReps.isEmpty
    }

    var body: some View {
        Form {
            if let exercise = currentExercise {
                Section(header: Text("Configuration for \(exercise.name)").foregroundColor(.white)) {
                    
                    HStack {
                        Text("Target Sets").foregroundColor(.black)
                        Spacer()
                        TextField("e.g. 3", text: $targetSets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.black)
                    }
                    .listRowBackground(Color.white)
                    
                    HStack {
                        Text("Target Reps").foregroundColor(.black)
                        Spacer()
                        TextField("e.g. 8-12", text: $targetReps)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.black)
                    }
                    .listRowBackground(Color.white)
                    
                    HStack {
                        Text("Starting Weight (lbs)").foregroundColor(.black)
                        Spacer()
                        TextField("e.g. 135.0", text: $startingWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.black)
                    }
                    .listRowBackground(Color.white)
                }
                
                Button(action: {
                    if let sets = Int(targetSets), let weight = Double(startingWeight) {
                        if let rIndex = store.routines.firstIndex(where: { $0.id == routineId }),
                           let wIndex = store.routines[rIndex].workouts.firstIndex(where: { $0.id == workoutId }),
                           let eIndex = store.routines[rIndex].workouts[wIndex].exercises.firstIndex(where: { $0.id == exerciseId }) {
                            
                            var updatedRoutine = store.routines[rIndex]
                            updatedRoutine.workouts[wIndex].exercises[eIndex].targetSets = sets
                            updatedRoutine.workouts[wIndex].exercises[eIndex].targetReps = targetReps
                            updatedRoutine.workouts[wIndex].exercises[eIndex].currentWeight = weight
                            
                            store.updateRoutine(updatedRoutine)
                            dismiss()
                        }
                    }
                }) {
                    Text("Save Changes")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isFormValid)
                .padding(.vertical)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.ignoresSafeArea())
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
