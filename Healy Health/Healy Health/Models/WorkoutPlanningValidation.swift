import Foundation

enum WorkoutPlanningValidationError: LocalizedError, Equatable {
    case emptyRoutineName
    case emptyWorkoutName
    case duplicateExerciseName

    var errorDescription: String? {
        switch self {
        case .emptyRoutineName:
            return "Enter a routine name."
        case .emptyWorkoutName:
            return "Enter a workout name."
        case .duplicateExerciseName:
            return "This workout already includes an exercise with that name."
        }
    }
}

/// Normalizes planning text at every routine/workout editing boundary. Exercise names are
/// unique within a workout, ignoring surrounding whitespace and letter case; the same exercise
/// can still be planned in other workouts.
enum WorkoutPlanningValidation {
    static func routineName(_ value: String) throws -> String {
        let normalized = ExerciseDomainValidation.trimmedText(value)
        guard !normalized.isEmpty else { throw WorkoutPlanningValidationError.emptyRoutineName }
        return normalized
    }

    static func workoutName(_ value: String) throws -> String {
        let normalized = ExerciseDomainValidation.trimmedText(value)
        guard !normalized.isEmpty else { throw WorkoutPlanningValidationError.emptyWorkoutName }
        return normalized
    }

    static func focus(_ value: String) -> String {
        ExerciseDomainValidation.trimmedText(value)
    }

    static func hasDuplicateExerciseName(_ name: String, in exercises: [Exercise], excludingID: UUID? = nil) -> Bool {
        let normalizedName = normalizedExerciseName(name)
        guard !normalizedName.isEmpty else { return false }
        return exercises.contains {
            $0.id != excludingID && normalizedExerciseName($0.name) == normalizedName
        }
    }

    private static func normalizedExerciseName(_ value: String) -> String {
        ExerciseDomainValidation.trimmedText(value).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}
