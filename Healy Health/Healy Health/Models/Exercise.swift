import Foundation

struct Exercise: Identifiable, Codable {
    var id = UUID()
    var name: String
    var targetSets: Int
    var targetReps: String // String to handle ranges like "8-12" or "Until Failure"
    var currentWeight: Double
    var isCompleted: Bool = false
    
    // Helper to format weight display
    var weightDisplay: String {
        return String(format: "%.1f lbs", currentWeight)
    }
}
