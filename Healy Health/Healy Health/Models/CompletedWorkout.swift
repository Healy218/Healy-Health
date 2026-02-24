import Foundation

struct CompletedWorkout: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var dayName: String
    var focus: String
    var exercises: [Exercise]
}
