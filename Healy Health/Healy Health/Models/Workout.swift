import Foundation

struct Workout: Identifiable, Codable {
    var id = UUID()
    var name: String // e.g., "Pull Day"
    var focus: String   // e.g., "Push - Chest/Shoulders/Tris"
    var exercises: [Exercise]
}
