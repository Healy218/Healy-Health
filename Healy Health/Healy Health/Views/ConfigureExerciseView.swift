import SwiftUI

struct ConfigureExerciseView: View {
    @Environment(\.dismiss) var dismiss

    let template: ExerciseTemplate
    var presetCategory: ExerciseCategory = .weightlifting
    var onAdd: (Exercise) -> Void

    @State private var targetSets: String = "3"
    @State private var targetReps: String = "8-12"
    @State private var startingWeight: String = "0.0"
    @State private var selectedCategory: ExerciseCategory = .weightlifting

    var isFormValid: Bool {
        Int(targetSets) != nil && Double(startingWeight) != nil && !targetReps.isEmpty
    }

    var body: some View {
        Form {
            // Category picker section
            Section(header: Text("Category").foregroundColor(.white)) {
                HStack(spacing: 0) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                        Button(action: { selectedCategory = cat }) {
                            VStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 18))
                                Text(cat.displayName)
                                    .font(.custom("ChalkboardSE-Regular", size: 12))
                            }
                            .foregroundColor(selectedCategory == cat ? .blue : Color(white: 0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listRowBackground(Color.white)
                .listRowInsets(EdgeInsets())
            }

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
                        currentWeight: weight,
                        category: selectedCategory
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
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.ignoresSafeArea())
        .navigationTitle("Configure Exercise")
        .onAppear { selectedCategory = presetCategory }
    }
}
