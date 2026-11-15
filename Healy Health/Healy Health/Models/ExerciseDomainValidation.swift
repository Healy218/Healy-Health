import Foundation

enum ExerciseValidationError: LocalizedError, Equatable {
    case emptyName
    case invalidTargetSets
    case emptyTargetReps
    case invalidWeight
    case invalidLogReps

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return String(localized: "Enter an exercise name.")
        case .invalidTargetSets:
            return String(localized: "Target sets must be a whole number greater than zero.")
        case .emptyTargetReps:
            return String(localized: "Enter a target rep range.")
        case .invalidWeight:
            return String(localized: "Weight must be a finite number that is zero or greater.")
        case .invalidLogReps:
            return String(localized: "Reps must be a whole number greater than zero.")
        }
    }
}

struct ValidatedExerciseConfiguration: Equatable {
    let name: String
    let targetSets: Int
    let targetReps: String
    let currentWeight: Double
}

struct ValidatedSetLog: Equatable {
    let weight: Double
    let reps: Int
}

/// The single source of truth for exercise data entered by people or received in imports.
enum ExerciseDomainValidation {
    static func trimmedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func configuration(
        name: String,
        targetSets: Int,
        targetReps: String,
        currentWeight: Double
    ) throws -> ValidatedExerciseConfiguration {
        let trimmedName = trimmedText(name)
        guard !trimmedName.isEmpty else { throw ExerciseValidationError.emptyName }
        guard targetSets > 0 else { throw ExerciseValidationError.invalidTargetSets }

        let trimmedReps = trimmedText(targetReps)
        guard !trimmedReps.isEmpty else { throw ExerciseValidationError.emptyTargetReps }
        guard currentWeight.isFinite, currentWeight >= 0 else {
            throw ExerciseValidationError.invalidWeight
        }

        return ValidatedExerciseConfiguration(
            name: trimmedName,
            targetSets: targetSets,
            targetReps: trimmedReps,
            currentWeight: currentWeight
        )
    }

    static func setLog(weight: Double, reps: Int) throws -> ValidatedSetLog {
        guard weight.isFinite, weight >= 0 else { throw ExerciseValidationError.invalidWeight }
        guard reps > 0 else { throw ExerciseValidationError.invalidLogReps }
        return ValidatedSetLog(weight: weight, reps: reps)
    }
}
