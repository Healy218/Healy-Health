import XCTest
import UserNotifications
@testable import Healy_Health

@MainActor
final class RoutineStoreTests: XCTestCase {
    private var storageDirectory: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName = ""

    override func setUpWithError() throws {
        storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoutineStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        defaultsSuiteName = "RoutineStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        if let storageDirectory {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        if let defaults {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        storageDirectory = nil
        defaults = nil
        defaultsSuiteName = ""
    }

    func testFlushSavesRoutineDataToInjectedDirectory() throws {
        let routine = makeRoutine(name: "Strength")
        let store = makeEmptyStore()

        store.addRoutine(routine)
        store.flushSaves()

        let data = try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedRoutines = try decoder.decode([Routine].self, from: data)

        XCTAssertEqual(savedRoutines.map(\.id), [routine.id])
        XCTAssertEqual(savedRoutines.first?.name, "Strength")
    }

    func testNewStoreLoadsDataFromItsInjectedDirectory() {
        let routine = makeRoutine(name: "Strength")
        let store = makeEmptyStore()
        store.addRoutine(routine)
        store.flushSaves()
        defaults.set(true, forKey: "hasMigratedToRoutines")

        let reloadedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertEqual(reloadedStore.routines.map(\.id), [routine.id])
    }

    func testLoadMigratesAndPersistsLegacyExerciseTrackingIDs() throws {
        let template = ExerciseTemplate(
            name: "Bench Press",
            primaryMuscleGroup: "Chest",
            equipmentType: "Barbell"
        )
        let legacyExercise = Exercise(
            trackingId: nil,
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135
        )
        let routine = Routine(
            name: "Strength",
            workouts: [Workout(name: "Upper", focus: "Chest", exercises: [legacyExercise])]
        )
        let history = CompletedWorkout(
            date: Date(),
            dayName: "Upper",
            focus: "Chest",
            exercises: [legacyExercise],
            routineId: routine.id,
            workoutId: routine.workouts[0].id
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([routine]).write(
            to: storageDirectory.appendingPathComponent("routines.json"),
            options: .atomic
        )
        try encoder.encode([history]).write(
            to: storageDirectory.appendingPathComponent("workout_history.json"),
            options: .atomic
        )
        defaults.set(true, forKey: "hasMigratedToRoutines")

        let reloadedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal,
            exerciseTemplatesProvider: { [template] },
            cancelTimerNotification: { _ in },
            cancelPendingTimerNotifications: { _ in }
        )

        XCTAssertEqual(reloadedStore.routines[0].workouts[0].exercises[0].trackingId, template.id)
        XCTAssertEqual(reloadedStore.completedWorkouts[0].exercises[0].trackingId, template.id)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedRoutines = try decoder.decode(
            [Routine].self,
            from: Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))
        )
        let savedHistory = try decoder.decode(
            [CompletedWorkout].self,
            from: Data(contentsOf: storageDirectory.appendingPathComponent("workout_history.json"))
        )
        XCTAssertEqual(savedRoutines[0].workouts[0].exercises[0].trackingId, template.id)
        XCTAssertEqual(savedHistory[0].exercises[0].trackingId, template.id)
    }

    func testLoadSortsHistoryNewestFirstWithUUIDTieBreak() throws {
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let oldest = CompletedWorkout(
            date: Date(timeIntervalSinceReferenceDate: 900),
            dayName: "Oldest",
            focus: "Full body",
            exercises: [],
            routineId: nil,
            workoutId: nil
        )
        let firstTie = CompletedWorkout(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            date: date,
            dayName: "Second tie",
            focus: "Full body",
            exercises: [],
            routineId: nil,
            workoutId: nil
        )
        let secondTie = CompletedWorkout(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            date: date,
            dayName: "First tie",
            focus: "Full body",
            exercises: [],
            routineId: nil,
            workoutId: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([oldest, firstTie, secondTie]).write(
            to: storageDirectory.appendingPathComponent("workout_history.json"),
            options: .atomic
        )
        defaults.set(true, forKey: "hasMigratedToRoutines")

        let reloadedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal,
            exerciseTemplatesProvider: { [] },
            cancelTimerNotification: { _ in },
            cancelPendingTimerNotifications: { _ in }
        )

        XCTAssertEqual(reloadedStore.completedWorkouts.map(\.id), [secondTie.id, firstTie.id, oldest.id])
    }

    func testRoutineSaveDoesNotWriteHistory() {
        var writtenFileNames: [String] = []
        let store = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .empty,
            saveDebounceInterval: 0,
            dataWriter: { data, url in
                writtenFileNames.append(url.lastPathComponent)
                try data.write(to: url, options: .atomic)
            }
        )

        store.routines = [makeRoutine(name: "Strength")]
        store.saveRoutines()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertEqual(writtenFileNames, ["routines.json"])
    }

    func testExerciseAnalyticsCountsOnlyLoggedExercisesAsTrainedSessions() {
        let firstDate = Date(timeIntervalSinceReferenceDate: 100)
        let secondDate = Date(timeIntervalSinceReferenceDate: 200)
        let benchTrackingID = UUID()
        let firstBench = Exercise(
            trackingId: benchTrackingID,
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            logs: [SetLog(weight: 135, reps: 8, completedDate: firstDate)]
        )
        let secondBench = Exercise(
            trackingId: benchTrackingID,
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 155,
            logs: [SetLog(weight: 155, reps: 5, completedDate: secondDate)]
        )
        let unloggedSquat = Exercise(name: "Squat", targetSets: 3, targetReps: "8", currentWeight: 185)
        let workouts = [
            CompletedWorkout(date: secondDate, dayName: "Upper", focus: "Chest", exercises: [secondBench, unloggedSquat], routineId: nil, workoutId: nil),
            CompletedWorkout(date: firstDate, dayName: "Upper", focus: "Chest", exercises: [firstBench], routineId: nil, workoutId: nil)
        ]

        let sessions = ExerciseAnalytics.trainedSessions(from: workouts)
        let summaries = ExerciseAnalytics.summaries(from: sessions)
        let history = ExerciseAnalytics.history(for: benchTrackingID, from: sessions)

        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(summaries, [ExerciseTrainingSummary(id: benchTrackingID, name: "Bench Press", count: 2)])
        XCTAssertEqual(history.map(\.session), [1, 2])
        XCTAssertEqual(history.map(\.date), [firstDate, secondDate])
        XCTAssertEqual(history.map(\.totalVolume), [1080, 775])
    }

    func testExerciseAnalyticsUsesIdentityForRenamesAndSameNameExercises() {
        let firstIdentity = UUID()
        let secondIdentity = UUID()
        let firstDate = Date(timeIntervalSinceReferenceDate: 100)
        let secondDate = Date(timeIntervalSinceReferenceDate: 200)
        let thirdDate = Date(timeIntervalSinceReferenceDate: 300)
        let workouts = [
            CompletedWorkout(
                date: firstDate,
                dayName: "First",
                focus: "Chest",
                exercises: [Exercise(
                    trackingId: firstIdentity,
                    name: "Barbell Bench Press",
                    targetSets: 3,
                    targetReps: "8",
                    currentWeight: 135,
                    logs: [SetLog(weight: 135, reps: 8, completedDate: firstDate)]
                )],
                routineId: nil,
                workoutId: nil
            ),
            CompletedWorkout(
                date: secondDate,
                dayName: "Second",
                focus: "Chest",
                exercises: [Exercise(
                    trackingId: firstIdentity,
                    name: "Competition Bench Press",
                    targetSets: 3,
                    targetReps: "8",
                    currentWeight: 145,
                    logs: [SetLog(weight: 145, reps: 8, completedDate: secondDate)]
                )],
                routineId: nil,
                workoutId: nil
            ),
            CompletedWorkout(
                date: thirdDate,
                dayName: "Third",
                focus: "Chest",
                exercises: [Exercise(
                    trackingId: secondIdentity,
                    name: "Competition Bench Press",
                    targetSets: 3,
                    targetReps: "8",
                    currentWeight: 95,
                    logs: [SetLog(weight: 95, reps: 8, completedDate: thirdDate)]
                )],
                routineId: nil,
                workoutId: nil
            )
        ]

        let sessions = ExerciseAnalytics.trainedSessions(from: workouts)
        let summaries = ExerciseAnalytics.summaries(from: sessions)

        XCTAssertEqual(summaries.first { $0.id == firstIdentity }, ExerciseTrainingSummary(id: firstIdentity, name: "Competition Bench Press", count: 2))
        XCTAssertEqual(summaries.first { $0.id == secondIdentity }, ExerciseTrainingSummary(id: secondIdentity, name: "Competition Bench Press", count: 1))
        XCTAssertEqual(ExerciseAnalytics.history(for: firstIdentity, from: sessions).count, 2)
        XCTAssertEqual(ExerciseAnalytics.history(for: secondIdentity, from: sessions).count, 1)
    }

    func testImportMigrationLinksLegacyExercisesToTheirLibraryTemplate() throws {
        let template = ExerciseTemplate(
            name: "Bench Press",
            primaryMuscleGroup: "Chest",
            equipmentType: "Barbell"
        )
        let legacyExercise = Exercise(
            trackingId: nil,
            name: " bench press ",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            logs: [SetLog(weight: 135, reps: 8, completedDate: Date())]
        )
        let routine = Routine(name: "Strength", workouts: [Workout(name: "Upper", focus: "Chest", exercises: [legacyExercise])])
        let history = CompletedWorkout(
            date: Date(),
            dayName: "Upper",
            focus: "Chest",
            exercises: [legacyExercise],
            routineId: routine.id,
            workoutId: routine.workouts[0].id
        )
        let export = AppExportData(
            schemaVersion: 1,
            exportedAt: Date(),
            routines: [routine],
            completedWorkouts: [history],
            exerciseLibrary: [template],
            selectedTheme: .light,
            activeRoutineId: nil,
            activeWorkoutId: nil
        )

        let normalized = try AppImportValidator.normalizedCandidate(from: export)

        XCTAssertEqual(normalized.routines[0].workouts[0].exercises[0].trackingId, template.id)
        XCTAssertEqual(normalized.completedWorkouts[0].exercises[0].trackingId, template.id)
    }

    func testFailedRoutineSavePreservesTheLastGoodFileAndPublishesAnError() throws {
        let original = makeRoutine(name: "Original")
        let initialStore = makeEmptyStore()
        initialStore.routines = [original]
        XCTAssertTrue(initialStore.flushSaves())
        let originalData = try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))

        let failedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .empty,
            dataWriter: { data, url in
                if url.lastPathComponent == "routines.json" {
                    throw CocoaError(.fileWriteNoPermission)
                }
                try data.write(to: url, options: .atomic)
            }
        )
        failedStore.routines = [makeRoutine(name: "Replacement")]

        XCTAssertFalse(failedStore.flushSaves())
        XCTAssertEqual(
            try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json")),
            originalData
        )
        XCTAssertEqual(failedStore.persistenceError?.resource, .routines)
        XCTAssertEqual(failedStore.persistenceError?.operation, .save)
    }

    func testCorruptRoutineFileIsReportedAndNeverReplacedWithDefaults() throws {
        defaults.set(true, forKey: "hasMigratedToRoutines")
        let routinesURL = storageDirectory.appendingPathComponent("routines.json")
        try Data("not valid JSON".utf8).write(to: routinesURL, options: .atomic)

        let store = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertTrue(store.routines.isEmpty)
        XCTAssertEqual(store.persistenceError?.resource, .routines)
        XCTAssertEqual(store.persistenceError?.operation, .load)
        XCTAssertEqual(try Data(contentsOf: routinesURL), Data("not valid JSON".utf8))
    }

    func testLoadClearsAnActiveRoutineThatNoLongerExists() throws {
        let routine = makeRoutine(name: "Strength")
        let store = makeEmptyStore()
        store.routines = [routine]
        XCTAssertTrue(store.flushSaves())
        defaults.set(true, forKey: "hasMigratedToRoutines")
        defaults.set(UUID().uuidString, forKey: "activeRoutineId")
        defaults.set(UUID().uuidString, forKey: "activeWorkoutId")

        let reloadedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertNil(reloadedStore.activeRoutineId)
        XCTAssertNil(reloadedStore.activeWorkoutId)
        XCTAssertNil(defaults.string(forKey: "activeRoutineId"))
        XCTAssertNil(defaults.string(forKey: "activeWorkoutId"))
    }

    func testLoadClearsAWorkoutThatDoesNotBelongToTheActiveRoutine() throws {
        let first = makeRoutine(name: "First")
        let second = makeRoutine(name: "Second")
        let store = makeEmptyStore()
        store.routines = [first, second]
        XCTAssertTrue(store.flushSaves())
        defaults.set(true, forKey: "hasMigratedToRoutines")
        defaults.set(first.id.uuidString, forKey: "activeRoutineId")
        defaults.set(second.workouts[0].id.uuidString, forKey: "activeWorkoutId")

        let reloadedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertEqual(reloadedStore.activeRoutineId, first.id)
        XCTAssertNil(reloadedStore.activeWorkoutId)
        XCTAssertEqual(defaults.string(forKey: "activeRoutineId"), first.id.uuidString)
        XCTAssertNil(defaults.string(forKey: "activeWorkoutId"))
    }

    func testActiveWorkoutStartAndRestTimerSurviveStoreReload() throws {
        let exercise = Exercise(name: "Bench Press", targetSets: 3, targetReps: "8", currentWeight: 135)
        let workout = Workout(name: "Upper", focus: "Chest", exercises: [exercise])
        let routine = Routine(name: "Strength", workouts: [workout])
        let store = makeEmptyStore()
        store.routines = [routine]
        XCTAssertTrue(store.flushSaves())
        defaults.set(true, forKey: "hasMigratedToRoutines")

        let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        let timerStart = Date(timeIntervalSinceReferenceDate: 900_000_000)
        store.startWorkout(routineId: routine.id, workoutId: workout.id, startedAt: startedAt)
        let timer = try XCTUnwrap(store.startRestTimer(
            routineId: routine.id,
            workoutId: workout.id,
            exerciseId: exercise.id,
            duration: 3_600,
            now: timerStart
        ))

        let reloadedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertEqual(reloadedStore.activeRoutineId, routine.id)
        XCTAssertEqual(reloadedStore.activeWorkoutId, workout.id)
        XCTAssertEqual(reloadedStore.activeWorkoutStartedAt, startedAt)
        XCTAssertEqual(reloadedStore.activeRestTimer, timer)
    }

    func testLoadCancelsAnExpiredRestTimerButKeepsTheActiveWorkout() throws {
        let exercise = Exercise(name: "Bench Press", targetSets: 3, targetReps: "8", currentWeight: 135)
        let workout = Workout(name: "Upper", focus: "Chest", exercises: [exercise])
        let routine = Routine(name: "Strength", workouts: [workout])
        let store = makeEmptyStore()
        store.routines = [routine]
        XCTAssertTrue(store.flushSaves())
        defaults.set(true, forKey: "hasMigratedToRoutines")
        store.startWorkout(routineId: routine.id, workoutId: workout.id)
        XCTAssertNotNil(store.startRestTimer(
            routineId: routine.id,
            workoutId: workout.id,
            exerciseId: exercise.id,
            duration: 1,
            now: Date(timeIntervalSinceReferenceDate: 0)
        ))

        let reloadedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertEqual(reloadedStore.activeRoutineId, routine.id)
        XCTAssertEqual(reloadedStore.activeWorkoutId, workout.id)
        XCTAssertNil(reloadedStore.activeRestTimer)
        XCTAssertNil(defaults.data(forKey: "activeRestTimer"))
    }

    func testMigrationReportsUnreadableLegacyDataAndRetriesOnNextLaunch() throws {
        let legacyURL = storageDirectory.appendingPathComponent("workout_schedule.json")
        try Data("not valid JSON".utf8).write(to: legacyURL, options: .atomic)

        let store = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertTrue(store.routines.isEmpty)
        XCTAssertEqual(store.persistenceError?.resource, .routines)
        XCTAssertEqual(store.persistenceError?.operation, .migration)
        XCTAssertFalse(defaults.bool(forKey: "hasMigratedToRoutines"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageDirectory.appendingPathComponent("routines.json").path))
        XCTAssertEqual(try Data(contentsOf: legacyURL), Data("not valid JSON".utf8))
    }

    func testMigrationPersistsValidLegacyFixturesAndRepairsActiveState() throws {
        let legacyWorkout = RoutineStore.LegacyWorkoutDay(
            dayName: "Legacy Push",
            focus: "Chest",
            exercises: [Exercise(name: "Bench Press", targetSets: 3, targetReps: "8", currentWeight: 135)]
        )
        let legacyURL = storageDirectory.appendingPathComponent("workout_schedule.json")
        try JSONEncoder().encode([legacyWorkout]).write(to: legacyURL, options: .atomic)
        defaults.set(UUID().uuidString, forKey: "activeRoutineId")
        defaults.set(UUID().uuidString, forKey: "activeWorkoutId")

        let store = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertTrue(defaults.bool(forKey: "hasMigratedToRoutines"))
        XCTAssertEqual(store.routines.map(\.name), ["Legacy Weekly Schedule"])
        XCTAssertEqual(store.routines[0].workouts.map(\.name), ["Legacy Push"])
        XCTAssertNil(store.activeRoutineId)
        XCTAssertNil(store.activeWorkoutId)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storageDirectory.appendingPathComponent("routines.json").path))
    }

    func testCustomExerciseLibraryAddsOnceAndPersistsTheNormalizedTemplate() {
        let manager = ExerciseManager(documentsDirectory: storageDirectory)
        let template = ExerciseTemplate(
            name: "  Custom Step-Up \n",
            primaryMuscleGroup: "Legs",
            equipmentType: "Custom"
        )

        XCTAssertEqual(manager.addExercise(template), .added)
        XCTAssertEqual(manager.addExercise(ExerciseTemplate(
            name: "custom step-up",
            primaryMuscleGroup: "Legs",
            equipmentType: "Custom"
        )), .duplicateName)

        let reloadedManager = ExerciseManager(documentsDirectory: storageDirectory)
        let savedTemplate = reloadedManager.exercises.first { $0.name == "Custom Step-Up" }
        XCTAssertEqual(savedTemplate?.primaryMuscleGroup, "Legs")
        XCTAssertEqual(savedTemplate?.equipmentType, "Custom")
    }

    func testDeletingOneRoutinePreservesAnUnrelatedActiveRoutine() {
        let first = makeRoutine(name: "First")
        let second = makeRoutine(name: "Second")
        let store = makeEmptyStore()
        store.routines = [first, second]
        store.activeRoutineId = second.id
        store.activeWorkoutId = second.workouts[0].id

        store.deleteRoutines(ids: [first.id])

        XCTAssertEqual(store.routines.map(\.id), [second.id])
        XCTAssertEqual(store.activeRoutineId, second.id)
        XCTAssertEqual(store.activeWorkoutId, second.workouts[0].id)
    }

    func testMultipleRoutineDeletionUsesStableIDsAndClearsActiveState() {
        let first = makeRoutine(name: "First")
        let second = makeRoutine(name: "Second")
        let third = makeRoutine(name: "Third")
        let store = makeEmptyStore()
        store.routines = [first, second, third]
        store.activeRoutineId = second.id
        store.activeWorkoutId = second.workouts[0].id

        store.deleteRoutines(ids: [first.id, second.id])

        XCTAssertEqual(store.routines.map(\.id), [third.id])
        XCTAssertNil(store.activeRoutineId)
        XCTAssertNil(store.activeWorkoutId)
    }

    func testDeletingActiveWorkoutKeepsItsRoutineAndClearsOnlyWorkoutState() {
        let routine = makeRoutine(name: "Strength")
        let secondWorkout = Workout(name: "Cardio", focus: "Conditioning", exercises: [])
        let store = makeEmptyStore()
        store.routines = [routine]
        store.routines[0].workouts.append(secondWorkout)
        store.activeRoutineId = routine.id
        store.activeWorkoutId = secondWorkout.id

        store.deleteWorkouts(routineId: routine.id, ids: [secondWorkout.id])

        XCTAssertEqual(store.routines[0].workouts.map(\.id), [routine.workouts[0].id])
        XCTAssertEqual(store.activeRoutineId, routine.id)
        XCTAssertNil(store.activeWorkoutId)
    }

    func testRestTimerDurationValidationRejectsUnsafeValues() {
        for invalidDuration: TimeInterval in [0, -1, .infinity, -.infinity, .nan] {
            XCTAssertEqual(
                RestTimerDuration.validate(invalidDuration),
                .failure(.invalidDuration),
                "Expected \(invalidDuration) to be rejected"
            )
        }

        XCTAssertEqual(
            RestTimerDuration.validate(RestTimerDuration.maximumSeconds + 1),
            .failure(.durationTooLong(maximumSeconds: RestTimerDuration.maximumSeconds))
        )
    }

    func testExerciseValidationTrimsConfigurationTextAndRejectsInvalidBoundaries() throws {
        let configuration = try ExerciseDomainValidation.configuration(
            name: "  Bench Press \n",
            targetSets: 3,
            targetReps: " 8-12 ",
            currentWeight: 135
        )

        XCTAssertEqual(configuration.name, "Bench Press")
        XCTAssertEqual(configuration.targetReps, "8-12")

        XCTAssertThrowsError(try ExerciseDomainValidation.configuration(name: " \n", targetSets: 3, targetReps: "8", currentWeight: 0))
        XCTAssertThrowsError(try ExerciseDomainValidation.configuration(name: "Bench", targetSets: 0, targetReps: "8", currentWeight: 0))
        XCTAssertThrowsError(try ExerciseDomainValidation.configuration(name: "Bench", targetSets: -1, targetReps: "8", currentWeight: 0))
        XCTAssertThrowsError(try ExerciseDomainValidation.configuration(name: "Bench", targetSets: 3, targetReps: " ", currentWeight: 0))
        XCTAssertThrowsError(try ExerciseDomainValidation.configuration(name: "Bench", targetSets: 3, targetReps: "8", currentWeight: -.infinity))
        XCTAssertThrowsError(try ExerciseDomainValidation.configuration(name: "Bench", targetSets: 3, targetReps: "8", currentWeight: .nan))
    }

    func testWorkoutPlanningValidationTrimsNamesAndDetectsDuplicateExercisesWithinOneWorkout() throws {
        XCTAssertEqual(try WorkoutPlanningValidation.routineName("  Strength \n"), "Strength")
        XCTAssertEqual(try WorkoutPlanningValidation.workoutName(" Upper Body "), "Upper Body")
        XCTAssertEqual(WorkoutPlanningValidation.focus(" Chest \n"), "Chest")
        XCTAssertThrowsError(try WorkoutPlanningValidation.routineName(" \n"))
        XCTAssertThrowsError(try WorkoutPlanningValidation.workoutName(" \n"))

        let exercise = Exercise(name: "Bench Press", targetSets: 3, targetReps: "8", currentWeight: 135)
        XCTAssertTrue(WorkoutPlanningValidation.hasDuplicateExerciseName("  bench press ", in: [exercise]))
        XCTAssertFalse(WorkoutPlanningValidation.hasDuplicateExerciseName("Bench Press", in: [exercise], excludingID: exercise.id))
    }

    func testPlanningMutationsTrimNamesChangeCategoryAndRejectDuplicateExercises() throws {
        let store = makeEmptyStore()
        let routine: Routine
        switch store.createRoutine(named: "  Strength \n") {
        case .success(let value): routine = value
        case .failure(let error): return XCTFail(error.localizedDescription)
        }

        let workout: Workout
        switch store.addWorkout(routineId: routine.id, name: " Upper ", focus: " Chest ") {
        case .success(let value): workout = value
        case .failure(let error): return XCTFail(error.localizedDescription)
        }
        let bench = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            category: .weightlifting
        )
        if case .failure(let error) = store.addExercise(routineId: routine.id, workoutId: workout.id, exercise: bench) {
            XCTFail(error.localizedDescription)
        }
        if case .failure(let error) = store.addExercise(
            routineId: routine.id,
            workoutId: workout.id,
            exercise: Exercise(name: " bench press ", targetSets: 3, targetReps: "8", currentWeight: 0)
        ) {
            XCTAssertEqual(error, .duplicateExerciseName)
        } else {
            XCTFail("Expected duplicate exercise to be rejected")
        }
        if case .failure(let error) = store.updateExerciseConfiguration(
            routineId: routine.id,
            workoutId: workout.id,
            exerciseId: bench.id,
            targetSets: 4,
            targetReps: " 10-12 ",
            currentWeight: 145,
            category: .cardio
        ) {
            XCTFail(error.localizedDescription)
        }
        XCTAssertEqual(store.routines[0].name, "Strength")
        XCTAssertEqual(store.routines[0].workouts[0].name, "Upper")
        XCTAssertEqual(store.routines[0].workouts[0].focus, "Chest")
        XCTAssertEqual(store.routines[0].workouts[0].exercises[0].targetReps, "10-12")
        XCTAssertEqual(store.routines[0].workouts[0].exercises[0].category, .cardio)

        store.flushSaves()
        let data = try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedRoutines = try decoder.decode([Routine].self, from: data)
        XCTAssertEqual(savedRoutines[0].name, "Strength")
        XCTAssertEqual(savedRoutines[0].workouts[0].name, "Upper")
        XCTAssertEqual(savedRoutines[0].workouts[0].exercises[0].category, .cardio)
    }

    func testSetLogValidationRejectsNegativeWeightAndNonpositiveReps() throws {
        XCTAssertEqual(try ExerciseDomainValidation.setLog(weight: 0, reps: 1), ValidatedSetLog(weight: 0, reps: 1))

        XCTAssertThrowsError(try ExerciseDomainValidation.setLog(weight: -0.1, reps: 1))
        XCTAssertThrowsError(try ExerciseDomainValidation.setLog(weight: .infinity, reps: 1))
        XCTAssertThrowsError(try ExerciseDomainValidation.setLog(weight: 100, reps: 0))
        XCTAssertThrowsError(try ExerciseDomainValidation.setLog(weight: 100, reps: -1))
    }

    func testUpdateLoggedSetUpdatesOnlyTheRequestedLogAndPersistsIt() throws {
        let firstLog = SetLog(weight: 135, reps: 8, completedDate: Date())
        let logToUpdate = SetLog(weight: 145, reps: 6, completedDate: Date())
        let exercise = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            logs: [firstLog, logToUpdate]
        )
        let routine = Routine(
            name: "Strength",
            workouts: [Workout(name: "Upper", focus: "Chest", exercises: [exercise])]
        )
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertSetLogMutationSucceeds(store.updateLoggedSet(
            routineId: routine.id,
            workoutId: routine.workouts[0].id,
            exerciseId: exercise.id,
            logId: logToUpdate.id,
            weight: 150,
            reps: 10
        ))

        let logs = store.routines[0].workouts[0].exercises[0].logs
        XCTAssertEqual(logs[0].weight, 135)
        XCTAssertEqual(logs[0].reps, 8)
        XCTAssertEqual(logs[1].weight, 150)
        XCTAssertEqual(logs[1].reps, 10)

        let data = try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedRoutines = try decoder.decode([Routine].self, from: data)
        XCTAssertEqual(savedRoutines[0].workouts[0].exercises[0].logs[1].weight, 150)
        XCTAssertEqual(savedRoutines[0].workouts[0].exercises[0].logs[1].reps, 10)
    }

    func testUpdateLoggedSetRejectsInvalidValuesWithoutMutatingTheLog() {
        let log = SetLog(weight: 135, reps: 8, completedDate: Date())
        let exercise = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            logs: [log]
        )
        let routine = Routine(
            name: "Strength",
            workouts: [Workout(name: "Upper", focus: "Chest", exercises: [exercise])]
        )
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertSetLogMutationFails(
            store.updateLoggedSet(
                routineId: routine.id,
                workoutId: routine.workouts[0].id,
                exerciseId: exercise.id,
                logId: log.id,
                weight: -.infinity,
                reps: 8
            ),
            with: .invalidLog(.invalidWeight)
        )
        XCTAssertSetLogMutationFails(
            store.updateLoggedSet(
                routineId: routine.id,
                workoutId: routine.workouts[0].id,
                exerciseId: exercise.id,
                logId: log.id,
                weight: 135,
                reps: 0
            ),
            with: .invalidLog(.invalidLogReps)
        )
        let unchangedLog = store.routines[0].workouts[0].exercises[0].logs[0]
        XCTAssertEqual(unchangedLog.id, log.id)
        XCTAssertEqual(unchangedLog.weight, log.weight)
        XCTAssertEqual(unchangedLog.reps, log.reps)
    }

    func testDeleteLoggedSetResetsCompletionBelowTargetAndPersistsIt() throws {
        let firstLog = SetLog(weight: 135, reps: 8, completedDate: Date())
        let logToDelete = SetLog(weight: 140, reps: 8, completedDate: Date())
        let exercise = Exercise(
            name: "Bench Press",
            targetSets: 2,
            targetReps: "8",
            currentWeight: 135,
            isCompleted: true,
            logs: [firstLog, logToDelete]
        )
        let routine = Routine(
            name: "Strength",
            workouts: [Workout(name: "Upper", focus: "Chest", exercises: [exercise])]
        )
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertSetLogMutationSucceeds(store.deleteLoggedSet(
            routineId: routine.id,
            workoutId: routine.workouts[0].id,
            exerciseId: exercise.id,
            logId: logToDelete.id
        ))

        let updatedExercise = store.routines[0].workouts[0].exercises[0]
        XCTAssertEqual(updatedExercise.logs.count, 1)
        XCTAssertEqual(updatedExercise.logs[0].id, firstLog.id)
        XCTAssertFalse(updatedExercise.isCompleted)

        let data = try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedRoutines = try decoder.decode([Routine].self, from: data)
        XCTAssertFalse(savedRoutines[0].workouts[0].exercises[0].isCompleted)
    }

    func testDeleteLoggedSetReportsMissingIDsWithoutMutatingTheExercise() {
        let log = SetLog(weight: 135, reps: 8, completedDate: Date())
        let exercise = Exercise(
            name: "Bench Press",
            targetSets: 2,
            targetReps: "8",
            currentWeight: 135,
            logs: [log]
        )
        let routine = Routine(
            name: "Strength",
            workouts: [Workout(name: "Upper", focus: "Chest", exercises: [exercise])]
        )
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertSetLogMutationFails(
            store.deleteLoggedSet(
                routineId: routine.id,
                workoutId: routine.workouts[0].id,
                exerciseId: exercise.id,
                logId: UUID()
            ),
            with: .logNotFound
        )
        XCTAssertSetLogMutationFails(
            store.deleteLoggedSet(
                routineId: routine.id,
                workoutId: routine.workouts[0].id,
                exerciseId: UUID(),
                logId: log.id
            ),
            with: .exerciseNotFound
        )
        let unchangedLog = store.routines[0].workouts[0].exercises[0].logs[0]
        XCTAssertEqual(unchangedLog.id, log.id)
        XCTAssertEqual(unchangedLog.weight, log.weight)
        XCTAssertEqual(unchangedLog.reps, log.reps)
    }

    func testRestTimerSchedulingRequestsPermissionAtTimerUseAndAddsNotification() {
        var requestedAuthorization = false
        var scheduledRequest: UNNotificationRequest?
        let completed = expectation(description: "timer scheduling completed")
        let manager = NotificationManager(
            authorizationStatusProvider: { completion in completion(.notDetermined) },
            authorizationRequester: { completion in
                requestedAuthorization = true
                completion(true, nil)
            },
            requestAdder: { request, completion in
                scheduledRequest = request
                completion(nil)
            },
            timerCanceler: { _ in }
        )

        manager.scheduleTimer(seconds: 120) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected scheduling error: \(error.localizedDescription)")
            }
            completed.fulfill()
        }

        wait(for: [completed], timeout: 1)
        XCTAssertTrue(requestedAuthorization)
        XCTAssertTrue(scheduledRequest?.identifier.hasPrefix("restTimer-") == true)
        XCTAssertEqual((scheduledRequest?.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval, 120)
    }

    func testRestTimerSchedulingReportsNotificationCenterFailure() {
        let completed = expectation(description: "timer scheduling failed")
        let manager = NotificationManager(
            authorizationStatusProvider: { completion in completion(.authorized) },
            authorizationRequester: { _ in XCTFail("Authorization should not be requested") },
            requestAdder: { _, completion in
                completion(NSError(domain: "NotificationTests", code: 1))
            },
            timerCanceler: { _ in }
        )

        manager.scheduleTimer(seconds: 120) { result in
            guard case .failure(.schedulingFailed) = result else {
                return XCTFail("Expected notification-center failure")
            }
            completed.fulfill()
        }

        wait(for: [completed], timeout: 1)
    }

    func testCancellingTimerPreventsAnInFlightAuthorizationFromSchedulingIt() {
        var authorizationCompletion: ((Bool, Error?) -> Void)?
        var scheduledRequest: UNNotificationRequest?
        var cancelledRequestIDs: [String] = []
        let timerID = UUID()
        let manager = NotificationManager(
            authorizationStatusProvider: { completion in completion(.notDetermined) },
            authorizationRequester: { completion in authorizationCompletion = completion },
            requestAdder: { request, completion in
                scheduledRequest = request
                completion(nil)
            },
            timerCanceler: { cancelledRequestIDs.append(contentsOf: $0) }
        )

        manager.scheduleTimer(seconds: 120, identifier: timerID) { _ in
            XCTFail("A cancelled timer should not report scheduling completion")
        }
        manager.cancelTimer(identifier: timerID)
        authorizationCompletion?(true, nil)

        XCTAssertNil(scheduledRequest)
        XCTAssertEqual(cancelledRequestIDs.count, 1)
        XCTAssertTrue(cancelledRequestIDs[0].hasPrefix("restTimer-"))
    }

    func testImportValidationRejectsDuplicateWorkoutIdentifiers() {
        let duplicateWorkoutID = UUID()
        let routine = Routine(
            name: "Strength",
            workouts: [
                Workout(id: duplicateWorkoutID, name: "Upper", focus: "Upper", exercises: []),
                Workout(id: duplicateWorkoutID, name: "Lower", focus: "Lower", exercises: [])
            ]
        )
        let export = makeExport(routines: [routine])

        XCTAssertThrowsError(try AppImportValidator.normalizedCandidate(from: export)) { error in
            XCTAssertEqual(error as? ImportError, .invalidData("duplicate workout identifiers"))
        }
    }

    func testImportValidationRejectsDanglingActiveWorkout() {
        let routine = makeRoutine(name: "Strength")
        let export = AppExportData(
            schemaVersion: 1,
            exportedAt: Date(),
            routines: [routine],
            completedWorkouts: [],
            exerciseLibrary: [],
            selectedTheme: .light,
            activeRoutineId: routine.id,
            activeWorkoutId: UUID()
        )

        XCTAssertThrowsError(try AppImportValidator.normalizedCandidate(from: export)) { error in
            XCTAssertEqual(
                error as? ImportError,
                .invalidData("the active workout does not belong to the active routine")
            )
        }
    }

    func testImportValidationSortsHistoryNewestFirstWithStableTieBreak() throws {
        let older = CompletedWorkout(
            date: Date(timeIntervalSinceReferenceDate: 1),
            dayName: "Older",
            focus: "Full body",
            exercises: [],
            routineId: nil,
            workoutId: nil
        )
        let newer = CompletedWorkout(
            date: Date(timeIntervalSinceReferenceDate: 2),
            dayName: "Newer",
            focus: "Full body",
            exercises: [],
            routineId: nil,
            workoutId: nil
        )

        let normalized = try AppImportValidator.normalizedCandidate(
            from: makeExport(completedWorkouts: [older, newer])
        )

        XCTAssertEqual(normalized.completedWorkouts.map(\.id), [newer.id, older.id])
    }

    func testImportValidationAcceptsRepeatedSnapshotIDsAcrossCompletedWorkouts() throws {
        let repeatedLog = SetLog(weight: 135, reps: 8, completedDate: Date())
        let repeatedExercise = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            logs: [repeatedLog]
        )
        let first = CompletedWorkout(
            date: Date(timeIntervalSinceReferenceDate: 1),
            dayName: "Upper",
            focus: "Chest",
            exercises: [repeatedExercise],
            routineId: nil,
            workoutId: nil
        )
        let second = CompletedWorkout(
            date: Date(timeIntervalSinceReferenceDate: 2),
            dayName: "Upper",
            focus: "Chest",
            exercises: [repeatedExercise],
            routineId: nil,
            workoutId: nil
        )

        let normalized = try AppImportValidator.normalizedCandidate(
            from: makeExport(completedWorkouts: [first, second])
        )

        XCTAssertEqual(normalized.completedWorkouts.count, 2)
        XCTAssertEqual(normalized.completedWorkouts[0].exercises[0].id, repeatedExercise.id)
        XCTAssertEqual(normalized.completedWorkouts[1].exercises[0].logs[0].id, repeatedLog.id)
    }

    func testFinishWorkoutResolvesTheCurrentStoredWorkoutByID() {
        let routine = makeRoutine(name: "Original routine")
        let workoutID = routine.workouts[0].id
        let exercise = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            logs: [SetLog(weight: 155, reps: 8, completedDate: Date())]
        )
        var currentRoutine = routine
        currentRoutine.name = "Updated routine"
        currentRoutine.workouts[0].name = "Updated workout"
        currentRoutine.workouts[0].focus = "Updated focus"
        currentRoutine.workouts[0].exercises = [exercise]
        let store = makeEmptyStore()
        store.routines = [currentRoutine]
        store.activeRoutineId = routine.id
        store.activeWorkoutId = workoutID

        XCTAssertCompletionSucceeds(store.finishWorkout(routineId: routine.id, workoutId: workoutID))
        XCTAssertEqual(store.completedWorkouts.count, 1)
        XCTAssertEqual(store.completedWorkouts[0].dayName, "Updated workout")
        XCTAssertEqual(store.completedWorkouts[0].focus, "Updated focus")
        XCTAssertNotEqual(store.completedWorkouts[0].exercises.map(\.id), [exercise.id])
        XCTAssertEqual(store.completedWorkouts[0].exercises[0].logs.count, 1)
        XCTAssertNotEqual(store.completedWorkouts[0].exercises[0].logs[0].id, exercise.logs[0].id)
        XCTAssertEqual(store.completedWorkouts[0].exercises[0].logs[0].weight, 155)
        XCTAssertTrue(store.routines[0].workouts[0].isCompleted)
        XCTAssertNil(store.activeWorkoutId)
    }

    func testFinishWorkoutCreatesIndependentHistorySnapshotIDs() {
        let log = SetLog(weight: 135, reps: 8, completedDate: Date())
        let exercise = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            logs: [log]
        )
        let workout = Workout(name: "Upper", focus: "Chest", exercises: [exercise])
        let routine = Routine(name: "Strength", workouts: [workout])
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertTrue(store.startWorkout(routineId: routine.id, workoutId: workout.id))
        XCTAssertCompletionSucceeds(store.finishWorkout(routineId: routine.id, workoutId: workout.id))
        store.finishRoutine(startNew: false)
        store.routines[0].workouts[0].exercises[0].logs = [log]
        XCTAssertTrue(store.startWorkout(routineId: routine.id, workoutId: workout.id))
        XCTAssertCompletionSucceeds(store.finishWorkout(routineId: routine.id, workoutId: workout.id))

        let snapshots = store.completedWorkouts.map { $0.exercises[0] }
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertNotEqual(snapshots[0].id, exercise.id)
        XCTAssertNotEqual(snapshots[1].id, exercise.id)
        XCTAssertNotEqual(snapshots[0].id, snapshots[1].id)
        XCTAssertEqual(snapshots[0].trackingId, exercise.trackingId)
        XCTAssertEqual(snapshots[1].trackingId, exercise.trackingId)
        XCTAssertNotEqual(snapshots[0].logs[0].id, log.id)
        XCTAssertNotEqual(snapshots[1].logs[0].id, log.id)
        XCTAssertNotEqual(snapshots[0].logs[0].id, snapshots[1].logs[0].id)
    }

    func testFinishWorkoutRejectsDuplicateCompletionWithoutAddingHistory() {
        let routine = makeRoutine(name: "Strength")
        let workoutID = routine.workouts[0].id
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertCompletionSucceeds(store.finishWorkout(routineId: routine.id, workoutId: workoutID))
        XCTAssertCompletionFails(
            store.finishWorkout(routineId: routine.id, workoutId: workoutID),
            with: .alreadyCompleted
        )
        XCTAssertEqual(store.completedWorkouts.count, 1)
    }

    func testFinishWorkoutRejectsMissingRoutineOrWorkoutWithoutAddingHistory() {
        let routine = makeRoutine(name: "Strength")
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertCompletionFails(
            store.finishWorkout(routineId: UUID(), workoutId: routine.workouts[0].id),
            with: .routineNotFound
        )
        XCTAssertCompletionFails(
            store.finishWorkout(routineId: routine.id, workoutId: UUID()),
            with: .workoutNotFound
        )
        XCTAssertTrue(store.completedWorkouts.isEmpty)
        XCTAssertFalse(store.routines[0].workouts[0].isCompleted)
    }

    func testStartingAnotherRoutineDoesNotImplicitlyReplaceAnActiveWorkout() {
        let first = makeRoutine(name: "First")
        let second = makeRoutine(name: "Second")
        let store = makeEmptyStore()
        store.routines = [first, second]

        XCTAssertTrue(store.startWorkout(routineId: first.id, workoutId: first.workouts[0].id))
        XCTAssertFalse(store.startRoutine(routineId: second.id))

        XCTAssertEqual(store.activeRoutineId, first.id)
        XCTAssertEqual(store.activeWorkoutId, first.workouts[0].id)
        store.abandonRoutine(routineId: first.id, discardProgress: false)
        XCTAssertTrue(store.startRoutine(routineId: second.id))
        XCTAssertEqual(store.activeRoutineId, second.id)
    }

    func testStartingAnotherWorkoutDoesNotImplicitlyReplaceAnActiveWorkout() {
        let firstWorkout = Workout(name: "Upper", focus: "Chest", exercises: [])
        let secondWorkout = Workout(name: "Lower", focus: "Legs", exercises: [])
        let routine = Routine(name: "Strength", workouts: [firstWorkout, secondWorkout])
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertTrue(store.startWorkout(routineId: routine.id, workoutId: firstWorkout.id))
        XCTAssertFalse(store.startWorkout(routineId: routine.id, workoutId: secondWorkout.id))

        XCTAssertEqual(store.activeRoutineId, routine.id)
        XCTAssertEqual(store.activeWorkoutId, firstWorkout.id)
    }

    func testAbandonWorkoutCanKeepOrDiscardPartialProgress() {
        let exercise = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            isCompleted: true,
            logs: [SetLog(weight: 135, reps: 8, completedDate: Date())]
        )
        let workout = Workout(name: "Upper", focus: "Chest", exercises: [exercise], isCompleted: true)
        let routine = Routine(name: "Strength", workouts: [workout])
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertTrue(store.startWorkout(routineId: routine.id, workoutId: workout.id))
        store.abandonWorkout(routineId: routine.id, workoutId: workout.id, discardProgress: false)
        XCTAssertEqual(store.routines[0].workouts[0].exercises[0].logs.count, 1)
        XCTAssertTrue(store.routines[0].workouts[0].isCompleted)
        XCTAssertNil(store.activeWorkoutId)

        XCTAssertTrue(store.startWorkout(routineId: routine.id, workoutId: workout.id))
        store.abandonWorkout(routineId: routine.id, workoutId: workout.id, discardProgress: true)
        XCTAssertTrue(store.routines[0].workouts[0].exercises[0].logs.isEmpty)
        XCTAssertFalse(store.routines[0].workouts[0].exercises[0].isCompleted)
        XCTAssertFalse(store.routines[0].workouts[0].isCompleted)
        XCTAssertNil(store.activeWorkoutId)
    }

    func testAbandonRoutineDiscardingProgressClearsEveryWorkoutAndRestTimer() {
        let firstExercise = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            isCompleted: true,
            logs: [SetLog(weight: 135, reps: 8, completedDate: Date())]
        )
        let secondExercise = Exercise(
            name: "Row",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 95,
            isCompleted: true,
            logs: [SetLog(weight: 95, reps: 8, completedDate: Date())]
        )
        let firstWorkout = Workout(name: "Upper", focus: "Chest", exercises: [firstExercise], isCompleted: true)
        let secondWorkout = Workout(name: "Back", focus: "Back", exercises: [secondExercise], isCompleted: true)
        let routine = Routine(name: "Strength", workouts: [firstWorkout, secondWorkout])
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertTrue(store.startWorkout(routineId: routine.id, workoutId: firstWorkout.id))
        XCTAssertNotNil(store.startRestTimer(
            routineId: routine.id,
            workoutId: firstWorkout.id,
            exerciseId: firstExercise.id,
            duration: 60
        ))
        store.abandonRoutine(routineId: routine.id, discardProgress: true)

        XCTAssertTrue(store.routines[0].workouts.allSatisfy { !$0.isCompleted })
        XCTAssertTrue(store.routines[0].workouts.allSatisfy { $0.exercises.allSatisfy { $0.logs.isEmpty && !$0.isCompleted } })
        XCTAssertNil(store.activeRoutineId)
        XCTAssertNil(store.activeWorkoutId)
        XCTAssertNil(store.activeRestTimer)
    }

    func testMoveRoutinesPersistsOrderAndRetainsActiveIDs() throws {
        let first = makeRoutine(name: "First")
        let second = makeRoutine(name: "Second")
        let third = makeRoutine(name: "Third")
        let store = makeEmptyStore()
        store.routines = [first, second, third]
        store.activeRoutineId = second.id
        store.activeWorkoutId = second.workouts[0].id

        XCTAssertTrue(store.moveRoutines(fromOffsets: [0], toOffset: 3))
        XCTAssertEqual(store.routines.map(\.id), [second.id, third.id, first.id])
        XCTAssertEqual(store.activeRoutineId, second.id)
        XCTAssertEqual(store.activeWorkoutId, second.workouts[0].id)

        let savedData = try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode([Routine].self, from: savedData).map(\.id), [second.id, third.id, first.id])
    }

    func testMoveWorkoutsPersistsOrderAndRetainsActiveWorkoutID() {
        let first = Workout(name: "First", focus: "A", exercises: [])
        let second = Workout(name: "Second", focus: "B", exercises: [])
        let third = Workout(name: "Third", focus: "C", exercises: [])
        let routine = Routine(name: "Strength", workouts: [first, second, third])
        let store = makeEmptyStore()
        store.routines = [routine]
        store.activeRoutineId = routine.id
        store.activeWorkoutId = second.id

        XCTAssertTrue(store.moveWorkouts(routineId: routine.id, fromOffsets: [2], toOffset: 0))
        XCTAssertEqual(store.routines[0].workouts.map(\.id), [third.id, first.id, second.id])
        XCTAssertEqual(store.activeWorkoutId, second.id)
    }

    func testMoveCategoryExercisesPreservesOtherCategoryPositions() {
        let cardioFirst = Exercise(
            name: "Run",
            targetSets: 1,
            targetReps: "20 min",
            currentWeight: 0,
            category: .cardio
        )
        let weights = Exercise(
            name: "Bench Press",
            targetSets: 3,
            targetReps: "8",
            currentWeight: 135,
            category: .weightlifting
        )
        let cardioSecond = Exercise(
            name: "Bike",
            targetSets: 1,
            targetReps: "20 min",
            currentWeight: 0,
            category: .cardio
        )
        let stretch = Exercise(
            name: "Hamstring Stretch",
            targetSets: 1,
            targetReps: "30 sec",
            currentWeight: 0,
            category: .stretch
        )
        let workout = Workout(
            name: "Mixed",
            focus: "Full body",
            exercises: [cardioFirst, weights, cardioSecond, stretch]
        )
        let routine = Routine(name: "Strength", workouts: [workout])
        let store = makeEmptyStore()
        store.routines = [routine]

        XCTAssertTrue(store.moveExercises(
            routineId: routine.id,
            workoutId: workout.id,
            orderedExerciseIDs: [cardioFirst.id, cardioSecond.id],
            fromOffsets: [1],
            toOffset: 0
        ))

        XCTAssertEqual(
            store.routines[0].workouts[0].exercises.map(\.id),
            [cardioSecond.id, weights.id, cardioFirst.id, stretch.id]
        )
    }

    private func makeEmptyStore() -> RoutineStore {
        RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .empty,
            cancelTimerNotification: { _ in },
            cancelPendingTimerNotifications: { _ in }
        )
    }

    private func XCTAssertCompletionSucceeds(
        _ result: Result<Void, WorkoutCompletionError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case .failure(let error) = result {
            XCTFail("Expected workout completion to succeed, got: \(error.localizedDescription)", file: file, line: line)
        }
    }

    private func XCTAssertCompletionFails(
        _ result: Result<Void, WorkoutCompletionError>,
        with expectedError: WorkoutCompletionError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let error) = result else {
            return XCTFail("Expected workout completion to fail with \(expectedError)", file: file, line: line)
        }
        XCTAssertEqual(error, expectedError, file: file, line: line)
    }

    private func XCTAssertSetLogMutationSucceeds(
        _ result: Result<Void, SetLogMutationError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case .failure(let error) = result {
            XCTFail("Expected logged-set mutation to succeed, got: \(error.localizedDescription)", file: file, line: line)
        }
    }

    private func XCTAssertSetLogMutationFails(
        _ result: Result<Void, SetLogMutationError>,
        with expectedError: SetLogMutationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let error) = result else {
            return XCTFail("Expected logged-set mutation to fail with \(expectedError)", file: file, line: line)
        }
        XCTAssertEqual(error, expectedError, file: file, line: line)
    }

    private func makeRoutine(name: String) -> Routine {
        Routine(
            name: name,
            workouts: [Workout(name: "Workout", focus: "Focus", exercises: [])]
        )
    }

    private func makeExport(
        routines: [Routine] = [],
        completedWorkouts: [CompletedWorkout] = []
    ) -> AppExportData {
        AppExportData(
            schemaVersion: 1,
            exportedAt: Date(),
            routines: routines,
            completedWorkouts: completedWorkouts,
            exerciseLibrary: [],
            selectedTheme: .light,
            activeRoutineId: nil,
            activeWorkoutId: nil
        )
    }
}
