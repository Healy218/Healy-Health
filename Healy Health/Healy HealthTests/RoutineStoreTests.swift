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
        XCTAssertEqual(store.completedWorkouts[0].exercises.map(\.id), [exercise.id])
        XCTAssertEqual(store.completedWorkouts[0].exercises[0].logs.count, 1)
        XCTAssertEqual(store.completedWorkouts[0].exercises[0].logs[0].weight, 155)
        XCTAssertTrue(store.routines[0].workouts[0].isCompleted)
        XCTAssertNil(store.activeWorkoutId)
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

    private func makeEmptyStore() -> RoutineStore {
        RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .empty
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
