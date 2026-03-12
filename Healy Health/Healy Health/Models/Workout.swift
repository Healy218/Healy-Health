import Foundation

struct Workout: Identifiable, Codable {
    var id = UUID()
    var name: String  // e.g., "Push Day"
    var focus: String // e.g., "Chest, Shoulders, Triceps"
    var exercises: [Exercise]
}
