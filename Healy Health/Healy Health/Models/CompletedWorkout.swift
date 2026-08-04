import Foundation

struct CompletedWorkout: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var dayName: String
    var focus: String
    var exercises: [Exercise]
    var routineId: UUID?
    var workoutId: UUID?

    /// Date ties are resolved by UUID so persisted and presented history order never depends on
    /// JSON array order or dictionary iteration.
    nonisolated static func newestFirst(_ lhs: CompletedWorkout, _ rhs: CompletedWorkout) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
