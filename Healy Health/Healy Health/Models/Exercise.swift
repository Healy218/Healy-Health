import Foundation

enum ExerciseCategory: String, Codable, CaseIterable {
    case cardio        = "Cardio"
    case stretch       = "Stretch"
    case weightlifting = "Weightlifting"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .cardio:        return "figure.run"
        case .stretch:       return "figure.flexibility"
        case .weightlifting: return "dumbbell.fill"
        }
    }
}

struct SetLog: Identifiable, Codable {
    var id = UUID()
    var weight: Double
    var reps: Int
    var completedDate: Date

    func weightDisplay(in unit: WeightUnit) -> String {
        WeightFormatter.string(fromPounds: weight, unit: unit)
    }
}

struct Exercise: Identifiable, Codable {
    var id = UUID()
    /// Stable identity for progress tracking. Unlike `id`, which identifies one planned exercise
    /// or immutable history snapshot, this follows the underlying library exercise over time.
    var trackingId: UUID?
    var name: String
    var targetSets: Int
    var targetReps: String  // e.g. "8-12" or "Until Failure"
    var currentWeight: Double
    var category: ExerciseCategory
    var isCompleted: Bool = false
    var logs: [SetLog] = []

    func weightDisplay(in unit: WeightUnit) -> String {
        WeightFormatter.string(fromPounds: currentWeight, unit: unit)
    }

    init(id: UUID = UUID(),
         trackingId: UUID? = UUID(),
         name: String,
         targetSets: Int,
         targetReps: String,
         currentWeight: Double,
         category: ExerciseCategory = .weightlifting,
         isCompleted: Bool = false,
         logs: [SetLog] = []) {
        self.id = id
        self.trackingId = trackingId
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.currentWeight = currentWeight
        self.category = category
        self.isCompleted = isCompleted
        self.logs = logs
    }

    enum CodingKeys: String, CodingKey {
        case id, trackingId, name, targetSets, targetReps, currentWeight, category, isCompleted, logs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,   forKey: .id)
        trackingId    = try c.decodeIfPresent(UUID.self, forKey: .trackingId)
        name          = try c.decode(String.self, forKey: .name)
        targetSets    = try c.decode(Int.self,    forKey: .targetSets)
        targetReps    = try c.decode(String.self, forKey: .targetReps)
        currentWeight = try c.decode(Double.self, forKey: .currentWeight)
        category      = (try? c.decode(ExerciseCategory.self, forKey: .category)) ?? .weightlifting
        isCompleted   = (try? c.decode(Bool.self,   forKey: .isCompleted)) ?? false
        logs          = (try? c.decode([SetLog].self,  forKey: .logs)) ?? []
    }
}

/// Upgrades pre-identity routine and history data without changing the exercise/snapshot IDs
/// used by existing screens and exports. Legacy records are associated by normalized display
/// name only once; newly created exercises instead retain their template UUID, so same-name
/// movements can remain distinct and renames keep their progress.
enum ExerciseIdentityMigration {
    struct Result {
        let routines: [Routine]
        let completedWorkouts: [CompletedWorkout]
        let routinesChanged: Bool
        let historyChanged: Bool

        var didChange: Bool { routinesChanged || historyChanged }
    }

    static func migrated(
        routines: [Routine],
        completedWorkouts: [CompletedWorkout],
        templates: [ExerciseTemplate]
    ) -> Result {
        var routineResult = routines
        var historyResult = completedWorkouts
        var identitiesByName: [String: UUID] = [:]
        for template in templates {
            identitiesByName[normalizedName(template.name), default: template.id] = template.id
        }
        var routinesChanged = false
        var historyChanged = false

        // Preserve any already-migrated identity as the canonical value for a legacy name.
        // The first stored occurrence makes migration deterministic for a fixed data snapshot.
        for routine in routines {
            for workout in routine.workouts {
                for exercise in workout.exercises {
                    if let trackingId = exercise.trackingId {
                        identitiesByName[normalizedName(exercise.name), default: trackingId] = trackingId
                    }
                }
            }
        }
        for workout in completedWorkouts {
            for exercise in workout.exercises {
                if let trackingId = exercise.trackingId {
                    identitiesByName[normalizedName(exercise.name), default: trackingId] = trackingId
                }
            }
        }

        for routineIndex in routineResult.indices {
            for workoutIndex in routineResult[routineIndex].workouts.indices {
                for exerciseIndex in routineResult[routineIndex].workouts[workoutIndex].exercises.indices {
                    if assignIdentity(
                        to: &routineResult[routineIndex].workouts[workoutIndex].exercises[exerciseIndex],
                        identitiesByName: &identitiesByName
                    ) {
                        routinesChanged = true
                    }
                }
            }
        }
        for workoutIndex in historyResult.indices {
            for exerciseIndex in historyResult[workoutIndex].exercises.indices {
                if assignIdentity(
                    to: &historyResult[workoutIndex].exercises[exerciseIndex],
                    identitiesByName: &identitiesByName
                ) {
                    historyChanged = true
                }
            }
        }

        return Result(
            routines: routineResult,
            completedWorkouts: historyResult,
            routinesChanged: routinesChanged,
            historyChanged: historyChanged
        )
    }

    private static func assignIdentity(
        to exercise: inout Exercise,
        identitiesByName: inout [String: UUID]
    ) -> Bool {
        guard exercise.trackingId == nil else { return false }
        let key = normalizedName(exercise.name)
        let trackingId = identitiesByName[key] ?? UUID()
        identitiesByName[key] = trackingId
        exercise.trackingId = trackingId
        return true
    }

    private static func normalizedName(_ name: String) -> String {
        ExerciseDomainValidation.trimmedText(name).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}
