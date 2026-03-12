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

    var weightDisplay: String {
        return String(format: "%.1f lbs", weight)
    }
}

struct Exercise: Identifiable, Codable {
    var id = UUID()
    var name: String
    var targetSets: Int
    var targetReps: String  // e.g. "8-12" or "Until Failure"
    var currentWeight: Double
    var category: ExerciseCategory
    var isCompleted: Bool = false
    var logs: [SetLog] = []

    var weightDisplay: String {
        return String(format: "%.1f lbs", currentWeight)
    }

    init(id: UUID = UUID(),
         name: String,
         targetSets: Int,
         targetReps: String,
         currentWeight: Double,
         category: ExerciseCategory = .weightlifting,
         isCompleted: Bool = false,
         logs: [SetLog] = []) {
        self.id = id
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.currentWeight = currentWeight
        self.category = category
        self.isCompleted = isCompleted
        self.logs = logs
    }

    enum CodingKeys: String, CodingKey {
        case id, name, targetSets, targetReps, currentWeight, category, isCompleted, logs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,   forKey: .id)
        name          = try c.decode(String.self, forKey: .name)
        targetSets    = try c.decode(Int.self,    forKey: .targetSets)
        targetReps    = try c.decode(String.self, forKey: .targetReps)
        currentWeight = try c.decode(Double.self, forKey: .currentWeight)
        category      = (try? c.decode(ExerciseCategory.self, forKey: .category)) ?? .weightlifting
        isCompleted   = (try? c.decode(Bool.self,   forKey: .isCompleted)) ?? false
        logs          = (try? c.decode([SetLog].self,  forKey: .logs)) ?? []
    }
}
