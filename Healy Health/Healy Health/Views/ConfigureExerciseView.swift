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

    private var theme: AppTheme { themeManager.current }

    private var validatedConfiguration: Result<ValidatedExerciseConfiguration, ExerciseValidationError> {
        guard let sets = Int(targetSets) else {
            return .failure(.invalidTargetSets)
        }
        guard let weight = Double(startingWeight) else {
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
                HStack(spacing: 0) {
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
                }
                .listRowBackground(theme.rowBackground)

                HStack {
                    Text("Target Reps").foregroundColor(theme.rowText)
                    Spacer()
                    TextField("e.g. 8-12", text: $targetReps)
                        .multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                }
                .listRowBackground(theme.rowBackground)

                HStack {
                    Text("Starting Weight (lbs)").foregroundColor(theme.rowText)
                    Spacer()
                    TextField("e.g. 135.0", text: $startingWeight)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(theme.rowText)
                }
                .listRowBackground(theme.rowBackground)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.red)
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
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                    .background(isFormValid ? theme.primaryColor : Color.gray).cornerRadius(10)
            }
            .disabled(!isFormValid)
            .padding(.vertical)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .scrollContentBackground(.hidden)
        .background(theme.primaryColor.ignoresSafeArea())
        .navigationTitle("Configure Exercise")
        .onAppear { selectedCategory = presetCategory }
    }
}
