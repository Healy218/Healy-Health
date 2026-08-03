import Foundation
import Combine

/// A template for an exercise, used in the Exercise Library
struct ExerciseTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var primaryMuscleGroup: String
    // E.g. "Barbell", "Dumbbell", "Machine", "Bodyweight"
    var equipmentType: String 
}

class ExerciseManager: ObservableObject {
    static let shared = ExerciseManager()
    
    @Published var exercises: [ExerciseTemplate] = []
    @Published private(set) var persistenceError: PersistenceError?
    
    private let libraryFileName = "exercise_library.json"
    
    private init() {
        loadLibrary()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Writes an import candidate without changing the currently displayed library.
    func persistImportCandidate(_ templates: [ExerciseTemplate]) throws {
        let data = try JSONEncoder().encode(templates)
        let url = getDocumentsDirectory().appendingPathComponent(libraryFileName)
        try data.write(to: url, options: .atomic)
    }

    func applyImportedLibrary(_ templates: [ExerciseTemplate]) {
        exercises = templates
    }
    
    @discardableResult
    func saveLibrary() -> Bool {
        do {
            let data = try JSONEncoder().encode(exercises)
            let url = getDocumentsDirectory().appendingPathComponent(libraryFileName)
            try data.write(to: url, options: .atomic)
            clearPersistenceError(for: .exerciseLibrary)
            return true
        } catch {
            recordPersistenceError(operation: .save, error: error)
            return false
        }
    }
    
    private func loadLibrary() {
        let url = getDocumentsDirectory().appendingPathComponent(libraryFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            loadDefaultExercises()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([ExerciseTemplate].self, from: data)
            exercises = decoded
        } catch {
            recordPersistenceError(operation: .load, error: error)
        }
    }
    
    func addExercise(_ template: ExerciseTemplate) {
        exercises.append(template)
        // Sort alphabetically
        exercises.sort { $0.name < $1.name }
        saveLibrary()
    }
    
    private func loadDefaultExercises() {
        exercises = [
            ExerciseTemplate(name: "Barbell Bench Press", primaryMuscleGroup: "Chest", equipmentType: "Barbell"),
            ExerciseTemplate(name: "Incline Dumbbell Press", primaryMuscleGroup: "Chest", equipmentType: "Dumbbell"),
            ExerciseTemplate(name: "Overhead Press", primaryMuscleGroup: "Shoulders", equipmentType: "Barbell"),
            ExerciseTemplate(name: "Lateral Raises", primaryMuscleGroup: "Shoulders", equipmentType: "Dumbbell"),
            ExerciseTemplate(name: "Tricep Pushdowns", primaryMuscleGroup: "Triceps", equipmentType: "Cable"),
            
            ExerciseTemplate(name: "Deadlift", primaryMuscleGroup: "Back", equipmentType: "Barbell"),
            ExerciseTemplate(name: "Pull-Ups (Assisted)", primaryMuscleGroup: "Back", equipmentType: "Machine"),
            ExerciseTemplate(name: "Weighted Pull-Ups", primaryMuscleGroup: "Back", equipmentType: "Bodyweight/Weights"),
            ExerciseTemplate(name: "Barbell Rows", primaryMuscleGroup: "Back", equipmentType: "Barbell"),
            ExerciseTemplate(name: "Dumbbell Rows", primaryMuscleGroup: "Back", equipmentType: "Dumbbell"),
            ExerciseTemplate(name: "Face Pulls", primaryMuscleGroup: "Shoulders", equipmentType: "Cable"),
            ExerciseTemplate(name: "Bicep Curls", primaryMuscleGroup: "Biceps", equipmentType: "Dumbbell"),
            
            ExerciseTemplate(name: "Squats", primaryMuscleGroup: "Legs", equipmentType: "Barbell"),
            ExerciseTemplate(name: "Leg Press", primaryMuscleGroup: "Legs", equipmentType: "Machine"),
            ExerciseTemplate(name: "Bulgarian Split Squats", primaryMuscleGroup: "Legs", equipmentType: "Dumbbell/Bodyweight"),
            
            ExerciseTemplate(name: "Norwegian 4x4 Run", primaryMuscleGroup: "Cardio", equipmentType: "Treadmill/Track"),
            ExerciseTemplate(name: "Cool Down Walk", primaryMuscleGroup: "Cardio", equipmentType: "Treadmill/Track"),
            ExerciseTemplate(name: "Hill Sprints", primaryMuscleGroup: "Cardio", equipmentType: "Treadmill/Track")
        ]
        
        exercises.sort { $0.name < $1.name }
    }

    func clearPersistenceError() {
        persistenceError = nil
    }

    private func recordPersistenceError(operation: PersistenceOperation, error: Error) {
        persistenceError = PersistenceError(
            resource: .exerciseLibrary,
            operation: operation,
            underlyingErrorDescription: error.localizedDescription
        )
    }

    private func clearPersistenceError(for resource: PersistenceResource) {
        guard persistenceError?.resource == resource else { return }
        persistenceError = nil
    }
}
