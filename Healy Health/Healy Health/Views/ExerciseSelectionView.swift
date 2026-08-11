import SwiftUI

struct ExerciseSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var exerciseManager = ExerciseManager.shared
    @State private var searchText = ""

    var presetCategory: ExerciseCategory = .weightlifting
    var onAdd: (Exercise) -> Void

    private var theme: AppTheme { themeManager.current }

    var filteredExercises: [ExerciseTemplate] {
        searchText.isEmpty ? exerciseManager.exercises :
            exerciseManager.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises) { template in
                    NavigationLink(destination: ConfigureExerciseView(template: template, presetCategory: presetCategory, onAdd: { newExercise in
                        onAdd(newExercise)
                        dismiss()
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundColor(theme.rowText)
                            HStack {
                                if !template.primaryMuscleGroup.isEmpty {
                                    Text(template.primaryMuscleGroup)
                                        .font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(theme.accentColor.opacity(0.1)).foregroundColor(theme.accentColor).cornerRadius(8)
                                }
                                if !template.equipmentType.isEmpty {
                                    Text(template.equipmentType)
                                        .font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.1)).foregroundColor(theme.secondaryRowText).cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(theme.rowBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.primaryColor.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select Exercise")
                        .font(.headline)
                        .foregroundColor(theme.onPrimaryText)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.onPrimaryText)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
        }
    }
}
