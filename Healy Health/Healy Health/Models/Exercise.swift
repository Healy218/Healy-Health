import Foundation

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
    var targetReps: String // String to handle ranges like "8-12" or "Until Failure"
    var currentWeight: Double
    var isCompleted: Bool = false
    var logs: [SetLog] = []
    
    // Helper to format weight display
    var weightDisplay: String {
        return String(format: "%.1f lbs", currentWeight)
    }
}
