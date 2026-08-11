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
    @State private var selectedCategory: ExerciseCategory = .weightlifting
    @State private var inputWeightUnit: WeightUnit = .pounds
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds

    private var theme: AppTheme { themeManager.current }

    private var currentExercise: Exercise? {
        store.routines.first(where: { $0.id == routineId })?
            .workouts.first(where: { $0.id == workoutId })?
            .exercises.first(where: { $0.id == exerciseId })
    }

    private var validatedConfiguration: Result<ValidatedExerciseConfiguration, ExerciseValidationError> {
        guard let exercise = currentExercise else {
            return .failure(.invalidWeight)
        }
        guard let sets = Int(targetSets) else {
            return .failure(.invalidTargetSets)
        }
        guard let weight = WeightFormatter.pounds(fromInput: startingWeight, unit: weightUnit) else {
            return .failure(.invalidWeight)
        }
        do {
            return .success(try ExerciseDomainValidation.configuration(
                name: exercise.name,
                targetSets: sets,
                targetReps: targetReps,
                currentWeight: weight
            ))
        } catch let error as ExerciseValidationError {
            return .failure(error)
        } catch {
            return .failure(.invalidWeight)
        }
    }

    var isFormValid: Bool {
        if case .success = validatedConfiguration { return true }
        return false
    }

    private var validationMessage: String? {
        if case .failure(let error) = validatedConfiguration { return error.localizedDescription }
        return nil
    }

    var body: some View {
        Form {
            if let exercise = currentExercise {
                Section(header: Text("Configuration for \(exercise.name)").foregroundColor(theme.onPrimaryText)) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .foregroundColor(theme.rowText)
                    .listRowBackground(theme.rowBackground)

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
                        Text("Starting Weight (\(weightUnit.symbol))").foregroundColor(theme.rowText)
                        Spacer()
                        TextField("e.g. 135.0", text: $startingWeight).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                    }.listRowBackground(theme.rowBackground)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(theme.destructiveColor)
                            .listRowBackground(theme.rowBackground)
                    }
                }

                Button(action: {
                    if case .success(let configuration) = validatedConfiguration,
                       case .success = store.updateExerciseConfiguration(
                        routineId: routineId,
                        workoutId: workoutId,
                        exerciseId: exerciseId,
                        targetSets: configuration.targetSets,
                        targetReps: configuration.targetReps,
                        currentWeight: configuration.currentWeight,
                        category: selectedCategory
                       ) {
                        dismiss()
                    }
                }) {
                    Text("Save Changes")
                        .font(.headline).foregroundColor(theme.onPrimaryText).frame(maxWidth: .infinity).padding()
                        .background(isFormValid ? theme.primaryColor : theme.disabledButtonColor).cornerRadius(10)
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
                startingWeight = WeightFormatter.inputString(fromPounds: ex.currentWeight, unit: weightUnit)
                selectedCategory = ex.category
                inputWeightUnit = weightUnit
            }
        }
        .onChange(of: weightUnit) { newUnit in
            reformatStartingWeight(for: newUnit)
        }
    }

    private func reformatStartingWeight(for newUnit: WeightUnit) {
        defer { inputWeightUnit = newUnit }
        guard let pounds = WeightFormatter.pounds(fromInput: startingWeight, unit: inputWeightUnit) else { return }
        startingWeight = WeightFormatter.inputString(fromPounds: pounds, unit: newUnit)
    }
}
