import Foundation
import Combine

class WorkoutSchedule: ObservableObject {
    static let shared = WorkoutSchedule()
    
    @Published var fullSchedule: [WorkoutDay] = []
    @Published var customWorkouts: [WorkoutDay] = []
    @Published var completedWorkouts: [CompletedWorkout] = []

    private let scheduleFileName = "workout_schedule.json"
    private let historyFileName = "workout_history.json"
    private let customWorkoutsFileName = "custom_workouts.json"
    
    private init() {
        loadSchedule()
        loadHistory()
        loadCustomWorkouts()
    }
    
    func toggleExerciseCompletion(dayId: UUID, exerciseId: UUID) {
        if let dayIndex = fullSchedule.firstIndex(where: { $0.id == dayId }),
           let exerciseIndex = fullSchedule[dayIndex].exercises.firstIndex(where: { $0.id == exerciseId }) {
            fullSchedule[dayIndex].exercises[exerciseIndex].isCompleted.toggle()
            saveSchedule()
        }
    }
    
    func finishWorkout(day: WorkoutDay) {
        // 1. Create a record of the completed workout
        let finishedWorkout = CompletedWorkout(
            date: Date(),
            dayName: day.dayName,
            focus: day.focus,
            exercises: day.exercises
        )
        
        // 2. Append to history and save
        completedWorkouts.insert(finishedWorkout, at: 0) // Newest first
        saveHistory()
        
        // 3. Reset the current schedule day for next time
        if let index = fullSchedule.firstIndex(where: { $0.id == day.id }) {
            for i in 0..<fullSchedule[index].exercises.count {
                fullSchedule[index].exercises[i].isCompleted = false
                fullSchedule[index].exercises[i].logs.removeAll() // Clear logs for a fresh start next week
                // Note: If you wanted to keep "Prvious Best" logs, you'd store them separately or not clear them.
                // For now, "History" is the record, so we clear the active day.
            }
            saveSchedule()
        }
        
        // Also reset if it's a custom workout
        if let index = customWorkouts.firstIndex(where: { $0.id == day.id }) {
            for i in 0..<customWorkouts[index].exercises.count {
                customWorkouts[index].exercises[i].isCompleted = false
                customWorkouts[index].exercises[i].logs.removeAll()
            }
            saveCustomWorkouts()
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveSchedule() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(fullSchedule) {
            let url = getDocumentsDirectory().appendingPathComponent(scheduleFileName)
            try? data.write(to: url)
        }
    }
    
    func saveCustomWorkouts() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(customWorkouts) {
            let url = getDocumentsDirectory().appendingPathComponent(customWorkoutsFileName)
            try? data.write(to: url)
        }
    }
    
    func addCustomWorkout(_ day: WorkoutDay) {
        customWorkouts.append(day)
        saveCustomWorkouts()
    }
    
    func saveHistory() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(completedWorkouts) {
            let url = getDocumentsDirectory().appendingPathComponent(historyFileName)
            try? data.write(to: url)
        }
    }
    
    private func loadSchedule() {
        let url = getDocumentsDirectory().appendingPathComponent(scheduleFileName)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([WorkoutDay].self, from: data) {
            fullSchedule = decoded
        } else {
            loadDefaultSchedule()
        }
    }
    
    private func loadCustomWorkouts() {
        let url = getDocumentsDirectory().appendingPathComponent(customWorkoutsFileName)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([WorkoutDay].self, from: data) {
            customWorkouts = decoded
        }
        
        // Seed default Push/Pull/Legs routines if we have no custom workouts
        if customWorkouts.isEmpty {
            // Re-use `fullSchedule` if it happens to be the default,
            // or just load the default schedule to pull them out.
            var tempSchedule: [WorkoutDay] = []
            
            // To guarantee we get the hardcoded defaults, we can call the same logic
            // that loadDefaultSchedule uses but return it. Let's just create them inline here for seeding.
            let defaultDays = [
                WorkoutDay(
                    dayName: "Push Day",
                    focus: "Chest, Shoulders, Triceps",
                    exercises: [
                        Exercise(name: "Barbell Bench Press", targetSets: 4, targetReps: "8-10", currentWeight: 135.0),
                        Exercise(name: "Overhead Press", targetSets: 3, targetReps: "8-12", currentWeight: 95.0),
                        Exercise(name: "Incline Dumbbell Press", targetSets: 3, targetReps: "10-12", currentWeight: 45.0),
                        Exercise(name: "Lateral Raises", targetSets: 4, targetReps: "12-15", currentWeight: 20.0),
                        Exercise(name: "Tricep Pushdowns", targetSets: 3, targetReps: "12-15", currentWeight: 40.0)
                    ]
                ),
                WorkoutDay(
                    dayName: "Pull Day",
                    focus: "Back, Biceps",
                    exercises: [
                        Exercise(name: "Deadlift", targetSets: 3, targetReps: "5", currentWeight: 225.0),
                        Exercise(name: "Pull-Ups (Assisted)", targetSets: 3, targetReps: "8-10", currentWeight: 0.0),
                        Exercise(name: "Barbell Rows", targetSets: 4, targetReps: "8-10", currentWeight: 135.0),
                        Exercise(name: "Face Pulls", targetSets: 3, targetReps: "15-20", currentWeight: 35.0),
                        Exercise(name: "Bicep Curls", targetSets: 3, targetReps: "10-12", currentWeight: 30.0)
                    ]
                ),
                WorkoutDay(
                    dayName: "Legs & Push Hybrid",
                    focus: "Legs, Push",
                    exercises: [
                        Exercise(name: "Squats", targetSets: 4, targetReps: "6-8", currentWeight: 185.0),
                        Exercise(name: "Leg Press", targetSets: 3, targetReps: "10-12", currentWeight: 270.0),
                        Exercise(name: "Incline Bench Press", targetSets: 3, targetReps: "8-10", currentWeight: 115.0),
                        Exercise(name: "Bulgarian Split Squats", targetSets: 3, targetReps: "10 each", currentWeight: 0.0)
                    ]
                )
            ]
            
            customWorkouts.append(contentsOf: defaultDays)
            saveCustomWorkouts()
        }
    }
    
    private func loadHistory() {
        let url = getDocumentsDirectory().appendingPathComponent(historyFileName)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([CompletedWorkout].self, from: data) {
            completedWorkouts = decoded
        }
    }
    
    private func loadDefaultSchedule() {
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
