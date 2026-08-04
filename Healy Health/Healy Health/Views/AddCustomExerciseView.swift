import SwiftUI

struct AddCustomExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var exerciseManager = ExerciseManager.shared

    var presetCategory: ExerciseCategory = .weightlifting
    var isNameInUse: (String) -> Bool = { _ in false }
    var onAdd: (Exercise) -> Void

    @State private var exerciseName: String = ""
    @State private var targetSets: String = "3"
    @State private var targetReps: String = "8-12"
    @State private var selectedCategory: ExerciseCategory = .weightlifting
    @State private var libraryErrorMessage: String?

    private var theme: AppTheme { themeManager.current }

    var isDuplicate: Bool {
        let normalizedName = ExerciseDomainValidation.trimmedText(exerciseName).lowercased()
        guard !normalizedName.isEmpty else { return false }
        return isNameInUse(exerciseName) || exerciseManager.exercises.contains {
            ExerciseDomainValidation.trimmedText($0.name).lowercased() == normalizedName
        }
    }

    private var validatedConfiguration: Result<ValidatedExerciseConfiguration, ExerciseValidationError> {
        guard let sets = Int(targetSets) else { return .failure(.invalidTargetSets) }
        do {
            return .success(try ExerciseDomainValidation.configuration(
                name: exerciseName,
                targetSets: sets,
                targetReps: targetReps,
                currentWeight: 0
            ))
        } catch let error as ExerciseValidationError {
            return .failure(error)
        } catch {
            return .failure(.invalidWeight)
        }
    }

    var isFormValid: Bool {
        if case .success = validatedConfiguration { return !isDuplicate }
        return false
    }

    private var validationMessage: String? {
        if let libraryErrorMessage { return libraryErrorMessage }
        if isDuplicate { return nil }
        if case .failure(let error) = validatedConfiguration {
            if error == .emptyName && exerciseName.isEmpty { return nil }
            return error.localizedDescription
        }
        return nil
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
                Text("An exercise with this name already exists in this workout or the library.")
                    .font(.custom("ChalkboardSE-Regular", size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
            Divider().padding(.leading)
            fieldRow(label: "Sets", placeholder: "e.g. 3", text: $targetSets, keyboard: .numberPad)
            Divider().padding(.leading)
            fieldRow(label: "Rep Range", placeholder: "e.g. 8-12", text: $targetReps, keyboard: .default)
            if let validationMessage {
                Text(validationMessage)
                    .font(.custom("ChalkboardSE-Regular", size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }
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
        guard case .success(let configuration) = validatedConfiguration, !isDuplicate else { return }
        let template = ExerciseTemplate(
            name: configuration.name,
            primaryMuscleGroup: selectedCategory.displayName,
            equipmentType: "Custom"
        )
        switch exerciseManager.addExercise(template) {
        case .added:
            break
        case .invalidName:
            libraryErrorMessage = "Enter an exercise name."
            return
        case .duplicateName:
            libraryErrorMessage = "An exercise with this name already exists in this workout or the library."
            return
        case .persistenceFailed:
            libraryErrorMessage = "Couldn’t save this custom exercise. Please try again."
            return
        }
        onAdd(Exercise(
            name: configuration.name,
            targetSets: configuration.targetSets,
            targetReps: configuration.targetReps,
            currentWeight: configuration.currentWeight,
            category: selectedCategory
        ))
        dismiss()
    }
}
