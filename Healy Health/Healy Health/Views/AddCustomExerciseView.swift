import SwiftUI

struct AddCustomExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var exerciseManager = ExerciseManager.shared

    var presetCategory: ExerciseCategory = .weightlifting
    var onAdd: (Exercise) -> Void

    @State private var exerciseName: String = ""
    @State private var targetSets: String = "3"
    @State private var targetReps: String = "8-12"
    @State private var selectedCategory: ExerciseCategory = .weightlifting

    private var theme: AppTheme { themeManager.current }

    var isDuplicate: Bool {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespaces).lowercased()
        return !trimmed.isEmpty && exerciseManager.exercises.contains { $0.name.lowercased() == trimmed }
    }

    var isFormValid: Bool {
        !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(targetSets) != nil &&
        !targetReps.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isDuplicate
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryColor.ignoresSafeArea()

                VStack(spacing: 20) {
                    categoryPicker
                    fieldCard
                    addButton
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.onPrimaryText)
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                }
            }
            .onAppear { selectedCategory = presetCategory }
        }
    }

    private var categoryPicker: some View {
        HStack(spacing: 0) {
            ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                Button(action: { selectedCategory = cat }) {
                    VStack(spacing: 4) {
                        Image(systemName: cat.icon).font(.system(size: 18))
                        Text(cat.displayName).font(.custom("ChalkboardSE-Regular", size: 13))
                    }
                    .foregroundColor(selectedCategory == cat ? theme.accentColor : theme.secondaryRowText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedCategory == cat ? theme.accentColor.opacity(0.08) : Color.clear)
                }
            }
        }
        .background(theme.rowBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var fieldCard: some View {
        VStack(spacing: 0) {
            fieldRow(label: "Exercise Name", placeholder: "e.g. Hamstring Stretch", text: $exerciseName, keyboard: .default)
            if isDuplicate {
                Text("An exercise with this name already exists in the library.")
                    .font(.custom("ChalkboardSE-Regular", size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
            Divider().padding(.leading)
            fieldRow(label: "Sets", placeholder: "e.g. 3", text: $targetSets, keyboard: .numberPad)
            Divider().padding(.leading)
            fieldRow(label: "Rep Range", placeholder: "e.g. 8-12", text: $targetReps, keyboard: .default)
        }
        .background(theme.rowBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var addButton: some View {
        Button(action: addExercise) {
            Text("Add Exercise")
                .font(.custom("ChalkboardSE-Regular", size: 18))
                .foregroundColor(isFormValid ? theme.accentColor : theme.secondaryRowText)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.rowBackground)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .disabled(!isFormValid)
    }

    @ViewBuilder
    private func fieldRow(label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(label).font(.custom("ChalkboardSE-Regular", size: 16)).foregroundColor(theme.rowText)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.custom("ChalkboardSE-Regular", size: 16))
                .foregroundColor(theme.rowText)
                .frame(maxWidth: 160)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }

    private func addExercise() {
        let name = exerciseName.trimmingCharacters(in: .whitespaces)
        let reps = targetReps.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let sets = Int(targetSets), !reps.isEmpty else { return }
        onAdd(Exercise(name: name, targetSets: sets, targetReps: reps, currentWeight: 0.0, category: selectedCategory))
        dismiss()
    }
}
