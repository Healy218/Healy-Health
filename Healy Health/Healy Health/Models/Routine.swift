import Foundation

struct Routine: Identifiable, Codable {
    var id = UUID()
    var name: String
    var dateCreated: Date = Date()
    var workouts: [Workout]
}
