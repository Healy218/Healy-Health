import SwiftUI

struct ExerciseSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var exerciseManager = ExerciseManager.shared
    @State private var searchText = ""
    
    // The handler to call when an exercise is fully configured and added
    var onAdd: (Exercise) -> Void
    
    var filteredExercises: [ExerciseTemplate] {
        if searchText.isEmpty {
            return exerciseManager.exercises
        } else {
            return exerciseManager.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises) { template in
                    NavigationLink(destination: ConfigureExerciseView(template: template, onAdd: { newExercise in
                        onAdd(newExercise)
                        dismiss()
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            HStack {
                                if !template.primaryMuscleGroup.isEmpty {
                                    Text(template.primaryMuscleGroup)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                                
                                if !template.equipmentType.isEmpty {
                                    Text(template.equipmentType)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.1))
                                        .foregroundColor(.gray)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.blue.ignoresSafeArea())
            .navigationTitle("Select Exercise")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .searchable(text: $searchText, prompt: "Search exercises")
        }
    }
}
