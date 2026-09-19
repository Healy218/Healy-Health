import SwiftUI

struct ConfigureExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    let template: ExerciseTemplate
    var presetCategory: ExerciseCategory = .weightlifting
    var onAdd: (Exercise) -> Void

    @State private var targetSets: String = "3"
    @State private var targetReps: String = "8-12"
    @State private var startingWeight: String = "0.0"
    @State private var selectedCategory: ExerciseCategory = .weightlifting
    @State private var inputWeightUnit: WeightUnit = .pounds
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var theme: AppTheme { themeManager.current }

    private var validatedConfiguration: Result<ValidatedExerciseConfiguration, ExerciseValidationError> {
        guard let sets = Int(targetSets) else {
            return .failure(.invalidTargetSets)
        }
        guard let weight = WeightFormatter.pounds(fromInput: startingWeight, unit: weightUnit) else {
            return .failure(.invalidWeight)
        }
        do {
            return .success(try ExerciseDomainValidation.configuration(
                name: template.name,
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
            Section(header: Text("Category").foregroundColor(theme.onPrimaryText)) {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 0),
                        count: dynamicTypeSize.isAccessibilitySize ? 1 : ExerciseCategory.allCases.count
                    ),
                    spacing: 0
                ) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                        Button(action: { selectedCategory = cat }) {
                            VStack(spacing: 4) {
                                Image(systemName: cat.icon).font(.system(size: 18))
                                Text(cat.displayName).font(AppTypography.chalkboard(12, relativeTo: .caption))
                            }
                            .foregroundColor(selectedCategory == cat ? theme.accentColor : theme.secondaryRowText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel(cat.displayName)
                        .accessibilityValue(selectedCategory == cat ? "Selected" : "Not selected")
                        .accessibilityAddTraits(selectedCategory == cat ? .isSelected : [])
                        .accessibilityHint("Sets the exercise category to \(cat.displayName).")
                    }
                }
                .listRowBackground(theme.rowBackground)
                .listRowInsets(EdgeInsets())
            }

            Section(header: Text("Configuration for \(template.name)").foregroundColor(theme.onPrimaryText)) {
                HStack {
                    Text("Target Sets").foregroundColor(theme.rowText)
                    Spacer()
                    TextField("e.g. 3", text: $targetSets)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                        .accessibilityLabel("Target sets")
                }
                .listRowBackground(theme.rowBackground)

                HStack {
                    Text("Target Reps").foregroundColor(theme.rowText)
                    Spacer()
                    TextField("e.g. 8-12", text: $targetReps)
                        .multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                        .accessibilityLabel("Target repetitions")
                }
                .listRowBackground(theme.rowBackground)

                HStack {
                    Text("Starting Weight (\(weightUnit.symbol))").foregroundColor(theme.rowText)
                    Spacer()
                    TextField("e.g. 135.0", text: $startingWeight)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                        .accessibilityLabel("Starting weight in \(weightUnit.spokenName)")
                }
                .listRowBackground(theme.rowBackground)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(theme.destructiveColor)
                        .listRowBackground(theme.rowBackground)
                }
            }

            Button(action: {
                if case .success(let configuration) = validatedConfiguration {
                    onAdd(Exercise(
                        trackingId: template.id,
                        name: configuration.name,
                        targetSets: configuration.targetSets,
                        targetReps: configuration.targetReps,
                        currentWeight: configuration.currentWeight,
                        category: selectedCategory
                    ))
                }
            }) {
                Text("Add to Workout")
                    .font(.headline).foregroundColor(theme.onPrimaryText).frame(maxWidth: .infinity).padding()
                    .background(isFormValid ? theme.primaryColor : theme.disabledButtonColor).cornerRadius(10)
            }
            .disabled(!isFormValid)
            .padding(.vertical)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .scrollContentBackground(.hidden)
        .background(theme.primaryColor.ignoresSafeArea())
        .navigationTitle("Configure Exercise")
        .onAppear { inputWeightUnit = weightUnit }
        .onChange(of: weightUnit) { newUnit in
            reformatStartingWeight(for: newUnit)
        }
        .onAppear { selectedCategory = presetCategory }
    }

    private func reformatStartingWeight(for newUnit: WeightUnit) {
        defer { inputWeightUnit = newUnit }
        guard let pounds = WeightFormatter.pounds(fromInput: startingWeight, unit: inputWeightUnit) else { return }
        startingWeight = WeightFormatter.inputString(fromPounds: pounds, unit: newUnit)
    }
}
