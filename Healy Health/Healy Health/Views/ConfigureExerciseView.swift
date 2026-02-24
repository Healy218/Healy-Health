import SwiftUI

struct ConfigureExerciseView: View {
    @Environment(\.dismiss) var dismiss
    
    let template: ExerciseTemplate
    var onAdd: (Exercise) -> Void
    
    @State private var targetSets: String = "3"
    @State private var targetReps: String = "8-12"
    @State private var startingWeight: String = "0.0"
    
    var isFormValid: Bool {
        Int(targetSets) != nil && Double(startingWeight) != nil && !targetReps.isEmpty
    }

    var body: some View {
        Form {
            Section(header: Text("Configuration for \(template.name)").foregroundColor(.white)) {
                
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
                    let newExercise = Exercise(
                        name: template.name,
                        targetSets: sets,
                        targetReps: targetReps,
                        currentWeight: weight
                    )
                    onAdd(newExercise)
                }
            }) {
                Text("Add to Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!isFormValid)
            .padding(.vertical)
            // Center the button in the form
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.ignoresSafeArea())
        .navigationTitle("Configure Exercise")
    }
}
