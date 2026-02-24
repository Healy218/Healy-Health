import Foundation

struct WorkoutDay: Identifiable, Codable {
    var id = UUID()
    var dayName: String // e.g., "Monday"
    var focus: String   // e.g., "Push - Chest/Shoulders/Tris"
    var exercises: [Exercise]
}
