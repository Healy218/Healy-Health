import Foundation
import Combine

enum PersistenceResource: String {
    case routines
    case history
    case exerciseLibrary

    var displayName: String {
        switch self {
        case .routines:
            return "routines"
        case .history:
            return "workout history"
        case .exerciseLibrary:
            return "exercise library"
        }
    }
}

enum PersistenceOperation: String {
    case load
    case save
    case migration
}

struct PersistenceError: LocalizedError, Identifiable {
    let resource: PersistenceResource
    let operation: PersistenceOperation
    let underlyingErrorDescription: String

    var id: String {
        "\(resource.rawValue)-\(operation.rawValue)-\(underlyingErrorDescription)"
    }

    var errorDescription: String? {
        switch operation {
        case .load:
            return "Couldn’t load your \(resource.displayName)."
        case .save:
            return "Couldn’t save your \(resource.displayName)."
        case .migration:
            return "Couldn’t migrate your legacy \(resource.displayName)."
        }
    }

    var recoverySuggestion: String? {
        switch operation {
        case .load:
            return "The existing file was left unchanged. Please keep the app open and try again after freeing storage or restoring a backup."
        case .save:
            return "No existing saved file was overwritten. Please keep the app open and try again after freeing storage."
        case .migration:
            return "Your legacy data was left unchanged. Please keep the app open and try again after freeing storage or restoring a backup."
        }
    }
}

enum WorkoutCompletionError: LocalizedError, Equatable {
    case routineNotFound
    case workoutNotFound
    case alreadyCompleted

    var errorDescription: String? {
        switch self {
        case .routineNotFound:
            return "This routine is no longer available."
        case .workoutNotFound:
            return "This workout is no longer available in the selected routine."
        case .alreadyCompleted:
            return "This workout has already been completed."
        }
    }
}

enum SetLogMutationError: LocalizedError, Equatable {
    case routineNotFound
    case workoutNotFound
    case exerciseNotFound
    case logNotFound
    case invalidLog(ExerciseValidationError)

    var errorDescription: String? {
        switch self {
        case .routineNotFound:
            return "This routine is no longer available."
        case .workoutNotFound:
            return "This workout is no longer available in the selected routine."
        case .exerciseNotFound:
            return "This exercise is no longer available in the selected workout."
        case .logNotFound:
            return "This logged set is no longer available."
        case .invalidLog(let error):
            return error.localizedDescription
        }
    }
}

/// The rest countdown belongs to the active workout, rather than an individual exercise screen.
/// Keeping its absolute deadline lets the UI accurately resume after navigation, backgrounding,
/// or a new app process.
struct ActiveRestTimerState: Codable, Equatable {
    let routineId: UUID
    let workoutId: UUID
    let exerciseId: UUID
    var endTime: Date
    var notificationId: UUID
}

class RoutineStore: ObservableObject {
    static let shared = RoutineStore()

    enum InitialLoadBehavior {
        case normal
        case empty
    }
    
    private var routinesSaveCancellable: AnyCancellable?
    private var historySaveCancellable: AnyCancellable?
    private let routinesSaveSubject = PassthroughSubject<Void, Never>()
    private let historySaveSubject = PassthroughSubject<Void, Never>()
    
    @Published var routines: [Routine] = []
    @Published var completedWorkouts: [CompletedWorkout] = []
    
    @Published var activeRoutineId: UUID? {
        didSet { saveActiveState() }
    }
    @Published var activeWorkoutId: UUID? {
        didSet { saveActiveState() }
    }
    @Published private(set) var activeWorkoutStartedAt: Date? {
        didSet { saveActiveState() }
    }
    @Published private(set) var activeRestTimer: ActiveRestTimerState? {
        didSet { saveActiveState() }
    }
    
    @Published var selectedTab: Int = 0
    @Published private(set) var persistenceError: PersistenceError?
    
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
    private let dataWriter: (Data, URL) throws -> Void
    
    // Legacy file names for migration
    private let legacyScheduleFileName = "workout_schedule.json"
    private let legacyCustomWorkoutsFileName = "custom_workouts.json"
    private let hasMigratedKey = "hasMigratedToRoutines"
    private let activeRoutineIdKey = "activeRoutineId"
    private let activeWorkoutIdKey = "activeWorkoutId"
    private let activeWorkoutStartedAtKey = "activeWorkoutStartedAt"
    private let activeRestTimerKey = "activeRestTimer"

    /// The directory containing the app's routine and history files. Import/export uses this
    /// to keep its recovery snapshots alongside the data they protect.
    var persistenceDirectory: URL { documentsDirectory }
    
    init(
        documentsDirectory: URL? = nil,
        userDefaults: UserDefaults = .standard,
        initialLoadBehavior: InitialLoadBehavior = .normal,
        saveDebounceInterval: TimeInterval = 1,
        dataWriter: @escaping (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) {
        self.documentsDirectory = documentsDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.userDefaults = userDefaults
        self.dataWriter = dataWriter

        // Keep routine and history saves independent so a routine edit never writes history.
        routinesSaveCancellable = routinesSaveSubject
            .debounce(for: .seconds(saveDebounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.performSaveRoutines()
            }
        historySaveCancellable = historySaveSubject
            .debounce(for: .seconds(saveDebounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] in
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

    private struct LegacyMigrationReadError: LocalizedError {
        let fileName: String
        let underlyingError: Error

        var errorDescription: String? {
            "Couldn’t read \(fileName): \(underlyingError.localizedDescription)"
        }
    }
    
    private func performMigration() {
        var migratedRoutines: [Routine] = []
        let urlSchedule = getDocumentsDirectory().appendingPathComponent(legacyScheduleFileName)
        let urlCustom = getDocumentsDirectory().appendingPathComponent(legacyCustomWorkoutsFileName)

        let scheduleDays: [LegacyWorkoutDay]?
        switch readLegacyWorkouts(from: urlSchedule) {
        case .success(let days):
            scheduleDays = days
        case .failure(let error):
            recordPersistenceError(resource: .routines, operation: .migration, error: error)
            return
        }

        let customDays: [LegacyWorkoutDay]?
        switch readLegacyWorkouts(from: urlCustom) {
        case .success(let days):
            customDays = days
        case .failure(let error):
            recordPersistenceError(resource: .routines, operation: .migration, error: error)
            return
        }

        appendMigratedRoutine(named: "Legacy Weekly Schedule", from: scheduleDays, to: &migratedRoutines)
        appendMigratedRoutine(named: "Legacy Custom Workouts", from: customDays, to: &migratedRoutines)

        if migratedRoutines.isEmpty {
            guard loadDefaultRoutines(immediatelyPersist: true) else { return }
        } else {
            self.routines = migratedRoutines
            guard performSaveRoutines() else { return }
        }

        loadHistory()
        userDefaults.set(true, forKey: hasMigratedKey)
    }

    private func readLegacyWorkouts(from url: URL) -> Result<[LegacyWorkoutDay]?, Error> {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .success(nil)
        }

        do {
            let data = try Data(contentsOf: url)
            return .success(try decode([LegacyWorkoutDay].self, from: data))
        } catch {
            return .failure(LegacyMigrationReadError(fileName: url.lastPathComponent, underlyingError: error))
        }
    }

    private func appendMigratedRoutine(
        named name: String,
        from legacyDays: [LegacyWorkoutDay]?,
        to routines: inout [Routine]
    ) {
        guard let legacyDays, !legacyDays.isEmpty else { return }
        let workouts = legacyDays.map {
            Workout(id: $0.id, name: $0.dayName, focus: $0.focus, exercises: $0.exercises)
        }
        routines.append(Routine(name: name, workouts: workouts))
    }
    
    // MARK: - Actions
    /// Starts (or resumes) a routine while intentionally retaining a rest timer when returning
    /// to the same routine. Switching routines discards the previous session context.
    func startRoutine(routineId: UUID) {
        guard routines.contains(where: { $0.id == routineId }) else { return }

        if activeRoutineId != routineId {
            cancelActiveRestTimer()
            activeWorkoutStartedAt = nil
        }
        activeRoutineId = routineId
        activeWorkoutId = nil
    }

    /// Starts a workout with a durable start timestamp. Re-selecting the same workout preserves
    /// its original timestamp; choosing a different workout starts a new session.
    func startWorkout(routineId: UUID, workoutId: UUID, startedAt: Date = Date()) {
        guard let routine = routines.first(where: { $0.id == routineId }),
              routine.workouts.contains(where: { $0.id == workoutId }) else {
            return
        }

        let isNewWorkout = activeRoutineId != routineId || activeWorkoutId != workoutId
        if isNewWorkout {
            cancelActiveRestTimer()
            activeWorkoutStartedAt = startedAt
        }
        activeRoutineId = routineId
        activeWorkoutId = workoutId
    }

    /// Stores a rest timer against the exact exercise that created it. Notification scheduling
    /// remains in the view so notification authorization errors can be presented there.
    @discardableResult
    func startRestTimer(
        routineId: UUID,
        workoutId: UUID,
        exerciseId: UUID,
        duration: TimeInterval,
        now: Date = Date()
    ) -> ActiveRestTimerState? {
        guard case .success(let validDuration) = RestTimerDuration.validate(duration),
              routines.first(where: { $0.id == routineId })?.workouts.first(where: { $0.id == workoutId })?.exercises.contains(where: { $0.id == exerciseId }) == true else {
            return nil
        }

        cancelActiveRestTimer()
        let timer = ActiveRestTimerState(
            routineId: routineId,
            workoutId: workoutId,
            exerciseId: exerciseId,
            endTime: now.addingTimeInterval(validDuration),
            notificationId: UUID()
        )
        activeRestTimer = timer
        return timer
    }

    /// Adds time by replacing the notification identity, since a cancelled notification cannot
    /// be safely reused while an authorization request is in flight.
    @discardableResult
    func addRestTime(
        routineId: UUID,
        workoutId: UUID,
        exerciseId: UUID,
        seconds: TimeInterval = 30
    ) -> ActiveRestTimerState? {
        guard case .success(let validSeconds) = RestTimerDuration.validate(seconds),
              var timer = matchingRestTimer(routineId: routineId, workoutId: workoutId, exerciseId: exerciseId) else {
            return nil
        }

        NotificationManager.shared.cancelTimer(identifier: timer.notificationId)
        timer.endTime = timer.endTime.addingTimeInterval(validSeconds)
        timer.notificationId = UUID()
        activeRestTimer = timer
        return timer
    }

    func cancelRestTimer(routineId: UUID, workoutId: UUID, exerciseId: UUID) {
        guard matchingRestTimer(routineId: routineId, workoutId: workoutId, exerciseId: exerciseId) != nil else {
            return
        }
        cancelActiveRestTimer()
    }

    /// Clears an elapsed timer and returns whether the countdown finished during this call.
    @discardableResult
    func clearExpiredRestTimer(now: Date = Date()) -> Bool {
        guard let timer = activeRestTimer, timer.endTime <= now else { return false }
        cancelActiveRestTimer()
        return true
    }

    func toggleExerciseCompletion(routineId: UUID, workoutId: UUID, exerciseId: UUID) {
        if let rIndex = routines.firstIndex(where: { $0.id == routineId }),
           let wIndex = routines[rIndex].workouts.firstIndex(where: { $0.id == workoutId }),
           let eIndex = routines[rIndex].workouts[wIndex].exercises.firstIndex(where: { $0.id == exerciseId }) {
            routines[rIndex].workouts[wIndex].exercises[eIndex].isCompleted.toggle()
            saveRoutines()
        }
    }

    /// Replaces one logged set using the current routine graph, then writes the change before
    /// returning. Keeping this mutation in the store prevents a stale view from editing a
    /// different exercise and gives all set-entry paths the same validation rules.
    @discardableResult
    func updateLoggedSet(
        routineId: UUID,
        workoutId: UUID,
        exerciseId: UUID,
        logId: UUID,
        weight: Double,
        reps: Int
    ) -> Result<Void, SetLogMutationError> {
        let validatedLog: ValidatedSetLog
        do {
            validatedLog = try ExerciseDomainValidation.setLog(weight: weight, reps: reps)
        } catch let error as ExerciseValidationError {
            return .failure(.invalidLog(error))
        } catch {
            return .failure(.invalidLog(.invalidWeight))
        }

        guard let routineIndex = routines.firstIndex(where: { $0.id == routineId }) else {
            return .failure(.routineNotFound)
        }
        guard let workoutIndex = routines[routineIndex].workouts.firstIndex(where: { $0.id == workoutId }) else {
            return .failure(.workoutNotFound)
        }
        guard let exerciseIndex = routines[routineIndex].workouts[workoutIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return .failure(.exerciseNotFound)
        }
        guard let logIndex = routines[routineIndex].workouts[workoutIndex].exercises[exerciseIndex].logs.firstIndex(where: { $0.id == logId }) else {
            return .failure(.logNotFound)
        }

        routines[routineIndex].workouts[workoutIndex].exercises[exerciseIndex].logs[logIndex].weight = validatedLog.weight
        routines[routineIndex].workouts[workoutIndex].exercises[exerciseIndex].logs[logIndex].reps = validatedLog.reps
        performSaveRoutines()
        return .success(())
    }

    /// Deletes exactly one logged set. If the correction puts a manually finished exercise below
    /// its target, its completion state is reset so the session UI reflects the remaining work.
    @discardableResult
    func deleteLoggedSet(
        routineId: UUID,
        workoutId: UUID,
        exerciseId: UUID,
        logId: UUID
    ) -> Result<Void, SetLogMutationError> {
        guard let routineIndex = routines.firstIndex(where: { $0.id == routineId }) else {
            return .failure(.routineNotFound)
        }
        guard let workoutIndex = routines[routineIndex].workouts.firstIndex(where: { $0.id == workoutId }) else {
            return .failure(.workoutNotFound)
        }
        guard let exerciseIndex = routines[routineIndex].workouts[workoutIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return .failure(.exerciseNotFound)
        }
        guard let logIndex = routines[routineIndex].workouts[workoutIndex].exercises[exerciseIndex].logs.firstIndex(where: { $0.id == logId }) else {
            return .failure(.logNotFound)
        }

        routines[routineIndex].workouts[workoutIndex].exercises[exerciseIndex].logs.remove(at: logIndex)
        if routines[routineIndex].workouts[workoutIndex].exercises[exerciseIndex].logs.count
            < routines[routineIndex].workouts[workoutIndex].exercises[exerciseIndex].targetSets {
            routines[routineIndex].workouts[workoutIndex].exercises[exerciseIndex].isCompleted = false
        }
        performSaveRoutines()
        return .success(())
    }
    
    /// Completes the workout currently stored under the supplied IDs. Resolving it here avoids
    /// recording stale view snapshots and makes a second completion attempt a no-op.
    @discardableResult
    func finishWorkout(routineId: UUID, workoutId: UUID) -> Result<Void, WorkoutCompletionError> {
        guard let routineIndex = routines.firstIndex(where: { $0.id == routineId }) else {
            return .failure(.routineNotFound)
        }
        guard let workoutIndex = routines[routineIndex].workouts.firstIndex(where: { $0.id == workoutId }) else {
            return .failure(.workoutNotFound)
        }
        guard !routines[routineIndex].workouts[workoutIndex].isCompleted else {
            return .failure(.alreadyCompleted)
        }

        let routine = routines[routineIndex]
        let workout = routines[routineIndex].workouts[workoutIndex]
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

        // Mark this workout as completed within the routine (don't reset yet).
        routines[routineIndex].workouts[workoutIndex].isCompleted = true
        performSaveRoutines()

        // Return to the routine workout list
        cancelRestTimerForWorkout(routineId: routineId, workoutId: workoutId)
        activeWorkoutStartedAt = nil
        activeWorkoutId = nil
        return .success(())
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
        cancelActiveRestTimer()
        activeWorkoutStartedAt = nil
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
            cancelActiveRestTimer()
            activeWorkoutStartedAt = nil
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
            cancelRestTimerForWorkout(routineId: routineId, workoutId: activeWorkoutId!)
            activeWorkoutStartedAt = nil
            activeWorkoutId = nil
        }
        if let timer = activeRestTimer, timer.routineId == routineId, ids.contains(timer.workoutId) {
            cancelActiveRestTimer()
        }
        saveRoutines()
    }
    
    // MARK: - Persistence
    private func getDocumentsDirectory() -> URL {
        documentsDirectory
    }
    
    // MARK: - Persistence

    /// Schedules only routine data for persistence.
    func saveRoutines() {
        routinesSaveSubject.send()
    }

    /// Schedules only completed-workout history for persistence.
    func saveHistory() {
        historySaveSubject.send()
    }

    /// Persists the current store state immediately. Used for lifecycle flushing and deterministic tests.
    @discardableResult
    func flushSaves() -> Bool {
        performSaveRoutines() && performSaveHistory()
    }

    func clearPersistenceError() {
        persistenceError = nil
    }
    
    // Fix #8: ISO 8601 date encoding for new saves, backward-compatible loading
    private var iso8601Encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    /// Tries ISO 8601 first, falls back to default (deferredToDate) for legacy data
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let iso8601Decoder = JSONDecoder()
        iso8601Decoder.dateDecodingStrategy = .iso8601
        do {
            return try iso8601Decoder.decode(type, from: data)
        } catch {
            let legacyDecoder = JSONDecoder()
            return try legacyDecoder.decode(type, from: data)
        }
    }

    // Actual save implementations. Atomic writes leave the previous complete file in place on failure.
    @discardableResult
    private func performSaveRoutines() -> Bool {
        save(routines, to: routinesFileName, resource: .routines)
    }

    @discardableResult
    func performSaveHistory() -> Bool {
        save(completedWorkouts, to: historyFileName, resource: .history)
    }

    @discardableResult
    private func save<T: Encodable>(_ value: T, to fileName: String, resource: PersistenceResource) -> Bool {
        do {
            try write(value, to: fileName)
            clearPersistenceError(for: resource)
            return true
        } catch {
            recordPersistenceError(resource: resource, operation: .save, error: error)
            return false
        }
    }

    private func write<T: Encodable>(_ value: T, to fileName: String) throws {
        let data = try iso8601Encoder.encode(value)
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        try dataWriter(data, url)
    }

    /// Writes an import candidate without changing the published store. Keeping the write and
    /// the in-memory commit separate lets `ExportManager` roll back if another import resource
    /// cannot be saved.
    func persistImportCandidate(routines: [Routine], completedWorkouts: [CompletedWorkout]) throws {
        try write(routines, to: routinesFileName)
        try write(completedWorkouts, to: historyFileName)
    }

    func applyImportedState(
        routines: [Routine],
        completedWorkouts: [CompletedWorkout],
        activeRoutineId: UUID?,
        activeWorkoutId: UUID?
    ) {
        // Exports deliberately contain only durable routine/history state and active IDs. A
        // live start timestamp or rest deadline from the pre-import session must never attach
        // itself to imported data, even if identifiers happen to match.
        activeWorkoutStartedAt = nil
        cancelActiveRestTimer()
        self.routines = routines
        self.completedWorkouts = completedWorkouts
        self.activeRoutineId = activeRoutineId
        self.activeWorkoutId = activeWorkoutId
        normalizeActiveState()
    }

    private func loadRoutines() {
        let url = getDocumentsDirectory().appendingPathComponent(routinesFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            loadDefaultRoutines()
            return
        }

        do {
            routines = try decode([Routine].self, from: Data(contentsOf: url))
        } catch {
            recordPersistenceError(resource: .routines, operation: .load, error: error)
        }
    }

    private func loadHistory() {
        let url = getDocumentsDirectory().appendingPathComponent(historyFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            completedWorkouts = try decode([CompletedWorkout].self, from: Data(contentsOf: url))
        } catch {
            recordPersistenceError(resource: .history, operation: .load, error: error)
        }
    }

    private func recordPersistenceError(resource: PersistenceResource, operation: PersistenceOperation, error: Error) {
        persistenceError = PersistenceError(
            resource: resource,
            operation: operation,
            underlyingErrorDescription: error.localizedDescription
        )
    }

    private func clearPersistenceError(for resource: PersistenceResource) {
        guard persistenceError?.resource == resource else { return }
        persistenceError = nil
    }
    
    private func saveActiveState() {
        userDefaults.set(activeRoutineId?.uuidString, forKey: activeRoutineIdKey)
        userDefaults.set(activeWorkoutId?.uuidString, forKey: activeWorkoutIdKey)
        userDefaults.set(activeWorkoutStartedAt, forKey: activeWorkoutStartedAtKey)

        if let activeRestTimer,
           let encodedTimer = try? iso8601Encoder.encode(activeRestTimer) {
            userDefaults.set(encodedTimer, forKey: activeRestTimerKey)
        } else {
            userDefaults.removeObject(forKey: activeRestTimerKey)
        }
    }

    private func loadActiveState() {
        activeRoutineId = userDefaults.string(forKey: activeRoutineIdKey).flatMap(UUID.init(uuidString:))
        activeWorkoutId = userDefaults.string(forKey: activeWorkoutIdKey).flatMap(UUID.init(uuidString:))
        activeWorkoutStartedAt = userDefaults.object(forKey: activeWorkoutStartedAtKey) as? Date
        if let data = userDefaults.data(forKey: activeRestTimerKey) {
            activeRestTimer = try? decode(ActiveRestTimerState.self, from: data)
        }
        normalizeActiveState()
        NotificationManager.shared.cancelPendingTimers(except: activeRestTimer?.notificationId)
    }

    /// Repairs persisted active-session references after routines have been loaded or migrated.
    /// A workout without its owning routine cannot be resumed, while a missing workout simply
    /// returns the person to the valid routine overview.
    private func normalizeActiveState() {
        guard let activeRoutineId,
              let routine = routines.first(where: { $0.id == activeRoutineId }) else {
            if self.activeRoutineId != nil || self.activeWorkoutId != nil {
                self.activeRoutineId = nil
                self.activeWorkoutId = nil
            }
            activeWorkoutStartedAt = nil
            cancelActiveRestTimer()
            return
        }

        guard let activeWorkoutId else {
            // A person may have navigated back to the routine list while a rest timer is still
            // running. Keep a valid timer in that case, but discard malformed or expired state.
            normalizeActiveRestTimer()
            return
        }
        if !routine.workouts.contains(where: { $0.id == activeWorkoutId }) {
            self.activeWorkoutId = nil
            activeWorkoutStartedAt = nil
        }
        normalizeActiveRestTimer()
    }

    private func normalizeActiveRestTimer(now: Date = Date()) {
        guard let timer = activeRestTimer else { return }
        guard timer.endTime > now,
              routines.first(where: { $0.id == timer.routineId })?.workouts.first(where: { $0.id == timer.workoutId })?.exercises.contains(where: { $0.id == timer.exerciseId }) == true else {
            cancelActiveRestTimer()
            return
        }
    }

    private func matchingRestTimer(routineId: UUID, workoutId: UUID, exerciseId: UUID) -> ActiveRestTimerState? {
        guard let timer = activeRestTimer,
              timer.routineId == routineId,
              timer.workoutId == workoutId,
              timer.exerciseId == exerciseId,
              timer.endTime > Date() else {
            return nil
        }
        return timer
    }

    private func cancelRestTimerForWorkout(routineId: UUID, workoutId: UUID) {
        guard let timer = activeRestTimer,
              timer.routineId == routineId,
              timer.workoutId == workoutId else {
            return
        }
        cancelActiveRestTimer()
    }

    private func cancelActiveRestTimer() {
        if let notificationId = activeRestTimer?.notificationId {
            NotificationManager.shared.cancelTimer(identifier: notificationId)
        }
        activeRestTimer = nil
    }
    
    @discardableResult
    private func loadDefaultRoutines(immediatelyPersist: Bool = false) -> Bool {
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
        if immediatelyPersist {
            return performSaveRoutines()
        }
        saveRoutines()
        return true
    }
}
