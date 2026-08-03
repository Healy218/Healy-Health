import Foundation
import Combine

class RoutineStore: ObservableObject {
    static let shared = RoutineStore()

    enum InitialLoadBehavior {
        case normal
        case empty
    }
    
    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()
    
    @Published var routines: [Routine] = []
    @Published var completedWorkouts: [CompletedWorkout] = []
    
    @Published var activeRoutineId: UUID? {
        didSet { saveActiveState() }
    }
    @Published var activeWorkoutId: UUID? {
        didSet { saveActiveState() }
    }
    
    @Published var selectedTab: Int = 0
    
    // Add properties to store the active routine and workout easily
    var activeRoutine: Routine? {
        routines.first { $0.id == activeRoutineId }
    }
    
    var activeWorkout: Workout? {
        activeRoutine?.workouts.first { $0.id == activeWorkoutId }
    }
    
    private let routinesFileName = "routines.json"
    private let historyFileName = "workout_history.json"
    private let documentsDirectory: URL
    private let userDefaults: UserDefaults
    
    // Legacy file names for migration
    private let legacyScheduleFileName = "workout_schedule.json"
    private let legacyCustomWorkoutsFileName = "custom_workouts.json"
    private let hasMigratedKey = "hasMigratedToRoutines"
    
    init(
        documentsDirectory: URL? = nil,
        userDefaults: UserDefaults = .standard,
        initialLoadBehavior: InitialLoadBehavior = .normal
    ) {
        self.documentsDirectory = documentsDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.userDefaults = userDefaults

        // Set up debounced save — saves at most once per second
        saveCancellable = saveSubject
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.performSaveRoutines()
                self?.performSaveHistory()
            }
        
        switch initialLoadBehavior {
        case .normal:
            if !userDefaults.bool(forKey: hasMigratedKey) {
                performMigration()
            } else {
                loadRoutines()
                loadHistory()
            }
            loadActiveState()
        case .empty:
            break
        }
    }
    
    // MARK: - Migration
    struct LegacyWorkoutDay: Codable {
        var id = UUID()
        var dayName: String
        var focus: String
        var exercises: [Exercise]
    }
    
    private func performMigration() {
        var migratedRoutines: [Routine] = []
        
        let urlSchedule = getDocumentsDirectory().appendingPathComponent(legacyScheduleFileName)
        
        // 1. Migrate Main Schedule
        if let data = try? Data(contentsOf: urlSchedule),
           let decoded = try? JSONDecoder().decode([LegacyWorkoutDay].self, from: data) {
            let workouts = decoded.map { Workout(id: $0.id, name: $0.dayName, focus: $0.focus, exercises: $0.exercises) }
            if !workouts.isEmpty {
                let mainRoutine = Routine(name: "Legacy Weekly Schedule", workouts: workouts)
                migratedRoutines.append(mainRoutine)
            }
        }
        
        // 2. Migrate Custom Workouts
        let urlCustom = getDocumentsDirectory().appendingPathComponent(legacyCustomWorkoutsFileName)
        if let data = try? Data(contentsOf: urlCustom),
           let decoded = try? JSONDecoder().decode([LegacyWorkoutDay].self, from: data) {
            let workouts = decoded.map { Workout(id: $0.id, name: $0.dayName, focus: $0.focus, exercises: $0.exercises) }
            if !workouts.isEmpty {
                let customRoutine = Routine(name: "Legacy Custom Workouts", workouts: workouts)
                migratedRoutines.append(customRoutine)
            }
        }
        
        // Save the migrated routines
        if migratedRoutines.isEmpty {
            loadDefaultRoutines()
        } else {
            self.routines = migratedRoutines
            saveRoutines()
        }
        
        // 3. Keep History the same, just load it
        loadHistory()
        
        // Mark as migrated
        userDefaults.set(true, forKey: hasMigratedKey)
    }
    
    // MARK: - Actions
    func toggleExerciseCompletion(routineId: UUID, workoutId: UUID, exerciseId: UUID) {
        if let rIndex = routines.firstIndex(where: { $0.id == routineId }),
           let wIndex = routines[rIndex].workouts.firstIndex(where: { $0.id == workoutId }),
           let eIndex = routines[rIndex].workouts[wIndex].exercises.firstIndex(where: { $0.id == exerciseId }) {
            routines[rIndex].workouts[wIndex].exercises[eIndex].isCompleted.toggle()
            saveRoutines()
        }
    }
    
    func finishWorkout(routine: Routine, workout: Workout) {
        // Record in history
        let finishedWorkout = CompletedWorkout(
            date: Date(),
            dayName: workout.name,
            focus: workout.focus,
            exercises: workout.exercises,
            routineId: routine.id,
            workoutId: workout.id
        )
        completedWorkouts.insert(finishedWorkout, at: 0)
        performSaveHistory()

        // Mark this workout as completed within the routine (don't reset yet)
        if let rIndex = routines.firstIndex(where: { $0.id == routine.id }),
           let wIndex = routines[rIndex].workouts.firstIndex(where: { $0.id == workout.id }) {
            routines[rIndex].workouts[wIndex].isCompleted = true
            performSaveRoutines()
        }

        // Return to the routine workout list
        activeWorkoutId = nil
    }

    /// Called when the user finishes the entire routine.
    /// - Parameter startNew: if true, clears the active routine so they can pick a new one.
    func finishRoutine(startNew: Bool) {
        if let rIndex = routines.firstIndex(where: { $0.id == activeRoutineId }) {
            for wIndex in routines[rIndex].workouts.indices {
                routines[rIndex].workouts[wIndex].isCompleted = false
                for eIndex in routines[rIndex].workouts[wIndex].exercises.indices {
                    routines[rIndex].workouts[wIndex].exercises[eIndex].isCompleted = false
                    routines[rIndex].workouts[wIndex].exercises[eIndex].logs.removeAll()
                }
            }
            performSaveRoutines()
        }
        activeWorkoutId = nil
        if startNew { activeRoutineId = nil }
    }
    
    func addRoutine(_ routine: Routine) {
        routines.append(routine)
        saveRoutines()
    }
    
    func updateRoutine(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
            saveRoutines()
        }
    }
    
    func deleteRoutine(_ routine: Routine) {
        deleteRoutines(ids: [routine.id])
    }

    func deleteRoutines(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }

        let removedActiveRoutine = activeRoutineId.map(ids.contains) ?? false
        routines.removeAll { ids.contains($0.id) }

        if removedActiveRoutine {
            activeRoutineId = nil
            activeWorkoutId = nil
        }
        saveRoutines()
    }

    func deleteWorkouts(routineId: UUID, ids: Set<UUID>) {
        guard !ids.isEmpty,
              let routineIndex = routines.firstIndex(where: { $0.id == routineId }) else {
            return
        }

        routines[routineIndex].workouts.removeAll { ids.contains($0.id) }
        if activeRoutineId == routineId,
           activeWorkoutId.map(ids.contains) ?? false {
            activeWorkoutId = nil
        }
        saveRoutines()
    }
    
    // MARK: - Persistence
    private func getDocumentsDirectory() -> URL {
        documentsDirectory
    }
    
    // Fix #3: Public save methods now debounce
    func saveRoutines() {
        saveSubject.send()
    }
    
    func saveHistory() {
        saveSubject.send()
    }

    /// Persists the current store state immediately. Used for lifecycle flushing and deterministic tests.
    func flushSaves() {
        performSaveRoutines()
        performSaveHistory()
    }
    
    // Fix #8: ISO 8601 date encoding for new saves, backward-compatible loading
    private var iso8601Encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    /// Tries ISO 8601 first, falls back to default (deferredToDate) for legacy data
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        let iso8601Decoder = JSONDecoder()
        iso8601Decoder.dateDecodingStrategy = .iso8601
        if let result = try? iso8601Decoder.decode(type, from: data) {
            return result
        }
        // Fallback to default decoder for legacy data
        return try? JSONDecoder().decode(type, from: data)
    }
    
    // Actual save implementations
    private func performSaveRoutines() {
        if let data = try? iso8601Encoder.encode(routines) {
            let url = getDocumentsDirectory().appendingPathComponent(routinesFileName)
            try? data.write(to: url)
        }
    }
    
    func performSaveHistory() {
        if let data = try? iso8601Encoder.encode(completedWorkouts) {
            let url = getDocumentsDirectory().appendingPathComponent(historyFileName)
            try? data.write(to: url)
        }
    }
    
    private func loadRoutines() {
        let url = getDocumentsDirectory().appendingPathComponent(routinesFileName)
        if let data = try? Data(contentsOf: url),
           let decoded = decode([Routine].self, from: data) {
            self.routines = decoded
        } else {
            loadDefaultRoutines()
        }
    }
    
    private func loadHistory() {
        let url = getDocumentsDirectory().appendingPathComponent(historyFileName)
        if let data = try? Data(contentsOf: url),
           let decoded = decode([CompletedWorkout].self, from: data) {
            self.completedWorkouts = decoded
        }
    }
    
    private func saveActiveState() {
        userDefaults.set(activeRoutineId?.uuidString, forKey: "activeRoutineId")
        userDefaults.set(activeWorkoutId?.uuidString, forKey: "activeWorkoutId")
    }

    private func loadActiveState() {
        if let rIdStr = userDefaults.string(forKey: "activeRoutineId"), let rId = UUID(uuidString: rIdStr) {
            activeRoutineId = rId
        }
        if let wIdStr = userDefaults.string(forKey: "activeWorkoutId"), let wId = UUID(uuidString: wIdStr) {
            activeWorkoutId = wId
        }
    }
    
    private func loadDefaultRoutines() {
        let defaultWorkouts = [
            Workout(
                name: "Push Day",
                focus: "Chest, Shoulders, Triceps",
                exercises: [
                    Exercise(name: "Barbell Bench Press", targetSets: 4, targetReps: "8-10", currentWeight: 135.0),
                    Exercise(name: "Overhead Press", targetSets: 3, targetReps: "8-12", currentWeight: 95.0),
                    Exercise(name: "Incline Dumbbell Press", targetSets: 3, targetReps: "10-12", currentWeight: 45.0),
                    Exercise(name: "Lateral Raises", targetSets: 4, targetReps: "12-15", currentWeight: 20.0),
                    Exercise(name: "Tricep Pushdowns", targetSets: 3, targetReps: "12-15", currentWeight: 40.0)
                ]
            ),
            Workout(
                name: "Pull Day",
                focus: "Back, Biceps",
                exercises: [
                    Exercise(name: "Deadlift", targetSets: 3, targetReps: "5", currentWeight: 225.0),
                    Exercise(name: "Pull-Ups (Assisted)", targetSets: 3, targetReps: "8-10", currentWeight: 0.0),
                    Exercise(name: "Barbell Rows", targetSets: 4, targetReps: "8-10", currentWeight: 135.0),
                    Exercise(name: "Face Pulls", targetSets: 3, targetReps: "15-20", currentWeight: 35.0),
                    Exercise(name: "Bicep Curls", targetSets: 3, targetReps: "10-12", currentWeight: 30.0)
                ]
            ),
            Workout(
                name: "Legs & Push Hybrid",
                focus: "Legs, Push",
                exercises: [
                    Exercise(name: "Squats", targetSets: 4, targetReps: "6-8", currentWeight: 185.0),
                    Exercise(name: "Leg Press", targetSets: 3, targetReps: "10-12", currentWeight: 270.0),
                    Exercise(name: "Incline Bench Press", targetSets: 3, targetReps: "8-10", currentWeight: 115.0),
                    Exercise(name: "Bulgarian Split Squats", targetSets: 3, targetReps: "10 each", currentWeight: 0.0)
                ]
            )
        ]
        
        let defaultRoutine = Routine(name: "Push Pull Legs", workouts: defaultWorkouts)
        self.routines = [defaultRoutine]
        saveRoutines()
    }
}
