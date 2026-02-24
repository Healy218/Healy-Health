import Foundation

class WorkoutSchedule {
    static let shared = WorkoutSchedule()
    
    var fullSchedule: [WorkoutDay] = []

    private let fileName = "workout_schedule.json"
    
    private init() {
        loadWithFallback()
    }
    
    func toggleExerciseCompletion(dayId: UUID, exerciseId: UUID) {
        if let dayIndex = fullSchedule.firstIndex(where: { $0.id == dayId }),
           let exerciseIndex = fullSchedule[dayIndex].exercises.firstIndex(where: { $0.id == exerciseId }) {
            fullSchedule[dayIndex].exercises[exerciseIndex].isCompleted.toggle()
            save()
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(fullSchedule) {
            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            try? data.write(to: url)
        }
    }
    
    private func loadWithFallback() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([WorkoutDay].self, from: data) {
            fullSchedule = decoded
        } else {
            // Fallback to default static data
            fullSchedule = [
                WorkoutDay(
                    dayName: "Monday",
                    focus: "Push (Chest, Shoulders, Triceps)",
                    exercises: [
                        Exercise(name: "Barbell Bench Press", targetSets: 4, targetReps: "8-10", currentWeight: 135.0),
                        Exercise(name: "Overhead Press", targetSets: 3, targetReps: "8-12", currentWeight: 95.0),
                        Exercise(name: "Incline Dumbbell Press", targetSets: 3, targetReps: "10-12", currentWeight: 45.0),
                        Exercise(name: "Lateral Raises", targetSets: 4, targetReps: "12-15", currentWeight: 20.0),
                        Exercise(name: "Tricep Pushdowns", targetSets: 3, targetReps: "12-15", currentWeight: 40.0)
                    ]
                ),
                WorkoutDay(
                    dayName: "Tuesday",
                    focus: "Pull (Back, Biceps)",
                    exercises: [
                        Exercise(name: "Deadlift", targetSets: 3, targetReps: "5", currentWeight: 225.0),
                        Exercise(name: "Pull-Ups (Assisted)", targetSets: 3, targetReps: "8-10", currentWeight: 0.0),
                        Exercise(name: "Barbell Rows", targetSets: 4, targetReps: "8-10", currentWeight: 135.0),
                        Exercise(name: "Face Pulls", targetSets: 3, targetReps: "15-20", currentWeight: 35.0),
                        Exercise(name: "Bicep Curls", targetSets: 3, targetReps: "10-12", currentWeight: 30.0)
                    ]
                ),
                WorkoutDay(
                    dayName: "Wednesday",
                    focus: "VO2 Max",
                    exercises: [
                        Exercise(name: "Norwegian 4x4 Run", targetSets: 4, targetReps: "4 min", currentWeight: 0.0, isCompleted: false),
                        Exercise(name: "Cool Down Walk", targetSets: 1, targetReps: "10 min", currentWeight: 0.0)
                    ]
                ),
                WorkoutDay(
                    dayName: "Thursday",
                    focus: "Legs & Push Hybrid",
                    exercises: [
                        Exercise(name: "Squats", targetSets: 4, targetReps: "6-8", currentWeight: 185.0),
                        Exercise(name: "Leg Press", targetSets: 3, targetReps: "10-12", currentWeight: 270.0),
                        Exercise(name: "Incline Bench Press", targetSets: 3, targetReps: "8-10", currentWeight: 115.0),
                        Exercise(name: "Bulgarian Split Squats", targetSets: 3, targetReps: "10 each", currentWeight: 0.0)
                    ]
                ),
                WorkoutDay(
                    dayName: "Friday",
                    focus: "Pull & VO2 Max Hybrid",
                    exercises: [
                        Exercise(name: "Weighted Pull-Ups", targetSets: 3, targetReps: "5-8", currentWeight: 10.0),
                        Exercise(name: "Dumbbell Rows", targetSets: 3, targetReps: "10", currentWeight: 60.0),
                        Exercise(name: "Hill Sprints", targetSets: 6, targetReps: "30 sec", currentWeight: 0.0)
                    ]
                )
            ]
        }
    }
}
